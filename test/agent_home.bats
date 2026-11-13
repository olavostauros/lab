#!/usr/bin/env bats

load test_helper

setup() {
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab init hearth --at "$H" >/dev/null
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
}

@test "agent home makes a missing home for a rostered agent and keeps an existing one" {
  require_lab_tasks init agent/add agent/home
  rm -rf "$H/.agents/home/vulcan"
  run lab agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "create:"
  [ -f "$H/.agents/home/vulcan/home/AGENTS.md" ]
  [ -f "$H/.agents/home/vulcan/home/mise.toml" ]
  [ -f "$H/.agents/home/vulcan/home/SCRATCHPAD.md" ]
  [ -d "$H/.agents/home/vulcan/home/.git" ]
  assert_file_contains "$H/.agents/home/vulcan/home/AGENTS.md" "You own"
  assert_file_contains "$H/.agents/home/vulcan/home/AGENTS.md" "$H/.agents/home/vulcan/home"
  ! grep -rq '{{' "$H/.agents/home/vulcan/home"

  run lab agent home vulcan --lab "$H"
  assert_success
  assert_output_contains "keep:"
  assert_output_contains "already has an AGENTS.md"
}

@test "agent home refuses a name that is not on the roster" {
  require_lab_tasks init agent/add agent/home
  run lab agent home nobody --lab "$H"
  assert_failure
  assert_output_contains "not on the roster"
}

@test "agent home renders a builder's ownership and a judge's stance from the roster" {
  require_lab_tasks init agent/add agent/home
  rm -rf "$H/.agents/home/vulcan"
  run lab agent home vulcan --lab "$H"
  assert_output_contains "create:"
  assert_file_contains "$H/.agents/home/vulcan/home/AGENTS.md" "server/"

  lab agent add argus --lab "$H" --role review >/dev/null
  rm -rf "$H/.agents/home/argus"
  run lab agent home argus --lab "$H"
  assert_output_contains "create:"
  [ -f "$H/.agents/home/argus/home/AGENTS.md" ]
}
