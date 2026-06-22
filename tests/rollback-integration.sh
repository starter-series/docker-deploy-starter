#!/usr/bin/env bash
# Integration test for scripts/deploy-with-rollback.sh.
#
# Runs entirely on the CI runner using local `docker compose` — no SSH, no
# registry. Builds two local images (good, bad) and exercises the full
# deploy flow the CD workflow uses in production.
#
# Scenarios covered:
#   1. First deploy of the good image succeeds.
#   2. Attempting to deploy the bad image over the good one fails AND
#      rollback restores the good image. After the attempt, /health must
#      still return 200 from the good image.
#   3. First deploy of a bad image (no previous image) fails with a
#      non-zero exit and leaves the system quiesced: docker-compose.yml is
#      gone, docker-compose.failed.yml is preserved for forensics, and no
#      container is left running. The script must not silently swallow the
#      failure nor leak an unhealthy container.
#   4. Both images unhealthy: a previous (unhealthy) container exists and the
#      new deploy is also unhealthy, so rollback to the previous fails too.
#      The script must end with the system quiesced (compose moved aside, no
#      container running) rather than cascading or leaking containers.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/deploy-with-rollback.sh"
GOOD_IMAGE="rollback-test/good:1"
BAD_IMAGE="rollback-test/bad:1"
PORT="${PORT:-38080}"
WORK_DIR="$(mktemp -d)"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  fail "Docker Compose is required (docker compose or docker-compose)"
fi

