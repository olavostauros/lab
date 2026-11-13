setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  ROSTER="$PWD/.agents/roster.tsv"
  SECRETS="$PWD/.agents/secrets"
}

teardown() {
  [ -f "$BATS_TEST_TMPDIR/mise.toml.orig" ] \
    && cp -f "$BATS_TEST_TMPDIR/mise.toml.orig" "$BATS_TEST_DIRNAME/../../mise.toml" || true
}

@test "agent-env prints exports for every agent on the roster" {
  while IFS= read -r name; do
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT_AUTHOR_NAME=$name"* ]]
    [[ "$output" == *"GIT_COMMITTER_EMAIL=$name@"* ]]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "agent-env stamps LAB_GH_EMAIL under the agent's name when the owner sets it" {
  name="$(awk -F '\t' '!/^#/ && NF && $1 != "steward" { print $1; exit }' "$ROSTER")"
  [ -n "$name" ] || name="$(awk -F '\t' '!/^#/ && NF { print $1; exit }' "$ROSTER")"
  cp mise.toml "$BATS_TEST_TMPDIR/mise.toml.orig"
  sed -i 's/^LAB_GH_EMAIL = ""/LAB_GH_EMAIL = "12345+owner@users.noreply.github.com"/' mise.toml
  run mise run -q agent-env "$name"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export GIT_AUTHOR_NAME=$name"* ]]
  [[ "$output" == *"export GIT_AUTHOR_EMAIL=12345+owner@users.noreply.github.com"* ]]
  [[ "$output" == *"export GIT_COMMITTER_EMAIL=12345+owner@users.noreply.github.com"* ]]
}

@test "agent-env rejects an agent who is not on the roster" {
  run mise run -q agent-env nobody-here
  [ "$status" -ne 0 ]
}

@test "agent-env prints exactly the four author lines when no credential is granted" {
  while IFS= read -r name; do
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "$output" != *SECRETS_* ]]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "agent-env exports the sops configuration from a granted identity, and never for the steward" {
  recipient="age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
  while IFS= read -r name; do
    dir="$SECRETS/$name"
    mkdir -p "$dir"
    printf '# created: 2026-01-01T00:00:00Z\n# public key: %s\nAGE-SECRET-KEY-1FAKE\n' "$recipient" > "$dir/identity.txt"
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
    rm -rf "$dir"
    if [ "$name" = steward ]; then
      [ "${#lines[@]}" -eq 4 ]
    else
      [ "${#lines[@]}" -eq 8 ]
      [[ "$output" == *"export SECRETS_PROVIDER=sops"* ]]
      [[ "$output" == *"export SECRETS_SOPS_FILE=$dir/vault.enc.yaml"* ]]
      [[ "$output" == *"export SECRETS_SOPS_AGE_KEY_FILE=$dir/identity.txt"* ]]
      [[ "$output" == *"export SECRETS_SOPS_RECIPIENT=$recipient"* ]]
    fi
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "agent-env fails an identity with no public-key line instead of exporting half a provider" {
  while IFS= read -r name; do
    dir="$SECRETS/$name"
    mkdir -p "$dir"
    printf 'AGE-SECRET-KEY-1FAKE\n' > "$dir/identity.txt"
    run mise run -q agent-env "$name"
    rm -rf "$dir"
    if [ "$name" = steward ]; then
      [ "$status" -eq 0 ]
    else
      [ "$status" -ne 0 ]
      [[ "$output" == *"no '# public key:' line"* ]]
      [[ "$output" != *SECRETS_* ]]
    fi
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}
