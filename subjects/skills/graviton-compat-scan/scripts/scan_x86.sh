#!/usr/bin/env bash
# scan_x86.sh — deterministic static scan for arm64 / AWS Graviton blockers.
#
# Usage:  bash scan_x86.sh [--strict] [--quiet] <repo-path>
#
# Output: one finding per line, tab-separated:
#           SEVERITY <TAB> RULE <TAB> file:line <TAB> snippet
#
# Exit:   0  no blocking findings
#         1  findings present (FAIL, or VERIFY when --strict)
#         2  usage error
#
# Deterministic by design: pure grep over the working tree, no model judgment,
# no network. Same input always produces the same output, so the result can be
# used as a CI gate and as a learning signal for agentic transformation tools.

set -uo pipefail

STRICT=0
QUIET=0
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  ROOT="$1"; shift ;;
  esac
done

[ -n "$ROOT" ] || { echo "usage: bash scan_x86.sh [--strict] [--quiet] <repo-path>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

N_FAIL=0
N_VERIFY=0
N_INFO=0

EXCLUDE_DIRS=".git node_modules vendor dist build target .venv venv __pycache__ .terraform .mypy_cache .pytest_cache coverage"

# scan_rule <severity> <rule-name> <regex> [include-glob ...]
scan_rule() {
  sev="$1"; rule="$2"; pat="$3"; shift 3

  set -- -rInE --binary-files=without-match "$@"
  args=""
  # build --include args
  includes=""
  for inc in "$@"; do
    case "$inc" in
      -*) ;;                        # already-known flags, skip
      *)  includes="$includes --include=$inc" ;;
    esac
  done

  excl=""
  for d in $EXCLUDE_DIRS; do
    excl="$excl --exclude-dir=$d"
  done

  # shellcheck disable=SC2086
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    loc="${hit%%:*}"
    rest="${hit#*:}"
    lineno="${rest%%:*}"
    snip="${rest#*:}"
    # strip leading whitespace, collapse tabs, truncate
    snip="$(printf '%s' "$snip" | sed 's/^[[:space:]]*//; s/	/ /g' | cut -c1-88)"
    rel="${loc#$ROOT}"
    rel="${rel#/}"
    printf '%s\t%s\t%s:%s\t%s\n' "$sev" "$rule" "$rel" "$lineno" "$snip"
    case "$sev" in
      FAIL)   N_FAIL=$((N_FAIL + 1)) ;;
      VERIFY) N_VERIFY=$((N_VERIFY + 1)) ;;
      INFO)   N_INFO=$((N_INFO + 1)) ;;
    esac
  done < <(grep -rInE --binary-files=without-match $excl $includes -- "$pat" "$ROOT" 2>/dev/null)
}

# scan_file_exists <severity> <rule> <filename-pattern>
scan_file_exists() {
  sev="$1"; rule="$2"; name="$3"
  prune=""
  for d in $EXCLUDE_DIRS; do
    prune="$prune -name $d -prune -o"
  done
  # shellcheck disable=SC2086
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#$ROOT}"; rel="${rel#/}"
    printf '%s\t%s\t%s\t%s\n' "$sev" "$rule" "$rel" "file present"
    case "$sev" in
      FAIL)   N_FAIL=$((N_FAIL + 1)) ;;
      VERIFY) N_VERIFY=$((N_VERIFY + 1)) ;;
      INFO)   N_INFO=$((N_INFO + 1)) ;;
    esac
  done < <(find "$ROOT" $prune -name "$name" -type f -print 2>/dev/null)
}

# ---------------------------------------------------------------------------
# FAIL — will not compile or run on arm64
# ---------------------------------------------------------------------------

# x86 SIMD intrinsic headers
scan_rule FAIL x86-simd-header \
  '#[[:space:]]*include[[:space:]]*<(immintrin|emmintrin|xmmintrin|smmintrin|tmmintrin|nmmintrin|pmmintrin|mmintrin|x86intrin|cpuid)\.h>' \
  '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.m' '*.mm'

# x86 SIMD types and intrinsic calls
scan_rule FAIL x86-simd-intrinsic \
  '(__m(128|256|512)[a-z]*|_mm(256|512)?_[a-z0-9_]+[[:space:]]*\()' \
  '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.rs'

