#!/usr/bin/env bash

LAB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_REPO_DIR="$(cd "$LAB_LIB_DIR/.." && pwd)"
LAB_SCAFFOLD="$LAB_REPO_DIR/scaffold"
STEWARD=steward

say() { printf '%s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; }
die() { err "$@"; exit 1; }

validate_name() {
  local what="$1" value="$2"
  [ -n "$value" ] || die "$what is required"
  case "$value" in
    *[!a-z0-9-]* | -* | *-) die "$what must use lowercase letters, digits, and internal hyphens only: $value" ;;
  esac
}

upper_env() {
  printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_'
}

caller_pwd() {
  printf '%s' "${LAB_CALLER_PWD:-${LAB_FRAMEWORK_CALLER_PWD:-${CALLER_PWD:-$PWD}}}"
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$(caller_pwd)" "$1" ;;
  esac
}

canonical_path() {
  local p="$1"
  mkdir -p "$p"
  (cd "$p" && pwd -P)
}

display_path() {
  case "$1" in
    "$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;;
    "$HOME")   printf '~\n' ;;
    *)         printf '%s\n' "$1" ;;
  esac
}

render() {
  local src="$1" dest="$2"
  shift 2
  local content key value
  content="$(cat "$src"; printf x)"
  content="${content%x}"
  for kv in "$@"; do
    key="${kv%%=*}"
    value="${kv#*=}"
    content="${content//"{{$key}}"/"$value"}"
  done
  mkdir -p "$(dirname "$dest")"
  printf '%s' "$content" > "$dest"
}

