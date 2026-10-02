# OnixGuard — orquestación de desarrollo (polyrepo).
# Supone los repos clonados como hermanos (ver docker-compose.yml).
.DEFAULT_GOAL := help
# Detecta compose v2 plugin (`docker compose`) o standalone (`docker-compose`).
COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)
# E2E local: compose base + override con Postgres efímero dentro de Docker.
COMPOSE_E2E := $(COMPOSE) -f docker-compose.yml -f docker-compose.localdb.yml

.PHONY: help dev up down logs ps build migrate migrate-down test-db codegen smoke e2e e2e-up e2e-migrate e2e-smoke e2e-down local local-down

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

dev: ## Levanta todo (NATS + core + frontend) con build. Criterio de Fase 0.
	$(COMPOSE) up --build

up: ## Levanta en segundo plano
	$(COMPOSE) up --build -d

down: ## Baja todo y borra contenedores
	$(COMPOSE) down

logs: ## Sigue los logs de todos los servicios
	$(COMPOSE) logs -f

ps: ## Estado de los servicios
	$(COMPOSE) ps

build: ## Reconstruye las imágenes
	$(COMPOSE) build

migrate: ## Aplica migraciones de onix-db a DATABASE_URL (perfil migrate)
	$(COMPOSE) --profile migrate run --rm migrate

migrate-down: ## Revierte la última migración
	$(COMPOSE) --profile migrate run --rm migrate \
	  -path=/migrations -database "$${DATABASE_URL}" down 1

test-db: ## Aplica up y down contra la base para verificar las migraciones
	$(COMPOSE) --profile migrate run --rm migrate \
	  -path=/migrations -database "$${DATABASE_URL}" up
	$(COMPOSE) --profile migrate run --rm migrate \
	  -path=/migrations -database "$${DATABASE_URL}" down -all

codegen: ## Regenera los tipos Go/Rust de onix-contracts
	bash ../onix-contracts/codegen/generate.sh

smoke: ## Smoke test de Fase 0: comprueba que /healthz responde
	@echo "Esperando a ingestor…"; \
	for i in $$(seq 1 30); do \
	  if curl -fsS http://localhost:8081/healthz >/dev/null 2>&1; then \
	    echo "✓ /healthz OK"; curl -s http://localhost:8081/healthz; echo; exit 0; \
	  fi; sleep 2; \
	done; \
	echo "✗ /healthz no respondió a tiempo"; exit 1

# ─────────────── E2E de Fase 1 (con Postgres efímero en Docker) ───────────────
e2e: e2e-up e2e-migrate e2e-smoke ## Fase 1 completa en local: levanta todo + migra + verifica

e2e-up: ## Levanta NATS + core + gateway + frontend + Postgres efímero (build, detached)
	$(COMPOSE_E2E) up --build -d

e2e-migrate: ## Aplica migraciones de onix-db al Postgres efímero
	$(COMPOSE_E2E) --profile migrate run --rm migrate

e2e-smoke: ## Verifica que core y gateway responden /healthz
	@echo "Esperando a core y gateway…"; \
	ok=0; for i in $$(seq 1 30); do \
	  if curl -fsS http://localhost:8081/healthz >/dev/null 2>&1 && curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then ok=1; break; fi; sleep 2; \
	done; \
	if [ $$ok -eq 1 ]; then echo "✓ core y gateway OK"; else echo "✗ no respondieron"; exit 1; fi

e2e-down: ## Baja el stack E2E y borra el volumen de Postgres
	$(COMPOSE_E2E) --profile migrate down -v

# ─────────────── Local de un comando (para dejarlo corriendo en tu PC) ───────────────
local: ## Levanta TODO en local (Docker + Postgres + frontend + onix-agent) y da la URL
	bash scripts/local.sh

local-down: ## Baja el stack local (usa 'make local-down ARGS=-v' para borrar datos)
	bash scripts/local-down.sh $(ARGS)