# x86 inline assembly
scan_rule FAIL x86-inline-asm \
  '(__asm__|asm)[[:space:]]*(__volatile__|volatile)?[[:space:]]*\(' \
  '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.rs' '*.go'

# compiler flags that only exist on x86
scan_rule FAIL x86-compiler-flag \
  '\-m(sse[0-9._]*|avx[0-9]*|avx512[a-z]*|mmx|fma|f16c|bmi2?|popcnt)([[:space:]"'"'"']|$)' \
  'Makefile' '*.mk' 'CMakeLists.txt' '*.cmake' 'meson.build' 'setup.py' '*.toml' '*.bazel' 'BUILD'

# Dockerfile pinned to amd64
scan_rule FAIL dockerfile-amd64-pin \
  '\-\-platform[= ]?(linux/)?(amd64|x86_64)' \
  'Dockerfile*' '*.dockerfile' 'docker-compose*.y*ml' '*.yaml' '*.yml'

# base image tag that only ships x86
scan_rule FAIL dockerfile-x86-base-tag \
  '^[[:space:]]*FROM[[:space:]].*(amd64|x86_64)' \
  'Dockerfile*' '*.dockerfile'

# downloading a prebuilt x86 binary
scan_rule FAIL x86-binary-download \
  '(curl|wget|ADD|Invoke-WebRequest)[^\n]*https?://[^[:space:]]*(x86[_-]?64|amd64|linux64|linux-x64|win-x64)' \
  'Dockerfile*' '*.dockerfile' '*.sh' '*.bash' '*.zsh' 'Makefile' '*.mk' '*.yml' '*.yaml' '*.ps1'

# .NET runtime identifier pinned to x64
scan_rule FAIL dotnet-rid-x64 \
  '(RuntimeIdentifiers?|--runtime|-r)[^\n]*(linux-x64|win-x64|osx-x64)' \
  '*.csproj' '*.fsproj' '*.vbproj' '*.props' '*.targets' '*.sh' '*.yml' '*.yaml' 'Dockerfile*'

# committed native binaries (arch-specific, cannot be reused)
scan_file_exists FAIL committed-native-object '*.so'
scan_file_exists FAIL committed-native-object '*.node'

# ---------------------------------------------------------------------------
# VERIFY — architecture-dependent, must be tested on arm64
# ---------------------------------------------------------------------------

# runtime architecture branching
scan_rule VERIFY arch-runtime-branch \
  '(platform\.(machine|processor)\(\)|os\.arch\(\)|runtime\.GOARCH|System\.getProperty\("os\.arch"\)|RuntimeInformation\.ProcessArchitecture|uname[[:space:]]+\-m)' \
  '*.py' '*.js' '*.ts' '*.tsx' '*.jsx' '*.go' '*.java' '*.kt' '*.cs' '*.rb' '*.sh' '*.bash' '*.rs'

# preprocessor / cfg architecture branching
scan_rule VERIFY arch-compile-branch \
  '(defined[[:space:]]*\([[:space:]]*(__x86_64__|__i386__|_M_X64|_M_IX86)|#[[:space:]]*(if|ifdef)[[:space:]]+(__x86_64__|__i386__|__SSE[0-9_]*|__AVX[0-9_]*)|target_arch[[:space:]]*=[[:space:]]*"x86_64")' \
  '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.rs' '*.toml'

# node packages that compile native code
scan_rule VERIFY node-native-dependency \
  '"(sharp|canvas|node-sass|bcrypt|sqlite3|grpc|@grpc/grpc-js|robotjs|node-gyp|better-sqlite3|zeromq|serialport|usb|libxmljs2?|puppeteer|playwright|@tensorflow/tfjs-node|re2|farmhash|snappy|lz4|blake3|argon2|node-rdkafka|couchbase|oracledb|ibm_db)"[[:space:]]*:' \
  'package.json'

# a node-gyp build is present -> native compilation on install
scan_file_exists VERIFY node-gyp-build 'binding.gyp'

