#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  Claude Code + Agent Teams Setup                                ║
# ║  Installs tools, configures environment, verifies config files. ║
# ║  Config files (agents, commands, etc.) are downloaded by         ║
# ║  install.sh — this script only handles tool installation.        ║
# ╚══════════════════════════════════════════════════════════════════╝

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# ─── Detect piped execution (curl ... | bash) ────────────────────
# When piped, stdin is not a terminal. Redirect reads from /dev/tty.
PIPED=false
if [ -t 0 ]; then
  INPUT_FD=0
elif [ -e /dev/tty ]; then
  INPUT_FD=3
  exec 3</dev/tty
  PIPED=true
else
  INPUT_FD=""
  PIPED=true
fi

# Wrapper for interactive prompts that works when piped from curl
# Usage: ask VARNAME "prompt text" [default]
ask() {
  local VARNAME="$1" PROMPT="$2" DEFAULT="${3:-}"
  if [ -n "$INPUT_FD" ]; then
    read -rp "$PROMPT" "$VARNAME" <&"$INPUT_FD"
  else
    echo "${PROMPT}${DEFAULT} (auto)"
    eval "$VARNAME='$DEFAULT'"
  fi
}

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

EXPECTED_AGENTS=("lead" "frontend" "backend" "devops" "skeptic" "qa" "researcher")
EXPECTED_COMMANDS=("prime" "build-with-agent-team" "deploy" "research")
EXPECTED_SKILLS=("premium-design" "scroll-animations" "section-transitions" "design-system-extraction")
VSCODE_EXTENSIONS=("dbaeumer.vscode-eslint" "bradlc.vscode-tailwindcss" "esbenp.prettier-vscode")

# ═══════════════════════════════════════════════════════════════════
# XCODE COMMAND LINE TOOLS — required for git, compilers, headers
# ═══════════════════════════════════════════════════════════════════

