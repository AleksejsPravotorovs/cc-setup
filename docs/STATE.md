# STATE

## Goal
Fix the macOS installer path (`install.sh` -> `scripts/setup.sh`) so a fresh Mac
completes setup without aborting on the Claude CLI install.

## Now
2026-08-02, colleague's Mac (`/Users/aleksanderdanilov`), reported by the owner.
CAUSE: `scripts/setup.sh:447` ran `npm install -g @anthropic-ai/claude-code` as the ONLY
install method. His npm global prefix is the root-owned `/usr/local` (Node from the
nodejs.org `.pkg`; his Homebrew is elsewhere), so npm failed with
`EACCES ... mkdir '/usr/local/lib/node_modules/@anthropic-ai'` -> SYMPTOM at
`setup.sh:453` "installation failed" -> hard `exit 1` at `setup.sh:523`.
Anthropic's own docs warn against the obvious "fix" (`sudo npm install -g`).
Fix: `install_claude()` now tries, in order and never with sudo —
(1) `curl -fsSL https://claude.ai/install.sh | bash` (official, `~/.local/bin`, auto-updating),
(2) `brew install --cask claude-code`, (3) npm, and only when `npm_prefix_writable` says the
prefix is user-writable. `ensure_local_bin_on_path` puts `~/.local/bin` on PATH for the run
and once in the shell rc. Exhausting all three prints the three manual commands instead of
a bare failure.

## Previously (Windows round, 2026-07-27)
Repairing two root causes reported from a colleague's run on `F:\...\lincsite`:
1. `$ErrorActionPreference = "Stop"` + native commands writing to stderr -> PowerShell 5.1
   raises `NativeCommandError` as a *terminating* error. Killed the script at
   `setup.ps1:624` (`code --install-extension`, node DEP0169 warning). The same class
   silently defeated the WSL locale / node / claude installs, whose failures were
   swallowed by bare `catch {}`.
2. `sudo` inside `wsl bash -c "..."` blocks on a password prompt setup cannot answer ->
   apt-get / locale-gen / npm never ran. Fix: provision via `wsl -u root bash -c`.
Plus `setup.ps1:461` called `Ensure-WSLLocale` without capturing its return value, printing
a bare `False` to the console.

Round 2 (same session): the round-1 fix regressed — see `## Failed attempts`. WSL calls
now use argv arrays instead of scriptblocks, and `pp` degrades to native Windows Claude
(teammateMode `in-process`) instead of dead-ending when WSL/tmux/apt are unusable.
Field evidence: the colleague's WSL DNS is broken (`nameserver 172.28.112.1` unresolvable)
but tmux 3.6a-2 was ALREADY installed — the probe only "failed" through the broken helper.

## Next
- Commit + push `scripts/setup.sh` — the colleague pulls it from `main` via `install.sh`,
  so the fix does not reach him until it is pushed. NOT pushed yet (not requested).
- Still open from the Windows round: verify on Windows (no PowerShell runtime on this host)
  `powershell -NoProfile -Command "$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\setup.ps1),[ref]$null,[ref]$e);$e"`
  then re-run `.\scripts\setup.ps1`.

## Constraints
- "fix this in a way so that everything works" — `pp` must never dead-end a user who
  cannot reach apt; WSL/tmux is an enhancement, not a hard requirement.

## Open items
- NOTED (not done): `setup.ps1:314` / `start.ps1:248` / `SETUP-WINDOWS.md:130` still install
  Claude via npm only (`sudo npm install -g` in the doc). Same class as the macOS bug;
  Windows npm prefixes are usually user-writable, so it has not bitten yet.
- NOTED (not done): `setup.ps1:268` parses `wsl --list --quiet`, whose output is UTF-16LE;
  the string match works by accident and can misreport distros on some systems.
- NOTED (not done): `setup.ps1:462` captures `$claudeWslOk` but never checks it, so
  "Pre-flight passed" prints even after the WSL Claude install fails.

## Failed attempts
ATTEMPT 1 [L1]: commit 76a301d wrapped native calls in scriptblocks passed to
`Invoke-Native`/`Get-NativeOutput`, whose parameters are ALSO named `$Command`.
PowerShell resolves scriptblock variables against the runtime scope chain at
invocation, so `{ wsl -u root bash -c $Command }` bound `$Command` to the helper's
scriptblock parameter (itself), and wsl.exe got the serialized scriptblock source.
-> observed: `bash: line 0: bash: IAB3AHMAbAAg...: invalid option name`
   (base64/UTF-16LE decodes to " wsl -u root bash -c $Command ")
Fix (this turn): WSL helpers take a `[string[]]` argv and splat it to `wsl.exe`
directly -- no scriptblock, so no deferred variable resolution is possible. The
remaining scriptblock helpers use `$NativeCall`, a name no caller body references.
