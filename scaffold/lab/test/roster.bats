setup() {
  LAB="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "every agent on the roster has an identity note" {
  while IFS= read -r name; do
    [ -f "$LAB/notes/$name.md" ]
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$LAB/roster.tsv")
}

@test "every agent on the roster is listed under Who lives here" {
  while IFS= read -r name; do
    grep -q "^- \*\*$name\*\* — " "$LAB/AGENTS.md"
  done < <(awk -F '\t' '!/^#/ && NF { print $1 }' "$LAB/roster.tsv")
}

@test "the contract keeps its markers and its authority sections" {
  for marker in "<!-- lab:roster -->" "<!-- lab:read-first -->"; do
    grep -qxF "$marker" "$LAB/AGENTS.md"
  done
  grep -qxF "### The tiers — canonical list" "$LAB/AGENTS.md"
  grep -qxF "### The loosenings — canonical list" "$LAB/AGENTS.md"
  grep -qxF "#### The two-key rule" "$LAB/AGENTS.md"
}

@test "the roster has at most one steward and it is named steward" {
  keepers="$(awk -F '\t' '!/^#/ && $4 == "steward" { print $1 }' "$LAB/roster.tsv")"
  [ "$(printf '%s' "$keepers" | grep -c .)" -le 1 ]
  [ -z "$keepers" ] || [ "$keepers" = steward ]
}
