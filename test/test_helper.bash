#!/usr/bin/env bash
# Shared fixtures for peninsula tests.

# Run a repo task through mise so tests exercise the real task path.
# `agent add|home` maps to the agent:add|agent:home task names.
peninsula() {
  local task="$1"
  shift
  case "$task" in
    agent) task="$task:$1"; shift ;;
  esac
  cd "$REPO_DIR" && env -u MISE_YES -u PENINSULA_YES \
    PENINSULA_CALLER_PWD="${CALLER:-}" \
    PENINSULA_DEFINITIONS_DIR="${DEFINITIONS_DIR:-}" \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 \
    MISE_AUTO_INSTALL=0 \
    mise run -q "$task" "$@"
}
export -f peninsula

# Run the public task with only the environment needed by real concurrency
# probes, excluding the per-test mock BATS and Rush commands.
peninsula_isolated() {
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TMPDIR="${TMPDIR:-/tmp}" \
    MISE_TRUSTED_CONFIG_PATHS="$REPO_DIR" \
    PROBE_DIR="${PROBE_DIR:-}" \
    mise -C "$REPO_DIR" run -q "$@"
}
export -f peninsula_isolated

# A generated lab runs serial bats — rush is the repo's pin, not the
# lab's — so the runner env the repo's test task exports must not leak in.
in_lab() {
  local dir="$1"
  shift
  env -u BATS_DEFAULT_TEST_TARGET -u BATS_NUMBER_OF_PARALLEL_JOBS \
    -u BATS_PARALLEL_BINARY_NAME \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 MISE_AUTO_INSTALL=0 \
    mise -C "$dir" run -q "$@"
}
export -f in_lab

# A task counts as ported once it exists and is the repo's own — it sources
# lib/peninsula.sh. Tests gated on this skip until their command lands.
peninsula_task_ported() {
  [ -f "$REPO_DIR/.mise/tasks/$1" ] &&
    grep -qF 'lib/peninsula.sh' "$REPO_DIR/.mise/tasks/$1"
}
export -f peninsula_task_ported

# In-place sed portable across GNU and BSD: -i's suffix is optional on one
# and required on the other — give both a backup name, then remove it.
sedi() {
  local file
  for file; do :; done
  sed -i.bak "$@" && rm -f "$file.bak"
}
export -f sedi

require_peninsula_tasks() {
  local task
  for task in "$@"; do
    peninsula_task_ported "$task" || skip "not ported yet: mise task $task"
  done
}
export -f require_peninsula_tasks

# Minimal stand-ins for the notes toolchain so install/doctor tests run
# offline: `notes setup --dir <d>` writes the git-crypt pattern and the
# manifest at the repo root, like the real thing, and rudi/git-crypt
# exist only so `command -v` sees them. Real encryption is exercised by
# the install job in CI.
stub_notes_tools() {
  local bin="$BATS_TEST_TMPDIR/notes-stub-bin"
  mkdir -p "$bin"
  cat > "$bin/notes" <<'EOF'
#!/usr/bin/env bash
dir="notes"
while [ $# -gt 0 ]; do
  case "$1" in --dir) dir="$2"; shift 2 ;; *) shift ;; esac
done
root="$(git rev-parse --show-toplevel)"
mkdir -p "$root/$dir"
printf '%s\n' "$dir/** filter=git-crypt diff=git-crypt" >> "$root/.gitattributes"
: > "$root/$dir/.manifest"
mkdir -p "$(git rev-parse --git-dir)/git-crypt"
EOF
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/rudi"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/git-crypt"
  chmod +x "$bin"/{notes,rudi,git-crypt}
  export PATH="$bin:$PATH"
}

peninsula_setup() {
  # The tool prints canonical paths; on macOS /var is a symlink to
  # /private/var, so the tests' base must be canonical too.
  BATS_TEST_TMPDIR="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  export CALLER="$BATS_TEST_TMPDIR/caller"
  export DEFINITIONS_DIR="$BATS_TEST_TMPDIR/definitions"
  export MISE_TRUSTED_CONFIG_PATHS="$BATS_TEST_TMPDIR"
  export GIT_AUTHOR_NAME="peninsula test"
  export GIT_AUTHOR_EMAIL="peninsula-test@example.invalid"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0="$GIT_AUTHOR_NAME"
  mkdir -p "$CALLER" "$DEFINITIONS_DIR"
  stub_notes_tools
}

make_project() {
  local dir="$BATS_TEST_TMPDIR/project"
  git init -q -b main "$dir"
  printf 'project\n' > "$dir/README.md"
  git -C "$dir" -c commit.gpgsign=false add README.md
  git -C "$dir" -c commit.gpgsign=false commit -q -m "initial"
  printf '%s' "$dir"
}

signing_env() {
  local fake="$BATS_TEST_TMPDIR/fake-gpg"
  cat > "$fake" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_GPG_LOG:?}"
case " $* " in
  *" -bsau "*)
    printf '\n[GNUPG:] SIG_CREATED D 1 8 00 0 X\n' >&2
    printf -- '-----BEGIN PGP SIGNATURE-----\nfake\n-----END PGP SIGNATURE-----\n'
    ;;
esac
EOF
  chmod +x "$fake"
  export FAKE_GPG_LOG="$BATS_TEST_TMPDIR/gpg.log"
  export GIT_CONFIG_COUNT=4 \
    GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0="$GIT_AUTHOR_NAME" \
    GIT_CONFIG_KEY_1=commit.gpgsign GIT_CONFIG_VALUE_1=true \
    GIT_CONFIG_KEY_2=gpg.program "GIT_CONFIG_VALUE_2=$fake" \
    GIT_CONFIG_KEY_3=user.signingkey GIT_CONFIG_VALUE_3=0123456789ABCDEF
}

path_without() {
  local farm="$BATS_TEST_TMPDIR/path-without" dir f name
  mkdir -p "$farm"
  IFS=: read -ra dirs <<< "$PATH"
  for dir in "${dirs[@]}"; do
    for f in "$dir"/*; do
      name="${f##*/}"
      if [ -x "$f" ] && [ "$name" != "$1" ] && [ ! -e "$farm/$name" ]; then ln -s "$f" "$farm/$name"; fi
    done
  done
  printf '%s' "$farm"
}

assert_success() {
  if [ "$status" -ne 0 ]; then
    printf 'expected success, got status %s\noutput:\n%s\n' "$status" "$output" >&2
    return 1
  fi
}

assert_failure() {
  if [ "$status" -eq 0 ]; then
    printf 'expected failure, got success\noutput:\n%s\n' "$output" >&2
    return 1
  fi
}

assert_output_contains() {
  case "$output" in
    *"$1"*) ;;
    *) printf 'expected output to contain %s\noutput:\n%s\n' "$1" "$output" >&2; return 1 ;;
  esac
}

assert_file_contains() {
  grep -qF -- "$2" "$1" || {
    printf 'expected %s to contain %s\n' "$1" "$2" >&2
    return 1
  }
}

assert_file_says() {
  tr -s '\n' ' ' < "$1" | grep -qF -- "$2" || {
    printf 'expected %s to say %s\n' "$1" "$2" >&2
    return 1
  }
}
