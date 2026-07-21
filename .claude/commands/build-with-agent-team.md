# Agent Team Orchestration (Official Agent Teams) - optimized v2

## MANDATORY - read before spawning anything
`.claude/PROMPT_FREE_PROTOCOL.md`. Every `Agent(...)` prompt you build MUST include the BLANKET PERMISSION block from the protocol. Hard rules:
- Teammates MUST NOT use `Write`/`Edit` on paths under `.claude/**` or `.git/**` - use `Bash` heredoc
- Teammate artifacts live at repo root (`findings.md`, `research/`, `strategies/`, `qa/`, `web/`) - NOT `.claude/`
- Teammates NEVER ask the user questions - pre-authorized blanket permission
- Model routing v2: every `Agent(...)` spawn passes an alias explicitly - `model: "fable"` for anything that ships as code (builders, reviewers, debuggers); `model: "opus"` ONLY for pure template-fill text (snapshot text, copy decks from a fixed template). When torn -> fable. Never a dated id.

## Phase -1: TRIAGE - size the engine to the job (run this FIRST, always)

The full team ceremony (contract -> TeamCreate -> 3-5 teammates -> fix cycles -> teardown)
costs the most wall-clock time and the most tokens of anything in this workflow. Most
feature requests and updates do NOT need it. Classify before spawning anything:

| Size | Signals | Engine |
|------|---------|--------|
| **S** | <=2 files, single layer, no schema/auth/payment/deploy surface | **No team, no subagents.** Implement directly, run Rule 0 self-critique + build/render check, done. |
| **M** | single layer, <=5 files, clear spec, low blast radius | **2 subagents, no team:** 1 builder + 1 combined reviewer (skeptic+QA in one prompt). Spawn builder; spawn reviewer only after builder reports done. Subagents report back to you - no inter-agent messaging needed at this size. |
| **L** | cross-layer (front+back+infra), genuinely parallel workstreams, contested scope | **Full team** (Phases 0-4 below), 2-4 teammates max. |

- The "lead never implements" rule applies ONLY in team mode (L). In S/M there is no
  team lead role - direct implementation is correct and cheapest.
- When torn between M and L, pick M. Escalate to L only if the builder reports scope
  that genuinely benefits from parallel hands. Never the reverse (starting L "just in case").
- Typical single-repo feature/update = S or M. L is the exception, not the default.

## Token + wall-clock economy rules (all modes)

1. **CONTEXT PACK - build once, paste everywhere.** Before spawning, the lead assembles
   one pack: stack line from CLAUDE.md GROUND TRUTH, exact file paths (+ key excerpts),
   conventions/tokens, acceptance criteria, file ownership. Paste it into EVERY agent
   prompt and state: "This pack is ground truth - do NOT re-explore the repo beyond the
   files named here." N agents independently re-reading the repo is the #1 token leak.
2. **Re-verify by SendMessage, never respawn.** Keep skeptic/QA alive through the fix
   cycle and send them the diff to re-check - their context is already loaded. Only spawn
   a fresh reviewer if the original was already shut down.
3. **Stage the spawns.** Builders first (all in ONE message so they start in parallel).
   Reviewers only when the first implementation task completes - idle reviewers burn
   tokens polling. Never spawn the whole roster up front.
4. **Fewer, bigger tasks.** 2-4 tasks per teammate, each independently verifiable.
   5-6 micro-tasks multiply claim/update/report overhead with no quality gain.
5. **Severity gate.** Only HIGH and MEDIUM findings trigger a fix cycle. LOW findings go
   to `findings.md` as backlog - do not spawn agents for them. Max 2 fix cycles; if still
   red, lead documents the residual in `findings.md` and ships or reverts (prompt-free:
   decide, do not ask).
6. **Shutdown on delivery, not at session end.** The moment a teammate's deliverable is
   verified, shut it down (Phase 4). Parked teammates burn tokens idling.
7. **Broadcast only for launch and teardown.** All other messages are 1:1.

## Agent roster

Agent definitions live in `.claude/agents/*.md`. Every roster agent is a senior-to-master-level expert whose .md embeds an "Expert toolkit" command-routing table (frontend: emil design-eng skills + `/impeccable <command> <target>` + Higgsfield CLI; backend/devops: Supabase/Vercel/Redis/Sentry CLIs) - trust those tables, run the proper commands. Frontmatter: coding roster `model: fable`; template agents may be `model: opus` (routing v2):
- **lead** - contract owner + orchestrator (you, L-mode only)
- **frontend** - UI + client logic
- **backend** - API + database + server logic
- **devops** - infrastructure + deployment
- **skeptic** - security + UX devil's advocate (review-only, no code). **Must update `findings.md` (repo root)** after every review.
- **qa** - structured pass/fail verification + regression checks
- **researcher** - technical research and best practices analysis (read-only)

For S/M work, skeptic + qa collapse into ONE combined reviewer prompt. Split them only
in L-mode when review volume genuinely warrants two contexts.

If a task references an agent name NOT in `.claude/agents/`: infer the role from context
and create `.claude/agents/<name>.md` (Bash heredoc - protected path) before spawning.
Prompt-free: pick the most sensible role definition, do not ask.

## Full-team workflow (L-mode only)

### Phase 0: Contract (lead only)
Produce a SHARED EXECUTION CONTRACT: scope (in/out), non-overlapping file ownership per
agent, acceptance criteria, merge order. Build the CONTEXT PACK here - one repo read,
reused by every teammate.

