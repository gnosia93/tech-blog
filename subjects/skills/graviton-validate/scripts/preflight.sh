#!/usr/bin/env bash
# preflight.sh — report whether arm64 validation on this host is trustworthy.
#
# Usage:  bash preflight.sh
# Exit:   0 ready (native arm64) · 1 ready but emulated · 2 not ready
#
# The distinction matters: emulated runs validate correctness but produce
# meaningless timings. Anything downstream that reports performance must know
# which mode it ran in.

set -uo pipefail

HOST_ARCH="$(uname -m)"
HOST_OS="$(uname -s)"
MODE="unknown"
READY=0

echo "=== host ==="
printf '  os          : %s\n' "$HOST_OS"
printf '  arch        : %s\n' "$HOST_ARCH"

case "$HOST_ARCH" in
  arm64|aarch64) NATIVE_ARM=1 ;;
  *)             NATIVE_ARM=0 ;;
esac

echo ""
echo "=== container runtime ==="
if ! command -v docker >/dev/null 2>&1; then
  echo "  docker      : NOT INSTALLED"
  READY=2
elif ! docker info >/dev/null 2>&1; then
  echo "  docker      : installed, DAEMON NOT RUNNING"
  echo "                start Docker Desktop, then re-run"
  READY=2
else
  sv="$(docker info --format '{{.ServerVersion}}' 2>/dev/null)"
  da="$(docker info --format '{{.Architecture}}' 2>/dev/null)"
  printf '  docker      : %s (daemon arch: %s)\n' "$sv" "$da"

  if docker buildx version >/dev/null 2>&1; then
    bv="$(docker buildx version 2>/dev/null | awk '{print $2}')"
    printf '  buildx      : %s\n' "$bv"
    plats="$(docker buildx inspect --bootstrap 2>/dev/null \
             | grep -i '^Platforms:' | sed 's/^Platforms:[[:space:]]*//')"
    if [ -n "$plats" ]; then
      printf '  platforms   : %s\n' "$plats"
      if printf '%s' "$plats" | grep -q 'linux/arm64'; then
        echo "  linux/arm64 : SUPPORTED"
      else
        echo "  linux/arm64 : NOT AVAILABLE — install QEMU emulators:"
        echo "                docker run --privileged --rm tonistiigi/binfmt --install arm64"
        READY=2
      fi
    fi
  else
    echo "  buildx      : NOT AVAILABLE (needed for multi-arch builds)"
    READY=2
  fi
fi

echo ""
echo "=== execution mode ==="
if [ "$READY" -eq 2 ]; then
  MODE="unavailable"
  echo "  arm64 containers cannot run on this host yet."
elif [ "$NATIVE_ARM" -eq 1 ]; then
  MODE="native"
  echo "  NATIVE — arm64 containers execute on arm64 hardware."
  echo "  Correctness results are valid."
  echo "  Timings indicate arm64 behaviour but are NOT EC2 Graviton numbers."
else
  MODE="emulated"
  READY=1
  echo "  EMULATED (QEMU) — host is $HOST_ARCH, target is arm64."
  echo "  Correctness results are usable but slow."
  echo "  TIMINGS ARE INVALID. Do not report them as performance data."
fi

echo ""
echo "=== toolchains present ==="
for c in node npm python3 pip3 uv go cargo mvn gradle java make cmake gcc clang; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '  %-8s yes\n' "$c"
  fi
done

echo ""
echo "---- preflight summary ------------------------------------"
printf 'mode  : %s\n' "$MODE"
case "$READY" in
  0) echo 'ready : yes — native arm64' ;;
  1) echo 'ready : yes — emulated (correctness only)' ;;
  2) echo 'ready : NO' ;;
esac
echo "----------------------------------------------------------"
echo "GRAVITON_EXEC_MODE=$MODE"

exit "$READY"
