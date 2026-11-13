#!/usr/bin/env bash

# The task surface needs bash 4+ (mapfile, dynamic fds). macOS ships 3.2 —
# say so before the first modern builtin, the way doctor would.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  printf 'Error: peninsula needs bash 4 or newer — this shell is %s\n' "${BASH_VERSION:-not bash}" >&2
  exit 1
fi

PENINSULA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PENINSULA_REPO_DIR="$(cd "$PENINSULA_LIB_DIR/.." && pwd)"
PENINSULA_SCAFFOLD="$PENINSULA_REPO_DIR/scaffold"
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
  printf '%s' "${PENINSULA_CALLER_PWD:-${CALLER_PWD:-$PWD}}"
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
  find "$src_root" -type f | sort | while IFS= read -r src; do
    rel="${src#"$src_root"/}"
    dest="$dest_root/$rel"
    if [ -e "$dest" ]; then
      say "keep: ${dest#"$dest_root"/}"
      continue
    fi
    render "$src" "$dest" "$@"
    case "${dest#"$dest_root"/}" in
      .agents/tasks/*|.agents/hooks/*) chmod +x "$dest" ;;
    esac
    say "create: ${dest#"$dest_root"/}"
  done
}

lab_root() {
  local candidate
  candidate="$(resolve_path "${1:-.}")"
  candidate="$(cd "$candidate" 2>/dev/null && pwd -P)" || die "not a directory: $1"
  if [ -f "$candidate/.agents/roster.tsv" ] && [ -f "$candidate/AGENTS.md" ]; then
    printf '%s\n' "$candidate"
    return
  fi
  if [ -f "$candidate/.agents/AGENTS.md" ] && [ -f "$candidate/.agents/roster.tsv" ]; then
    die "an older lab layout: the contract moved out of .agents/ — move .agents/{AGENTS.md,README.md,mise.toml,.gitignore} up to $(display_path "$candidate"), and .agents/.mise/tasks to .agents/tasks"
  fi
  if [ -f "$candidate/AGENTS.md" ] && [ -f "$candidate/roster.tsv" ]; then
    die "an older lab layout: artifacts moved under .agents/ — move {notes,hooks,test,roster.tsv} under .agents/, and .mise/tasks to .agents/tasks"
  fi
  die "not a lab (no .agents/roster.tsv and AGENTS.md): $candidate"
}

lab_name() {
  local name
  name="$(sed -n 's/^LAB_NAME = "\(.*\)"$/\1/p' "$1/mise.toml" 2>/dev/null | head -1)"
  printf '%s\n' "${name:-$(basename "$1")}"
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
  top="$(git -C "$lab" rev-parse --show-toplevel 2>/dev/null)" || top=""
  if [ -n "$top" ] && [ "$top" != "$lab" ]; then
    printf '%s\n' "$top"
  else
    printf '%s\n' "$lab"
  fi
}

# The lab's .agents/notes, relative to the work repo root — the dir notes
# encrypts (its --dir is repo-relative; a lab made before the install task
# was the only shape could be a subdir of its work repo).
notes_dir_rel() {
  local lab="$1" work="$2" rel
  rel="${lab#"$work"}"
  rel="${rel#/}"
  printf '%s\n' "${rel:+$rel/}.agents/notes"
}

# In-place sed portable across GNU and BSD: -i's suffix is optional on one
# and required on the other — give both a backup name, then remove it.
sedi() {
  local file
  for file; do :; done
  sed -i.bak "$@" && rm -f "$file.bak"
}

# notes' rendered hooks call "run_notes <task>" without --dir, which breaks
# every hook for a non-default notes dir. Each rendered hook defines
# NOTES_ROOT; pass it through. Idempotent: a file already carrying --dir
# (an upstream fix, or this patch) is left alone.
patch_notes_hooks() {
  local hooks_dir="$1" f
  for f in "$hooks_dir"/*.d/obfuscation "$hooks_dir"/*.d/deobfuscation; do
    [ -f "$f" ] || continue
    grep -q -- '--dir' "$f" && continue
    sedi -E "s/run_notes (obfuscate|deobfuscate)/run_notes \\1 --dir \"\$NOTES_ROOT\"/g" "$f"
  done
}

roster_agents() {
  awk -F '\t' '!/^#/ && NF { print $1 }' "$1/.agents/roster.tsv"
}

roster_has() {
  awk -F '\t' -v n="$2" '!/^#/ && $1 == n { found = 1 } END { exit !found }' "$1/.agents/roster.tsv"
}

roster_append() {
  local lab="$1" name="$2" role="$3" owns="$4" kind="$5"
  printf '%s\t%s\t%s\t%s\n' "$name" "$role" "$owns" "$kind" >> "$lab/.agents/roster.tsv"
}

roster_field() {
  awk -F '\t' -v n="$2" -v f="$3" '!/^#/ && $1 == n { print $f; exit }' "$1/.agents/roster.tsv"
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
  awk -F '\t' -v k="$2" '!/^#/ && $4 == k { found = 1 } END { exit !found }' "$1/.agents/roster.tsv"
}

agent_home_note() {
  printf '%s/.agents/notes/%s-home.md\n' "$1" "$2"
}

agent_scratchpad_note() {
  printf '%s/.agents/notes/%s-scratchpad.md\n' "$1" "$2"
}

agent_secrets_dir() {
  printf '%s/.agents/secrets/%s\n' "$1" "$2"
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
  printf '%s\n' "${PENINSULA_TODAY:-$(date +%Y-%m-%d)}"
}

framework_version() {
  if [ -n "${PENINSULA_FRAMEWORK_VERSION:-}" ]; then
    printf '%s\n' "$PENINSULA_FRAMEWORK_VERSION"
    return
  fi
  if [ "$(git -C "$PENINSULA_REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$PENINSULA_REPO_DIR" && pwd -P)" ]; then
    git -C "$PENINSULA_REPO_DIR" describe --tags --exact-match HEAD 2>/dev/null \
      || git -C "$PENINSULA_REPO_DIR" rev-parse --short HEAD 2>/dev/null \
      && return
  fi
  printf 'unknown\n'
}

lab_framework_version() {
  [ -f "$1/README.md" ] || return 0
  local version
  version="$(tr '\n' ' ' < "$1/README.md" \
    | grep -oE 'Started from \[(lab|peninsula)\]\([^)]*\) on [0-9-]+, at [^ ]+\.' \
    | sed 's/.*, at //; s/\.$//' | head -1)" || version=""
  printf '%s\n' "$version"
}

signing_describe() {
  local dir="$1" format key
  [ "$(git -C "$dir" config --type=bool commit.gpgsign 2>/dev/null)" = true ] || return 1
  format="$(git -C "$dir" config gpg.format 2>/dev/null || printf openpgp)"
  key="$(git -C "$dir" config user.signingkey 2>/dev/null)" || key=""
  if [ -n "$key" ]; then
    printf '%s, key %s\n' "$format" "$key"
  else
    printf '%s, no user.signingkey — picked by the committer identity %s\n' "$format" \
      "$(git -C "$dir" var GIT_COMMITTER_IDENT | sed 's/ [0-9]* [-+][0-9]*$//')"
  fi
}

default_charge() {
  case "$1" in
    builder) printf "Builds and maintains everything under \`%s\`.\n" "$2" ;;
    steward) printf '%s\n' "Keeps the lab's written record true: the queue, the backlog, the notes, the branches, and this contract against what is actually on disk. No GitHub identity and no mail, by design." ;;
    *)       printf 'Produces judgement the owner acts on, never patches.\n' ;;
  esac
}

agent_vars() {
  local lab="$1" name="$2" role="$3" owns="$4" charge="$5" kind="$6"
  local lab_name project work
  lab_name="$(lab_name "$lab")"
  project="$(lab_project "$lab")"
  project="${project:-$lab_name}"
  work="$(lab_work_dir "$lab")"
  printf '%s\n' \
    "AGENT=$name" \
    "ROLE=$role" \
    "OWNS=$owns" \
    "CHARGE=$charge" \
    "LAB_NAME=$lab_name" \
    "LAB_UPPER=$(upper_env "$lab_name")" \
    "LAB_PATH=$(display_path "$lab")" \
    "WORK_PATH=$(display_path "$work")" \
    "PROJECT=$project" \
    "HOME_NOTE=$(display_path "$(agent_home_note "$lab" "$name")")" \
    "SCRATCHPAD_NOTE=$(display_path "$(agent_scratchpad_note "$lab" "$name")")" \
    "AUTHOR_DOMAIN=$(lab_author_domain "$lab")" \
    "CREATED=$(today)"
}

ensure_home() {
  local lab="$1" name="$2" kind home_note scratchpad
  shift 2
  kind="$(roster_kind "$lab" "$name")"
  home_note="$(agent_home_note "$lab" "$name")"
  scratchpad="$(agent_scratchpad_note "$lab" "$name")"
  if [ -e "$home_note" ]; then
    say "keep: .agents/notes/$name-home.md already exists"
  else
    render "$PENINSULA_SCAFFOLD/agent/$kind/home.md" "$home_note" "$@"
    say "create: .agents/notes/$name-home.md"
  fi
  if [ -e "$scratchpad" ]; then
    say "keep: .agents/notes/$name-scratchpad.md already exists"
  else
    render "$PENINSULA_SCAFFOLD/agent/scratchpad.md" "$scratchpad" "$@"
    say "create: .agents/notes/$name-scratchpad.md"
  fi
}

add_agent() {
  local lab="$1" name="$2" role="$3" owns="$4" charge="$5"
  local kind roster_line vars vars_text

  validate_name "agent name" "$name"
  kind="$(agent_kind "$name" "$owns")"
  if [ "$kind" = steward ] && [ -n "$owns" ]; then die "the steward owns no directory; drop --owns"; fi
  if roster_has "$lab" "$name"; then
    die "$name is already on the roster of $(display_path "$lab"); missing home notes are made with 'peninsula agent home $name'"
  fi
  if [ "$kind" = steward ] && roster_has_kind "$lab" steward; then
    die "$(display_path "$lab") already has a steward; a lab has exactly one"
  fi

  case "$kind" in
    builder)
      owns="${owns%/}/"
      charge="${charge:-$(default_charge builder "$owns")}"
      roster_line="- **$name** — $role. Owns \`$owns\`: $charge"
      ;;
    judge)
      charge="${charge:-$(default_charge judge)}"
      roster_line="- **$name** — $role. Owns no directory. $charge"
      ;;
    steward)
      charge="${charge:-$(default_charge steward)}"
      roster_line="- **$name** — $role. Owns no directory. $charge"
      ;;
  esac

  vars_text="$(agent_vars "$lab" "$name" "$role" "$owns" "$charge" "$kind")"
  mapfile -t vars <<< "$vars_text"

  roster_append "$lab" "$name" "$role" "$owns" "$kind"
  say "roster: $name ($kind)"

  render "$PENINSULA_SCAFFOLD/agent/$kind/note.md" "$lab/.agents/notes/$name.md" "${vars[@]}"
  say "create: .agents/notes/$name.md"

  if grep -qxF "<!-- lab:roster -->" "$lab/AGENTS.md" \
  && grep -qxF "<!-- lab:read-first -->" "$lab/AGENTS.md"; then
    insert_before_marker "$lab/AGENTS.md" "<!-- lab:roster -->" "$roster_line"
    insert_before_marker "$lab/AGENTS.md" "<!-- lab:read-first -->" \
      "| act as $name for the first time in a session | [\`.agents/notes/$name.md\`](.agents/notes/$name.md) |"
    say "update: AGENTS.md (roster, read-first)"
  else
    say "note: AGENTS.md lacks the lab markers — merge the contract's markers in; $name is on the roster but not in the contract's list"
  fi

  ensure_home "$lab" "$name" "${vars[@]}"
}

lineage_names() {
  local own name
  own=" $(lab_name "$1") $(lab_project "$1" | tr '[:upper:]' '[:lower:]') "
  awk '$1 == "lab" { print $2 }' "$PENINSULA_LIB_DIR/lineage-names" |
  while IFS= read -r name; do
    case "$own" in *" $name "*) ;; *) printf '%s\n' "$name" ;; esac
  done
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
  if [ -z "$value" ]; then
    value="$(git -C "$dir" config "user.$key" 2>/dev/null)" || value=""
  fi
  [ -n "$value" ]
}

on_path() {
  case ":$PATH:" in *":$1:"*) ;; *) return 1 ;; esac
}

# Nearest ancestor-or-self of $1 that is a lab root; rc 1 when there is none.
lab_root_up() {
  local d="$1"
  while :; do
    if [ -f "$d/.agents/roster.tsv" ] && [ -f "$d/AGENTS.md" ]; then
      printf '%s\n' "$d"
      return 0
    fi
    [ "$d" = / ] && return 1
    d="$(dirname "$d")"
  done
}

is_truthy() {
  case "${1:-}" in
    true | 1 | yes | y) return 0 ;;
    *) return 1 ;;
  esac
}

# PENINSULA_YES/MISE_YES answer every confirmation yes — the convention notes'
# confirm_destructive set. Guided choices (which name, which kind) still ask.
peninsula_yes() {
  is_truthy "${PENINSULA_YES:-}" || is_truthy "${MISE_YES:-}"
}

# Answers come from $PENINSULA_PROMPT_TTY when set, else /dev/tty when one opens,
# else stdin — a pipe drives the same prompts without a terminal. The caller
# opens the fd once with ask_open; subshells share its file offset, so every
# ask reads the next line. gum renders only when the source is a real terminal.
ask_open() {
  [ -n "${PENINSULA_ASK_FD:-}" ] && return 0
  [ "${BASHPID:-$$}" = "$$" ] || return 1  # a subshell's fd would die with it — the caller must open first
  PENINSULA_ASK_TTY=""
  PENINSULA_ASK_SRC=""
  if [ -n "${PENINSULA_PROMPT_TTY:-}" ]; then
    { exec {PENINSULA_ASK_FD}<"$PENINSULA_PROMPT_TTY"; } 2>/dev/null || return 1
    if [ -c "$PENINSULA_PROMPT_TTY" ]; then
      PENINSULA_ASK_TTY=1
      PENINSULA_ASK_SRC="$PENINSULA_PROMPT_TTY"
    fi
  elif { exec {PENINSULA_ASK_FD}</dev/tty; } 2>/dev/null; then
    PENINSULA_ASK_TTY=1
    PENINSULA_ASK_SRC=/dev/tty
  else
    exec {PENINSULA_ASK_FD}<&0
  fi
}

ask_have_gum() {
  [ -n "$PENINSULA_ASK_TTY" ] && command -v gum >/dev/null 2>&1
}

ask_read() {
  IFS= read -r -u "$PENINSULA_ASK_FD" "$1"
}

ask_input() {
  local prompt="$1" default="${2:-}" answer rc=0
  ask_open || return 1
  if ask_have_gum; then
    # A terminal device intentionally carries prompt input and output.
    # shellcheck disable=SC2094
    answer="$(gum input --prompt "$prompt " --placeholder "$default" <"$PENINSULA_ASK_SRC" 2>"$PENINSULA_ASK_SRC")" || return 1
  else
    printf '%s%s: ' "$prompt" "${default:+ [$default]}" >&2
    ask_read answer || rc=$?
    { [ "$rc" -eq 0 ] || [ -n "$answer" ]; } || return 1
  fi
  printf '%s\n' "${answer:-$default}"
}

ask_choice() {
  local prompt="$1" opt answer i
  shift
  ask_open || return 1
  if ask_have_gum; then
    # A terminal device intentionally carries prompt input and output.
    # shellcheck disable=SC2094
    gum choose --header "$prompt" "$@" <"$PENINSULA_ASK_SRC" 2>"$PENINSULA_ASK_SRC"
    return
  fi
  printf '%s\n' "$prompt" >&2
  i=1
  for opt in "$@"; do
    printf '  %d) %s\n' "$i" "$opt" >&2
    i=$((i + 1))
  done
  while :; do
    printf '> ' >&2
    ask_read answer || return 1
    case "$answer" in
      "") continue ;;
      *[!0-9]*)
        for opt in "$@"; do
          [ "$answer" = "$opt" ] && { printf '%s\n' "$opt"; return 0; }
        done
        ;;
      *)
        i=1
        for opt in "$@"; do
          [ "$i" -eq "$answer" ] && { printf '%s\n' "$opt"; return 0; }
          i=$((i + 1))
        done
        ;;
    esac
    printf 'choose 1-%d\n' "$#" >&2
  done
}

ask_confirm() {
  local prompt="$1" default="${2:-y}" answer
  ask_open || return 1
  if ask_have_gum; then
    local go=true
    [ "$default" = n ] && go=false
    # A terminal device intentionally carries prompt input, output, and errors.
    # shellcheck disable=SC2094
    gum confirm --default="$go" "$prompt" <"$PENINSULA_ASK_SRC" >"$PENINSULA_ASK_SRC" 2>"$PENINSULA_ASK_SRC"
    return
  fi
  local hint='[y/N]'
  [ "$default" = y ] && hint='[Y/n]'
  while :; do
    printf '%s %s ' "$prompt" "$hint" >&2
    ask_read answer || return 1
    case "${answer:-$default}" in
      y | Y | yes | YES) return 0 ;;
      n | N | no | NO) return 1 ;;
    esac
  done
}
