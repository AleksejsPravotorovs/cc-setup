#Requires -Version 5.1
# +==================================================================+
# |  Claude Code -- Session Launcher (Windows)                       |
# |  Launches Claude inside tmux (via WSL) for split-pane agent      |
# |  teams. Teammates auto-appear as tmux panes.                     |
# +==================================================================+

$ErrorActionPreference = "Stop"

# ScriptDir = where start.ps1 lives (cc-setup repo)
# WorkDir   = where the user wants to work — defaults to current directory (e.g. folder open in VS Code)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ($args.Count -gt 0 -and (Test-Path $args[0] -PathType Container)) {
    $WorkDir = (Resolve-Path $args[0]).Path
} else {
    $WorkDir = (Get-Location).Path
}
Set-Location $WorkDir

$SessionName = (Split-Path -Leaf $WorkDir).ToLower() -replace '[.\s]', '-'

# --- Helpers: native + WSL command execution ----------------------
# $ErrorActionPreference = "Stop" (above) makes PowerShell 5.1 promote ANY line a
# native command writes to stderr into a *terminating* NativeCommandError -- even a
# harmless one (apt-get notices, node deprecation warnings). `2>$null` does NOT
# prevent it. Every external command goes through these helpers instead.
#
# The scriptblock parameter is named $NativeCall, NOT $Command: a scriptblock's
# variables resolve against the RUNTIME scope chain when it is invoked, not where it
# was written. A helper parameter sharing a name with a variable inside the caller's
# scriptblock silently shadows it -- that is how `{ wsl bash -c $Command }` ended up
# handing its own serialized source to wsl.exe. Keep this name unique.

function Invoke-Native {
    param([Parameter(Mandatory = $true)][scriptblock]$NativeCall)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        & $NativeCall 2>&1 | ForEach-Object { "$_" }
    } finally {
        $script:ErrorActionPreference = $prev
    }
}

# For commands that must keep the console (prompts, tmux) -- no redirection.
function Invoke-NativeInteractive {
    param([Parameter(Mandatory = $true)][scriptblock]$NativeCall)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try { & $NativeCall } finally { $script:ErrorActionPreference = $prev }
}

# WSL calls take an ARGUMENT ARRAY, never a scriptblock: the args are evaluated here
# and splatted straight to wsl.exe, so no deferred variable resolution can be shadowed.
function Invoke-WslCapture {
    param([Parameter(Mandatory = $true)][string[]]$WslArgv)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $lines = & wsl.exe @WslArgv 2>&1 | ForEach-Object { "$_" }
        if ($null -eq $lines) { return "" }
        return (($lines -join "`n").Trim())
    } catch {
        return ""
    } finally {
        $script:ErrorActionPreference = $prev
    }
}

# Default user, non-login shell -- exact output for probes.
function Invoke-WSL {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("bash", "-c", $Script))
}

# Default user, login shell -- use where PATH must be complete (npm global bin).
function Invoke-WSLLogin {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("bash", "-lc", $Script))
}

# Root, for provisioning. `sudo` inside `wsl bash -c` blocks on a password prompt
# this script cannot answer, so apt-get / locale-gen / npm never actually ran.
function Invoke-WSLRoot {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("-u", "root", "bash", "-c", $Script))
}

function Test-AptNetworkFailure {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$AptOutput)
    return ($AptOutput -match "Temporary failure resolving|Could not resolve|Failed to fetch")
}

function Show-WSLNetworkHint {
    Write-Host "[!!] WSL cannot reach the Ubuntu archives -- a WSL DNS problem, not a missing package." -ForegroundColor Yellow
    Write-Host "     Fix DNS inside WSL, then re-run 'pp'. Run these three, in order:" -ForegroundColor Cyan
    # Here-string: every character is literal, so the quoting the user must retype is
    # exactly what they see. Do not rewrite these as interpolated strings.
    $hint = @'
     wsl -u root bash -c "printf '[network]\ngenerateResolvConf=false\n' > /etc/wsl.conf"
     wsl --shutdown
     wsl -u root bash -c "printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf"
'@
    foreach ($line in ($hint -split "`n")) { Write-Host $line.TrimEnd() -ForegroundColor White }
}

# --- Fallback: run Claude natively on Windows ---------------------
# tmux only buys split panes. Claude Code runs natively on Windows with in-process
# teammates (Shift+Down to cycle), so a broken WSL must never block the session.

