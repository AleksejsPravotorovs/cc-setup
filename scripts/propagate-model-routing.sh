#!/usr/bin/env bash
# DEPRECATED 2026-08-17 - DO NOT RUN. Superseded by model policy v3.
#
# This script rolls out "Model Routing v2": fable for code, opus for template text.
# That policy is retired - the owner retired Fable 5 outright ("No more Fable 5").
# Current policy: Opus 5 default, Sonnet 5 for trivial text with no design decision,
# Haiku 4.5 for high-volume mechanical passes, fable never spawned.
#
# Running this would overwrite every tracked project's AGENTS.md and roster with the
# old fable-first policy. Its own preflight now fails anyway (it requires
# "model: fable" frontmatter, which no agent carries any more). Kept only as history.
if [ "${ALLOW_DEPRECATED_MODEL_ROUTING:-0}" != "1" ]; then
  echo "propagate-model-routing.sh is DEPRECATED (model routing v2 / fable-first)." >&2
  echo "Model policy v3 retired fable. Refusing to run." >&2
  exit 1
fi
# propagate-model-routing.sh
# Fleet rollout of Model Routing v2 (2026-07-21):
#   Fable 5 (alias `fable`) = default for anything that ships as code;
#   Opus 4.8 (alias `opus`) = trivial templated text only.
# Plus the senior-expert agent roster (toolkit command routing embedded in the
# agent .md files) and the routing-aware copies of the three fleet commands.
#
# For every active project tracked in the Obsidian vault's Projects/<slug>.md:
#   1. Overwrite <local_path>/AGENTS.md with the canonical ~/AGENTS.md
#      (same overwrite semantics as pp-update; one-time .bak is kept).
#   2. Sync the 7 core roster agents from ~/.claude/agents/ into
#      <local_path>/.claude/agents/ (only the roster files - project-specific
#      extra agents are never touched).
#   3. If <local_path>/.claude/commands/ exists, sync build-with-agent-team.md,
#      deploy.md, prime.md from ~/.claude/commands/.
#   4. If the project is a git repo, stage exactly the synced paths and commit.
#      (Commit only - never pushes.)
#
# Usage:
#   ./scripts/propagate-model-routing.sh --dry-run --verbose
#   ./scripts/propagate-model-routing.sh --only nicokaz
#   ./scripts/propagate-model-routing.sh --no-commit
#   ./scripts/propagate-model-routing.sh                # writes + commits
#
# Skip rules (same contract as propagate-guardrails-kit.sh): Projects/_archived/,
# names starting with _, README, *-state, status: archived, missing/empty
# local_path, missing local dir. Symlinked targets are refused.
#
# Compatible with bash 3.2 (macOS system bash).

set -euo pipefail

VAULT="/Users/aleksejpravotorov/Desktop/My AI Knowledge Base"
PROJECTS_DIR="$VAULT/Projects"
CANON_AGENTS_MD="$HOME/AGENTS.md"
CANON_AGENT_DIR="$HOME/.claude/agents"
CANON_CMD_DIR="$HOME/.claude/commands"

ROSTER="lead frontend backend devops skeptic qa researcher"
COMMANDS="build-with-agent-team deploy prime"

COMMIT_MSG="chore(fleet): model routing v2 (fable=code, opus=template) + senior expert agent roster

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"

DRY_RUN=0
VERBOSE=0
NO_COMMIT=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --no-commit) NO_COMMIT=1 ;;
    --only)
      shift
      ONLY="${1:-}"
      if [ -z "$ONLY" ]; then
        echo "ERROR: --only requires a slug argument" >&2; exit 2
      fi
      ;;
    *) echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done

log() { [ "$VERBOSE" = "1" ] && echo "  $*" >&2 || true; }

get_frontmatter_value() {
  local file="$1" key="$2"
  /usr/bin/awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      if (match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/) { v = substr(v, 2, length(v) - 2) }
        else if (v ~ /^\x27.*\x27$/) { v = substr(v, 2, length(v) - 2) }
        print v
        exit
      }
    }
  ' "$file"
}

