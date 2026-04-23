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
#      non-zero exit and leaves nothing healthy — the script must not
#      silently swallow the failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/deploy-with-rollback.sh"
GOOD_IMAGE="rollback-test/good:1"
BAD_IMAGE="rollback-test/bad:1"
PORT="${PORT:-38080}"
WORK_DIR="$(mktemp -d)"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

cleanup() {
  if [ -f "$WORK_DIR/docker-compose.yml" ]; then
    (cd "$WORK_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
  fi
  rm -rf "$WORK_DIR"
  docker rmi -f "$GOOD_IMAGE" "$BAD_IMAGE" >/dev/null 2>&1 || true
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

# Tear down before scenario 3 (we want a truly fresh state with no PREV_IMAGE).
(cd "$WORK_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
rm -f "$WORK_DIR/docker-compose.yml"

# ---------------------------------------------------------------------------
# Scenario 3: first deploy of a bad image (no previous) must fail loudly.
# ---------------------------------------------------------------------------
echo "==> Scenario 3: first deploy of bad image (no previous) — expect failure"
set +e
IMAGE="$BAD_IMAGE" PORT="$PORT" DEPLOY_DIR="$WORK_DIR" SKIP_PULL=1 \
  bash "$SCRIPT"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  fail "bad image first deploy returned 0 — failure was swallowed"
fi
pass "bad image first deploy returned non-zero ($rc)"

echo ""
echo "All rollback integration scenarios passed."
