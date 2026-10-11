setup() {
  cd "$BATS_TEST_DIRNAME/.."
  ROSTER="$PWD/roster.tsv"
}

@test "agent-env prints exports for every agent on the roster" {
  while IFS= read -r name; do
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT_AUTHOR_NAME=$name"* ]]
    [[ "$output" == *"GIT_COMMITTER_EMAIL=$name@"* ]]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "agent-env rejects an agent who is not on the roster" {
  run mise run -q agent-env nobody-here
  [ "$status" -ne 0 ]
}

@test "agent-env prints exactly the four author lines when no credential is granted" {
  export LAB_AGENTS_ROOT="$BATS_TEST_TMPDIR/agents"
  while IFS= read -r name; do
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "$output" != *SECRETS_* ]]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "agent-env exports the sops configuration from a granted identity, and never for the steward" {
  export LAB_AGENTS_ROOT="$BATS_TEST_TMPDIR/agents"
  recipient="age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
  while IFS= read -r name; do
    dir="$LAB_AGENTS_ROOT/$name/.secrets"
    mkdir -p "$dir"
    printf '# created: 2026-01-01T00:00:00Z\n# public key: %s\nAGE-SECRET-KEY-1FAKE\n' "$recipient" > "$dir/identity.txt"
    run mise run -q agent-env "$name"
    [ "$status" -eq 0 ]
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
  export LAB_AGENTS_ROOT="$BATS_TEST_TMPDIR/agents"
  while IFS= read -r name; do
    dir="$LAB_AGENTS_ROOT/$name/.secrets"
    mkdir -p "$dir"
    printf 'AGE-SECRET-KEY-1FAKE\n' > "$dir/identity.txt"
    run mise run -q agent-env "$name"
    if [ "$name" = steward ]; then
      [ "$status" -eq 0 ]
    else
      [ "$status" -ne 0 ]
      [[ "$output" == *"no '# public key:' line"* ]]
      [[ "$output" != *SECRETS_* ]]
    fi
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}
