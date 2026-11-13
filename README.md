<div align="center">

# lab

**The starting point of a lab of agents.**

The rules, the roster, the queue and the checks — in place before the first agent wakes.

![shape: mise + BATS](https://img.shields.io/badge/shape-mise%20%2B%20BATS-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 33](https://img.shields.io/badge/tests-33-brightgreen?style=flat)](test/)
![lints: @all](https://img.shields.io/badge/lints-%40all-blue?style=flat)
![README: TSX](https://img.shields.io/badge/README-TSX-f472b6?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)](LICENSE)

</div>

<br />

## What this is

`lab` scaffolds a lab of agents — a contract, a roster, a work queue, a commit guard and a steward — under any agent harness or none. It runs on git, bash and `mise`, and it is a rewrite of [lab_old](https://github.com/olavostauros/lab_old) on the [KnickKnackLabs skeleton](https://github.com/KnickKnackLabs/trahmpolina): mise-managed tasks, parallel BATS tests, codebase convention lints, generated README, and CI.

The rewrite is in progress. [`AGENTS.md`](AGENTS.md) is the product contract — what a change must preserve — and the commands land as they port from lab_old.

## Quick start

```bash
gh repo clone olavostauros/lab
cd lab

mise trust
mise install
mise run validate
mise run doctor

# Optional local safety net: installs .git/hooks/pre-commit.d/codebase
codebase pre-commit
```

## Goodies baked in

| Goodie                        | Why it exists                                                                                                                 | Where                        |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| Generated README              | TSX can count tests, list tasks, and keep docs honest in CI.                                                                  | `README.tsx`                 |
| Doctor hook check             | Local pre-commit hooks are clone-local, so the repo can report them without pretending they are tracked.                      | `mise run doctor`            |
| Convention lints              | Best-practice drift gets caught as code, not folklore.                                                                        | `[_.codebase].lint`          |
| Real test path                | BATS tests call tasks through `mise run`, not raw scripts.                                                                    | `test/test_helper.bash`      |
| Public test workflow          | The complete BATS runner stays visible and testable at the public task boundary.                                              | `.mise/tasks/test`           |
| Reference validation workflow | One gate owns explicit check ordering, private evidence, interruption, and the final verdict. Local and CI use the same path. | `.mise/tasks/validate`       |
| Parallel BATS                 | The KKL Bats fork and Rush schedule isolated tests concurrently across and within files.                                      | `.mise/tasks/test`           |
| Mac + Linux CI                | Bash and tooling differences show up before merge.                                                                            | ubuntu-latest + macos-latest |

## Scaffold inventory

| Path                         | Status | Purpose                                               |
| ---------------------------- | ------ | ----------------------------------------------------- |
| `mise.toml`                  | ✓      | tools, settings, and codebase lint config             |
| `README.tsx`                 | ✓      | programmable README source                            |
| `CONTRIBUTING.md`            | ✓      | repo-entry orientation surface                        |
| `.mise/tasks/test`           | ✓      | complete public BATS command workflow                 |
| `.mise/tasks/validate`       | ✓      | aggregate validation, private logs, and final outcome |
| `.mise/tasks/doctor`         | ✓      | local health check plus hook hint                     |
| `.github/workflows/test.yml` | ✓      | Ubuntu/macOS CI                                       |
| `test/`                      | ✓      | BATS smoke coverage                                   |
| `lib/`                       | ✓      | shared sourced code starts here when needed           |

## Tasks

| Task                | Description                                                          |
| ------------------- | -------------------------------------------------------------------- |
| `mise run doctor`   | Check local development setup                                        |
| `mise run test`     | Run BATS tests                                                       |
| `mise run validate` | Run all validation checks with compact results and private full logs |

## Parallel tests

The canonical test task uses the [KKL-maintained Bats fork](https://github.com/KnickKnackLabs/bats-core) with [Rush](https://github.com/shenwei356/rush) and a measured four-job default. Isolated tests can run concurrently across separate files and within one file.

```bash
mise run test                         # measured four-job default
mise run test --jobs 4                # explicit job count
BATS_NUMBER_OF_PARALLEL_JOBS=2 mise run test
mise run test --jobs 1                # serial debugging
```

Parallel suites must isolate mutable state per test and process. Use `$BATS_TEST_TMPDIR`, unique ports, and fixture-local repositories instead of shared files, services, HOME overrides, or repository mutations.

## Skeleton conventions

1. Rewrite this README around the actual tool as it grows, keeping the dynamic counters if they help.
2. Keep the complete test runner in `.mise/tasks/test` so the public task is the tested workflow.
3. Keep other public `.mise/tasks` readable and command-shaped; extract sourced Bash under `lib/` only when multiple commands share one domain contract.
4. If the installed tool resolves caller-relative paths, read the shiv-provided `<PACKAGE>_CALLER_PWD` variable, not generic `CALLER_PWD`.
5. Keep parallel tests isolated per test/process, or opt the suite into serial execution until shared state is removed.
6. Preserve the [validation ownership and evidence contracts](CONTRIBUTING.md#reference-validation-workflow) when adding checks, dependencies, or shared writes.

<details>
<summary><b>Current convention checks</b></summary>

This repo currently asks [codebase](https://github.com/KnickKnackLabs/codebase) to run these lint rules:

```
@all
```

</details>

## Validation

```bash
mise run validate                      # compact results, private full logs
mise run validate --verbose            # full output for ephemeral CI
BATS_NUMBER_OF_PARALLEL_JOBS=1 mise run validate
```

The gate runs tests, Codebase lint, generated-README verification, and whitespace checks. Those checks are independent and run serially; BATS/Rush still owns test parallelism. A failed check does not suppress its independent peers. Interruption stops later checks and contains the active process group.

Every invocation prints its private log directory and one timed result per check. Full logs, command arguments, and per-check receipts remain there; failures include a bounded excerpt. The final `report.tsv` distinguishes passing checks from the whole-run outcome after cleanup. A partial run or cleanup failure cannot report overall success. Logs are private, not redacted; remove them when no longer needed.

CI calls the same gate with `--verbose` so detailed failures survive in its masked job log. The explicit `ci_lint_gate` declaration tells Codebase that this tested aggregate owns lint; it is not automatic inspection of the task. Read the [adoption guide](CONTRIBUTING.md#reference-validation-workflow) for the report format, prerequisite example, concurrency ownership, process-group limits, and when shared writes require an exclusion boundary. The individual commands remain available for focused checks.

The starter suite currently has **33 tests** and **3 public tasks**. Those numbers are read from the repo at README build time.

<div align="center">

---

<sub>
This README was generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />A skeleton is a kindness to whoever has to remember the boring parts tomorrow.
</sub></div>
