# lab

`lab` is a [shiv](https://github.com/KnickKnackLabs/shiv) package: a git
repo with a `mise.toml` and executable tasks in `.mise/tasks/`. Installed,
it scaffolds and maintains **labs** — home bases for the agents of a
project, with a contract, a roster, encrypted notes, a work queue and a
steward.

This repository is the tool, not a lab: it has no `.agents/` of its own,
no roster and no contract. The lab architecture lives in `scaffold/`,
rendered into a target repo by `lab init`.

## Layout

- `.mise/tasks/` — the public command surface (`init`, `agent add`,
  `agent home`, `doctor`, `version`) plus dev tasks (`test`, `validate`,
  `suite` is `test`). Each task is a thin executable that sources
  `lib/lab.sh`.
- `lib/` — shared Bash. `lab.sh` holds the domain contract; keep tasks
  command-shaped and put shared logic here.
- `scaffold/` — the payload `lab init` installs: `scaffold/lab/` becomes
  the lab's root, `scaffold/agent/` renders per-agent notes,
  `scaffold/work/` lands at the work-repo root.
- `test/` — BATS. Tests call tasks through `mise run`, never raw scripts.
- `notes/` — the product's written memory, encrypted at rest by git-crypt.
- `README.tsx` — README source; `readme build` regenerates `README.md`.

## The render contract

`scaffold/` files are templates: `init` and `agent` substitute `{{KEY}}`
placeholders via `render` in `lib/lab.sh`. Every placeholder is a fact the
tool computes; a scaffold may not ask the owner for one.

Lab facts, rendered by `lab init`:

- `{{LAB_NAME}}` — the lab's name, lowercase
- `{{LAB_UPPER}}` — the name uppercased, for env var prefixes
- `{{LAB_PATH}}` — where the lab lives
- `{{WORK_PATH}}` — the work repo root the lab governs
- `{{WORK_DIR_EXPR}}` — the `mise.toml` expression resolving the work root
- `{{PROJECT}}` — what the lab works on
- `{{CREATED}}` — the date the lab was made
- `{{FRAMEWORK_VERSION}}` — the tag or commit of this tool at init time
- `{{OWNER}}` — the owner's name as it appears in the contract
- `{{AUTHOR_DOMAIN}}` — the `<name>@<lab>.invalid` author label domain
- `{{PLACEMENT}}` — the paragraph describing embedded vs standalone

Agent facts, rendered by `lab agent add|home`:

- `{{AGENT}}` — the agent's name
- `{{ROLE}}` — what the agent is for, in two or three words
- `{{OWNS}}` — the directory a builder owns; empty for judge and steward
- `{{CHARGE}}` — one sentence on what the agent does
- `{{HOME_NOTE}}` — its canonical startup note
- `{{SCRATCHPAD_NOTE}}` — its session-log note

A new `{{KEY}}` is a new fact: compute it in `lib/lab.sh`, pass it through
`agent_vars` or the `init` `VARS` array, and add it to this list. A key
that can't be computed is a design smell — the tool decides, not the
owner.

## Workflow

- `mise run test` — BATS, parallel by default (`--jobs 1` for serial).
- `mise run validate` — the gate: tests, `codebase lint`, README check,
  whitespace. CI runs the same command with `--verbose`.
- `readme build` — regenerate `README.md` after editing `README.tsx`.
- `codebase lint .` — the convention lints alone (`@all`, configured in
  `mise.toml` under `[_.codebase]`).

Commits land as the owner: there is no roster and no identity guard on
this repo. `notes/` is encrypted — don't read git history for it, and
don't move secrets into the tree.