ensure_xcode_clt() {
  [[ "$(uname -s)" != "Darwin" ]] && return 0

  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools found"
    return 0
  fi

  warn "Xcode Command Line Tools not installed (required for git and build tools)"
  echo ""
  ask INSTALL_CLT "  Install Xcode Command Line Tools now? (y/n) " "y"
  echo ""
  if [[ "$INSTALL_CLT" != "y" ]]; then
    fail "Xcode CLT is required. Install manually: xcode-select --install"
    return 1
  fi

  info "Installing Xcode Command Line Tools (a system dialog will appear)..."
  xcode-select --install 2>/dev/null || true

  info "Waiting for installation to complete (this may take a few minutes)..."
  echo "  Close the installer dialog when it finishes, then this script will continue."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done

  log "Xcode Command Line Tools installed"
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# HOMEBREW — macOS package manager
# ═══════════════════════════════════════════════════════════════════

ensure_homebrew() {
  [[ "$(uname -s)" != "Darwin" ]] && return 0

  if command -v brew >/dev/null 2>&1; then
    log "Homebrew found: $(brew --version | head -1)"
    return 0
  fi

  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log "Homebrew found (Apple Silicon): $(brew --version | head -1)"
    return 0
  fi

  warn "Homebrew is not installed (required for installing Node.js, tmux, etc.)"
  echo ""
  ask INSTALL_BREW "  Install Homebrew now? (y/n) " "y"
  echo ""
  if [[ "$INSTALL_BREW" != "y" ]]; then
    fail "Homebrew is required on macOS. Install manually:"
    echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    return 1
  fi

  info "Installing Homebrew (this may take a minute)..."
  # Redirect stdin from /dev/tty so Homebrew can prompt for sudo password
  # even when this script is piped (curl ... | bash)
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty

  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="/opt/homebrew/bin:$PATH"
  fi

  if command -v brew >/dev/null 2>&1; then
    log "Homebrew installed: $(brew --version | head -1)"

    local SHELL_RC="$HOME/.zshrc"
    [[ "$(basename "${SHELL:-}")" != "zsh" ]] && SHELL_RC="$HOME/.bashrc"
    if [[ -f /opt/homebrew/bin/brew ]] && ! grep -qF '/opt/homebrew/bin/brew' "$SHELL_RC" 2>/dev/null; then
      echo '' >> "$SHELL_RC"
      echo '# Homebrew (added by setup.sh)' >> "$SHELL_RC"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
      info "Added Homebrew to $SHELL_RC (Apple Silicon path)"
    fi
    return 0
  else
    fail "Homebrew installation failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# GIT — verify availability and configure identity
# ═══════════════════════════════════════════════════════════════════

ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
      warn "git not found — installing via Homebrew..."
      brew install git || { fail "git installation failed"; return 1; }
    else
      fail "git is not installed. Install it manually."
      return 1
    fi
  fi
  log "Git found: $(git --version)"

  # Only check — don't prompt. Name/email are needed for commits, not for setup.
  local GIT_NAME GIT_EMAIL
  GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
  GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

  if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    info "Git user.name/email not configured yet (only needed when you make commits)"
    echo "    git config --global user.name \"Your Name\""
    echo "    git config --global user.email \"your@email.com\""
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════
# VS CODE — CLI setup + recommended extensions
# ═══════════════════════════════════════════════════════════════════

setup_vscode() {
  if ! command -v code >/dev/null 2>&1; then
    local VSCODE_BIN=""
    for trypath in \
      "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
      "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
      if [[ -f "$trypath" ]]; then
        VSCODE_BIN="$trypath"
        break
      fi
    done

    if [[ -n "$VSCODE_BIN" ]]; then
      warn "VS Code found but 'code' command is not in PATH"
      echo ""
      ask ADD_CODE "  Add VS Code 'code' command to PATH? (y/n) " "y"
      if [[ "$ADD_CODE" == "y" ]]; then
        local TARGET="/usr/local/bin/code"
        sudo mkdir -p /usr/local/bin 2>/dev/null || true
        if sudo ln -sf "$VSCODE_BIN" "$TARGET" 2>/dev/null; then
          log "'code' command added to PATH"
        else
          warn "Could not add 'code' to PATH automatically"
          info "Open VS Code → Cmd+Shift+P → 'Shell Command: Install code command in PATH'"
          return 0
        fi
      else
        info "Skipping — add it later: VS Code → Cmd+Shift+P → 'Shell Command: Install code command in PATH'"
        return 0
      fi
    else
      info "VS Code not detected — skipping extension setup"
      return 0
    fi
  fi

  log "VS Code CLI found: $(code --version 2>/dev/null | head -1)"
  echo ""
  info "Recommended extensions for this project:"
  echo "    ESLint              (dbaeumer.vscode-eslint)"
  echo "    Tailwind CSS        (bradlc.vscode-tailwindcss)"
  echo "    Prettier            (esbenp.prettier-vscode)"
  echo ""
  ask INSTALL_EXT "  Install recommended VS Code extensions? (y/n) " "y"
  if [[ "$INSTALL_EXT" == "y" ]]; then
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
      if code --list-extensions 2>/dev/null | grep -qi "$ext"; then
        log "Already installed: $ext"
      else
        info "Installing: $ext"
        code --install-extension "$ext" --force 2>/dev/null || warn "Failed to install $ext"
      fi
    done
    log "VS Code extensions installed"
  else
    info "Skipping. Install later:"
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
      echo "    code --install-extension $ext"
    done
  fi
}

# ═══════════════════════════════════════════════════════════════════
# PROJECT DEPENDENCIES — npm install
# ═══════════════════════════════════════════════════════════════════

install_project_deps() {
  if [[ -d node_modules ]]; then
    log "Project dependencies already installed (node_modules exists)"
    return 0
  fi

  if [[ ! -f package.json ]]; then
    info "No package.json found — skipping npm install"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not available — cannot install project dependencies"
    return 1
  fi

  info "Installing project dependencies (npm install)..."
  npm install
  if [[ -d node_modules ]]; then
    log "Project dependencies installed"
    return 0
  else
    fail "npm install failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# TMUX — detect, install
# ═══════════════════════════════════════════════════════════════════

install_tmux() {
  local OS
  OS="$(uname -s)"

  case "$OS" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        info "Installing tmux via Homebrew..."
        brew install tmux
      elif command -v port >/dev/null 2>&1; then
        info "Installing tmux via MacPorts..."
        sudo port install tmux
      else
        fail "No package manager found. Install Homebrew first:"
        echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  Then re-run this script."
        return 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        info "Installing tmux via apt..."
        sudo apt-get update -qq && sudo apt-get install -y tmux
      elif command -v dnf >/dev/null 2>&1; then
        info "Installing tmux via dnf..."
        sudo dnf install -y tmux
      elif command -v yum >/dev/null 2>&1; then
        info "Installing tmux via yum..."
        sudo yum install -y tmux
      elif command -v pacman >/dev/null 2>&1; then
        info "Installing tmux via pacman..."
        sudo pacman -S --noconfirm tmux
      elif command -v apk >/dev/null 2>&1; then
        info "Installing tmux via apk..."
        sudo apk add tmux
      else
        fail "No supported package manager found."
        echo "  Install tmux manually: https://github.com/tmux/tmux/wiki/Installing"
        return 1
      fi
      ;;
    *)
      fail "Unsupported OS: $OS"
      echo "  Install tmux manually: https://github.com/tmux/tmux/wiki/Installing"
      return 1
      ;;
  esac

  if command -v tmux >/dev/null 2>&1; then
    log "tmux installed: $(tmux -V)"
    return 0
  else
    fail "tmux installation failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# NODE.JS — detect, install (Homebrew → nvm fallback)
# ═══════════════════════════════════════════════════════════════════

install_node_via_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm (Node Version Manager) — no admin rights required..."
    local NVM_SCRIPT
    NVM_SCRIPT=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o "$NVM_SCRIPT"
    bash "$NVM_SCRIPT"
    rm -f "$NVM_SCRIPT"
  fi

  # Load nvm into current shell
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  if ! command -v nvm >/dev/null 2>&1; then
    fail "nvm installation failed"
    return 1
  fi

  log "nvm installed"
  info "Installing latest LTS Node.js via nvm..."
  nvm install --lts

  if command -v node >/dev/null 2>&1; then
    log "Node.js installed via nvm: $(node --version)"
    return 0
  else
    fail "Node.js installation via nvm failed"
    return 1
  fi
}

install_node() {
  local OS
  OS="$(uname -s)"

  case "$OS" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        info "Installing Node.js via Homebrew..."
        brew install node
      else
        info "Homebrew not available — using nvm instead"
        install_node_via_nvm
        return $?
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        info "Installing Node.js via apt..."
        sudo apt-get update -qq && sudo apt-get install -y nodejs npm
      elif command -v dnf >/dev/null 2>&1; then
        info "Installing Node.js via dnf..."
        sudo dnf install -y nodejs npm
      elif command -v pacman >/dev/null 2>&1; then
        info "Installing Node.js via pacman..."
        sudo pacman -S --noconfirm nodejs npm
      else
        fail "No supported package manager found."
        echo "  Install Node.js manually: https://nodejs.org"
        return 1
      fi
      ;;
    *)
      fail "Unsupported OS: $OS"
      echo "  Install Node.js manually: https://nodejs.org"
      return 1
      ;;
  esac

  if command -v node >/dev/null 2>&1; then
    log "Node.js installed: $(node --version)"
    return 0
  else
    fail "Node.js installation failed"
    return 1
  fi
}

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    log "Node.js found: $(node --version)"
    return 0
  fi

  warn "Node.js is not installed (required for Claude CLI and npm packages)"
  echo ""
  ask INSTALL_NODE "  Install Node.js now? (y/n) " "y"
  echo ""
  if [[ "$INSTALL_NODE" == "y" ]]; then
    install_node
  else
    fail "Node.js is required. Install manually: https://nodejs.org"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# CLAUDE CLI — detect, install
#
# Install order — never sudo. Anthropic's docs warn explicitly against
# `sudo npm install -g` (permission + security problems):
#   1. official native installer → ~/.local/bin/claude, auto-updating
#   2. Homebrew cask             → when the installer could not be used
#   3. npm -g                    → only if the global prefix is writable
# npm alone used to be the only path, and it dead-ended every Mac whose
# npm prefix is root-owned (Node from the nodejs.org .pkg) with EACCES.
# ═══════════════════════════════════════════════════════════════════

LOCAL_BIN="$HOME/.local/bin"

# The native installer puts the launcher in ~/.local/bin, which a default
# macOS shell does not have on PATH. Add it for this run, and persist it
# once so a fresh terminal can find `claude` too.
ensure_local_bin_on_path() {
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) export PATH="$LOCAL_BIN:$PATH" ;;
  esac
  hash -r 2>/dev/null || true

  local RC=""
  case "$(basename "${SHELL:-/bin/zsh}")" in
    zsh)  RC="$HOME/.zshrc" ;;
    bash) if [ -f "$HOME/.bash_profile" ]; then RC="$HOME/.bash_profile"; else RC="$HOME/.bashrc"; fi ;;
    *)    return 0 ;;
  esac

  if [ -f "$RC" ] && grep -q '\.local/bin' "$RC" 2>/dev/null; then
    return 0
  fi

  {
    echo ''
    echo '# Added by cc-setup — Claude CLI (native install)'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$RC" && info "Added ~/.local/bin to PATH in $RC"
}

