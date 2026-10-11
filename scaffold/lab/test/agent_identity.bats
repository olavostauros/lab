setup() {
  HOOK="$BATS_TEST_DIRNAME/../hooks/agent-identity"
  ROSTER="$BATS_TEST_DIRNAME/../roster.tsv"
}

@test "refuses an unset author" {
  run env -u GIT_AUTHOR_NAME -u {{LAB_UPPER}}_OWNER_COMMIT "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing this commit"* ]]
}

@test "refuses the owner without the escape hatch" {
  run env -u {{LAB_UPPER}}_OWNER_COMMIT GIT_AUTHOR_NAME=someone-else "$HOOK"
  [ "$status" -eq 1 ]
}

@test "accepts every agent on the roster" {
  while IFS= read -r name; do
    run env -u {{LAB_UPPER}}_OWNER_COMMIT GIT_AUTHOR_NAME="$name" "$HOOK"
    [ "$status" -eq 0 ]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$ROSTER")
}

@test "accepts the owner with {{LAB_UPPER}}_OWNER_COMMIT=1" {
  run env GIT_AUTHOR_NAME=someone-else {{LAB_UPPER}}_OWNER_COMMIT=1 "$HOOK"
  [ "$status" -eq 0 ]
}

@test "refuses everyone when the roster is missing" {
  tmp="$BATS_TEST_TMPDIR/lab"
  mkdir -p "$tmp/hooks"
  cp "$HOOK" "$tmp/hooks/agent-identity"
  run env -u {{LAB_UPPER}}_OWNER_COMMIT -u LAB_DIR GIT_AUTHOR_NAME=anyone "$tmp/hooks/agent-identity"
  [ "$status" -eq 1 ]
  [[ "$output" == *"roster not found"* ]]
}
