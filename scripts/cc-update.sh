#!/usr/bin/env bash
# cc-update.sh - fast, non-interactive freshness gate + refresh for the Claude Code fleet config.
#
# Two modes:
#   --check   Is the cc-setup clone behind origin/main? Prints ONE line, exits:
#               0 = up to date (or throttled - checked recently)
#               3 = BEHIND origin/main -> caller should run --apply
#               4 = cannot tell (not a clone / offline / no remote)
#             Network-throttled by a stamp file so /prime stays inside its 30s budget.
#   --apply   git pull --ff-only, then sync user scope (~/.claude/agents, ~/.claude/commands,
#             ~/AGENTS.md) from the clone. Every overwritten file is backed up
#             first to ~/.claude/.cc-update-backup/<timestamp>/. Default when no mode is given.
#
# Flags: --force (ignore the throttle stamp)  --quiet  --dir <path to cc-setup clone>
#
# Direction of truth: origin/main -> clone -> this machine. On the AUTHORING machine push
# cc-setup first; otherwise --apply will pull older canonical files over newer local ones
# (recoverable from the backup dir, but avoidable).
#
# Compatible with bash 3.2 (macOS system bash).

set -uo pipefail

MODE=""
FORCE=0
QUIET=0
CC_DIR="${CC_SETUP_DIR:-$HOME/Downloads/cc-setup}"
THROTTLE_SECONDS="${CC_UPDATE_THROTTLE:-21600}"   # 6h
STAMP="$HOME/.claude/.cc-update-check"
FETCH_TIMEOUT=8

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --apply) MODE="apply" ;;
    --force) FORCE=1 ;;
    --quiet|-q) QUIET=1 ;;
    --dir) shift; CC_DIR="${1:-}"; [ -n "$CC_DIR" ] || { echo "ERROR: --dir needs a path" >&2; exit 2; } ;;
    -h|--help) /usr/bin/sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$MODE" ] || MODE="apply"

say() { [ "$QUIET" = "1" ] || echo "$@"; }

ROSTER="lead frontend backend devops skeptic qa researcher"
COMMANDS="build-with-agent-team deploy prime research think-first"

# ── preflight ────────────────────────────────────────────────────────────────
if [ ! -d "$CC_DIR/.git" ]; then
  say "cc-setup: not a git clone at $CC_DIR - cannot check (set CC_SETUP_DIR or run pp-update)"
  exit 4
fi
if ! /usr/bin/git -C "$CC_DIR" remote get-url origin >/dev/null 2>&1; then
  say "cc-setup: no origin remote - cannot check"
  exit 4
fi

# git fetch with a hard timeout, non-interactive (no SSH/HTTP password prompts ever).
fetch_with_timeout() {
  GIT_TERMINAL_PROMPT=0 \
  GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new" \
  /usr/bin/git -C "$CC_DIR" fetch --quiet origin >/dev/null 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    [ "$waited" -ge "$FETCH_TIMEOUT" ] && { kill -TERM "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return 1; }
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null
}

default_branch() {
  local b
  b=$(/usr/bin/git -C "$CC_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$b" ] && { echo "${b#origin/}"; return 0; }
  /usr/bin/git -C "$CC_DIR" show-ref --verify --quiet refs/remotes/origin/main && { echo main; return 0; }
  /usr/bin/git -C "$CC_DIR" show-ref --verify --quiet refs/remotes/origin/master && { echo master; return 0; }
  echo main
}

