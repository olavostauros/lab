#!/usr/bin/env bash

HOUSE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOUSE_REPO_DIR="$(cd "$HOUSE_LIB_DIR/.." && pwd)"
HOUSE_SCAFFOLD="$HOUSE_REPO_DIR/scaffold"
HOUSEKEEPER=housekeeper

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
  printf '%s' "${HOUSE_CALLER_PWD:-${HOUSE_FRAMEWORK_CALLER_PWD:-${CALLER_PWD:-$PWD}}}"
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

house_root() {
  local candidate
  candidate="$(resolve_path "${1:-.}")"
  candidate="$(cd "$candidate" 2>/dev/null && pwd -P)" || die "not a directory: $1"
  [ -f "$candidate/roster.tsv" ] && [ -f "$candidate/AGENTS.md" ] \
    || die "not a house (no roster.tsv and AGENTS.md): $candidate"
  printf '%s\n' "$candidate"
}

house_name() {
  basename "$1"
}

house_project() {
  sed -n 's/^HOUSE_PROJECT = "\(.*\)"$/\1/p' "$1/mise.toml" | head -1
}

house_author_domain() {
  local domain
  domain="$(sed -n 's/^HOUSE_AUTHOR_DOMAIN = "\(.*\)"$/\1/p' "$1/mise.toml" | head -1)"
  printf '%s\n' "${domain:-$(house_name "$1").invalid}"
}

house_work_dir() {
  local house="$1" top
  top="$(git -C "$house" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ] && [ "$top" != "$house" ]; then
    printf '%s\n' "$top"
  else
    printf '%s\n' "$house"
  fi
}

roster_agents() {
  awk -F '\t' '!/^#/ && NF { print $1 }' "$1/roster.tsv"
}

roster_has() {
  awk -F '\t' -v n="$2" '!/^#/ && $1 == n { found = 1 } END { exit !found }' "$1/roster.tsv"
}

roster_append() {
  local house="$1" name="$2" role="$3" owns="$4" kind="$5"
  printf '%s\t%s\t%s\t%s\n' "$name" "$role" "$owns" "$kind" >> "$house/roster.tsv"
}

roster_field() {
  awk -F '\t' -v n="$2" -v f="$3" '!/^#/ && $1 == n { print $f; exit }' "$1/roster.tsv"
}

agent_kind() {
  local name="$1" owns="$2"
  if [ "$name" = "$HOUSEKEEPER" ]; then printf 'housekeeper\n'
  elif [ -n "$owns" ]; then printf 'builder\n'
  else printf 'judge\n'
  fi
}

roster_kind() {
  local house="$1" name="$2" kind
  kind="$(roster_field "$house" "$name" 4)"
  if [ -n "$kind" ]; then printf '%s\n' "$kind"; return; fi
  agent_kind "$name" "$(roster_field "$house" "$name" 3)"
}

roster_has_kind() {
  awk -F '\t' -v k="$2" '!/^#/ && $4 == k { found = 1 } END { exit !found }' "$1/roster.tsv"
}

agent_workspace() {
  local house="$1" name="$2" kind="$3" root="${HOUSE_AGENTS_ROOT:-$HOME/agents}"
  if [ "$kind" = housekeeper ]; then
    printf '%s/%s\n' "$root" "$(house_name "$house")"
  else
    printf '%s/%s\n' "$root" "$name"
  fi
}

agent_secrets_dir() {
  printf '%s/.secrets\n' "$(agent_workspace "$@")"
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
  printf '%s\n' "${HOUSE_TODAY:-$(date +%Y-%m-%d)}"
}

framework_version() {
  if [ -n "${HOUSE_FRAMEWORK_VERSION:-}" ]; then
    printf '%s\n' "$HOUSE_FRAMEWORK_VERSION"
    return
  fi
  if [ "$(git -C "$HOUSE_REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$HOUSE_REPO_DIR" && pwd -P)" ]; then
    git -C "$HOUSE_REPO_DIR" describe --tags --exact-match HEAD 2>/dev/null \
      || git -C "$HOUSE_REPO_DIR" rev-parse --short HEAD 2>/dev/null \
      && return
  fi
  printf 'unknown\n'
}

