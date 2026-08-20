#!/usr/bin/env bash
# verify_availability.sh — confirm instance types exist in a region before applying.
#
# Usage:  bash verify_availability.sh <region> <type> [type ...]
#         bash verify_availability.sh us-east-1 m7g.2xlarge c7g.large
#
# Exit:   0 all types available · 1 at least one unavailable · 2 usage error
#
# Requires the AWS CLI with credentials. This check exists because a mapping
# table cannot know regional availability: not every family/size combination is
# offered in every region, and an unavailable type fails at APPLY time, after
# terraform plan has already shown green.

set -uo pipefail

REGION="${1:-}"
shift || true
[ -n "$REGION" ] && [ $# -gt 0 ] || {
  echo "usage: bash verify_availability.sh <region> <type> [type ...]" >&2
  exit 2
}

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not installed — cannot verify availability." >&2
  echo "Types remain UNVERIFIED. Do not treat this as a pass." >&2
  exit 2
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials not configured or expired." >&2
  echo "Run: aws sso login   (or configure credentials)" >&2
  echo "Types remain UNVERIFIED. Do not treat this as a pass." >&2
  exit 2
fi

FAILED=0
echo "=== instance type availability in $REGION ==="

for t in "$@"; do
  # strip db./cache. prefixes: those are RDS/ElastiCache, a different API
  case "$t" in
    db.*|cache.*)
      printf '  MANUAL  %-18s (managed service — check engine version support)\n' "$t"
      continue ;;
  esac

  azs="$(aws ec2 describe-instance-type-offerings \
           --region "$REGION" \
           --location-type availability-zone \
           --filters "Name=instance-type,Values=$t" \
           --query 'InstanceTypeOfferings[].Location' \
           --output text 2>/dev/null | tr '\t' ' ')"

  if [ -z "$azs" ]; then
    printf '  MISSING %-18s not offered in %s\n' "$t" "$REGION"
    FAILED=$((FAILED+1))
    # suggest the nearest available size in the same family
        fam="${t%%.*}"
    alts="$(aws ec2 describe-instance-type-offerings \
              --region "$REGION" --location-type region \
              --filters "Name=instance-type,Values=${fam}.*" \
              --query 'InstanceTypeOfferings[].InstanceType' \
              --output text 2>/dev/null | tr '\t' '\n' | sort | head -8 | tr '\n' ' ')"
    [ -n "$alts" ] && printf '          available in %s: %s\n' "$fam" "$alts"
  else
    n_az="$(printf '%s' "$azs" | wc -w | tr -d ' ')"
    printf '  OK      %-18s %s AZ(s): %s\n' "$t" "$n_az" "$azs"
    # single-AZ availability is a real risk for a multi-AZ ASG
    if [ "$n_az" -lt 2 ]; then
      printf '          WARNING: only %s AZ — a multi-AZ ASG will fail to balance\n' "$n_az"
    fi
  fi
done

echo ""
echo "---- availability summary ---------------------------------"
printf 'unavailable : %d\n' "$FAILED"
echo "----------------------------------------------------------"
if [ "$FAILED" -gt 0 ]; then
  echo "NOTE: pick a different size or family for unavailable types."
  echo "      Applying an unavailable type fails at deploy, not at plan."
fi

[ "$FAILED" -eq 0 ] || exit 1
exit 0
