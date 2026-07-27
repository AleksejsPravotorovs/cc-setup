#Requires -Version 5.1
# +==================================================================+
# |  Claude Code + Agent Teams Setup (Windows)                       |
# |  Equivalent of scripts/setup.sh for Windows / PowerShell         |
# |  Idempotent: safe to run multiple times.                          |
# +==================================================================+

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

# --- Logging helpers ----------------------------------------------

function Log($msg)  { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Info($msg) { Write-Host "  [ii] $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "  [XX] $msg" -ForegroundColor Red }

# --- Native command helpers ---------------------------------------
# $ErrorActionPreference = "Stop" (above) makes PowerShell 5.1 promote ANY line a
# native command writes to stderr into a *terminating* NativeCommandError -- even a
# harmless one (node's DEP0169 warning from `code`, apt-get notices, git progress).
# `2>$null` does NOT prevent it: the error record is created before the redirect.
# Every external command therefore goes through these helpers, which relax the
# preference for the duration of the call and turn stderr into plain text.
# Exit status stays in $LASTEXITCODE for the caller to check.

# The parameter is named $NativeCall, NOT $Command: a scriptblock's variables are
# resolved against the RUNTIME scope chain when it is invoked, not captured where it
# was written. A helper parameter sharing a name with a variable inside the caller's
# scriptblock silently shadows it -- that is how `{ wsl bash -c $Command }` ended up
# passing its own serialized source to wsl.exe. Keep this name unique.

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

# Same, but returns the combined output as one trimmed string and never throws.
function Get-NativeOutput {
    param([Parameter(Mandatory = $true)][scriptblock]$NativeCall)
    try {
        $lines = Invoke-Native $NativeCall
        if ($null -eq $lines) { return "" }
        return (($lines -join "`n").Trim())
    } catch {
        return ""
    }
}

# --- WSL execution ------------------------------------------------
# WSL calls take an ARGUMENT ARRAY, never a scriptblock: the args are evaluated here
# and splatted straight to wsl.exe, so there is no deferred variable resolution to
# get shadowed. Returns combined output as one trimmed string; never throws.

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

# Provision as root. `sudo` inside `wsl bash -c` blocks on a password prompt that
# setup cannot answer, so apt-get / locale-gen / npm never actually ran.
function Invoke-WSLRoot {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("-u", "root", "bash", "-c", $Script))
}

# Default user, NON-login shell: profile files stay unsourced, so the output is
# exactly what the command printed (used for exact-match probes).
function Invoke-WSLUser {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("bash", "-c", $Script))
}

# Default user, LOGIN shell -- needed only where PATH must be complete
# (npm's global bin lands on PATH via the profile files).
function Invoke-WSLLogin {
    param([Parameter(Mandatory = $true)][string]$Script)
    return (Invoke-WslCapture @("bash", "-lc", $Script))
}

# True when apt could not reach the archives (the common WSL DNS failure). Callers
# use this to explain the real problem instead of blaming the package.
function Test-AptNetworkFailure {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$AptOutput)
    return ($AptOutput -match "Temporary failure resolving|Could not resolve|Failed to fetch")
}

function Show-WSLNetworkHint {
    Warn "WSL cannot reach the Ubuntu archives -- this is a WSL DNS problem, not a missing package."
    Info "Fix DNS inside WSL, then retry. Run these three, in order:"
    # Here-string: every character is literal, so the quoting the user must retype
    # is exactly what they see. Do not rewrite these as interpolated strings.
    $hint = @'
    wsl -u root bash -c "printf '[network]\ngenerateResolvConf=false\n' > /etc/wsl.conf"
    wsl --shutdown
    wsl -u root bash -c "printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf"
'@
    foreach ($line in ($hint -split "`n")) { Write-Host $line.TrimEnd() -ForegroundColor White }
    Info "Corporate VPN? The VPN's DNS must be reachable from WSL, or use the static file above."
}

$ExpectedAgents   = @("lead", "frontend", "backend", "devops", "skeptic", "qa", "researcher")
$ExpectedCommands = @("prime", "build-with-agent-team", "deploy", "research")
$VscodeExtensions = @("dbaeumer.vscode-eslint", "bradlc.vscode-tailwindcss", "esbenp.prettier-vscode")