house_framework_version() {
  [ -f "$1/README.md" ] || return 0
  tr '\n' ' ' < "$1/README.md" \
    | grep -oE 'Started from \[house\]\([^)]*\) on [0-9-]+, at [^ ]+\.' \
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
  local house="$1" name="$2" role="$3" owns="$4" charge="$5"
  local kind house_name house_upper project work workspace home_dir roster_line

  validate_name "agent name" "$name"
  kind="$(agent_kind "$name" "$owns")"
  if [ "$kind" = housekeeper ] && [ -n "$owns" ]; then die "the housekeeper owns no directory; drop --owns"; fi
  if roster_has "$house" "$name"; then
    die "$name is already on the roster of $(display_path "$house")"
  fi
  if [ "$kind" = housekeeper ] && roster_has_kind "$house" housekeeper; then
    die "$(display_path "$house") already has a housekeeper; a house has exactly one"
  fi

  house_name="$(house_name "$house")"
  house_upper="$(upper_env "$house_name")"
  project="$(house_project "$house")"
  project="${project:-$house_name}"
  work="$(house_work_dir "$house")"
  workspace="$(agent_workspace "$house" "$name" "$kind")"
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
    housekeeper)
      local default_charge="Keeps the household's written record true: the queue, the backlog, the notes, the branches, and this contract against what is actually on disk. No GitHub identity and no mail, by design."
      charge="${charge:-$default_charge}"
      roster_line="- **$name** — $role. Owns no directory. $charge"
      ;;
  esac

  local vars=(
    "AGENT=$name"
    "ROLE=$role"
    "OWNS=$owns"
    "CHARGE=$charge"
    "HOUSE_NAME=$house_name"
    "HOUSE_UPPER=$house_upper"
    "HOUSE_PATH=$(display_path "$house")"
    "WORK_PATH=$(display_path "$work")"
    "PROJECT=$project"
    "WORKSPACE_PATH=$(display_path "$workspace")"
    "HOME_PATH=$(display_path "$home_dir")"
    "AUTHOR_DOMAIN=$(house_author_domain "$house")"
    "CREATED=$(today)"
  )

  roster_append "$house" "$name" "$role" "$owns" "$kind"
  say "roster: $name ($kind)"

  render "$HOUSE_SCAFFOLD/agent/$kind/note.md" "$house/notes/$name.md" "${vars[@]}"
  say "create: notes/$name.md"

  insert_before_marker "$house/AGENTS.md" "<!-- house:roster -->" "$roster_line"
  insert_before_marker "$house/AGENTS.md" "<!-- house:read-first -->" \
    "| act as $name for the first time in a session | [\`notes/$name.md\`](notes/$name.md) |"
  say "update: AGENTS.md (roster, read-first)"

  if [ -e "$home_dir/AGENTS.md" ]; then
    say "keep: $(display_path "$home_dir") already has an AGENTS.md"
  else
    mkdir -p "$home_dir"
    render "$HOUSE_SCAFFOLD/agent/$kind/AGENTS.md" "$home_dir/AGENTS.md" "${vars[@]}"
    render "$HOUSE_SCAFFOLD/agent/home/mise.toml" "$home_dir/mise.toml" "${vars[@]}"
    render "$HOUSE_SCAFFOLD/agent/home/SCRATCHPAD.md" "$home_dir/SCRATCHPAD.md" "${vars[@]}"
    [ -d "$home_dir/.git" ] || git -C "$home_dir" init -q -b main
    say "create: $(display_path "$home_dir") (AGENTS.md, mise.toml, SCRATCHPAD.md; local repo, no remote)"
  fi
}

lineage_names() {
  local own name
  own=" $(house_name "$1") $(house_project "$1" | tr '[:upper:]' '[:lower:]') "
  while IFS= read -r name; do
    case "$own" in *" $name "*) ;; *) printf '%s\n' "$name" ;; esac
  done < <(awk '$1 == "house" { print $2 }' "$HOUSE_LIB_DIR/lineage-names")
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
