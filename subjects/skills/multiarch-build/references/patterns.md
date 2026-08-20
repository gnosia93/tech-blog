# Multi-arch build patterns

Established fixes for each `audit_dockerfile.sh` rule. Prefer these over
invented variants — they have been validated on Graviton.

---

## FAIL: platform-pinned-amd64

```dockerfile
# before — forces x86 even on a Graviton host
FROM --platform=linux/amd64 python:3.11-slim

# after — buildx resolves per target platform
FROM python:3.11-slim
```

Only pin a stage when it genuinely must cross-compile. The correct form pins the
**builder** to the native host and parameterizes the output:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22 AS build
ARG TARGETARCH
RUN GOARCH=$TARGETARCH CGO_ENABLED=0 go build -o /app ./cmd/server

FROM gcr.io/distroless/static
COPY --from=build /app /app
```

`$BUILDPLATFORM` = the machine running the build. `$TARGETARCH` = what you are
building for (`amd64` / `arm64`). Both are supplied by buildx automatically;
`TARGETARCH` still must be declared with `ARG` in each stage that uses it.

---

## FAIL: from-tag-x86

An image tag containing `amd64` usually means the publisher ships per-arch
repositories rather than a manifest list.

```dockerfile
# before
FROM amd64/ubuntu:22.04