# True only when this user can write into npm's global prefix. A root-owned
# prefix (typically /usr/local from the nodejs.org .pkg) is what produces
# `EACCES: permission denied, mkdir '/usr/local/lib/node_modules/...'`.
npm_prefix_writable() {
  command -v npm >/dev/null 2>&1 || return 1
  local PREFIX
  PREFIX="$(npm config get prefix 2>/dev/null)" || return 1
  [ -n "$PREFIX" ] && [ "$PREFIX" != "undefined" ] || return 1
  if [ -d "$PREFIX/lib/node_modules" ]; then
    [ -w "$PREFIX/lib/node_modules" ]
  else
    [ -w "$PREFIX" ]
  fi
}

install_claude_native() {
  command -v curl >/dev/null 2>&1 || return 1
  info "Installing Claude CLI via the official installer (no npm, no sudo)..."
  # bash reads the script from the pipe — do not redirect its stdin here.
  curl -fsSL https://claude.ai/install.sh | bash || return 1
  ensure_local_bin_on_path
  command -v claude >/dev/null 2>&1
}

install_claude_brew() {
  command -v brew >/dev/null 2>&1 || return 1
  info "Installing Claude CLI via Homebrew cask..."
  brew install --cask claude-code || return 1
  hash -r 2>/dev/null || true
  command -v claude >/dev/null 2>&1
}

