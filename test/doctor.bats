load test_helper

setup() {
  house_setup
  H="$BATS_TEST_TMPDIR/hearth"
  house init hearth --at "$H" >/dev/null
}

@test "doctor is healthy on a fresh house, and warns only about the guard" {
  run house doctor --house "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "ok:   housekeeper: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   nothing here is the framework's: no {{placeholder}}, no lineage name"
  assert_output_contains "warn: pre-commit guard not installed"
  ! [[ "$output" == *"fail:"* ]]
  ! [[ "$output" == *"decide"* ]]
  ! [[ "$output" == *"stance"* ]]
}

@test "doctor warns about an empty roster and a missing housekeeper" {
  printf '# name\trole\towns\tkind\n' > "$H/roster.tsv"
  run house doctor --house "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "warn: roster is empty"
  assert_output_contains "warn: no housekeeper"
  assert_output_contains "warn: pre-commit guard not installed"
}

@test "doctor fails a leftover placeholder in the house or in a home" {
  printf '{{HOUSE_NAME}}\n' >> "$H/README.md"
  printf 'the home of {{AGENT}}\n' >> "$AGENTS_ROOT/hearth/home/SCRATCHPAD.md"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "fail: placeholder: README.md:$(wc -l < "$H/README.md"):{{HOUSE_NAME}}"
  assert_output_contains "fail: placeholder: $AGENTS_ROOT/hearth/home/SCRATCHPAD.md:$(wc -l < "$AGENTS_ROOT/hearth/home/SCRATCHPAD.md"):{{AGENT}}"
  assert_output_contains "doctor: 2 failing"
  assert_output_contains "next: each placeholder: and lineage: line is the owner's to fix"
}

@test "doctor fails a lineage name, but not the house's own name or the tool pin" {
  first="$(awk '$1 == "house" { print $2; exit }' "$REPO_DIR/lib/lineage-names")"
  last="$(awk '$1 == "house" { name = $2 } END { print name }' "$REPO_DIR/lib/lineage-names")"
  printf 'as %s does, and as %s did\n' "$first" "${last^}" >> "$H/notes/work-queue.md"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "fail: lineage: notes/work-queue.md:$(wc -l < "$H/notes/work-queue.md"):as $first does, and as ${last^} did"
  assert_output_contains "doctor: 1 failing"
  ! [[ "$output" == *"fail: lineage: mise.toml"* ]]
  printf 'read KnickKnackLabs/notes\n' >> "$H/notes/work-queue.md"
  run house doctor --house "$H"
  assert_output_contains "fail: lineage: notes/work-queue.md:$(wc -l < "$H/notes/work-queue.md"):read KnickKnackLabs/notes"

  a="$BATS_TEST_TMPDIR/$first"
  house init "$first" --at "$a" --project "the ${first^}" >/dev/null
  run house doctor --house "$a"
  assert_success
}

@test "doctor is quiet once the guard is installed and an agent has everything, and never looks for a harness" {
  in_house "$H" install-hooks >/dev/null
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  run env PATH="$PATH:$HOME/.local/bin" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
  assert_output_contains "ok:   housekeeper: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   vulcan: notes/vulcan.md"
  assert_output_contains "ok:   vulcan: home at"
  ! [[ "$output" == *"warn:"* ]]
  ! [[ "$output" == *"note:"* ]]
  ! [[ "$output" == *"definition"* ]]
  ! [[ "$output" == *"credential"* ]]
  ! [[ "$output" == *"secrets"* ]]
}

@test "doctor fails on a second housekeeper or one under another name" {
  printf 'hestia\thousekeeping\t\thousekeeper\n' >> "$H/roster.tsv"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "fail: hestia: a housekeeper must be named housekeeper"
  assert_output_contains "fail: roster lists 2 housekeepers"
}

@test "doctor reads a roster without a kind column" {
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  house agent add argus --house "$H" --role review >/dev/null
  awk -F '\t' 'BEGIN { OFS = "\t" } /^#/ { print; next } { print $1, $2, $3 }' "$H/roster.tsv" > "$H/roster.new"
  mv "$H/roster.new" "$H/roster.tsv"
  run house doctor --house "$H"
  assert_success
  assert_output_contains "ok:   housekeeper: home at $AGENTS_ROOT/hearth/home"
  assert_output_contains "ok:   vulcan: home at $AGENTS_ROOT/vulcan/home"
  assert_output_contains "ok:   argus: home at $AGENTS_ROOT/argus/home"
}

