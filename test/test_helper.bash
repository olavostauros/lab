house() {
  local task="$1"
  shift
  case "$task" in
    agent) task="$task:$1"; shift ;;
  esac
  cd "$REPO_DIR" && env \
    HOUSE_CALLER_PWD="$CALLER" \
    HOUSE_AGENTS_ROOT="$AGENTS_ROOT" \
    HOUSE_DEFINITIONS_DIR="$DEFINITIONS_DIR" \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 \
    MISE_AUTO_INSTALL=0 \
    mise run -q "$task" "$@"
}
export -f house

in_house() {
  local dir="$1"
  shift
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 MISE_AUTO_INSTALL=0 mise -C "$dir" run -q "$@"
}
export -f in_house

house_setup() {
  export CALLER="$BATS_TEST_TMPDIR/caller"
  export AGENTS_ROOT="$BATS_TEST_TMPDIR/agents"
  export DEFINITIONS_DIR="$BATS_TEST_TMPDIR/definitions"
  export MISE_TRUSTED_CONFIG_PATHS="$BATS_TEST_TMPDIR"
  export GIT_AUTHOR_NAME="house test"
  export GIT_AUTHOR_EMAIL="house-test@example.invalid"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0="$GIT_AUTHOR_NAME"
  mkdir -p "$CALLER" "$AGENTS_ROOT" "$DEFINITIONS_DIR"
}

setup() {
  house_setup
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
