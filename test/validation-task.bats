#!/usr/bin/env bats

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  fixture="$BATS_TEST_TMPDIR/workspace with spaces"
  mkdir -p "$fixture/.mise/tasks" "$fixture/bin" "$BATS_TEST_TMPDIR/logs"
  fixture=$(cd "$fixture" && pwd -P)
  cp "$REPO_DIR/.mise/tasks/validate" "$fixture/.mise/tasks/validate"
  export TMPDIR="$BATS_TEST_TMPDIR/logs"
  export VALIDATION_FIXTURE="$fixture"
  export MISE_TRUSTED_CONFIG_PATHS="$fixture"
  export CODEBASE="$fixture/bin/codebase" README="$fixture/bin/readme"
  git -C "$fixture" init -q
  cat > "$fixture/mise.toml" <<TOML
[settings]
quiet = true
task_output = "interleave"
TOML
  cat > "$fixture/.mise/tasks/test" <<'BASH'
#!/usr/bin/env bash
#MISE description="Synthetic test dependency for the real validate task"
exec "$MISE_CONFIG_ROOT/bin/tests" "$@" # codebase:ignore -- Generated task; mise supplies its fixture root.
BASH
  cat > "$fixture/check" <<'BASH'
#!/usr/bin/env bash
set -eu
name="${0##*/}"
case "$name" in codebase) name=lint ;; esac
printf '%s\n' "$name" >> "$VALIDATION_FIXTURE/order"
printf '%s\n' "$@" > "$VALIDATION_FIXTURE/$name.args"
printf '%s stdout\n' "$name"
printf '%s stderr\n' "$name" >&2
if [ "${LARGE_OUTPUT:-}" = "$name" ]; then
  awk 'BEGIN {for (i=0; i<10000; i++) printf "x"; print "FINAL FAILURE"}'
fi
if [ "${BLOCK_CHECK:-}" = "$name" ] || [ "${ORPHAN_CHECK:-}" = "$name" ]; then
  sleep 60 &
  printf '%s\n' "$!" > "$VALIDATION_FIXTURE/nested.pid"
  if [ "${ORPHAN_CHECK:-}" = "$name" ]; then exit 0; fi
  wait
fi
if [ "${REPORT_FAILURE:-}" = "$name" ]; then
  for directory in "$TMPDIR"/peninsula-validation.*; do
    mkdir "$directory/report.tsv.next"
  done
fi
if [ "${FAIL_CHECK:-}" = "$name" ]; then exit 7; fi
BASH
  for name in tests codebase readme; do
    ln -s ../check "$fixture/bin/$name"
  done
  chmod +x "$fixture/check" "$fixture/.mise/tasks/test"
}

teardown() {
  if [ -f "$fixture/nested.pid" ]; then
    pid=$(< "$fixture/nested.pid")
    if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid"; fi
  fi
  if [ -n "${driver:-}" ] && kill -0 "$driver" 2>/dev/null; then
    kill -TERM "$driver"
    if wait "$driver"; then :; else :; fi
  fi
}

log_directory() {
  local first="${output%%$'\n'*}"
  printf '%s\n' "${first#Validation logs: }"
}

wait_for_file() {
  local path="$1"
  for _ in {1..100}; do
    [ ! -f "$path" ] || return 0
    sleep 0.05
  done
  printf 'Timed out waiting for fixture file: %s\n' "$path" >&2
  return 1
}

@test "validate owns one explicit serial inventory and retains private full logs" {
  run mise -C "$fixture" run validate
  [ "$status" -eq 0 ]
  [[ "$output" == *'PASS:'* ]]
  [[ "$output" != *'tests stdout'* ]]
  [ "$(< "$fixture/order")" = $'tests\nlint\nreadme' ]
  [ "$(< "$fixture/lint.args")" = "$(printf 'lint\n%s' "$fixture")" ]
  [ "$(< "$fixture/readme.args")" = $'build\n--check' ]
  local directory
  directory=$(log_directory)
  [ "$(< "$directory/whitespace.command")" = 'git diff --check ' ]
  [ "$(wc -c < "$directory/tests.log")" -gt 0 ]
  run grep -F 'tests stderr' "$directory/tests.log"
  [ "$status" -eq 0 ]
  run grep $'^run\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run find "$directory" -type d ! -perm 700 -print
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run find "$directory" -type f ! -perm 600 -print
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "validate preserves failure exit and bounded excerpt while running independent peers" {
  # shellcheck disable=SC2030 # BATS intentionally isolates this test's exports.
  export FAIL_CHECK=tests LARGE_OUTPUT=tests
  run mise -C "$fixture" run validate
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL:'* ]]
  [[ "$output" == *'FINAL FAILURE'* ]]
  [ "${#output}" -lt 2500 ]
  [ "$(< "$fixture/order")" = $'tests\nlint\nreadme' ]
  local directory
  directory=$(log_directory)
  [ "$(wc -c < "$directory/tests.log")" -gt 10000 ]
  run grep $'^tests\tFAIL\t7\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^readme\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
}

@test "validate propagates Codebase lint failure and still runs independent checks" {
  # shellcheck disable=SC2031 # This test has its own environment, not the previous test's.
  export FAIL_CHECK=lint
  run mise -C "$fixture" run validate
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL:'* ]]
  [ "$(< "$fixture/order")" = $'tests\nlint\nreadme' ]
  local directory
  directory=$(log_directory)
  run grep $'^lint\tFAIL\t7\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^readme\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^whitespace\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^run\tFAIL\t1\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
}

@test "validate verbose emits full passing output without changing the inventory" {
  run mise -C "$fixture" run validate --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *'tests stdout'* ]]
  [[ "$output" == *'readme stderr'* ]]
  [ "$(< "$fixture/order")" = $'tests\nlint\nreadme' ]
}

