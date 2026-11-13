#!/usr/bin/env bats

load test_helper

setup() {
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab init hearth --at "$H" >/dev/null
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
}

@test "agent home makes missing home notes for a rostered agent and keeps existing ones" {
  require_lab_tasks init agent/add agent/home
  rm -f "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"
  run lab agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "create:"
  [ -f "$H/.agents/notes/vulcan-home.md" ]
  [ -f "$H/.agents/notes/vulcan-scratchpad.md" ]
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "You own"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-home.md"
  ! grep -rq '{{' "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"

  run lab agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "keep:"
  assert_output_contains "already exists"
}

@test "agent home refuses a name that is not on the roster" {
  require_lab_tasks init agent/add agent/home
  run lab agent home nobody --lab "$H"
  assert_failure
  assert_output_contains "not on the roster"
}

@test "agent home renders a builder's ownership and a judge's stance from the roster" {
  require_lab_tasks init agent/add agent/home
  rm -f "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-scratchpad.md"
  run lab agent home vulcan --lab "$H"
  assert_output_contains "create:"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "server/"

  lab agent add argus --lab "$H" --role review >/dev/null
  rm -f "$H/.agents/notes/argus-home.md" "$H/.agents/notes/argus-scratchpad.md"
  run lab agent home argus --lab "$H"
  assert_output_contains "create:"
  [ -f "$H/.agents/notes/argus-home.md" ]
}
