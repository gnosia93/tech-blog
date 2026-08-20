# Graviton instance mapping and coupled settings

CRITICAL: this table is a starting point, not an authority. Regional
availability varies — always confirm with `verify_availability.sh` before
committing a mapping. An unavailable type passes `terraform plan` and fails at
`apply`.

---

## EC2 families

| x86 family | Graviton | Notes |
|---|---|---|
| `t2`, `t3`, `t3a` | `t4g` | Burstable. `t4g` has a free-trial tier in some regions |
| `m4`, `m5`, `m5a`, `m5n`, `m6i`, `m6a`, `m7i` | `m6g` / `m7g` / `m8g` | General purpose |
| `c4`, `c5`, `c5a`, `c5n`, `c6i`, `c7i` | `c6g` / `c7g` / `c8g` | Compute. `c6gn` for high network |
| `r4`, `r5`, `r5a`, `r5b`, `r6i`, `r7i` | `r6g` / `r7g` / `r8g` | Memory optimized |
| `i3`, `i3en` | `im4gn` / `is4gen` | Local NVMe. Disk sizes differ — verify capacity |
| `i4i` | `i4g` | Storage optimized |
| `x1`, `x1e`, `x2idn` | `x2gd` | High memory. Ratios are not identical |
| `z1d` | **none** | z1d sells clock speed; no Graviton equivalent |
| `p*`, `g*`, `inf*`, `trn*`, `f1`, `vt1` | **none** | Accelerators; some have arm64 hosts but not drop-in |

Generation choice: `m7g` (Graviton3) is the safe default. `m8g` (Graviton4) is
faster but has narrower regional coverage. `m6g` (Graviton2) is the widest
available. Do not assume the newest generation exists in your region.

## RDS

| x86 | Graviton |
|---|---|
| `db.t3` | `db.t4g` |
| `db.m5`, `db.m6i` | `db.m6g` / `db.m7g` |
| `db.r5`, `db.r6i` | `db.r6g` / `db.r7g` |

CRITICAL: Graviton DB classes require minimum engine versions. Roughly:
PostgreSQL ≥ 12.x, MySQL ≥ 8.0.17, MariaDB ≥ 10.4.x, Aurora PostgreSQL ≥ 12.4,
Aurora MySQL ≥ 2.10 / 3.x. Verify with
`aws rds describe-orderable-db-instance-options --engine <e> --db-instance-class <c>`
before proposing a change — the exact floor moves with AWS releases.

The class change is a **replacement with downtime** unless the instance is
Multi-AZ (then it is a failover). Report this.

## ElastiCache

| x86 | Graviton |
|---|---|
| `cache.t3` | `cache.t4g` |
| `cache.m5`, `cache.m6i` | `cache.m6g` / `cache.m7g` |
| `cache.r5`, `cache.r6i` | `cache.r6g` / `cache.r7g` |

Redis ≥ 5.0.6 and Memcached ≥ 1.5.16 required for Graviton node types.

## OpenSearch

| x86 | Graviton |
|---|---|
| `m5.*.search`, `m6g` | `m6g.*.search` / `m7g.*.search` |
| `r5.*.search` | `r6g.*.search` / `r7g.*.search` |
| `c5.*.search` | `c6g.*.search` |

Requires OpenSearch 1.0+ or Elasticsearch 7.9+. Older domains must upgrade first.

---

## Coupled settings — an instance type change alone is usually incomplete

### EC2 / Auto Scaling — AMI must change too

```hcl
# before
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]          # <-- must become arm64
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]   # <-- name pattern too
  }
}

# after
filter {
  name   = "architecture"
  values = ["arm64"]
}
filter {
  name   = "name"
  values = ["amzn2-ami-hvm-*-arm64-gp2"]
}
```

CRITICAL: changing `instance_type` while leaving the AMI filter on `x86_64`
produces an instance that cannot boot. The failure appears at launch, well after
`terraform apply` reports success. If an ASG is involved, it appears as repeated
instance termination with no obvious cause.

SSM parameter paths also encode architecture:
```
/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2
/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2
```

### Launch templates

A launch template referencing an x86 AMI must be updated and a **new version**
created. ASGs pinned to a specific launch template version keep using the old
AMI silently.

### EKS node groups

```hcl
resource "aws_eks_node_group" "arm" {
  instance_types = ["m7g.large"]
  ami_type       = "AL2023_ARM_64_STANDARD"   # was AL2023_x86_64_STANDARD
}
```

Valid arm64 AMI types: `AL2_ARM_64`, `AL2023_ARM_64_STANDARD`,
`BOTTLEROCKET_ARM_64`, `BOTTLEROCKET_ARM_64_NVIDIA`.

CRITICAL: in a mixed-architecture cluster, arm64-only workloads need a
nodeSelector or the scheduler will place them on x86 nodes, where the pod
crash-loops with `exec format error`:

```yaml
nodeSelector:
  kubernetes.io/arch: arm64
```

DaemonSets are the usual casualty — they schedule to every node regardless of
arch. Every DaemonSet image must be multi-arch before the first arm64 node joins.

### ECS task definitions

```hcl
resource "aws_ecs_task_definition" "app" {
  runtime_platform {
    cpu_architecture        = "ARM64"      # default is X86_64
    operating_system_family = "LINUX"
  }
}
```

Fargate requires this field to match the image. An arm64 image with the default
`X86_64` fails to start with a platform mismatch error.

### Lambda

```hcl
resource "aws_lambda_function" "api" {
  architectures = ["arm64"]     # default is ["x86_64"]
}
```

CDK: `architecture: lambda.Architecture.ARM_64`
SAM/CFN: `Architectures: [arm64]`

CRITICAL: every layer attached to the function must be rebuilt for arm64. A
layer containing compiled dependencies fails at **invoke** time, not deploy
time, so the deployment looks successful. Layers declare compatible
architectures — set `compatible_architectures = ["arm64"]`.

Container-image Lambdas need an arm64 image; `--platform linux/arm64` at build.

---

## Change impact — report this before applying

| Change | Impact |
|---|---|
| EC2 `instance_type` | Stop/start or replacement. Instance store data lost |
| ASG launch template AMI | New instances only; existing ones need refresh |
| RDS `instance_class` | Replacement. Downtime unless Multi-AZ failover |
| ElastiCache `node_type` | Replacement. Cache cold-start after cutover |
| Lambda `architectures` | In-place, new version published |
| ECS `runtime_platform` | New task definition revision; service redeploy |
| EKS `ami_type` | Node group replacement — cordon/drain required |

## Staged rollout — mixed-architecture ASG

Do not flip an entire fleet at once. A mixed-instances policy runs both
architectures behind one ASG so rollback is a weight change rather than a
redeploy:

```hcl
mixed_instances_policy {
  instances_distribution {
    on_demand_base_capacity                  = 0
    on_demand_percentage_above_base_capacity = 100
  }
  launch_template {
    override { instance_type = "m5.large"  }   # x86, existing
    override { instance_type = "m7g.large" }   # Graviton, new
  }
}
```

CRITICAL: this only works if the AMI and userdata resolve per-architecture. A
single x86 AMI in the launch template means the `m7g` overrides never launch
successfully. Use an arch-aware AMI lookup or separate launch templates per arch
with two ASGs behind one target group — the two-ASG form is easier to reason
about and to roll back.
