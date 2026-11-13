#!/usr/bin/env bats

load test_helper

setup() {
  peninsula_setup
  H="$BATS_TEST_TMPDIR/hearth"
  peninsula install hearth --at "$H" >/dev/null
  peninsula agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
}

@test "agent home makes missing home notes for a rostered agent and keeps existing ones" {
  require_peninsula_tasks install agent/add agent/home
  rm -f "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"
  run peninsula agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "create:"
  [ -f "$H/.agents/notes/vulcan-home.md" ]
  [ -f "$H/.agents/notes/vulcan-scratchpad.md" ]
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "You own"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-home.md"
  ! grep -rq '{{' "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"

  run peninsula agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "keep:"
  assert_output_contains "already exists"
}

@test "agent home refuses a name that is not on the roster" {
  require_peninsula_tasks install agent/add agent/home
  run peninsula agent home nobody --lab "$H"
  assert_failure
  assert_output_contains "not on the roster"
}

@test "agent home renders a builder's ownership and a judge's stance from the roster" {
  require_peninsula_tasks install agent/add agent/home
  rm -f "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"
  run peninsula agent home vulcan --lab "$H"
  assert_output_contains "create:"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "server/"

  peninsula agent add argus --lab "$H" --role review >/dev/null
  rm -f "$H/.agents/notes/argus-home.md" "$H/.agents/notes/argus-scratchpad.md"
  run peninsula agent home argus --lab "$H"
  assert_output_contains "create:"
  [ -f "$H/.agents/notes/argus-home.md" ]
}
