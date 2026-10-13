load test_helper

@test "init scaffolds a standalone lab with its own repo and a bootstrap commit" {
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "create: AGENTS.md"
  assert_output_contains "commit: bootstrap the lab"

  h="$BATS_TEST_TMPDIR/hearth"
  for f in AGENTS.md README.md mise.toml roster.tsv .gitignore hooks/agent-identity \
           .mise/tasks/welcome .mise/tasks/test .mise/tasks/agent-env .mise/tasks/install-hooks \
           notes/work-queue.md notes/lab-backlog.md \
           test/agent_env.bats test/agent_identity.bats test/roster.bats; do
    [ -f "$h/$f" ]
  done
  [ -x "$h/hooks/agent-identity" ]
  [ -x "$h/.mise/tasks/welcome" ]
  [ -d "$h/.git" ]
  [ "$(git -C "$h" log --oneline | wc -l)" -eq 1 ]
  [ -z "$(git -C "$h" status --porcelain)" ]
}

@test "init renders the lab name into the contract, the guard and the env" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/AGENTS.md" "# hearth"
  assert_file_contains "$h/AGENTS.md" "HEARTH_OWNER_COMMIT=1"
  assert_file_contains "$h/hooks/agent-identity" 'HEARTH_OWNER_COMMIT'
  assert_file_contains "$h/mise.toml" 'LAB_NAME = "hearth"'
  assert_file_contains "$h/mise.toml" 'WORK_DIR = "{{ config_root }}"'
  ! grep -q '{{LAB' "$h/AGENTS.md"
  ! grep -rq '{{LAB' "$h/.mise" "$h/hooks" "$h/test" "$h/notes"
}

@test "init --embedded places the lab inside a project repo without a repo of its own" {
  project="$(make_project)"
  run lab init hall --at "$project/hall" --embedded
  assert_success
  assert_output_contains "next: review the new files"
  [ ! -d "$project/hall/.git" ]
  assert_file_contains "$project/hall/mise.toml" 'WORK_DIR = "{{ config_root }}/.."'
  assert_file_contains "$project/hall/mise.toml" 'LAB_PROJECT = "project"'
  assert_file_contains "$project/hall/AGENTS.md" "lives **inside** the project"
  [ -n "$(git -C "$project" status --porcelain -- hall)" ]
}

@test "init --embedded nested deeper still points WORK_DIR at the top of the repo" {
  project="$(make_project)"
  run lab init hall --at "$project/labs/hall" --embedded
  assert_success
  assert_file_contains "$project/labs/hall/mise.toml" 'WORK_DIR = "{{ config_root }}/../.."'
  [ "$(cd "$project/labs/hall/../.." && pwd -P)" = "$(cd "$project" && pwd -P)" ]
  run lab doctor --lab "$project/labs/hall"
  assert_success
  assert_output_contains "ok:   WORK_DIR resolves to the work tree"
}

@test "init --embedded refuses a parent that is not a git repository" {
  run lab init hall --at "$BATS_TEST_TMPDIR/loose/hall" --embedded
  assert_failure
  assert_output_contains "--embedded needs the parent"
}

@test "init --project names what the lab works on" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth" --project "Evento Livre"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/AGENTS.md" "agents of **Evento Livre**"
  assert_file_contains "$BATS_TEST_TMPDIR/hearth/mise.toml" 'LAB_PROJECT = "Evento Livre"'
}

@test "init keeps existing files and reports them" {
  h="$BATS_TEST_TMPDIR/hearth"
  mkdir -p "$h"
  printf 'mine\n' > "$h/README.md"
  run lab init hearth --at "$h" --no-commit
  assert_success
  assert_output_contains "keep: README.md"
  [ "$(cat "$h/README.md")" = "mine" ]
}

@test "init rejects a name that is not lowercase-kebab" {
  run lab init Hearth --at "$BATS_TEST_TMPDIR/x"
  assert_failure
  run lab init "my lab" --at "$BATS_TEST_TMPDIR/y"
  assert_failure
}

@test "a fresh lab passes its own checks" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run in_lab "$BATS_TEST_TMPDIR/hearth" test
  assert_success
  assert_output_contains "== bats =="
  assert_output_contains "== welcome smoke =="
}

@test "a fresh lab's welcome reports the steward on the roster and a missing guard" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run env -u GIT_AUTHOR_NAME bash -c 'in_lab "$@"' _ "$BATS_TEST_TMPDIR/hearth" welcome
  assert_success
  assert_output_contains "not activated"
  [[ "$output" == *"== roster =="$'\n'"steward "* ]]
  assert_output_contains "pre-commit guard: missing"
  assert_output_contains "nothing queued"
}

