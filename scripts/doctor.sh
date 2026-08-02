#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  cc-setup doctor — why isn't the Claude CLI working?             ║
# ║  Read-only. No sudo. No installs. Paste the whole output back.   ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:  bash scripts/doctor.sh
#
# Deliberately does NOT use `set -e`: every probe must run even when the
# previous one fails — a doctor that stops at the first symptom is useless.

echo "===== cc-setup doctor ====="
date
echo

echo "--- system ---"
echo "os:      $(uname -s) $(uname -r)"
echo "arch:    $(uname -m)"
echo "shell:   ${SHELL:-unset}   (running under: $(ps -p $$ -o comm= 2>/dev/null))"
echo "user:    $(whoami)"
echo "home:    $HOME"
echo

echo "--- claude on PATH ---"
if command -v claude >/dev/null 2>&1; then
  echo "which:   $(command -v claude)"
  echo "version: $(claude --version 2>&1 | head -1)"
else
  echo "which:   NOT FOUND on PATH"
fi
echo "launcher ~/.local/bin/claude: $([ -e "$HOME/.local/bin/claude" ] && ls -l "$HOME/.local/bin/claude" || echo 'absent')"
echo "versions ~/.local/share/claude/versions:"
ls -1 "$HOME/.local/share/claude/versions" 2>/dev/null | tail -3 || echo "  (none)"
echo

echo "--- other claude installs (conflicts) ---"
for p in /usr/local/bin/claude /opt/homebrew/bin/claude "$HOME/.npm-global/bin/claude"; do
  [ -e "$p" ] && echo "found: $(ls -l "$p")"
done
command -v brew >/dev/null 2>&1 && brew list --cask 2>/dev/null | grep -i claude && echo "(installed as a Homebrew cask)"
alias claude 2>/dev/null && echo "(a shell ALIAS named claude exists — it wins over PATH)"
echo

echo "--- is ~/.local/bin on PATH? ---"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "yes" ;;
  *) echo "NO  <-- this alone makes 'claude' look uninstalled" ;;
esac
echo "PATH entries:"
printf '%s\n' "$PATH" | tr ':' '\n' | sed 's/^/  /'
echo

echo "--- shell rc files ---"
for RC in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zprofile"; do
  [ -f "$RC" ] || continue
  echo "$RC:"
  grep -nE '\.local/bin|alias pp|npm-global|NPM_CONFIG_PREFIX' "$RC" 2>/dev/null | sed 's/^/  /' || echo "  (no relevant lines)"
done
echo

echo "--- node / npm ---"
echo "node:    $(command -v node || echo 'absent')  $(node --version 2>/dev/null)"
echo "npm:     $(command -v npm  || echo 'absent')  $(npm --version 2>/dev/null)"
if command -v npm >/dev/null 2>&1; then
  PREFIX="$(npm config get prefix 2>/dev/null)"
  echo "npm global prefix: $PREFIX"
  if [ -d "$PREFIX/lib/node_modules" ]; then
    echo "owner of \$PREFIX/lib/node_modules: $(ls -ld "$PREFIX/lib/node_modules" | awk '{print $3":"$4}')"
    if [ -w "$PREFIX/lib/node_modules" ]; then
      echo "writable by $(whoami): yes"
    else
      echo "writable by $(whoami): NO  <-- 'npm install -g' here fails with EACCES"
    fi
  fi
fi
echo

echo "--- network reachability ---"
echo "(any HTTP code = reachable; UNREACHABLE = blocked by network/proxy/DNS)"
for url in https://claude.ai/install.sh https://downloads.claude.ai/claude-code-releases/latest https://api.anthropic.com; do
  # -L follows redirects, no -f: we want the status code, not curl's verdict
  code="$(curl -sS -L -o /dev/null -m 10 -w '%{http_code}' "$url" 2>/dev/null)"
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    code="UNREACHABLE"
  fi
  echo "  $code  $url"
done
echo

echo "--- claude doctor (only if claude runs) ---"
if command -v claude >/dev/null 2>&1; then
  claude doctor 2>&1 | head -40
else
  echo "skipped — claude is not on PATH"
fi
echo

echo "--- tmux ---"
echo "tmux:    $(command -v tmux || echo 'absent')  $(tmux -V 2>/dev/null)"
echo
echo "===== end of report — paste everything above ====="
