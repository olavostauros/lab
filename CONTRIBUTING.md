# Contributing

lab is a small tool with a strict shape, so a change lands more easily
when it is discussed before it is written.

1. **Open an issue first.** Say what you would change and why. A scaffold
   change alters the lab every future owner gets; it is the framework's
   opinion, and an opinion is discussed before it is changed.
2. **Branch in your fork and open a pull request into `main`.** One idea per
   pull request.
3. **Run the gates before you push**, the same two CI runs:

   ```bash
   mise run test
   git diff --check
   ```

4. **Commit messages are conventional** — `feat:`, `fix:`, `docs:`, `test:`,
   `refactor:` — with no footers and no tool attribution.
5. **Read [`AGENTS.md`](AGENTS.md).** It is the contract for this repository
   for anyone's agent, and it lists what a change must preserve.

## Releasing

A tag is an install target, not a bookmark: bare `shiv install lab` takes
the newest release tag, and `shiv update lab` on any machine advances to
it. So:

- tag on `main` only, once the gates are green there;
- `v` prefix and bare semver — `v0.2.0`, never `0.2.0` or `v0.2.0-rc1`;
  `test/version.bats` checks every `v*` tag on the checkout for that shape;
- `mise run version` on the tagged commit prints the tag, and a lab made
  from it records the tag in its README's attribution line.

`v0.1.0` is the first.

Nothing here asks you to belong to a lab, to know where a rule came from,
or to run any particular agent harness.
