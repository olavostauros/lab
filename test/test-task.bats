#!/usr/bin/env bats

load test_helper
bats_require_minimum_version 1.5.0

write_passing_test() {
  local path="$1" name="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' \
    '#!/usr/bin/env bats' \
    "@test \"$name\" {" \
    '  true' \
    '}' > "$path"
}

@test "options-only calls use the configured default test directory" {
  run peninsula_isolated test --jobs 1 --filter '^standard skeleton surfaces exist$'

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 standard skeleton surfaces exist'* ]]
}

@test "an explicit test target takes precedence over the configured default" {
  local target="$BATS_TEST_TMPDIR/explicit.bats"
  write_passing_test "$target" 'explicit target only'

  run peninsula_isolated test --jobs 1 "$target"

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 explicit target only'* ]]
}

@test "relative test targets resolve from the repository root" {
  run peninsula_isolated test --jobs 1 test/skeleton.bats --filter '^standard skeleton surfaces exist$'

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 standard skeleton surfaces exist'* ]]
}

@test "whitespace-bearing explicit test targets remain one argument" {
  local target="$BATS_TEST_TMPDIR/explicit target/passing test.bats"
  write_passing_test "$target" 'whitespace target'

  run peninsula_isolated test --jobs 2 "$target"

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 whitespace target'* ]]
}

@test "canonical task runs separate BATS files concurrently" {
  local probe_dir="$BATS_TEST_TMPDIR/parallel-probe"
  local barrier_dir="$BATS_TEST_TMPDIR/barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first worker observes second worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/one.bats"

  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"second worker observes first worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/two.bats"

  export PROBE_DIR="$barrier_dir"
  run peninsula_isolated test "$probe_dir"

  [ "$status" -eq 0 ]
}

@test "canonical task runs tests within one BATS file concurrently" {
  local probe_dir="$BATS_TEST_TMPDIR/within-file-probe"
  local barrier_dir="$BATS_TEST_TMPDIR/within-file-barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first test observes second test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
    printf '%s\n' "$test_keyword \"second test observes first test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/within-file.bats"

  export PROBE_DIR="$barrier_dir"
  run peninsula_isolated test "$probe_dir"

  [ "$status" -eq 0 ]
}