# ── check mode ───────────────────────────────────────────────────────────────
if [ "$MODE" = "check" ]; then
  if [ "$FORCE" != "1" ] && [ -f "$STAMP" ]; then
    now=$(date +%s)
    then_=$(cat "$STAMP" 2>/dev/null || echo 0)
    case "$then_" in ''|*[!0-9]*) then_=0 ;; esac
    if [ $((now - then_)) -lt "$THROTTLE_SECONDS" ]; then
      say "cc-setup: check skipped (last checked $(( (now - then_) / 60 ))m ago)"
      exit 0
    fi
  fi

  if ! fetch_with_timeout; then
    say "cc-setup: offline or fetch timed out (${FETCH_TIMEOUT}s) - skipping"
    exit 4
  fi
  /bin/mkdir -p "$(dirname "$STAMP")" 2>/dev/null || true
  date +%s > "$STAMP" 2>/dev/null || true

  BR=$(default_branch)
  BEHIND=$(/usr/bin/git -C "$CC_DIR" rev-list --count "HEAD..origin/$BR" 2>/dev/null || echo "")
  AHEAD=$(/usr/bin/git -C "$CC_DIR" rev-list --count "origin/$BR..HEAD" 2>/dev/null || echo "")
  if [ -z "$BEHIND" ]; then
    say "cc-setup: cannot compare against origin/$BR"
    exit 4
  fi
  if [ "$BEHIND" -gt 0 ]; then
    say "cc-setup: STALE - $BEHIND commit(s) behind origin/$BR (auto-updating)"
    exit 3
  fi
  if [ "${AHEAD:-0}" -gt 0 ]; then
    say "cc-setup: up to date ($AHEAD local commit(s) unpushed)"
  else
    say "cc-setup: up to date"
  fi
  exit 0
fi

# ── apply mode ───────────────────────────────────────────────────────────────
BR=$(default_branch)
say "cc-setup: pulling origin/$BR ..."
if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
     /usr/bin/git -C "$CC_DIR" pull --ff-only --quiet origin "$BR" >/dev/null 2>&1; then
  say "cc-setup: pull failed (local commits, dirty tree, or offline) - syncing from current checkout"
fi
date +%s > "$STAMP" 2>/dev/null || true

TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/.claude/.cc-update-backup/$TS"
SYNCED=0
BACKED=0
SKIPPED=0

sync_one() {
  src="$1"; dst="$2"
  [ -f "$src" ] || return 0
  if [ -L "$dst" ]; then
    echo "cc-update: refusing to overwrite symlink $dst" >&2
    return 0
  fi
  if [ -f "$dst" ] && /usr/bin/cmp -s "$src" "$dst"; then
    return 0
  fi
  # Authoring-machine guard: never revert a user-scope file that was edited AFTER the
  # clone's copy was last written. A real update arrives via `git pull`, which stamps the
  # clone file with checkout time - so genuine updates are always newer and still apply.
  if [ -f "$dst" ] && [ "$dst" -nt "$src" ] && [ "$FORCE" != "1" ]; then
    say "  skip ${dst#$HOME/} (local copy is newer than the clone - use --force to overwrite)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  if [ -f "$dst" ]; then
    /bin/mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")" 2>/dev/null || true
    /bin/cp "$dst" "$BACKUP/${dst#$HOME/}" 2>/dev/null && BACKED=$((BACKED + 1))
  fi
  /bin/mkdir -p "$(dirname "$dst")" 2>/dev/null || true
  if /bin/cp "$src" "$dst"; then
    SYNCED=$((SYNCED + 1))
    say "  sync ${dst#$HOME/}"
  else
    echo "cc-update: cp failed for $dst" >&2
  fi
}

/bin/mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" 2>/dev/null || true
for n in $ROSTER;   do sync_one "$CC_DIR/.claude/agents/$n.md"   "$HOME/.claude/agents/$n.md";   done
for n in $COMMANDS; do sync_one "$CC_DIR/.claude/commands/$n.md" "$HOME/.claude/commands/$n.md"; done
sync_one "$CC_DIR/AGENTS.md" "$HOME/AGENTS.md"
# NOT CLAUDE.md: cc-setup/CLAUDE.md is a PROJECT file (it carries a FLEET:GROUNDTRUTH
# stack block). The user-scope ~/CLAUDE.md is only the loader line, so seed it if it is
# missing and never overwrite it.
if [ ! -e "$HOME/CLAUDE.md" ]; then
  echo "@AGENTS.md" > "$HOME/CLAUDE.md" && say "  seed CLAUDE.md (@AGENTS.md loader)"
fi

SKIPNOTE=""
[ "$SKIPPED" -gt 0 ] && SKIPNOTE=", $SKIPPED skipped as locally newer"
if [ "$SYNCED" -eq 0 ]; then
  say "cc-update: already current (nothing synced$SKIPNOTE)"
else
  say "cc-update: $SYNCED synced, $BACKED backed up to ${BACKUP#$HOME/}$SKIPNOTE"
fi
exit 0
