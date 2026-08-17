# Claude Code — User Config Snapshot

Snapshot of user-scope (`~/.claude/`) config — plugins, hooks, settings — captured from a working setup.

## What's here

```
claude-user-config/
├── settings.template.json   Sanitized ~/.claude/settings.json (__HOME__ placeholder)
├── plugins.manifest.json    6 plugins + 4 marketplaces I use daily
├── hooks/                   5 GSD hook scripts (SessionStart, Pre/PostToolUse, statusLine)
└── README.md                (this file)
```

## What gets installed

### Plugins (6)

| Plugin | Marketplace | Role |
|---|---|---|
| `superpowers` | claude-plugins-official | Brainstorming, TDD, verification, plan execution, subagent dispatch, debugging, worktrees, code review |
| `vercel-plugin` | vercel-vercel-plugin | Deploy, env vars, preview URLs, runtime logs, Next.js / AI SDK / Turborepo guidance |
| `context7` | claude-plugins-official | Live library/framework docs lookup (React, Next.js, Prisma, etc.) |
| `code-simplifier` | claude-plugins-official | Refine recently modified code |
| `code-review` | claude-plugins-official | Automated PR review |
| `claude-mem` | thedotmack | Persistent cross-session memory |

### Hooks (5 — all GSD project)

- `gsd-check-update.js` — SessionStart — check for GSD updates
- `gsd-context-monitor.js` — PostToolUse — context window warnings
- `gsd-prompt-guard.js` — PreToolUse Write/Edit — prompt quality guard
- `gsd-statusline.js` — statusLine — custom status line
- `gsd-workflow-guard.js` — not currently wired in settings; kept for future use

### Permissions

Pre-approved bash/edit/agent/team/MCP tools so the assistant never blocks on permission prompts (user works remotely from phone). Default mode: `bypassPermissions`. Adjust `allow` list in `settings.template.json` if you want tighter defaults.

### Agent Teams

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` keeps agent teams OFF, which is the harness default and what you want: with the flag on, a subagent Claude *names* launches as a teammate, and teammates never self-terminate - they idle in the agent panel forever. `teammateMode` is left unset (default `"in-process"`). Turn teams on only for work that genuinely needs teammates messaging each other, and turn it back off afterwards.

## Install

From the repo root:

```bash
bash scripts/install-plugins.sh
```

That script:

1. Copies `hooks/*.js` → `~/.claude/hooks/`
2. Substitutes `__HOME__` in `settings.template.json` → writes to `~/.claude/settings.json` (backing up any existing one)
3. Registers the 3 required marketplaces via `claude plugin marketplace add`
4. Installs the 6 plugins via `claude plugin install`
5. On first `claude` launch, anything that CLI-install missed is auto-installed from `enabledPlugins` in settings.

## What is NOT here (by design)

- **`~/.claude.json`** — contains OAuth / session tokens. Never copied.
- **MCP server credentials** — per-project in `.mcp.json` or `claude mcp add` with auth tokens. Add those yourself.
- **Project-specific `.claude/`** — agents, commands, findings, snapshots live in each project's `.claude/` dir, not here.
- **Vercel plugin telemetry ID / device ID** — machine-specific, re-generated on first run.
- **History, cache, sessions, projects/** — runtime state, regenerated locally.

## Updating the snapshot

To refresh this dir from your current `~/.claude/`:

```bash
# hooks
cp ~/.claude/hooks/*.js claude-user-config/hooks/

# settings — strip absolute paths
sed "s|$HOME|__HOME__|g" ~/.claude/settings.json > claude-user-config/settings.template.json

# plugins manifest — manually sync with ~/.claude/plugins/installed_plugins.json
# (the JSON shape differs; manifest is human-curated)
```

Commit the diff.
