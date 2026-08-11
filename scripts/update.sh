#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  pp-update - refresh Claude Code setup from GitHub              ║
# ║                                                                  ║
# ║  Two modes (auto-detected):                                     ║
# ║    • cc-setup clone  → git pull + refresh ~/.claude user scope  ║
# ║    • bootstrapped    → re-download project .claude/ files       ║
# ╚══════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_URL="https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

# tty detection for curl|bash prompts
if [ -t 0 ]; then INPUT_FD=0
elif [ -e /dev/tty ]; then INPUT_FD=3; exec 3</dev/tty
else INPUT_FD=""
fi

ask() {
  local var="$1" prompt="$2" default="${3:-}"
  if [ -n "$INPUT_FD" ]; then
    read -rp "$prompt" "$var" <&"$INPUT_FD"
  else
    echo "${prompt}${default} (auto)"
    eval "$var='$default'"
  fi
}

# Detect mode
if [ -d "$PROJECT_DIR/claude-user-config" ] && [ -f "$PROJECT_DIR/scripts/install-plugins.sh" ]; then
  MODE="cc-setup"
else
  MODE="project"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Claude Code - pp-update                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
info "Mode: $MODE"
info "Dir : $PROJECT_DIR"
echo ""

# ─── cc-setup clone mode ────────────────────────────────────────────

if [ "$MODE" = "cc-setup" ]; then
  if [ -d "$PROJECT_DIR/.git" ]; then
    info "Pulling latest cc-setup..."
    if git -C "$PROJECT_DIR" pull --ff-only; then
      ok "cc-setup up to date"
    else
      warn "git pull failed (local changes? non-fast-forward?) - continuing with current checkout"
    fi
  else
    warn "Not a git clone - skipping pull (consider cloning via git instead of downloading zip)"
  fi

  echo ""
  info "Refreshing user-scope config (~/.claude)..."
  bash "$PROJECT_DIR/scripts/install-plugins.sh"

  echo ""
  if [ -x "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" ]; then
    info "Applying self-edit-safeguard protocol to cc-setup itself..."
    bash "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" "$PROJECT_DIR" || warn "safeguard apply returned non-zero - review output above"
  fi

  echo ""
  ok "pp-update complete."
  echo ""
  info "To refresh a bootstrapped project's .claude/ files, cd into it and run pp-update there."
  exit 0
fi

# ─── Bootstrapped-project mode ──────────────────────────────────────

info "Refreshing project files from GitHub..."
echo ""

mkdir -p scripts .claude/agents .claude/commands .claude/snapshots .vscode

# Scripts (includes apply-self-edit-safeguard-fix.sh - protocol patcher)
for file in setup.sh start.sh stop.sh update.sh cc-update.sh install-plugins.sh doctor.sh reap-teammates.sh apply-self-edit-safeguard-fix.sh; do
  echo "  scripts/$file"
  curl -fsSL "$REPO_URL/scripts/$file" -o "$PROJECT_DIR/scripts/$file"
done
chmod +x "$PROJECT_DIR"/scripts/setup.sh "$PROJECT_DIR"/scripts/start.sh "$PROJECT_DIR"/scripts/update.sh "$PROJECT_DIR"/scripts/cc-update.sh "$PROJECT_DIR"/scripts/install-plugins.sh "$PROJECT_DIR"/scripts/doctor.sh "$PROJECT_DIR"/scripts/reap-teammates.sh "$PROJECT_DIR"/scripts/apply-self-edit-safeguard-fix.sh

# Agents
for agent in lead frontend backend devops skeptic qa researcher; do
  echo "  .claude/agents/$agent.md"
  curl -fsSL "$REPO_URL/.claude/agents/$agent.md" -o "$PROJECT_DIR/.claude/agents/$agent.md"
done

# Commands
for cmd in prime build-with-agent-team deploy research think-first; do
  echo "  .claude/commands/$cmd.md"
  curl -fsSL "$REPO_URL/.claude/commands/$cmd.md" -o "$PROJECT_DIR/.claude/commands/$cmd.md"
