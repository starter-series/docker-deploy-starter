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
#   PUBLISH_HOST Host address the app port is published on. Defaults to
#                127.0.0.1 so only a same-host reverse proxy (e.g. Caddy, see
#                docs/HTTPS_SETUP.md) can reach the app and the plaintext port
#                is never exposed to the internet. Set to 0.0.0.0 only for
#                setups with no reverse proxy that must serve the port directly.

set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${PORT:?PORT is required}"
: "${DEPLOY_DIR:?DEPLOY_DIR is required}"
ENV_FILE="${ENV_FILE:-}"
SKIP_PULL="${SKIP_PULL:-0}"
PUBLISH_HOST="${PUBLISH_HOST:-127.0.0.1}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "::error::Docker Compose is required (docker compose or docker-compose)." >&2
  exit 1
fi

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
    echo "    environment:"
    echo "      PORT: \"${PORT}\""
    echo "    ports:"
    echo "      - \"${PUBLISH_HOST}:${PORT}:${PORT}\""
    echo "    restart: unless-stopped"
    echo "    read_only: true"
    echo "    tmpfs:"
    echo "      - /tmp"
    echo "    cap_drop:"
    echo "      - ALL"
    echo "    security_opt:"
    echo "      - no-new-privileges:true"
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
if "${COMPOSE[@]}" ps -q app >/dev/null 2>&1; then
  CID="$("${COMPOSE[@]}" ps -q app || true)"
  if [ -n "$CID" ]; then
    PREV_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$CID" 2>/dev/null || true)"
  fi
fi
echo "Previous image: ${PREV_IMAGE:-<none>}"
echo "Target image:   ${IMAGE}"

write_compose "$IMAGE"

if [ "$SKIP_PULL" != "1" ]; then
  "${COMPOSE[@]}" pull
fi

if "${COMPOSE[@]}" up -d --wait; then
  echo "Deploy succeeded."
  docker image prune -f >/dev/null 2>&1 || true
  exit 0
fi

echo "::error::Deploy health check failed."
if [ -n "$PREV_IMAGE" ] && [ "$PREV_IMAGE" != "$IMAGE" ]; then
  echo "Rolling back to $PREV_IMAGE"
  write_compose "$PREV_IMAGE"
  if "${COMPOSE[@]}" up -d --wait; then
    echo "Rollback succeeded."
  else
    # Rollback failed too — tear the broken container down BEFORE moving the
    # compose file (otherwise `docker compose down` has no compose file to act
    # on and would leak the unhealthy container), then remove the broken
    # compose so the next deploy starts from a clean slate (PREV_IMAGE
    # detection on a broken container otherwise loops the cascade). Save a
    # copy for forensics.
    echo "::error::Rollback also failed — clearing compose file. Saved as docker-compose.failed.yml for investigation."
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
    mv docker-compose.yml docker-compose.failed.yml 2>/dev/null || true
  fi
else
  echo "No previous image available to roll back to."
  # First deploy of a bad image — tear the failed container down (BEFORE
  # moving the compose file, so `docker compose down` can find it) so we
  # don't leak an unhealthy container, then move the broken compose aside so
  # we don't carry it into the next attempt.
  "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  mv docker-compose.yml docker-compose.failed.yml 2>/dev/null || true
fi
exit 1
