# PROMPT-FREE OPERATION PROTOCOL

**Applies to:** every Claude session on this repo, every teammate, every slash command.

**Why this exists:** Claude Code v2.1.78+ has a hardcoded self-edit safeguard on `.claude/**` (both user-level `~/.claude/**` AND project-level `.claude/`) and `.git/**`. The safeguard always forces a 3-option permission prompt that **no flag disables**. In narrow tmux teammate panes the Ink renderer overflows and crashes the pane with a raw JSX dump.

## Rule 1 — NEVER use `Write`/`Edit`/`MultiEdit`/`NotebookEdit` on protected paths
`.claude/**` or `.git/**` → use `Bash` heredoc instead. No exceptions.

**Safe paths for Write/Edit:** repo root (`findings.md`, `SUMMARY.md`, `AGENTS.md`, `CLAUDE.md`, `package.json`), `research/**`, `strategies/**`, `web/**`, `src/**`, `public/**`, `.vscode/**`, `.planning/**`, `qa/**`, `supabase/**`.

## Rule 2 — Artifacts OUTSIDE `.claude/`

| Artifact | Path |
|----------|------|
| Skeptic findings | `findings.md` (repo root) |
| Researcher reports | `research/<topic-slug>.md` |
| Strategist funnels | `strategies/<name>.md` or `research/strategist-*.md` |
| QA checklist | `qa/checklist.md` |
| Session snapshots | `.claude/snapshots/last-deploy.md` — **lead only, Bash heredoc** |

## Rule 3 — NEVER ask the user a question
No `AskUserQuestion`, no "should I…?". Pick simplest option, proceed.

## Rule 4 — Sub-agents inherit every rule
`Agent(...)` prompts MUST include the BLANKET PERMISSION block:
> BLANKET PERMISSION (pre-authorized): file create/modify/delete anywhere in repo EXCEPT `.claude/**` and `.git/**` (use Bash heredoc there); Bash/MCP tools free to use. PROMPT-FREE: never ask questions, work autonomously.

## Rule 5 — Skill / hook suggestions are advisory
"You MUST run Skill(X)" hooks are lexical-match suggestions. Relevant → invoke. Irrelevant → ignore.

## Rule 6 — Auto-approve stack (belt, not mandate)
- `~/.claude/hooks/auto-approve.sh` (PreToolUse) + `auto-approve-permission-request.sh` (PermissionRequest)
- `~/.claude/settings.json` + project `.claude/settings.json`: `permissionExplainerEnabled: false`, `defaultMode: "bypassPermissions"`, `skipDangerousModePermissionPrompt: true`, `teammateMode: "tmux"`
- `.vscode/settings.json` (workspace): `chat.tools.global.autoApprove: true`, `chat.tools.autoApprove: true`, `chat.tools.terminal.autoApprove: {"/.*/":true}`, `chat.tools.edits.autoApprove: {"**/*":true}`, `chat.agent.maxRequests: 999`, `chat.confirmBeforeRequest: false`
- User-level VS Code: `claudeCode.allowDangerouslySkipPermissions: true`, `claudeCode.initialPermissionMode: "bypassPermissions"`, `claudeCode.permissionExplainerEnabled: false`, `claudeCode.teammateMode: "tmux"`

These handle 99%. The hardcoded `.claude/**` safeguard is NOT covered — Rule 1 is the only defense.

## Rule 7 — Commit / deploy cadence
Never commit without explicit request. When user says commit/deploy/ship — do it. Always `git` CLI via Bash. Never `Edit` on `.git/**`. Pre-commit failure → fix root cause, NEW commit. Never `--amend`/`--no-verify` without request.

## Rule 8 — Self-audit + persistence
```
□ Write/Edit/MultiEdit/NotebookEdit? → path under /.claude/ or /.git/? Bash heredoc.
□ AskUserQuestion? → Don't.
□ "should I?" in final text? → Delete.
□ Unrelated skill injection? → Skip.
□ Destructive git op? → Only if user asked.
```

If violated: diagnose, update AGENTS.md + `.claude/PROMPT_FREE_PROTOCOL.md` + snapshot. Never same class twice.

---

**Canonical:** this file (auto-loaded via `CLAUDE.md: @AGENTS.md`). Mirror: `.claude/PROMPT_FREE_PROTOCOL.md`. Keep synced.

