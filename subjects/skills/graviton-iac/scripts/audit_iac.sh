#!/usr/bin/env bash
# audit_iac.sh — inventory x86 pins in IaC and print the Graviton mapping.
#
# Usage:  bash audit_iac.sh [--quiet] <repo-path>
#
# Output: CATEGORY <TAB> file:line <TAB> current -> suggested <TAB> snippet
# Exit:   0 nothing to change · 1 changes needed · 2 usage error
#
# Deterministic: grep + a fixed mapping table. No network, no model judgment.
# Region availability is NOT checked here — use verify_availability.sh.

set -uo pipefail

QUIET=0; ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
[ -n "$ROOT" ] || { echo "usage: bash audit_iac.sh [--quiet] <repo-path>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

N_INST=0; N_AMI=0; N_LAMBDA=0; N_EKS=0; N_ECS=0; N_CI=0

EXCL="--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.terraform --exclude-dir=vendor --exclude-dir=dist"

# graviton_for <family> -> arm64 family, or empty if none exists
graviton_for() {
  case "$1" in
    t2|t3|t3a)          echo "t4g" ;;
    m4|m5|m5a|m5n|m5zn) echo "m7g" ;;
    m6i|m6a|m7i|m7a)    echo "m7g" ;;
    c4|c5|c5a|c5n)      echo "c7g" ;;
    c6i|c6a|c7i|c7a)    echo "c7g" ;;
    r4|r5|r5a|r5b|r5n)  echo "r7g" ;;
    r6i|r6a|r7i|r7a)    echo "r7g" ;;
    i3|i3en)            echo "im4gn" ;;
    i4i)                echo "i4g" ;;
    x1|x1e|x2i|x2idn)   echo "x2gd" ;;
    z1d)                echo "" ;;   # no Graviton counterpart (high clock)
    p2|p3|p4|p5|g4|g5|g6|inf1|inf2|trn1|dl1|f1|vt1) echo "" ;;  # accelerator
    *)                  echo "" ;;
  esac
}

suggest_type() {
  full="$1"                       # e.g. m5.2xlarge  |  db.r5.large  |  cache.m5.large
  prefix=""; rest="$full"
  case "$full" in
    db.*)    prefix="db.";    rest="${full#db.} " ;;
    cache.*) prefix="cache."; rest="${full#cache.} " ;;
  esac
  rest="${rest% }"
  fam="${rest%%.*}"; size="${rest#*.}"
  g="$(graviton_for "$fam")"
  if [ -z "$g" ]; then
    echo "NO-GRAVITON-EQUIVALENT"
    return
  fi
  # RDS/ElastiCache lag a generation behind EC2 for Graviton families
  if [ -n "$prefix" ]; then
    case "$g" in
      m7g) g="m6g" ;;
      c7g) g="c6g" ;;
      r7g) g="r6g" ;;
      t4g) g="t4g" ;;
      *)   g="m6g" ;;
    esac
  fi
  echo "${prefix}${g}.${size}"
}

emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" \
    "$(printf '%s' "$4" | sed 's/^[[:space:]]*//; s/	/ /g' | cut -c1-64)"
}

# --- 1. instance types / classes / node types --------------------------------
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  loc="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"; snip="${rest#*:}"
  rel="${loc#$ROOT}"; rel="${rel#/}"
  cur="$(printf '%s' "$snip" \
        | grep -oE '"((db|cache)\.)?(t[234][a-z]?|m[4-7][ian]?|c[4-7][ian]?|r[4-7][abin]?|i[34][a-z]*|x[12][a-z]*|z1d)\.[0-9]*[a-z]+"' \
        | head -1 | tr -d '"')"
  [ -n "$cur" ] || continue
  sug="$(suggest_type "$cur")"
  [ "$sug" = "$cur" ] && continue
  emit INSTANCE-TYPE "$rel:$ln" "$cur -> $sug" "$snip"
  N_INST=$((N_INST+1))
done < <(grep -rInE $EXCL \
  --include='*.tf' --include='*.tfvars' --include='*.ts' --include='*.py' \
  --include='*.json' --include='*.yaml' --include='*.yml' \
  '(instance_type|instanceType|InstanceType|instance_class|instanceClass|node_type|CacheNodeType|instance_types|instanceTypes)' \
  "$ROOT" 2>/dev/null)

# --- 2. AMI architecture filters --------------------------------------------
# An arch value sits on its own line inside a filter block:
#     filter {
#       name   = "architecture"
#       values = ["x86_64"]      <-- no "ami"/"filter" keyword on this line
#     }
# Requiring the keyword on the same line as the value misses every one of these,
# so each candidate line is matched against a window of its surrounding context.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  loc="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"; snip="${rest#*:}"
  rel="${loc#$ROOT}"; rel="${rel#/}"

  # keyword on the same line -> definitely AMI-related
  if printf '%s' "$snip" | grep -qiE '(ami|architecture|image_id|imageId|name_regex|ssm.*parameter|instance-type)'; then
    emit AMI-ARCH "$rel:$ln" "x86_64 -> arm64" "$snip"
    N_AMI=$((N_AMI+1))
    continue
  fi

  # otherwise look at the 6 lines above for an AMI/filter/architecture context
  start=$(( ln > 6 ? ln - 6 : 1 ))
  if sed -n "${start},${ln}p" "$loc" 2>/dev/null \
       | grep -qiE '(ami|architecture|image|filter[[:space:]]*\{|name[[:space:]]*=[[:space:]]*"architecture")'; then
    emit AMI-ARCH "$rel:$ln" "x86_64 -> arm64" "$snip"
    N_AMI=$((N_AMI+1))
  fi