install_claude_npm() {
  command -v npm >/dev/null 2>&1 || return 1
  if ! npm_prefix_writable; then
    warn "Skipping npm — its global prefix ($(npm config get prefix 2>/dev/null || echo '?')) is not writable by $(whoami)"
    return 1
  fi
  info "Installing Claude CLI via npm..."
  npm install -g @anthropic-ai/claude-code || return 1
  hash -r 2>/dev/null || true
  command -v claude >/dev/null 2>&1
}

install_claude() {
  install_claude_native && { log "Claude CLI installed: $(claude --version 2>/dev/null | head -1)"; return 0; }
  warn "Official installer did not complete — trying Homebrew"

  install_claude_brew && { log "Claude CLI installed: $(claude --version 2>/dev/null | head -1)"; return 0; }
  warn "Homebrew cask unavailable — trying npm"

  install_claude_npm && { log "Claude CLI installed: $(claude --version 2>/dev/null | head -1)"; return 0; }

  fail "Claude CLI installation failed — all three methods were tried"
  echo ""
  echo "  Install it manually with ONE of these, then re-run this script:"
  echo "    curl -fsSL https://claude.ai/install.sh | bash   # recommended"
  echo "    brew install --cask claude-code"
  echo "    npm install -g @anthropic-ai/claude-code         # needs a writable npm prefix"
  echo ""
  echo "  Do NOT run 'sudo npm install -g' — it causes permission and security problems."
  echo "  Help: https://code.claude.com/docs/en/troubleshoot-install"
  return 1
}

ensure_claude() {
  # A previous native install may sit in ~/.local/bin without being on PATH.
  [ -x "$LOCAL_BIN/claude" ] && ensure_local_bin_on_path

  if command -v claude >/dev/null 2>&1; then
    local CLAUDE_VERSION
    CLAUDE_VERSION="$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")"
    log "Claude CLI found: $CLAUDE_VERSION"
    return 0
  fi

  warn "Claude CLI is not installed"
  echo ""
  ask INSTALL_CLAUDE "  Install Claude CLI now? (y/n) " "y"
  echo ""
  if [[ "$INSTALL_CLAUDE" == "y" ]]; then
    install_claude
  else
    fail "Claude CLI is required. Install: curl -fsSL https://claude.ai/install.sh | bash"
    return 1
  fi
}

