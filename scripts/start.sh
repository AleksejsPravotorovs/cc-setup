#!/usr/bin/env bash
set -euo pipefail

# SCRIPT_DIR = where start.sh lives (cc-setup repo) — used to find tmux config
# WORK_DIR   = where the user wants to work — defaults to $PWD (e.g. folder open in VS Code)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${1:-$(pwd)}"
SESSION="$(basename "$WORK_DIR" | tr '[:upper:].' '[:lower:]-')"
TMUX_CONF="$SCRIPT_DIR/.tmux.agent.conf"

# The native Claude install lives in ~/.local/bin, which a freshly opened or
# non-login shell may not have on PATH. Look there before declaring claude
# missing — otherwise pp dead-ends and sends the user back to setup.sh, which
# correctly finds Claude already installed and changes nothing.
if [ -x "$HOME/.local/bin/claude" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi

command -v tmux  >/dev/null 2>&1 || { echo "tmux not found — run ./scripts/setup.sh to install"; exit 1; }
if ! command -v claude >/dev/null 2>&1; then
  echo "claude not found on PATH."
  echo "  Install it:  curl -fsSL https://claude.ai/install.sh | bash"
  echo "  Then open a new terminal (or run: exec \$SHELL -l) and try pp again."
  echo "  Diagnose:    bash \"$SCRIPT_DIR/scripts/doctor.sh\""
  exit 1
fi

# Kill previous session if exists
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Build tmux flags — use agent config if present
TMUX_FLAGS=()
if [ -f "$TMUX_CONF" ]; then
  TMUX_FLAGS+=(-f "$TMUX_CONF")
fi

# Prevent VS Code shell integration from conflicting with tmux panes
# (fixes the "extensions want to relaunch the terminal" warning in VS Code)
unset VSCODE_SHELL_INTEGRATION VSCODE_INJECTION 2>/dev/null || true

# Create session in project dir
tmux "${TMUX_FLAGS[@]}" new-session -d -s "$SESSION" -c "$WORK_DIR"

# Agent teams stay OFF - a named subagent would otherwise launch as a teammate
# and never self-terminate. Settings files override this anyway; keep them agreed.
tmux set-environment -t "$SESSION" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 0

# Pass the PATH we just verified into the session, so panes find the same
# claude binary this script found — even if their shell rc does not add it
tmux set-environment -t "$SESSION" PATH "$PATH"

# Clean VS Code env vars from session so new panes don't inherit them
tmux set-environment -t "$SESSION" -u VSCODE_SHELL_INTEGRATION 2>/dev/null || true
tmux set-environment -t "$SESSION" -u VSCODE_INJECTION 2>/dev/null || true

# Single full-width Claude pane
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #{pane_title} "
tmux select-pane -t "$SESSION:0.0" -T "CLAUDE"

# Left pane: launch Claude. Agent teams are off by default (see above); subagents
# run in-process, return their result to the caller and exit on their own.
tmux send-keys -t "$SESSION:0.0" "claude --dangerously-skip-permissions" C-m

# Focus Claude pane
tmux select-pane -t "$SESSION:0.0"
exec tmux attach -t "$SESSION"
