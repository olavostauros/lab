<div align="center">

# peninsula

<img src="logo.jpg" width="220" alt="The Scandinavian Peninsula covered in snow, seen from space" /><br />**The starting point of a lab of agents.**

The rules, the roster, the queue and the checks — in place before the first agent wakes.

![shape: mise + BATS](https://img.shields.io/badge/shape-mise%20%2B%20BATS-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 98](https://img.shields.io/badge/tests-98-brightgreen?style=flat)](test/)
![lints: @all](https://img.shields.io/badge/lints-%40all-blue?style=flat)
![README: TSX](https://img.shields.io/badge/README-TSX-f472b6?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)](LICENSE)

</div>

<br />

## What this is

For anyone who runs a roster of agents against a repository — under any agent harness, or none — and wants the rules, the roster, the queue and the checks in place before the first agent wakes. It runs on git, bash and `mise`, and it is a rewrite of [lab_old](https://github.com/olavostauros/lab_old) on the [KnickKnackLabs skeleton](https://github.com/KnickKnackLabs/trahmpolina): mise-managed tasks, parallel BATS tests, codebase convention lints, a generated README, and CI on ubuntu-latest + macos-latest.

A **lab** is a directory where a roster of agents wake, read their rules, take work from a queue, and return. `peninsula install` gives you one, complete: a contract that says what an agent may do without asking and what only you decide, a roster, a work queue, a lab style, a commit guard that refuses an author who is not on the roster, a steward that keeps the record true, and a set of checks. `peninsula agent add` puts an agent on it, and `peninsula doctor` measures the lab against the shape every lab shares. The command is `peninsula`.

peninsula is [MIT-licensed](LICENSE). A lab it writes belongs to whoever generated it and is not bound by the framework's license.

A lab does not depend on any agent harness. Everything it generates is markdown, bash, git and `mise`; what a runner needs is already in the roster and in each agent's home, and the runner's own files are written outside the lab, by you.

The framework asserts, and a fresh lab is complete. There is no menu of styles, packages or rule sets to choose from, and no question left in the contract for you to answer: the shape and the opinions are the framework's, and what you supply is facts — a name, a project, an owner, a roster — and, later, dated widenings in the contract. `peninsula doctor` calls the lab healthy on the day it is made. `.agents/notes/` encrypts at rest from the first commit — readable in an unlocked checkout, opaque in git. Each larger capability — per-agent accounts and keys, mail, chat, CI wakes — is yours to file and switch on, in your own turn.

## Prerequisites

To run `peninsula`:

- bash 4 or newer, first on `PATH`
- [git](https://git-scm.com) 2.28 or newer, with `user.name` and `user.email` set: `peninsula install` makes a bootstrap commit
- curl, jq, CA certificates for HTTPS, and `sha256sum` or `shasum`: shiv's installer refuses without curl, git and jq; mise's installer checks its download with a sha tool; the `peninsula` shim resolves `peninsula agent add` to `agent:add` through jq
- [shiv](https://github.com/KnickKnackLabs/shiv), which installs [mise](https://mise.jdx.dev) if it is absent; mise runs every `peninsula` command, and `mise install` in the clone brings the tools `mise.toml` pins

To live in a lab: git, bash and mise. A generated lab's own tasks never call shiv, and `peninsula doctor` checks the list above — the bash and git versions, the git identity, mise and jq on `PATH` — and prints the fix for each line it fails. An agent the owner has given an account also needs [secrets](https://github.com/KnickKnackLabs/secrets) and [sops](https://github.com/getsops/sops) on `PATH`; `doctor` says so when the grant is there and the tools are not, and asks for neither otherwise.

## Install

```bash
curl -fsSL shiv.knacklabs.co/install.sh | bash   # installs mise too, if absent
mkdir -p ~/.config/shiv/sources                  # source file: see below
echo '{"peninsula": "olavostauros/peninsula"}' > ~/.config/shiv/sources/peninsula.json
MISE_JOBS=1 shiv install peninsula                   # serial: see below
peninsula --version
```

Restart the shell once after the first line: the installer adds a line to your shell rc and needs it. The source file is needed until `peninsula` is in shiv's own index ([KnickKnackLabs/shiv#176](https://github.com/KnickKnackLabs/shiv/pull/176) is the request): without it, `shiv install peninsula` stops at `'peninsula' not found in package index`. Once that merges, the two source-file lines go; a fork under another name stays the same one line away from being installable as `peninsula` for its owner.

Bare `shiv install peninsula` takes the newest release tag; `shiv install peninsula@main` tracks `main`, `shiv install peninsula@v0.1.0` pins, and `shiv update peninsula` moves an install to the newest release. `peninsula --version` is what a bug report quotes: the tag at the install's `HEAD`, else its short commit, then the branch and the age of the last commit. `peninsula version` is the same tag or short commit from the inside, and it is what a lab records when it is made.

Three things to know about the chain before running it. The installer `eval`s a terminal-UI library fetched over the network at run time, and falls back silently when the fetch fails. The installer does not install shiv's own tools; the first `shiv` command does, and two of them (`shiv:codebase`, `shiv:readme`) race on the backend's clone when mise installs them side by side ([KnickKnackLabs/vfox-shiv#22](https://github.com/KnickKnackLabs/vfox-shiv/issues/22)), which on a clean machine fails every time — `MISE_JOBS=1` on that first command serializes them. And those two are floating `shiv:` ranges in shiv's own `mise.toml`; they are shiv's, not a lab's, and `doctor` does not read them.

### From a checkout

```bash
git clone https://github.com/olavostauros/peninsula
cd peninsula && mise trust && mise install
```

`mise trust` is asked once, because `mise.toml` sets tool and task settings for this directory. Every `peninsula` command in this README is a `mise run` task of this checkout (`peninsula install` is `mise run install`, `peninsula agent add` is `mise run agent:add`, `peninsula version` is `mise run version`), which is how CI runs it:

```bash
mise run install example --at /path/to/example
```

To put a working clone on `PATH` as `peninsula` — the way to try the shim against a branch — register the checkout itself as a local-path package:

```bash
shiv install peninsula "$PWD"
```

## Quick start

Run `peninsula install` with no name and it asks for each fact it needs — where the lab lives, its name, its owner — scaffolds, then offers the roster, the hooks and a first check. Given a name it asks nothing: the flags are the same facts, and CI never sees a prompt.

```bash
# A lab — a new directory that is a repo of its own
peninsula install example --at ~/example --owner 'Your Name'

cd ~/project
peninsula agent add builder --role implementation --owns src/   --charge 'Builds what the queue asks for, under src/.'
peninsula agent add judge --role review   --charge 'Reads every pull request into main before the owner merges it.'

mise run install-hooks
mise run welcome
peninsula doctor            # healthy
```

`--owner` defaults to `git config user.name`, and `install` fails when neither names anyone: the owner's name is the one fact only the owner can supply.

Install makes a new directory and a repo of its own: `--at` must not exist yet, and an existing directory is refused rather than scaffolded into. The lab's name is `LAB_NAME` in its `mise.toml`, never the directory's.

Where the shape came from is history, kept in git and nowhere in the tree: the bootstrap commit names the labs it was distilled from, and `lib/lineage-names` lists them only so `doctor` can reject them in a lab.

## What install writes

| Path                                                   | What it is                                                                                                                                                                                                                                            |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`                                            | the contract: what the lab is, who owns it, the roster, how the owner merges, the three rules that protect the guard and the shared checkout, a Domain rules section, the tiers, the loosenings table, the two-key rule, the Read-first table         |
| `.agents/roster.tsv`                                   | who counts as an agent, with role, owned directory and kind — read by the guard, agent-env, welcome and doctor; the steward is its first row                                                                                                          |
| `.agents/notes/work-queue.md`                          | the owner files entries here, each addressed to one agent                                                                                                                                                                                             |
| `.agents/notes/lab-backlog.md`                         | Tier 2 proposals; empty                                                                                                                                                                                                                               |
| `.agents/notes/lab-style.md`                           | how the lab likes its work done — wired to Read-first; practice, not authority, and the owner's to change                                                                                                                                             |
| `.agents/notes/steward.md`                             | the steward's identity note; its home is .agents/notes/steward-home.md                                                                                                                                                                                |
| `.agents/hooks/agent-identity`                         | pre-commit guard: refuses an author not on the roster unless <LAB>_OWNER_COMMIT=1                                                                                                                                                                     |
| `.agents/tasks/{welcome,test,agent-env,install-hooks}` | the task surface; agent-env sets <name>@<lab>.invalid as the git author — a label on a reserved name that claims no domain — or, with LAB_GH_EMAIL set in mise.toml, an address GitHub attributes to the owner                                        |
| `.agents/test/*.bats`                                  | the lab's own checks, roster-driven so they stay true as agents join                                                                                                                                                                                  |
| `.agents/secrets/`                                     | granted credentials, git-ignored and machine-local: each <name>/ holds an age identity and a secrets sops vault                                                                                                                                       |
| `notes/ at the work root`                              | the product's written memory — docs under notes/docs/, numbered decisions under notes/decisions/, learned facts flat; shared and append-only, and never .agents/notes/, which stays the lab's                                                         |
| `mise.toml, README.md, .gitignore`                     | the rest; the README carries the one line of attribution a lab keeps, Started from peninsula on <date>, at <version> — the version peninsula version printed when the lab was made, which peninsula doctor reads back against the version checking it |

Every lab is a repo of its own with a bootstrap commit, which is where the framework's name goes.

## What is yours

The facts: the lab's name and path, the project and the owner, given to `install`. The roster, and each agent's role, directory and charge, given to `agent add`. The loosenings table, one dated row at a time, in your own turn. A granted account, as a row in that table and two files in `.agents/secrets/<name>/`: an age identity you mint and a `secrets` sops vault. A lighter attribution needs no account: set `LAB_GH_EMAIL` in the lab's `mise.toml` to an address GitHub attributes to you — your `users.noreply.github.com` address works — and `agent-env` stamps it, so every commit still names its agent and links to your account. Everything under `.agents/notes/`, including the lab style and each agent's Stance, which the framework writes and you may change. The contract itself is Tier 2 for every agent and yours alone to edit.

What is not yours is the shape: the tiers, the two-key rule, the markers, the guard, one steward. `peninsula doctor` checks that shape, and it also fails on a leftover `{{KEY}}` or on the name of a lab the framework grew out of (the list is `lib/lineage-names`; `KnickKnackLabs` outside the tool pin is added), because those are the framework's leftovers and never your text. The lab's own name and project are never counted, so a lab that happens to share a name with one of those passes. Where an identity file sits under an agent's workspace, `doctor` also checks what `secrets` will check before an activation can fail on it — the directory and both files owner-only, one age key, a recipient line — proves the identity opens the vault with one `secrets list`, and fails any such file under the steward's workspace. Without the file it says nothing.

If your git config signs commits, `install` says so and names the key before the passphrase prompt can appear, and `--no-commit` avoids it. Every lab's `mise run welcome` reports the same state, and the lab README's **Signing** section says what a signing machine means for the agents: their commits carry the owner's key, and a stalled prompt is reported, never worked around.

## The steward

Every lab has exactly one, and it is always named `steward`. `install` adds it; a second one, or one under another name, is refused by `agent add` and failed by `doctor`. Its work is standing and needs no filing: it measures the queue, the backlog, the notes, the roster and the branches against what is on disk, fixes verified-false facts in `.agents/notes/` on a local branch, files everything else as a backlog proposal, and reports to the owner in the session.

The steward is the lab speaking, so its identity is the lab's. Its home note is `.agents/notes/steward-home.md` — an encrypted note like every agent's — and a runner's definition for it, where one exists, is named after the lab.

It carries **no GitHub account, no signing key and no mail, permanently.** Its note and its home say so, and the contract excludes it from any identity entry the owner files for the other agents. It reads GitHub through the owner's login and writes nothing there; it pushes nothing. The record can be trusted because the one agent whose job is the record has no voice outside the lab.

## What agent add writes

- a row on `.agents/roster.tsv`: name, role, owned directory, kind
- `.agents/notes/<name>.md`, the lab-visible identity, with a Stance the framework writes for the kind — narrowing it is the agent's, widening it is yours
- a bullet under "Who lives here" and a row in the Read-first table
- `.agents/notes/<name>-home.md` and `.agents/notes/<name>-scratchpad.md` — the agent's own startup contract and session memory, encrypted at rest with the rest of the notes; `peninsula agent home <name>` rebuilds them if they are ever lost

Three kinds, and the kind is derived. `--owns <dir>/` makes a **builder**: takes queue entries, works on `<name>/<topic>` branches under its directory, opens PRs, may edit and write. Without `--owns` it is a **judge**: owns nothing, answers in the written record, reads and researches but never patches. The name `steward` makes the one above. Whatever the kind, the owner merges and the owner files the queue.

## Domain rules

A rule set binds one named agent: five or six lines the code can be checked against, in the contract's "Domain rules" section. That section says when to write one — when an agent's mistakes would be permanent or expensive — and the shape it takes, and you write it there, in your own turn. The framework ships none: it does not know your domain.

## Harnesses

Nothing above knows which runner the agents wake under, and no generated file names one. What a runner needs is already in the lab: `.agents/roster.tsv` (name, role, owned directory, kind), each home's `AGENTS.md` as the agent's brief, and the rule that the steward's file is named after the lab. A runner's definition is a projection of those, written outside the lab by you, in your own turn; the lab contract makes every such definition Tier 2, and nothing in this repository writes one. The framework names no runner.

## Invariants

These hold in every lab, and `peninsula doctor` checks the ones a script can:

- **The contract is authority-only** and enumerated once. Tiers, loosenings and the owner-only list live in `AGENTS.md` and nowhere else; definitions, homes and notes link to them and never restate them.
- **Narrowing is the agent's; widening is the owner's**, in the owner's own turn, as a dated row in the loosenings table.
- **Relayed approval is not approval.** Only the owner's turn or a permission prompt is consent.
- **Nobody merges but the owner**, until a loosening says otherwise.
- **The roster is one file**, and the guard fails closed without it.
- **Homes are the agent's boundary**, not the lab's: `agent add` creates them once and never overwrites them.
- **The lab is harness-agnostic.** `install`, `agent add` and `doctor` never read or write a runner's files.
- **There is one steward, named steward, homed at .agents/notes/steward-home.md.** It has no outward identity, and no upgrade path gives it one.
- **A fresh lab is complete.** The framework asserts; the owner supplies facts and grants widenings. `peninsula install x && peninsula doctor --lab x` exits 0, and no generated file names a lineage or a runner, or depends on a toolchain outside the `bats` pin.

## Tasks

| Task                  | Description                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------ |
| `mise run agent:add`  | Put an agent on a lab's roster: identity note and home notes                                                 |
| `mise run agent:home` | Create the home notes of a rostered agent that lacks them                                                    |
| `mise run doctor`     | Check a lab against the framework's invariants                                                               |
| `mise run install`    | Install a lab: contract, roster, queue, style, guard, steward and tasks — a new directory, a repo of its own |
| `mise run test`       | Run BATS tests                                                                                               |
| `mise run validate`   | Run all validation checks with compact results and private full logs                                         |
| `mise run version`    | Print the framework version: the tag at HEAD, else the short commit, else unknown                            |

Every public task is also a shim command — `peninsula install`, `peninsula doctor`, `peninsula version`, `peninsula agent add`, `peninsula agent home`, `peninsula test`, `peninsula validate` — and nothing is hidden; the shim resolves `agent add` to `agent:add` through jq.

## Development

```bash
mise trust
mise install
mise run validate      # tests, codebase lint, generated-README check, whitespace
mise run test          # parallel BATS only, for focused runs
readme build           # regenerate README.md after editing README.tsx
mise run version       # what a lab made from this checkout records
git diff --check
```

The tests scaffold labs into temporary directories — homes included — and `PENINSULA_DEFINITIONS_DIR` points at an empty directory they assert stays empty: nothing here writes a runner's files. Nothing under your home is touched.

The canonical test task uses the [KKL-maintained Bats fork](https://github.com/KnickKnackLabs/bats-core) with [Rush](https://github.com/shenwei356/rush) and a measured four-job default. Isolated tests can run concurrently across separate files and within one file:

```bash
mise run test                         # measured four-job default
mise run test --jobs 4                # explicit job count
BATS_NUMBER_OF_PARALLEL_JOBS=2 mise run test
mise run test --jobs 1                # serial debugging
```

Parallel suites must isolate mutable state per test and process. Use `$BATS_TEST_TMPDIR`, unique ports, and fixture-local repositories instead of shared files, services, HOME overrides, or repository mutations.

How a release is cut and how to propose a change is in [CONTRIBUTING.md](CONTRIBUTING.md); what a change must preserve is in [AGENTS.md](AGENTS.md).

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

The suite currently has **98 tests** and **7 public tasks**. Those numbers are read from the repo at README build time.

<div align="center">

---

<sub>
This README was generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />A skeleton is a kindness to whoever has to remember the boring parts tomorrow.
</sub></div>
