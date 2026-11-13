#!/usr/bin/env bats

load test_helper

setup() {
  peninsula_setup
}

@test "install scaffolds a standalone lab with its own repo and a bootstrap commit" {
  require_peninsula_tasks install
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "create: AGENTS.md"
  assert_output_contains "commit: bootstrap the lab"

  h="$BATS_TEST_TMPDIR/hearth"
  for f in AGENTS.md README.md mise.toml .gitignore notes/README.md .agents/roster.tsv \
           .agents/hooks/agent-identity \
           .agents/tasks/welcome .agents/tasks/test .agents/tasks/agent-env .agents/tasks/install-hooks \
           .agents/notes/work-queue.md .agents/notes/lab-backlog.md \
           .agents/test/agent_env.bats .agents/test/agent_identity.bats .agents/test/roster.bats; do
    [ -f "$h/$f" ]
  done
  [ -x "$h/.agents/hooks/agent-identity" ]
  [ -x "$h/.agents/tasks/welcome" ]
  [ -d "$h/.git" ]
  [ "$(git -C "$h" log --oneline | wc -l)" -eq 1 ]
  [ -z "$(git -C "$h" status --porcelain)" ]
}

@test "install renders the lab name into the contract, the guard and the env" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/AGENTS.md" "# hearth"
  assert_file_contains "$h/AGENTS.md" "HEARTH_OWNER_COMMIT=1"
  assert_file_contains "$h/.agents/hooks/agent-identity" 'HEARTH_OWNER_COMMIT'
  assert_file_contains "$h/mise.toml" 'LAB_NAME = "hearth"'
  assert_file_contains "$h/mise.toml" 'WORK_DIR = "{{ config_root }}"'
  ! grep -q '{{LAB' "$h/AGENTS.md"
  ! grep -rq '{{LAB' "$h/.agents"
}

@test "install --project names what the lab works on" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth" --project "Evento Livre"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/AGENTS.md" "agents of **Evento Livre**"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/mise.toml" 'LAB_PROJECT = "Evento Livre"'
}

@test "install refuses an existing path — it makes a new directory" {
  require_peninsula_tasks install
  h="$BATS_TEST_TMPDIR/hearth"
  mkdir -p "$h"
  run peninsula install hearth --at "$h"
  assert_failure
  assert_output_contains "already exists"
  printf 'mine\n' > "$BATS_TEST_TMPDIR/plain-file"
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/plain-file"
  assert_failure
  assert_output_contains "already exists"
}

@test "install rejects a name that is not lowercase-kebab" {
  require_peninsula_tasks install
  run peninsula install Hearth --at "$BATS_TEST_TMPDIR/x"
  assert_failure
  run peninsula install "my lab" --at "$BATS_TEST_TMPDIR/y"
  assert_failure
}

@test "a fresh lab passes its own checks" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  run in_lab "$BATS_TEST_TMPDIR/hearth" test
  assert_success
  assert_output_contains "== bats =="
  assert_output_contains "== welcome smoke =="
}

@test "a fresh lab's welcome reports the steward on the roster and a missing guard" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  run env -u GIT_AUTHOR_NAME bash -c 'in_lab "$@"' _ "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "not activated"
  grep -qF $'== roster ==\nsteward ' <<< "$output"
  assert_output_contains "pre-commit guard: missing"
  assert_output_contains "nothing queued"
}

@test "install names the signing key before the bootstrap commit when the git config signs" {
  require_peninsula_tasks install
  signing_env
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "sign: the bootstrap commit is signed (openpgp, key 0123456789ABCDEF)"
  assert_output_contains "--no-commit leaves the files"
  [[ "$output" == *"sign: the bootstrap commit"*"commit: bootstrap the lab"* ]]
  grep -q -- '-bsau 0123456789ABCDEF' "$FAKE_GPG_LOG"
  git -C "$BATS_TEST_TMPDIR/hearth" cat-file commit HEAD | grep -q '^gpgsig '
}

@test "install names the committer identity when the config signs with no user.signingkey" {
  require_peninsula_tasks install
  signing_env
  export GIT_CONFIG_COUNT=3
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "sign: the bootstrap commit is signed (openpgp, no user.signingkey — picked by the committer identity peninsula test <peninsula-test@example.invalid>)"
}

@test "install says nothing about signing when commits are unsigned or --no-commit" {
  require_peninsula_tasks install
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  ! [[ "$output" == *"sign:"* ]]
  signing_env
  run peninsula install hall --at "$BATS_TEST_TMPDIR/hall" --no-commit
  assert_success
  ! [[ "$output" == *"sign:"* ]]
  [ ! -e "$FAKE_GPG_LOG" ]
}

@test "welcome reports the signing state, the key, and that an agent signs as the owner" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  run in_lab "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "== signing =="
  assert_output_contains "commits here: unsigned"
  signing_env
  run env GIT_AUTHOR_NAME=steward bash -c 'in_lab "$@"' _ "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "commits here: signed (openpgp, key 0123456789ABCDEF)"
  assert_output_contains "signed with this same key"
  assert_output_contains "stop and report"
  export GIT_CONFIG_COUNT=3
  run in_lab "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "commits here: signed (openpgp, key unset; picked by the committer identity)"
}

