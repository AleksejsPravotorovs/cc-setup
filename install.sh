#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  Claude Code — One-liner bootstrap (macOS / Linux)              ║
# ║  curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
# ╚══════════════════════════════════════════════════════════════════╝

REPO="https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main"

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

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Claude Code — Downloading files     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Create directory structure
mkdir -p scripts .claude/agents .claude/commands .claude/snapshots

# --- Scripts ---
for file in setup.sh start.sh stop.sh update.sh install-plugins.sh doctor.sh; do
  echo "  Downloading scripts/$file..."
  curl -fsSL "$REPO/scripts/$file" -o "scripts/$file"
done
chmod +x scripts/setup.sh scripts/start.sh scripts/stop.sh scripts/update.sh scripts/install-plugins.sh scripts/doctor.sh

# --- Agents ---
for agent in lead frontend backend devops skeptic qa researcher; do
  echo "  Downloading .claude/agents/$agent.md..."
  curl -fsSL "$REPO/.claude/agents/$agent.md" -o ".claude/agents/$agent.md"
done

# --- Commands ---
for cmd in prime build-with-agent-team deploy research; do
  echo "  Downloading .claude/commands/$cmd.md..."
  curl -fsSL "$REPO/.claude/commands/$cmd.md" -o ".claude/commands/$cmd.md"
done

# --- Config files (only if not already present) ---
for file in .claude/settings.json .tmux.agent.conf CLAUDE.md AGENTS.md; do
  if [ ! -f "$file" ]; then
    echo "  Downloading $file..."
    curl -fsSL "$REPO/$file" -o "$file"
  else
    echo "  Skipping $file (already exists)"
  fi
done

# --- Frontend design add-on (opt-in) ---
echo ""
echo "Optional: frontend design add-on"
echo "  • 4 skills        premium-design, scroll-animations, section-transitions, design-system-extraction"
echo "  • 6 research docs bold-design, scroll-driven UI, video smoothing, section transitions, ..."
echo "  • scroll-animations TS library (animations.ts, easings.ts, ...)"
echo ""
ask INSTALL_FRONTEND "Install frontend design set? (y/n) " "n"
echo ""

if [[ "$INSTALL_FRONTEND" == "y" ]]; then
  mkdir -p .claude/skills research/design libraries/scroll-animations

  for skill in premium-design scroll-animations section-transitions design-system-extraction; do
    echo "  Downloading .claude/skills/$skill.md..."
    curl -fsSL "$REPO/.claude/skills/$skill.md" -o ".claude/skills/$skill.md"
  done

  for doc in bold-design-principles premium-design-system-template scroll-driven-ui-roadmap-template scroll-scrubbed-video section-transitions-spec video-smoothing; do
    echo "  Downloading research/design/$doc.md..."
    curl -fsSL "$REPO/research/design/$doc.md" -o "research/design/$doc.md"
  done

  for lib in README.md animations.ts easings.ts scroll-animations.ts tailwind-theme-reference.js; do
    echo "  Downloading libraries/scroll-animations/$lib..."
    curl -fsSL "$REPO/libraries/scroll-animations/$lib" -o "libraries/scroll-animations/$lib"
  done
fi

echo ""
echo "  Files downloaded."
echo "  Running setup..."
echo ""

bash scripts/setup.sh
