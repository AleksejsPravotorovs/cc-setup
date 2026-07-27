# STATE

## Goal
Fix the Windows installer path (`install.ps1` -> `scripts/setup.ps1` -> `scripts/start.ps1`)
so a fresh Windows + WSL machine completes setup without aborting.

## Now
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

Status: all four scripts edited (setup.ps1, start.ps1, update.ps1, install.ps1).
NOT pushed — the colleague's `install.ps1` / `pp-update` fetch from GitHub main, so the
fix only reaches them after an explicit push.

## Next
Verify on Windows (no PowerShell runtime on the macOS dev host):
`powershell -NoProfile -Command "$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\setup.ps1),[ref]$null,[ref]$e);$e"`
then re-run `.\scripts\setup.ps1`.

## Constraints
(none recorded)

## Open items
- NOTED (not done): `setup.ps1:268` parses `wsl --list --quiet`, whose output is UTF-16LE;
  the string match works by accident and can misreport distros on some systems.
- NOTED (not done): `setup.ps1:462` captures `$claudeWslOk` but never checks it, so
  "Pre-flight passed" prints even after the WSL Claude install fails.

## Failed attempts
(none)
