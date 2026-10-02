# OnixGuard — Runbook de operación

Guía operativa del despliegue en el VPS. Para desarrollo local ver el README de `onix-deploy`.

## Topología (producción)
- **VPS** (tras nginx + Cloudflare, subdominio `onix.devtoolsdk.com`): NATS/JetStream, `onix-ingestor`, `onix-guard`, `onix-recorder`, `onix-orchestrator`, `onix-gateway`, frontend. PostgreSQL **externo al compose** (en el host del VPS).
- **Tu PC**: `onix-hook` (telemetría) y `onix-agent` (proyectos/repos). Solo conexiones **salientes** a NATS (TLS + token).

## Configurar los secrets en GitHub (lo haces TÚ — nunca me los pases)
La clave SSH privada **jamás** se comparte ni se pone en un archivo del repo. Con el CLI `gh`:
```bash
# una sola vez, a nivel de organización/usuario (o repo por repo con -R <owner>/<repo>):
gh auth login
for r in onix-ingestor onix-guard onix-recorder onix-orchestrator onix-gateway OnixGuard; do
  gh secret set VPS_HOST    -R levapo97-cell/$r -b "IP_O_DOMINIO_DEL_VPS"
  gh secret set VPS_USER    -R levapo97-cell/$r -b "usuario_deploy"
  gh secret set VPS_SSH_KEY -R levapo97-cell/$r < ~/.ssh/onix_deploy_key   # la PRIVADA, leída de tu disco
done
```
En el VPS, `/opt/onixguard/.env` tiene: `DATABASE_URL` (password fuerte), `JWT_SECRET`, `PANEL_USER`, `PANEL_PASSWORD_HASH` (bcrypt), `CORS_ORIGIN`.
Generar el hash bcrypt del panel: `htpasswd -bnBC 12 "" 'TU_PASSWORD' | tr -d ':\n' | sed 's/^$2y/$2a/'` (o cualquier generador bcrypt).

## Despliegue (CD)
- Cada repo de servicio tiene `.github/workflows/cd.yml` que invoca `reusable-cd.yml` de este repo: build → push a GHCR → SSH al VPS → `docker compose up -d --no-deps <svc>` → health-check → **rollback** a la imagen previa si falla.
- Secrets necesarios en cada repo de servicio: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`.
- En el VPS, `/opt/onixguard` contiene el `docker-compose.yml` de producción (imágenes `ghcr.io/levapo97-cell/<svc>:current`) y el `.env` con los secretos.

## Secretos (nunca en git/imagen/logs)
- `DATABASE_URL` (Postgres del VPS, contraseña FUERTE — cambiar la de dev `Qwerty*`).
- `JWT_SECRET`, `PANEL_USER`, `PANEL_PASSWORD_HASH` (bcrypt) — login del panel.
- `NATS_TOKEN` (auth de máquina para onix-hook/onix-agent).
- Rotar un secreto: actualizar en el gestor de secretos del VPS → `docker compose up -d <svc>` para recargarlo.

## Operaciones
```bash
# ver estado / logs
docker compose ps
docker compose logs -f onix-gateway        # nunca loguear secretos

# redeploy manual de un servicio
docker compose pull onix-gateway && docker compose up -d --no-deps onix-gateway

# rollback manual (a la imagen anterior)
docker tag ghcr.io/levapo97-cell/onix-gateway:<sha-previo> ghcr.io/levapo97-cell/onix-gateway:current
docker compose up -d --no-deps onix-gateway

# migraciones de BD (onix-db)
docker run --rm -v "$PWD/onix-db/migrations:/migrations" migrate/migrate \
  -path=/migrations -database "$DATABASE_URL" up

# backup / restore de Postgres (en el host del VPS)
pg_dump "$DATABASE_URL" > backup-$(date +%F).sql
psql "$DATABASE_URL" < backup-AAAA-MM-DD.sql
```

## nginx / Cloudflare
- `nginx/onix.conf` rutea `/` (frontend), `/api`+`/auth` y `/ws` (gateway), `/mcp` (orchestrator).
- **Importante:** `/ws` y `/mcp` necesitan timeouts largos y sin buffering (ya en el conf). En Cloudflare, no bufferear esas rutas o el MCP bloqueante se corta (~100s).

## Checklist pre-producción (hardening)
- [ ] Contraseña fuerte de Postgres + `PANEL_PASSWORD_HASH` (bcrypt), no los defaults de dev.
- [ ] `JWT_SECRET` aleatorio y secreto.
- [ ] NATS con TLS + `NATS_TOKEN` (hoy dev sin TLS).
- [ ] Rate-limit de login activo (ya implementado en el gateway).
- [ ] Revisar que `onix-guard` redacta (test de credenciales en verde).
- [ ] CORS del gateway restringido al dominio del panel (hoy `*` en dev).
