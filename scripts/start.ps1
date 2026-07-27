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

function Invoke-Native {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        & $Command 2>&1 | ForEach-Object { "$_" }
    } finally {
        $script:ErrorActionPreference = $prev
    }
}

# For commands that must keep the console (prompts, tmux) -- no redirection.
function Invoke-NativeInteractive {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try { & $Command } finally { $script:ErrorActionPreference = $prev }
}

function Get-NativeOutput {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    try {
        $lines = Invoke-Native $Command
        if ($null -eq $lines) { return "" }
        return (($lines -join "`n").Trim())
    } catch {
        return ""
    }
}

# Default user, non-login shell -- exact output for probes.
function Invoke-WSL {
    param([Parameter(Mandatory = $true)][string]$Command)
    return (Get-NativeOutput { wsl bash -c $Command })
}

# Default user, login shell -- use where PATH must be complete (npm global bin).
function Invoke-WSLLogin {
    param([Parameter(Mandatory = $true)][string]$Command)
    return (Get-NativeOutput { wsl bash -lc $Command })
}

# Root, for provisioning. `sudo` inside `wsl bash -c` blocks on a password prompt
# this script cannot answer, so apt-get / locale-gen / npm never actually ran.
function Invoke-WSLRoot {
    param([Parameter(Mandatory = $true)][string]$Command)
    return (Get-NativeOutput { wsl -u root bash -c $Command })
}

# --- Pre-flight: WSL with a distro --------------------------------

# Check WSL has a working distro
$distroCheck = Get-NativeOutput { wsl echo "ok" }

if ($distroCheck -ne "ok") {
    Write-Host "[!!] WSL has no Linux distribution installed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Installing Ubuntu (this takes a few minutes)..." -ForegroundColor Cyan
    Write-Host "    You will be asked to create a Unix username and password." -ForegroundColor Cyan
    Write-Host ""

    # Install Ubuntu -- this is interactive (user creates username/password),
    # so it runs unredirected; only the error preference is relaxed.
    Invoke-NativeInteractive { wsl --install -d Ubuntu }

    Write-Host ""
    Write-Host "[i] Ubuntu installed. Re-run 'pp' or '.\scripts\start.ps1' to continue." -ForegroundColor Cyan
    exit 0
}

# --- Pre-flight: tmux in WSL -------------------------------------

$tmuxCheck = Invoke-WSLLogin "command -v tmux"
if ($tmuxCheck -notmatch "tmux") {
    Write-Host "[i] Installing tmux in WSL..." -ForegroundColor Cyan
    Invoke-WSLRoot "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y tmux" | Out-Host
    $tmuxCheck = Invoke-WSLLogin "command -v tmux"
    if ($tmuxCheck -notmatch "tmux") {
        Write-Host "[X] tmux installation failed in WSL" -ForegroundColor Red
        Write-Host "    Try manually: wsl -u root bash -c 'apt-get update && apt-get install -y tmux'" -ForegroundColor White
        exit 1
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
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y locales
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 ru_RU.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
'@
    Invoke-WSLRoot $localeScript | Out-Host

    # Verify instead of announcing success unconditionally.
    $charmap = Invoke-WSL "LANG=en_US.UTF-8 locale charmap 2>/dev/null"
    if ($charmap -eq "UTF-8") {
        Write-Host "[OK] UTF-8 locale installed (Cyrillic supported)" -ForegroundColor Green
    } else {
        Write-Host "[!!] UTF-8 locale still not active -- Cyrillic text may break" -ForegroundColor Yellow
        Write-Host "    Fix: wsl -u root bash -c 'apt-get install -y locales && locale-gen en_US.UTF-8 ru_RU.UTF-8'" -ForegroundColor White
        Write-Host "    Then: wsl --shutdown" -ForegroundColor White
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
apt-get update -qq
apt-get install -y curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
'@
        Invoke-WSLRoot $nodeScript | Out-Host
    }

    Invoke-WSLRoot "npm install -g @anthropic-ai/claude-code" | Out-Host

    # Verify it actually runs
    $claudeVer = Invoke-WSLLogin "claude --version 2>/dev/null | head -1"
    if ($claudeVer -notmatch "\d+\.\d+") {
        Write-Host "[X] Claude CLI installation failed in WSL" -ForegroundColor Red
        Write-Host "    Try manually: wsl -u root bash -c 'npm install -g @anthropic-ai/claude-code'" -ForegroundColor White
        exit 1
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
    Write-Host "    Make sure your project is on a Windows drive (C:, D:, etc.)" -ForegroundColor White
    exit 1
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