@test "init names the signing key before the bootstrap commit when the git config signs" {
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
  signing_env
  export GIT_CONFIG_COUNT=3
  run lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  assert_success
  assert_output_contains "sign: the bootstrap commit is signed (openpgp, no user.signingkey — picked by the committer identity lab test <lab-test@example.invalid>)"
}

@test "init says nothing about signing when commits are unsigned or --no-commit" {
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
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  assert_file_contains "$h/README.md" "## Signing"
  assert_file_contains "$h/README.md" "signed with the owner's key"
  assert_file_contains "$h/README.md" "git -C $h config"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "stalls on its passphrase prompt is reported, not"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "never set"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "HEARTH_OWNER_COMMIT"
}

@test "install-hooks wires the guard into the work tree and the guard refuses the owner" {
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

@test "init ships a steward by default, homed under the lab's name, with no GitHub identity and no mail" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  grep -q $'^steward\tstewardship\t\tsteward$' "$h/roster.tsv"
  assert_file_contains "$h/AGENTS.md" "- **steward** — stewardship. Owns no directory."
  assert_file_contains "$h/AGENTS.md" "The exception is **steward**, the lab's own voice"
  assert_file_contains "$h/AGENTS.md" "The steward is"
  assert_file_contains "$h/AGENTS.md" "its workspace is the lab's own: \`~/agents/hearth/\`"
  assert_file_contains "$h/AGENTS.md" "The steward is excluded from any such entry"
  assert_file_contains "$h/notes/steward.md" "No GitHub account, no signing key, no mail — by design"
  assert_file_contains "$h/notes/steward.md" "$AGENTS_ROOT/hearth/home/"
  [ ! -e "$AGENTS_ROOT/steward" ]
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "# hearth"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "You are **steward**, the steward of **hearth**"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "no GitHub account, no signing key, and no mail, permanently"
  [ -d "$AGENTS_ROOT/hearth/home/.git" ]
  [ -z "$(ls -A "$DEFINITIONS_DIR")" ]
  ! grep -rq '{{' "$h/notes/steward.md" "$AGENTS_ROOT/hearth/home"
  [ -z "$(git -C "$h" status --porcelain)" ]
  run in_lab "$h" test
  assert_success
}

@test "init refuses a lab whose name already keeps a steward home" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run lab init hearth --at "$BATS_TEST_TMPDIR/elsewhere/hearth"
  assert_failure
  assert_output_contains "already exists"
  assert_output_contains "Pick another name"
  [ ! -e "$BATS_TEST_TMPDIR/elsewhere/hearth/AGENTS.md" ]
}

@test "init keys the lab by its name, not by the basename of --at" {
  lab init hearth --at "$BATS_TEST_TMPDIR/project/lab"
  h="$BATS_TEST_TMPDIR/project/lab"
  [ -f "$AGENTS_ROOT/hearth/home/AGENTS.md" ]
  [ ! -e "$AGENTS_ROOT/lab" ]
  assert_file_contains "$h/notes/steward.md" "$AGENTS_ROOT/hearth/home/"
  lab agent add builder --lab "$h" --role implementation --owns src/
  grep -q $'^builder\t' "$h/roster.tsv"
  run lab doctor --lab "$h"
  assert_success
}

@test "two labs on one machine each keep their own steward" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  run lab init hall --at "$BATS_TEST_TMPDIR/hall"
  assert_success
  [ -f "$AGENTS_ROOT/hearth/home/AGENTS.md" ]
  [ -f "$AGENTS_ROOT/hall/home/AGENTS.md" ]
  grep -q '^steward' "$BATS_TEST_TMPDIR/hall/roster.tsv"
}

@test "the steward's guard and env work like any agent's, and welcome points at the lab's home" {
  lab init hearth --at "$BATS_TEST_TMPDIR/hearth"
  h="$BATS_TEST_TMPDIR/hearth"
  run env -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=steward "$h/hooks/agent-identity"
  assert_success
  run in_lab "$h" agent-env steward
  assert_success
  assert_output_contains "export GIT_AUTHOR_NAME=steward"
  run env GIT_AUTHOR_NAME=steward bash -c 'in_lab "$@"' _ "$h" welcome
  assert_success
  assert_output_contains "home: ~/agents/hearth/home/AGENTS.md"
}
