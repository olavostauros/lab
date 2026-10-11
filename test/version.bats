load test_helper

setup() {
  export MISE_TRUSTED_CONFIG_PATHS="$BATS_TEST_TMPDIR"
  export GIT_AUTHOR_NAME="lab test"
  export GIT_AUTHOR_EMAIL="lab-test@example.invalid"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  COPY="$BATS_TEST_TMPDIR/copy"
  mkdir -p "$COPY"
  cp -R "$REPO_DIR/lib" "$REPO_DIR/.mise" "$REPO_DIR/mise.toml" "$COPY/"
}

version_of_copy() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 MISE_AUTO_INSTALL=0 mise -C "$COPY" run -q version "$@"
}

commit_copy() {
  git -C "$COPY" -c commit.gpgsign=false add -A
  git -C "$COPY" -c commit.gpgsign=false commit -q --allow-empty -m "$1"
}

@test "version prints the tag at HEAD, else the short commit, and unknown outside a git worktree" {
  run version_of_copy
  assert_success
  [ "$output" = "unknown" ]
  git init -q -b main "$COPY"
  commit_copy "first"
  git -C "$COPY" tag v9.9.9
  run version_of_copy
  assert_success
  [ "$output" = "v9.9.9" ]
  commit_copy "second"
  run version_of_copy
  assert_success
  [ "$output" = "$(git -C "$COPY" rev-parse --short HEAD)" ]
  [[ "$output" =~ ^[0-9a-f]{7,}$ ]]
  run env LAB_FRAMEWORK_VERSION=v1.2.3 MISE_AUTO_INSTALL=0 mise -C "$COPY" run -q version
  [ "$output" = "v1.2.3" ]
}

@test "a copy of the checkout inside another repository does not borrow that repository's tags" {
  git init -q -b main "$BATS_TEST_TMPDIR"
  git -C "$BATS_TEST_TMPDIR" -c commit.gpgsign=false commit -q --allow-empty -m "outer"
  git -C "$BATS_TEST_TMPDIR" tag v7.7.7
  run version_of_copy
  assert_success
  [ "$output" = "unknown" ]
}

@test "every release tag is a bare semver with a v prefix" {
  [ "$(git -C "$REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$REPO_DIR" && pwd -P)" ] || skip "not a git worktree"
  while IFS= read -r tag; do
    [ -z "$tag" ] || [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
  done < <(git -C "$REPO_DIR" tag --list 'v*')
}