ensure_tmux() {
  if command -v tmux >/dev/null 2>&1; then
    log "tmux found: $(tmux -V)"
    return 0
  fi

  warn "tmux is not installed (required for agent team orchestration)"
  echo ""
  ask INSTALL_TMUX "  Install tmux now? (y/n) " "y"
  echo ""
  if [[ "$INSTALL_TMUX" == "y" ]]; then
    install_tmux
  else
    fail "tmux is required for agent team orchestration. Install manually and re-run this script."
    echo ""
    case "$(uname -s)" in
      Darwin) echo "    brew install tmux" ;;
      Linux)  echo "    sudo apt install tmux  # or your distro's package manager" ;;
      *)      echo "    https://github.com/tmux/tmux/wiki/Installing" ;;
    esac
    echo ""
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# MAIN SETUP
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Claude Code + Agent Teams Setup     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ─── Install tools ────────────────────────────────────────────────

if [[ "$(uname -s)" == "Darwin" ]]; then
  ensure_xcode_clt || { fail "Xcode Command Line Tools are required. Cannot continue."; exit 1; }
  ensure_homebrew  || warn "Homebrew not available — will use alternatives where possible."
fi
ensure_git || { warn "Git configuration incomplete — some features may not work."; }

ensure_node || { warn "Continuing without Node.js — some features will not be available."; }
ensure_claude || { fail "Claude CLI is required. Cannot continue."; exit 1; }
ensure_tmux

log "Pre-flight passed"
echo ""

# ─── User-level settings (~/.claude/settings.json) ───────────────

USER_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [ -f "$USER_SETTINGS" ]; then
  NEEDS_UPDATE=false

  # Agent teams stay OFF: with the flag on, a *named* subagent launches as a
  # teammate, and teammates never self-terminate (idle rows pile up in the panel).
  grep -q '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"' "$USER_SETTINGS" 2>/dev/null || NEEDS_UPDATE=true

  if [ "$NEEDS_UPDATE" = true ]; then
    info "Updating user settings for agent teams..."
    python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
s.setdefault('env', {})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '0'
s.pop('teammateMode', None)   # harness default is "in-process"
with open(path, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$USER_SETTINGS" && log "Updated $USER_SETTINGS (agent teams off, default teammate mode)" \
                   || warn "Could not auto-update $USER_SETTINGS — add manually"
  else
    log "User settings: agent teams already off"
  fi
else
  cat > "$USER_SETTINGS" <<'JSON'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"
  }
}
JSON
  log "Created $USER_SETTINGS (agent teams off)"
fi

# ─── Verify config files ─────────────────────────────────────────
# These are downloaded by install.sh. If missing, warn the user.

MISSING=0

for agent in "${EXPECTED_AGENTS[@]}"; do
  [ -f ".claude/agents/${agent}.md" ] || { warn "Missing: .claude/agents/${agent}.md"; MISSING=$((MISSING+1)); }
done

for cmd in "${EXPECTED_COMMANDS[@]}"; do
  [ -f ".claude/commands/${cmd}.md" ] || { warn "Missing: .claude/commands/${cmd}.md"; MISSING=$((MISSING+1)); }
done

if [ -d ".claude/skills" ]; then
  for skill in "${EXPECTED_SKILLS[@]}"; do
    [ -f ".claude/skills/${skill}.md" ] || { warn "Missing: .claude/skills/${skill}.md"; MISSING=$((MISSING+1)); }
  done
else
  info "Frontend skills not installed (optional — re-run install.sh and answer 'y' to the frontend prompt)"
fi

[ -f .claude/settings.json ] || { warn "Missing: .claude/settings.json"; MISSING=$((MISSING+1)); }
[ -f .tmux.agent.conf ]      || { warn "Missing: .tmux.agent.conf"; MISSING=$((MISSING+1)); }
[ -f scripts/start.sh ]      || { warn "Missing: scripts/start.sh"; MISSING=$((MISSING+1)); }
[ -f CLAUDE.md ]              || { warn "Missing: CLAUDE.md"; MISSING=$((MISSING+1)); }
[ -f AGENTS.md ]              || { warn "Missing: AGENTS.md"; MISSING=$((MISSING+1)); }