# ===================================================================
# EXECUTION POLICY -- allow scripts to run (profile, pp, pp-setup)
# ===================================================================

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
    Warn "PowerShell execution policy is '$currentPolicy' -- scripts (including your profile) are blocked"
    Write-Host ""
    $setPolicy = Read-Host "    Set to 'RemoteSigned' for current user? (y/n)"
    if ($setPolicy -eq "y") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        } catch {
            # Non-fatal: policy is set for future sessions but a Process-level
            # override (e.g. -ExecutionPolicy Bypass) takes precedence right now
        }
        Log "Execution policy set to RemoteSigned (takes effect in new terminals)"
    } else {
        Warn "Skipping -- your PowerShell profile and 'pp' commands may not work"
        Info "Fix manually: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }
} else {
    Log "Execution policy: $currentPolicy"
}

# ===================================================================
# INSTALL HELPERS
# ===================================================================

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-GitBash {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitDir = Split-Path -Parent (Split-Path -Parent (Get-Command git).Source)
        $bashPath = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $bashPath) {
            Log "Git Bash found: $bashPath"
            return $true
        }
    }

    $commonPaths = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            Log "Git Bash found: $p"
            Info "If Claude cannot find it, set: `$env:CLAUDE_CODE_GIT_BASH_PATH = '$p'"
            return $true
        }
    }

    Warn "Git for Windows is not installed (required by Claude Code)"
    Write-Host ""
    $install = Read-Host "    Install Git for Windows now? (y/n)"
    if ($install -ne "y") {
        Fail "Git for Windows is required. Install: https://git-scm.com/downloads/win"
        return $false
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Git for Windows via winget..."
        Invoke-Native { winget install Git.Git --accept-source-agreements --accept-package-agreements } | Out-Host
        Refresh-Path
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Log "Git for Windows installed"
            return $true
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Info "Installing Git for Windows via Chocolatey..."
        Invoke-Native { choco install git -y } | Out-Host
        Refresh-Path
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Log "Git for Windows installed"
            return $true
        }
    }

    Fail "Automatic installation failed. Install manually:"
    Write-Host "    https://git-scm.com/downloads/win" -ForegroundColor White
    Write-Host "    or: winget install Git.Git" -ForegroundColor White
    return $false
}

function Install-NodeJS {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Log "Node.js found: $(node --version)"
        return $true
    }

    Warn "Node.js is not installed (required for Claude CLI and npm packages)"
    Write-Host ""
    $install = Read-Host "    Install Node.js LTS now? (y/n)"
    if ($install -ne "y") {
        Fail "Node.js is required. Install manually: https://nodejs.org"
        return $false
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Node.js LTS via winget..."
        Invoke-Native { winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements } | Out-Host
        Refresh-Path
        if (Get-Command node -ErrorAction SilentlyContinue) {
            Log "Node.js installed: $(node --version)"
            return $true
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Info "Installing Node.js LTS via Chocolatey..."
        Invoke-Native { choco install nodejs-lts -y } | Out-Host
        Refresh-Path
        if (Get-Command node -ErrorAction SilentlyContinue) {
            Log "Node.js installed: $(node --version)"
            return $true
        }
    }

    Fail "Automatic installation failed. Install manually:"
    Write-Host "    https://nodejs.org/en/download" -ForegroundColor White
    Write-Host "    or: winget install OpenJS.NodeJS.LTS" -ForegroundColor White
    return $false
}

function Ensure-Npm {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Log "npm found: $(npm --version)"
        return $true
    }

    # npm should come with Node.js -- try refreshing PATH first
    Refresh-Path
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Log "npm found: $(npm --version)"
        return $true
    }

    # Try common Node.js install locations
    $nodePaths = @(
        "$env:ProgramFiles\nodejs",
        "$env:LOCALAPPDATA\Programs\nodejs",
        "$env:APPDATA\npm"
    )
    foreach ($p in $nodePaths) {
        if (Test-Path "$p\npm.cmd") {
            $env:Path = "$p;$env:Path"
            Log "npm found at $p"
            return $true
        }
    }

    if (Get-Command node -ErrorAction SilentlyContinue) {
        Warn "Node.js is installed but npm was not found"
        Info "This usually means you need to close and reopen your terminal after Node.js install"
        Info "If the problem persists, reinstall Node.js from https://nodejs.org"
    } else {
        Warn "npm not available -- install Node.js first (npm is bundled with it)"
    }
    return $false
}