install_tree() {
  local src_root="$1" dest_root="$2"
  shift 2
  local src rel dest
  while IFS= read -r src; do
    rel="${src#"$src_root"/}"
    dest="$dest_root/$rel"
    if [ -e "$dest" ]; then
      say "keep: ${dest#"$dest_root"/}"
      continue
    fi
    render "$src" "$dest" "$@"
    case "${dest#"$dest_root"/}" in
      .mise/tasks/*|hooks/*) chmod +x "$dest" ;;
    esac
    say "create: ${dest#"$dest_root"/}"
  done < <(find "$src_root" -type f | sort)
}

lab_root() {
  local candidate
  candidate="$(resolve_path "${1:-.}")"
  candidate="$(cd "$candidate" 2>/dev/null && pwd -P)" || die "not a directory: $1"
  [ -f "$candidate/roster.tsv" ] && [ -f "$candidate/AGENTS.md" ] \
    || die "not a lab (no roster.tsv and AGENTS.md): $candidate"
  printf '%s\n' "$candidate"
}

lab_name() {
  basename "$1"
}

lab_project() {
  sed -n 's/^LAB_PROJECT = "\(.*\)"$/\1/p' "$1/mise.toml" | head -1
}

lab_author_domain() {
  local domain
  domain="$(sed -n 's/^LAB_AUTHOR_DOMAIN = "\(.*\)"$/\1/p' "$1/mise.toml" | head -1)"
  printf '%s\n' "${domain:-$(lab_name "$1").invalid}"
}

lab_work_dir() {
  local lab="$1" top
  top="$(git -C "$lab" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ] && [ "$top" != "$lab" ]; then
    printf '%s\n' "$top"
  else
    printf '%s\n' "$lab"
  fi
}

roster_agents() {
  awk -F '\t' '!/^#/ && NF { print $1 }' "$1/roster.tsv"
}

roster_has() {
  awk -F '\t' -v n="$2" '!/^#/ && $1 == n { found = 1 } END { exit !found }' "$1/roster.tsv"
}

roster_append() {
  local lab="$1" name="$2" role="$3" owns="$4" kind="$5"
  printf '%s\t%s\t%s\t%s\n' "$name" "$role" "$owns" "$kind" >> "$lab/roster.tsv"
}

roster_field() {
  awk -F '\t' -v n="$2" -v f="$3" '!/^#/ && $1 == n { print $f; exit }' "$1/roster.tsv"
}

agent_kind() {
  local name="$1" owns="$2"
  if [ "$name" = "$STEWARD" ]; then printf 'steward\n'
  elif [ -n "$owns" ]; then printf 'builder\n'
  else printf 'judge\n'
  fi
}

roster_kind() {
  local lab="$1" name="$2" kind
  kind="$(roster_field "$lab" "$name" 4)"
  if [ -n "$kind" ]; then printf '%s\n' "$kind"; return; fi
  agent_kind "$name" "$(roster_field "$lab" "$name" 3)"
}

roster_has_kind() {
  awk -F '\t' -v k="$2" '!/^#/ && $4 == k { found = 1 } END { exit !found }' "$1/roster.tsv"
}

agent_workspace() {
  local lab="$1" name="$2" kind="$3" root="${LAB_AGENTS_ROOT:-$HOME/agents}"
  if [ "$kind" = steward ]; then
    printf '%s/%s\n' "$root" "$(lab_name "$lab")"
  else
    printf '%s/%s\n' "$root" "$name"
  fi
}

insert_before_marker() {
  local file="$1" marker="$2" text="$3"
  local tmp line found=0
  grep -qxF "$marker" "$file" || die "marker missing in $file: $marker"
  tmp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$marker" ] && [ "$found" -eq 0 ]; then
      printf '%s\n' "$text"
      found=1
    fi
    printf '%s\n' "$line"
  done < "$file" > "$tmp"
  mv "$tmp" "$file"
}

today() {
  printf '%s\n' "${LAB_TODAY:-$(date +%Y-%m-%d)}"
}

framework_version() {
  if [ -n "${LAB_FRAMEWORK_VERSION:-}" ]; then
    printf '%s\n' "$LAB_FRAMEWORK_VERSION"
    return
  fi
  if [ "$(git -C "$LAB_REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$LAB_REPO_DIR" && pwd -P)" ]; then
    git -C "$LAB_REPO_DIR" describe --tags --exact-match HEAD 2>/dev/null \
      || git -C "$LAB_REPO_DIR" rev-parse --short HEAD 2>/dev/null \
      && return
  fi
  printf 'unknown\n'
}

lab_framework_version() {
  [ -f "$1/README.md" ] || return 0
  tr '\n' ' ' < "$1/README.md" \
    | grep -oE 'Started from \[lab\]\([^)]*\) on [0-9-]+, at [^ ]+\.' \
    | sed 's/.*, at //; s/\.$//' | head -1 || true
}

signing_describe() {
  local dir="$1" format key
  [ "$(git -C "$dir" config --type=bool commit.gpgsign 2>/dev/null)" = true ] || return 1
  format="$(git -C "$dir" config gpg.format 2>/dev/null || printf openpgp)"
  key="$(git -C "$dir" config user.signingkey 2>/dev/null || true)"
  if [ -n "$key" ]; then
    printf '%s, key %s\n' "$format" "$key"
  else
    printf '%s, no user.signingkey — picked by the committer identity %s\n' "$format" \
      "$(git -C "$dir" var GIT_COMMITTER_IDENT | sed 's/ [0-9]* [-+][0-9]*$//')"
  fi
}

add_agent() {
  local lab="$1" name="$2" role="$3" owns="$4" charge="$5"
  local kind lab_name lab_upper project work workspace home_dir roster_line

  validate_name "agent name" "$name"
  kind="$(agent_kind "$name" "$owns")"
  if [ "$kind" = steward ] && [ -n "$owns" ]; then die "the steward owns no directory; drop --owns"; fi
  if roster_has "$lab" "$name"; then
    die "$name is already on the roster of $(display_path "$lab")"
  fi
  if [ "$kind" = steward ] && roster_has_kind "$lab" steward; then
    die "$(display_path "$lab") already has a steward; a lab has exactly one"
  fi

  lab_name="$(lab_name "$lab")"
  lab_upper="$(upper_env "$lab_name")"
  project="$(lab_project "$lab")"
  project="${project:-$lab_name}"
  work="$(lab_work_dir "$lab")"
  workspace="$(agent_workspace "$lab" "$name" "$kind")"
  home_dir="$workspace/home"

  case "$kind" in
    builder)
      owns="${owns%/}/"
      charge="${charge:-Builds and maintains everything under \`$owns\`.}"
      roster_line="- **$name** — $role. Owns \`$owns\`: $charge"
      ;;
    judge)
      charge="${charge:-Produces judgement the owner acts on, never patches.}"
      roster_line="- **$name** — $role. Owns no directory. $charge"
      ;;
    steward)
      local default_charge="Keeps the lab's written record true: the queue, the backlog, the notes, the branches, and this contract against what is actually on disk. No GitHub identity and no mail, by design."
      charge="${charge:-$default_charge}"
      roster_line="- **$name** — $role. Owns no directory. $charge"
      ;;
  esac

  local vars=(
    "AGENT=$name"
    "ROLE=$role"
    "OWNS=$owns"
    "CHARGE=$charge"
    "LAB_NAME=$lab_name"
    "LAB_UPPER=$lab_upper"
    "LAB_PATH=$(display_path "$lab")"
    "WORK_PATH=$(display_path "$work")"
    "PROJECT=$project"
    "WORKSPACE_PATH=$(display_path "$workspace")"
    "HOME_PATH=$(display_path "$home_dir")"
    "AUTHOR_DOMAIN=$(lab_author_domain "$lab")"
    "CREATED=$(today)"
  )

  roster_append "$lab" "$name" "$role" "$owns" "$kind"
  say "roster: $name ($kind)"

  render "$LAB_SCAFFOLD/agent/$kind/note.md" "$lab/notes/$name.md" "${vars[@]}"
  say "create: notes/$name.md"

  insert_before_marker "$lab/AGENTS.md" "<!-- lab:roster -->" "$roster_line"
  insert_before_marker "$lab/AGENTS.md" "<!-- lab:read-first -->" \
    "| act as $name for the first time in a session | [\`notes/$name.md\`](notes/$name.md) |"
  say "update: AGENTS.md (roster, read-first)"

  if [ -e "$home_dir/AGENTS.md" ]; then
    say "keep: $(display_path "$home_dir") already has an AGENTS.md"
  else
    mkdir -p "$home_dir"
    render "$LAB_SCAFFOLD/agent/$kind/AGENTS.md" "$home_dir/AGENTS.md" "${vars[@]}"
    render "$LAB_SCAFFOLD/agent/home/mise.toml" "$home_dir/mise.toml" "${vars[@]}"
    render "$LAB_SCAFFOLD/agent/home/SCRATCHPAD.md" "$home_dir/SCRATCHPAD.md" "${vars[@]}"
    [ -d "$home_dir/.git" ] || git -C "$home_dir" init -q -b main
    say "create: $(display_path "$home_dir") (AGENTS.md, mise.toml, SCRATCHPAD.md; local repo, no remote)"
  fi
}

lineage_names() {
  local own name
  own=" $(lab_name "$1") $(lab_project "$1" | tr '[:upper:]' '[:lower:]') "
  while IFS= read -r name; do
    case "$own" in *" $name "*) ;; *) printf '%s\n' "$name" ;; esac
  done < <(awk '$1 == "lab" { print $2 }' "$LAB_LIB_DIR/lineage-names")
}

bash_version() {
  bash --version 2>/dev/null | sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p'
}

git_version() {
  git --version 2>/dev/null | sed -n '1s/^git version \([0-9][0-9.]*\).*/\1/p'
}

version_at_least() {
  local have_major have_minor want_major want_minor
  IFS=. read -r have_major have_minor _ <<< "$1"
  IFS=. read -r want_major want_minor _ <<< "$2"
  [ "${have_major:-0}" -gt "${want_major:-0}" ] \
    || { [ "${have_major:-0}" -eq "${want_major:-0}" ] && [ "${have_minor:-0}" -ge "${want_minor:-0}" ]; }
}

git_identity() {
  local dir="$1" key="$2" value=""
  case "$key" in
    name)  value="${GIT_AUTHOR_NAME:-${GIT_COMMITTER_NAME:-}}" ;;
    email) value="${GIT_AUTHOR_EMAIL:-${GIT_COMMITTER_EMAIL:-}}" ;;
  esac
  [ -n "${value:-$(git -C "$dir" config "user.$key" 2>/dev/null || true)}" ]
}

on_path() {
  case ":$PATH:" in *":$1:"*) ;; *) return 1 ;; esac
}