@test "the lab README and the steward's home note say what a signing machine means" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/README.md" "## Signing"
  assert_file_contains "$h/README.md" "signed with the owner's key"
  assert_file_contains "$h/README.md" "git -C $h config"
  assert_file_contains "$h/.agents/notes/steward-home.md" "stalls on its passphrase prompt is reported, not"
  assert_file_contains "$h/.agents/notes/steward-home.md" "never set"
  assert_file_contains "$h/.agents/notes/steward-home.md" "HEARTH_OWNER_COMMIT"
}

@test "install-hooks wires the guard into the work tree and the guard refuses the owner" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  run in_lab "$h" install-hooks
  assert_success
  [ -x "$h/.git/hooks/pre-commit" ]

  printf 'x\n' > "$h/scratch.md"
  git -C "$h" add scratch.md
  run env GIT_CONFIG_GLOBAL=/dev/null git -C "$h" -c commit.gpgsign=false commit -q -m "as the owner"
  assert_failure
  assert_output_contains "refusing this commit"

  run env GIT_CONFIG_GLOBAL=/dev/null HEARTH_OWNER_COMMIT=1 git -C "$h" -c commit.gpgsign=false commit -q -m "as the owner, deliberately"
  assert_success
}

@test "install ships a steward by default, homed inside the lab, with no GitHub identity and no mail" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  grep -q $'^steward\tstewardship\t\tsteward$' "$h/.agents/roster.tsv"
  assert_file_contains "$h/AGENTS.md" "- **steward** — stewardship. Owns no directory."
  assert_file_contains "$h/AGENTS.md" "The exception is **steward**, the lab's own voice"
  assert_file_contains "$h/AGENTS.md" "The steward is"
  assert_file_contains "$h/AGENTS.md" "its home note is \`.agents/notes/steward-home.md\`"
  assert_file_contains "$h/AGENTS.md" "The steward is excluded from any such entry"
  assert_file_contains "$h/.agents/notes/steward.md" "No GitHub account, no signing key, no mail — by design"
  assert_file_contains "$h/.agents/notes/steward.md" "$h/.agents/notes/steward-home.md"
  assert_file_contains "$h/.agents/notes/steward-home.md" "# hearth"
  assert_file_contains "$h/.agents/notes/steward-home.md" "You are **steward**, the steward of **hearth**"
  assert_file_contains "$h/.agents/notes/steward-home.md" "no GitHub account, no signing key, and no mail, permanently"
  [ ! -e "$h/.agents/home" ]
  [ -z "$(ls -A "$DEFINITIONS_DIR")" ]
  ! grep -rq '{{' "$h/.agents/notes/steward.md" "$h/.agents/notes/steward-home.md" "$h/.agents/notes/steward-scratchpad.md"
  [ -z "$(git -C "$h" status --porcelain)" ]
  run in_lab "$h" test
  assert_success
}

@test "two labs may share a name on one machine, and each keeps its own steward" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/one/hearth"
  run peninsula install hearth --at "$BATS_TEST_TMPDIR/two/hearth"
  assert_success
  [ -f "$BATS_TEST_TMPDIR/one/hearth/.agents/notes/steward-home.md" ]
  [ -f "$BATS_TEST_TMPDIR/two/hearth/.agents/notes/steward-home.md" ]
}

@test "two labs on one machine each keep their own steward" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  run peninsula install hall --at "$BATS_TEST_TMPDIR/hall"
  assert_success
  [ -f "$BATS_TEST_TMPDIR/hearth/.agents/notes/steward-home.md" ]
  [ -f "$BATS_TEST_TMPDIR/hall/.agents/notes/steward-home.md" ]
  grep -q '^steward' "$BATS_TEST_TMPDIR/hall/.agents/roster.tsv"
}

@test "install keys the lab by its name, not by the basename of --at" {
  require_peninsula_tasks install agent/add doctor
  peninsula install hearth --at "$BATS_TEST_TMPDIR/project/lab"
  h="$BATS_TEST_TMPDIR/project/lab"
  assert_file_contains "$h/mise.toml" 'LAB_NAME = "hearth"'
  [ -f "$h/.agents/notes/steward-home.md" ]
  assert_file_contains "$h/.agents/notes/steward.md" "$h/.agents/notes/steward-home.md"
  peninsula agent add builder --lab "$h" --role implementation --owns src/
  grep -q $'^builder\t' "$h/.agents/roster.tsv"
  run peninsula doctor --lab "$h"
  assert_success
}

@test "the steward's guard and env work like any agent's, and welcome points at its home" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  run env -u LAB_DIR -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=steward "$h/.agents/hooks/agent-identity"
  assert_success
  run in_lab "$h" agent-env steward
  assert_success
  assert_output_contains "export GIT_AUTHOR_NAME=steward"
  run env GIT_AUTHOR_NAME=steward bash -c 'in_lab "$@"' _ "$h" welcome
  assert_success
  assert_output_contains "home: .agents/notes/steward-home.md"
}

