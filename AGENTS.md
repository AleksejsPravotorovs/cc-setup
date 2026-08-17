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
- `~/.claude/settings.json` + project `.claude/settings.json`: `permissionExplainerEnabled: false`, `defaultMode: "bypassPermissions"`, `skipDangerousModePermissionPrompt: true`. **`teammateMode` is deliberately unset** (default `"in-process"`) and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is `"0"` - see the agent-lifecycle rule below
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

**Model policy: opus-first, sonnet for trivial text (2026-08-17).** Owner retired Fable 5 outright - "No more Fable 5"; use the best model for each individual job. **Opus 5** (alias `opus`) is the DEFAULT for anything that ships or is reviewed as code: frontend, backend, devops/infra, schema/auth/payments, architecture, debugging, code review. **Sonnet 5** (alias `sonnet`) takes trivial work with no design decision: copy and wording edits, boilerplate docs, commit subjects, snapshot/state entries, mechanical renames. **Haiku 4.5** is available for high-volume mechanical passes. `fable` is retired and must never be spawned. Every `Agent(...)` spawn passes its alias explicitly. NEVER pin a dated/closed id - aliases survive retirements. New agent .md files must include a model line. GSD agents are governed by `/gsd:set-profile` instead.

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
## Rule - Agent lifecycle: use the DEFAULTS, never hand-roll teardown

**Corrected 2026-08-17.** The previous version of this rule commanded
`scripts/reap-teammates.sh --reap` and described `SessionEnd` / `Stop` /
`SubagentStop` hooks. **None of it was ever wired up in this repo** - no
`scripts/reap-teammates.sh`, and no such hooks in either `settings.json`. (The script
is real: it lives in `~/Downloads/cc-setup/scripts/` and in the durance.dev,
averium-consulting and novashop clones. It was simply never synced here.) So nothing
was ever reaped, and the command this rule told every session to run would have failed. Worse, the doctrine this rule enforced is precisely what
produced the dead-but-resident rows in the agent panel.

### Root cause of the zombie agent rows (measured 2026-08-17)

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` was `1` in three places at once
(`~/.claude/settings.json`, project `.claude/settings.json`, `~/.zshrc:2`). Per the
official docs, while that flag is on, **a subagent that Claude names launches as a
teammate** - "teams can form even when you didn't ask for one". Teammates do not
self-terminate; they idle indefinitely awaiting more work. Because this very file
also mandated a `name:` on every `Agent(...)` spawn, EVERY delegation silently became
a teammate. The docs name the second symptom too: "an orchestration flow that waits
on subagent results can stall" - the row you can arrow into that is alive and idle.

### The rule now

**Agent teams are OFF** - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "0"` in both
settings files. Consequences, all of them wanted:

- A named subagent is an ordinary **subagent** again: its result returns to the caller
  on completion, and it terminates by itself.
- `teammateMode` is unset, so the default `"in-process"` applies. No tmux panes means
  no orphan panes and no Ink renderer crash in narrow panes.
- **There is no teardown step. Do not write one.** Subagent cleanup is the harness's
  job, and with the flag off it does it correctly.

Turn teams back on only for work that genuinely needs teammates messaging each other
over a shared task list - and say so explicitly at the time. It must never be the
standing default, because ordinary delegation gets silently upgraded into it.

Self-audit: "[] About to add a shutdown / reap / teardown step? -> Don't. Verify the
flag reads `0` instead."
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

## Model policy (fleet) - opus-first, sonnet for trivial text
Owner instruction 2026-08-17. Supersedes opus-first (2026-08-08) and balanced routing
v2 in full: **no more Fable 5.** Pick the best model for each individual job.
- **Opus 5** (alias `opus`) - the DEFAULT. Anything that ships or is reviewed as code:
  frontend, backend, devops/infra, schema/auth/payments, architecture, debugging,
  review. When torn -> `opus`.
- **Sonnet 5** (alias `sonnet`) - trivial work carrying no design decision: copy and
  wording changes, boilerplate/doc fill, commit subjects, snapshot and state entries,
  mechanical renames, format conversions.
- **Haiku 4.5** (`claude-haiku-4-5-20251001`) - optional, for high-volume mechanical
  passes where Sonnet is overkill. Name it deliberately or not at all.
- **`fable` is retired. Never spawn it.**
Frontmatter: every roster agent stays `model: opus` - they are all senior roles.
`Agent(...)` spawns pass the alias explicitly. NEVER pin a dated/closed model id -
aliases survive retirements; the Haiku id above is the one documented exception.
<!-- /FLEET:RULE0 -->
