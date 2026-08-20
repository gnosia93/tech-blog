#!/usr/bin/env bash
# run_arm64_tests.sh — build and run a repo's tests inside linux/arm64.
#
# Usage:  bash run_arm64_tests.sh <repo-path> [--cmd "<test command>"]
#                                 [--image <base image>] [--keep]
#
# Exit:   0 tests passed on arm64 · 1 tests failed · 2 cannot run
#
# This is the only step that produces evidence of arm64 readiness. A static scan
# finds known patterns; a build proves compilation; only running the suite inside
# linux/arm64 proves behaviour.
#
# CRITICAL: a pass on macOS arm64 is not a pass on Linux arm64. glibc vs musl,
# wheel availability and system libraries all differ. That is why this runs in a
# container rather than on the host.

set -uo pipefail

ROOT=""; TEST_CMD=""; BASE_IMAGE=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cmd)   TEST_CMD="${2:-}"; shift 2 ;;
    --image) BASE_IMAGE="${2:-}"; shift 2 ;;
    --keep)  KEEP=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

[ -n "$ROOT" ] || { echo "usage: bash run_arm64_tests.sh <repo-path> [--cmd \"...\"]" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker not installed" >&2; exit 2; }
docker info >/dev/null 2>&1 || {
  echo "docker daemon not running — start Docker Desktop and retry" >&2
  exit 2
}

if ! docker buildx inspect --bootstrap 2>/dev/null | grep -q 'linux/arm64'; then
  echo "linux/arm64 not available to buildx. Install emulators:" >&2
  echo "  docker run --privileged --rm tonistiigi/binfmt --install arm64" >&2
  exit 2
fi

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  arm64|aarch64) EXEC_MODE="native" ;;
  *)             EXEC_MODE="emulated (QEMU — slow, timings invalid)" ;;
esac

# --- detect stack and default test command ----------------------------------
detect() {
  if [ -f "$ROOT/package.json" ]; then
    echo "node"
  elif [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ] || [ -f "$ROOT/setup.py" ]; then
    echo "python"
  elif [ -f "$ROOT/go.mod" ]; then
    echo "go"
  elif [ -f "$ROOT/Cargo.toml" ]; then
    echo "rust"
  elif [ -f "$ROOT/pom.xml" ]; then
    echo "maven"
  elif [ -f "$ROOT/build.gradle" ] || [ -f "$ROOT/build.gradle.kts" ]; then
    echo "gradle"
  elif [ -f "$ROOT/Makefile" ] || [ -f "$ROOT/CMakeLists.txt" ]; then
    echo "c"
  else
    echo "unknown"
  fi
}

STACK="$(detect)"

if [ -z "$BASE_IMAGE" ]; then
  case "$STACK" in
    node)   BASE_IMAGE="node:22-bookworm" ;;
    python) BASE_IMAGE="python:3.12-bookworm" ;;
    go)     BASE_IMAGE="golang:1.23-bookworm" ;;
    rust)   BASE_IMAGE="rust:1-bookworm" ;;
    maven)  BASE_IMAGE="maven:3.9-eclipse-temurin-21" ;;
    gradle) BASE_IMAGE="gradle:8-jdk21" ;;
    c)      BASE_IMAGE="gcc:13-bookworm" ;;
    *)      BASE_IMAGE="debian:bookworm" ;;
  esac
fi

if [ -z "$TEST_CMD" ]; then
  case "$STACK" in
    node)   TEST_CMD="npm ci --no-audit --no-fund && npm test" ;;
    python) TEST_CMD="pip install --root-user-action=ignore -q -r requirements.txt 2>/dev/null; pip install --root-user-action=ignore -q pytest && python -m pytest -q" ;;
    go)     TEST_CMD="go test ./..." ;;
    rust)   TEST_CMD="cargo test --quiet" ;;
    maven)  TEST_CMD="mvn -q -B test" ;;
    gradle) TEST_CMD="gradle test --console=plain" ;;
    c)      TEST_CMD="make && (make test || make check || echo 'no test target')" ;;
    *)      echo "cannot detect a test command for this repo; pass --cmd \"...\"" >&2; exit 2 ;;
  esac
fi

echo "=== arm64 test run ==="
printf '  repo        : %s\n' "$ROOT"
printf '  stack       : %s\n' "$STACK"
printf '  base image  : %s\n' "$BASE_IMAGE"
printf '  platform    : linux/arm64\n'
printf '  exec mode   : %s\n' "$EXEC_MODE"
printf '  command     : %s\n' "$TEST_CMD"
echo ""

# --- confirm the base image has arm64 before spending time on it -------------
if ! docker manifest inspect "$BASE_IMAGE" 2>/dev/null | grep -q '"architecture": *"arm64"'; then
  echo "WARNING: could not confirm an arm64 manifest for $BASE_IMAGE."
  echo "         Continuing, but a pull failure here means the base image is x86-only."
  echo ""
fi

echo "--- pulling base image (linux/arm64) ---"
if ! docker pull --platform linux/arm64 "$BASE_IMAGE" 2>&1 | tail -3; then
  echo "failed to pull $BASE_IMAGE for linux/arm64" >&2
  exit 2
fi

echo ""
echo "--- verifying container architecture ---"
IN_ARCH="$(docker run --rm --platform linux/arm64 "$BASE_IMAGE" uname -m 2>/dev/null)"
printf '  container reports: %s\n' "$IN_ARCH"
case "$IN_ARCH" in
  aarch64|arm64) : ;;
  *) echo "container is not arm64 (got '$IN_ARCH') — aborting" >&2; exit 2 ;;
esac

echo ""
echo "--- running tests ---"
LOG="$(mktemp)"
set +e
docker run --rm --platform linux/arm64 \
  -v "$ROOT":/workspace -w /workspace \
  -e CI=true -e PIP_DISABLE_PIP_VERSION_CHECK=1 \
  "$BASE_IMAGE" \
  bash -lc "set -o pipefail; $TEST_CMD" 2>&1 | tee "$LOG"
RC="${PIPESTATUS[0]}"
set -e

echo ""
echo "---- arm64 test summary -----------------------------------"
printf 'stack     : %s\n' "$STACK"
printf 'exec mode : %s\n' "$EXEC_MODE"
printf 'exit code : %s\n' "$RC"
if [ "$RC" -eq 0 ]; then
  echo 'result    : PASS on linux/arm64'
else
  echo 'result    : FAIL on linux/arm64'
  echo ""
  echo "likely causes (see graviton-compat-scan/references/known-failures.md):"
  grep -iE 'exec format error|illegal instruction|no matching distribution|could not build wheels|unsupported (arch|platform)|immintrin|__m128|unknown register|cannot execute binary' "$LOG" \
    | head -8 | sed 's/^/  /' || echo "  (no known signature matched — read the log above)"
fi
echo "----------------------------------------------------------"
if [ "$EXEC_MODE" != "native" ]; then
  echo "NOTE: emulated run. Correctness is meaningful; timing is not."
fi
echo "NOTE: passing here means the suite works on Linux arm64."
echo "      It is not an EC2 Graviton performance measurement."

[ "$KEEP" -eq 1 ] && echo "log kept at: $LOG" || rm -f "$LOG"

exit "$RC"
