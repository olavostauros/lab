# lab

A tool repo, not a lab. There is no roster here and no queue; `notes/`
is this repo's own written memory — a lab's notes come only from
`scaffold/`, and the labs this shape was distilled from are named in
`lib/lineage-names` and in git history, nowhere else. This file is the
contract for this repository, for whoever's agent works on it — yours,
under any harness or none, with no lab behind it. It says what the repo
must preserve and what a change needs;
[`CONTRIBUTING.md`](CONTRIBUTING.md) has the mechanics. An agent that
does belong to a lab is still governed by that lab's contract; this one
governs the repo.

This repo is a rewrite of the tool now archived at
[olavostauros/lab_old](https://github.com/olavostauros/lab_old), on the
KnickKnackLabs skeleton. The invariants below are the product's, carried
over unchanged; the skeleton owns the mechanics (the `validate` gate,
parallel BATS, the generated README, the `codebase` lints).

## What this repo must preserve

`scaffold/lab/` is the lab every owner gets, byte for byte but for the
facts, and `scaffold/lab/AGENTS.md` is the contract every new lab
starts from. The framework asserts the shape and the opinions; the owner
supplies facts and, later, dated widenings. A change to the scaffold
changes the lab every future owner gets, so the same discipline applies
here as in a live lab:

- **The tiers, the two-key rule and the loosenings table stay whole and in
  one place** in the scaffold's contract. Do not split them, summarise them
  elsewhere, or add a second copy in a home or a definition.
- **The scaffold only narrows by default.** A widening — an agent that may
  merge, push `main`, or act on relayed approval — is never the starting
  point. A lab grants it as a dated row after it exists.
- **The two markers** (`lab:roster`, `lab:read-first`) are
  load-bearing: `agent add` inserts at them and `doctor` checks for them.
  Rename one and every existing lab fails `doctor`.
- **A fresh lab is complete.** The framework asserts; the owner supplies
  facts and grants widenings. `init` asks nothing: no `lab:decide`
  marker exists in `scaffold/` or in a rendered lab, no flag selects a
  file, every lab gets its steward, and
  `lab init x && lab doctor --lab x` exits 0. Where only the owner
  can answer — the owner's name — `init` takes the fact as an argument and
  fails without it. What the framework used to ask, it now states: what a
  lab is, how the owner merges, the lab style, the author domain, what
  is not there yet, each agent's Stance. `doctor` still fails a leftover
  `{{KEY}}` and every name a `lab` line of `lib/lineage-names` lists
  (`KnickKnackLabs` outside `mise.toml` too), because those are the
  framework's and never the owner's text.
- **A lab is `AGENTS.md` plus `.agents/`.** The contract sits at the lab
  root; the roster, notes, guard, tasks, checks and agent homes all live
  under `.agents/`, and `.agents/home/` is git-ignored so a home stays
  private. `init --embedded` with no `--at` puts `AGENTS.md` and
  `.agents/` at the project repo's root; `--at` takes any path inside
  the repo. Existing files are kept: a project `AGENTS.md`, `mise.toml`
  or `.gitignore` is never overwritten — `init` says what to merge, and
  `doctor` fails until the markers and the env block are in. The lab's
  name stays `LAB_NAME`, never the directory's.
- **`notes/` at the work root is the product's written memory, and
  `docs/` lives under it.** `init` emits `notes/` there — product docs
  under `notes/docs/`, numbered decisions under `notes/decisions/`,
  learned facts flat — while `.agents/notes/` stays lab machinery: queue,
  backlog, style, identity. The contract names the split, grants any
  agent a *new* file there and keeps edits Tier 2. A top-level `docs/` is
  the older layout; `init` and `doctor` both say so.
- **Substitution is facts only, and the list is closed.** A key in a
  scaffold file names a fact the lab or the agent has; it never selects a
  passage. The lab facts are `{{LAB_NAME}}`, `{{LAB_UPPER}}`,
  `{{LAB_PATH}}`, `{{WORK_PATH}}`, `{{WORK_DIR_EXPR}}`, `{{PROJECT}}`,
  `{{CREATED}}`, `{{FRAMEWORK_VERSION}}` and `{{OWNER}}`;
  `{{AUTHOR_DOMAIN}}` is derived from the name; `{{PLACEMENT}}` is the one
  two-way structural fact, embedded or standalone. The agent facts are
  `{{AGENT}}`, `{{ROLE}}`, `{{OWNS}}`, `{{CHARGE}}`, `{{WORKSPACE_PATH}}`
  and `{{HOME_PATH}}`.
  `test/own_lab.bats` greps `scaffold/` and fails on any key outside
  this list, and on any key in this list that this paragraph does not
  name. A key that would select text is a template, and templates are
  refused.
- **No presets, no menus.** The asserted toolchain is git, bash, `mise`,
  the one `bats` pin, and the `notes`+`rudi` pins that keep
  `.agents/notes/` encrypted at rest. A lab that wants another package
  adds the pin, the wiring and the dated loosening row in its own turn;
  the contract's Tooling and Communication sections say how.
- **This is a tool for strangers.** lab is public and meant for
  people who have never heard of the labs it grew out of. Personal
  names, lineage names and the name of the runner the lineage ran under
  appear in `lib/lineage-names` alone: `doctor` reads its `lab` lines to
  reject those names in a generated lab, and `test/agent_add.bats` reads
  its `runner` line to assert a lab never carries that one. Usage
  examples, help text, the scaffold and the tests use generic names
  (`example`, `builder`, `Your Name`) and paths that mean the same on
  every machine. No harness is named anywhere else. The repo-wide test in
  `test/own_lab.bats` greps every file but that one for every name on
  the list and fails on any other mention; the one personal string it
  allows is the address of this repository, which a lab's README links.
- **The steward stays voiceless, singular and named.** Its scaffold
  (`scaffold/agent/steward/`) states that it has no GitHub identity and
  no mail by design, and the contract's Tooling clause excludes it from any
  identity entry the owner files. Its name is the constant `STEWARD`
  in `lib/lab.sh`; its home is `.agents/home/steward/` inside the lab,
  and a runner's definition for it, where one exists, is named after the
  lab. Every lab has it from `init`. Do
  not add a rename flag, a `--github` or `--mail` path, a way to skip it,
  or a way to have two; a lab that wants a speaking agent adds a judge.
- **The lab is harness-agnostic.** `init`, `agent add`, `agent home` and
  `doctor` read and write only the lab — the homes live inside it. Nothing here writes
  a runner's files: what a runner needs is `.agents/roster.tsv`, each
  home's `AGENTS.md` and the rule that the steward's file is named after
  the lab, and its definition is the owner's to write outside the
  lab. Do not add an exporter, and do not let a harness path, tool name
  or settings file into the contract, the notes, the homes or the library.
- **Generated files are never overwritten.** `install_tree` and `agent add`
  keep what exists and say so. A change to the scaffold reaches an existing
  lab only by hand, in that lab's own turn.

## Working here

```bash
mise run validate      # tests, codebase lint, generated-README check, whitespace
mise run test          # parallel BATS only, for focused runs
readme build           # regenerate README.md after editing README.tsx
```

- Scaffold files carry `{{KEY}}` — uppercase, no spaces, one of the facts
  listed above and nothing else. mise's own `{{ config_root }}` and
  `{{ env.X }}` have spaces and pass through untouched; keep it that way.
- The scaffold's executables (`.agents/hooks/`, `.agents/tasks/`) must pass
  `bash -n`; a BATS test owns that check, not the `test` task.
- Every public `.mise/tasks/*` file carries `#USAGE` help with at least one
  example; the skeleton's tests call each task's `--help` and expect them.
- Tests run in parallel across and within files: isolate mutable state per
  test and process (`$BATS_TEST_TMPDIR`, fixture-local repositories) — the
  old suite already did, and the ported tests keep that.
- Comments carry constraints, not narrative. No decorative separators.
- Commit messages: conventional, no footers, no tool attribution.
- When the scaffold changes and you know which lab of the lineage its
  practice came from, say so in the commit; if you do not, say it is new.
  Nobody is expected to know.
