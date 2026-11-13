#!/usr/bin/env bats

load test_helper

setup() {
  require_lab_tasks install agent/add doctor
  lab_setup
  H="$BATS_TEST_TMPDIR/hearth"
  lab install hearth --at "$H" >/dev/null
}

@test "doctor is healthy on a fresh lab, and warns only about the guard" {
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "ok:   steward: home note .agents/notes/steward-home.md"
  assert_output_contains "ok:   nothing here is the framework's: no {{placeholder}}, no lineage name"
  assert_output_contains "warn: pre-commit guard not installed"
  ! [[ "$output" == *"fail:"* ]]
  ! [[ "$output" == *"decide"* ]]
  ! [[ "$output" == *"stance"* ]]
}

@test "doctor warns about an empty roster and a missing steward" {
  printf '# name\trole\towns\tkind\n' > "$H/.agents/roster.tsv"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "doctor: healthy"
  assert_output_contains "warn: roster is empty"
  assert_output_contains "warn: no steward"
  assert_output_contains "warn: pre-commit guard not installed"
}

@test "doctor warns when the work root lacks notes/ or keeps a top-level docs/" {
  rm -r "$H/notes"
  mkdir "$H/docs"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "warn: no notes/ at the work root"
  assert_output_contains "warn: docs/ at the work root is the older layout"
  mkdir "$H/notes"
  mv "$H/docs" "$H/notes/docs"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   notes/ at the work root: the product's written memory"
  ! [[ "$output" == *"docs/ at the work root"* ]]
}

@test "doctor warns when .agents/secrets is not git-ignored" {
  mkdir "$H/.agents/secrets"
  sed -i '/^\.agents\/secrets\/$/d' "$H/.gitignore"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "warn: .agents/secrets/ is not git-ignored"
}

@test "doctor fails a leftover placeholder in the lab or in a home note" {
  printf '{{LAB_NAME}}\n' >> "$H/README.md"
  printf 'the home of {{AGENT}}\n' >> "$H/.agents/notes/steward-scratchpad.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: placeholder: README.md:$(wc -l < "$H/README.md"):{{LAB_NAME}}"
  assert_output_contains "fail: placeholder: .agents/notes/steward-scratchpad.md:$(wc -l < "$H/.agents/notes/steward-scratchpad.md"):{{AGENT}}"
  assert_output_contains "doctor: 2 failing"
  assert_output_contains "next: each placeholder: and lineage: line is the owner's to fix"
}

@test "doctor fails a lineage name, but not the lab's own name or the tool pin" {
  first="$(awk '$1 == "lab" { print $2; exit }' "$REPO_DIR/lib/lineage-names")"
  last="$(awk '$1 == "lab" { name = $2 } END { print name }' "$REPO_DIR/lib/lineage-names")"
  printf 'as %s does, and as %s did\n' "$first" "${last^}" >> "$H/.agents/notes/work-queue.md"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: lineage: .agents/notes/work-queue.md:$(wc -l < "$H/.agents/notes/work-queue.md"):as $first does, and as ${last^} did"
  assert_output_contains "doctor: 1 failing"
  ! [[ "$output" == *"fail: lineage: mise.toml"* ]]
  printf 'read KnickKnackLabs/notes\n' >> "$H/.agents/notes/work-queue.md"
  run lab doctor --lab "$H"
  assert_output_contains "fail: lineage: .agents/notes/work-queue.md:$(wc -l < "$H/.agents/notes/work-queue.md"):read KnickKnackLabs/notes"

  a="$BATS_TEST_TMPDIR/$first"
  lab install "$first" --at "$a" --project "the ${first^}" >/dev/null
  run lab doctor --lab "$a"
  assert_success
}

@test "doctor is quiet once the guard is installed and an agent has everything, and never looks for a harness" {
  in_lab "$H" install-hooks >/dev/null
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  run env PATH="$PATH:$HOME/.local/bin" bash -c 'lab "$@"' _ doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   steward: home note .agents/notes/steward-home.md"
  assert_output_contains "ok:   vulcan: .agents/notes/vulcan.md"
  assert_output_contains "ok:   vulcan: home note .agents/notes/vulcan-home.md"
  ! [[ "$output" == *"warn:"* ]]
  ! [[ "$output" == *"note:"* ]]
  ! [[ "$output" == *"definition"* ]]
  ! [[ "$output" == *"credential"* ]]
  ! [[ "$output" == *"secrets"* ]]
}

@test "doctor fails on a second steward or one under another name" {
  printf 'hestia\tstewardship\t\tsteward\n' >> "$H/.agents/roster.tsv"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: hestia: a steward must be named steward"
  assert_output_contains "fail: roster lists 2 stewards"
}

@test "doctor reads a roster without a kind column" {
  lab agent add vulcan --lab "$H" --role backend --owns server/ >/dev/null
  lab agent add argus --lab "$H" --role review >/dev/null
  awk -F '\t' 'BEGIN { OFS = "\t" } /^#/ { print; next } { print $1, $2, $3 }' "$H/.agents/roster.tsv" > "$H/.agents/roster.new"
  mv "$H/.agents/roster.new" "$H/.agents/roster.tsv"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "ok:   steward: home note .agents/notes/steward-home.md"
  assert_output_contains "ok:   vulcan: home note .agents/notes/vulcan-home.md"
  assert_output_contains "ok:   argus: home note .agents/notes/argus-home.md"
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
  chmod -x "$H/.agents/hooks/agent-identity"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains ".agents/hooks/agent-identity is not executable"
}

grant() {
  local dir="$H/.agents/secrets/$1"
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

@test "doctor fails a credential vault under the steward's secrets dir" {
  grant steward >/dev/null
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: steward: has $H/.agents/secrets/steward/identity.txt; a steward has no account, ever"
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

@test "doctor names the two older lab layouts instead of a bare 'not a lab'" {
  old="$BATS_TEST_TMPDIR/old-gen2"
  mkdir -p "$old/.agents"
  touch "$old/.agents/AGENTS.md" "$old/.agents/roster.tsv"
  run lab doctor --lab "$old"
  assert_failure
  assert_output_contains "the contract moved out of .agents/"

  old="$BATS_TEST_TMPDIR/old-gen1"
  mkdir -p "$old"
  touch "$old/AGENTS.md" "$old/roster.tsv"
  run lab doctor --lab "$old"
  assert_failure
  assert_output_contains "artifacts moved under .agents/"
}

@test "doctor fails a missing lab test file" {
  rm "$H/.agents/test/roster.bats"
  run lab doctor --lab "$H"
  assert_failure
  assert_output_contains "fail: .agents/test/roster.bats missing"
}

@test "doctor warns when the work-tree hook is a different file than the lab's guard" {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$H/.git/hooks/pre-commit"
  chmod +x "$H/.git/hooks/pre-commit"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "warn: pre-commit hook at $H/.git/hooks/pre-commit is not this lab's guard → mise run install-hooks"
}

@test "doctor notes a framework file that drifted from the scaffold's render" {
  printf '# owner tweak\n' >> "$H/.agents/tasks/welcome"
  run lab doctor --lab "$H"
  assert_success
  assert_output_contains "note: .agents/tasks/welcome differs from the scaffold's render"
}