function Install-ClaudeCLI {
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $v = (claude --version 2>$null | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*', '$1'
        Log "Claude CLI found: $v"
        return $true
    }

    Warn "Claude CLI is not installed"
    Write-Host ""
    $install = Read-Host "    Install Claude CLI now? (y/n)"
    if ($install -ne "y") {
        Fail "Claude CLI is required. Install: npm install -g @anthropic-ai/claude-code"
        return $false
    }

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Fail "npm not available -- install Node.js first"
        return $false
    }

    Info "Installing Claude CLI via npm..."
    Invoke-Native { npm install -g @anthropic-ai/claude-code } | Out-Host
    Refresh-Path

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $v = (claude --version 2>$null | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*', '$1'
        Log "Claude CLI installed: $v"
        return $true
    }

    Fail "Installation failed. Try manually: npm install -g @anthropic-ai/claude-code"
    return $false
}

# ===================================================================
# WSL + TMUX -- required for split-pane agent teams on Windows
# ===================================================================

function Ensure-WSL {
    # wsl.exe exists as a stub on Windows even when WSL isn't installed,
    # so we can't trust Get-Command. Try running it and check the result.
    $wslInstalled = $false
    $wslStatus = Invoke-WslCapture @("--status")
    # If --status succeeds without "not installed" message, WSL is enabled
    if ($wslStatus -and $wslStatus -notmatch "not installed" -and $wslStatus -notmatch "is not") {
        $wslInstalled = $true
    }

    if (-not $wslInstalled) {
        Warn "WSL is not installed (required for tmux split-pane agent teams)"
        Write-Host ""
        $install = Read-Host "    Install WSL now? (y/n)"
        if ($install -eq "y") {
            Info "Installing WSL with Ubuntu (this may take a few minutes)..."
            # wsl --install enables WSL and installs Ubuntu by default
            Invoke-Native { wsl --install } | Out-Host
            Write-Host ""
            Warn "WSL installed. You MUST restart your computer before continuing."
            Info "After restart, re-run: .\scripts\setup.ps1"
            Read-Host "Press Enter to exit"
            exit 0
        } else {
            Fail "WSL is required for tmux split-pane agent teams."
            Info "Install manually: wsl --install"
            return $false
        }
    }

    # Check a distro is actually installed
    $hasDistro = $false
    $distros = Invoke-WslCapture @("--list", "--quiet")
    if ($distros -and $distros -notmatch "not installed" -and $distros -notmatch "is not") {
        $hasDistro = $true
    }

    if (-not $hasDistro) {
        Warn "WSL is enabled but no Linux distribution found"
        Write-Host ""
        $install = Read-Host "    Install Ubuntu distro now? (y/n)"
        if ($install -eq "y") {
            Info "Installing Ubuntu..."
            Invoke-Native { wsl --install -d Ubuntu } | Out-Host
            Warn "Distro installed. You may need to restart your terminal."
            Info "After restart, re-run: .\scripts\setup.ps1"
            Read-Host "Press Enter to exit"
            exit 0
        } else {
            Fail "A WSL distro is required. Install: wsl --install -d Ubuntu"
            return $false
        }
    }

    Log "WSL found"
    return $true
}

