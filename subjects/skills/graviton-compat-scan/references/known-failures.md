# Known arm64 / Graviton failures and their fixes

Each entry maps a `scan_x86.sh` rule to the remediation that has actually worked.
Add to this file whenever a migration turns up a failure mode not listed here —
this file is the accumulated memory of the migration effort.

---

## FAIL: x86-simd-header, x86-simd-intrinsic

**Symptom**
```
fatal error: immintrin.h: No such file or directory
error: unknown type name '__m128i'
```

**Cause** SSE/AVX intrinsics are x86-only. arm64 uses NEON (`arm_neon.h`).

**Fix, in order of preference**

1. **Delete the hand-written SIMD.** Modern compilers auto-vectorize at `-O3`
   on arm64. Measure before assuming the intrinsics are worth keeping — on
   Graviton3/4 the scalar loop is frequently within noise of the x86 SIMD path.
2. **Use a portable wrapper.** `simde` (SIMD Everywhere) provides drop-in
   `_mm_*` implementations that compile to NEON. Usually a one-line include
   swap: `#include <simde/x86/sse2.h>` plus `-DSIMDE_ENABLE_NATIVE_ALIASES`.
   Lowest-effort path for a large intrinsic surface.
3. **Write a NEON path** behind `#if defined(__aarch64__)`. Highest effort,
   only justified when benchmarks prove the SIMD path is on the hot path.

**Common intrinsic mapping** (for option 3)

| x86 | NEON |
|---|---|
| `_mm_setzero_si128()` | `vdupq_n_s64(0)` |
| `_mm_loadu_si128(p)` | `vld1q_u8((const uint8_t*)p)` |
| `_mm_add_epi64(a,b)` | `vaddq_s64(a,b)` |
| `_mm_add_epi32(a,b)` | `vaddq_s32(a,b)` |
| `_mm_xor_si128(a,b)` | `veorq_s8(a,b)` |
| `_mm_movemask_epi8(a)` | no direct equivalent — needs a reduction idiom |

CRITICAL: `_mm_movemask_epi8` and the other mask-extraction intrinsics have no
one-instruction NEON equivalent. Code relying on them needs an algorithmic
rewrite, not a mechanical translation. Flag these for human review.

---

## FAIL: x86-inline-asm

**Symptom** `error: unknown register name 'a'`, or assembler errors on `rdtsc`.

**Cause** x86 assembly and register names do not exist on arm64.

**Fix**

- `rdtsc` (cycle counter) → use `clock_gettime(CLOCK_MONOTONIC, ...)` or
  `std::chrono::steady_clock`. Portable and almost always what the code
  actually wanted.
- `cpuid` → use compiler builtins (`__builtin_cpu_supports`) or read
  `/proc/cpuinfo`; on arm64, feature detection uses `getauxval(AT_HWCAP)`.
- Atomics written in asm → replace with C11 `<stdatomic.h>` or
  `__atomic_*` builtins. The compiler emits correct arm64 LSE instructions.
- Memory barriers → `atomic_thread_fence` instead of `mfence`/`lfence`/`sfence`.

---

## FAIL: x86-compiler-flag

**Symptom** `error: unrecognized command-line option '-msse4.2'`

**Fix** Make the flags architecture-conditional rather than deleting them.

Makefile:
```make
ARCH := $(shell uname -m)
ifeq ($(ARCH),aarch64)
  ARCHFLAGS = -mcpu=neoverse-v2      # Graviton4; use neoverse-n1 for Graviton2
else
  ARCHFLAGS = -msse4.2 -mavx2
endif
CFLAGS = -O3 $(ARCHFLAGS)
```

CMake:
```cmake
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  add_compile_options(-mcpu=neoverse-n1)
else()
  add_compile_options(-msse4.2 -mavx2)
endif()
```

**`-march=native` is a trap.** It works on both architectures but bakes in the
*build machine's* CPU. If CI builds on Graviton4 and you deploy to Graviton2,
the binary faults with SIGILL. Use an explicit `-mcpu=` target.

Graviton `-mcpu` values: Graviton2 → `neoverse-n1`, Graviton3 → `neoverse-512tvb`,
Graviton4 → `neoverse-v2`. For a binary that must run on all of them, target the
oldest.

---

## FAIL: dockerfile-amd64-pin, dockerfile-x86-base-tag

**Fix** Remove the platform pin and let buildx resolve per-target, or use the
build argument.

