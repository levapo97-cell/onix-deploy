#!/usr/bin/env bash
# OnixGuard — preparación del VPS (lo corre EL JEFE en el servidor, una sola vez).
# No contiene secretos: te pide que crees /opt/onixguard/.env con ellos.
# Uso:  sudo bash vps-setup.sh
set -euo pipefail

APP_DIR=/opt/onixguard
REPO_OWNER=levapo97-cell

echo "== 1. Docker =="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || { echo "Instala el plugin docker compose v2"; exit 1; }

echo "== 2. Carpeta de la app =="
mkdir -p "$APP_DIR/nats"
cd "$APP_DIR"

echo "== 3. Archivos de despliegue =="
# Copia aquí docker-compose.prod.yml y nats/nats.conf desde el repo onix-deploy, p.ej.:
#   scp onix-deploy/docker-compose.prod.yml  vps:/opt/onixguard/docker-compose.yml
#   scp onix-deploy/nats/nats.conf           vps:/opt/onixguard/nats/nats.conf
#   scp onix-deploy/nginx/onix.conf          vps:/etc/nginx/sites-available/onix.conf
[ -f docker-compose.yml ] || { echo "Falta /opt/onixguard/docker-compose.yml (usa docker-compose.prod.yml)"; exit 1; }

echo "== 4. Secretos (.env) =="
if [ ! -f .env ]; then
  cat > .env <<'ENV'
# Rellena con valores REALES (nunca los subas a git):
DATABASE_URL=postgresql://devtools:CAMBIA_ME@localhost:5432/onixguard
JWT_SECRET=CAMBIA_ME_aleatorio_largo
PANEL_USER=jefe
PANEL_PASSWORD_HASH=CAMBIA_ME_bcrypt
CORS_ORIGIN=https://onix.devtoolsdk.com
ENV
  echo "   Creé .env de plantilla en $APP_DIR/.env → EDÍTALO con los valores reales y vuelve a correr."
  exit 0
fi

echo "== 5. Login a GHCR =="
# Necesita un PAT con read:packages, o 'gh auth token'. Export GHCR_TOKEN y GHCR_USER antes.
if [ -n "${GHCR_TOKEN:-}" ]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "${GHCR_USER:-$REPO_OWNER}" --password-stdin
fi

echo "== 6. Arranque =="
docker compose pull
docker compose up -d

echo "== 7. nginx (manual) =="
echo "   Habilita onix.conf:  ln -s /etc/nginx/sites-available/onix.conf /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx"
echo "   Y en Cloudflare: apunta onix.devtoolsdk.com al VPS; no buffereies /ws ni /mcp."

echo "✓ Listo. 'docker compose ps' para ver el estado. Migraciones: ver docs/RUNBOOK.md."
