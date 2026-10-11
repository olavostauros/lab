load test_helper

setup() {
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab init hearth --at "$H" --project "the forge" >/dev/null
}

@test "a fresh lab already has its steward, and there is one per lab under one name" {
  grep -q $'^steward\tstewardship\t\tsteward$' "$H/roster.tsv"
  assert_file_contains "$H/notes/steward.md" "The steward of the forge"
  assert_file_contains "$AGENTS_ROOT/hearth/home/AGENTS.md" "the steward of **the forge**"
  [ ! -e "$AGENTS_ROOT/steward" ]
  run lab agent add steward --lab "$H"
  assert_failure
  assert_output_contains "already on the roster"
  run lab agent add steward --lab "$H" --owns tidy/
  assert_failure
  assert_output_contains "the steward owns no directory"
  sed -i '/^steward\t/d' "$H/roster.tsv"
  printf 'hestia\tstewardship\t\tsteward\n' >> "$H/roster.tsv"
  run lab agent add steward --lab "$H"
  assert_failure
  assert_output_contains "already has a steward; a lab has exactly one"
}

@test "agent add puts a builder on the roster with note and home, and no harness file" {
  run lab agent add vulcan --lab "$H" --role backend --owns server/ --charge "Owns the schema and the API."
  assert_success
  assert_output_contains "roster: vulcan (builder)"
  assert_output_contains "its Stance is the framework's for a builder"

  grep -q $'^vulcan\tbackend\tserver/\tbuilder$' "$H/roster.tsv"
  assert_file_contains "$H/notes/vulcan.md" "Owns \`$H/server/\`"
  assert_file_contains "$H/notes/vulcan.md" "The failing case first, then the change, then the gates"
  assert_file_says "$H/notes/vulcan.md" "Narrowing this stance is vulcan's; widening it is the owner's."
  assert_file_contains "$H/AGENTS.md" "- **vulcan** — backend. Owns \`server/\`: Owns the schema and the API."
  assert_file_contains "$H/AGENTS.md" "| act as vulcan for the first time in a session | [\`notes/vulcan.md\`](notes/vulcan.md) |"

  [ -f "$AGENTS_ROOT/vulcan/home/AGENTS.md" ]
  [ -f "$AGENTS_ROOT/vulcan/home/mise.toml" ]
  [ -f "$AGENTS_ROOT/vulcan/home/SCRATCHPAD.md" ]
  [ -d "$AGENTS_ROOT/vulcan/home/.git" ]
  assert_file_contains "$AGENTS_ROOT/vulcan/home/AGENTS.md" "You own"
  assert_file_contains "$AGENTS_ROOT/vulcan/home/AGENTS.md" "git switch -c vulcan/<short-topic>"
  assert_file_contains "$AGENTS_ROOT/vulcan/home/AGENTS.md" "stalls on its passphrase prompt is reported, not"

  assert_file_contains "$AGENTS_ROOT/vulcan/home/AGENTS.md" "$AGENTS_ROOT/vulcan/home"
  [ -z "$(ls -A "$DEFINITIONS_DIR")" ]
  ! grep -rq '{{' "$H/notes/vulcan.md" "$AGENTS_ROOT/vulcan/home"
  ! grep -rqiwE "$(awk '$1 == "runner" { print $2 }' "$REPO_DIR/lib/lineage-names" | paste -sd '|')" "$H" "$AGENTS_ROOT/vulcan/home"
  ! grep -rq 'lab:decide' "$H/notes/vulcan.md" "$AGENTS_ROOT/vulcan/home"
}

@test "agent add without --owns makes a judge" {
  run lab agent add argus --lab "$H" --role "review and security"
  assert_success
  assert_output_contains "roster: argus (judge)"
  assert_output_contains "its Stance is the framework's for a judge"
  grep -q $'^argus\treview and security\t\tjudge$' "$H/roster.tsv"
  assert_file_contains "$H/AGENTS.md" "- **argus** — review and security. Owns no directory."
  assert_file_contains "$AGENTS_ROOT/argus/home/AGENTS.md" "You own no"
  assert_file_contains "$AGENTS_ROOT/argus/home/AGENTS.md" "stalls on its passphrase prompt is reported, not"
  assert_file_contains "$H/notes/argus.md" "Judgement, not patches"
  assert_file_contains "$H/notes/argus.md" "The diff before the description, and the test before the diff"
  assert_file_says "$H/notes/argus.md" "Narrowing this stance is argus's; widening it is the owner's."
  ! grep -q 'lab:decide' "$H/notes/argus.md"
}

@test "agent add refuses a duplicate and an agent with no role" {
  lab agent add vulcan --lab "$H" --role backend --owns server/
  run lab agent add vulcan --lab "$H" --role backend --owns server/
  assert_failure
  assert_output_contains "already on the roster"
  run lab agent add loki --lab "$H"
  assert_failure
  assert_output_contains "--role is required"
}

@test "agent add keeps a home that exists" {
  mkdir -p "$AGENTS_ROOT/apollo/home"
  printf 'mine\n' > "$AGENTS_ROOT/apollo/home/AGENTS.md"
  run lab agent add apollo --lab "$H" --role music
  assert_success
  assert_output_contains "keep:"
  [ "$(cat "$AGENTS_ROOT/apollo/home/AGENTS.md")" = "mine" ]
}

@test "after agent add the lab's own checks and guard know the new agent" {
  lab agent add vulcan --lab "$H" --role backend --owns server/
  lab agent add argus --lab "$H" --role review
  run in_lab "$H" test
  assert_success

  run in_lab "$H" agent-env vulcan
  assert_success
  assert_output_contains "export GIT_AUTHOR_NAME=vulcan"
  assert_output_contains "export GIT_AUTHOR_EMAIL=vulcan@hearth.invalid"

  run env -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=argus "$H/hooks/agent-identity"
  assert_success
  run env -u HEARTH_OWNER_COMMIT GIT_AUTHOR_NAME=loki "$H/hooks/agent-identity"
  assert_failure
}

@test "agent add resolves the lab from the caller's directory" {
  export CALLER="$H"
  run lab agent add vulcan --role backend --owns server/
  assert_success
  grep -q '^vulcan' "$H/roster.tsv"
}

@test "agent add rejects a directory that is not a lab" {
  run lab agent add vulcan --lab "$BATS_TEST_TMPDIR" --role backend
  assert_failure
  assert_output_contains "not a lab"
}

@test "agent add renders a charge with an ampersand verbatim" {
  run lab agent add caesar --lab "$H" --role payments --owns payments/ --charge 'Takes money & refunds it.'
  assert_success
  assert_file_contains "$H/AGENTS.md" "Takes money & refunds it."
  assert_file_contains "$H/notes/caesar.md" "Takes money & refunds it."
  assert_file_contains "$AGENTS_ROOT/caesar/home/AGENTS.md" "Takes money & refunds it."
  ! grep -rq '{{CHARGE}}' "$H/AGENTS.md" "$H/notes/caesar.md" "$AGENTS_ROOT/caesar/home"
}
