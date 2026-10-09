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