done < <(grep -rInE $EXCL \
  --include='*.tf' --include='*.tfvars' --include='*.ts' --include='*.py' \
  --include='*.json' --include='*.yaml' --include='*.yml' --include='*.hcl' \
  '(x86_64|amd64)' "$ROOT" 2>/dev/null)

# --- 3. Lambda architecture --------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f#$ROOT}"; rel="${rel#/}"
  if grep -qE '(aws_lambda_function|AWS::Serverless::Function|AWS::Lambda::Function|new lambda\.Function|lambda_\.Function)' "$f" 2>/dev/null; then
    if ! grep -qiE '(architectures?[[:space:]]*[:=]|Architectures)' "$f" 2>/dev/null; then
      ln="$(grep -nE '(aws_lambda_function|AWS::Serverless::Function|AWS::Lambda::Function|new lambda\.Function)' "$f" | head -1 | cut -d: -f1)"
      emit LAMBDA-ARCH "$rel:${ln:-1}" "unset (defaults x86_64) -> arm64" "add architectures = [\"arm64\"]"
      N_LAMBDA=$((N_LAMBDA+1))
    fi
  fi
done < <(find "$ROOT" \( -name .git -o -name node_modules -o -name .terraform \) -prune -o \
           \( -name '*.tf' -o -name 'template.y*ml' -o -name 'serverless.y*ml' \
              -o -name '*.ts' -o -name '*.py' \) -type f -print 2>/dev/null)

# --- 4. EKS node group AMI type ---------------------------------------------
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  loc="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"; snip="${rest#*:}"
  rel="${loc#$ROOT}"; rel="${rel#/}"
  emit EKS-AMI-TYPE "$rel:$ln" "x86 AMI type -> AL2023_ARM_64_STANDARD" "$snip"
  N_EKS=$((N_EKS+1))
done < <(grep -rInE $EXCL --include='*.tf' --include='*.ts' --include='*.yaml' --include='*.yml' \
  'ami_type[[:space:]]*=[[:space:]]*"?(AL2_x86_64|AL2023_x86_64_STANDARD|BOTTLEROCKET_x86_64)' \
  "$ROOT" 2>/dev/null)

# --- 5. ECS runtimePlatform --------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f#$ROOT}"; rel="${rel#/}"
  if grep -qE '(aws_ecs_task_definition|AWS::ECS::TaskDefinition|FargateTaskDefinition|TaskDefinition\()' "$f" 2>/dev/null; then
    if ! grep -qiE '(cpu_architecture|cpuArchitecture|runtime_platform|runtimePlatform)' "$f" 2>/dev/null; then
      ln="$(grep -nE '(aws_ecs_task_definition|AWS::ECS::TaskDefinition|FargateTaskDefinition)' "$f" | head -1 | cut -d: -f1)"
      emit ECS-RUNTIME "$rel:${ln:-1}" "unset (defaults X86_64) -> ARM64" "add runtime_platform.cpu_architecture"
      N_ECS=$((N_ECS+1))
    fi
  fi
done < <(find "$ROOT" \( -name .git -o -name node_modules -o -name .terraform \) -prune -o \
           \( -name '*.tf' -o -name '*.ts' -o -name '*.json' -o -name '*.y*ml' \) -type f -print 2>/dev/null)

# --- 6. CI runners -----------------------------------------------------------
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  loc="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"; snip="${rest#*:}"
  rel="${loc#$ROOT}"; rel="${rel#/}"
  if printf '%s' "$snip" | grep -qE 'runs-on'; then
    emit CI-RUNNER "$rel:$ln" "x86 runner -> ubuntu-24.04-arm" "$snip"
  else
    emit CI-RUNNER "$rel:$ln" "LINUX_CONTAINER -> ARM_CONTAINER" "$snip"
  fi
  N_CI=$((N_CI+1))
done < <(grep -rInE $EXCL --include='*.yml' --include='*.yaml' --include='*.tf' --include='*.ts' \
  '(runs-on:[[:space:]]*(ubuntu|windows|macos)-(latest|[0-9.]+)[[:space:]]*$|type:[[:space:]]*LINUX_CONTAINER|aws/codebuild/(standard|amazonlinux2-x86_64))' \
  "$ROOT" 2>/dev/null)

TOTAL=$((N_INST + N_AMI + N_LAMBDA + N_EKS + N_ECS + N_CI))

if [ "$QUIET" -eq 0 ]; then
  printf '\n'
  printf -- '---- IaC audit --------------------------------------------\n'
  printf 'instance types    : %d\n' "$N_INST"
  printf 'AMI arch filters  : %d\n' "$N_AMI"
  printf 'Lambda arch unset : %d\n' "$N_LAMBDA"
  printf 'EKS AMI types     : %d\n' "$N_EKS"
  printf 'ECS runtimePlatform: %d\n' "$N_ECS"
  printf 'CI runners        : %d\n' "$N_CI"
  printf 'total changes     : %d\n' "$TOTAL"
  printf -- '----------------------------------------------------------\n'
  printf 'NEXT: verify region availability before applying:\n'
  printf '  bash verify_availability.sh <region> <type> ...\n'
  printf 'NOTE: the app must be arm64-ready first. Switching instance\n'
  printf '      types under an x86-only image fails at deploy.\n'
fi

[ "$TOTAL" -eq 0 ] || exit 1
exit 0
