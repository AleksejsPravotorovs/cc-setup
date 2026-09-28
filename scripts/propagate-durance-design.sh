#!/usr/bin/env bash
# propagate-durance-design.sh
# Idempotently install the durance-design skill (the design + frontend doctrine
# distilled from the durance.dev rework, 2026-09) into every repo that has a
# frontend:
#
#   <repo>/.claude/skills/durance-design/SKILL.md
#   <repo>/.claude/skills/durance-design/{references,templates,scripts}/*
#
# Source of truth: skills/durance-design/ in this cc-setup clone. The copy is
# byte-identical everywhere; hand edits in a repo are detected and skipped unless
# --force is given (the skill is fleet-owned; put project-specific rules in the
# project's CLAUDE.md instead).
#
# Repo discovery, union of two sources:
#   1. Obsidian vault Projects/<slug>.md notes with a `local_path:` (fleet convention,
#      same skip rules as propagate-design-loop.sh).
#   2. --scan <dir> (repeatable; default ~/Downloads): every child directory that is a
#      git repo. Bare directories without .git are skipped unless --include-non-git.
# A repo qualifies when it HAS A FRONTEND: a package.json (root or one level down,
# not node_modules) that depends on next/react/vue/svelte/vite/astro/nuxt/solid, or
# an index.html at the root or one level down (static sites), excluding dist/,
# build/, .next/, node_modules/. Everything else is skipped.
#
# Writes with `cp` from a shell script ON PURPOSE: AGENTS.md Rule 1 bans the
# Write/Edit tools on `.claude/**`; a script is the sanctioned path there.
#
# Usage:
#   ./scripts/propagate-durance-design.sh --dry-run --verbose
#   ./scripts/propagate-durance-design.sh --only durance.dev
#   ./scripts/propagate-durance-design.sh --scan ~/Downloads --scan ~/work
#   ./scripts/propagate-durance-design.sh --force        # overwrite hand-edited copies
#   ./scripts/propagate-durance-design.sh                # writes for real
#
# Safety: symlinked destinations are refused; never runs git.
# Compatible with bash 3.2 (macOS system bash).

set -euo pipefail

VAULT="/Users/aleksejpravotorov/Desktop/My AI Knowledge Base"
PROJECTS_DIR="$VAULT/Projects"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/skills/durance-design"
REL_DEST=".claude/skills/durance-design"

DRY_RUN=0; VERBOSE=0; FORCE=0; ONLY=""; INCLUDE_NON_GIT=0
SCAN_DIRS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --force) FORCE=1 ;;
    --include-non-git) INCLUDE_NON_GIT=1 ;;
    --scan) shift; SCAN_DIRS="$SCAN_DIRS
${1:-}" ;;
    --only) shift; ONLY="${1:-}"; [ -n "$ONLY" ] || { echo "ERROR: --only needs a name" >&2; exit 2; } ;;
    -h|--help) /usr/bin/sed -n '2,/^$/p' "$0" | /usr/bin/sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$(printf '%s' "$SCAN_DIRS" | tr -d '\n')" ] || SCAN_DIRS="$HOME/Downloads"

log() { if [ "$VERBOSE" = "1" ]; then echo "$*" >&2; fi; }

# ---- validate the source skill --------------------------------------------
[ -f "$SKILL_SRC/SKILL.md" ] || { echo "ERROR: source skill missing: $SKILL_SRC/SKILL.md" >&2; exit 2; }
/usr/bin/head -n 1 "$SKILL_SRC/SKILL.md" | /usr/bin/grep -q '^---' || { echo "ERROR: SKILL.md has no YAML frontmatter" >&2; exit 2; }
/usr/bin/grep -q '^name:[[:space:]]*durance-design[[:space:]]*$' "$SKILL_SRC/SKILL.md" || { echo "ERROR: frontmatter lacks 'name: durance-design'" >&2; exit 2; }
if LC_ALL=C /usr/bin/grep -rq $'\xe2\x80\x94' "$SKILL_SRC"; then
  echo "ERROR: source contains an em-dash (U+2014) - house style forbids it" >&2; exit 2
fi
SRC_FILES=$(cd "$SKILL_SRC" && /usr/bin/find . -type f \( -name '*.md' -o -name '*.css' -o -name '*.tsx' -o -name '*.mjs' -o -name '*.sh' \) | /usr/bin/sed 's|^\./||' | /usr/bin/sort)

# ---- repo discovery --------------------------------------------------------
get_fm() {  # file key
  /usr/bin/awk -v k="$2" '
    NR==1 && /^---[[:space:]]*$/ {fm=1; next}
    fm && /^---[[:space:]]*$/ {exit}
    fm && match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*") {
      v=substr($0, RLENGTH+1); sub(/[[:space:]]+$/,"",v)
      if (v ~ /^".*"$/) v=substr(v,2,length(v)-2)
      print v; exit }' "$1"
}

