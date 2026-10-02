#!/usr/bin/env bash
# Baja OnixGuard local (stack + onix-agent). Con -v borra también los datos (Postgres efímero).
set -uo pipefail
cd "$(dirname "$0")/.."
COMPOSE="docker compose"; docker compose version >/dev/null 2>&1 || COMPOSE="docker-compose"
FILES="-f docker-compose.yml -f docker-compose.localdb.yml"

pkill -f "/tmp/onix-agent" 2>/dev/null && echo "onix-agent detenido" || true
if [ "${1:-}" = "-v" ]; then
  $COMPOSE $FILES --profile migrate down -v
  echo "stack y datos borrados"
else
  $COMPOSE $FILES --profile migrate down
  echo "stack detenido (datos conservados en el volumen)"
fi