function Ensure-WSLLocale {
    # Check if locale is already UTF-8
    $localeCheck = Invoke-WSLUser "locale 2>/dev/null | head -1"
    if ($localeCheck -match "UTF-8") {
        Log "WSL locale: UTF-8 configured (Cyrillic supported)"
        return $true
    }

    Warn "WSL locale is NOT set to UTF-8 -- Cyrillic characters will break in tmux"
    Info "Configuring UTF-8 locale in WSL (installs en_US.UTF-8 + ru_RU.UTF-8)..."

    # Run as root (wsl -u root): `sudo` here would block on a password prompt that
    # setup cannot answer, which is how this step used to fail silently.
    # Only single quotes below -- embedded double quotes do not survive PowerShell's
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
    $localeOut = Invoke-WSLRoot $localeScript
    $localeOut | Out-Host

    # Persist the vars in the DEFAULT USER's dotfiles -- as root, ~ is /root, so this
    # part must run unprivileged or tmux sessions would start without the locale.
    $profileScript = @'
grep -qF 'export LANG=' ~/.bashrc 2>/dev/null || echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
grep -qF 'export LC_ALL=' ~/.bashrc 2>/dev/null || echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
grep -qF 'export LANG=' ~/.profile 2>/dev/null || echo 'export LANG=en_US.UTF-8' >> ~/.profile
grep -qF 'export LC_ALL=' ~/.profile 2>/dev/null || echo 'export LC_ALL=en_US.UTF-8' >> ~/.profile
'@
    Invoke-WSLUser $profileScript | Out-Null

    # Verify the locale actually works
    $charmap = Invoke-WSLUser "LANG=en_US.UTF-8 locale charmap 2>/dev/null"
    $testCyrillic = Invoke-WSLUser "LANG=en_US.UTF-8 printf '\xd0\x9f\xd1\x80\xd0\xb8\xd0\xb2\xd0\xb5\xd1\x82' 2>/dev/null"

    if ($charmap -eq "UTF-8") {
        Log "WSL locale configured: en_US.UTF-8 (Cyrillic supported)"
        if ($testCyrillic -match "[A-Za-z]" -or $testCyrillic.Length -eq 0) {
            Warn "Cyrillic render test inconclusive -- verify in tmux after launch"
        }
        return $true
    } else {
        Fail "UTF-8 locale verification FAILED -- Cyrillic WILL NOT work"
        Warn "This MUST be fixed before using Claude with Cyrillic text"
        if (Test-AptNetworkFailure $localeOut) { Show-WSLNetworkHint }
        Info "Run manually:"
        Write-Host "    wsl -u root bash -c 'apt-get install -y locales && locale-gen en_US.UTF-8 ru_RU.UTF-8 && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8'" -ForegroundColor White
        Info "Then restart WSL: wsl --shutdown"
        return $false
    }
}

function Ensure-TmuxInWSL {
    $tmuxCheck = Invoke-WSLLogin "command -v tmux"
    if ($tmuxCheck -match "tmux") {
        $tmuxVer = Invoke-WSLUser "tmux -V"
        Log "tmux found in WSL: $tmuxVer"
        return $true
    }

    Warn "tmux not found in WSL (required for split-pane agent teams)"
    Write-Host ""
    $install = Read-Host "    Install tmux in WSL now? (y/n)"
    if ($install -eq "y") {
        Info "Installing tmux in WSL..."
        # As root -- `sudo` would block on an unanswerable password prompt.
        $aptOut = Invoke-WSLRoot "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y tmux"
        $aptOut | Out-Host
        $tmuxCheck = Invoke-WSLLogin "command -v tmux"
        if ($tmuxCheck -match "tmux") {
            Log "tmux installed in WSL"
            return $true
        } else {
            Fail "tmux installation failed"
            if (Test-AptNetworkFailure $aptOut) { Show-WSLNetworkHint }
            return $false
        }
    } else {
        Fail "tmux is required. Install manually: wsl -u root bash -c 'apt-get install -y tmux'"
        return $false
    }
}