has_frontend() {  # dir -> 0/1
  local d="$1" pj
  for pj in "$d/package.json" "$d"/*/package.json; do
    [ -f "$pj" ] || continue
    case "$pj" in */node_modules/*|*/.next/*|*/dist/*|*/build/*) continue ;; esac
    if /usr/bin/grep -Eq '"(next|react|vue|svelte|vite|astro|nuxt|solid-js|@angular/core)"[[:space:]]*:' "$pj"; then return 0; fi
  done
  local h
  for h in "$d/index.html" "$d"/*/index.html; do
    [ -f "$h" ] || continue
    case "$h" in */node_modules/*|*/.next/*|*/dist/*|*/build/*|*/out/*|*/coverage/*) continue ;; esac
    return 0
  done
  return 1
}

CANDIDATES=""
add_candidate() { CANDIDATES="$CANDIDATES
$1"; }

if [ -d "$PROJECTS_DIR" ]; then
  for note in "$PROJECTS_DIR"/*.md; do
    [ -f "$note" ] || continue
    base=$(/usr/bin/basename "$note" .md)
    case "$base" in _*|README|*-state) continue ;; esac
    [ "$(get_fm "$note" status)" = "archived" ] && continue
    lp=$(get_fm "$note" local_path)
    [ -n "$lp" ] && [ -d "$lp" ] && add_candidate "$lp"
  done
else
  log "vault Projects dir not found ($PROJECTS_DIR) - filesystem scan only"
fi

while IFS= read -r sd; do
  [ -n "$sd" ] || continue
  case "$sd" in "~"*) sd="$HOME${sd#\~}" ;; esac
  [ -d "$sd" ] || { log "scan dir missing: $sd"; continue; }
  for d in "$sd"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    if [ ! -d "$d/.git" ] && [ "$INCLUDE_NON_GIT" = "0" ]; then continue; fi
    add_candidate "$d"
  done
done <<EOS
$SCAN_DIRS
EOS

# de-dupe, keep order
REPOS=$(printf '%s\n' "$CANDIDATES" | /usr/bin/sed '/^$/d' | /usr/bin/awk '!seen[$0]++')

COUNT_INSTALLED=0; COUNT_UPDATED=0; COUNT_NOOP=0; COUNT_SKIP=0; COUNT_WARN=0; ERRORS=0; MATCHED_ONLY=0

install_into() {
  local repo="$1" name dst
  name=$(/usr/bin/basename "$repo")
  if [ -n "$ONLY" ] && [ "$name" != "$ONLY" ]; then return 0; fi
  if [ "$repo" = "$(cd "$SCRIPT_DIR/.." && pwd)" ]; then return 0; fi   # cc-setup itself keeps the source
  if ! has_frontend "$repo"; then log "skip:  $name (no frontend)"; COUNT_SKIP=$((COUNT_SKIP+1)); return 0; fi
  [ -n "$ONLY" ] && MATCHED_ONLY=1
  dst="$repo/$REL_DEST"
  if [ -L "$dst" ] || [ -L "$dst/SKILL.md" ]; then echo "ERROR: $dst is a symlink - refusing" >&2; ERRORS=$((ERRORS+1)); return 0; fi

  # compare every source file; classify
  local state="noop" f
  if [ ! -f "$dst/SKILL.md" ]; then state="install"
  else
    for f in $SRC_FILES; do
      if [ ! -f "$dst/$f" ] || ! /usr/bin/cmp -s "$SKILL_SRC/$f" "$dst/$f"; then state="update"; break; fi
    done
  fi
  if [ "$state" = "noop" ]; then log "ok:    $name (canonical)"; COUNT_NOOP=$((COUNT_NOOP+1)); return 0; fi

  if [ "$state" = "update" ] && [ "$FORCE" = "0" ]; then
    # hand-edited = destination SKILL.md carries no fleet stamp line
    if ! /usr/bin/grep -q '^<!-- fleet: durance-design' "$dst/SKILL.md" 2>/dev/null; then
      echo "WARN: $dst/SKILL.md has no fleet stamp (hand-edited?) - skipped. --force to replace." >&2
      COUNT_WARN=$((COUNT_WARN+1)); COUNT_SKIP=$((COUNT_SKIP+1)); return 0
    fi
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY:   would $state $dst"
    [ "$state" = "install" ] && COUNT_INSTALLED=$((COUNT_INSTALLED+1)) || COUNT_UPDATED=$((COUNT_UPDATED+1))
    return 0
  fi
  /bin/mkdir -p "$dst" || { echo "ERROR: cannot create $dst" >&2; ERRORS=$((ERRORS+1)); return 0; }
  for f in $SRC_FILES; do
    /bin/mkdir -p "$(/usr/bin/dirname "$dst/$f")"
    /bin/cp "$SKILL_SRC/$f" "$dst/$f"
  done
  /bin/chmod +x "$dst"/scripts/*.sh 2>/dev/null || true
  # remove stale files that the source no longer ships (references, templates, scripts)
  for sub in references templates scripts; do
    [ -d "$dst/$sub" ] || continue
    for f in "$dst/$sub"/*; do
      [ -f "$f" ] || continue
      rel="$sub/$(/usr/bin/basename "$f")"
      printf '%s\n' "$SRC_FILES" | /usr/bin/grep -qx "$rel" || /bin/rm -f "$f"
    done
  done
  if [ "$state" = "install" ]; then log "INSTALL: $dst"; COUNT_INSTALLED=$((COUNT_INSTALLED+1)); else log "UPDATE:  $dst"; COUNT_UPDATED=$((COUNT_UPDATED+1)); fi
}

while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  install_into "$repo"
done <<EOS
$REPOS
EOS

if [ -n "$ONLY" ] && [ "$MATCHED_ONLY" -eq 0 ]; then echo "ERROR: --only '$ONLY' matched no frontend repo" >&2; exit 1; fi
MODE="LIVE"; [ "$DRY_RUN" = "1" ] && MODE="DRY-RUN"
echo ""
echo "[$MODE] durance-design: installed $COUNT_INSTALLED | updated $COUNT_UPDATED | noop $COUNT_NOOP | skipped $COUNT_SKIP | warnings $COUNT_WARN | errors $ERRORS"
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
