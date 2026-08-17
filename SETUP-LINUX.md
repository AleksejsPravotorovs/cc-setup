# Claude Code Setup — Linux

## Quick start (one command)

Open your terminal in your project folder and run:

```bash
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
```

This downloads the scripts and runs the full setup. Follow the prompts.

## Supported package managers

The setup script auto-detects your package manager:

| Distro | Package manager | Node.js | tmux |
|--------|----------------|---------|------|
| Ubuntu / Debian | apt | `apt install nodejs npm` | `apt install tmux` |
| Fedora | dnf | `dnf install nodejs npm` | `dnf install tmux` |
| CentOS / RHEL | yum | — | `yum install tmux` |
| Arch / Manjaro | pacman | `pacman -S nodejs npm` | `pacman -S tmux` |
| Alpine | apk | — | `apk add tmux` |

## What it installs

The setup script detects what's missing and offers to install each item:

1. **Git** — expected to be pre-installed; prompts to configure user.name/email if unset
2. **Node.js + npm** — JavaScript runtime (via your distro's package manager)
3. **Claude CLI** — official installer (`curl -fsSL https://claude.ai/install.sh | bash` → `~/.local/bin/claude`, auto-updating), falling back to `npm install -g @anthropic-ai/claude-code` only if npm's global prefix is writable. Never `sudo npm`.
4. **tmux** — terminal multiplexer for agent team split panes
5. **Project dependencies** — `npm install` (only if `package.json` exists)
6. **VS Code extensions** — ESLint, Tailwind CSS IntelliSense, Prettier (if `code` CLI is available)

It also configures:
- `~/.claude/settings.json` — user-level settings. Agent teams are OFF (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0`) and `teammateMode` is unset (harness default `in-process`)
- `.gitignore` — adds `.env` and `.env.*` entries

## What it downloads

The installer (`install.sh`) downloads these files before running setup:

- `scripts/setup.sh` — full setup script
- `scripts/start.sh` — tmux session launcher
- `.claude/agents/` — 7 agent definitions (lead, frontend, backend, devops, skeptic, qa, researcher)
- `.claude/commands/` — 4 slash commands (/prime, /build-with-agent-team, /deploy, /research)
- `.claude/settings.json` — project-level agent teams configuration (only if not present)
- `.tmux.agent.conf` — tmux configuration for agent panes (only if not present)
- `CLAUDE.md`, `AGENTS.md` — project instructions for Claude (only if not present)

## After setup

### Start a Claude session

```bash
pp
```

This launches a tmux session with Claude (`--dangerously-skip-permissions`) in the left pane and a git watch loop in the right pane.

### Re-run setup

```bash
pp-setup
```

### Set up a new project

```bash
mkdir my-new-project && cd my-new-project
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
```

### Inside Claude

| Command | What it does |
|---|---|
| `/prime` | Load codebase context |
| `/build-with-agent-team` | Spawn agent team (auto split panes) |
| `/research <topic>` | Spawn research agent |
| `/deploy` | Commit, push, snapshot |

## Troubleshooting

**"pp: command not found"**
Run `source ~/.bashrc` (or `source ~/.zshrc`) or open a new terminal. The setup adds quick commands to your shell profile.

**"tmux not found"**
Install via your package manager (e.g., `sudo apt install tmux`) or re-run setup with `pp-setup`.

**"node: command not found" after install**
Some distros install an older version. If you need a newer Node.js, use [NodeSource](https://github.com/nodesource/distributions):
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Git not installed**
Most Linux distros include git. If missing: `sudo apt install git` (Debian/Ubuntu) or `sudo dnf install git` (Fedora).

**VS Code `code` command not found**
Open VS Code, then Ctrl+Shift+P and type "Shell Command: Install 'code' command in PATH".