function Ensure-ClaudeInWSL {
    $claudeCheck = Invoke-WSLLogin "command -v claude"
    if ($claudeCheck -match "claude") {
        $claudeVer = Invoke-WSLLogin "claude --version 2>/dev/null | head -1"
        Log "Claude CLI found in WSL: $claudeVer"
        return $true
    }

    Warn "Claude CLI not found in WSL (required for tmux split-pane mode)"
    Write-Host ""
    $install = Read-Host "    Install Claude CLI in WSL now? (y/n)"
    if ($install -ne "y") {
        Fail "Claude CLI in WSL is required for split-pane mode."
        Info "Install manually: wsl -u root bash -c 'npm install -g @anthropic-ai/claude-code'"
        return $false
    }

    # Everything below runs as root (wsl -u root). The previous version used `sudo`,
    # which blocks on a password prompt setup cannot answer -- the install never ran.
    $nodeCheck = Invoke-WSLLogin "command -v node"
    if ($nodeCheck -notmatch "node") {
        Info "Installing Node.js in WSL..."
        $nodeScript = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
'@
        $nodeOut = Invoke-WSLRoot $nodeScript
        $nodeOut | Out-Host

        $nodeCheck = Invoke-WSLLogin "command -v node"
        if ($nodeCheck -notmatch "node") {
            Fail "Node.js installation failed in WSL -- Claude CLI cannot be installed"
            if (Test-AptNetworkFailure $nodeOut) { Show-WSLNetworkHint }
            Info "Try manually: wsl -u root bash -c 'apt-get update && apt-get install -y nodejs npm'"
            return $false
        }
    }

    Info "Installing Claude CLI in WSL (npm install -g)..."
    $npmOutput = Invoke-WSLRoot "npm install -g @anthropic-ai/claude-code"
    $npmOutput | Out-Host

    $claudeCheck = Invoke-WSLLogin "command -v claude"
    if ($claudeCheck -match "claude") {
        Log "Claude CLI installed in WSL"
        return $true
    }

    Fail "Claude CLI installation failed in WSL"
    if ($npmOutput) {
        Info "npm said:"
        foreach ($line in (($npmOutput -split "`n") | Select-Object -Last 5)) {
            Write-Host "    $line" -ForegroundColor White
        }
    }
    Info "Try manually: wsl -u root bash -c 'npm install -g @anthropic-ai/claude-code'"
    return $false
}

# ===================================================================
# MAIN SETUP (idempotent -- runs the same whether first or repeat)
# ===================================================================

Write-Host ""
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host "|  Claude Code + Agent Teams Setup     |" -ForegroundColor Cyan
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host ""

# --- Install tools ------------------------------------------------

$gitOk   = Install-GitBash
$nodeOk  = Install-NodeJS
$npmOk   = Ensure-Npm
$claudeOk = Install-ClaudeCLI

if (-not $gitOk) {
    Fail "Git for Windows is required by Claude Code. Cannot continue."
    Write-Host "    Install: winget install Git.Git" -ForegroundColor White
    Write-Host "    Then close and reopen this terminal." -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not $claudeOk) {
    Fail "Claude CLI is required. Cannot continue."
    exit 1
}

if (-not $nodeOk) {
    Warn "Node.js missing -- some features will not be available."
}

if (-not $npmOk) {
    Warn "npm missing -- try closing and reopening terminal, then re-run setup."
}

# --- WSL + tmux (required for split-pane agent teams) -------------

$wslOk = Ensure-WSL
if ($wslOk) {
    # Capture every return value -- an unassigned function call writes its result
    # ("True"/"False") straight to the console.
    $tmuxOk      = Ensure-TmuxInWSL
    $localeOk    = Ensure-WSLLocale
    $claudeWslOk = Ensure-ClaudeInWSL
} else {
    Warn "WSL not available -- agent teams will not have split-pane support"
    $tmuxOk = $false; $localeOk = $false; $claudeWslOk = $false
}

if ($tmuxOk -and $localeOk -and $claudeWslOk) {
    Log "Pre-flight passed"
} else {
    Warn "Pre-flight finished with unresolved items (see above):"
    if (-not $tmuxOk)      { Write-Host "    - tmux in WSL"          -ForegroundColor White }
    if (-not $localeOk)    { Write-Host "    - UTF-8 locale in WSL"  -ForegroundColor White }
    if (-not $claudeWslOk) { Write-Host "    - Claude CLI in WSL"    -ForegroundColor White }
    Info "Config below still installs; split-pane agent teams need the items above."
}

