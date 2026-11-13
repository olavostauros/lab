#!/usr/bin/env bats

load test_helper

setup() {
  lab_setup
}

@test "init scaffolds a standalone lab with its own repo and a bootstrap commit" {
  require_lab_tasks init
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
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

@test "init renders the lab name into the contract, the guard and the env" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/AGENTS.md" "# hearth"
  assert_file_contains "$h/AGENTS.md" "HEARTH_OWNER_COMMIT=1"
  assert_file_contains "$h/.agents/hooks/agent-identity" 'HEARTH_OWNER_COMMIT'
  assert_file_contains "$h/mise.toml" 'LAB_NAME = "hearth"'
  assert_file_contains "$h/mise.toml" 'WORK_DIR = "{{ config_root }}"'
  ! grep -q '{{LAB' "$h/AGENTS.md"
  ! grep -rq '{{LAB' "$h/.agents"
}

@test "init --embedded with no --at puts the lab at the project repo's root" {
  require_lab_tasks init
  project="$(make_project)"
  CALLER="$project" run lab init hall --embedded
  assert_success
  assert_output_contains "keep: README.md"
  assert_output_contains "next: review the new files"
  [ -f "$project/AGENTS.md" ]
  [ -f "$project/.agents/roster.tsv" ]
  [ ! -d "$project/.agents/.git" ]
  assert_file_contains "$project/mise.toml" 'LAB_NAME = "hall"'
  assert_file_contains "$project/mise.toml" 'LAB_PROJECT = "project"'
  assert_file_contains "$project/mise.toml" 'WORK_DIR = "{{ config_root }}"'
  assert_file_contains "$project/AGENTS.md" "lives **inside** the project"
  assert_file_contains "$project/AGENTS.md" "is the root of the \`project\` repo"
  [ -n "$(git -C "$project" status --porcelain)" ]
  [ -f "$project/.agents/home/steward/home/AGENTS.md" ]
  [ -f "$project/notes/README.md" ]
}

@test "init --embedded --at puts the lab in a subdirectory of the project repo" {
  require_lab_tasks init
  project="$(make_project)"
  run lab init hall --at "$project/hall" --embedded
  assert_success
  [ ! -d "$project/hall/.git" ]
  assert_file_contains "$project/hall/mise.toml" 'WORK_DIR = "{{ config_root }}/.."'
  assert_file_contains "$project/hall/mise.toml" 'LAB_PROJECT = "project"'
  assert_file_contains "$project/hall/AGENTS.md" "is a directory of the \`project\` repo"
  [ -n "$(git -C "$project" status --porcelain -- hall)" ]
  [ -f "$project/hall/.agents/home/steward/home/AGENTS.md" ]
  [ -f "$project/notes/README.md" ]
  [ ! -e "$project/hall/notes" ]
}

@test "init --embedded says how a top-level docs/ moves under notes/" {
  require_lab_tasks init
  project="$(make_project)"
  mkdir "$project/docs"
  printf 'docs\n' > "$project/docs/BRIEF.md"
  git -C "$project" -c commit.gpgsign=false add docs && git -C "$project" -c commit.gpgsign=false commit -qm docs
  CALLER="$project" run lab init hall --embedded
  assert_success
  assert_output_contains "docs/ at the work root is the older layout"
  assert_output_contains "git -C $project mv docs notes/"
  [ -d "$project/docs" ]
  [ -f "$project/notes/README.md" ]
}

@test "init --embedded refuses a parent that is not a git repository" {
  require_lab_tasks init
  run lab init hall --at "$BATS_TEST_TMPDIR/loose/hall" --embedded
  assert_failure
  assert_output_contains "--embedded needs"
}

