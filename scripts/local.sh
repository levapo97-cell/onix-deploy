#!/usr/bin/env bash
# OnixGuard en LOCAL con un solo comando: backend + Postgres + frontend + onix-agent.
# Pensado para dejarlo corriendo en tu PC. (Para producción: ver RUNBOOK / Vercel.)
set -euo pipefail
cd "$(dirname "$0")/.."   # onix-deploy

echo "== OnixGuard local =="

# 1. Motor de Docker
if ! docker info >/dev/null 2>&1; then
  if command -v colima >/dev/null 2>&1; then echo "→ arrancando colima…"; colima start; else
    echo "✗ Docker no está corriendo. Abre Docker Desktop o instala colima (brew install colima docker-compose)."; exit 1; fi
fi

# 2. Compose (v2 plugin o standalone)
COMPOSE="docker compose"; docker compose version >/dev/null 2>&1 || COMPOSE="docker-compose"
FILES="-f docker-compose.yml -f docker-compose.localdb.yml"

# 3. Levantar todo (incluye Postgres efímero y frontend)
echo "→ construyendo y levantando servicios (primera vez tarda)…"
$COMPOSE $FILES up --build -d

# 4. Migraciones
echo "→ aplicando migraciones…"
$COMPOSE $FILES --profile migrate run --rm migrate

# 5. onix-agent en tu PC (para Proyectos/Sesiones). Necesita Go, o un binario prebuilt.
AGENT_DIR="$(cd ../onix-agent 2>/dev/null && pwd || true)"
if [ -n "$AGENT_DIR" ]; then
  if command -v go >/dev/null 2>&1; then
    echo "→ compilando onix-agent…"
    ( cd "$AGENT_DIR" && go build -o /tmp/onix-agent ./cmd/onix-agent )
    pkill -f "/tmp/onix-agent" 2>/dev/null || true
    NATS_URL=nats://localhost:4222 nohup /tmp/onix-agent >/tmp/onix-agent.log 2>&1 &
    echo "  onix-agent corriendo (log: /tmp/onix-agent.log)"
  else
    echo "  (Go no instalado → onix-agent no arrancó. Proyectos/Sesiones quedarán sin agente local.)"
  fi
fi

# 6. Esperar health del frontend y el gateway
ok=0
for i in $(seq 1 30); do
  if curl -fsS http://localhost:3000/healthz >/dev/null 2>&1 && curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done

echo
if [ "$ok" = "1" ]; then
  echo "✓ OnixGuard LISTO"
else
  echo "⚠ Levantado, pero el health tardó. Revisa: $COMPOSE $FILES ps"
fi
echo "   Panel:    http://localhost:3000"
echo "   Usuario:  jefe"
echo "   Password: onix"
echo "   Apagar:   make local-down"
