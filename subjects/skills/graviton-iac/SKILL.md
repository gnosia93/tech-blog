---
name: graviton-iac
description: Converts Terraform, CDK, CloudFormation and SAM infrastructure from x86 to AWS Graviton instance families, AMIs, Lambda architectures and managed-service node types. Use when migrating infrastructure code to Graviton, mapping instance types to their arm64 equivalents, or auditing IaC for x86 pins.
---

# Graviton Infrastructure-as-Code Migration

Change the infrastructure definitions so arm64 workloads actually get scheduled
onto Graviton hardware.

## When to use

- Instance types, DB instance classes, or cache node types must move to Graviton
- Lambda functions should run on arm64
- An AMI lookup still filters on `x86_64` after an instance type change
- EKS node groups or ECS task definitions need arm64 settings

Run `graviton-compat-scan` first. This skill fixes what that scan reports under
the `iac-*` and `lambda-*` rules. **The application must be arm64-ready before
the infrastructure is switched** — flipping instance types under an x86-only
image produces a failed deployment, not a migration.

## Process

1. Inventory every x86 pin, deterministically:

   ```bash
   bash scripts/audit_iac.sh <repo-path>
   ```

2. Propose the mapping. Use `references/instance-mapping.md`, never invent a
   mapping from the family name.

3. CRITICAL: verify each target type exists in the target region **before**
   editing. Not every family/size combination is offered in every region, and
   an unavailable type fails at apply time, not plan time:

   ```bash
   bash scripts/verify_availability.sh <region> <type> [type ...]
   ```

4. Apply the edits. For each resource also check the coupled settings listed in
   `references/instance-mapping.md` — an instance type change alone is usually
   incomplete:
   - EC2 → AMI architecture filter and AMI name pattern
   - EKS node group → AMI type (`AL2023_ARM_64_STANDARD`)
   - ECS task → `runtimePlatform.cpuArchitecture`
   - Lambda → `architectures` plus every layer
   - Launch templates → the AMI they reference

5. Run `terraform plan` (or `cdk diff`) and read it. Report replacements versus
   in-place updates — several of these changes force instance replacement.

## Rules

- CRITICAL: never change an instance type without also updating the AMI lookup.
  An `x86_64`-filtered AMI on a Graviton instance fails to boot, and the error
  surfaces at launch, not at plan.
- CRITICAL: verify region availability before committing a mapping. `aws ec2
  describe-instance-type-offerings` is the authority; the mapping table is a
  starting point.
- Report which changes force replacement. In production this needs a rollout
  plan, not a bare `apply`.
- RDS and ElastiCache engine-version minimums apply to Graviton node types.
  Check the engine version before proposing `db.r6g` / `cache.m6g`.
- Do not switch every resource at once by default. Prefer a staged plan unless
  the user asks for a full conversion.