```dockerfile
# before
FROM --platform=linux/amd64 python:3.11-slim

# after
FROM python:3.11-slim
```

When a stage genuinely must be pinned (e.g. a cross-compiling builder), pin
only that stage and use `$TARGETARCH` for the payload:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22 AS build
ARG TARGETARCH
RUN GOARCH=$TARGETARCH go build -o /app ./cmd/server

FROM gcr.io/distroless/static
COPY --from=build /app /app
```

Verify the base image actually has an arm64 manifest before committing:
```bash
docker manifest inspect python:3.11-slim | grep -A2 architecture
```

---

## FAIL: x86-binary-download

**Symptom** Container builds fine, then `exec format error` at runtime.

This is the failure mode that most often slips through code review, because the
Docker build succeeds — the binary is only executed at runtime.

**Fix** Select the download by `$TARGETARCH`:

```dockerfile
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) SUFFIX=x86_64 ;; \
      arm64) SUFFIX=aarch64 ;; \
      *) echo "unsupported: $TARGETARCH" >&2; exit 1 ;; \
    esac && \
    curl -fsSL "https://example.com/releases/tool-linux-${SUFFIX}.tar.gz" \
      | tar xz -C /usr/local/bin
```

CRITICAL: always include the failing `*)` branch. A silent fallback to the x86
URL produces a container that builds green and dies in production.

If the vendor publishes no aarch64 build, that is a hard blocker — escalate to a
human. Options are: build from source, find a replacement tool, or keep that one
service on x86.

---

## FAIL: dotnet-rid-x64

**Fix** `linux-x64` → `linux-arm64`. Check `RuntimeIdentifiers` in the project
file, `--runtime` in build scripts, and any `PublishReadyToRun` settings
(R2R images are architecture-specific and must be regenerated).

---

## FAIL: committed-native-object

`.so` / `.node` files committed to git are compiled for one architecture and
cannot be reused. They must be rebuilt from source on arm64. If the source is
not available, this is a hard blocker.

---

## VERIFY: arch-runtime-branch

**Symptom** `RuntimeError: unsupported arch: aarch64`

**Cause** Code that enumerates known architectures and rejects the rest.

**Fix** Add the arm64 case. Note the names differ by runtime:

| Runtime | x86 value | arm64 value |
|---|---|---|
| Python `platform.machine()` | `x86_64` | `aarch64` |
| Node `os.arch()` | `x64` | `arm64` |
| Go `runtime.GOARCH` | `amd64` | `arm64` |
| Java `os.arch` | `amd64` | `aarch64` |
| .NET `ProcessArchitecture` | `X64` | `Arm64` |
| `uname -m` | `x86_64` | `aarch64` |

CRITICAL: Linux reports `aarch64` while macOS and Node report `arm64`. Code that
checks only one string breaks on the other. Match both.

---

## VERIFY: node-native-dependency, node-gyp-build

These packages compile C/C++ at install time or ship prebuilt binaries.

**Fix**

1. Upgrade first. Most have shipped arm64 prebuilds for years:
   - `sharp` ≥ 0.31 — arm64 prebuilds available
   - `bcrypt` ≥ 5.1 — arm64 prebuilds available
   - `better-sqlite3` ≥ 8 — arm64 prebuilds available
   - `node-sass` — **no arm64 support, deprecated.** Migrate to `sass`
     (dart-sass, pure JS). This is a code change, not a version bump.
2. If no prebuild exists, install build tooling in the image
   (`build-essential`, `python3`) so `node-gyp` can compile.
3. Delete and regenerate the lockfile on arm64 if it pinned x86 artifacts.

---

## VERIFY: python-wheel-risk

**Symptom** `pip install` starts compiling from source, then fails on a missing
system header — or succeeds but takes 20 minutes.

**Cause** No `manylinux*_aarch64` wheel for that version.

**Fix** Raise the floor. Minimum versions with aarch64 wheels:

| Package | First version with aarch64 wheel |
|---|---|
| `numpy` | 1.19 |
| `scipy` | 1.6 |
| `pandas` | 1.2 |
| `grpcio` | 1.34 |
| `pyarrow` | 4.0 |
| `cryptography` | 3.4 |
| `pillow` | 8.0 |
| `lxml` | 4.6 |
| `psycopg2-binary` | 2.9.2 |
| `confluent-kafka` | 1.9 |
| `opencv-python` | 4.5.3 |

CRITICAL: the table above is necessary but not sufficient. aarch64 wheel
availability is a function of **(package version × Python version)**, not
package version alone. A version that has aarch64 wheels for py3.10 may have
none for py3.11.

Verified example: `grpcio==1.48.0` ships `manylinux_2_17_aarch64` wheels for
cp36–cp310 but **no cp311 wheel at all**. It satisfies the "≥1.34" rule above
and still fails on a py3.11 Graviton build. Same for `pyarrow==9.0.0`.

Always check empirically against the Python version actually in use:
```bash
pip download --no-deps --only-binary=:all: \
  --platform manylinux2014_aarch64 --python-version 3.11 \
  --dest /tmp/whl "numpy==1.21.0"
