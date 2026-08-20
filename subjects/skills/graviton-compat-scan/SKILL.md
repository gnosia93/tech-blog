---
name: graviton-compat-scan
description: Detects x86-specific code, dependencies, and infrastructure that block an arm64/AWS Graviton migration. Use when migrating a repository from x86 to Graviton, auditing arm64 readiness, or estimating migration effort.
---

# Graviton Compatibility Scan

Find everything in a repository that will break on arm64 (AWS Graviton), classify it
by severity, and report it so a human can size the migration.

## When to use

- A repository is being assessed or migrated from x86_64 to arm64 / AWS Graviton
- Someone asks "is this arm64-ready?" or "how much work is the Graviton migration?"
- A build succeeded on x86 but fails on Graviton and the cause is unknown
- Before writing any migration code — always scan first

## Process

**IMPORTANT: run the scanner before reading any source file.** The scanner is
deterministic; your own reading is not. Start from its output.

1. Run the static scan:

   ```bash
   bash scripts/scan_x86.sh <repo-path>
   ```

   Exit code `0` means no blockers. Exit code `1` means findings exist.
   Use `--strict` to also fail on VERIFY-level findings.

2. Read the output and group findings by rule, not by file. One root cause
   usually produces many lines.

3. For each `FAIL` finding, consult `references/known-failures.md` for the
   established remediation. Do not invent a fix if a documented one exists.

4. Run the dependency check, which needs network access and resolves real
   wheels/images rather than guessing:

   ```bash
   bash scripts/check_deps_arm64.sh <repo-path>
   ```

5. Report findings to the user as a table: rule, count, severity, remediation.
   **Do not start editing files until the user confirms the scope.**

## Severity meaning

| Severity | Meaning | Action |
|---|---|---|
| `FAIL` | Will not build or run on arm64 | Must fix before migration |
| `VERIFY` | Architecture-dependent; may or may not break | Must be tested on arm64 |
| `INFO` | Not a blocker, but relevant to the migration plan | Note in the plan |

## Rules

- CRITICAL: never claim a repository is arm64-clean based on a passing scan
  alone. The scan finds known patterns; it cannot prove absence of problems.
  Only a passing build and test run inside a `linux/arm64` container is evidence.
- CRITICAL: macOS arm64 is not Linux arm64. A passing local build on Apple
  Silicon does not validate Graviton. Always verify in `linux/arm64`.
- Report the exact counts the scanner produced. Never round or summarize away
  findings.
- If the scanner reports zero findings, say so plainly and move on to the
  container build validation — do not pad the report.