# Write the teammateMode that this machine can actually honour. tmux gives one pane
# per teammate but needs WSL + tmux + Claude-in-WSL; in-process is Claude Code's own
# default and needs none of it (Shift+Down cycles teammates). Claiming "tmux" on a
# machine without it leaves teammates with nowhere to appear.
if ($tmuxOk -and $claudeWslOk) {
    $TeammateMode = "tmux"
    Info "teammateMode: tmux (split panes -- one pane per teammate)"
} else {
    $TeammateMode = "in-process"
    Info "teammateMode: in-process (no WSL/tmux needed -- Shift+Down cycles teammates)"
}
Write-Host ""

# --- User-level settings -----------------------------------------

$userSettingsDir  = "$env:USERPROFILE\.claude"
$userSettingsFile = "$userSettingsDir\settings.json"

if (-not (Test-Path $userSettingsDir)) { New-Item -ItemType Directory -Path $userSettingsDir -Force | Out-Null }

if (Test-Path $userSettingsFile) {
    $content = Get-Content $userSettingsFile -Raw
    $needsUpdate = $false
    if ($content -notmatch "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")   { $needsUpdate = $true }
    if ($content -notmatch "teammateMode")                           { $needsUpdate = $true }
    # Also correct a stale mode: "tmux" on a machine without tmux strands teammates.
    if ($content -notmatch "`"teammateMode`"\s*:\s*`"$TeammateMode`"") { $needsUpdate = $true }

    if ($needsUpdate) {
        Info "Updating user settings for agent teams..."
        try {
            $settings = $content | ConvertFrom-Json
            if (-not $settings.env) { $settings | Add-Member -NotePropertyName "env" -NotePropertyValue ([PSCustomObject]@{}) }
            $settings.env | Add-Member -NotePropertyName "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" -NotePropertyValue "1" -Force
            $settings | Add-Member -NotePropertyName "teammateMode" -NotePropertyValue $TeammateMode -Force
            $settings | ConvertTo-Json -Depth 10 | Set-Content $userSettingsFile -Encoding UTF8
            Log "Updated $userSettingsFile (teammateMode: $TeammateMode)"
        } catch {
            Warn "Could not auto-update user settings. Add manually:"
            Write-Host '    env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' -ForegroundColor White
            Write-Host "    teammateMode = ""$TeammateMode""" -ForegroundColor White
        }
    } else {
        Log "User settings: agent teams already configured"
    }
} else {
    $settingsJson = @"
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "$TeammateMode"
}
"@
    $settingsJson | Set-Content $userSettingsFile -Encoding UTF8
    Log "Created $userSettingsFile"
}

# --- Project-level settings ---------------------------------------

if (-not (Test-Path ".claude")) { New-Item -ItemType Directory -Path ".claude" -Force | Out-Null }

if (Test-Path ".claude/settings.json") {
    $content = Get-Content ".claude/settings.json" -Raw
    $needsUpdate = $false
    if ($content -notmatch "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")   { $needsUpdate = $true }
    if ($content -notmatch "teammateMode")                           { $needsUpdate = $true }
    if ($content -notmatch "`"teammateMode`"\s*:\s*`"$TeammateMode`"") { $needsUpdate = $true }

    if ($needsUpdate) {
        try {
            $settings = $content | ConvertFrom-Json
            if (-not $settings.env) { $settings | Add-Member -NotePropertyName "env" -NotePropertyValue ([PSCustomObject]@{}) }
            $settings.env | Add-Member -NotePropertyName "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" -NotePropertyValue "1" -Force
            $settings | Add-Member -NotePropertyName "teammateMode" -NotePropertyValue $TeammateMode -Force
            $settings | ConvertTo-Json -Depth 10 | Set-Content ".claude/settings.json" -Encoding UTF8
            Log "Updated .claude\settings.json (teammateMode: $TeammateMode)"
        } catch {
            Warn "Could not auto-update project settings"
        }
    } else {
        Log "Project settings already configured"
    }
} else {
    $projSettings = @"
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "$TeammateMode"
}
"@
    $projSettings | Set-Content ".claude/settings.json" -Encoding UTF8
    Log "Created .claude\settings.json"
}

# --- Verify config files ------------------------------------------