```

CRITICAL: `--platform` is matched as a literal string, so one attempt is not a
conclusive answer. `manylinux2014_aarch64`, `manylinux_2_17_aarch64`,
`manylinux_2_28_aarch64` and `linux_aarch64` all describe compatible platforms,
and a package may be tagged with any of them. `grpcio==1.48.0` resolves under
`manylinux_2_17_aarch64` but fails under `manylinux2014_aarch64` — checking only
the latter produces a false "no arm64 support" verdict. `check_deps_arm64.sh`
tries every tag before reporting a failure; do the same when checking by hand.

`uwsgi` and `pycurl` have no wheels for any platform — they always compile.
Ensure the image has the needed headers rather than trying to find a wheel.

---

## VERIFY: jvm-native-classifier

Java bytecode is portable; JNI libraries are not. Check:

- `netty-tcnative` → needs the `linux-aarch_64` classifier
- `snappy-java`, `lz4-java`, `rocksdbjni` → upgrade; recent versions bundle arm64
- JavaCPP / JNA-based libraries → verify the arm64 native is bundled

Also review JVM flags. `-XX:UseAVX` and similar x86-specific flags are silently
ignored on arm64 in some JVMs and fatal in others.

---

## INFO: iac-x86-instance-type

Graviton equivalents (same vCPU/memory, roughly 20% cheaper):

| x86 | Graviton |
|---|---|
| `t3` / `t3a` | `t4g` |
| `m5` / `m5a` / `m6i` | `m6g` / `m7g` / `m8g` |
| `c5` / `c5a` / `c6i` | `c6g` / `c7g` / `c8g` |
| `r5` / `r5a` / `r6i` | `r6g` / `r7g` / `r8g` |
| `i3` / `i4i` | `im4gn` / `is4gen` |
| `db.m5` / `db.r5` | `db.m6g` / `db.r6g` |
| `cache.m5` / `cache.r5` | `cache.m6g` / `cache.r6g` |

CRITICAL: not every family/size combination exists in every region. Verify with
`aws ec2 describe-instance-type-offerings --location-type availability-zone`
before committing an IaC change, or the apply fails at deploy time.

Also note: `m7g` has no `.metal` in all regions, and some x86 families have no
Graviton counterpart at all (e.g. GPU instances with x86-only drivers, `z1d`'s
high clock speed).

---

## INFO: iac-x86-ami-filter

AMI lookups filtered on `architecture = x86_64` silently keep returning x86
images even after the instance type changes — producing a launch failure. Update
the filter to `arm64` and confirm the AMI name pattern also changes
(e.g. `amzn2-ami-hvm-*-x86_64-gp2` → `amzn2-ami-hvm-*-arm64-gp2`).

---

## INFO: lambda-architecture-unset

Lambda defaults to `x86_64`. Setting arm64 is a one-line change and typically
gives ~20% better price-performance:

- Terraform: `architectures = ["arm64"]`
- SAM/CFN: `Architectures: [arm64]`
- CDK: `architecture: lambda.Architecture.ARM_64`

Layers must be rebuilt for arm64 — a layer containing compiled dependencies will
fail at runtime, not at deploy time. Container-image Lambdas need an arm64 image.

---

## INFO: ci-x86-runner

The build must run on arm64, or cross-build. Options:

- GitHub Actions: `runs-on: ubuntu-24.04-arm` (public arm64 runners)
- CodeBuild: `ARM_CONTAINER` with `aws/codebuild/amazonlinux2-aarch64-standard`
- Cross-build with QEMU: `docker/setup-qemu-action` then
  `buildx --platform linux/amd64,linux/arm64`

**QEMU is 5–20× slower than native** and unsuitable for timing-sensitive tests.
Use it for image builds, native arm64 runners for test suites.