### Phase 1: Spawn team (official mechanism - MANDATORY)
As of Claude Code v2.1.178 there is NO `TeamCreate`/`TeamDelete` - the team forms
automatically when the first teammate is spawned, and team resources are cleaned up
automatically when the lead session exits. `team_name` on `Agent(...)` is accepted but
ignored - do not pass it or wait on team setup.

1. **`TaskCreate`** - 2-4 tasks per teammate with acceptance criteria and dependencies
   (`addBlockedBy`); review/QA tasks blocked by implementation tasks. (Official docs
   suggest 5-6 per teammate; we deliberately run fewer/bigger to cut claim/report overhead.)
2. **`Agent`** tool - spawn BUILDERS ONLY first, all in one message, each with:
   - `name` (e.g. "frontend", "backend") - predictable names for later SendMessage
   - model per routing v2: `model: "fable"` for code work (the default); `"opus"` only for pure template-fill. Plus `mode: "bypassPermissions"`, `run_in_background: true`
   - `prompt`: CONTEXT PACK + their contract slice + BLANKET PERMISSION block
     (teammates auto-load CLAUDE.md/skills/MCP but NOT the lead's conversation history)
3. Spawn reviewer(s) when the first implementation task completes, not before
4. Known limits (experimental): one team per session; no nested teams (teammates cannot
   spawn teammates); in-process teammates cannot run background subagents; `/resume`
   does not restore in-process teammates - respawn instead

**Team size**: 2-4 teammates. Three focused teammates outperform five scattered ones.

**Anti-patterns (DO NOT DO):** manual `tmux split-window` / `send-keys` agent spawning,
`cat prompt.md | claude` pipes, spawning the full roster before work exists for it.

**After spawning:** stay quiet. Teammates message when done. Speak only on blockers.

### Phase 2: Coordination
- Teammates claim tasks via `TaskUpdate` (file-locked) and mark them completed
- Blocked tasks unblock automatically when dependencies complete
- `SendMessage` 1:1 for everything; broadcast only launch/teardown
- Lead reviews outputs against the contract as each teammate reports back - and shuts
  that teammate down immediately once its deliverable is verified (Phase 4), even while
  others still work

### Phase 3: Fix cycle (HIGH/MEDIUM findings only)
1. Lead MUST NOT fix bugs directly - create fix tasks referencing the findings
2. Route fixes to the still-alive builder via SendMessage if possible; spawn fresh only
   if it was already shut down
3. After fixes land, re-verify via SendMessage to the STILL-ALIVE skeptic/QA (rule 2
   above) - do not spawn fresh reviewers while the originals live
4. Max 2 cycles, then severity-gate rule 5 applies (document residual, ship or revert)

**Anti-patterns:** lead editing implementation files; skipping re-verification;
respawning fresh reviewers each cycle; fix cycles for LOW findings.

### Phase 4: Cleanup (see AGENTS.md "Shut down completed teammates")
1. The moment a teammate's deliverable is verified, send it a shutdown request
   (SendMessage). Only the lead originates shutdowns.
2. The teammate must APPROVE the request - approval is what ends the process; a prose
   "ok" does NOT terminate it. Mid tool-call, shutdown completes that call first - wait.
3. VERIFY each pane/process is actually gone (task list no longer shows it). Orphaned
   pane (Claude Code #29787): `tmux kill-pane` on the teammate pane (never the lead),
   or `scripts/stop.sh` for full teardown.
4. Session end = exit the lead session (`/exit`), which auto-terminates remaining
   teammates and auto-cleans team directories (no TeamDelete step exists anymore).
   `scripts/stop.sh` is the hard fallback; the task-list dir under `~/.claude/tasks/`
   persists by design for resumed sessions.
5. Update `findings.md` (repo root) with resolved items.

## Findings automation
- **Skeptic/reviewer** updates `findings.md` (repo root) after every review: new findings
  under section + severity heading; resolved items marked ~~strikethrough~~ with commit context
- **Lead** marks findings resolved when fixes are verified and merged

## Rules
- Agents MUST NOT edit files outside their contracted scope
- In L-mode the lead only contracts, coordinates, creates tasks, spawns, and verifies
- Reviewers find bugs -> fix tasks -> re-verify via SendMessage. Never lead-self-fix in L-mode.
- Build/verify per CLAUDE.md GROUND TRUTH must pass after all changes (`npm run build`
  where a build exists; rendered-page check on static stacks)
- If an agent starts doing another agent's job, STOP and redirect

## Prerequisites & display
- Claude Code v2.1.178+, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `teammateMode` in
  settings.json. Default is `"in-process"` since v2.1.179 - our fleet sets `"tmux"`
  explicitly for split panes (each teammate in its own pane; click to interact).
  Split panes need tmux or iTerm2 (`it2` CLI); not supported in VS Code terminal,
  Windows Terminal, or Ghostty.
- Navigation: Shift+Down cycles teammates (in-process) / click pane (tmux); Ctrl+T task
  list; Escape interrupts; Alt+Arrows move panes; prefix+z zooms.
- Launch: if not already in tmux, start with `./scripts/start.sh`.

## Plan approval mode
For risky L-mode tasks only: teammate plans read-only until the lead approves. Give the
lead explicit approval criteria (e.g. "only approve plans that include test coverage").
Skip for S/M - the plan IS the contract slice.
