# notes

{{PROJECT}}'s written memory: what was decided and why, and what was
learned that the code does not say. How the agents work is the lab's —
`{{LAB_PATH}}/AGENTS.md` and `{{LAB_PATH}}/.agents/`. This directory is
about the product.

## Layout

- `docs/` — the product's docs: briefs, specs, references. A top-level
  `docs/` is the older layout; it moves here.
- `decisions/` — one file per decision, `NNNN-short-title.md`, numbered in
  order.
- Flat in this directory — facts learned along the way (API behaviour, data
  quality, measurements), `short-title.md`.

## Append-only

Add a new file; do not edit or delete an existing one. To change a
decision, write a new one that says `Supersedes: NNNN` and why. The old
file stays as the record of what was believed then. A typo fix or a
broken link is the only edit that does not need a new file.

Anyone working on the project, owner or agent, may add a file here.
Changing or removing an existing one is the owner's call.

Write nothing here that would be a problem in a public repo: no keys, no
search results, no personal data.

## Decision format

```
# NNNN. <decision, as a statement>

- Date: YYYY-MM-DD
- By: <who decided>
- Status: accepted | superseded by NNNN
- Supersedes: <NNNN, if any>

## Context
<what forced a choice>

## Decision
<what was chosen>

## Consequences
<what follows, including what it costs>
```

A decision is worth a file when someone later could reasonably ask "why is
it like this?" and the code alone would not answer.