@test "doctor fails when an agent is on the roster but not in the contract" {
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  sed -i '/^- \*\*vulcan\*\* — /d' "$H/AGENTS.md"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: not listed"
}

@test "doctor fails when a marker or an authority section is gone" {
  sed -i '/^<!-- house:read-first -->$/d' "$H/AGENTS.md"
  sed -i 's/^#### The two-key rule$/#### Two keys/' "$H/AGENTS.md"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "lacks marker <!-- house:read-first -->"
  assert_output_contains "lacks section: #### The two-key rule"
}

@test "doctor fails when the guard is not executable" {
  chmod -x "$H/hooks/agent-identity"
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "hooks/agent-identity is not executable"
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

@test "doctor fails a credential vault under the housekeeper's workspace" {
  grant hearth >/dev/null
  run house doctor --house "$H"
  assert_failure
  assert_output_contains "fail: housekeeper: has $AGENTS_ROOT/hearth/.secrets/identity.txt; a housekeeper has no account, ever"
  assert_output_contains "doctor: 1 failing"
}

@test "doctor checks a granted identity the way secrets will, and skips the round trip when the tools are off PATH" {
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  farm="$(path_without secrets)"
  chmod 640 "$dir/identity.txt"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir/identity.txt is readable by others (mode 640) → chmod 600 $dir/identity.txt"
  ! [[ "$output" == *"credentials at"* ]]
  chmod 600 "$dir/identity.txt"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
  assert_output_contains "ok:   vulcan: credentials at $dir (sops)"
  assert_output_contains "warn: vulcan: secrets is not on PATH, and agent-env points it at this vault → shiv install secrets"
  assert_output_contains "note: vulcan: no vault yet at $dir/vault.enc.yaml; the first secrets set creates it"
  vault "$dir"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
  assert_output_contains "note: vulcan: round trip skipped; secrets list needs both tools on PATH"
  vault "$dir" "age1$(printf 'z%.0s' $(seq 58))"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir/vault.enc.yaml is encrypted to a different recipient than the public-key line of $dir/identity.txt → age-keygen -y $dir/identity.txt prints the right one"
  ! [[ "$output" == *"credentials at"* ]]
  assert_output_contains "doctor: 1 failing"
  vault "$dir"
  chmod 770 "$dir"
  printf '%s\n' "$SECRET_KEY" > "$dir/identity.txt"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir is writable by others (mode 770) → chmod 700 $dir"
  assert_output_contains "fail: vulcan: $dir/identity.txt has no '# public key: age1…' line"
  assert_output_contains "doctor: 2 failing"
}

@test "doctor proves the identity opens the vault through secrets list, under the exports agent-env would print" {
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  vault "$dir"
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$SECRETS_PROVIDER $SECRETS_SOPS_FILE $SECRETS_SOPS_AGE_KEY_FILE $SECRETS_SOPS_RECIPIENT $*" >> "$SECRETS_LOG"\nexit "${SECRETS_EXIT:-0}"\n' > "$bin/secrets"
  printf '#!/usr/bin/env bash\n' > "$bin/sops"
  chmod +x "$bin/secrets" "$bin/sops"
  export SECRETS_LOG="$BATS_TEST_TMPDIR/secrets.log"
  run env PATH="$bin:$PATH" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
  assert_output_contains "ok:   vulcan: secrets opens the vault with this identity"
  ! [[ "$output" == *"warn:"* ]]
  [ "$(cat "$SECRETS_LOG")" = "sops $dir/vault.enc.yaml $dir/identity.txt $RECIPIENT list --prefix vulcan/" ]
  run env PATH="$bin:$PATH" SECRETS_EXIT=1 bash -c 'house "$@"' _ doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: secrets cannot open the vault with this identity → eval \"\$(mise run -q agent-env vulcan)\" in the house, then secrets list --prefix vulcan/ says why"
  assert_output_contains "doctor: 1 failing"
}

@test "doctor judges a symlinked .secrets by the directory it points at, so the fix it names applies" {
  house agent add vulcan --house "$H" --role backend --owns server/ >/dev/null
  dir="$(grant vulcan)"
  farm="$(path_without secrets)"
  mv "$dir" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$dir"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
  assert_output_contains "ok:   vulcan: credentials at $dir (sops)"
  chmod 770 "$BATS_TEST_TMPDIR/elsewhere"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_failure
  assert_output_contains "fail: vulcan: $dir is writable by others (mode 770) → chmod 700 $dir"
  chmod 700 "$dir"
  run env PATH="$farm" bash -c 'house "$@"' _ doctor --house "$H"
  assert_success
}
