#!/usr/bin/env bats

load test_helper

setup() {
  require_lab_tasks install doctor
  lab_setup
  # lab_setup fakes user.name through GIT_CONFIG_COUNT so install can commit;
  # doctor's identity checks read `git config`, which that override would
  # answer — drop it so the -u probes below see the real config.
  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
  H="$BATS_TEST_TMPDIR/hearth"
  lab install hearth --at "$H" --owner "$GIT_AUTHOR_NAME" >/dev/null
  in_lab "$H" install-hooks >/dev/null
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  ln -s "$(command -v mise)" "$BIN/mise"
  printf '#!/usr/bin/env bash\n' > "$BIN/jq"
  chmod +x "$BIN/jq"
}

doctor_with() {
  run env "$@" bash -c 'lab "$@"' _ doctor --lab "$H"
}

# Run the doctor script with an exact env, bypassing mise run's PATH
# augmentation — needed to simulate a missing tool, since mise puts its
# managed tools (shims included) back on a task's PATH. Caller's env args
# go first so -u unset flags work.
doctor_directly_with() {
  run env "$@" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    MISE_CONFIG_ROOT="$REPO_DIR" usage_lab="$H" \
    bash "$REPO_DIR/.mise/tasks/doctor"  # codebase:ignore bats-test-helper — bypassing mise run is the point: PATH must not regain managed tools
}

@test "doctor reports every environment line ok when the tool has what it needs" {
  require_lab_tasks version
  doctor_with PATH="$BIN:$PATH:$HOME/.local/bin"
  assert_success
  assert_output_contains "ok:   bash $(bash --version | sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p')"
  assert_output_contains "ok:   git $(git --version | sed -n '1s/^git version \([0-9][0-9.]*\).*/\1/p')"
  assert_output_contains "ok:   git user.name"
  assert_output_contains "ok:   git user.email"
  assert_output_contains "ok:   mise on PATH"
  assert_output_contains "ok:   jq on PATH"
  assert_output_contains "ok:   ~/.local/bin on PATH"
  assert_output_contains "ok:   framework: made at $(lab version), this tool's version"
  ! [[ "$output" == *"warn:"* ]]
  ! [[ "$output" == *"note:"* ]]
}

@test "doctor fails without a git identity, naming the key to set" {
  doctor_with -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL
  assert_failure
  assert_output_contains "fail: git user.name is unset, so lab install cannot commit → git config --global user.name"
  assert_output_contains "fail: git user.email is unset, so lab install cannot commit → git config --global user.email"
  assert_output_contains "doctor: 2 failing"
  git -C "$H" config user.name "Ada"
  git -C "$H" config user.email "ada@example.invalid"
  doctor_with -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL
  assert_success
  assert_output_contains "ok:   git user.email"
}

@test "doctor warns when the shim would run without jq and when ~/.local/bin is off PATH" {
  farm="$(path_without jq)"
  doctor_directly_with LAB_CALLER_PWD="$CALLER" PATH="$farm"
  assert_success
  assert_output_contains "warn: jq is not on PATH: without it the lab shim runs 'lab agent add' as 'mise run agent add' → install jq"
  assert_output_contains "warn: ~/.local/bin is not on PATH, and shiv and mise install there → export PATH=\"\$HOME/.local/bin:\$PATH\""
  assert_output_contains "ok:   mise on PATH"
  doctor_directly_with -u LAB_CALLER_PWD PATH="$farm"
  ! [[ "$output" == *"jq"* ]]
}

@test "doctor fails a bash below 4 and a git below 2.28" {
  real_bash="$(command -v bash)"
  real_git="$(command -v git)"
  printf '#!%s\n[ "$1" = --version ] && { echo "GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin)"; exit 0; }\nexec %s "$@"\n' "$real_bash" "$real_bash" > "$BIN/bash"
  printf '#!%s\n[ "$1" = --version ] && { echo "git version 2.20.1"; exit 0; }\nexec %s "$@"\n' "$real_bash" "$real_git" > "$BIN/git"
  chmod +x "$BIN/bash" "$BIN/git"
  doctor_with PATH="$BIN:$PATH"
  assert_failure
  assert_output_contains "fail: bash 3.2.57: lab needs bash 4 or newer first on PATH"
  assert_output_contains "fail: git 2.20.1: lab install needs git 2.28 or newer for git init -b"
  assert_output_contains "doctor: 2 failing"
}

@test "doctor notes the framework version a lab records against the one checking it, and never fails on it" {
  require_lab_tasks version
  doctor_with LAB_FRAMEWORK_VERSION=v5.0.0
  assert_success
  assert_output_contains "note: framework: made at $(lab version); this tool is v5.0.0"
  sed -i '/^on [0-9-]*, at /d' "$H/README.md"
  doctor_with
  assert_success
  assert_output_contains "note: framework: the README records no framework version (this tool is $(lab version))"
}
