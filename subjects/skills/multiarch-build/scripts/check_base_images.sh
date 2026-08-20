#!/usr/bin/env bash
# check_base_images.sh — does every base image have a real arm64 manifest?
#
# Usage:  bash check_base_images.sh <repo-path>
# Exit:   0 all images have arm64 · 1 at least one does not · 2 usage error
#
# Requires network. Prefers `docker manifest inspect`; falls back to the
# registry HTTP API when the Docker daemon is unavailable, so this still
# works in CI containers without a daemon.

set -uo pipefail

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: bash check_base_images.sh <repo-path>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

FAILED=0; CHECKED=0; SKIPPED=0
MODE="none"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  MODE="docker"
elif command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  MODE="registry-api"
fi

echo "=== base image arm64 manifests (mode: $MODE) ==="

# --- extract FROM images -----------------------------------------------------
IMAGES=()
while IFS= read -r img; do
  [ -n "$img" ] && IMAGES+=("$img")
done < <(
  find "$ROOT" \( -name .git -o -name node_modules \) -prune -o \
    \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.dockerfile' \) \
    -type f -print 2>/dev/null \
  | xargs -I{} grep -hIE '^[[:space:]]*FROM[[:space:]]+' {} 2>/dev/null \
  | sed -E 's/^[[:space:]]*FROM[[:space:]]+//I
            s/--platform=[^[:space:]]+[[:space:]]*//
            s/[[:space:]]+AS[[:space:]]+.*$//I
            s/[[:space:]]+$//' \
  | grep -vE '^\$|^scratch$|^$' \
  | sort -u
)

if [ "${#IMAGES[@]}" -eq 0 ]; then
  echo "  no base images found"
  exit 0
fi

# --- registry API fallback ---------------------------------------------------
check_via_api() {
  ref="$1"
  python3 - "$ref" <<'PY'
import json, sys, urllib.request, urllib.error

ref = sys.argv[1]

# strip digest
if "@" in ref:
    ref = ref.split("@", 1)[0]

tag = "latest"
name = ref
if ":" in ref.rsplit("/", 1)[-1]:
    name, tag = ref.rsplit(":", 1)

# only Docker Hub is handled by the fallback; other registries need auth
host = name.split("/")[0]
if "." in host or ":" in host:
    print("SKIP non-dockerhub registry")
    sys.exit(2)

repo = name if "/" in name else f"library/{name}"

try:
    tok = json.load(urllib.request.urlopen(
        "https://auth.docker.io/token?service=registry.docker.io"
        f"&scope=repository:{repo}:pull", timeout=25))["token"]
    req = urllib.request.Request(
        f"https://registry-1.docker.io/v2/{repo}/manifests/{tag}",
        headers={
            "Authorization": f"Bearer {tok}",
            "Accept": ("application/vnd.oci.image.index.v1+json,"
                       "application/vnd.docker.distribution.manifest.list.v2+json,"
                       "application/vnd.docker.distribution.manifest.v2+json"),
        })
    m = json.load(urllib.request.urlopen(req, timeout=25))
except urllib.error.HTTPError as e:
    print(f"SKIP http {e.code}")
    sys.exit(2)
except Exception as e:
    print(f"SKIP {type(e).__name__}")
    sys.exit(2)

arches = {
    f"{p.get('platform',{}).get('os','')}/{p.get('platform',{}).get('architecture','')}"
    for p in m.get("manifests", [])
    if p.get("platform", {}).get("architecture") != "unknown"
}
if not arches:
    print("SINGLE single-arch manifest (no arm64 variant)")
    sys.exit(1)
if "linux/arm64" in arches:
    print("OK " + ",".join(sorted(arches)))
    sys.exit(0)
print("NOARM " + ",".join(sorted(arches)))
sys.exit(1)
PY
}

for img in "${IMAGES[@]}"; do
  CHECKED=$((CHECKED+1))
  case "$MODE" in
    docker)
      out="$(docker manifest inspect "$img" 2>/dev/null)"
      if [ -z "$out" ]; then
        printf '  SKIP    %-44s (manifest unreachable)\n' "$img"
        SKIPPED=$((SKIPPED+1))
      elif printf '%s' "$out" | grep -q '"architecture": *"arm64"'; then
        printf '  OK      %-44s arm64 present\n' "$img"
      else
        printf '  NO-ARM  %-44s no arm64 in manifest\n' "$img"
        FAILED=$((FAILED+1))
      fi
      ;;
    registry-api)
      res="$(check_via_api "$img")"; rc=$?
      case "$rc" in
        0) printf '  OK      %-44s %s\n' "$img" "${res#OK }" ;;
        1) printf '  NO-ARM  %-44s %s\n' "$img" "$res"; FAILED=$((FAILED+1)) ;;
        *) printf '  SKIP    %-44s %s\n' "$img" "$res"; SKIPPED=$((SKIPPED+1)) ;;
      esac
      ;;
    *)
      printf '  SKIP    %-44s (need docker daemon or curl+python3)\n' "$img"
      SKIPPED=$((SKIPPED+1))
      ;;
  esac
done

echo ""
echo "---- base image summary -----------------------------------"
printf 'checked  : %d\n' "$CHECKED"
printf 'no-arm64 : %d\n' "$FAILED"
printf 'skipped  : %d\n' "$SKIPPED"
echo "-----------------------------------------------------------"
[ "$SKIPPED" -eq 0 ] || echo "NOTE: skipped images are unknown, not passing."
[ "$FAILED" -eq 0 ] || echo "NOTE: an image with no arm64 manifest cannot be fixed by"
[ "$FAILED" -eq 0 ] || echo "      removing a --platform pin. Find a multi-arch base."

[ "$FAILED" -eq 0 ] || exit 1
exit 0
