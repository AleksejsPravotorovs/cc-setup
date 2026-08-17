---
description: Fast lean prime - repo state + vault state + cc-setup freshness in ONE bash call, then work
allowed-tools: Read, Glob, Bash
---

# /prime - Fast Lean Prime (30s hard budget)

ONE Bash call, ZERO follow-up reads, then a 3-4 line report. CLAUDE.md is already
in context: do NOT re-read it, any style/token file, the full snapshot, or the
Obsidian note. The state file is cat'ed INSIDE the bash block - never Read it as
a second tool call.

## Run this single Bash block - it is the ENTIRE prime

```bash
echo "== repo =="
git log --oneline -5 2>/dev/null
echo "uncommitted: $(git status --short 2>/dev/null | wc -l | tr -d ' ') files"
echo "== cc-setup freshness (auto-updates when stale) =="
CCU="${CC_SETUP_DIR:-$HOME/Downloads/cc-setup}/scripts/cc-update.sh"
if [ -x "$CCU" ]; then
  "$CCU" --check; CCRC=$?
  [ "$CCRC" = "3" ] && bash "$CCU" --apply --quiet && echo "cc-update: applied"
else
  echo "cc-setup: cc-update.sh not installed (run pp-update to get it)"
fi
echo "== state file (authoritative; <=40 lines by /deploy contract) =="
VAULT="${OBSIDIAN_VAULT:-$HOME/Desktop/My AI Knowledge Base}"
NOTE=$(grep -rl "local_path: $(pwd)$" "$VAULT/Projects" 2>/dev/null | head -1)
STATE=""
[ -n "$NOTE" ] && STATE="$VAULT/Projects/$(basename "$NOTE" .md)-state.md"
if [ -n "$STATE" ] && [ -f "$STATE" ]; then
  head -60 "$STATE"
else
  echo "(no state file - fallback: snapshot tail, capped)"
  SNAP=".claude/snapshots/last-deploy.md"
  [ -f "$SNAP" ] && tail -40 "$SNAP"
fi
echo "== LAUNCH PLAN (if present) =="
PLAN="LAUNCH-PLAN.md"
if [ -f "$PLAN" ]; then
  PTOTAL=$(grep -cE '^- \[[ xX]\] \*\*P' "$PLAN" 2>/dev/null || true)
  PDONE=$(grep -cE '^- \[[xX]\] \*\*P' "$PLAN" 2>/dev/null || true)
  NPEND=$(grep -cE '^- \[ \] \*\*N' "$PLAN" 2>/dev/null || true)
  echo "Progress: ${PDONE}/${PTOTAL} P-steps done, ${NPEND} external (N) open"
  grep -nE '^- \[ \] \*\*P' "$PLAN" 2>/dev/null | head -1 || echo "(all P-steps checked)"
else
  echo "(no LAUNCH-PLAN.md - normal prime)"
fi
```

## Rules for interpreting the output (no extra tool calls)

- The STATE FILE is the single source of last-session context. It supersedes the
  snapshot; never open both.
- cc-setup gate: `cc-update.sh --check` exits 0 = fresh (or throttled, it only hits
  the network every 6h), 3 = behind origin/main and the block already auto-applied
  the update, 4 = offline / not a clone (ignore, never block on it). If it printed
  "cc-update: applied", say so in one clause and carry on - do NOT re-verify, and do
  NOT spend a second tool call on it.
- Strict plan mode: if a "next unchecked P-step" printed, that IS the task.
  Honor any OWNER OVERRIDE recorded inside the step line or the state file
  (overrides route to a different step - follow them). Report, then IMMEDIATELY
  start executing the resolved step: open LAUNCH-PLAN.md at that step ONLY (grep
  its line range - not the whole file), run its prompt, verify, mark [x]. Do not
  ask "what do you want to work on?".
- No LAUNCH-PLAN.md: report and ask for the task in one line.
- The stack comes from CLAUDE.md GROUND TRUTH already in context - do not ls or
  glob to "confirm" it at prime time.

## Report (3-4 lines, then act)

```
State: <branch> @ <short-hash> - <N> uncommitted<, cc-setup updated if it was>
Last: <1 line - what shipped + what is next, from the state file>
Plan: <done>/<total> P - next: <P-id> <(overridden -> P-x.y if so)> - <k> N open
<Executing P-x.y ... | What do you want to work on?>
```

## Hard budget

Prime = 1 Bash call + report. Anything more (second read, snapshot + state file
both, MCP checks, vault note, src globbing) is a violation of this command.
Per-task guardrails (PLAN/CODE docs, TASK block) belong to the TASK, after prime.

## Rules (always active)
- Ship the smallest correct change; LOCK & PATCH; exact paths/patches/commands.
- Ask only truly blocking questions; otherwise state assumptions and proceed.
- No new deps / no global tooling changes / no rewrites unless asked.
- Model policy opus-first: every `Agent(...)` spawn passes `model: "opus"` - code and
  text alike; `model: "sonnet"` for trivial text-only work. `fable` is retired - never spawn it. Never a dated id.
- Multi-agent work runs the coordinator doctrine (AGENTS.md): blank-slate subagents,
  brief-is-the-only-channel, hub-and-spoke, `decomposition.md` before the first spawn.
