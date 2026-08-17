# Claude Code Setup — macOS

## Quick start (one command)

Open VS Code, open your project folder, open the terminal (`` Ctrl+` ``), and run:

```bash
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
```

This downloads the scripts and runs the full setup. Follow the prompts.

## What it installs

The setup script detects what's missing and offers to install each item:

1. **Xcode Command Line Tools** — git, compilers, build tools
2. **Homebrew** — macOS package manager (handles Apple Silicon automatically)
3. **Git** — version control + prompts to configure user.name/email
4. **Node.js + npm** — JavaScript runtime (via Homebrew)
5. **Claude CLI** — official installer (`curl -fsSL https://claude.ai/install.sh | bash` → `~/.local/bin/claude`, auto-updating). Falls back to `brew install --cask claude-code`, then to `npm install -g @anthropic-ai/claude-code` if npm's global prefix is writable. Never `sudo npm`.
6. **tmux** — terminal multiplexer for agent team split panes (via Homebrew)
7. **Project dependencies** — `npm install` (only if `package.json` exists)
8. **VS Code extensions** — ESLint, Tailwind CSS IntelliSense, Prettier

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
Run `source ~/.zshrc` (or `source ~/.bashrc`) or open a new terminal. The setup adds your quick commands to your shell profile.

**"tmux not found"**
Run `brew install tmux`, or re-run setup with `pp-setup`.

**Claude CLI install fails with `EACCES: permission denied, mkdir '/usr/local/lib/node_modules/...'`**
npm's global prefix is root-owned (usually because Node came from the nodejs.org `.pkg`
installer). Do **not** fix this with `sudo npm install -g`. Install Claude Code the
recommended way instead, then re-run `pp-setup`:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

It installs to `~/.local/bin/claude`, needs no admin rights, and auto-updates.
Check your prefix with `npm config get prefix` and `ls -ld $(npm config get prefix)/lib/node_modules`.

**Homebrew on Apple Silicon**
The setup handles `/opt/homebrew` automatically and adds it to your `.zshrc`.

**VS Code `code` command not found**
Open VS Code, then Cmd+Shift+P and type "Shell Command: Install 'code' command in PATH".