function Start-NativeClaude {
    param([Parameter(Mandatory = $true)][string]$Reason)

    Write-Host ""
    Write-Host "[i] $Reason" -ForegroundColor Yellow
    Write-Host "[i] Falling back to native Windows mode -- teammates run in-process." -ForegroundColor Cyan
    Write-Host "    Shift+Down cycles teammates, Ctrl+T shows the task list." -ForegroundColor White
    Write-Host ""

    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "[X] Claude CLI is not installed on Windows either." -ForegroundColor Red
        Write-Host "    Install: npm install -g @anthropic-ai/claude-code" -ForegroundColor White
        Write-Host "    Or re-run: .\scripts\setup.ps1" -ForegroundColor White
        exit 1
    }

    # Split panes need tmux; without it, teammateMode must be in-process or teammates
    # have nowhere to appear. Project settings override user settings, so writing the
    # project file is enough -- and it must EXIST, or a user-level "tmux" still wins.
    $settingsDir  = Join-Path $WorkDir ".claude"
    $settingsPath = Join-Path $settingsDir "settings.json"
    if (Test-Path $settingsPath) {
        $settingsText = [System.IO.File]::ReadAllText($settingsPath)
        if ($settingsText -match '"teammateMode"\s*:\s*"tmux"') {
            $patched = $settingsText -replace '"teammateMode"\s*:\s*"tmux"', '"teammateMode": "in-process"'
            [System.IO.File]::WriteAllText($settingsPath, $patched, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "[i] Set teammateMode to 'in-process' in .claude\settings.json (was 'tmux')." -ForegroundColor Cyan
        }
    } else {
        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
        $minimal = @'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "in-process"
}
'@
        [System.IO.File]::WriteAllText($settingsPath, $minimal, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "[i] Created .claude\settings.json with teammateMode 'in-process'." -ForegroundColor Cyan
    }

    $env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
    Invoke-NativeInteractive { claude }
    exit $LASTEXITCODE
}

# --- Pre-flight: WSL, tmux, Claude-in-WSL (all optional) ----------
# Each probe can only downgrade to the native fallback -- never dead-end.

$distroCheck = Invoke-WslCapture @("echo", "ok")

if ($distroCheck -ne "ok") {
    Write-Host "[!!] WSL has no working Linux distribution" -ForegroundColor Yellow
    Write-Host ""
    $installWsl = Read-Host "    Install Ubuntu now? Takes a few minutes; you'll create a Unix user (y/n)"
    if ($installWsl -eq "y") {
        Write-Host ""
        # Interactive (user creates username/password): unredirected on purpose.
        Invoke-NativeInteractive { wsl --install -d Ubuntu }
        Write-Host ""
        Write-Host "[i] Ubuntu installed. Re-run 'pp' to use split-pane mode." -ForegroundColor Cyan
        exit 0
    }
    Start-NativeClaude "WSL has no working distro."
}

# tmux: probe FIRST and only install when genuinely missing. A machine with tmux
# already present must never be blocked by an unreachable apt mirror.
$tmuxCheck = Invoke-WSLLogin "command -v tmux"
if ($tmuxCheck -notmatch "tmux") {
    Write-Host "[i] tmux not found in WSL -- installing..." -ForegroundColor Cyan
    # `;` not `&&`: a failing `apt-get update` (no DNS) must not block an install
    # that cached package lists can still satisfy.
    $aptOut = Invoke-WSLRoot "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y tmux"
    $aptOut | Out-Host
    $tmuxCheck = Invoke-WSLLogin "command -v tmux"
    if ($tmuxCheck -notmatch "tmux") {
        if (Test-AptNetworkFailure $aptOut) { Show-WSLNetworkHint }
        Start-NativeClaude "tmux could not be installed in WSL."
    }
}

# --- Pre-flight: UTF-8 locale in WSL (Cyrillic support) -----------

$localeCheck = Invoke-WSL "locale 2>/dev/null | head -1"
if ($localeCheck -notmatch "UTF-8") {
    Write-Host "[!!] WSL locale is not UTF-8 -- Cyrillic characters will break" -ForegroundColor Yellow
    Write-Host "[i] Installing UTF-8 locale in WSL..." -ForegroundColor Cyan
    # Root, not sudo: a sudo password prompt here cannot be answered.
    # Single quotes only -- embedded double quotes do not survive PowerShell's
    # native-argument quoting on the way to wsl.exe.
    $localeScript = @'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y locales
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 ru_RU.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
'@
    $localeOut = Invoke-WSLRoot $localeScript
    $localeOut | Out-Host

    # Verify instead of announcing success unconditionally.
    $charmap = Invoke-WSL "LANG=en_US.UTF-8 locale charmap 2>/dev/null"
    if ($charmap -eq "UTF-8") {
        Write-Host "[OK] UTF-8 locale installed (Cyrillic supported)" -ForegroundColor Green
    } else {
        Write-Host "[!!] UTF-8 locale still not active -- Cyrillic text may break" -ForegroundColor Yellow
        if (Test-AptNetworkFailure $localeOut) { Show-WSLNetworkHint }
    }
}

