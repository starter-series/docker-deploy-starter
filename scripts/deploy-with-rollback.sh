#!/usr/bin/env bash
# Deploy a container image via docker compose with automatic rollback on
# health-check failure.
#
# This script is shared between:
#   - .github/workflows/cd.yml  (runs on the VPS over SSH during production deploy)
#   - .github/workflows/ci.yml  (runs locally on the CI runner as a regression test)
#
# Responsibilities:
#   1. Detect the image currently running for the "app" service (if any) and
#      remember it as the rollback target.
#   2. Write a docker-compose.yml that points at the new image.
#   3. `docker compose up -d --wait` — Docker blocks until the container is
#      healthy. If unhealthy, the command fails.
#   4. On failure, rewrite the compose file with the previous image and
#      restart. If there was no previous image, exit non-zero.
#
# Required env vars:
#   IMAGE        Container image to deploy (e.g. ghcr.io/org/app:1.2.3)
#   PORT         Port the app listens on (host and container)
#   DEPLOY_DIR   Directory that holds docker-compose.yml (created if missing)
#
# Optional env vars:
#   ENV_FILE     Path to an env_file for the compose service. Empty disables it.
#   SKIP_PULL    If "1", skip `docker compose pull` (useful when the test has
#                already loaded a local image that is not in a registry).

set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${PORT:?PORT is required}"
: "${DEPLOY_DIR:?DEPLOY_DIR is required}"
ENV_FILE="${ENV_FILE:-}"
SKIP_PULL="${SKIP_PULL:-0}"

mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

write_compose() {
  local img="$1"
  {
    echo "services:"
    echo "  app:"
    echo "    image: $img"
    if [ -n "$ENV_FILE" ]; then
      echo "    env_file: $ENV_FILE"
    fi
    echo "    ports:"
    echo "      - \"${PORT}:${PORT}\""
    echo "    restart: unless-stopped"
    echo "    healthcheck:"
    echo "      test: [\"CMD-SHELL\", \"wget -qO /dev/null http://localhost:${PORT}/health || exit 1\"]"
    echo "      interval: 5s"
    echo "      timeout: 3s"
    echo "      retries: 3"
    echo "      start_period: 5s"
  } > docker-compose.yml
}

# Capture currently running image for potential rollback.
PREV_IMAGE=""
if docker compose ps -q app >/dev/null 2>&1; then
  CID="$(docker compose ps -q app || true)"
  if [ -n "$CID" ]; then
    PREV_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$CID" 2>/dev/null || true)"
  fi
fi
echo "Previous image: ${PREV_IMAGE:-<none>}"
echo "Target image:   ${IMAGE}"

write_compose "$IMAGE"

if [ "$SKIP_PULL" != "1" ]; then
  docker compose pull
fi

if docker compose up -d --wait; then
  echo "Deploy succeeded."
  docker image prune -f >/dev/null 2>&1 || true
  exit 0
fi

echo "::error::Deploy health check failed."
if [ -n "$PREV_IMAGE" ] && [ "$PREV_IMAGE" != "$IMAGE" ]; then
  echo "Rolling back to $PREV_IMAGE"
  write_compose "$PREV_IMAGE"
  if docker compose up -d --wait; then
    echo "Rollback succeeded."
  else
    echo "::error::Rollback also failed — manual intervention required."
  fi
else
  echo "No previous image available to roll back to."
fi
exit 1
