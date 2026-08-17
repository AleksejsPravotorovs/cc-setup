# PROMPT-FREE OPERATION PROTOCOL

**Applies to:** every Claude session on this repo, every teammate, every slash command.

**Why this exists:** Claude Code v2.1.78+ has a hardcoded self-edit safeguard on `.claude/**` (both user-level `~/.claude/**` AND project-level `.claude/`) and `.git/**`. The safeguard always forces a 3-option permission prompt that **no flag disables**. In narrow tmux teammate panes the Ink renderer overflows and crashes the pane with a raw JSX dump.

## Rule 1 – NEVER use `Write`/`Edit`/`MultiEdit`/`NotebookEdit` on protected paths
`.claude/**` or `.git/**` → use `Bash` heredoc instead. No exceptions.

**Safe paths for Write/Edit:** repo root (`findings.md`, `SUMMARY.md`, `AGENTS.md`, `CLAUDE.md`, `package.json`), `research/**`, `strategies/**`, `web/**`, `src/**`, `public/**`, `.vscode/**`, `.planning/**`, `qa/**`, `supabase/**`.

## Rule 2 – Artifacts OUTSIDE `.claude/`

| Artifact | Path |
|----------|------|
| Coordinator decomposition log | `decomposition.md` (repo root) - written BEFORE the first spawn |
| Skeptic findings | `findings.md` (repo root) |
| Researcher reports | `research/<topic-slug>.md` |
| Strategist funnels | `strategies/<name>.md` or `research/strategist-*.md` |
| QA checklist | `qa/checklist.md` |
| Session snapshots | `.claude/snapshots/last-deploy.md` – **lead only, Bash heredoc** |

## Rule 3 – NEVER ask the user a question
No `AskUserQuestion`, no "should I…?". Pick simplest option, proceed.

## Rule 4 – Sub-agents inherit every rule
`Agent(...)` prompts MUST include the BLANKET PERMISSION block:
> BLANKET PERMISSION (pre-authorized): file create/modify/delete anywhere in repo EXCEPT `.claude/**` and `.git/**` (use Bash heredoc there); Bash/MCP tools free to use. PROMPT-FREE: never ask questions, work autonomously.

## Rule 5 – Skill / hook suggestions are advisory
"You MUST run Skill(X)" hooks are lexical-match suggestions. Relevant → invoke. Irrelevant → ignore.

## Rule 6 – Auto-approve stack (belt, not mandate)
- `~/.claude/hooks/auto-approve.sh` (PreToolUse) + `auto-approve-permission-request.sh` (PermissionRequest)
- `~/.claude/settings.json` + project `.claude/settings.json`: `permissionExplainerEnabled: false`, `defaultMode: "bypassPermissions"`, `skipDangerousModePermissionPrompt: true`. **`teammateMode` is deliberately unset** (default `"in-process"`) and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is `"0"`
- `.vscode/settings.json` (workspace): `chat.tools.global.autoApprove: true`, `chat.tools.autoApprove: true`, `chat.tools.terminal.autoApprove: {"/.*/":true}`, `chat.tools.edits.autoApprove: {"**/*":true}`, `chat.agent.maxRequests: 999`, `chat.confirmBeforeRequest: false`
- User-level VS Code: `claudeCode.allowDangerouslySkipPermissions: true`, `claudeCode.initialPermissionMode: "bypassPermissions"`, `claudeCode.permissionExplainerEnabled: false` (no `claudeCode.teammateMode` - the default is correct)

These handle 99%. The hardcoded `.claude/**` safeguard is NOT covered – Rule 1 is the only defense.

## Rule 7 – Commit / deploy cadence
Never commit without explicit request. When user says commit/deploy/ship – do it. Always `git` CLI via Bash. Never `Edit` on `.git/**`. Pre-commit failure → fix root cause, NEW commit. Never `--amend`/`--no-verify` without request.