done

# Root-level canonical docs (AGENTS.md = PROMPT_FREE_PROTOCOL canonical; CLAUDE.md loads it)
for root_doc in AGENTS.md CLAUDE.md; do
  echo "  $root_doc"
  curl -fsSL "$REPO_URL/$root_doc" -o "$PROJECT_DIR/$root_doc" 2>/dev/null || warn "    (missing remotely - skipped)"
done

# Guardrails Kit playbooks (docs/guardrails/) - on-demand docs the CLAUDE.md
# GUARDRAILS_KIT block routes to. The always-loaded core rides in CLAUDE.md above.
mkdir -p "$PROJECT_DIR/docs/guardrails"
for gd in PLAN CODE TRAPS DEBUG VERIFY EFFICIENCY SESSION _FORMAT; do
  echo "  docs/guardrails/$gd.md"
  curl -fsSL "$REPO_URL/docs/guardrails/$gd.md" -o "$PROJECT_DIR/docs/guardrails/$gd.md" 2>/dev/null || warn "    (missing remotely - skipped)"
done

# Protocol mirror inside .claude/ (agent-facing)
echo "  .claude/PROMPT_FREE_PROTOCOL.md"
curl -fsSL "$REPO_URL/.claude/PROMPT_FREE_PROTOCOL.md" -o "$PROJECT_DIR/.claude/PROMPT_FREE_PROTOCOL.md" 2>/dev/null || warn "    (missing remotely - skipped)"

# VS Code workspace auto-approve
echo "  .vscode/settings.json"
curl -fsSL "$REPO_URL/.vscode/settings.json" -o "$PROJECT_DIR/.vscode/settings.json" 2>/dev/null || warn "    (missing remotely - skipped)"

# Frontend set - refresh only if already installed
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  info "Frontend skills detected - refreshing..."
  for skill in premium-design scroll-animations section-transitions design-system-extraction; do
    echo "  .claude/skills/$skill.md"
    curl -fsSL "$REPO_URL/.claude/skills/$skill.md" -o "$PROJECT_DIR/.claude/skills/$skill.md" 2>/dev/null || warn "    (missing remotely - skipped)"
  done
fi

# Design research docs live at research/design/ (outside .claude/ - protected-path safeguard avoidance)
if [ -d "$PROJECT_DIR/research/design" ] || [ -d "$PROJECT_DIR/.claude/research" ]; then
  mkdir -p "$PROJECT_DIR/research/design"
  for doc in bold-design-principles premium-design-system-template scroll-driven-ui-roadmap-template scroll-scrubbed-video section-transitions-spec video-smoothing; do
    echo "  research/design/$doc.md"
    curl -fsSL "$REPO_URL/research/design/$doc.md" -o "$PROJECT_DIR/research/design/$doc.md" 2>/dev/null || warn "    (missing remotely - skipped)"
  done
fi

if [ -d "$PROJECT_DIR/libraries/scroll-animations" ]; then
  for lib in README.md animations.ts easings.ts scroll-animations.ts tailwind-theme-reference.js; do
    echo "  libraries/scroll-animations/$lib"
    curl -fsSL "$REPO_URL/libraries/scroll-animations/$lib" -o "$PROJECT_DIR/libraries/scroll-animations/$lib" 2>/dev/null || warn "    (missing remotely - skipped)"
  done
fi

echo ""
ok "Project files refreshed."
echo ""

# Auto-apply the self-edit-safeguard protocol so the refreshed project is safe to run immediately.
# Idempotent - no-op when already patched.
if [ -x "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" ]; then
  info "Applying self-edit-safeguard protocol (idempotent)..."
  if bash "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" "$PROJECT_DIR"; then
    ok "Protocol applied / verified"
  else
    warn "Safeguard apply returned non-zero - review output above"
  fi
  echo ""
fi

info "To also refresh user-scope hooks/plugins (~/.claude), run: bash scripts/install-plugins.sh"
