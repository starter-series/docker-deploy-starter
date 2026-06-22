#!/usr/bin/env bash
set -euo pipefail

CONFIG_ONLY=0
if [ "${1:-}" = "--config-only" ]; then
  CONFIG_ONLY=1
elif [ "${1:-}" != "" ]; then
  echo "Usage: bash scripts/smoke.sh [--config-only]" >&2
  exit 2
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "::error::Docker Compose is required (docker compose or docker-compose)." >&2
  exit 1
fi

created_env=0
if [ ! -f .env ]; then
  if [ ! -f .env.example ]; then
    echo "::error::.env is missing and .env.example was not found." >&2
    exit 1
  fi
  cp .env.example .env
  created_env=1
fi

cleanup() {
  if [ "$created_env" -eq 1 ]; then
    rm -f .env
  fi
}
trap cleanup EXIT

if ! "${COMPOSE[@]}" config --quiet; then
  "${COMPOSE[@]}" config >/dev/null
fi
echo "Compose config smoke passed."

if [ "$CONFIG_ONLY" -eq 1 ]; then
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "::error::Docker daemon is not reachable. Start Docker Desktop, Colima, or your Docker service, then rerun npm run smoke." >&2
  exit 1
fi

docker build -t docker-deploy-starter:smoke .
echo "Docker build smoke passed: docker-deploy-starter:smoke"