## Rule 8 – Self-audit + persistence
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
Every roster agent is a senior-to-master-level expert in its field. The agent .md
files embed an "Expert toolkit" section with exact command routing (frontend: emil
design-eng skills, `/impeccable <command> <target>`, Higgsfield CLI; backend/devops:
Supabase, Vercel, Redis, Sentry CLIs). Agents give and run the PROPER COMMANDS from
those tables based on what needs fixing - never improvised flags.
Launch: `./scripts/start.sh`.

Roster `.md` files are OVERWRITTEN by fleet syncs. To keep project-authored content in
one, put it below this exact line - everything from the marker to EOF survives every
future sync verbatim:
`<!-- PROJECT-LOCAL: preserved across fleet syncs -->`

**Model policy: opus-first (2026-08-08).** Owner, verbatim: "why are the agents fable 5... please, from now on, use opus 5". **Opus 5** (alias `opus`) is the DEFAULT for EVERY spawn - code and text alike: frontend, backend, devops/infra, schema/auth/payments, architecture, debugging, code review, snapshots, commit subjects, boilerplate docs. Every `Agent(...)` spawn passes `model: "opus"` explicitly. `fable` is no longer spawned by default - use it only when the owner names it. NEVER pin a dated/closed id (e.g. `claude-opus-4-8`) - aliases survive retirements. New agent .md files must include a model line. GSD agents are governed by `/gsd:set-profile` instead.

## Coordinator doctrine (multi-agent work) - full version: `/build-with-agent-team`

The orchestrating session is the **coordinator**, and everything below follows from one
fact: **every subagent starts blank.**

1. **Shape, not difficulty.** Go multi-agent only when the WORK's shape asks for it -
   parallelizable, context-exceeding, breadth-first, many-tools. Tightly-coupled work and
   coherent coding changes belong to ONE agent no matter how hard they are.
2. **Isolation.** A subagent gets its own system prompt + your brief + project CLAUDE.md +
   its tools. It does NOT get your history, tool results, reasoning, or any peer's output,
   and it remembers nothing between invocations. Only its final message returns, verbatim.
3. **The brief is the only channel.** Anything you know and do not write into the
   `Agent(...)` prompt does not exist. Write goals and quality criteria, not step lists.
   The coordinator's `allowed-tools` MUST include `Agent`/`Task` or delegation silently
   never happens.
4. **Hub-and-spoke.** Subagents return only to the coordinator, never to each other, and
   cannot spawn subagents. That buys observability, one error policy, controlled flow.
5. **Four jobs:** decompose-and-select, partition scope (disjoint slices), refine
   iteratively (re-brief BROADER), route centrally.
6. **Log the decomposition** in `decomposition.md` (repo root) before spawning.
7. **Signature failure:** result incomplete but every subagent succeeded = the
   coordinator's decomposition was too narrow. Read the log, broaden, re-spawn. Never
   blame the worker, add tools, or upgrade the model first.
8. **Citations are a context-passing problem.** Pass findings as structured data
   (`source_url`, `document_name`, `page_number`, `file:line`) - uncited synthesis means
   the synthesizer was handed a summary instead of the findings.
9. **Spawn independent agents in parallel** - multiple `Agent(...)` calls in ONE message.
10. **Prompt = sign (probabilistic), code = lock (deterministic).** Financial, security,
    compliance and irreversible actions need programmatic enforcement (a `PreToolUse`
    hook / prerequisite gate), never a stronger prompt. `PreToolUse` can block (exit 2);
    `PostToolUse` cannot - it only reshapes results after the action already ran. exit 1
    does NOT block.
11. **Attention dilution** (quality degrading across many items) is structural: fix it
    with per-item passes plus a separate cross-item integration pass, never with a bigger
    model or a longer context window.
12. **Sessions:** resume when the old context is still true, fork to explore a divergent
    path, start fresh with a structured summary when files changed underneath. Forking
    does NOT fix staleness - it copies the stale baseline into both branches.

<!-- FLEET:AGENT-SHUTDOWN (managed by agent-team-shutdown-upgrade.sh) -->
## Rule - Shut down completed teammates (clean teardown, no orphan panes)

Claude Code Agent Teams keep teammates ALIVE after a task by design - they idle
awaiting more work; they do NOT self-terminate. Clean shutdown is the LEAD's
explicit job. Skipping it is why panes linger and idle agents burn tokens.