if [ "$MISSING" -gt 0 ]; then
  echo ""
  warn "$MISSING config file(s) missing. Run install.sh to download them:"
  echo "    curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash"
  echo ""
else
  AGENT_COUNT=${#EXPECTED_AGENTS[@]}
  CMD_COUNT=${#EXPECTED_COMMANDS[@]}
  SKILL_COUNT=${#EXPECTED_SKILLS[@]}
  log "Config files verified: $AGENT_COUNT agents, $CMD_COUNT commands, $SKILL_COUNT skills, settings, tmux config"
fi

chmod +x scripts/start.sh 2>/dev/null || true
mkdir -p .claude/snapshots .claude/skills

# ─── .gitignore additions ────────────────────────────────────────

if [ -f .gitignore ]; then
  IGNORE_ENTRIES=(".env" ".env.*")
  for entry in "${IGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" .gitignore 2>/dev/null; then
      echo "$entry" >> .gitignore
    fi
  done
  log "Updated .gitignore (env files)"
else
  info "No .gitignore found — skipping"
fi

# ─── Project dependencies ──────────────────────────────────────

install_project_deps

# ─── VS Code setup ─────────────────────────────────────────────

setup_vscode

# ─── Quick commands (pp, pp-setup) ────────────────────────────
# pp       — launches Claude session (tmux + split pane git watch)
# pp-setup — re-runs setup in this project

register_quick_commands() {
  local SHELL_RC
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi

  local NEEDS_PP=false NEEDS_PP_SETUP=false NEEDS_PP_UPDATE=false NEEDS_CLEANUP=false

  # Check for correct pp alias (must call this project's start.sh)
  if grep -qF "alias pp=" "$SHELL_RC" 2>/dev/null; then
    if ! grep -qF "alias pp='\"${PROJECT_DIR}/scripts/start.sh\"'" "$SHELL_RC" 2>/dev/null; then
      NEEDS_PP=true
      NEEDS_CLEANUP=true
    fi
  else
    NEEDS_PP=true
  fi

  if ! grep -qF "alias pp-setup=" "$SHELL_RC" 2>/dev/null; then
    NEEDS_PP_SETUP=true
  fi

  # Check for pp-update alias (new)
  if grep -qF "alias pp-update=" "$SHELL_RC" 2>/dev/null; then
    if ! grep -qF "alias pp-update='bash \"${PROJECT_DIR}/scripts/update.sh\"'" "$SHELL_RC" 2>/dev/null; then
      NEEDS_PP_UPDATE=true
      NEEDS_CLEANUP=true
    fi
  else
    NEEDS_PP_UPDATE=true
  fi

  if [ "$NEEDS_PP" = false ] && [ "$NEEDS_PP_SETUP" = false ] && [ "$NEEDS_PP_UPDATE" = false ]; then
    log "Quick commands already registered (pp, pp-setup, pp-update)"
    return 0
  fi

  echo ""
  info "Quick commands:"
  echo "    pp         — launch Claude session (tmux + git watch split pane)"
  echo "    pp-setup   — re-run setup for this project"
  echo "    pp-update  — pull latest cc-setup + refresh hooks/plugins"
  echo ""
  ask ADD_PP "  Add 'pp', 'pp-setup', 'pp-update' to $SHELL_RC? (y/n) " "y"
  if [[ "$ADD_PP" != "y" ]]; then
    info "Skipping quick commands. Add manually later."
    return 0
  fi

  if [ "$NEEDS_CLEANUP" = true ]; then
    sed -i.bak '/# PayPong.*Claude session/d;/# Claude Code.*quick commands/d;/alias pp=/d;/alias pp-update=/d' "$SHELL_RC"
    rm -f "${SHELL_RC}.bak"
    info "Cleaned up old pp aliases"
  fi

  cat >> "$SHELL_RC" <<CMDS

# Claude Code — quick commands (added by setup.sh)
alias pp='"${PROJECT_DIR}/scripts/start.sh"'
alias pp-setup='cd "${PROJECT_DIR}" && bash scripts/setup.sh'
alias pp-update='bash "${PROJECT_DIR}/scripts/update.sh"'
CMDS

  log "Added 'pp', 'pp-setup', 'pp-update' to $SHELL_RC"
  info "Run 'source $SHELL_RC' or open a new terminal to use them"
}

register_quick_commands

# ─── Self-edit safeguard protection (prevents teammate-pane crashes) ─────────
# Auto-applies the PROMPT_FREE_PROTOCOL + canonical AGENTS.md + .vscode settings.
# Idempotent — safe to re-run. Background: Claude Code v2.1.78+ has a hardcoded
# safeguard on .claude/** that crashes narrow tmux teammate panes with a raw
# JSX dump. Keeping this in setup.sh means every new project born from cc-setup
# is protected by default.
if [[ -x "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" ]]; then
  info "Applying self-edit-safeguard protection..."
  if bash "$PROJECT_DIR/scripts/apply-self-edit-safeguard-fix.sh" "$PROJECT_DIR" > /tmp/cc-setup-safeguard.log 2>&1; then
    log "Self-edit safeguard protection applied (see /tmp/cc-setup-safeguard.log for details)"
  else
    warn "Safeguard patch script returned non-zero — review /tmp/cc-setup-safeguard.log"
  fi
else
  warn "scripts/apply-self-edit-safeguard-fix.sh not found — teammate panes may crash on .claude/ writes"
  warn "Re-pull cc-setup to get the fix: pp-update"
fi

# ─── Clean up leftover files ─────────────────────────────────────


# ─── Summary ────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Setup Complete                      ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Tmux:"
echo "    .tmux.agent.conf             Agent-optimized config (mouse, pane labels, nav)"
echo "    scripts/start.sh             Launcher (sources .tmux.agent.conf)"
echo ""
echo "  Agent Teams (Official Mechanism):"
echo "    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0  Agent teams OFF (harness default)"
echo "    teammateMode unset                      Default \"in-process\"; no orphan panes"
echo "    .claude/settings.json                   Project-level settings"
echo "    ~/.claude/settings.json                 User-level settings"
echo "    .claude/agents/              ${#EXPECTED_AGENTS[@]} agents: ${EXPECTED_AGENTS[*]}"
echo ""
echo "  Commands:"
echo "    .claude/commands/            ${#EXPECTED_COMMANDS[@]} commands: ${EXPECTED_COMMANDS[*]}"
echo "    .claude/snapshots/           Deploy snapshot dir"
echo ""
echo "  Skills (auto-inject during frontend work):"
echo "    .claude/skills/              ${#EXPECTED_SKILLS[@]} skills: ${EXPECTED_SKILLS[*]}"
echo ""
echo "  Quick commands (added to shell profile):"
echo "    pp                           Launch Claude session in current folder (tmux + git watch)"
echo "    pp-setup                     Re-run setup for this project"
echo "    pp-update                    Pull latest cc-setup + refresh hooks/plugins"
echo ""
echo "  Protection (auto-applied):
    .claude/PROMPT_FREE_PROTOCOL.md       Canonical bug-avoidance rules (8)
    AGENTS.md                             Auto-loads via CLAUDE.md
    bugfix/                               Post-mortems (if referenced)
    scripts/apply-self-edit-safeguard-fix.sh   Re-run anytime

  Inside Claude:"
echo "    /prime                       Prime the session with codebase context"
echo "    /build-with-agent-team       Spawn agent team (split panes auto-created)"
echo "    /research <topic>            Spawn research agent for best practices"
echo "    /deploy                      Commit, push, snapshot"
echo ""
echo "  How agent teams work:"
echo "    1. start.sh launches Claude inside tmux"
echo "    2. /build-with-agent-team creates team via official Agent Teams API"
echo "    3. Subagents run in-process and exit on their own; no teardown needed"
echo "    4. Shift+Down cycles between teammates, click pane to interact"
echo "    5. Lead coordinates via shared task list + messaging"
echo "    6. Teammates communicate directly via SendMessage"
echo "    7. Lead cleans up team when done (TeamDelete)"
echo ""
echo "  Tmux shortcuts (inside session):"
echo "    Alt + Arrow keys             Navigate between panes"
echo "    Shift + Down                 Cycle through teammates (in-process mode)"
echo "    Prefix + |                   Split pane horizontally"
echo "    Prefix + -                   Split pane vertically"
echo "    Prefix + z                   Zoom/unzoom current pane"
echo "    Mouse                        Click to focus, drag to resize"
echo ""
echo -e "  ${GREEN}To start:${NC}  ./scripts/start.sh   (or just type 'pp')"
echo ""