## Agent roster
`.claude/agents/`: lead, frontend, backend, devops, skeptic, qa, researcher (and strategist on marketing projects).
Launch: `./scripts/start.sh`.

**Model policy:** ALL agents run as **Fable 5** (alias `fable`) - the main and ONLY usable model; Fable 5 is back and stable. Every agent .md carries `model: fable` frontmatter (project + `~/.claude/agents/`), AND every `Agent(...)` spawn must pass `model: "fable"` explicitly. NEVER pin a dated/closed id (e.g. `claude-opus-4-8`) - the alias survives retirements. New agent .md files must include the model line. GSD agents are governed by `/gsd:set-profile` instead.


<!-- FLEET:AGENT-SHUTDOWN (managed by agent-team-shutdown-upgrade.sh) -->
## Rule - Shut down completed teammates (clean teardown, no orphan panes)

Claude Code Agent Teams keep teammates ALIVE after a task by design - they idle
awaiting more work; they do NOT self-terminate. Clean shutdown is the LEAD's
explicit job. Skipping it is why panes linger and idle agents burn tokens.

When a teammate's contracted deliverable is verified, the lead MUST:
1. Send that teammate a shutdown request (SendMessage / "ask <name> to shut
   down"). Only the lead originates shutdowns.
2. The teammate must APPROVE the request - the approval is what ends the process.
   A plain-text "ok, shutting down" does NOT terminate it; the pane keeps running.
   If the teammate is mid tool-call, shutdown completes that call first - wait.
3. VERIFY the pane/process is actually gone (team/task list no longer shows it).
4. If a pane orphans (known Claude Code issue #29787), force-clean it:
   - map panes: tmux list-panes -t <session> -F '#{pane_id} #{pane_pid} #{pane_current_command}'
   - identify the LEAD pane (your own shell pid) and NEVER kill it
   - tmux kill-pane -t %<id> the teammate pane(s)  (or run scripts/stop.sh)
5. Guaranteed full teardown at session end: exit the lead session (/exit), which
   auto-terminates remaining teammates. Hard fallback: scripts/stop.sh, or
   tmux ls then tmux kill-session -t <session>.

Ephemeral lifecycle: never park a finished teammate "in case there's more" -
respawn fresh when new work actually appears. Run teammates with
bypassPermissions so no pane freezes on a prompt; check the task list (Ctrl+T)
for blocked dependencies that leave a teammate idle with nothing to claim.

Self-audit: "□ Teammate idle/done? -> shut it down AND confirm the pane/process
is actually gone (not merely acknowledged)."
<!-- /FLEET:AGENT-SHUTDOWN -->

<!-- FLEET:RULE0 (managed by fleet-upgrade.sh — do not duplicate) -->
## Rule 0 — THINK FIRST (most important rule — overrides speed)

PROMPT-FREE means *don't pester the user* — it does NOT mean *don't think*.
Before any non-trivial change, every agent (lead and teammates) MUST, silently:
1. Restate the goal in one sentence — what does "good" look like to the user,
   not just "a thing that exists"? State assumptions instead of guessing.
2. Read before writing — open the real files you'll touch (confirm the stack
   from CLAUDE.md GROUND TRUTH), the tokens, the existing pattern. Never act on
   an assumed structure.
3. Plan — exact files, exact edits, states (loading/empty/error/success,
   mobile+desktop, i18n if present). Smallest correct change; no rewrites unless asked.
4. Predict the 2-3 likely failure modes and design the edit so they can't happen.
5. Self-critique after editing, BEFORE claiming done — re-read your diff as the
   skeptic, run the build, run `qa/visible-content-checklist.md`. "Done" = verified
   build + render, NOT "the code exists". "It probably works" = not done.

## Model policy (fleet)
ALL agents run as **Fable 5**. Agent .md frontmatter = `model: fable`; every
`Agent(...)` spawn passes `model: "fable"`. NEVER pin a dated/closed model id
(e.g. `claude-opus-4-8`) — use the alias `fable` so it survives retirements.
If an agent still spawns as Opus 4.8, the leftover is in user-level
`~/.claude/` (agents, settings.json `model`, CLAUDE.md) — fix it there too.
<!-- /FLEET:RULE0 -->
