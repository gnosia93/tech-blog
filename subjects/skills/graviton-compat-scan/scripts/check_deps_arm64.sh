#!/usr/bin/env bash
# check_deps_arm64.sh — resolve whether dependencies actually have arm64 artifacts.
#
# Unlike scan_x86.sh (pure grep, offline), this script queries real registries.
# It answers "does an aarch64 wheel / arm64 image manifest exist for the exact
# version this repo pins?" instead of guessing from a version table.
#
# Usage:  bash check_deps_arm64.sh <repo-path>
#
# Exit:   0  everything resolved for arm64
#         1  at least one dependency has no arm64 artifact
#         2  usage error
#
# Requires network. Skips checks whose tooling is absent and says so.

set -uo pipefail

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: bash check_deps_arm64.sh <repo-path>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

# A wheel tagged manylinux_2_17_aarch64 and one tagged manylinux2014_aarch64 target
# the same platform, but pip matches the tag as a string. Trying only one produces
# false negatives, so every equivalent tag is attempted before declaring failure.
PY_PLATFORMS="manylinux2014_aarch64 manylinux_2_17_aarch64 manylinux_2_28_aarch64 linux_aarch64"
PY_VERSION="${PY_VERSION:-3.11}"
FAILED=0
CHECKED=0
SKIPPED=0

say()  { printf '%s\n' "$*"; }
ok()   { printf '  OK      %s\n' "$*"; }
bad()  { printf '  NO-ARM  %s\n' "$*"; FAILED=$((FAILED+1)); }
skip() { printf '  SKIP    %s\n' "$*"; SKIPPED=$((SKIPPED+1)); }

# ---------------------------------------------------------------------------
# 1. Docker base images — does an arm64 manifest exist?
# ---------------------------------------------------------------------------
say ""
say "=== Docker base images ==="
if ! command -v docker >/dev/null 2>&1; then
  skip "docker not installed"
elif ! docker info >/dev/null 2>&1; then
  skip "docker daemon not running (start Docker Desktop)"
else
  found_image=0
  while IFS= read -r img; do
    [ -n "$img" ] || continue
    found_image=1
    CHECKED=$((CHECKED+1))
    if docker manifest inspect "$img" 2>/dev/null \
         | grep -q '"architecture": *"arm64"'; then
      ok "$img"
    else
      bad "$img  (no arm64 in manifest)"
    fi
  done < <(
    grep -rhIE '^[[:space:]]*FROM[[:space:]]+' \
      --include='Dockerfile*' --include='*.dockerfile' \
      --exclude-dir=.git "$ROOT" 2>/dev/null \
    | sed -E 's/^[[:space:]]*FROM[[:space:]]+//I; s/--platform=[^[:space:]]+[[:space:]]*//; s/[[:space:]]+AS[[:space:]]+.*$//I' \
    | grep -vE '^\$|^scratch$' \
    | sort -u
  )
  [ "$found_image" -eq 1 ] || skip "no Dockerfile FROM lines found"
fi

# ---------------------------------------------------------------------------
# 2. Python dependencies — is there an aarch64 wheel for the pinned version?
# ---------------------------------------------------------------------------
say ""
say "=== Python wheels (aarch64, py${PY_VERSION}) ==="
PIPCMD=""
if command -v pip3 >/dev/null 2>&1; then PIPCMD="pip3"
elif command -v pip >/dev/null 2>&1; then PIPCMD="pip"
fi

if [ -z "$PIPCMD" ]; then
  skip "pip not installed"
