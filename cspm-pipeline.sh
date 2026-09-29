#!/bin/bash
# ============================================
# CSPM Pipeline — funciones compartidas
# Escaneo (Prowler) → Remediación (Cloud Custodian) → Validación → Slack
#
# Esto es una LIBRERÍA (se sourcea, no se corre directo) y NO toca
# infraestructura — no crea ni destruye nada. La usan:
#
#   - cspm-automate.sh → corré esto contra tu propia cuenta AWS real,
#     apuntando tus propias policies de Cloud Custodian.
#   - run-cspm.sh       → el demo de ESTE repo, que además crea y destruye
#     una infra vulnerable de juguete con Terraform para tener algo que
#     escanear. Esa parte es solo para la demo, no para uso real.
# ============================================

# Colors para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar que las credenciales AWS estén configuradas
check_aws_credentials() {
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_error "AWS credentials not found!"
        echo "Por favor configura las variables de entorno (o tu .env):"
        echo "  export AWS_ACCESS_KEY_ID=your_key"
        echo "  export AWS_SECRET_ACCESS_KEY=your_secret"
        echo "  export AWS_SESSION_TOKEN=your_token (si usas SSO)"
        exit 1
    fi
    log_success "AWS credentials configured"
}

# Notificar a Slack (lee SLACK_WEBHOOK_URL de .env; si está vacío, no hace nada)
send_slack() {
    local text="$1"
    local webhook
    webhook=$(grep -E '^SLACK_WEBHOOK_URL=' .env 2>/dev/null | head -1 | cut -d '=' -f2-)
    if [ -z "$webhook" ]; then
        return 0
    fi
    curl -s -X POST -H 'Content-type: application/json' \
        --data "$(jq -n --arg text "$text" '{text: $text}')" \
        "$webhook" > /dev/null || log_warning "No se pudo notificar a Slack"
}

# Cuenta hallazgos del CSV de Prowler correctamente:
# - El CSV usa `;` como delimitador y varios campos (Risk, Remediation, etc.)
#   traen texto con saltos de línea propios, así que `wc -l` / `grep -c "FAIL"`
#   sobre el archivo crudo cuenta líneas físicas, no filas lógicas — da
#   números completamente inflados/incorrectos.
# - Solo toma el CSV más reciente del directorio (run_initial_scan/run_validation
#   limpian el directorio antes de escanear, así que debería haber uno solo).
# Imprime "TOTAL FAILED PASSED" separado por espacios.
count_prowler_csv() {
    local dir="$1"
    python3 -c "
import csv, glob, os
files = sorted(glob.glob('$dir/*.csv'), key=os.path.getmtime, reverse=True)
if not files:
    print('0 0 0')
else:
    with open(files[0], newline='') as fh:
        r = csv.reader(fh, delimiter=';')
        header = next(r)
        idx = header.index('STATUS')
        rows = list(r)
        total = len(rows)
        failed = sum(1 for row in rows if row[idx] == 'FAIL')
        passed = sum(1 for row in rows if row[idx] == 'PASS')
        print(total, failed, passed)
"
}