# ── preflight: canonical sources must already carry routing v2 ──────────────
preflight() {
  local ok=1 f name
  if ! /usr/bin/grep -q "balanced routing v2" "$CANON_AGENTS_MD"; then
    echo "PREFLIGHT FAIL: $CANON_AGENTS_MD lacks 'balanced routing v2' block" >&2; ok=0
  fi
  if /usr/bin/grep -q $'\xe2\x80\x94' "$CANON_AGENTS_MD"; then
    echo "PREFLIGHT FAIL: $CANON_AGENTS_MD contains em-dashes (U+2014)" >&2; ok=0
  fi
  for name in $ROSTER; do
    f="$CANON_AGENT_DIR/$name.md"
    if [ ! -f "$f" ]; then
      echo "PREFLIGHT FAIL: missing canonical agent $f" >&2; ok=0; continue
    fi
    if ! /usr/bin/grep -q "^model: fable" "$f"; then
      echo "PREFLIGHT FAIL: $f lacks 'model: fable' frontmatter" >&2; ok=0
    fi
    if ! /usr/bin/grep -q "^name: $name\$" "$f"; then
      echo "PREFLIGHT FAIL: $f lacks 'name: $name' (required for subagent registration)" >&2; ok=0
    fi
    if ! /usr/bin/grep -q "^tools:" "$f"; then
      echo "PREFLIGHT FAIL: $f lacks 'tools:' (subagent key; 'allowed-tools' is the slash-command key)" >&2; ok=0
    fi
  done
  for name in $COMMANDS; do
    f="$CANON_CMD_DIR/$name.md"
    if [ ! -f "$f" ]; then
      echo "PREFLIGHT FAIL: missing canonical command $f" >&2; ok=0; continue
    fi
    if ! /usr/bin/grep -qi "routing v2" "$f"; then
      echo "PREFLIGHT FAIL: $f lacks a 'routing v2' reference" >&2; ok=0
    fi
  done
  [ "$ok" = "1" ] || exit 2
}

COUNT_PROJECTS=0
COUNT_AGENTS_MD=0
COUNT_AGENT_FILES=0
COUNT_CMD_FILES=0
COUNT_COMMITS=0
COUNT_NOOP=0
COUNT_SKIP=0
ERRORS=0
MATCHED_ONLY=0

# copy src -> dst when missing or different.
# Echoes: 1 = write happened, 0 = noop, E = error (caller MUST count E -
# this runs in a $(...) subshell, so incrementing ERRORS here would be lost).
sync_file() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    echo "ERROR: refusing to overwrite symlink $dst" >&2
    echo E; return 0
  fi
  if [ -f "$dst" ] && /usr/bin/cmp -s "$src" "$dst"; then
    echo 0; return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY: would sync $dst"
    echo 1; return 0
  fi
  # cp failure must surface as E: set -e does not propagate into $(...) callers
  if ! /bin/cp "$src" "$dst"; then
    echo "ERROR: cp failed: $dst" >&2
    echo E; return 0
  fi
  log "SYNC: $dst"
  echo 1
}