@test "validate leaves a running report if final report publication fails" {
  export REPORT_FAILURE=readme
  run mise -C "$fixture" run validate
  [ "$status" -eq 1 ]
  [[ "$output" == *'ERROR: could not publish final report'* ]]
  [[ "$output" != *'PASS:'* ]]
  local directory
  directory=$(log_directory)
  run grep $'^run\tRUNNING\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
}

@test "validate cleanup failure cannot turn passing checks into a successful run" {
  cat > "$fixture/deny-cleanup.bash" <<'BASH'
kill() {
  if [ "${1:-}" = -KILL ]; then
    printf 'synthetic permission denied\n' >&2
    return 1
  fi
  builtin kill "$@"
}
BASH
  # shellcheck disable=SC2030 # BATS intentionally isolates this test's exports.
  export BASH_ENV="$fixture/deny-cleanup.bash"
  run mise -C "$fixture" run validate
  [ "$status" -eq 1 ]
  [[ "$output" == *'Cleanup uncertain'* ]]
  [[ "$output" == *'ERROR:'* ]]
  [[ "$output" != *'PASS:'* ]]
  local directory
  directory=$(log_directory)
  run grep $'^tests\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^run\tERROR\t1\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  [ "$(< "$fixture/order")" = tests ]
}

@test "validate SIGINT and SIGTERM stop nested work without admitting later checks" {
  export BLOCK_CHECK=tests
  local signal expected directory supervisor nested code
  for signal in INT TERM; do
    rm -f "$fixture/order" "$fixture/nested.pid"
    mise -C "$fixture" run validate > "$fixture/output" 2>&1 &
    driver=$!
    wait_for_file "$fixture/nested.pid"
    output=$(< "$fixture/output")
    directory=$(log_directory)
    supervisor=$(< "$directory/supervisor.pid")
    nested=$(< "$fixture/nested.pid")
    kill "-$signal" "$supervisor"
    if wait "$driver"; then code=0; else code=$?; fi
    driver=""
    if [ "$signal" = INT ]; then expected=130; else expected=143; fi
    [ "$code" -eq "$expected" ]
    [ "$(< "$fixture/order")" = tests ]
    run grep "$(printf '^run\tINTERRUPTED\t%s\t' "$expected")" "$directory/report.tsv"
    [ "$status" -eq 0 ]
    run grep $'^tests\tINTERRUPTED\t-\t' "$directory/report.tsv"
    [ "$status" -eq 0 ]
    run grep $'^lint\tNOT-RUN\t' "$directory/report.tsv"
    [ "$status" -eq 0 ]
    run -1 kill -0 "$nested"
  done
}

@test "validate interruption before launch does not signal the previous check again" {
  cat > "$fixture/interrupt-before-launch.bash" <<'BASH'
printf() {
  if [ "${active_name:-}" = lint ] && [ "${1:-}" = '%q ' ]; then
    builtin kill -TERM "$$"
  fi
  builtin printf "$@"
}
kill() {
  builtin printf '%s\n' "$*" >> "$VALIDATION_FIXTURE/group-signals"
  builtin kill "$@"
}
BASH
  # shellcheck disable=SC2031 # This test has its own environment, not the previous test's.
  export BASH_ENV="$fixture/interrupt-before-launch.bash"
  run mise -C "$fixture" run validate
  [ "$status" -eq 143 ]
  [ "$(< "$fixture/order")" = tests ]
  # Only normal cleanup of the finished tests group is permitted.
  [ "$(wc -l < "$fixture/group-signals")" -eq 1 ]
  local directory
  directory=$(log_directory)
  run grep $'^tests\tPASS\t0\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^lint\tNOT-RUN\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
  run grep $'^run\tINTERRUPTED\t143\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
}

@test "validate contains descendants even when their immediate command exits first" {
  export ORPHAN_CHECK=tests
  run mise -C "$fixture" run validate
  [ "$status" -eq 0 ]
  local nested
  nested=$(< "$fixture/nested.pid")
  run -1 kill -0 "$nested"
}

@test "validate interruption reaches the real BATS and Rush subprocess tree" {
  cp "$REPO_DIR/mise.toml" "$fixture/mise.toml"
  cp "$REPO_DIR/.mise/tasks/test" "$fixture/.mise/tasks/test"
  mkdir "$fixture/test"
  local test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"blocking nested fixture\" {"
    # shellcheck disable=SC2016 # Expanded by the generated fixture, not its writer.
    printf '%s\n' '  sleep 60 &' '  printf "%s\\n" "$!" > "$VALIDATION_FIXTURE/nested.pid"' '  wait' '}'
  } > "$fixture/test/blocking.bats"
  mise -C "$fixture" run validate > "$fixture/output" 2>&1 &
  driver=$!
  wait_for_file "$fixture/nested.pid"
  output=$(< "$fixture/output")
  local directory supervisor nested code
  directory=$(log_directory)
  supervisor=$(< "$directory/supervisor.pid")
  nested=$(< "$fixture/nested.pid")
  kill -TERM "$supervisor"
  if wait "$driver"; then code=0; else code=$?; fi
  driver=""
  [ "$code" -eq 143 ]
  run -1 kill -0 "$nested"
  run grep $'^run\tINTERRUPTED\t143\t' "$directory/report.tsv"
  [ "$status" -eq 0 ]
}
