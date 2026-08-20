#!/usr/bin/env bash
# benchmark.sh — measure a workload on linux/amd64 vs linux/arm64.
#
# Usage:  bash benchmark.sh <repo-path> --cmd "<workload>" [--runs 5]
#                           [--image <base image>] [--arm-only]
#
# Exit:   0 completed · 2 cannot run
#
# CRITICAL: this measures containers on THIS host, not EC2 instances. On an
# arm64 host the amd64 side runs under QEMU and its timing is meaningless; on an
# x86 host the reverse. A defensible price-performance number requires the same
# workload on comparable x86 and Graviton EC2 instances under production-like
# load. This script exists to catch order-of-magnitude regressions early, not to
# produce a figure for a proposal.

set -uo pipefail

ROOT=""; CMD=""; RUNS=5; BASE_IMAGE="debian:bookworm"; ARM_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cmd)      CMD="${2:-}"; shift 2 ;;
    --runs)     RUNS="${2:-5}"; shift 2 ;;
    --image)    BASE_IMAGE="${2:-}"; shift 2 ;;
    --arm-only) ARM_ONLY=1; shift ;;
    -h|--help)  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

[ -n "$ROOT" ] && [ -n "$CMD" ] || {
  echo 'usage: bash benchmark.sh <repo-path> --cmd "<workload>" [--runs 5]' >&2
  exit 2
}
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || {
  echo "docker daemon not available — cannot benchmark" >&2
  exit 2
}

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  arm64|aarch64) NATIVE="linux/arm64"; EMULATED="linux/amd64" ;;
  *)             NATIVE="linux/amd64"; EMULATED="linux/arm64" ;;
esac

echo "=== benchmark ==="
printf '  repo     : %s\n' "$ROOT"
printf '  image    : %s\n' "$BASE_IMAGE"
printf '  command  : %s\n' "$CMD"
printf '  runs     : %s\n' "$RUNS"
printf '  host     : %s  (native: %s, emulated: %s)\n' "$HOST_ARCH" "$NATIVE" "$EMULATED"
echo ""

# median of N runs, in milliseconds, via the shell's own clock inside the container
time_platform() {
  plat="$1"
  times=""
  for i in $(seq 1 "$RUNS"); do
    ms="$(docker run --rm --platform "$plat" \
            -v "$ROOT":/workspace -w /workspace "$BASE_IMAGE" \
            bash -lc "s=\$(date +%s%N); $CMD >/dev/null 2>&1; e=\$(date +%s%N); echo \$(( (e-s)/1000000 ))" \
            2>/dev/null | tail -1)"
    case "$ms" in
      ''|*[!0-9]*) printf '    run %s: FAILED\n' "$i" >&2; continue ;;
    esac
    printf '    run %s: %s ms\n' "$i" "$ms" >&2
    times="$times $ms"
  done
  # median
  printf '%s\n' $times | sort -n | awk '{a[NR]=$1} END {
    if (NR==0) { print "" }
    else if (NR%2) { print a[(NR+1)/2] }
    else { print int((a[NR/2]+a[NR/2+1])/2) }
  }'
}

echo "--- linux/arm64 ---"
ARM_MS="$(time_platform linux/arm64)"
[ -n "$ARM_MS" ] && printf '  median: %s ms\n' "$ARM_MS" || echo "  all runs failed"

AMD_MS=""
if [ "$ARM_ONLY" -eq 0 ]; then
  echo ""
  echo "--- linux/amd64 ---"
  AMD_MS="$(time_platform linux/amd64)"
  [ -n "$AMD_MS" ] && printf '  median: %s ms\n' "$AMD_MS" || echo "  all runs failed"
fi

echo ""
echo "---- benchmark summary ------------------------------------"
[ -n "$AMD_MS" ] && printf 'linux/amd64 median : %s ms%s\n' "$AMD_MS" \
  "$([ "$EMULATED" = "linux/amd64" ] && echo '   <-- EMULATED, INVALID')"
[ -n "$ARM_MS" ] && printf 'linux/arm64 median : %s ms%s\n' "$ARM_MS" \
  "$([ "$EMULATED" = "linux/arm64" ] && echo '   <-- EMULATED, INVALID')"

if [ -n "$AMD_MS" ] && [ -n "$ARM_MS" ] && [ "$AMD_MS" -gt 0 ]; then
  delta="$(awk -v a="$AMD_MS" -v b="$ARM_MS" 'BEGIN{printf "%.1f", (a-b)/a*100}')"
  printf 'raw delta          : %s%% (positive = arm64 faster)\n' "$delta"
fi
echo "----------------------------------------------------------"
echo "CRITICAL: one side of this comparison ran under QEMU emulation, so the"
echo "          delta above is NOT a Graviton price-performance figure."
echo ""
echo "For a defensible number:"
echo "  1. Launch comparable instances, e.g. m7i.xlarge (x86) and m7g.xlarge (Graviton)"
echo "  2. Run the same workload with production-like load and data"
echo "  3. Compare throughput or p99 latency per hour of on-demand cost"
echo "  4. Report the measured figure, not the marketing number"

exit 0