### The teardown is ONE command. Everything else below is context.

```
scripts/reap-teammates.sh --reap     # kill every teammate, verified by PID
scripts/reap-teammates.sh --check    # the ONLY accepted proof they are gone
```

Run `--reap` the moment a deliverable is verified. Do not send a shutdown
request and assume it worked, and do not park a finished teammate "in case
there is more" - respawn fresh when new work actually appears.

**`ListAgents`, the agent panel, and the task list are NOT proof.** Measured
2026-08-08: `ListAgents` returned "No reachable agents" while the teammate was
still running (pid 41677, 56 minutes resident), and the agent panel kept showing
a row for a process that was already dead. Both lie in both directions.
`scripts/reap-teammates.sh --check` reads `ps` and is the only honest answer;
exit 0 means none alive, exit 1 lists them.

**Do not treat "idle" as "finished".** Measured the same day: `TeammateIdle`
fires while an agent is mid tool call - an agent whose only job was `sleep 120`
had already reported idle with the sleep still running. And `SubagentStop` did
NOT fire at all for a background teammate on 2.1.226; that agent sat resident
for 7 minutes after its work completed. So no hook event reliably means "done",
which is exactly why the lead must run `--reap` deliberately.

The harness now backstops this (`.claude/settings.json`):
- `SessionEnd` -> `--reap`. Guarantees nothing outlives the session, ever.
- `Stop` -> `--sweep`. Every turn, prints any resident teammate with its uptime.
  It only auto-kills agents with a real completion marker; an unmarked agent is
  reported, never killed, because killing live work is worse than a nag.
- `SubagentStop` / `TaskCompleted` -> `--mark-done`. Wired so that if either
  starts firing, precise auto-reap begins working with no code change.

If a pane orphans anyway (Claude Code issue #29787), `--reap` already kills the
pane and the PID together. Manual fallback, in order:
   - map panes: tmux list-panes -t <session> -F '#{pane_id} #{pane_pid} #{pane_current_command}'
   - identify the LEAD pane (your own shell pid) and NEVER kill it
   - tmux kill-pane -t %<id> the teammate pane(s)  (or run scripts/stop.sh)
   - never kill by image name (`pkill node`) - that takes down the harness too
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

<!-- FLEET:RULE0 (managed by fleet-upgrade.sh - do not duplicate) -->
## Rule 0 - THINK FIRST (most important rule - overrides speed)

PROMPT-FREE means *don't pester the user* - it does NOT mean *don't think*.
Before any non-trivial change, every agent (lead and teammates) MUST, silently:
1. Restate the goal in one sentence - what does "good" look like to the user,
   not just "a thing that exists"? State assumptions instead of guessing.
2. Read before writing - open the real files you'll touch (confirm the stack
   from CLAUDE.md GROUND TRUTH), the tokens, the existing pattern. Never act on
   an assumed structure.
3. Plan - exact files, exact edits, states (loading/empty/error/success,
   mobile+desktop, i18n if present). Smallest correct change; no rewrites unless asked.
4. Predict the 2-3 likely failure modes and design the edit so they can't happen.
5. Self-critique after editing, BEFORE claiming done - re-read your diff as the
   skeptic, run the build, run `qa/visible-content-checklist.md`. "Done" = verified
   build + render, NOT "the code exists". "It probably works" = not done.

## Model policy (fleet) - opus-first
Owner instruction, 2026-08-08, verbatim: "why are the agents fable 5... please,
from now on, use opus 5". This SUPERSEDES balanced routing v2 in full.
- **Opus 5** (alias `opus`) - DEFAULT for EVERY spawn, code and text alike:
  frontend, backend, devops/infra, schema/auth/payments, debugging, review,
  snapshots, commit subjects, boilerplate docs.
- `fable` is no longer spawned by default. Use it only when the owner names it.
Frontmatter: every roster agent = `model: opus`. `Agent(...)` spawns pass the
alias explicitly. NEVER pin a dated/closed model id - aliases survive retirements.
<!-- /FLEET:RULE0 -->