@test "install encrypts the lab's .agents/notes at rest" {
  require_peninsula_tasks install doctor
  peninsula install hall --at "$BATS_TEST_TMPDIR/hall"
  h="$BATS_TEST_TMPDIR/hall"
  assert_file_contains "$h/.gitattributes" '.agents/notes/** filter=git-crypt'
  [ -f "$h/.agents/notes/.manifest" ]
  run peninsula doctor --lab "$h"
  assert_output_contains "ok:   .agents/notes encrypts at rest"
}

@test "install-hooks hangs the guard off the notes dispatcher and patches --dir once" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  mkdir -p "$h/.git/hooks/pre-commit.d"
  printf 'NOTES_ROOT=".agents/notes"\n      run_notes obfuscate "${unobfuscated[@]}" >&2\n' \
    > "$h/.git/hooks/pre-commit.d/obfuscation"
  run in_lab "$h" install-hooks
  assert_success
  [ -L "$h/.git/hooks/pre-commit.d/agent-identity" ]
  grep -q 'run_notes obfuscate --dir "$NOTES_ROOT"' "$h/.git/hooks/pre-commit.d/obfuscation"
  run in_lab "$h" install-hooks
  [ "$(grep -c -- '--dir' "$h/.git/hooks/pre-commit.d/obfuscation")" -eq 1 ]
}

@test "install with no name asks for the facts and scaffolds a standalone lab" {
  require_peninsula_tasks install
  answers="$BATS_TEST_TMPDIR/answers"
  printf '%s\n' \
    "BAD NAME" \
    "hearth" \
    "$BATS_TEST_TMPDIR/hearth" \
    "" \
    "" \
    "y" \
    "n" "n" "n" "n" > "$answers"
  CALLER="$BATS_TEST_TMPDIR/caller" PENINSULA_PROMPT_TTY="$answers" run peninsula install
  assert_success
  assert_output_contains "commit: bootstrap the lab"
  assert_output_contains "done: hearth at"
  [ -f "$BATS_TEST_TMPDIR/hearth/.agents/roster.tsv" ]
}

@test "install with no name asks, scaffolds a lab and puts an agent on the roster" {
  require_peninsula_tasks install
  answers="$BATS_TEST_TMPDIR/answers"
  printf '%s\n' \
    "hall" \
    "" \
    "" \
    "" \
    "y" \
    "y" \
    "vulcan" \
    "1" \
    "src/" \
    "implementation" \
    "" \
    "n" \
    "n" "n" "n" > "$answers"
  CALLER="$BATS_TEST_TMPDIR/caller" PENINSULA_PROMPT_TTY="$answers" run peninsula install
  assert_success
  h="$BATS_TEST_TMPDIR/caller/hall"
  [ -f "$h/AGENTS.md" ]
  assert_file_contains "$h/.agents/roster.tsv" "vulcan"
  [ -f "$h/.agents/notes/vulcan.md" ]
}

@test "install with no name honors flags already given in guided mode" {
  require_peninsula_tasks install
  answers="$BATS_TEST_TMPDIR/answers"
  printf '%s\n' \
    "hall" \
    "" \
    "" \
    "y" \
    "n" "n" "n" "n" > "$answers"
  CALLER="$BATS_TEST_TMPDIR/caller" PENINSULA_PROMPT_TTY="$answers" run peninsula install --project "the forge"
  assert_success
  h="$BATS_TEST_TMPDIR/caller/hall"
  assert_file_contains "$h/AGENTS.md" "agents of **the forge**"
  [ -f "$h/.agents/roster.tsv" ]
}

@test "install with no name writes nothing when the owner declines" {
  require_peninsula_tasks install
  answers="$BATS_TEST_TMPDIR/answers"
  printf '%s\n' \
    "hearth" \
    "$BATS_TEST_TMPDIR/hearth" \
    "" \
    "" \
    "n" > "$answers"
  CALLER="$BATS_TEST_TMPDIR/caller" PENINSULA_PROMPT_TTY="$answers" run peninsula install
  assert_failure
  assert_output_contains "nothing written"
  [ ! -e "$BATS_TEST_TMPDIR/hearth" ]
}

@test "install with no name and nothing to ask explains itself" {
  require_peninsula_tasks install
  : > "$BATS_TEST_TMPDIR/answers"
  CALLER="$BATS_TEST_TMPDIR/caller" PENINSULA_PROMPT_TTY="$BATS_TEST_TMPDIR/answers" run peninsula install
  assert_failure
  assert_output_contains "it needs a terminal, or answers on stdin"
}

@test "install with no name inside a lab points at it instead of nesting" {
  require_peninsula_tasks install
  peninsula install hearth --at "$BATS_TEST_TMPDIR/hearth"
  CALLER="$BATS_TEST_TMPDIR/hearth" run peninsula install
  assert_success
  assert_output_contains "already the hearth lab"
}