foreach ($dir in @(".claude/agents", ".claude/commands", ".claude/snapshots")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$missingAgents = @()
foreach ($agent in $ExpectedAgents) {
    if (-not (Test-Path ".claude/agents/$agent.md")) { $missingAgents += $agent }
}

$missingCommands = @()
foreach ($cmd in $ExpectedCommands) {
    if (-not (Test-Path ".claude/commands/$cmd.md")) { $missingCommands += $cmd }
}

if ($missingAgents.Count -gt 0 -or $missingCommands.Count -gt 0) {
    Warn "Missing config files. Run install.ps1 to download them:"
    Write-Host "    irm https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.ps1 | iex" -ForegroundColor White
    if ($missingAgents.Count -gt 0) { Warn "  Missing agents: $($missingAgents -join ', ')" }
    if ($missingCommands.Count -gt 0) { Warn "  Missing commands: $($missingCommands -join ', ')" }
} else {
    Log "Config files verified: $($ExpectedAgents.Count) agents, $($ExpectedCommands.Count) commands"
}

# --- .gitignore additions -----------------------------------------

if (Test-Path ".gitignore") {
    $ignoreContent = Get-Content ".gitignore" -Raw -ErrorAction SilentlyContinue
    $entries = @(".env", ".env.*")
    foreach ($entry in $entries) {
        if ($ignoreContent -notmatch [regex]::Escape($entry)) {
            Add-Content ".gitignore" $entry
        }
    }
    Log "Updated .gitignore"
}

# --- Project dependencies -----------------------------------------

if (Test-Path "package.json") {
    if (Test-Path "node_modules") {
        Log "Project dependencies installed (node_modules)"
    } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
        Info "Installing project dependencies (npm install)..."
        Invoke-Native { npm install } | Out-Host
        if (Test-Path "node_modules") {
            Log "Project dependencies installed"
        } else {
            Warn "npm install failed"
        }
    } else {
        Warn "npm not available -- cannot install project dependencies"
    }
} else {
    Info "No package.json found -- skipping npm install"
}

# --- VS Code extensions -------------------------------------------

if (Get-Command code -ErrorAction SilentlyContinue) {
    Log "VS Code CLI found"

    Write-Host ""
    Info "Recommended VS Code extensions:"
    foreach ($ext in $VscodeExtensions) {
        Write-Host "    $ext" -ForegroundColor White
    }
    Write-Host ""
    $installExt = Read-Host "    Install recommended VS Code extensions? (y/n)"
    if ($installExt -eq "y") {
        foreach ($ext in $VscodeExtensions) {
            Info "Installing: $ext"
            # --force updates if already installed, avoids opening VS Code windows.
            # Wrapped: `code` shells out to node, whose deprecation warnings go to
            # stderr -- under $ErrorActionPreference = "Stop" that killed the script.
            Invoke-Native { code --install-extension $ext --force } | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log "Installed: $ext"
            } else {
                Warn "Could not install $ext (exit $LASTEXITCODE) -- install it from the VS Code UI"
            }
        }
    } else {
        Info "Skipping. Install later:"
        foreach ($ext in $VscodeExtensions) {
            Write-Host "    code --install-extension $ext" -ForegroundColor White
        }
    }
} else {
    Info "VS Code 'code' command not in PATH -- skipping extension setup"
    Info "Open VS Code -> Ctrl+Shift+P -> 'Shell Command: Install code command in PATH'"
}

# --- Quick commands (pp, pp-setup) --------------------------------

$psProfile = $PROFILE
if (-not (Test-Path $psProfile)) {
    $profileDir = Split-Path -Parent $psProfile
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    # Create empty profile so we can append to it
    [System.IO.File]::WriteAllText($psProfile, "", (New-Object System.Text.UTF8Encoding($true)))
}

$profileContent = Get-Content $psProfile -Raw -ErrorAction SilentlyContinue
$hasPp       = $profileContent -match 'function pp '
$hasPpSetup  = $profileContent -match 'function pp-setup '
$hasPpUpdate = $profileContent -match 'function pp-update '
$ppIsStale   = $hasPp -and ($profileContent -match 'function pp \{[^}]*Set-Location')

