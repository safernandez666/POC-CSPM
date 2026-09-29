#!/bin/bash

# ============================================
# CSPM Demo Orchestrator (SOLO para este repo)
# Crea infra vulnerable de juguete con Terraform para tener algo que
# escanear, y corre el pipeline real (cspm-pipeline.sh) sobre ella.
#
# Si estás leyendo esto para aplicarlo a TU cuenta AWS: no uses este
# script. Usá ./cspm-automate.sh, que es el mismo pipeline sin el
# deploy/destroy de infra de juguete — vos ya tenés tu propia infra.
# ============================================

set -e
cd "$(dirname "$0")"

source ./cspm-pipeline.sh

# Paso 1: Deploy vulnerable infrastructure (SOLO demo — no forma parte
# del pipeline CSPM real, ver cspm-automate.sh)
deploy_infrastructure() {
    log_info "Paso 1/5: Desplegando infraestructura vulnerable (demo)..."

    docker-compose run --rm terraform -chdir=/workspace init
    docker-compose run --rm terraform -chdir=/workspace apply -auto-approve

    log_success "Infraestructura desplegada"
}

# Destruye la infra de juguete (SOLO demo)
cleanup() {
    log_warning "Destruyendo infraestructura de demo..."
    docker-compose run --rm terraform -chdir=/workspace destroy -auto-approve
    log_success "Infraestructura destruida"
}

# Menú principal
show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║   CSPM Demo — POC-CSPM (infra de juguete) ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    echo "Para correr el pipeline CSPM contra TU cuenta AWS real,"
    echo "usá ./cspm-automate.sh en cambio — este menú es solo para"
    echo "levantar/tirar la infra vulnerable de este demo."
    echo ""
    echo "Selecciona una opción:"
    echo "  1) Ciclo completo del demo (Deploy → Scan → Remediate → Validate)"
    echo "  2) Solo deploy de infraestructura de demo"
    echo "  3) Solo scan con Prowler"
    echo "  4) Solo remediación con Cloud Custodian"
    echo "  5) Destruir infraestructura de demo (cleanup)"
    echo "  0) Salir"
    echo ""
    read -p "Opción: " choice

    case $choice in
        1)
            check_aws_credentials
            deploy_infrastructure
            run_initial_scan
            run_analysis
            run_remediation
            run_validation
            log_success "¡Ciclo CSPM completado!"
            ;;
        2)
            check_aws_credentials
            deploy_infrastructure
            ;;
        3)
            check_aws_credentials
            run_initial_scan
            ;;
        4)
            check_aws_credentials
            run_remediation
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
