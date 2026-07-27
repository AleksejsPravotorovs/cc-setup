# Last Deploy Snapshot
Generated: 2026-04-20T10:34:00Z
Branch: main
Commit: 1edbc79 fix(install): download research docs from research/design path

## Changes deployed
```
 install.ps1 | 6 +++---
 install.sh  | 6 +++---
 2 files changed, 6 insertions(+), 6 deletions(-)
```

## Build status
Skipped — no package.json (template/config repo).

## Context for next /prime
- **Installer 404 fixed:** both `install.sh` and `install.ps1` now download the 6 design research docs from `research/design/<doc>.md` (correct) instead of `.claude/research/<doc>.md` (stale path deleted during safeguard refactor). Opt-in frontend add-on no longer 404s.
- **Verified via curl:** `research/design/bold-design-principles.md` → 200; old path → 404.
- **Canonical protocol:** `AGENTS.md` (root), mirrored at `.claude/PROMPT_FREE_PROTOCOL.md`. Rule 1 enforced: snapshot written via Bash heredoc (never Write/Edit on `.claude/**`).
- **Entry points:** `install.sh` / `install.ps1` (one-liner bootstrap) → `scripts/setup.sh` → auto-applies safeguard protocol. `scripts/update.sh` (`pp-update`) does the same on refresh.
- **Users with broken half-install from the 404:** just re-run the one-liner (or `pp-update`); idempotent — skips existing files, finishes the missing ones.
- **Recent commits:**
  1edbc79 fix(install): download research docs from research/design path
  4295db8 feat(setup): auto-apply safeguard protocol on first-time setup
  59ad3d5 docs: document safeguard protocol + make pp-update self-sufficient
  1d7f7fd fix(self-edit-safeguard): redirect skills + update scripts away from .claude/research
  86273fd fix: add self-edit-safeguard protection layer (v2)
- **Follow-up:** none blocking. `research/design/*.md` now fully served by installers.
- **Untracked (don't commit):** `.DS_Store`, `package-lock.json` (orphaned — no package.json exists).

---

## 2026-07-27 – Windows installer: native-stderr + sudo root causes fixed

**HEAD:** `5bcf699` on `main`
**Live:** https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.ps1 (one-liner bootstrap)

### Shipped
- `$ErrorActionPreference = "Stop"` + native stderr = terminating NativeCommandError in
  PowerShell 5.1. `2>$null` does NOT suppress it. Killed setup.ps1 at
  `code --install-extension` (node DEP0169) and silently aborted every WSL
  apt/locale/npm step (failures eaten by bare `catch {}`).
  Fix: `Invoke-Native` / `Invoke-NativeInteractive` / `Get-NativeOutput` helpers in
  setup.ps1, start.ps1, update.ps1; preference relaxed at the install.ps1 handoff.
- `sudo` inside `wsl bash -c` blocks on an unanswerable password prompt -> all WSL
  provisioning now runs `wsl -u root bash -c`. Locale exports still written to the
  DEFAULT user's dotfiles (root's ~ is /root).
- setup.ps1:461 called `Ensure-WSLLocale` unassigned -> printed a bare `False`.
- "Pre-flight passed" no longer prints when tmux / locale / Claude are unresolved.
- update.ps1 reported a SUCCESSFUL `git pull` as failed (git progress goes to stderr).
- WSL probes needing PATH use `bash -lc`; exact-output probes stay on `bash -c`.
- Failure-path copy-paste hints switched from `sudo` to `wsl -u root` (commit 5bcf699).

### Verification status
- Verified: `bash -n` on all 5 WSL here-string fragments -> OK.
- Verified: commit-pinned raw fetch of scripts/setup.ps1 -> 0 live `sudo` lines, 8x `wsl -u root`.
- EDITED-UNVERIFIED: the PowerShell side. No pwsh/powershell runtime on the macOS dev host.
  Windows check: `$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\setup.ps1),[ref]$null,[ref]$e); $e`

### Open backlog
- setup.ps1 parses `wsl --list --quiet`, whose output is UTF-16LE; the match works by
  accident and can misreport distros.
- fix-profile.ps1 was NOT audited for the same native-stderr class.

### What was NOT touched
- All `.sh` scripts (setup.sh / start.sh / stop.sh) - the bug is PowerShell-specific.
- Agent roster, skills, guardrails kit, model routing.
