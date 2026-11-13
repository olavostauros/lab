# Contributing

This repo was scaffolded from [KnickKnackLabs/trahmpolina](https://github.com/KnickKnackLabs/trahmpolina),
the KnickKnackLabs starter skeleton for small maintained tools. Keep it boring
on purpose: inherit conventions, not product decisions.

[`AGENTS.md`](AGENTS.md) is the contract for this repository — read it before
changing `scaffold/`, `lib/` or the command surface. A scaffold change alters
the lab every future owner gets; it is the framework's opinion, and an opinion
is discussed before it is changed, so open an issue first. One idea per pull
request. Commit messages are conventional — `feat:`, `fix:`, `docs:`,
`test:`, `refactor:` — with no footers and no tool attribution.

## Structure

```text
lab/
├── mise.toml              # Tools, settings, codebase lint config
├── README.tsx             # Source for generated README.md
├── README.md              # Generated; keep in sync with README.tsx
├── CONTRIBUTING.md        # Repo orientation surface
├── .mise/tasks/test       # Complete public BATS command workflow
├── .mise/tasks/validate   # Aggregate checks, logs, and lifecycle ownership
├── .mise/tasks/doctor     # Local health checks + optional hook status
├── lib/                   # Sourced code shared by multiple commands
└── test/                  # BATS tests and helpers
```

## Local setup

```bash
mise trust
mise install
mise run validate
mise run doctor
```

`doctor` reports whether the optional local `codebase pre-commit` hook is installed.
Install it in your clone when you want convention lints to run before every commit:

```bash
codebase pre-commit
```

The hook lives under `.git/hooks/`, so it is intentionally not tracked by the repo.

## Parallel test contract

`mise run test` uses the KKL-maintained Bats fork and Rush with a measured
four-job default. Isolated tests can run concurrently across separate `.bats`
files and within one file.

Override the measured default when needed:

```bash
mise run test --jobs 4
BATS_NUMBER_OF_PARALLEL_JOBS=2 mise run test
mise run test --jobs 1  # serial debugging
```

Parallel tests must isolate mutable state per test and process. Prefer
`$BATS_TEST_TMPDIR`, unique ports, and fixture-local repositories. Do not share
fixed files, services, HOME overrides, or repository mutations across tests. A
copied suite that is not yet isolated should opt into one job until it is safe.

## README workflow

Edit `README.tsx`, then regenerate and check the output:

```bash
readme build
readme build --check
```

CI also checks that `README.md` matches `README.tsx`.

## Conventions inherited from the skeleton

1. Keep the complete test runner in `.mise/tasks/test` so the public task is the tested workflow.
1. Keep other public `.mise/tasks` readable and command-shaped; extract sourced code under `lib/` only when multiple commands share one domain contract.
1. Keep tests calling tasks through `mise run`, not by invoking `.mise/tasks/*` or `libexec/*` directly.
1. If the tool resolves caller-relative paths after shiv install, use the package-scoped `<PACKAGE>_CALLER_PWD` variable.
1. Keep parallel tests isolated per test/process, or use one job until shared state is removed.
1. Preserve the validation ownership and evidence contracts below when replacing this skeleton's checks.

## Reference validation workflow

```bash
mise run validate                      # compact local results; private full logs
mise run validate --verbose            # full output for an ephemeral CI runner
BATS_NUMBER_OF_PARALLEL_JOBS=1 mise run validate
```

This is the before-merge gate. Local development and CI invoke the same task;
CI uses `--verbose` so detailed failures survive its ephemeral filesystem in the
ordinary masked job log. The individual commands remain useful for focused work:
`mise run test`, `codebase lint "$PWD"`, `readme build --check`, and
`git diff --check`. `doctor` reports setup health, not aggregate acceptance.

The aggregate-gate declaration requires **Codebase 0.5 or later**. A `0.4`
tool pin will not pick up this feature.

`[_.codebase].ci_lint_gate` explicitly declares `mise run validate --verbose` as
this repository's lint-owning CI command. Codebase checks the complete CI step
and its failure-propagation settings; it does not inspect or execute the task.
The declaration is a trust boundary, not automatic discovery: the public-task
tests prove lint is in the inventory and its failure makes validation fail.
Keep the declaration aligned with CI when adopting or renaming the gate. Without
an opt-in declaration, Codebase still requires direct `codebase lint` in CI.

### One gate, explicit ordering, one owner of each concurrency budget

The complete workflow and its command inventory live in `.mise/tasks/validate`.
The four checks are independent and run serially at the aggregate level. A failed
check is recorded, then the other independent checks still run. Infrastructure
failure or interruption stops admission; unstarted checks remain `NOT-RUN`.
BATS/Rush alone owns the existing test concurrency and its overrides. Codebase
owns its rule scheduling. Do not add a competing pool without measuring the
whole workload and accounting for nested parallelism and shared writes.

A copied codebase may need real prerequisites. Add the new names to `checks`
and keep the explicit `run_check` calls beside that inventory. For example, a
build-dependent suite should be admitted only after its build succeeds:

```bash
# Include build and tests in checks so skipped work has a NOT-RUN result.
if run_check build your-build-command; then
  run_check tests mise run test || failed=1
else
  failed=1
fi
# Independent lint/documentation checks can still run afterward.
```

Do not equate command order with dependency success. There is no invented build
phase in this skeleton, and no generic scheduler hiding that policy. The ordinary
Unix command selectors `CODEBASE` and `README` can select alternate executables;
their defaults are the declared tools. `doctor` also honors `CODEBASE` for both
lint and optional-hook checks, so diagnostics assess the same selected tool.
The tests use those selectors to isolate check outcomes without replacing the
public mise dispatcher.

### Compact output is a view, not discarded evidence

Each invocation creates a distinct private temporary directory, printed at
startup. Directories are mode 0700; files are mode 0600. It contains complete
combined `<check>.log` output, shell-quoted `<check>.command` arguments,
per-check `.result` receipts, `supervisor.pid`, and `report.tsv`. Timing uses
Bash's whole-second clock; it is operational context, not a benchmark.

The TSV columns are `check`, `status`, `exit_code`, `seconds`, and `process_group`.
The final `run` row is the whole-run verdict. Check exit codes are preserved;
the aggregate exits 0 only on complete success and 1 on check or lifecycle
failure. SIGINT/SIGTERM exit 130/143 unless cleanup itself fails. A dash means
not observed or not applicable, never a fabricated success. Check receipts show
ongoing work while the initial aggregate report remains `RUNNING`; the terminal
report replaces it atomically at finalization.

Default output is one timed result per check and a final verdict. Failures show
at most the last 1,200 bytes / eight lines plus the exact full-log path. Use
`--verbose` to print complete logs, or open the retained file directly. Logs and
arguments are private, not redacted: do not put secrets in command arguments or
upload raw run directories. Remove a run directory when its evidence is no
longer needed. SIGKILL or a machine crash cannot finalize a report; a surviving
`RUNNING` row is incomplete evidence, not acceptance.

### Cleanup belongs to the final verdict

The Bash task owns one process group per admitted check. On interruption it
sends TERM, allows a short grace period, then sends KILL to the owned group.
It also contains descendants when their immediate command exits first. Checks
must remain noninteractive and must not daemonize or detach into other process
groups. Unexpected signal errors are failures, not interpreted as missing
processes. An uncertain cleanup preserves logs and process identities for owner
inspection; never blindly signal an old recorded PID after it might be reused.

The supervisor publishes the final report and summary only after cleanup.
A passing check stays a passing check even when cleanup makes the whole run
`ERROR`. A failure to publish the terminal report stays nonzero and cannot print
whole-run `PASS`. The tests cover those negative boundaries, including actual
BATS/Rush interruption, rather than merely checking that green output is short.

These checks do not install dependencies or write build outputs, and their test
fixtures are isolated. There is no worktree lock. If an adopter adds shared
writes, revisit ordering and exclusion before allowing overlapping runs; do not
inherit a safety claim that this skeleton has not established.

## Releasing

A tag is an install target, not a bookmark: bare `shiv install lab` takes
the newest release tag, and `shiv update lab` on any machine advances to
it. So:

- tag on `main` only, once the gates are green there;
- `v` prefix and bare semver — `v0.2.0`, never `0.2.0` or `v0.2.0-rc1`;
- `mise run version` on the tagged commit prints the tag, and a lab made
  from it records the tag in its README's attribution line.
