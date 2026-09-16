#!/bin/bash

# ============================================
# CSPM Automation Script
# Ejecuta el ciclo completo: Deploy → Scan → Remediate → Validate
# ============================================

set -e

# Colors para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones helper
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar que las credenciales AWS estén configuradas
check_aws_credentials() {
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_error "AWS credentials not found!"
        echo "Por favor configura las variables de entorno:"
        echo "  export AWS_ACCESS_KEY_ID=your_key"
        echo "  export AWS_SECRET_ACCESS_KEY=your_secret"
        echo "  export AWS_SESSION_TOKEN=your_token (si usas SSO)"
        exit 1
    fi
    log_success "AWS credentials configured"
}

# Paso 1: Deploy vulnerable infrastructure
deploy_infrastructure() {
    log_info "Paso 1/5: Desplegando infraestructura vulnerable..."
    
    docker-compose run --rm terraform -chdir=/workspace init
    docker-compose run --rm terraform -chdir=/workspace apply -auto-approve
    
    log_success "Infraestructura desplegada"
}

# Paso 2: Initial Prowler scan
initial_scan() {
    log_info "Paso 2/5: Escaneando con Prowler (scan inicial)..."
    
    # Crear directorio de output
    mkdir -p prowler-output-before
    
    # Ejecutar Prowler con filtros
    log_info "   📌 Filtrado: Solo EC2, S3, IAM, VPC | Severidad: Critical, High"
    docker-compose run --rm \
        -v $(pwd)/prowler-output-before:/prowler/output \
        prowler aws \
        --resource-tag Project=cspm-demo \
        --services ec2 s3 iam vpc \
        --severity critical high \
        --output-formats html csv json-ocsf \
        --output-directory /prowler/output
    
    log_success "Scan inicial completado"
    log_info "Reporte: $(ls -t prowler-output-before/*.html | head -1)"
}

# Paso 3: Analyze findings
analyze_findings() {
    log_info "Paso 3/5: Analizando hallazgos..."
    
    # Contar fallas en el CSV
    TOTAL_CHECKS=$(tail -n +2 prowler-output-before/*.csv | wc -l | tr -d ' ')
    FAILED_CHECKS=$(tail -n +2 prowler-output-before/*.csv | grep -c "FAIL" || true)
    PASSED_CHECKS=$(tail -n +2 prowler-output-before/*.csv | grep -c "PASS" || true)
    
    echo ""
    echo "📊 Resultados del scan inicial:"
    echo "   Total checks: $TOTAL_CHECKS"
    echo "   ❌ Failed: $FAILED_CHECKS"
    echo "   ✅ Passed: $PASSED_CHECKS"
    echo ""
    
    log_warning "Vulnerabilidades críticas detectadas - procediendo a remediación..."
}

# Paso 4: Remediate with Cloud Custodian
remediate() {
    log_info "Paso 4/5: Remediando con Cloud Custodian..."
    
    # Build the custodian image
    docker-compose build custodian
    
    # Ejecutar políticas de remediación
    docker-compose run --rm custodian \
        run -s /custodian/output \
        /custodian/policies/remediation-policies.yml
    
    log_success "Remediación completada"
    
    # Esperar un poco para que AWS propague los cambios
    log_info "Esperando 30 segundos para propagación de cambios..."
    sleep 30
}

# Paso 5: Validate with second Prowler scan
validate() {
    log_info "Paso 5/5: Validando remediación con segundo scan de Prowler..."
    
    # Crear directorio de output
    mkdir -p prowler-output-after
    
    # Ejecutar Prowler de nuevo con filtros
    log_info "   📌 Filtrado: Solo EC2, S3, IAM, VPC | Severidad: Critical, High"
    docker-compose run --rm \
        -v $(pwd)/prowler-output-after:/prowler/output \
        prowler aws \
        --resource-tag Project=cspm-demo \
        --services ec2 s3 iam vpc \
        --severity critical high \
        --output-formats html csv json-ocsf \
        --output-directory /prowler/output
    
    log_success "Scan de validación completado"
    
    # Contar fallas después de remediación
    TOTAL_CHECKS_AFTER=$(tail -n +2 prowler-output-after/*.csv | wc -l | tr -d ' ')
    FAILED_CHECKS_AFTER=$(tail -n +2 prowler-output-after/*.csv | grep -c "FAIL" || true)
    PASSED_CHECKS_AFTER=$(tail -n +2 prowler-output-after/*.csv | grep -c "PASS" || true)
    
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
    else
        log_warning "No se detectaron mejoras automáticas"
    fi
}

# Función de cleanup
cleanup() {
    log_warning "Destruyendo infraestructura..."
    docker-compose run --rm terraform -chdir=/workspace destroy -auto-approve
    log_success "Infraestructura destruida"
}

# Menú principal
show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║   CSPM Automation - Ciclo Completo        ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    echo "Selecciona una opción:"
    echo "  1) Ejecutar ciclo completo (Deploy → Scan → Remediate → Validate)"
    echo "  2) Solo deploy de infraestructura"
    echo "  3) Solo scan con Prowler"
    echo "  4) Solo remediación con Cloud Custodian"
    echo "  5) Destruir infraestructura (cleanup)"
    echo "  0) Salir"
    echo ""
    read -p "Opción: " choice
    
    case $choice in
        1)
            check_aws_credentials
            deploy_infrastructure
            initial_scan
            analyze_findings
            remediate
            validate
            log_success "¡Ciclo CSPM completado!"
            ;;
        2)
            check_aws_credentials
            deploy_infrastructure
            ;;
        3)
            check_aws_credentials
            initial_scan
            ;;
        4)
            check_aws_credentials
            remediate
            ;;
        5)
            check_aws_credentials
            cleanup
            ;;
        0)
            log_info "Saliendo..."
            exit 0
            ;;
        *)
            log_error "Opción inválida"
            show_menu
            ;;
    esac
}

# Main
clear
show_menu
