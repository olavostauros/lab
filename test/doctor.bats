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
  ! [[ "$output" == *"note:"* ]]
  ! [[ "$output" == *"definition"* ]]
  ! [[ "$output" == *"credential"* ]]
  ! [[ "$output" == *"secrets"* ]]
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

@test "doctor fails a WORK_DIR that misses the top of the repo, and names the right one" {
  project="$(make_project)"
  lab init hall --at "$project/labs/hall" --embedded >/dev/null
  sed -i 's|^WORK_DIR = .*|WORK_DIR = "{{ config_root }}/.."|' "$project/labs/hall/mise.toml"
  run lab doctor --lab "$project/labs/hall"
  assert_failure
  assert_output_contains "fail: WORK_DIR in mise.toml resolves to $project/labs, not the work tree $project"
  assert_output_contains 'set WORK_DIR = "{{ config_root }}/../.."'
}

@test "doctor leaves an owner's own WORK_DIR expression alone" {
  sed -i 's|^WORK_DIR = .*|WORK_DIR = "{{ env.HOME }}"|' "$H/mise.toml"
  run lab doctor --lab "$H"
  assert_success
  ! [[ "$output" == *"WORK_DIR"* ]]
}

@test "doctor warns when the installed guard dangles after a move" {
  in_lab "$H" install-hooks >/dev/null
  mv "$H" "$BATS_TEST_TMPDIR/moved"
  run lab doctor --lab "$BATS_TEST_TMPDIR/moved"
  assert_success
  assert_output_contains "warn: pre-commit guard points at $H/hooks/agent-identity, which is gone (was the lab moved?) → mise run install-hooks"
  in_lab "$BATS_TEST_TMPDIR/moved" install-hooks >/dev/null
  run lab doctor --lab "$BATS_TEST_TMPDIR/moved"
  assert_output_contains "ok:   pre-commit guard installed in the work tree"
}

grant() {
  local dir="$AGENTS_ROOT/$1/.secrets"
  mkdir -p "$dir"
  chmod 700 "$dir"
  printf '# created: 2026-01-01T00:00:00Z\n# public key: %s\n%s\n' "$RECIPIENT" "$SECRET_KEY" > "$dir/identity.txt"
  chmod 600 "$dir/identity.txt"
  printf '%s' "$dir"
}

vault() {
  printf 'vulcan/github-pat: ENC[AES256_GCM,data:x,type:str]\nsops:\n    age:\n        - recipient: %s\n          enc: |\n            x\n' "${2:-$RECIPIENT}" > "$1/vault.enc.yaml"
  chmod 600 "$1/vault.enc.yaml"
}
RECIPIENT="age1$(printf 'q%.0s' $(seq 58))"
SECRET_KEY="AGE-SECRET-KEY-1$(printf 'Q%.0s' $(seq 58))"

@test "doctor fails a credential vault under the steward's workspace" {
  grant hearth >/dev/null
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: steward: has $AGENTS_ROOT/hearth/.secrets/identity.txt; a steward has no account, ever"
  assert_output_contains "doctor: 1 failing"
}

@test "doctor checks a granted identity the way secrets will, and skips the round trip when the tools are off PATH" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  farm="$(path_without secrets)"
  chmod 640 "$dir/identity.txt"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir/identity.txt is readable by others (mode 640) → chmod 600 $dir/identity.txt"
  ! [[ "$output" == *"credentials at"* ]]
  chmod 600 "$dir/identity.txt"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   vulcan: credentials at $dir (sops)"
  assert_output_contains "warn: vulcan: secrets is not on PATH, and agent-env points it at this vault → shiv install secrets"
  assert_output_contains "note: vulcan: no vault yet at $dir/vault.enc.yaml; the first secrets set creates it"
  vault "$dir"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "note: vulcan: round trip skipped; secrets list needs both tools on PATH"
  vault "$dir" "age1$(printf 'z%.0s' $(seq 58))"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir/vault.enc.yaml is encrypted to a different recipient than the public-key line of $dir/identity.txt → age-keygen -y $dir/identity.txt prints the right one"
  ! [[ "$output" == *"credentials at"* ]]
  assert_output_contains "doctor: 1 failing"
  vault "$dir"
  chmod 770 "$dir"
  printf '%s\n' "$SECRET_KEY" > "$dir/identity.txt"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir is writable by others (mode 770) → chmod 700 $dir"
  assert_output_contains "fail: vulcan: $dir/identity.txt has no '# public key: age1…' line"
  assert_output_contains "doctor: 2 failing"
}

@test "doctor proves the identity opens the vault through secrets list, under the exports agent-env would print" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  vault "$dir"
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$SECRETS_PROVIDER $SECRETS_SOPS_FILE $SECRETS_SOPS_AGE_KEY_FILE $SECRETS_SOPS_RECIPIENT $*" >> "$SECRETS_LOG"\nexit "${SECRETS_EXIT:-0}"\n' > "$bin/secrets"
  printf '#!/usr/bin/env bash\n' > "$bin/sops"
  chmod +x "$bin/secrets" "$bin/sops"
  export SECRETS_LOG="$BATS_TEST_TMPDIR/secrets.log"
  run env PATH="$bin:$PATH" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   vulcan: secrets opens the vault with this identity"
  ! [[ "$output" == *"warn:"* ]]
  [ "$(cat "$SECRETS_LOG")" = "sops $dir/vault.enc.yaml $dir/identity.txt $RECIPIENT list --prefix vulcan/" ]
  run env PATH="$bin:$PATH" SECRETS_EXIT=1 bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: secrets cannot open the vault with this identity → eval \"\$(mise run -q agent-env vulcan)\" in the lab, then secrets list --prefix vulcan/ says why"
  assert_output_contains "doctor: 1 failing"
}

@test "doctor judges a symlinked .secrets by the directory it points at, so the fix it names applies" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  farm="$(path_without secrets)"
  mv "$dir" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$dir"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   vulcan: credentials at $dir (sops)"
  chmod 770 "$BATS_TEST_TMPDIR/elsewhere"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir is writable by others (mode 770) → chmod 700 $dir"
  chmod 700 "$dir"
  run env PATH="$farm" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
}