# lockfile pinned to an x86 platform
scan_rule VERIFY lockfile-x86-platform \
  '(linux-x64|linux_x86_64|darwin-x64|win32-x64|x86_64-linux|manylinux[0-9_]*_x86_64|musllinux[0-9_]*_x86_64)' \
  'package-lock.json' 'yarn.lock' 'pnpm-lock.yaml' 'poetry.lock' 'Pipfile.lock' 'Gemfile.lock' 'Cargo.lock' 'composer.lock' 'uv.lock'

# python packages whose older releases had no aarch64 wheel
scan_rule VERIFY python-wheel-risk \
  '^[[:space:]]*(grpcio|numpy|scipy|pandas|pyarrow|lxml|psycopg2|psycopg2-binary|cryptography|pillow|opencv-python|confluent-kafka|tensorflow|torch|scikit-learn|h5py|netifaces|python-snappy|ujson|orjson|uwsgi|mysqlclient|cassandra-driver|thrift|pycurl)([=><!~[:space:]]|$)' \
  'requirements*.txt' 'constraints*.txt' 'pyproject.toml' 'setup.py' 'setup.cfg' 'Pipfile' 'environment.y*ml'

# JVM native libs / arch-specific classifiers
scan_rule VERIFY jvm-native-classifier \
  '(linux-x86_64|linux-amd64|natives-linux|jni.*x86|<classifier>linux)' \
  'pom.xml' 'build.gradle' 'build.gradle.kts' '*.sbt'

# ---------------------------------------------------------------------------
# INFO — migration-planning relevant, not a code blocker
# ---------------------------------------------------------------------------

# Terraform / CDK / CFN x86 instance families
scan_rule INFO iac-x86-instance-type \
  '(instance_type|instanceType|InstanceType|instance_class|node_type|CacheNodeType|instanceTypes?)[^\n]*"?(t2|t3|t3a|m4|m5|m5a|m5n|m5zn|m6i|m6a|m7i|c4|c5|c5a|c5n|c6i|c6a|c7i|r4|r5|r5a|r5b|r5n|r6i|r6a|r7i|i3|i4i|z1d|x1|x2i)\.' \
  '*.tf' '*.tfvars' '*.ts' '*.py' '*.json' '*.yaml' '*.yml'

# AMI / image lookups filtered to x86
scan_rule INFO iac-x86-ami-filter \
  '(x86_64|amd64)' \
  '*.tf' '*.tfvars' '*.packer.hcl'

# Lambda with no architecture set (defaults to x86_64)
scan_rule INFO lambda-architecture-unset \
  '(aws_lambda_function|AWS::Serverless::Function|AWS::Lambda::Function|new lambda\.Function|Runtime[[:space:]]*[:=])' \
  '*.tf' 'template.y*ml' 'serverless.y*ml' '*.ts' '*.py'

# CI runners / build images that are x86-only
scan_rule INFO ci-x86-runner \
  '(runs-on:[[:space:]]*(ubuntu|windows|macos)-(latest|[0-9.]+)|image:[[:space:]]*aws/codebuild/(standard|amazonlinux2-x86_64)|LINUX_CONTAINER|BUILD_GENERAL1_(SMALL|MEDIUM|LARGE))' \
  '*.yml' '*.yaml' 'buildspec*.y*ml' '*.tf' '*.ts'

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------

if [ "$QUIET" -eq 0 ]; then
  printf '\n'
  printf -- '---- scan summary ----------------------------------------\n'
  printf 'root      : %s\n' "$ROOT"
  printf 'FAIL      : %d   (blocks arm64 build/run)\n' "$N_FAIL"
  printf 'VERIFY    : %d   (arch-dependent, must test on arm64)\n' "$N_VERIFY"
  printf 'INFO      : %d   (migration planning)\n' "$N_INFO"
  printf -- '----------------------------------------------------------\n'
  printf 'NOTE: a clean scan is not proof of arm64 readiness.\n'
  printf '      Only a passing build+test inside linux/arm64 is evidence.\n'
fi

if [ "$N_FAIL" -gt 0 ]; then
  exit 1
fi
if [ "$STRICT" -eq 1 ] && [ "$N_VERIFY" -gt 0 ]; then
  exit 1
fi
exit 0
