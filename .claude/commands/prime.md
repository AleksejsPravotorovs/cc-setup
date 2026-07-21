---
description: Fast lean prime – repo state + snapshot + vault state in one pass, then work
allowed-tools: Read, Glob, Bash
---

# /prime – Fast Lean Prime

Load just enough to start working, in ONE pass, target under ~30s. CLAUDE.md is
already in context: do NOT re-read it or any style/token files. Do not assume a
stack (Next.js/src) – confirm it from the file listing below.

## Run this single Bash block, then read at most ONE file, then STOP

```bash
echo "== recent commits (latest updates) =="
git log --oneline -8 2>/dev/null
echo "== uncommitted =="
git status --short 2>/dev/null | head -40
echo "== top-level layout =="
ls -1 2>/dev/null
echo "== last snapshot entry =="
SNAP=".claude/snapshots/last-deploy.md"
[ -f "$SNAP" ] && awk 'BEGIN{buf=""} /^---$/{buf=""; next} {buf=buf $0 "\n"} END{printf "%s", buf}' "$SNAP"
echo "== My AI Knowledge Base state file =="
VAULT="${OBSIDIAN_VAULT:-$HOME/Desktop/My AI Knowledge Base}"
NOTE=$(grep -rl "local_path: $(pwd)$" "$VAULT/Projects" 2>/dev/null | head -1)
[ -n "$NOTE" ] && echo "STATE=$VAULT/Projects/$(basename "$NOTE" .md)-state.md" || echo "STATE=(none)"
echo "== LAUNCH PLAN (this repo, if present) =="
PLAN="LAUNCH-PLAN.md"
if [ -f "$PLAN" ]; then
  PTOTAL=$(grep -cE '^- \[[ xX]\] \*\*P' "$PLAN" 2>/dev/null || true)
  PDONE=$(grep -cE '^- \[[xX]\] \*\*P' "$PLAN" 2>/dev/null || true)
  NPEND=$(grep -cE '^- \[ \] \*\*N' "$PLAN" 2>/dev/null || true)
  echo "Progress: ${PDONE}/${PTOTAL} P-steps done · ${NPEND} external (N) tasks still open"
  echo "-- next unchecked P-step --"
  grep -nE '^- \[ \] \*\*P' "$PLAN" 2>/dev/null | head -1 || echo "(all P-steps checked – plan complete)"
  echo ">> STRICT PLAN MODE: the task IS the next unchecked P-step. Read it in LAUNCH-PLAN.md, run its prompt, verify, then mark it [x]. Do NOT skip ahead or improvise."
else
  echo "(no LAUNCH-PLAN.md – normal prime)"
fi
```

If a `STATE=<path>` is printed and the file exists, Read that ONE file – it is the
compact (<=40 line) project state written by /deploy and is the only vault read
needed. That IS the "info from My AI Knowledge Base".

## Strict plan mode (only when LAUNCH-PLAN.md exists in this repo)

If the Bash block printed a `next unchecked P-step`, this repo is on a launch plan.
After the report, do NOT ask "what do you want to work on?" – the task is fixed:
open `LAUNCH-PLAN.md`, execute the NEXT unchecked P-step exactly (each step is a
self-contained prompt), then mark that line `[x]`. Follow the plan order and the
"Зависит от" dependencies; only deviate if the user explicitly overrides. External
`N` tasks (N1–N5) are human/parallel – surface them but do not try to "do" them in code.

## Removed on purpose (the slow, redundant second pass)
Do NOT: read the full Obsidian project NOTE or its Related/Skills/Vault-knowledge
sections, tail the vault activity log, run MCP verification, or glob for
src/app | src/components. Those were the second stage that slowed prime with no
payoff – the snapshot + state file already carry the context.

## Report (3 lines, +1 if on a launch plan) then STOP and wait for the task
```
State: <branch> @ <hash> · <N> uncommitted · stack: <from ls>
Last session: <1-2 lines – what shipped + what is next, from snapshot/STATE>
Plan: <done>/<total> P-steps · next: <P-id + title> · <k> external (N) pending   [only if LAUNCH-PLAN.md]
Ready – <next P-step prompt is queued> / <what do you want to work on? if no plan>
```
No Goal/Plan/Lock template at prime time – that is per-task, after you have the task.

## Rules (always active)
- Ship the smallest correct change; LOCK & PATCH; give exact paths/patches/commands.
- Ask only truly blocking questions; otherwise state assumptions and proceed.
- No new deps / no global tooling changes / no rewrites unless asked.
- Model routing v2: subagents doing code work spawn with `model: "fable"`; pure template-fill text may use `model: "opus"`. When torn -> fable.
