#!/usr/bin/env bash
# Instalador de OnixGuard en LOCAL con un comando.
# Clona los repos (rama dev) y levanta todo. Requisitos: git, docker (o colima), y Go (para onix-agent).
#
# Uso:
#   bash <(curl -fsSL https://raw.githubusercontent.com/levapo97-cell/onix-deploy/dev/scripts/install.sh)
#   # o:  DIR=~/OnixGuard bash install.sh
set -euo pipefail

OWNER=levapo97-cell
BRANCH="${BRANCH:-dev}"
DIR="${DIR:-$HOME/OnixGuard}"
REPOS="onix-contracts onix-db onix-deploy onix-ingestor onix-guard onix-recorder onix-orchestrator onix-gateway onix-hook onix-agent OnixGuard"

echo "== Instalando OnixGuard en: $DIR (rama $BRANCH) =="
command -v git >/dev/null || { echo "Falta git"; exit 1; }
command -v docker >/dev/null || { echo "Falta Docker (instala Docker Desktop o 'brew install colima docker-compose')"; exit 1; }

mkdir -p "$DIR"; cd "$DIR"
for r in $REPOS; do
  if [ -d "$r/.git" ]; then
    echo "→ $r: actualizando"; ( cd "$r" && git fetch -q origin "$BRANCH" && git checkout -q "$BRANCH" && git pull -q )
  else
    echo "→ $r: clonando"; git clone -q -b "$BRANCH" "https://github.com/$OWNER/$r.git" || git clone -q "https://github.com/$OWNER/$r.git"
  fi
done

echo "== Levantando (make local) =="
cd onix-deploy
make local

echo
echo "✓ Instalado. Panel: http://localhost:3000  (jefe / onix)"
echo "  Apagar:  cd $DIR/onix-deploy && make local-down"