# Escaneo inicial con Prowler
run_initial_scan() {
    log_info "Escaneando con Prowler (scan inicial)..."

    # Directorio limpio — si queda un CSV de una corrida anterior, el
    # conteo de hallazgos mezcla ambos scans y da cualquier cosa.
    mkdir -p prowler-output-before
    rm -f prowler-output-before/*.csv prowler-output-before/*.html prowler-output-before/*.json

    # Prowler devuelve exit code != 0 cuando encuentra checks FAILED —
    # es esperado y NO es un error del script.
    log_info "   📌 Filtrado: Solo EC2, S3, IAM, VPC | Severidad: Critical, High"
    docker-compose run --rm \
        -v $(pwd)/prowler-output-before:/prowler/output \
        prowler aws \
        --resource-tag Project=cspm-demo \
        --services ec2 s3 iam vpc \
        --severity critical high \
        --output-formats html csv json-ocsf \
        --output-directory /prowler/output || true

    log_success "Scan inicial completado"
    log_info "Reporte: $(ls -t prowler-output-before/*.html | head -1)"
}

# Analiza los hallazgos del scan inicial y notifica a Slack
run_analysis() {
    log_info "Analizando hallazgos..."

    read -r TOTAL_CHECKS FAILED_CHECKS PASSED_CHECKS <<< "$(count_prowler_csv prowler-output-before)"

    echo ""
    echo "📊 Resultados del scan inicial:"
    echo "   Total checks: $TOTAL_CHECKS"
    echo "   ❌ Failed: $FAILED_CHECKS"
    echo "   ✅ Passed: $PASSED_CHECKS"
    echo ""

    log_warning "Vulnerabilidades críticas detectadas - procediendo a remediación..."

    send_slack "🔎 *Prowler* escaneó la cuenta AWS: *${FAILED_CHECKS} checks FAILED* / ${PASSED_CHECKS} passed (${TOTAL_CHECKS} total). Arrancando remediación automática con Cloud Custodian..."
}

# Remediación con Cloud Custodian
run_remediation() {
    log_info "Remediando con Cloud Custodian..."

    docker-compose build custodian

    # Renderizar policies con la URL real de Slack (lee .env, nunca se commitea)
    ./render-policies.sh

    docker-compose run --rm custodian \
        run -s /custodian/output \
        /custodian/policies/remediation-policies.rendered.yml

    log_success "Remediación completada"

    log_info "Esperando 30 segundos para propagación de cambios..."
    sleep 30
}

# Segundo scan de Prowler para validar + comparación before/after a Slack
run_validation() {
    log_info "Validando remediación con segundo scan de Prowler..."

    mkdir -p prowler-output-after
    rm -f prowler-output-after/*.csv prowler-output-after/*.html prowler-output-after/*.json

    log_info "   📌 Filtrado: Solo EC2, S3, IAM, VPC | Severidad: Critical, High"
    docker-compose run --rm \
        -v $(pwd)/prowler-output-after:/prowler/output \
        prowler aws \
        --resource-tag Project=cspm-demo \
        --services ec2 s3 iam vpc \
        --severity critical high \
        --output-formats html csv json-ocsf \
        --output-directory /prowler/output || true

    log_success "Scan de validación completado"

    read -r TOTAL_CHECKS_AFTER FAILED_CHECKS_AFTER PASSED_CHECKS_AFTER <<< "$(count_prowler_csv prowler-output-after)"

    echo ""
    echo "📊 Comparación Before / After:"
    echo ""
    echo "   BEFORE remediation:"
    echo "   ❌ Failed: $FAILED_CHECKS"
    echo "   ✅ Passed: $PASSED_CHECKS"
    echo ""
    echo "   AFTER remediation:"
    echo "   ❌ Failed: $FAILED_CHECKS_AFTER"
    echo "   ✅ Passed: $PASSED_CHECKS_AFTER"
    echo ""

    IMPROVEMENT=$((FAILED_CHECKS - FAILED_CHECKS_AFTER))
    if [ $IMPROVEMENT -gt 0 ]; then
        log_success "¡Mejoramos! Resolvimos $IMPROVEMENT vulnerabilidades"
        if [ "$FAILED_CHECKS" -gt 0 ]; then
            IMPROVEMENT_PCT=$(( IMPROVEMENT * 100 / FAILED_CHECKS ))
        else
            IMPROVEMENT_PCT=0
        fi
        send_slack "✅ *Ciclo CSPM completo*
Antes: *${FAILED_CHECKS} failed* / ${PASSED_CHECKS} passed
Después: *${FAILED_CHECKS_AFTER} failed* / ${PASSED_CHECKS_AFTER} passed
Mejora: *${IMPROVEMENT_PCT}%* automática — ${IMPROVEMENT} vulnerabilidad(es) resueltas por Cloud Custodian sin intervención manual."
    else
        log_warning "No se detectaron mejoras automáticas"
        send_slack "⚠️ *Ciclo CSPM completo* sin mejoras detectadas. Antes: ${FAILED_CHECKS} failed → Después: ${FAILED_CHECKS_AFTER} failed"
    fi
}
