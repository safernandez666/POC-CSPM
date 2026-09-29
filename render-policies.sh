#!/bin/bash
# ============================================
# Renderiza las policies de Cloud Custodian sustituyendo
# ${SLACK_WEBHOOK_URL} por el valor real leído de .env.
#
# Cloud Custodian no soporta variables de entorno dentro de las
# policies, así que este script genera una copia "rendered" que
# SÍ tiene la URL real. Esa copia queda en .gitignore — nunca se
# commitea. El archivo fuente (remediation-policies.yml) se sube
# a git con el placeholder intacto.
# ============================================

set -euo pipefail
cd "$(dirname "$0")"

SRC="cloud-custodian-policies/remediation-policies.yml"
OUT="cloud-custodian-policies/remediation-policies.rendered.yml"

if [ ! -f .env ]; then
  echo "❌ Falta .env (copiá .env.example a .env y completá tus credenciales)"
  exit 1
fi

SLACK_WEBHOOK_URL=$(grep -E '^SLACK_WEBHOOK_URL=' .env | head -1 | cut -d '=' -f2- || true)

if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "⚠️  SLACK_WEBHOOK_URL no está seteado en .env — las notificaciones a Slack quedarán vacías (webhook a URL en blanco fallará silenciosamente)."
fi

sed "s|\${SLACK_WEBHOOK_URL}|${SLACK_WEBHOOK_URL}|g" "$SRC" > "$OUT"

echo "✅ Policies renderizadas en $OUT"