process_project() {
  local note="$1"
  local base="${note##*/}"
  base="${base%.md}"

  case "$base" in
    _*|README|readme|Readme) log "skip: $base (system file)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0 ;;
    *-state) log "skip: $base (prime snapshot, not a project note)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0 ;;
  esac

  if [ -n "$ONLY" ] && [ "$base" != "$ONLY" ]; then
    return 0
  fi

  local status local_path
  status=$(get_frontmatter_value "$note" "status")
  local_path=$(get_frontmatter_value "$note" "local_path")

  if [ "$status" = "archived" ]; then
    log "skip: $base (status=archived)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi
  if [ -z "$local_path" ]; then
    log "skip: $base (no local_path in frontmatter)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi
  if [ ! -d "$local_path" ]; then
    log "skip: $base (local_path does not exist: $local_path)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi

  if [ -n "$ONLY" ]; then MATCHED_ONLY=1; fi
  COUNT_PROJECTS=$((COUNT_PROJECTS + 1))

  local changed=0 wrote name p

  # ── 1. AGENTS.md overwrite (canonical distribution semantics) ────────────
  local agents_target="$local_path/AGENTS.md"
  if [ -L "$agents_target" ]; then
    echo "ERROR: $agents_target is a symlink - refusing" >&2
    ERRORS=$((ERRORS + 1))
  else
    if [ -f "$agents_target" ] && ! /usr/bin/cmp -s "$CANON_AGENTS_MD" "$agents_target"; then
      if [ "$DRY_RUN" != "1" ] && [ ! -f "$agents_target.bak-model-routing-v2" ]; then
        /bin/cp "$agents_target" "$agents_target.bak-model-routing-v2"
      fi
    fi
    wrote=$(sync_file "$CANON_AGENTS_MD" "$agents_target")
    case "$wrote" in
      1) COUNT_AGENTS_MD=$((COUNT_AGENTS_MD + 1)); changed=1 ;;
      E) ERRORS=$((ERRORS + 1)) ;;
    esac
  fi

  # ── 2. roster agents ──────────────────────────────────────────────────────
  if [ "$DRY_RUN" != "1" ]; then
    /bin/mkdir -p "$local_path/.claude/agents"
  fi
  for name in $ROSTER; do
    if [ ! -d "$local_path/.claude/agents" ] && [ "$DRY_RUN" = "1" ]; then
      log "DRY: would create $local_path/.claude/agents and sync $name.md"
      COUNT_AGENT_FILES=$((COUNT_AGENT_FILES + 1)); changed=1
      continue
    fi
    wrote=$(sync_file "$CANON_AGENT_DIR/$name.md" "$local_path/.claude/agents/$name.md")
    case "$wrote" in
      1) COUNT_AGENT_FILES=$((COUNT_AGENT_FILES + 1)); changed=1 ;;
      E) ERRORS=$((ERRORS + 1)) ;;
    esac
  done

  # ── 3. fleet commands (only where the project already has a commands dir) ─
  if [ -d "$local_path/.claude/commands" ]; then
    for name in $COMMANDS; do
      wrote=$(sync_file "$CANON_CMD_DIR/$name.md" "$local_path/.claude/commands/$name.md")
      case "$wrote" in
        1) COUNT_CMD_FILES=$((COUNT_CMD_FILES + 1)); changed=1 ;;
        E) ERRORS=$((ERRORS + 1)) ;;
      esac
    done
  fi

  if [ "$changed" = "0" ]; then
    log "noop: $base (files already current)"
    COUNT_NOOP=$((COUNT_NOOP + 1))
    # NO return: still attempt the commit below - a prior run may have synced
    # files but failed to commit (self-healing rerun).
  fi

  # ── 4. commit (git projects only, live runs only) ─────────────────────────
  if [ "$DRY_RUN" = "1" ] || [ "$NO_COMMIT" = "1" ]; then
    log "commit: skipped for $base (dry-run/no-commit)"
    return 0
  fi
  if [ ! -d "$local_path/.git" ]; then
    log "commit: $base is not a git repo - files synced only"
    return 0
  fi

  # Pathspec-limited commit: never sweeps a user's pre-staged work into ours.
  # Candidates first; the final pathspec keeps only paths git actually TRACKS
  # after the adds - gitignored/never-tracked paths (e.g. repos ignoring
  # .claude/) would make `git commit -- pathspec` hard-error otherwise.
  local candidates=("AGENTS.md")
  for name in $ROSTER; do
    candidates[${#candidates[@]}]=".claude/agents/$name.md"
  done
  for name in $COMMANDS; do
    [ -f "$local_path/.claude/commands/$name.md" ] && \
      candidates[${#candidates[@]}]=".claude/commands/$name.md"
  done

  local pathspec=()
  for p in "${candidates[@]}"; do
    /usr/bin/git -C "$local_path" add -- "$p" 2>/dev/null || true
    if /usr/bin/git -C "$local_path" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      pathspec[${#pathspec[@]}]="$p"
    fi
  done

  if [ "${#pathspec[@]}" -eq 0 ]; then
    log "commit: $base (no synced path is tracked - .claude/AGENTS.md gitignored here)"
    return 0
  fi
  if [ -z "$(/usr/bin/git -C "$local_path" status --porcelain -- "${pathspec[@]}" 2>/dev/null)" ]; then
    log "commit: $base (synced paths already committed/clean)"
    return 0
  fi
  if /usr/bin/git -C "$local_path" commit -m "$COMMIT_MSG" -- "${pathspec[@]}" >/dev/null 2>&1; then
    COUNT_COMMITS=$((COUNT_COMMITS + 1))
    log "COMMIT: $base"
  else
    echo "ERROR: git commit failed in $local_path (pre-commit hook, merge state?) - synced files left staged" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

preflight

if [ ! -d "$PROJECTS_DIR" ]; then
  echo "ERROR: Projects dir not found: $PROJECTS_DIR" >&2
  exit 2
fi

shopt -s nullglob
for note in "$PROJECTS_DIR"/*.md; do
  [ -f "$note" ] || continue
  process_project "$note"
done
shopt -u nullglob

if [ -n "$ONLY" ] && [ "$MATCHED_ONLY" -eq 0 ]; then
  echo "ERROR: --only slug '$ONLY' matched a note but the project was filtered out" >&2
  exit 1
fi

MODE="LIVE"
[ "$DRY_RUN" = "1" ] && MODE="DRY-RUN"
echo ""
echo "[$MODE] projects touched: $COUNT_PROJECTS | AGENTS.md synced: $COUNT_AGENTS_MD | agent files: $COUNT_AGENT_FILES | command files: $COUNT_CMD_FILES | commits: $COUNT_COMMITS | noop: $COUNT_NOOP | skipped: $COUNT_SKIP | errors: $ERRORS"

if [ "$ERRORS" -gt 0 ]; then exit 1; fi
exit 0
