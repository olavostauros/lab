load test_helper

setup() {
  export CALLER="$BATS_TEST_TMPDIR/caller"
  export AGENTS_ROOT="$BATS_TEST_TMPDIR/agents"
  export DEFINITIONS_DIR="$BATS_TEST_TMPDIR/definitions"
  export MISE_TRUSTED_CONFIG_PATHS="$BATS_TEST_TMPDIR"
  export GIT_AUTHOR_NAME="house test"
  export GIT_AUTHOR_EMAIL="house-test@example.invalid"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  mkdir -p "$CALLER" "$AGENTS_ROOT" "$DEFINITIONS_DIR"
  H="$BATS_TEST_TMPDIR/hearth"
  house init hearth --at "$H" --owner "$GIT_AUTHOR_NAME" >/dev/null
  in_house "$H" install-hooks >/dev/null
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  ln -s "$(command -v mise)" "$BIN/mise"
  printf '#!/usr/bin/env bash\n' > "$BIN/jq"
  chmod +x "$BIN/jq"
}

doctor_with() {
  run env "$@" bash -c 'house "$@"' _ doctor --house "$H"
}

@test "doctor reports every environment line ok when the tool has what it needs" {
  doctor_with PATH="$BIN:$PATH:$HOME/.local/bin"
  assert_success
  assert_output_contains "ok:   bash $(bash --version | sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p')"
  assert_output_contains "ok:   git $(git --version | sed -n '1s/^git version \([0-9][0-9.]*\).*/\1/p')"
  assert_output_contains "ok:   git user.name"
  assert_output_contains "ok:   git user.email"
  assert_output_contains "ok:   mise on PATH"
  assert_output_contains "ok:   jq on PATH"
  assert_output_contains "ok:   ~/.local/bin on PATH"
  assert_output_contains "ok:   framework: made at $(house version), this tool's version"
  ! [[ "$output" == *"warn:"* ]]
  ! [[ "$output" == *"note:"* ]]
}

@test "doctor fails without a git identity, naming the key to set" {
  doctor_with -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL
  assert_failure
  assert_output_contains "fail: git user.name is unset, so house init cannot commit → git config --global user.name"
  assert_output_contains "fail: git user.email is unset, so house init cannot commit → git config --global user.email"
  assert_output_contains "doctor: 2 failing"
  git -C "$H" config user.name "Ada"
  git -C "$H" config user.email "ada@example.invalid"
  doctor_with -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL
  assert_success
  assert_output_contains "ok:   git user.email"
}

@test "doctor warns when the shim would run without jq and when ~/.local/bin is off PATH" {
  farm="$(path_without jq)"
  doctor_with PATH="$farm"
  assert_success
  assert_output_contains "warn: jq is not on PATH: without it the house shim runs 'house agent add' as 'mise run agent add' → install jq"
  assert_output_contains "warn: ~/.local/bin is not on PATH, and shiv and mise install there → export PATH=\"\$HOME/.local/bin:\$PATH\""
  assert_output_contains "ok:   mise on PATH"
  doctor_with PATH="$farm" -u HOUSE_CALLER_PWD
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
  assert_output_contains "fail: bash 3.2.57: house needs bash 4 or newer first on PATH"
  assert_output_contains "fail: git 2.20.1: house init needs git 2.28 or newer for git init -b"
  assert_output_contains "doctor: 2 failing"
}

@test "doctor notes the framework version a house records against the one checking it, and never fails on it" {
  doctor_with HOUSE_FRAMEWORK_VERSION=v5.0.0
  assert_success
  assert_output_contains "note: framework: made at $(house version); this tool is v5.0.0"
  sed -i '/^on [0-9-]*, at /d' "$H/README.md"
  doctor_with
  assert_success
  assert_output_contains "note: framework: the README records no framework version (this tool is $(house version))"
}
