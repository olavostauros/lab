---
title: Reference validation workflow
type: plan
status: done
owner: kabir
created: 2026-09-07
updated: 2026-09-08
---

# Reference validation workflow

## Outcome

Landed through [Trahmpolina PR #17](https://github.com/KnickKnackLabs/trahmpolina/pull/17)
at `02d25a4`. Released-tool local acceptance passed all 23 tests and 19 lint
rules; [main CI](https://github.com/KnickKnackLabs/trahmpolina/actions/runs/34229727456)
passed on Ubuntu and macOS. The required Codebase policy landed through
[PR #149](https://github.com/KnickKnackLabs/codebase/pull/149) and was released
as v0.5.0; Trahmpolina selects its `0.5` stream.

Other repositories pinned to `0.4` do not automatically receive this feature.
Adopters of `ci_lint_gate` need `0.5`; direct-lint repositories can remain on
`0.4`. A broader consumer-pin inventory is deferred, not part of this completed
reference implementation. The sections below retain the implementation and
validation history rather than describing unfinished work.

## Purpose

This skeleton should teach the complete validation pattern to its adopters, not
merely hide noisy output. A reader should find one public gate, see which checks
it owns and how they depend on one another, understand the concurrency budget,
and be able to inspect failures and interruption without mistaking partial work
for success.

## Interface and ownership

- `.mise/tasks/validate` is the complete public aggregate workflow in Bash.
  It runs the existing tests, Codebase lints, generated-README check, and Git
  whitespace check. `--verbose` prints full check logs for ephemeral CI.
- These four checks are independent and run serially at the aggregate level.
  A failed check does not prevent the remaining independent checks from running.
  An interruption or infrastructure failure stops admission of later checks.
  There is no invented build phase in a skeleton that does not need one.
- `.mise/tasks/test` remains unchanged and owns the complete BATS command.
  BATS/Rush owns its existing test parallelism and override semantics. The
  aggregate does not introduce another parallel pool.
- The aggregate owns private run logs, per-check statuses/exit codes/timing,
  subprocess containment, and the final whole-run outcome. Successful checks
  cannot make an interrupted or failed-cleanup run pass.
- New repos extend the explicit command list. Actual prerequisites must finish
  successfully before their dependents are admitted; independent checks may
  continue after peer failure. Document that distinction rather than implying
  command order alone proves a dependency.

The lifecycle and command list remain together in the public task because they
form one workflow with one consumer. Do not extract a generic framework or a
single-consumer library merely to make the task file shorter. `doctor` remains
an observational setup-health command, not a second aggregate gate.

## Evidence and cleanup boundary

Use a new private temporary log directory per invocation. Keep full combined
stdout/stderr there, print one timed result per check, and show only a bounded
failure excerpt by default. Logs are private, not redacted. CI uses verbose
output in its ordinary masked job log; do not upload raw private run directories.

Prove Bash process-group handling on the real public mise path before claiming
interruption safety, including nested children and early parent exit. The
checks are noninteractive and must not detach into independent process groups.
Unexpected signaling or report-publication errors must remain nonzero and leave
recoverable evidence. No worktree lock is proposed for these nonmutating,
isolated checks; adding installs/build writes later requires revisiting that
boundary rather than inheriting an unsupported concurrency claim.

## Proof and adoption documentation

BATS public-path fixtures will cover exact command inventory, serial aggregate
admission, independent failure continuation, preserved exit codes/full logs,
bounded output, private directories/files, verbose output, interrupted/not-run
outcomes, and nested-process cleanup. Keep existing real test-task concurrency
and argument tests intact. Test Bash 3.2 compatibility and run the real aggregate
after focused checks. Review the whole resulting slice as a copyable reference.

Update CONTRIBUTING and README.tsx, regenerate README.md, and make CI invoke the
same gate. Explain where adopters add checks and prerequisites, which component
owns parallelism, how to inspect results, and what cleanup does and does not
cover. Do not claim performance gains from this small scaffold.

## Current proof and policy integration

The ten new public-path validation contract tests pass on macOS Bash 3.2, including real
BATS/Rush interruption, SIGINT/SIGTERM, early-parent-exit descendant cleanup,
full private logs, failure continuation, and final-report/signaling failures.
A temporary mutation omitting KILL made the descendant regression fail on the
actual surviving process; the mutation was removed. ShellCheck, actionlint,
README regeneration/check, and whitespace checks pass.

Initial fixture PATH overlays did not select their commands under mise 2026.8.10.
The fixtures now copy the real public task, select synthetic Codebase/README
executables explicitly, and use a real isolated Git repository. They do not
replace the mise dispatcher. A macOS canonical-path assertion was corrected,
and ineffective BATS negation assertions were replaced with expected-exit checks
before accepting the lifecycle proof.

The initial real aggregate ran all four checks. Its remaining blocker was
Codebase 0.4.7's `lint:ci-lint-enforcement`, which required a whole GitHub Actions
run step containing only direct `codebase lint` (or `mise exec -- codebase lint`).
That version did not follow public validation tasks, so it rejected the new
shared local/CI gate even though Codebase failure propagated. This also failed
the doctor smoke because doctor ran the same lint portfolio. All other
convention rules passed after correcting Bash-3.2 array forms and annotating
the valid generated-task root reference.

Or subsequently approved the corresponding local Codebase change. It adds the
explicit `[_.codebase].ci_lint_gate` declaration, retains direct lint by default,
and keeps whole-step matching, shell, expression, and continue-on-error checks.
The declaration trusts the repository's tested aggregate; it does not trace or
execute task internals. Trahmpolina declares `mise run validate --verbose`.

Codebase's focused policy suite passed 37 tests and its full suite passed 423.
The integrated Trahmpolina gate passed all four checks and 21 BATS tests using
an explicit executable selector for the local Codebase source. An initial
exported-function selector was lost in the nested BATS doctor path, which
correctly exposed the old installed policy again. `doctor` now honors the same
`CODEBASE` selector for lint and optional-hook checks; its regression passes.
No installed package or tool pin was changed to manufacture acceptance.

Final review added a direct lint-failure regression to back the trust declaration
specifically, rather than relying only on the existing generic failed-check test.
That new 22nd test passed through the public test task. README was regenerated
and checked for 22 tests, then the final integrated gate passed all four checks:
22 BATS tests, all 19 Codebase rules through the explicit local source executable,
generated README, and whitespace. Its final report records PASS/exit zero for
every check and the whole run. This is local macOS acceptance, not an installed
release or hosted-CI result. A temporary mutation prepared for that test was
restored before execution; it is not claimed as falsification evidence.

Or subsequently approved review, Codebase publication/release, released-tool
acceptance, and Trahmpolina landing. Codebase's signed candidate landed through PR #149;
its initial hosted run failed before tests because mise-action selected an
unavailable `2026.9.3` release. Both workflows now pin the locally validated
`2026.8.10` with verified Linux/macOS release assets, and actionlint passes.
Codebase v0.5.0 was released at `49c1d8f` with a Kabir-signed tag; both PR and
main CI passed on Ubuntu and macOS. Trahmpolina now selects its `0.5` stream.

Final review also found that interruption before a new check launched could
reuse the previous check's PID through the cleanup fallback. A deterministic
public-path regression failed on those repeated cleanup signals. The task now
records pending signals and handles them at admission/wait boundaries after
child identity is established, with no stale-PID fallback. All ten validation
contract tests pass, including the new pre-launch case and the existing nested
process interruption cases. README is regenerated for 23 repository tests.
BATS-specific ShellCheck diagnostics on independent per-test exports have narrow,
explained annotations; the changed task/test and workflows pass static checks.

The normal Trahmpolina gate subsequently passed against installed Codebase
v0.5.0 with both source executable selectors unset: 23 tests, all 19 configured
lint rules, generated README, and whitespace. The installed source head matches
the released commit, and private log/report modes remain 0700/0600.
This proves released-tool local acceptance; the pull request and main CI record
hosted acceptance separately. Resulting-slice self-review covered command and
concurrency ownership, lifecycle failure paths, the declared-gate trust boundary,
and the teaching surface. No independent peer approval is implied.

## Non-goals and authority

No Bun/Nu dependency, new scheduler, Codebase policy copy, shared jobserver,
product commands, optional-hook provisioning, or NVR changes. Or approved this
local implementation and validation boundary, then separately approved landing
and release in dependency order. Reviewer contact remains a separate boundary;
no peer approval is inferred from self-review or repository access.
