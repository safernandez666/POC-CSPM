#!/bin/bash
# ============================================
# CSPM Automate — el pipeline real, para tu cuenta AWS
#
# Esto es lo que te llevás de este proyecto: escanea tu cuenta con
# Prowler, remedia lo que matchee tus policies de Cloud Custodian,
# vuelve a escanear para confirmar, y te avisa por Slack en cada paso.
#
# NO crea ni destruye infraestructura. No es parte de este script ni
# debería serlo — vos ya tenés tu infra. Antes de correrlo:
#
#   1. Completá .env con tus credenciales AWS (y opcionalmente
#      SLACK_WEBHOOK_URL) — ver .env.example.
#   2. Ajustá cloud-custodian-policies/remediation-policies.yml a tus
#      propios recursos: el filtro `tag:Project: cspm-demo` de este repo
#      es del demo, cambialo por el tag (o filtro) que use tu cuenta.
#   3. Corré con --dry-run primero si no confiás todavía (ver custodian
#      run -d) antes de dejar que remedie de verdad.
#
# Uso: ./cspm-automate.sh
# ============================================

set -e
cd "$(dirname "$0")"

source ./cspm-pipeline.sh

check_aws_credentials
run_initial_scan
run_analysis
run_remediation
run_validation

log_success "¡Pipeline CSPM completado!"