@test "init --embedded keeps a pre-existing AGENTS.md and mise.toml and says what to merge" {
  require_lab_tasks init doctor
  project="$(make_project)"
  printf 'ours\n' > "$project/AGENTS.md"
  printf '[env]\nFOO = "1"\n' > "$project/mise.toml"
  CALLER="$project" run lab init hall --embedded
  assert_success
  assert_output_contains "keep: AGENTS.md"
  assert_output_contains "keep: mise.toml"
  assert_output_contains "note: AGENTS.md is pre-existing"
  assert_output_contains "note: mise.toml is pre-existing"
  [ "$(cat "$project/AGENTS.md")" = "ours" ]
  run lab doctor --lab "$project"
  assert_failure
  assert_output_contains "lacks marker <!-- lab:roster -->"
  assert_output_contains "mise.toml lacks the LAB_* env"
}

@test "init --project names what the lab works on" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth" --project "Evento Livre"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/AGENTS.md" "agents of **Evento Livre**"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/mise.toml" 'LAB_PROJECT = "Evento Livre"'
}

@test "init keeps existing files and reports them" {
  require_lab_tasks init
  h="$BATS_TEST_TMPDIR/hearth"
  mkdir -p "$h"
  printf 'mine\n' > "$h/README.md"
  run lab init hearth --at "$h" --no-commit
  assert_success
  assert_output_contains "keep: README.md"
  [ "$(cat "$h/README.md")" = "mine" ]
}

@test "init rejects a name that is not lowercase-kebab" {
  require_lab_tasks init
  run lab init Hearth --at "$BATS_TEST_TMPDIR/x"
  assert_failure
  run lab init "my lab" --at "$BATS_TEST_TMPDIR/y"
  assert_failure
}

@test "a fresh lab passes its own checks" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run in_lab "$BATS_TEST_TMPDIR/hearth" test
  assert_success
  assert_output_contains "== bats =="
  assert_output_contains "== welcome smoke =="
}

@test "a fresh lab's welcome reports the steward on the roster and a missing guard" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run env -u GIT_AUTHOR_NAME bash -c 'in_lab "$@"' _ "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "not activated"
  grep -qF $'== roster ==\nsteward ' <<< "$output"
  assert_output_contains "pre-commit guard: missing"
  assert_output_contains "nothing queued"
}

@test "init names the signing key before the bootstrap commit when the git config signs" {
  require_lab_tasks init
  signing_env
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "sign: the bootstrap commit is signed (openpgp, key 0123456789ABCDEF)"
  assert_output_contains "--no-commit leaves the files"
  [[ "$output" == *"sign: the bootstrap commit"*"commit: bootstrap the lab"* ]]
  grep -q -- '-bsau 0123456789ABCDEF' "$FAKE_GPG_LOG"
  git -C "$BATS_TEST_TMPDIR/hearth" cat-file commit HEAD | grep -q '^gpgsig '
}

@test "init names the committer identity when the config signs with no user.signingkey" {
  require_lab_tasks init
  signing_env
  export GIT_CONFIG_COUNT=3
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "sign: the bootstrap commit is signed (openpgp, no user.signingkey — picked by the committer identity lab test <lab-test@example.invalid>)"
}

@test "init says nothing about signing when commits are unsigned or --no-commit" {
  require_lab_tasks init
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  ! [[ "$output" == *"sign:"* ]]
  signing_env
  run lab init hall --at "$BATS_TEST_TMPDIR/hall" --no-commit
  assert_success
  ! [[ "$output" == *"sign:"* ]]
  [ ! -e "$FAKE_GPG_LOG" ]
}

@test "welcome reports the signing state, the key, and that an agent signs as the owner" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
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

@test "the lab README and the steward's home say what a signing machine means" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/README.md" "## Signing"
  assert_file_contains "$h/README.md" "signed with the owner's key"
  assert_file_contains "$h/README.md" "git -C $h config"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "stalls on its passphrase prompt is reported, not"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "never set"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "HEARTH_OWNER_COMMIT"
}

@test "install-hooks wires the guard into the work tree and the guard refuses the owner" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
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