else
  found_req=0
  tmpd="$(mktemp -d)"
  trap 'rm -rf "$tmpd"' EXIT
  while IFS= read -r reqfile; do
    [ -n "$reqfile" ] || continue
    found_req=1
    say "  -- ${reqfile#$ROOT/}"
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue
      CHECKED=$((CHECKED+1))
      hit_plat=""
      for plat in $PY_PLATFORMS; do
        if "$PIPCMD" download --no-deps --only-binary=:all: \
             --platform "$plat" --python-version "$PY_VERSION" \
             --dest "$tmpd" "$spec" >/dev/null 2>&1; then
          hit_plat="$plat"
          break
        fi
      done

      if [ -n "$hit_plat" ]; then
        ok "$spec  [$hit_plat]"
        continue
      fi

      # No wheel for the requested Python version. Distinguish "this package has
      # no aarch64 support at all" from "it has aarch64 wheels, but not for
      # py$PY_VERSION" — those need different fixes.
      alt_pv=""
      for pv in 3.13 3.12 3.11 3.10 3.9 3.8; do
        [ "$pv" = "$PY_VERSION" ] && continue
        for plat in $PY_PLATFORMS; do
          if "$PIPCMD" download --no-deps --only-binary=:all: \
               --platform "$plat" --python-version "$pv" \
               --dest "$tmpd" "$spec" >/dev/null 2>&1; then
            alt_pv="$pv"
            break 2
          fi
        done
      done

      if [ -n "$alt_pv" ]; then
        bad "$spec  (aarch64 wheel exists for py$alt_pv but NOT py$PY_VERSION -> bump the package or pin python to $alt_pv)"
      else
        bad "$spec  (no aarch64 wheel on any python -> compiles from source; ensure build deps in image)"
      fi
    done < <(
      grep -vE '^[[:space:]]*(#|-r|--|$)' "$reqfile" 2>/dev/null \
      | sed -E 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' \
      | grep -vE '^\-e|@' \
      | head -40
    )
  done < <(find "$ROOT" -name 'requirements*.txt' -not -path '*/.git/*' \
             -not -path '*/node_modules/*' -not -path '*/.venv/*' -type f 2>/dev/null)
  [ "$found_req" -eq 1 ] || skip "no requirements*.txt found"
fi

# ---------------------------------------------------------------------------
# 3. Node dependencies — does the package publish linux-arm64 prebuilds?
# ---------------------------------------------------------------------------
say ""
say "=== Node native packages ==="
if ! command -v npm >/dev/null 2>&1; then
  skip "npm not installed"
else
  NATIVE_RE='^(sharp|canvas|node-sass|bcrypt|sqlite3|better-sqlite3|grpc|robotjs|zeromq|serialport|usb|libxmljs2?|re2|farmhash|snappy|lz4|blake3|argon2|node-rdkafka|couchbase|oracledb|ibm_db|@tensorflow/tfjs-node)$'
  found_pkg=0
  while IFS= read -r pj; do
    [ -n "$pj" ] || continue
    say "  -- ${pj#$ROOT/}"
    while IFS=$'\t' read -r name range; do
      [ -n "$name" ] || continue
      printf '%s' "$name" | grep -qE "$NATIVE_RE" || continue
      found_pkg=1
      CHECKED=$((CHECKED+1))
      if [ "$name" = "node-sass" ]; then
        bad "node-sass  (no arm64 support, deprecated -> migrate to 'sass')"
        continue
      fi
      # ask the registry for os/cpu metadata and optional prebuild deps
      meta="$(npm view "${name}@${range}" cpu --json 2>/dev/null | tr -d '\n[:space:]')"
      if [ -z "$meta" ] || [ "$meta" = "undefined" ]; then
        # no cpu restriction declared -> not blocked by metadata, still needs a build
        ok "$name@$range  (no cpu restriction; verify prebuild or allow node-gyp)"
      elif printf '%s' "$meta" | grep -q 'arm64'; then
        ok "$name@$range  (declares arm64)"
      else
        bad "$name@$range  (cpu field excludes arm64: $meta)"
      fi
    done < <(
      python3 - "$pj" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for key in ("dependencies", "devDependencies", "optionalDependencies"):
    for k, v in (d.get(key) or {}).items():
        if isinstance(v, str):
            print(f"{k}\t{v}")
PY
    )
  done < <(find "$ROOT" -name package.json -not -path '*/node_modules/*' \
             -not -path '*/.git/*' -type f 2>/dev/null | head -20)
  [ "$found_pkg" -eq 1 ] || skip "no known native packages in package.json"
fi

# ---------------------------------------------------------------------------
say ""
say "---- dependency check summary ------------------------------"
printf 'checked   : %d\n' "$CHECKED"
printf 'no-arm64  : %d\n' "$FAILED"
printf 'skipped   : %d\n' "$SKIPPED"
say "-----------------------------------------------------------"
if [ "$SKIPPED" -gt 0 ]; then
  say "NOTE: skipped checks are unknown, not passing."
fi

[ "$FAILED" -eq 0 ] || exit 1
exit 0