cleanup() {
  if [ -f "$WORK_DIR/docker-compose.yml" ]; then
    (cd "$WORK_DIR" && "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true)
  fi
  if [ -f "$WORK_DIR/docker-compose.failed.yml" ]; then
    (cd "$WORK_DIR" && "${COMPOSE[@]}" -f docker-compose.failed.yml down -v --remove-orphans >/dev/null 2>&1 || true)
  fi
  rm -rf "$WORK_DIR"
  docker rmi -f "$GOOD_IMAGE" "$BAD_IMAGE" "rollback-test/bad:prev" >/dev/null 2>&1 || true
}
trap cleanup EXIT

check_health() {
  local expected_build="$1"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    body="$(curl -sf "http://127.0.0.1:${PORT}/health" 2>/dev/null || true)"
    if echo "$body" | grep -q "\"build\":\"${expected_build}\""; then
      return 0
    fi
    sleep 1
  done
  echo "health check did not return build=${expected_build} (last body: ${body:-<empty>})" >&2
  return 1
}

# Count app containers still tracked by either the live or the failed compose
# file in WORK_DIR. After a failed deploy with no successful rollback, this
# must be zero (the script is responsible for tearing the container down).
running_app_containers() {
  local count=0 ids
  if [ -f "$WORK_DIR/docker-compose.yml" ]; then
    ids="$(cd "$WORK_DIR" && "${COMPOSE[@]}" ps -q app 2>/dev/null || true)"
    [ -n "$ids" ] && count=$((count + $(echo "$ids" | grep -c .)))
  fi
  if [ -f "$WORK_DIR/docker-compose.failed.yml" ]; then
    ids="$(cd "$WORK_DIR" && "${COMPOSE[@]}" -f docker-compose.failed.yml ps -q app 2>/dev/null || true)"
    [ -n "$ids" ] && count=$((count + $(echo "$ids" | grep -c .)))
  fi
  echo "$count"
}

assert_compose_hardened() {
  local label="$1"
  grep -q '^    read_only: true$' "$WORK_DIR/docker-compose.yml" \
    || fail "$label: compose missing read_only hardening"
  grep -q '^      - /tmp$' "$WORK_DIR/docker-compose.yml" \
    || fail "$label: compose missing tmpfs /tmp"
  grep -q '^      - ALL$' "$WORK_DIR/docker-compose.yml" \
    || fail "$label: compose missing cap_drop ALL"
  grep -q '^      - no-new-privileges:true$' "$WORK_DIR/docker-compose.yml" \
    || fail "$label: compose missing no-new-privileges"
  pass "$label: compose includes hardening defaults"
}

# Assert the deployment is fully quiesced after a terminal failure:
#   - docker-compose.yml has been moved aside (gone)
#   - docker-compose.failed.yml is preserved for forensics
#   - nothing the deploy created is still running
#   - nothing answers /health on the port
assert_quiesced() {
  local label="$1"
  [ ! -f "$WORK_DIR/docker-compose.yml" ] \
    || fail "$label: docker-compose.yml should be gone (moved to .failed.yml)"
  [ -f "$WORK_DIR/docker-compose.failed.yml" ] \
    || fail "$label: docker-compose.failed.yml should be preserved for forensics"
  local n
  n="$(running_app_containers)"
  [ "$n" -eq 0 ] \
    || fail "$label: expected no running app containers, found $n"
  if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    fail "$label: something is still serving /health on port ${PORT}"
  fi
  pass "$label: system quiesced (no compose, .failed.yml saved, nothing running)"
}

echo "==> Building fixture images"
docker build -t "$GOOD_IMAGE" "$REPO_ROOT/tests/fixtures/good-app" >/dev/null
docker build -t "$BAD_IMAGE" "$REPO_ROOT/tests/fixtures/bad-app" >/dev/null

# ---------------------------------------------------------------------------
# Scenario 1: first deploy of the good image must succeed.
# ---------------------------------------------------------------------------
echo "==> Scenario 1: deploy good image (first deploy)"
if IMAGE="$GOOD_IMAGE" PORT="$PORT" DEPLOY_DIR="$WORK_DIR" SKIP_PULL=1 \
     bash "$SCRIPT"; then
  pass "good image deploy returned 0"
else
  fail "good image deploy returned non-zero"
fi
check_health good || fail "good image not serving /health"
pass "good image /health responds with build=good"
assert_compose_hardened "scenario 1"

# ---------------------------------------------------------------------------
# Scenario 2: deploying the bad image on top must fail AND rollback must
# restore the good image.
# ---------------------------------------------------------------------------
echo "==> Scenario 2: deploy bad image, expect rollback to good"
set +e
IMAGE="$BAD_IMAGE" PORT="$PORT" DEPLOY_DIR="$WORK_DIR" SKIP_PULL=1 \
  bash "$SCRIPT"
deploy_rc=$?
set -e
if [ "$deploy_rc" -eq 0 ]; then
  fail "bad image deploy returned 0 — rollback script failed to detect failure"
fi
pass "bad image deploy returned non-zero ($deploy_rc)"

# After rollback, /health must still respond build=good.
check_health good || fail "rollback did not restore the good image"
pass "rollback restored good image — /health still serves build=good"

# The compose file on disk should now point back at the good image.
if grep -q "image: $GOOD_IMAGE" "$WORK_DIR/docker-compose.yml"; then
  pass "compose file was rewritten to the good image after rollback"
else
  fail "compose file does not point to good image after rollback"
fi
assert_compose_hardened "scenario 2"

# Tear down before scenario 3 (we want a truly fresh state with no PREV_IMAGE).
(cd "$WORK_DIR" && "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true)
rm -f "$WORK_DIR/docker-compose.yml"

# ---------------------------------------------------------------------------
# Scenario 3: first deploy of a bad image (no previous) must fail loudly AND
# leave the system quiesced.
# ---------------------------------------------------------------------------
echo "==> Scenario 3: first deploy of bad image (no previous) — expect failure + quiesce"
set +e
IMAGE="$BAD_IMAGE" PORT="$PORT" DEPLOY_DIR="$WORK_DIR" SKIP_PULL=1 \
  bash "$SCRIPT"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  fail "bad image first deploy returned 0 — failure was swallowed"
fi
pass "bad image first deploy returned non-zero ($rc)"

# The failed first deploy must have moved the compose aside, kept the
# forensic copy, and left nothing running.
assert_quiesced "scenario 3"

# Fresh state before scenario 4.
(cd "$WORK_DIR" && "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true)
if [ -f "$WORK_DIR/docker-compose.failed.yml" ]; then
  (cd "$WORK_DIR" && "${COMPOSE[@]}" -f docker-compose.failed.yml down -v --remove-orphans >/dev/null 2>&1 || true)
fi
rm -f "$WORK_DIR/docker-compose.yml" "$WORK_DIR/docker-compose.failed.yml"

# ---------------------------------------------------------------------------
# Scenario 4: both images unhealthy. A previous (unhealthy) container is
# already running and tracked by a compose file, then a new bad deploy is
# attempted. Rollback targets the previous image, which is ALSO unhealthy, so
# rollback fails too. The script must end with the system quiesced — not
# cascading restarts, not leaking the unhealthy container.
# ---------------------------------------------------------------------------
echo "==> Scenario 4: both images unhealthy — expect failure + quiesce"

# Pre-seed a running-but-unhealthy "previous" container so PREV_IMAGE
# detection finds a bad image to (fail to) roll back to. We bring it up
# WITHOUT --wait so the unhealthy container stays running and is recorded in a
# compose file the deploy script will discover.
BAD_PREV_IMAGE="rollback-test/bad:prev"
docker tag "$BAD_IMAGE" "$BAD_PREV_IMAGE" >/dev/null 2>&1
cat > "$WORK_DIR/docker-compose.yml" <<EOF
services:
  app:
    image: $BAD_PREV_IMAGE
    environment:
      PORT: "${PORT}"
    ports:
      - "${PORT}:${PORT}"
    restart: "no"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO /dev/null http://localhost:${PORT}/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
EOF
(cd "$WORK_DIR" && "${COMPOSE[@]}" up -d >/dev/null 2>&1)
# Sanity: a previous container is actually running before we attempt the deploy.
prev_running="$(running_app_containers)"
[ "$prev_running" -ge 1 ] || fail "scenario 4 setup: previous unhealthy container is not running"
pass "scenario 4 setup: previous unhealthy container is running (PREV will be detected)"

set +e
IMAGE="$BAD_IMAGE" PORT="$PORT" DEPLOY_DIR="$WORK_DIR" SKIP_PULL=1 \
  bash "$SCRIPT"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  fail "both-unhealthy deploy returned 0 — failure was swallowed"
fi
pass "both-unhealthy deploy returned non-zero ($rc)"

# Even though rollback was attempted and also failed, the system must be
# quiesced: compose moved aside, forensic copy kept, nothing running.
assert_quiesced "scenario 4"

docker rmi -f "$BAD_PREV_IMAGE" >/dev/null 2>&1 || true

echo ""
echo "All rollback integration scenarios passed."
