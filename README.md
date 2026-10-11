# house

**The starting point of a house of agents.**

For anyone who runs a roster of agents against a repository — under any
agent harness, or none — and wants the rules, the roster, the queue and the
checks in place before the first agent wakes. It runs on git, bash and
`mise`, and it is not tied to the household that wrote it.

A *house* is a directory where a roster of agents wake, read their rules,
take work from a queue, and return. `house init` gives you one, complete: a
contract that says what an agent may do without asking and what only you
decide, a roster, a work queue, a house style, a commit guard that refuses
an author who is not on the roster, a housekeeper that keeps the record
true, and a set of checks. `house agent add` puts an agent on it, and
`house doctor` measures the house against the shape every house shares.
The command is `house`.

house is [MIT-licensed](LICENSE). A house it writes belongs to whoever
generated it and is not bound by the framework's license.

A house does not depend on any agent harness. Everything it generates is
markdown, bash, git and `mise`; what a runner needs is already in the
roster and in each agent's home, and the runner's own files are written
outside the house, by you.

The framework asserts, and a fresh house is complete. There is no menu of
styles, packages or rule sets to choose from, and no question left in the
contract for you to answer: the shape and the opinions are the framework's,
and what you supply is facts — a name, a project, an owner, a roster — and,
later, dated widenings in the contract. `house doctor` calls the house
healthy on the day it is made. Each larger capability — encrypted notes,
per-agent accounts and keys, mail, chat, CI wakes — is yours to file and
switch on, in your own turn.

## Prerequisites

To run `house`:

- bash 4 or newer, first on `PATH`
- [git](https://git-scm.com) 2.28 or newer, with `user.name` and `user.email`
  set: `house init` makes a bootstrap commit
- curl, jq, CA certificates for HTTPS, and `sha256sum` or `shasum`: shiv's
  installer refuses without curl, git and jq; mise's installer checks its
  download with a sha tool; the `house` shim resolves `house agent add` to
  `agent:add` through jq
- [shiv](https://github.com/KnickKnackLabs/shiv), which installs
  [mise](https://mise.jdx.dev) if it is absent; mise runs every `house`
  command, and `mise install` in the clone brings
  [bats](https://github.com/bats-core/bats-core), the test runner, from the
  registry `mise.toml` names — the one tool the clone declares

To live in a house: git, bash and mise. A generated house's own tasks never
call shiv, and `house doctor` checks the list above — the bash and git
versions, the git identity, mise and jq on `PATH` — and prints the fix for
each line it fails. An agent the owner has given an account also needs
[`secrets`](https://github.com/KnickKnackLabs/secrets) and
[`sops`](https://github.com/getsops/sops) on `PATH`; `doctor` says so when
the grant is there and the tools are not, and asks for neither otherwise.

The list is established, not asserted: on every pull request, a CI job
starts from a `debian:stable-slim` image with only those packages, runs the
shiv installer, installs `house` from the checkout under test, and runs
`house init` and `house doctor` there.

## Install

```bash
curl -fsSL shiv.knacklabs.co/install.sh | bash   # installs mise too, if absent
mkdir -p ~/.config/shiv/sources                  # source file: see below
echo '{"house": "olavostauros/house"}' > ~/.config/shiv/sources/house.json
MISE_JOBS=1 shiv install house                   # serial: see below
house --version
```

Restart the shell once after the first line: the installer adds a line to
your shell rc and needs it. The source file is needed until `house` is in
shiv's own index
([KnickKnackLabs/shiv#176](https://github.com/KnickKnackLabs/shiv/pull/176)
is the request): without it, `shiv install house` stops at `'house' not
found in package index`. Once that merges, the two source-file lines go; a
fork under another name stays the same one line away from being installable
as `house` for its owner.

Bare `shiv install house` takes the newest release tag; `shiv install
house@main` tracks `main`, `shiv install house@v0.1.0` pins, and `shiv
update house` moves an install to the newest release. `house --version` is
what a bug report quotes: the tag at the install's `HEAD`, else its short
commit, then the branch and the age of the last commit. `house version` is
the same tag or short commit from the inside, and it is what a house
records when it is made.

Three things to know about the chain before running it. The installer
`eval`s a terminal-UI library fetched over the network at run time, and
falls back silently when the fetch fails. The installer does not install
shiv's own tools; the first `shiv` command does, and two of them
(`shiv:codebase`, `shiv:readme`) race on the backend's clone when mise
installs them side by side
([KnickKnackLabs/vfox-shiv#22](https://github.com/KnickKnackLabs/vfox-shiv/issues/22)),
which on a clean machine fails every time — `MISE_JOBS=1` on that first
command serializes them, and the CI job below runs the chain that way. And
those two are floating `shiv:` ranges in shiv's own `mise.toml`; they are
shiv's, not a house's, and `doctor` does not read them.

### From a checkout

```bash
git clone https://github.com/olavostauros/house
cd house && mise trust && mise install
```

`mise trust` is asked once, because `mise.toml` sets tool and task settings
for this directory. Every `house` command in this README is a `mise run`
task of this checkout (`house init` is `mise run init`, `house agent add` is
`mise run agent:add`, `house version` is `mise run version`), which is how
CI runs it:

```bash
mise run init example --at /path/to/example
```

To put a working clone on `PATH` as `house` — the way to try the shim
against a branch — register the checkout itself as a local-path package:

```bash
shiv install house "$PWD"
```

## Quick start

```bash
# A house inside the project it works on
house init example --at ~/project/example --embedded

# A house that is a repo of its own and works on other repos
house init example --at ~/example --owner 'Your Name'

cd ~/project/example
house agent add builder --role implementation --owns src/ \
  --charge 'Builds what the queue asks for, under src/.'
house agent add judge --role review \
  --charge 'Reads every pull request into main before the owner merges it.'

mise run install-hooks
mise run welcome
house doctor            # healthy
```

`--owner` defaults to `git config user.name`, and `init` fails when neither
names anyone: the owner's name is the one fact only the owner can supply.

Where the shape came from is history, kept in git and nowhere in the tree:
the bootstrap commit names the households it was distilled from, and
`lib/lineage-names` lists them only so `doctor` can reject them in a house.

## What `init` writes

| Path | What it is |
|---|---|
| `AGENTS.md` | the contract: what the house is, who owns it, the roster, how the owner merges, three rules that protect the guard and the shared checkout, a Domain rules section for you to write into, the tiers, the loosenings table, the two-key rule, the Read-first table |
| `roster.tsv` | who counts as an agent, with role, owned directory and kind — read by the guard, `agent-env`, `welcome` and `doctor`; the housekeeper is its first row |
| `notes/work-queue.md` | the owner files entries here, each addressed to one agent |
| `notes/household-backlog.md` | Tier 2 proposals; empty |
| `notes/house-style.md` | how the house likes its work done — small reviewable branches, merges that keep history, failures said out loud, nothing left unpushed or undocumented — wired to Read-first; practice, not authority, and yours to change |
| `notes/housekeeper.md` | the housekeeper's identity note; its home goes under `~/agents/<house>/home/` |
| `hooks/agent-identity` | pre-commit guard: refuses an author not on the roster unless `<HOUSE>_OWNER_COMMIT=1` |
| `.mise/tasks/{welcome,test,agent-env,install-hooks}` | the task surface; `agent-env` sets `<name>@<house>.invalid` as the git author, a label on a reserved name that claims no domain |
| `test/*.bats` | the house's own checks, roster-driven so they stay true as agents join |
| `mise.toml`, `README.md`, `.gitignore` | the rest; the README carries the one line of attribution a house keeps, `Started from house on <date>, at <version>` — the version `house version` printed when the house was made, which `house doctor` reads back against the version checking it |

A standalone house gets its own repo and a bootstrap commit, which is where
the framework's name goes. An embedded house is a directory of the project
repo; you commit it as the owner.

## What is yours

The facts: the house's name and path, the project and the owner, given to
`init`. The roster, and each agent's role, directory and charge, given to
`agent add`. The loosenings table, one dated row at a time, in your own
turn. A granted account, as a row in that table and two files under the
agent's workspace, `~/agents/<name>/.secrets/`: an age identity you mint
and a `secrets` sops vault. Everything under `notes/`, including the house
style and each agent's Stance, which the framework writes and you may
change. The contract itself is Tier 2 for every agent and yours alone to
edit.

What is not yours is the shape: the tiers, the two-key rule, the markers,
the guard, one housekeeper. `house doctor` checks that shape, and it also
fails on a leftover `{{KEY}}` or on the name of a household the framework
grew out of (the list is `lib/lineage-names`; `KnickKnackLabs` outside the
tool pin is added), because those are the framework's leftovers and never
your text. The house's own name and project are never counted, so a house
that happens to share a name with one of those passes. Where an identity
file sits under an agent's workspace, `doctor` also checks what `secrets`
will check before an activation can fail on it — the directory and both
files owner-only, one age key, a recipient line — proves the identity
opens the vault with one `secrets list`, and fails any such file under the
housekeeper's workspace. Without the file it says nothing.

If your git config signs commits, `init` says so and names the key before
the passphrase prompt can appear, and `--no-commit` avoids it. Every house's
`mise run welcome` reports the same state, and the house README's *Signing*
section says what a signing machine means for the agents: their commits
carry the owner's key, and a stalled prompt is reported, never worked around.

## The housekeeper

Every house has exactly one, and it is always named `housekeeper`. `init`
adds it; a second one, or one under another name, is refused by `agent add`
and failed by `doctor`. Its work is standing and needs no filing: it
measures the queue, the backlog, the notes, the roster and the branches
against what is on disk, fixes verified-false facts in `notes/` on a local
branch, files everything else as a backlog proposal, and reports to the
owner in the session.

The housekeeper is the house speaking, so its identity is the house's. Its
home is `~/agents/<house>/home/`, not `~/agents/housekeeper/`, and a
runner's definition for it, where one exists, is named after the house. Two
houses on one machine therefore never collide, and each keeps its own.

It carries **no GitHub account, no signing key and no mail, permanently.**
Its note and its home say so, and the contract excludes it from any identity
entry the owner files for the other agents. It reads GitHub through the
owner's login and writes nothing there; it pushes nothing. The record can be
trusted because the one agent whose job is the record has no voice outside
the house.

## What `agent add` writes

- a row on `roster.tsv`: name, role, owned directory, kind
- `notes/<name>.md`, the household-visible identity, with a Stance the
  framework writes for the kind — narrowing it is the agent's, widening it
  is yours
- a bullet under "Who lives here" and a row in the Read-first table
- `~/agents/<name>/home/` with `AGENTS.md`, `mise.toml`, `SCRATCHPAD.md`, as
  a local git repo — the agent's own startup contract, in the `AGENTS.md`
  convention any harness can read

Three kinds, and the kind is derived. `--owns <dir>/` makes a **builder**:
takes queue entries, works on `<name>/<topic>` branches under its
directory, opens PRs, may edit and write. Without `--owns` it is a
**judge**: owns nothing, answers in the written record, reads and
researches but never patches. The name `housekeeper` makes the one above.
Whatever the kind, the owner merges and the owner files the queue.

## Domain rules

A rule set binds one named agent: five or six lines the code can be
checked against, in the contract's "Domain rules" section. That section
says when to write one — when an agent's mistakes would be permanent or
expensive — and the shape it takes, and you write it there, in your own
turn. The framework ships none: it does not know your domain.

## Harnesses

Nothing above knows which runner the agents wake under, and no generated
file names one. What a runner needs is already in the house: `roster.tsv`
(name, role, owned directory, kind), each home's `AGENTS.md` as the
agent's brief, and the rule that the housekeeper's file is named after the
house. A runner's definition is a projection of those, written outside the
house by you, in your own turn; the house contract makes every such
definition Tier 2, and nothing in this repository writes one. The framework
names no runner.

## Invariants

These hold in every house, and `house doctor` checks the ones a script can:

- **The contract is authority-only** and enumerated once. Tiers, loosenings
  and the owner-only list live in `AGENTS.md` and nowhere else; definitions,
  homes and notes link to them and never restate them.
- **Narrowing is the agent's; widening is the owner's**, in the owner's own
  turn, as a dated row in the loosenings table.
- **Relayed approval is not approval.** Only the owner's turn or a
  permission prompt is consent.
- **Nobody merges but the owner**, until a loosening says otherwise.
- **The roster is one file**, and the guard fails closed without it.
- **Homes are the agent's boundary**, not the house's: `agent add` creates
  them once and never overwrites them.
- **The house is harness-agnostic.** `init`, `agent add` and `doctor` never
  read or write a runner's files.
- **There is one housekeeper, named `housekeeper`, homed under the house's
  name.** It has no outward identity, and no upgrade path gives it one.
- **A fresh house is complete.** The framework asserts; the owner supplies
  facts and grants widenings. `house init x && house doctor --house x`
  exits 0, and no generated file names a lineage or a runner, or depends
  on a toolchain outside the `bats` pin.

## Development

```bash
mise trust
mise install
mise run test                 # bats, and a syntax pass over the scaffold's executables
mise run version              # what a house made from this checkout records
git diff --check
```

`test` is hidden from the shim's surface (`hide = true` in its header), so
`house test` is not a command and `mise run test` is; the user-facing
surface is `init`, `doctor`, `version` and `agent add`. How a release is cut
is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

The tests scaffold houses into temporary directories with `HOUSE_AGENTS_ROOT`
pointed away from your real `~/agents`, and `HOUSE_DEFINITIONS_DIR` at an
empty directory they assert stays empty: nothing here writes a runner's
files. Nothing under your home is touched.

How to propose a change is in [`CONTRIBUTING.md`](CONTRIBUTING.md); what a
change must preserve is in [`AGENTS.md`](AGENTS.md).