# after — the manifest-list repo resolves both arches
FROM ubuntu:22.04
```

If the publisher only ships per-arch repos, dispatch on `TARGETARCH`:

```dockerfile
ARG TARGETARCH
FROM ${TARGETARCH}/ubuntu:22.04
```

Verify first — many `amd64/*` repos have an `arm64v8/*` sibling, not `arm64/*`.
The naming is inconsistent across publishers.

---

## FAIL: binary-download-hardcoded-x86

The highest-risk defect in this category: **the build succeeds and the container
dies at runtime with `exec format error`.** Code review rarely catches it.

```dockerfile
# before
RUN curl -fsSL https://example.com/releases/tool-linux-x86_64.tar.gz \
      | tar xz -C /usr/local/bin

# after
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) SUFFIX=x86_64 ;; \
      arm64) SUFFIX=aarch64 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac && \
    curl -fsSL "https://example.com/releases/tool-linux-${SUFFIX}.tar.gz" \
      | tar xz -C /usr/local/bin
```

CRITICAL: the `*)` branch must `exit 1`. A fallback to the x86 URL produces a
green build and a production outage.

Vendor naming is not standardized. Common arm64 suffixes:

| Vendor convention | arm64 value |
|---|---|
| GNU triple style | `aarch64` |
| Go release style | `arm64` |
| Debian package style | `arm64` |
| Some JDK/vendor builds | `aarch64` or `arm64v8` |
| Node.js distributions | `arm64` |

Check the vendor's release page before assuming. If no arm64 asset exists, this
is a hard blocker — escalate rather than working around it.

---

## FAIL: pip-platform-x86

```dockerfile
# before
RUN pip install --platform manylinux2014_x86_64 --only-binary=:all: -r requirements.txt

# after — let pip resolve for the image's own architecture
RUN pip install -r requirements.txt
```

An explicit `--platform` is only needed when building a Lambda layer or wheel
bundle for a different architecture than the build host. In that case
parameterize it:

```dockerfile
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) PLAT=manylinux2014_x86_64 ;; \
      arm64) PLAT=manylinux2014_aarch64 ;; \
      *) exit 1 ;; \
    esac && \
    pip install --platform "$PLAT" --only-binary=:all: --target /deps -r requirements.txt
```

CRITICAL: `--platform` is string-matched by pip. A package may publish under
`manylinux_2_17_aarch64` and not `manylinux2014_aarch64` even though the
platforms are compatible. If resolution fails, try the sibling tags before
concluding the package lacks arm64 support.

---

## WARN: build-target-x64

| Toolchain | x86 form | arm64 form |
|---|---|---|
| .NET | `--runtime linux-x64` | `--runtime linux-arm64` |
| Go | `GOARCH=amd64` | `GOARCH=arm64` |
| Rust | `--target x86_64-unknown-linux-gnu` | `--target aarch64-unknown-linux-gnu` |
| Java | (portable bytecode) | check JNI natives only |

.NET note: `PublishReadyToRun` produces architecture-specific images and must be
regenerated for arm64. A ReadyToRun x64 image silently falls back to JIT or
fails depending on runtime version.

---

## WARN: targetarch-not-declared

`TARGETARCH` is supplied by buildx but is **not automatically in scope**. Each
stage that references it needs its own `ARG`:

```dockerfile
FROM alpine AS a
ARG TARGETARCH        # required here
RUN echo $TARGETARCH

FROM alpine AS b
ARG TARGETARCH        # and again here — ARG does not cross stages
RUN echo $TARGETARCH
```

Without the `ARG`, the variable expands to an empty string. A `case` statement
then falls to its default branch — which is why the failing `*)` branch matters.

---

## CI: adding arm64 builds

### GitHub Actions — native arm64 runners (preferred)

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          - runner: ubuntu-24.04
            platform: linux/amd64
          - runner: ubuntu-24.04-arm
            platform: linux/arm64
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          platforms: ${{ matrix.platform }}
          push: true
          tags: myrepo/app:${{ github.sha }}-${{ matrix.arch }}
```

Native runners run tests at full speed. Prefer this over QEMU whenever the
suite is timing-sensitive or long.

### GitHub Actions — QEMU cross-build (single job)

```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64
    push: true
```

Simpler, one manifest list out, but **5-20x slower**. Acceptable for image
builds; unsuitable for running test suites.

### AWS CodeBuild — arm64

```yaml
environment:
  type: ARM_CONTAINER
  image: aws/codebuild/amazonlinux2-aarch64-standard:3.0
  computeType: BUILD_GENERAL1_LARGE
```

`type` must change to `ARM_CONTAINER`. Leaving `LINUX_CONTAINER` with an
aarch64 image fails at provisioning.

### Merging per-arch builds into one manifest list

When arches build in separate jobs, combine them at the end:

```bash
docker buildx imagetools create -t myrepo/app:1.0 \
  myrepo/app:1.0-amd64 \
  myrepo/app:1.0-arm64
```

---

## Verification

A build that succeeds is not evidence. Run the image:

```bash
# build and load locally
docker buildx build --platform linux/arm64 -t app:arm64 --load .

# confirm the image's declared architecture
docker image inspect app:arm64 --format '{{.Architecture}}'   # expect: arm64

# confirm binaries inside are actually arm64, not x86 that happened to copy in
docker run --rm --platform linux/arm64 app:arm64 \
  sh -c 'file /usr/local/bin/tool 2>/dev/null || uname -m'

# smoke test the real entrypoint
docker run --rm --platform linux/arm64 app:arm64 --version
```

CRITICAL: `docker image inspect` reporting `arm64` only describes the image
config. A vendored x86 binary inside an arm64 image still yields
`exec format error` when executed. Run the actual entrypoint.

---

## ECS / EKS / Lambda runtime settings

Changing the image is not sufficient — the platform must be told to schedule
arm64.

**ECS task definition**
```json
"runtimePlatform": {
  "cpuArchitecture": "ARM64",
  "operatingSystemFamily": "LINUX"
}
```

**EKS** — node group instance types must be Graviton (`m7g`, `c7g`, …), and the
AMI type must be `AL2_ARM_64` / `AL2023_ARM_64_STANDARD`. Mixed-arch clusters
need `nodeSelector: kubernetes.io/arch: arm64` on arm64-only workloads,
otherwise the scheduler may place an arm64-only image on an x86 node.

**Lambda (container image)** — `Architectures: [arm64]` and the image must be
built for arm64. Zip-based functions with compiled dependencies need those
dependencies rebuilt; a layer built for x86 fails at invoke time, not deploy.
