---
description: Commit, deploy, verify, and snapshot session state for next prime
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# /deploy – Commit & Deploy

**Model routing v2:** /deploy runs inline. If a helper agent is spawned: code verification / build debugging -> `model: "fable"`; snapshot/state-file template fill (steps 6-7) -> `model: "opus"` is fine.

## 1) Pre-flight (parallel)

Run all at once:
- `git status` – uncommitted changes?
- `git remote -v` – remote configured?
- `git branch --show-current` – current branch?
- Glob `.vercel/project.json` OR `netlify.toml` – hosting connected?
**If no remote**: STOP – "No git remote."
**If no changes**: Ask – "Working tree clean. Force deploy? (y/n)"

## 2) Build gate

```bash
npm run build
```

**If build fails**: STOP. Show error. Do NOT commit broken code.

## 3) Lint gate (if script exists)

```bash
npm run lint 2>&1 || true
```

Report warnings but don't block. Only block on errors.

## 4) Commit

Analyze changes with `git diff --stat` and `git status`.

Stage changed files (specific files, NOT `git add -A`):
- Stage source code changes
- Stage `.claude/commands/` if modified
- Stage `CLAUDE.md` if modified
- Do NOT stage `.env*`, credentials

Conventional commit message:
- Format: `type(scope): description`
- Types: feat, fix, chore, refactor, style, docs
- Keep subject under 72 chars

## 5) Push

```bash
git push origin <current-branch>
```

## 6) Session snapshot (local, full history)

Append a dated entry to `.claude/snapshots/last-deploy.md` **via Bash heredoc** (the path is protected – see `.claude/PROMPT_FREE_PROTOCOL.md`, Rule 1).

Append-only (never overwrite – the file is the long-term deploy log). Use this shape:

```markdown
---

## YYYY-MM-DD – [one-line summary]

**HEAD:** `<hash>` on `<branch>`
**Live:** <url or N/A>

### Shipped
[2–5 bullets on what changed]

### Open backlog
[items carried forward, if any]

### What was NOT touched
[paths/systems unchanged, if notable]
```

## 7) Obsidian project-state file (token-lean, for /prime)

Write a compact state file to the Obsidian vault. **This is what the next `/prime` will read first** – keep it ≤40 lines.

```bash
VAULT="$HOME/Desktop/My AI Knowledge Base"
CWD="$(pwd)"
NOTE=$(grep -rl "local_path: $CWD$" "$VAULT/Projects" 2>/dev/null | head -1)
if [ -n "$NOTE" ]; then
  SLUG=$(basename "$NOTE" .md)
  STATE_FILE="$VAULT/Projects/${SLUG}-state.md"
  # Overwrite with compact current state – /prime reads this as its primary source
  cat > "$STATE_FILE" <<EOF
---
title: ${SLUG} – current state
source: /deploy
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
branch: <BRANCH>
head: <SHORT_HASH>
---

# ${SLUG} – Current state

**Live:** <LIVE_URL or N/A>
**Build:** <pass/fail>
**Routes / output:** <if relevant – e.g., "288 prerendered HTML">

## Recently shipped (this deploy)
- <commit subject / 1–3 bullets on what changed>

## Open backlog (top 5, most actionable first)
- <item>
- <item>

## Lock (don't touch without reason)
- <paths or systems>

## Follow-ups / user TODOs
- <item or "–">
EOF
  echo "State file: $STATE_FILE"
else
  echo "State file: no matching project note in vault – skipping."
fi
```

Fill the `<PLACEHOLDERS>` with real values from the deploy before writing. The file is OVERWRITTEN every deploy (not appended – it's a live snapshot, not a log).

If the vault is missing or the project has no Obsidian note: log one line and continue – never fail the deploy.

## 7b) Refresh `OWNER-ACTIONS.md` (the owner's step-by-step action list)

**Standing user instruction (2026-07-27), verbatim:** "From now on, whatever is
required via my attention, I want you to set up a document for me that I could
use as a step-by-step guide of what I need to do in order to fix or resolve any
situation that needs my attention."

`OWNER-ACTIONS.md` at the repo ROOT is that document. Root is a Write-safe path -
use `Write`/`Edit`, not a heredoc.

Every deploy, reconcile it against what this session actually changed:

1. **Remove** items the owner completed (they said so, or you verified it). A
   finished item leaves the file - do not build an archive section.
2. **Add** every NEW item this session created that only the owner can do:
   hand-applied migrations, third-party account steps (Stripe/Resend/Sentry/DNS),
   decisions you deliberately refused to make for them, credentials, and anything
   you wrote into the snapshot as "OWNER" or "QUESTION FOR THE OWNER".
3. **Update** the `Updated:` line (date + commit) and the status-at-a-glance table.
4. Keep the register: plain English, click-by-click, exact values, zero repo
   jargon. Each item states Why / Steps / Done when / Then tell me. The owner must
   be able to act without opening any other file.
5. Deploy produced NO owner-facing change? Say so in the report and leave the file
   alone. Do not churn it.

Why this step exists: `LAUNCH-ACTION-REQUIRED.html` (2026-05-18) was a one-off
owner to-do that nobody regenerated. It sat two months stale while its contents
drifted into four other files.## 8) Output report

```
Deploy Complete
═══════════════
Commit:   [hash] [message]
Branch:   [branch] → origin/[branch]
Build:    [pass/fail]
Snapshot: .claude/snapshots/last-deploy.md (appended)
State:    <VAULT>/Projects/<slug>-state.md (overwritten)  [or "skipped"]
Owner:    OWNER-ACTIONS.md (<n> open items)  [or "unchanged - nothing new for the owner"]

Next prime will auto-load the vault state file for context.
```

## 9) Save to Obsidian wiki (cross-project knowledge base)

After the state file is written and the deploy report is printed, invoke the `/claude-obsidian:save` skill to file a human-readable deploy summary into the shared vault for cross-project queries.

Call it as:

```
/claude-obsidian:save [project-slug] – [commit-subject] ([YYYY-MM-DD])
```

Example: `/claude-obsidian:save techaccounting – nav merge PR #20 (2026-04-24)`

The note should include:
- Project / repo name
- Branch + commit hash
- One-paragraph summary of what shipped (pulled from the snapshot)
- Follow-up / backlog items (copied from snapshot)
- Link to production URL

**Fail-safe**: if the vault is missing, Obsidian plugin not installed, or the save skill errors, log a single-line warning and continue – never fail the deploy on a save error. Cross-project retrieval in future sessions uses `/claude-obsidian:wiki-query` (aliases: "query: …", "what do you know about …", "based on the wiki …").
