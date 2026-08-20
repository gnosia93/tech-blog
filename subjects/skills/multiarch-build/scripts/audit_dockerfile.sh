#!/usr/bin/env bash
# audit_dockerfile.sh — deterministic audit of Dockerfiles for arm64 readiness.
#
# Usage:  bash audit_dockerfile.sh [--quiet] <repo-path>
#
# Output: SEVERITY <TAB> RULE <TAB> file:line <TAB> snippet
# Exit:   0 clean · 1 findings · 2 usage error
#
# Offline and deterministic: grep only, no registry calls, no model judgment.
# Use check_base_images.sh for the network-dependent manifest check.

set -uo pipefail

QUIET=0
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

[ -n "$ROOT" ] || { echo "usage: bash audit_dockerfile.sh [--quiet] <repo-path>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

N_FAIL=0; N_WARN=0; N_INFO=0

emit() {
  sev="$1"; rule="$2"; loc="$3"; snip="$4"
  snip="$(printf '%s' "$snip" | sed 's/^[[:space:]]*//; s/	/ /g' | cut -c1-84)"
  printf '%s\t%s\t%s\t%s\n' "$sev" "$rule" "$loc" "$snip"
  case "$sev" in
    FAIL) N_FAIL=$((N_FAIL+1)) ;;
    WARN) N_WARN=$((N_WARN+1)) ;;
    INFO) N_INFO=$((N_INFO+1)) ;;
  esac
}

# collect Dockerfiles
DOCKERFILES=()
while IFS= read -r f; do
  [ -n "$f" ] && DOCKERFILES+=("$f")
done < <(find "$ROOT" \
           \( -name .git -o -name node_modules -o -name vendor \) -prune -o \
           \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.dockerfile' \) \
           -type f -print 2>/dev/null | sort)

if [ "${#DOCKERFILES[@]}" -eq 0 ]; then
  [ "$QUIET" -eq 1 ] || echo "no Dockerfiles found under $ROOT"
  exit 0
fi

for df in "${DOCKERFILES[@]}"; do
  rel="${df#$ROOT}"; rel="${rel#/}"
  lineno=0
  has_targetarch_arg=0
  # pre-scan for ARG TARGETARCH so ordering does not matter
  if grep -qiE '^[[:space:]]*ARG[[:space:]]+TARGETARCH' "$df" 2>/dev/null; then
    has_targetarch_arg=1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    case "$line" in \#*) continue ;; esac

    # --- FAIL: platform pinned to amd64 on any stage
    if printf '%s' "$line" | grep -qiE -- '--platform[= ]?(linux/)?(amd64|x86_64)'; then
      emit FAIL platform-pinned-amd64 "$rel:$lineno" "$line"
    fi

    # --- FAIL: FROM tag carrying an x86 arch marker
    # The --platform flag is stripped first, otherwise "--platform=linux/amd64"
    # double-reports as both platform-pinned-amd64 and from-tag-x86.
    if printf '%s' "$line" | grep -qiE '^[[:space:]]*FROM[[:space:]]'; then
      from_ref="$(printf '%s' "$line" \
        | sed -E 's/^[[:space:]]*FROM[[:space:]]+//I; s/--platform=[^[:space:]]+[[:space:]]*//')"
      if printf '%s' "$from_ref" | grep -qiE '(amd64|x86_64|x86-64)'; then
        emit FAIL from-tag-x86 "$rel:$lineno" "$line"
      fi
    fi

    # --- FAIL: fetching an arch-specific binary without TARGETARCH dispatch
    if printf '%s' "$line" | grep -qiE '(curl|wget|ADD[[:space:]]+http|Invoke-WebRequest)' \
       && printf '%s' "$line" | grep -qiE '(x86[_-]?64|amd64|linux-?64|linux-x64|win-x64|darwin-x64)'; then
      if printf '%s' "$line" | grep -q 'TARGETARCH'; then
        emit INFO binary-download-parameterized "$rel:$lineno" "$line"
      else
        emit FAIL binary-download-hardcoded-x86 "$rel:$lineno" "$line"
      fi
    fi

    # --- FAIL: pip/npm install forcing an x86 platform
    if printf '%s' "$line" | grep -qiE 'pip[0-9]?[[:space:]]+install' \
       && printf '%s' "$line" | grep -qiE -- '--platform[= ][^[:space:]]*(x86_64|amd64)'; then
      emit FAIL pip-platform-x86 "$rel:$lineno" "$line"
    fi

    # --- WARN: .NET / Go / Rust target pinned to x64
    if printf '%s' "$line" | grep -qiE '(dotnet[[:space:]]+(publish|build)[^\n]*(linux-x64|win-x64)|GOARCH=amd64|--target[= ]x86_64-)'; then
      emit WARN build-target-x64 "$rel:$lineno" "$line"
    fi

    # --- WARN: TARGETARCH used but never declared as ARG
    if printf '%s' "$line" | grep -q '\$TARGETARCH' && [ "$has_targetarch_arg" -eq 0 ]; then
      emit WARN targetarch-not-declared "$rel:$lineno" "$line"
      has_targetarch_arg=2   # report once per file
    fi

    # --- WARN: case dispatch on TARGETARCH with no failing default branch
    # Dockerfile RUN blocks are continued with trailing backslashes, so the
    # default branch is usually on a later physical line than the `case`.
    # The whole file is joined before matching, otherwise a correct
    # `*) exit 1 ;;` two lines down reads as missing.
    if printf '%s' "$line" | grep -qE 'case[[:space:]]+"?\$\{?TARGETARCH'; then
      if ! sed -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}' "$df" 2>/dev/null \
           | grep -qE '\*\).*exit[[:space:]]+[1-9]'; then
        emit WARN targetarch-no-fail-branch "$rel:$lineno" "$line"
      fi
    fi

    # --- INFO: multi-arch aware constructs already present (good signal)
    if printf '%s' "$line" | grep -qE -- '--platform=\$(BUILDPLATFORM|TARGETPLATFORM)'; then
      emit INFO platform-parameterized "$rel:$lineno" "$line"
    fi
  done < "$df"
done

if [ "$QUIET" -eq 0 ]; then
  printf '\n'
  printf -- '---- dockerfile audit -------------------------------------\n'
  printf 'dockerfiles : %d\n' "${#DOCKERFILES[@]}"
  printf 'FAIL        : %d   (breaks arm64)\n' "$N_FAIL"
  printf 'WARN        : %d   (review required)\n' "$N_WARN"
  printf 'INFO        : %d   (already parameterized)\n' "$N_INFO"
  printf -- '----------------------------------------------------------\n'
  printf 'NOTE: a passing audit does not prove the image runs on arm64.\n'
  printf '      Build for linux/arm64 and run a smoke command.\n'
fi

[ "$N_FAIL" -eq 0 ] || exit 1
exit 0
