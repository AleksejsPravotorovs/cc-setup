# cc-setup

One-command setup for Claude Code + Agent Teams. Installs all dependencies, configures VS Code, and gets you coding in minutes.

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
```

### Windows

```powershell
irm https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.ps1 | iex
```

Open your project folder in VS Code, open the terminal, paste the command, and follow the prompts.

## What you get

**Tools installed** (skips what's already present):

| Tool | macOS | Linux | Windows |
|------|-------|-------|---------|
| Xcode CLT + Homebrew | Yes | — | — |
| Git | Via Homebrew | Expected pre-installed | Via winget/Chocolatey |
| Node.js + npm | Via Homebrew | Via apt/dnf/pacman | Via winget/Chocolatey |
| Claude CLI | npm global | npm global | npm global |
| tmux | Via Homebrew | Via apt/dnf/yum/pacman/apk | Via WSL (auto-installed) |
| WSL + Ubuntu | — | — | Auto-installed if missing |
| Claude CLI in WSL | — | — | Auto-installed for split panes |
| VS Code extensions | ESLint, Tailwind CSS, Prettier | ESLint, Tailwind CSS, Prettier | ESLint, Tailwind CSS, Prettier |

**Project configured**:
- `.claude/agents/` — 7 agent definitions (lead, frontend, backend, devops, skeptic, qa, researcher), each with MANDATORY prompt-free protocol block
- `.claude/commands/` — 4 slash commands (/prime, /build-with-agent-team, /deploy, /research)
- `.claude/settings.json` — agent teams config + PreToolUse/PermissionRequest auto-approve hooks + `permissionExplainerEnabled: false`
- `.claude/PROMPT_FREE_PROTOCOL.md` — mirror of the 8-rule safeguard protocol (AGENTS.md is canonical)
- `.vscode/settings.json` — workspace-level auto-approve (`chat.tools.*.autoApprove`, `chat.confirmBeforeRequest: false`)
- `.tmux.agent.conf` — tmux config for agent panes (macOS/Linux)
- `scripts/start.sh` — tmux session launcher (macOS/Linux)
- `scripts/start.ps1` — WSL tmux session launcher (Windows)
- `scripts/apply-self-edit-safeguard-fix.sh` — idempotent patcher that applies the full protocol (agents, skills, commands, settings, hooks) to any project
- `skills/durance-design/` - the fleet's design + frontend doctrine (trust narrative, tokens, type, motion on every block, process, gates), distilled from the durance.dev rework; ships with drop-in `templates/` (motion controller, reveal CSS, tokens) and `scripts/` (filmstrip shooter, design lock, image cost cap). Installed into every frontend repo as `.claude/skills/durance-design/` by `scripts/propagate-durance-design.sh`; loads on "design" / "frontend" / "landing" / "redesign".
- `CLAUDE.md`, `AGENTS.md` — project instructions (AGENTS.md holds the canonical 8-rule PROMPT_FREE_PROTOCOL, loaded into every session via `CLAUDE.md: @AGENTS.md`)

**User-scope Claude Code setup** (optional, macOS/Linux):
- `claude-user-config/` — 6 plugins + 5 GSD hook scripts + sanitized global settings.json
- `scripts/install-plugins.sh` — one-shot installer for plugins/hooks/settings (`bash scripts/install-plugins.sh`)
- See [claude-user-config/README.md](claude-user-config/README.md) for the plugin list and what gets wired up.

**Quick commands added** (persisted in shell profile):
- `pp` — launch Claude session (tmux + split pane git watch, `--dangerously-skip-permissions`)
- `pp-setup` — re-run setup for this project
- `pp-update` - pull latest `cc-setup` files from GitHub + auto-apply the safeguard protocol + refresh the `durance-design` skill in every frontend repo (vault projects and `~/Downloads` scan)

## Usage

```bash
# Start working
pp

# Re-run setup
pp-setup

# Pull latest cc-setup files + apply protocol updates
pp-update

# Inside Claude
/prime                    # Load codebase context
/build-with-agent-team    # Spawn agent team
/deploy                   # Commit, push, snapshot
/research <topic>         # Background research agent (writes to research/)
```

## Self-edit safeguard protocol (v2, 2026-04-17)

Claude Code v2.1.78+ has a **hardcoded self-edit safeguard** on `.claude/**` and `.git/**` that forces a 3-option permission prompt no flag disables. In narrow tmux teammate panes the Ink renderer overflows and crashes the pane with a raw JSX dump. `cc-setup` works around this structurally:

**Rules baked in** (`AGENTS.md` canonical / `.claude/PROMPT_FREE_PROTOCOL.md` mirror):
1. No `Write`/`Edit`/`MultiEdit`/`NotebookEdit` on `.claude/**` or `.git/**` — use `Bash` heredoc instead.
2. Agent artifacts live at repo root: `findings.md`, `research/`, `strategies/`, `qa/`, `web/` — never `.claude/`.
3. Teammates never ask the user — pre-authorised blanket permission.
4. Sub-agent prompts include the BLANKET PERMISSION block.
5. `Skill(X)` hooks are advisory; irrelevant → ignore.
6. Auto-approve stack: user-level `~/.claude/hooks/auto-approve*.sh` + project `.claude/settings.json` + `.vscode/settings.json` — 99% coverage. Rule 1 is the only defense for the hardcoded safeguard.
7. Commit/deploy cadence — only on explicit user request; always via `git` CLI; never `Edit` on `.git/**`.
8. Self-audit + persistence — violations are diagnosed and baked into the protocol.

**Apply the protocol to any project** (cc-setup-generated or bootstrapped otherwise):

```bash
cd <project>
bash ~/Downloads/cc-setup/scripts/apply-self-edit-safeguard-fix.sh
# or, if the project was created from cc-setup and has the script locally:
bash scripts/apply-self-edit-safeguard-fix.sh
```

The script is idempotent — safe to re-run. It patches agents/skills/commands, migrates artifacts out of `.claude/`, registers auto-approve hooks at user and project scope, and runs an 18-check verification pass.

**Full post-mortem:** `bugfix/bugfix-report-2026-04-17-self-edit-safeguard.md`.

## Detailed instructions

- [macOS setup guide](SETUP-MAC.md)
- [Linux setup guide](SETUP-LINUX.md)
- [Windows setup guide](SETUP-WINDOWS.md)