@test "init ships a steward by default, homed inside the lab, with no GitHub identity and no mail" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  grep -q $'^steward\tstewardship\t\tsteward$' "$h/.agents/roster.tsv"
  assert_file_contains "$h/AGENTS.md" "- **steward** — stewardship. Owns no directory."
  assert_file_contains "$h/AGENTS.md" "The exception is **steward**, the lab's own voice"
  assert_file_contains "$h/AGENTS.md" "The steward is"
  assert_file_contains "$h/AGENTS.md" "its workspace is the lab's own: \`.agents/home/steward/\`"
  assert_file_contains "$h/AGENTS.md" "The steward is excluded from any such entry"
  assert_file_contains "$h/.agents/notes/steward.md" "No GitHub account, no signing key, no mail — by design"
  assert_file_contains "$h/.agents/notes/steward.md" "$h/.agents/home/steward/home/"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "# hearth"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "You are **steward**, the steward of **hearth**"
  assert_file_contains "$h/.agents/home/steward/home/AGENTS.md" "no GitHub account, no signing key, and no mail, permanently"
  [ -d "$h/.agents/home/steward/home/.git" ]
  [ -z "$(ls -A "$DEFINITIONS_DIR")" ]
  ! grep -rq '{{' "$h/.agents/notes/steward.md" "$h/.agents/home/steward/home"
  [ -z "$(git -C "$h" status --porcelain)" ]
  run in_lab "$h" test
  assert_success
}

@test "two labs may share a name on one machine, and each keeps its own steward" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/one/hearth"
  run lab init hearth --at "$BATS_TEST_TMPDIR/two/hearth"
  assert_success
  [ -f "$BATS_TEST_TMPDIR/one/hearth/.agents/home/steward/home/AGENTS.md" ]
  [ -f "$BATS_TEST_TMPDIR/two/hearth/.agents/home/steward/home/AGENTS.md" ]
}

@test "two labs on one machine each keep their own steward" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run lab init hall --at "$BATS_TEST_TMPDIR/hall"
  assert_success
  [ -f "$BATS_TEST_TMPDIR/hearth/.agents/home/steward/home/AGENTS.md" ]
  [ -f "$BATS_TEST_TMPDIR/hall/.agents/home/steward/home/AGENTS.md" ]
  grep -q '^steward' "$BATS_TEST_TMPDIR/hall/.agents/roster.tsv"
}

@test "init keys the lab by its name, not by the basename of --at" {
  require_lab_tasks init agent/add doctor
  lab init hearth --at "$BATS_TEST_TMPDIR/project/lab"
  h="$BATS_TEST_TMPDIR/project/lab"
  assert_file_contains "$h/mise.toml" 'LAB_NAME = "hearth"'
  [ -f "$h/.agents/home/steward/home/AGENTS.md" ]
  assert_file_contains "$h/.agents/notes/steward.md" "$h/.agents/home/steward/home/"
  lab agent add builder --lab "$h" --role implementation --owns src/
  grep -q $'^builder\t' "$h/.agents/roster.tsv"
  run lab doctor --lab "$h"
  assert_success
}

@test "the steward's guard and env work like any agent's, and welcome points at its home" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  run env -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=steward "$h/.agents/hooks/agent-identity"
  assert_success
  run in_lab "$h" agent-env steward
  assert_success
  assert_output_contains "export GIT_AUTHOR_NAME=steward"
  run env GIT_AUTHOR_NAME=steward bash -c 'in_lab "$@"' _ "$h" welcome
  assert_success
  assert_output_contains "home: .agents/home/steward/home/AGENTS.md"
}

@test "init encrypts the lab's .agents/notes at rest, at the work root" {
  require_lab_tasks init doctor
  project="$(make_project)"
  lab init hall --at "$project/labs/hall" --embedded
  assert_file_contains "$project/.gitattributes" 'labs/hall/.agents/notes/** filter=git-crypt'
  [ -f "$project/labs/hall/.agents/notes/.manifest" ]
  run lab doctor --lab "$project/labs/hall"
  assert_output_contains "ok:   labs/hall/.agents/notes encrypts at rest"
}

@test "install-hooks hangs the guard off the notes dispatcher and patches --dir once" {
  require_lab_tasks init
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
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
