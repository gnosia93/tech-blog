---
name: graviton-validate
description: Builds and runs a repository's tests inside a linux/arm64 container to prove Graviton readiness, and benchmarks x86 against arm64. Use to validate an arm64 migration, when a scan passed but runtime behaviour is unverified, or when a Graviton price-performance claim needs real measurement.
---

# Graviton Validation and Benchmark

Produce evidence. A passing static scan and a successful build are not evidence
that a workload runs correctly on Graviton — only a passing test run inside
`linux/arm64` is.

## When to use

- After `graviton-compat-scan` / `multiarch-build` edits, to confirm they worked
- A migration is "done" and needs sign-off evidence
- Someone cites "up to 40% better price-performance" and the real number for
  this workload is unknown
- A test suite passes on x86 and its arm64 behaviour is unknown

## Process

1. Check the host and tooling. The result changes what is trustworthy:

   ```bash
   bash scripts/preflight.sh
   ```

   On an arm64 host (Apple Silicon, Graviton) arm64 containers run natively.
   On x86, they run under QEMU — builds are valid, timings are not.

2. Run the test suite inside `linux/arm64`:

   ```bash
   bash scripts/run_arm64_tests.sh <repo-path> [--cmd "<test command>"]
   ```

   The runtime is auto-detected when `--cmd` is omitted. Be explicit when the
   project has a non-standard entry point.

3. Read the failures. Consult `graviton-compat-scan`'s
   `references/known-failures.md` first — most arm64 test failures are one of
   the documented causes, not novel.

4. Only when correctness is established, measure performance:

   ```bash
   bash scripts/benchmark.sh <repo-path> --cmd "<workload command>" [--runs 5]
   ```

5. Report: tests passed/failed on arm64, and if benchmarked, the measured delta
   with the caveats the script prints. **Never report a QEMU timing as a
   Graviton performance result.**

## Rules

- CRITICAL: macOS arm64 is not Linux arm64. A passing `pytest` on Apple Silicon
  does not validate Graviton — glibc/musl, wheels, and system libraries differ.
  Always run inside a Linux arm64 container.
- CRITICAL: never present QEMU-emulated timings as performance data. QEMU is
  5-20x slower and distorts results non-uniformly. `preflight.sh` reports the
  execution mode; include it in any benchmark claim.
- CRITICAL: a local container benchmark is not a Graviton benchmark. Container
  timings on Apple Silicon indicate arm64 correctness, not EC2 price-performance.
  A real figure requires the same workload on comparable x86 and Graviton
  instances with production-like load.
- Report the actual measured number, never the marketing figure. If the measured
  delta is smaller than 40%, say so.
- If tests cannot run (no test suite, missing toolchain), say that plainly
  rather than reporting a pass.
