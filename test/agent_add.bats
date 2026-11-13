#!/usr/bin/env bats

load test_helper

setup() {
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab install hearth --at "$H" --project "the forge" >/dev/null
}

@test "a fresh lab already has its steward, and there is one per lab under one name" {
  require_lab_tasks install agent/add
  grep -q $'^steward\tstewardship\t\tsteward$' "$H/.agents/roster.tsv"
  assert_file_contains "$H/.agents/notes/steward.md" "The steward of the forge"
  assert_file_contains "$H/.agents/notes/steward-home.md" "the steward of **the forge**"
  run lab agent add steward --lab "$H"
  assert_failure
  assert_output_contains "already on the roster"
  run lab agent add steward --lab "$H" --owns tidy/
  assert_failure
  assert_output_contains "the steward owns no directory"
  sed -i '/^steward\t/d' "$H/.agents/roster.tsv"
  printf 'hestia\tstewardship\t\tsteward\n' >> "$H/.agents/roster.tsv"
  run lab agent add steward --lab "$H"
  assert_failure
  assert_output_contains "already has a steward; a lab has exactly one"
}

@test "agent add puts a builder on the roster with note and home, and no harness file" {
  require_lab_tasks install agent/add
  run lab agent add vulcan --lab "$H" --role backend --owns server/ --charge "Owns the schema and the API."
  assert_success
  assert_output_contains "roster: vulcan (builder)"
  assert_output_contains "its Stance is the framework's for a builder"

  grep -q $'^vulcan\tbackend\tserver/\tbuilder$' "$H/.agents/roster.tsv"
  assert_file_contains "$H/.agents/notes/vulcan.md" "Owns \`$H/server/\`"
  assert_file_contains "$H/.agents/notes/vulcan.md" "The failing case first, then the change, then the gates"
  assert_file_says "$H/.agents/notes/vulcan.md" "Narrowing this stance is vulcan's; widening it is the owner's."
  assert_file_contains "$H/AGENTS.md" "- **vulcan** — backend. Owns \`server/\`: Owns the schema and the API."
  assert_file_contains "$H/AGENTS.md" "| act as vulcan for the first time in a session | [\`.agents/notes/vulcan.md\`](.agents/notes/vulcan.md) |"

  [ -f "$H/.agents/notes/vulcan-home.md" ]
  [ -f "$H/.agents/notes/vulcan-scratchpad.md" ]
  [ ! -e "$H/.agents/home" ]
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "You own"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "git switch -c vulcan/<short-topic>"
  assert_file_contains "$H/.agents/notes/vulcan-home.md" "stalls on its passphrase prompt is reported, not"

  assert_file_contains "$H/.agents/notes/vulcan-home.md" "$H/.agents/notes/vulcan-home.md"
  [ -z "$(ls -A "$DEFINITIONS_DIR")" ]
  ! grep -rq '{{' "$H/.agents/notes/vulcan.md" "$H/.agents/notes/vulcan-home.md"
  ! grep -rqiwE "$(awk '$1 == "runner" { print $2 }' "$REPO_DIR/lib/lineage-names" | paste -sd '|')" "$H"
  ! grep -rq 'lab:decide' "$H/.agents/notes/vulcan.md" "$H/.agents/notes/vulcan-home.md"
}

@test "agent add without --owns makes a judge" {
  require_lab_tasks install agent/add
  run lab agent add argus --lab "$H" --role "review and security"
  assert_success
  assert_output_contains "roster: argus (judge)"
  assert_output_contains "its Stance is the framework's for a judge"
  grep -q $'^argus\treview and security\t\tjudge$' "$H/.agents/roster.tsv"
  assert_file_contains "$H/AGENTS.md" "- **argus** — review and security. Owns no directory."
  assert_file_contains "$H/.agents/notes/argus-home.md" "You own no"
  assert_file_contains "$H/.agents/notes/argus-home.md" "stalls on its passphrase prompt is reported, not"
  assert_file_contains "$H/.agents/notes/argus.md" "Judgement, not patches"
  assert_file_contains "$H/.agents/notes/argus.md" "The diff before the description, and the test before the diff"
  assert_file_says "$H/.agents/notes/argus.md" "Narrowing this stance is argus's; widening it is the owner's."
  ! grep -q 'lab:decide' "$H/.agents/notes/argus.md"
}

@test "agent add refuses a duplicate and an agent with no role" {
  require_lab_tasks install agent/add
  lab agent add vulcan --lab "$H" --role backend --owns server/
  run lab agent add vulcan --lab "$H" --role backend --owns server/
  assert_failure
  assert_output_contains "already on the roster"
  run lab agent add loki --lab "$H"
  assert_failure
  assert_output_contains "--role is required"
}

@test "agent add keeps home notes that exist" {
  require_lab_tasks install agent/add
  printf 'mine\n' > "$H/.agents/notes/apollo-home.md"
  run lab agent add apollo --lab "$H" --role music
  assert_success
  assert_output_contains "keep:"
  [ "$(cat "$H/.agents/notes/apollo-home.md")" = "mine" ]
}

@test "after agent add the lab's own checks and guard know the new agent" {
  require_lab_tasks install agent/add
  lab agent add vulcan --lab "$H" --role backend --owns server/
  lab agent add argus --lab "$H" --role review
  run in_lab "$H" test
  assert_success

  run in_lab "$H" agent-env vulcan
  assert_success
  assert_output_contains "export GIT_AUTHOR_NAME=vulcan"
  assert_output_contains "export GIT_AUTHOR_EMAIL=vulcan@hearth.invalid"

  run env -u LAB_DIR -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=argus "$H/.agents/hooks/agent-identity"
  assert_success
  run env -u LAB_DIR -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=loki "$H/.agents/hooks/agent-identity"
  assert_failure
}

@test "agent add resolves the lab from the caller's directory" {
  require_lab_tasks install agent/add
  export CALLER="$H"
  run lab agent add vulcan --role backend --owns server/
  assert_success
  grep -q '^vulcan' "$H/.agents/roster.tsv"
}

@test "agent add rejects a directory that is not a lab" {
  require_lab_tasks install agent/add
  run lab agent add vulcan --lab "$BATS_TEST_TMPDIR" --role backend
  assert_failure
  assert_output_contains "not a lab"
}

@test "agent add renders a charge with an ampersand verbatim" {
  require_lab_tasks install agent/add
  run lab agent add caesar --lab "$H" --role payments --owns payments/ --charge 'Takes money & refunds it.'
  assert_success
  assert_file_contains "$H/AGENTS.md" "Takes money & refunds it."
  assert_file_contains "$H/.agents/notes/caesar.md" "Takes money & refunds it."
  assert_file_contains "$H/.agents/notes/caesar-home.md" "Takes money & refunds it."
  ! grep -rq '{{CHARGE}}' "$H/AGENTS.md" "$H/.agents/notes/caesar.md" "$H/.agents/notes/caesar-home.md"
}
