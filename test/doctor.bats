load test_helper

setup() {
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab init hearth --at "$H" >/dev/null
}

@test "doctor is healthy on a fresh lab, and warns only about the guard" {
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "ok:   steward: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   nothing here is the framework's: no {{placeholder}}, no lineage name"
  assert_output_contains "warn: pre-commit guard not installed"
  ! [[ "$output" == *"fail:"* ]]
  ! [[ "$output" == *"decide"* ]]
  ! [[ "$output" == *"stance"* ]]
}

@test "doctor warns about an empty roster and a missing steward" {
  printf '# name\trole\towns\tkind\n' > "$H/roster.tsv"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "warn: roster is empty"
  assert_output_contains "warn: no steward"
  assert_output_contains "warn: pre-commit guard not installed"
}

@test "doctor fails a leftover placeholder in the lab or in a home" {
  printf '{{LAB_NAME}}\n' >> "$H/README.md"
  printf 'the home of {{AGENT}}\n' >> "$AGENTS_ROOT/hearth/home/SCRATCHPAD.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: placeholder: README.md:$(wc -l < "$H/README.md"):{{LAB_NAME}}"
  assert_output_contains "fail: placeholder: $AGENTS_ROOT/hearth/home/SCRATCHPAD.md:$(wc -l < "$AGENTS_ROOT/hearth/home/SCRATCHPAD.md"):{{AGENT}}"
  assert_output_contains "doctor: 2 failing"
  assert_output_contains "next: each placeholder: and lineage: line is the owner's to fix"
}

@test "doctor fails a lineage name, but not the lab's own name or the tool pin" {
  first="$(awk '$1 == "lab" { print $2; exit }' "$REPO_DIR/lib/lineage-names")"
  last="$(awk '$1 == "lab" { name = $2 } END { print name }' "$REPO_DIR/lib/lineage-names")"
  printf 'as %s does, and as %s did\n' "$first" "${last^}" >> "$H/notes/work-queue.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: lineage: notes/work-queue.md:$(wc -l < "$H/notes/work-queue.md"):as $first does, and as ${last^} did"
  assert_output_contains "doctor: 1 failing"
  ! [[ "$output" == *"fail: lineage: mise.toml"* ]]
  printf 'read KnickKnackLabs/notes\n' >> "$H/notes/work-queue.md"
  run lab doctor --lab "$H"
  assert_output_contains "fail: lineage: notes/work-queue.md:$(wc -l < "$H/notes/work-queue.md"):read KnickKnackLabs/notes"

  a="$BATS_TEST_TMPDIR/$first"
  lab init "$first" --at "$a" --project "the ${first^}" >/dev/null
  run lab doctor --lab "$a"
  assert_success
}

@test "doctor is quiet once the guard is installed and an agent has everything, and never looks for a harness" {
  in_lab "$H" install-hooks >/dev/null
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  run env PATH="$PATH:$HOME/.local/bin" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   steward: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   vulcan: notes/vulcan.md"
  assert_output_contains "ok:   vulcan: home at"
  ! [[ "$output" == *"warn:"* ]]
  ! [[ "$output" == *"definition"* ]]
}

@test "doctor fails on a second steward or one under another name" {
  printf 'hestia\tstewardship\t\tsteward\n' >> "$H/roster.tsv"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: hestia: a steward must be named steward"
  assert_output_contains "fail: roster lists 2 stewards"
}

@test "doctor reads a roster without a kind column" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  lab agent add argus --lab "$H" --role review >/dev/null
  awk -F '\t' 'BEGIN { OFS = "\t" } /^#/ { print; next } { print $1, $2, $3 }' "$H/roster.tsv" > "$H/roster.new"
  mv "$H/roster.new" "$H/roster.tsv"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   steward: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   vulcan: home at $AGENTS_ROOT/vulcan/home"
  assert_output_contains "ok:   argus: home at $AGENTS_ROOT/argus/home"
}

@test "doctor fails when an agent is on the roster but not in the contract" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  sed -i '/^- \*\*vulcan\*\* — /d' "$H/AGENTS.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: not listed"
}

@test "doctor fails when a marker or an authority section is gone" {
  sed -i '/^<!-- lab:read-first -->$/d' "$H/AGENTS.md"
  sed -i 's/^#### The two-key rule$/#### Two keys/' "$H/AGENTS.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "lacks marker <!-- lab:read-first -->"
  assert_output_contains "lacks section: #### The two-key rule"
}

@test "doctor fails when the guard is not executable" {
  chmod -x "$H/hooks/agent-identity"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "hooks/agent-identity is not executable"
}
