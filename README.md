# lab

Home base for the agents of **lab**. Part contract, part notebook,
part work queue: the agents read their rules here, record what they learn
here, and take work from here.

Started from [lab](https://github.com/olavostauros/lab)
on 2026-11-13, at v0.1.0.

## Who lives here

See `.agents/roster.tsv` and the "Who lives here" section of `AGENTS.md`.
Add an agent with `lab agent add <name> --lab . --role <role> [--owns <dir>/]`.

Builders work on `<name>/<topic>` branches and open pull requests into
`main`; none merges. The owner files work into
`.agents/notes/work-queue.md`, addressed to one agent, and that agent
takes it from the top.

## Usage

```bash
cd ~/Work/lab
mise run welcome                       # orientation and setup health
mise run test                          # lab checks
mise run install-hooks                 # commit guard for the work tree
eval "$(mise run -q agent-env <name>)" # become an agent, in the shell that commits
```

## How it is laid out

- **`AGENTS.md`** — the lab contract and the real documentation: lab
  rules, any domain rule sets, and the authority model that says what an
  agent may do without asking.
- **`.agents/roster.tsv`** — who counts as an agent. Read by the guard,
  `agent-env` and `welcome`.
- **`.agents/notes/`** — shared notes, encrypted at rest (readable in
  this checkout, opaque in git). Identity in
  `<name>.md`, work in `work-queue.md`, proposed changes to the lab in
  `lab-backlog.md`. Not to be confused with `~/Work/lab/notes/`, the
  product's written memory at the work root — outside the lab when the
  lab is a subdirectory — with docs under `docs/`, numbered decisions
  under `decisions/`, and learned facts flat. Shared and append-only.
- **`.agents/hooks/`** — `agent-identity`, the pre-commit guard.
- **`.agents/tasks/`** — the lab's own machinery, run by `mise run`.
- **`.agents/test/`** — the lab's own checks, run by `mise run test`.
- **`.agents/home/`** — private agent workspaces, git-ignored and never
  committed. Each `<name>/` holds a `home/` repo (the canonical
  `AGENTS.md`, a scratchpad) and, once granted, a `.secrets/` vault.

## Signing

Whether commits here are signed is the machine's git config, not the
lab's. `mise run welcome` reports it under `== signing ==`, with the key.
When they are signed, expect three things:

- **A passphrase prompt during a `lab` command or a commit is for that
  key.** The dialog is GnuPG's: it names the key and not the terminal that
  asked. `lab init` says so before its bootstrap commit; nothing else
  in the lab opens one on its own.
- **An agent's commit is signed with the owner's key.** `agent-env` sets
  the author and committer only, so a commit made as an agent is authored
  by the agent and verifies as the owner. Per-agent keys are the backlog
  entry in `.agents/notes/lab-backlog.md`, not a switch.
- **The prompt repeats.** With no `~/.gnupg/gpg-agent.conf`, gpg-agent
  caches a passphrase for 10 minutes and drops it after 2 hours, so a long
  session asks more than once. A longer `default-cache-ttl` and
  `max-cache-ttl` there, or a pinentry backed by the login keyring, stops
  it; both are machine setup, outside the lab.

To stop signing for this repository alone: `git -C ~/Work/lab config
commit.gpgsign false`, in the owner's own turn. An agent never does that: a
commit that stalls on a passphrase prompt is reported, not worked around.

## Attribution on GitHub

Pushes and PRs run through the owner's `gh` login, and the first line of a
PR body or comment names the agent that wrote it. Commits name the agent as
author; set `LAB_GH_EMAIL` in `mise.toml` to an address GitHub attributes
to the owner — the `users.noreply.github.com` noreply is the one — and they
resolve to that account too, still under the agent's name.

## What is not here yet

Not here yet: no per-agent GitHub identity or signing key, no mail, no
chat, no CI wake-ups.

None is filed: the owner files the ones this lab wants in
`.agents/notes/lab-backlog.md`, one at a time, and each becomes a dated
widening in `AGENTS.md` when it is granted. A granted account is that row
plus two files under the agent's workspace,
`.agents/home/<name>/.secrets/`: an age identity and a `secrets` sops
vault, which `mise run agent-env <name>` then exports and `mise run
welcome` reports under `credentials:`.
