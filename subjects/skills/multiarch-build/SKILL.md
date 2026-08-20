---
name: multiarch-build
description: Converts Dockerfiles and CI pipelines to build for linux/arm64 (AWS Graviton) alongside or instead of amd64. Use when a container image must run on Graviton, when a build pins --platform to amd64, when adding buildx multi-arch builds, or when a CI pipeline needs an arm64 runner.
---

# Multi-arch Container and CI Build

Make a container image and its build pipeline produce working `linux/arm64`
artifacts.

## When to use

- A Dockerfile pins `--platform=linux/amd64` or a `FROM` tag containing `amd64`
- An image must run on Graviton (ECS/EKS/EC2/Lambda container images)
- CI builds only x86 and needs an arm64 or multi-arch build
- A container builds successfully but fails at runtime with `exec format error`

Run `graviton-compat-scan` first if the repository has not been scanned. This
skill fixes what that scan finds under the `dockerfile-*` and `x86-binary-download`
and `ci-x86-runner` rules.

## Process

1. Audit the Dockerfiles. This is deterministic — do not eyeball it:

   ```bash
   bash scripts/audit_dockerfile.sh <repo-path>
   ```

2. Verify every base image actually has an arm64 manifest **before** editing
   anything. An image without an arm64 manifest cannot be fixed by removing a
   platform pin:

   ```bash
   bash scripts/check_base_images.sh <repo-path>
   ```

3. Apply fixes in this order. Consult `references/patterns.md` for the exact
   form of each:
   a. Remove `--platform=linux/amd64` pins from runtime stages
   b. Replace hardcoded arch in binary downloads with `$TARGETARCH` dispatch
   c. Swap arch-specific base tags for multi-arch tags
   d. Add arm64 to the CI build matrix

4. Build for arm64 and confirm it actually works. A build that succeeds proves
   nothing about runtime — you must run the image:

   ```bash
   docker buildx build --platform linux/arm64 -t <tag>:arm64 --load .
   docker run --rm --platform linux/arm64 <tag>:arm64 <smoke-command>
   ```

5. Report which images now build and run on arm64, and which are blocked by an
   upstream image or vendor binary with no arm64 build.

## Rules

- CRITICAL: `exec format error` at runtime is the signature failure of this
  work. It means an x86 binary landed in an arm64 image. The Docker build
  succeeds, so only running the image catches it. Always run a smoke command.
- CRITICAL: never add a silent fallback in a `$TARGETARCH` case statement. An
  unmatched architecture must `exit 1`. A fallback to the x86 URL produces an
  image that builds green and dies in production.
- CRITICAL: QEMU emulation (`--platform linux/arm64` on an x86 host) is 5-20x
  slower and unsuitable for timing-sensitive tests. Use it for image builds
  only; run test suites on native arm64.
- Do not delete the amd64 build unless the user asked for arm64-only. Default
  to multi-arch so rollback stays possible.
- If a base image or vendor binary has no arm64 build, that is a hard blocker.
  Escalate to the user instead of silently keeping that stage on x86.