# --- Pre-flight: Claude CLI in WSL --------------------------------

$claudeVer = Invoke-WSLLogin "claude --version 2>/dev/null | head -1"
if ($claudeVer -notmatch "\d+\.\d+") {
    Write-Host "[i] Claude CLI not working in WSL -- installing..." -ForegroundColor Cyan

    # Ensure Node.js (as root -- sudo would block on a password prompt)
    $nodeCheck = Invoke-WSLLogin "command -v node"
    if ($nodeCheck -notmatch "node") {
        Write-Host "[i] Installing Node.js in WSL..." -ForegroundColor Cyan
        $nodeScript = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
'@
        $nodeOut = Invoke-WSLRoot $nodeScript
        $nodeOut | Out-Host
        if (Test-AptNetworkFailure $nodeOut) { Show-WSLNetworkHint }
    }

    Invoke-WSLRoot "npm install -g @anthropic-ai/claude-code" | Out-Host

    # Verify it actually runs
    $claudeVer = Invoke-WSLLogin "claude --version 2>/dev/null | head -1"
    if ($claudeVer -notmatch "\d+\.\d+") {
        Start-NativeClaude "Claude CLI could not be installed inside WSL."
    }
}
Write-Host "[OK] Claude CLI in WSL: $claudeVer" -ForegroundColor Green

# --- Convert Windows path to WSL path -----------------------------

# Convert Windows path to WSL path in PowerShell (avoids encoding issues with wslpath)
$wslPath = $WorkDir -replace '\\', '/'
if ($wslPath -match '^([A-Za-z]):(.*)') {
    $drive = $Matches[1].ToLower()
    $rest = $Matches[2]
    $wslPath = "/mnt/$drive$rest"
}

# If path contains non-ASCII (e.g. Cyrillic), create an ASCII-only NTFS junction
if ($wslPath -match '[^\x00-\x7F]') {
    $linkName = "claude-project-" + $SessionName
    $linkTarget = "$env:TEMP\$linkName"
    # Remove stale junction if it exists
    if (Test-Path $linkTarget) {
        Invoke-Native { cmd /c rmdir "$linkTarget" } | Out-Null
    }
    Invoke-Native { cmd /c mklink /J "$linkTarget" "$WorkDir" } | Out-Null
    if (Test-Path $linkTarget) {
        $juncDrive = $linkTarget.Substring(0, 1).ToLower()
        $wslPath = "/mnt/$juncDrive" + ($linkTarget.Substring(2) -replace '\\', '/')
        Write-Host "[i] Using ASCII junction for Cyrillic path: $linkTarget" -ForegroundColor Cyan
    } else {
        Write-Host "[!!] Could not create junction for Cyrillic path -- WSL may fail with non-ASCII paths" -ForegroundColor Yellow
    }
}

# --- Launch Claude in tmux via WSL --------------------------------

Write-Host ""
Write-Host "+----------------------------------------------+" -ForegroundColor Cyan
Write-Host "|  Claude Code -- tmux split-pane mode          |" -ForegroundColor Cyan
Write-Host "|                                              |" -ForegroundColor Cyan
Write-Host "|  Agent teammates auto-appear as tmux panes   |" -ForegroundColor Cyan
Write-Host "|  Alt+Arrow     Navigate between panes        |" -ForegroundColor Cyan
Write-Host "|  Mouse         Click pane to focus            |" -ForegroundColor Cyan
Write-Host "|  Prefix + z    Zoom/unzoom pane              |" -ForegroundColor Cyan
Write-Host "+----------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# Kill previous session if exists, then create new tmux session with Claude
# The tmux session runs inside WSL with access to the project via /mnt/
# Verify the path works
$pathCheck = Invoke-WSL "test -d '$wslPath' && echo ok"
if ($pathCheck -ne "ok") {
    Write-Host "[X] WSL cannot access project path: $wslPath" -ForegroundColor Red
    Start-NativeClaude "WSL cannot reach this project path (is it on a Windows drive?)."
}

# Launch tmux -- if claude crashes, keep the pane open to show the error
$tmuxCmd = @"
cd '$wslPath' && \
export LANG=en_US.UTF-8 && \
export LC_ALL=en_US.UTF-8 && \
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 && \
tmux kill-session -t '$SessionName' 2>/dev/null; \
tmux -u new-session -s '$SessionName' -c '$wslPath' \
  'claude; echo; echo \"[Claude exited. Press Enter to close.]\"; read'
"@

# Interactive: no redirection, so tmux keeps the console. Only the error
# preference is relaxed, so a stderr line from claude cannot kill the launcher.
Invoke-NativeInteractive { wsl bash -c $tmuxCmd }