if ($hasPp -and $hasPpSetup -and $hasPpUpdate -and -not $ppIsStale) {
    Log "Quick commands already registered (pp, pp-setup, pp-update)"
} else {
    Write-Host ""
    Info "Quick commands:"
    Write-Host "    pp         -- launch Claude session in current folder"
    Write-Host "    pp-setup   -- re-run setup for this project"
    Write-Host "    pp-update  -- pull latest cc-setup + refresh hooks/plugins"
    Write-Host ""
    $addCmds = Read-Host "    Add 'pp', 'pp-setup', 'pp-update' to PowerShell profile? (y/n)"
    if ($addCmds -eq "y") {
        if ($hasPp -or $hasPpSetup -or $hasPpUpdate) {
            $profileContent = $profileContent -replace '(?m)^# Claude Code -- quick commands.*\r?\n', ''
            $profileContent = $profileContent -replace '(?m)^function pp \{[^}]+\}\r?\n?', ''
            $profileContent = $profileContent -replace '(?m)^function pp-setup \{[^}]+\}\r?\n?', ''
            $profileContent = $profileContent -replace '(?m)^function pp-update \{[^}]+\}\r?\n?', ''
            [System.IO.File]::WriteAllText($psProfile, $profileContent, (New-Object System.Text.UTF8Encoding($true)))
            Info "Cleaned up old quick commands"
        }

        $cmdBlock = @"

# Claude Code -- quick commands (added by setup.ps1)
function pp { & "$ProjectDir\scripts\start.ps1" (Get-Location).Path }
function pp-setup { Set-Location "$ProjectDir"; & powershell -ExecutionPolicy Bypass -File ".\scripts\setup.ps1" @args }
function pp-update { & powershell -ExecutionPolicy Bypass -File "$ProjectDir\scripts\update.ps1" @args }
"@
        $existingContent = if (Test-Path $psProfile) {
            [System.IO.File]::ReadAllText($psProfile, [System.Text.Encoding]::UTF8)
        } else { "" }
        $newContent = $existingContent + $cmdBlock
        [System.IO.File]::WriteAllText($psProfile, $newContent, (New-Object System.Text.UTF8Encoding($true)))
        Log "Added 'pp', 'pp-setup', 'pp-update' to $psProfile"
        Info "Restart PowerShell or run '. `$PROFILE' to use them"
    } else {
        Info "Skipping quick commands. Add manually later."
    }
}

# --- Clean up leftover files --------------------------------------


# --- Summary ------------------------------------------------------

Write-Host ""
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host "|  Setup Complete                      |" -ForegroundColor Cyan
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Agent Teams (Official Mechanism):"
Write-Host "    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1  Enabled in settings"
Write-Host "    teammateMode: tmux                      Teammates auto-create split panes via WSL tmux"
Write-Host "    .claude\settings.json                   Project-level settings"
Write-Host "    ~\.claude\settings.json                 User-level settings"
Write-Host "    .claude\agents\              $($ExpectedAgents.Count) agents: $($ExpectedAgents -join ', ')"
Write-Host ""
Write-Host "  Commands:"
Write-Host "    .claude\commands\            $($ExpectedCommands.Count) commands: $($ExpectedCommands -join ', ')"
Write-Host ""
Write-Host "  Quick commands (added to PowerShell profile):"
Write-Host "    pp                           Launch Claude session in current folder"
Write-Host "    pp-setup                     Re-run setup for this project"
Write-Host "    pp-update                    Pull latest cc-setup + refresh hooks/plugins"
Write-Host ""
Write-Host "  Inside Claude:"
Write-Host "    /prime                       Prime the session with codebase context"
Write-Host "    /build-with-agent-team       Spawn agent team"
Write-Host "    /research <topic>            Spawn research agent"
Write-Host "    /deploy                      Commit, push, snapshot"
Write-Host ""
Write-Host "  To start:" -ForegroundColor Green
Write-Host "    . `$PROFILE              Reload profile (required once after setup)" -ForegroundColor Green
Write-Host "    pp                       Launch Claude session" -ForegroundColor Green
Write-Host ""
Write-Host "  Or run directly:  .\scripts\start.ps1" -ForegroundColor Green
Write-Host ""
