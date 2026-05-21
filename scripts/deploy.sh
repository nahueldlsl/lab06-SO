#!/usr/bin/env bash
# Remote deployment script — executed on the server via SSH
set -euo pipefail

DEPLOY_DIR=${DEPLOY_DIR:-/opt/lab06}

echo "[deploy] Logging in to ghcr.io..."
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

echo "[deploy] Pulling latest images..."
docker compose -f "$DEPLOY_DIR/docker-compose.yml" pull

echo "[deploy] Starting services..."
docker compose -f "$DEPLOY_DIR/docker-compose.yml" up -d --remove-orphans

echo "[deploy] Waiting for services to start..."
sleep 5

echo "[deploy] Verifying dummy-a (port 80)..."
curl -sf http://localhost/ | grep -q "Hola Mundo DevOps" \
  && echo "[deploy] dummy-a: OK" \
  || { echo "[deploy] dummy-a: FAIL"; exit 1; }

echo "[deploy] Verifying dummy-b (port 8080)..."
STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:8080/health)
[ "$STATUS" = "200" ] \
  && echo "[deploy] dummy-b: OK (HTTP $STATUS)" \
  || { echo "[deploy] dummy-b: FAIL (HTTP $STATUS)"; exit 1; }

echo "[deploy] Deployment successful."
