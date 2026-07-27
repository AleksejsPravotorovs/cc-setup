#Requires -Version 5.1
# +==================================================================+
# |  pp-update -- refresh Claude Code setup from GitHub (Windows)   |
# |                                                                  |
# |  Two modes (auto-detected):                                     |
# |    * cc-setup clone  -> git pull + refresh ~\.claude user scope |
# |    * bootstrapped    -> re-download project .claude\ files      |
# +==================================================================+

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$RepoUrl    = "https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main"

function Log($msg)  { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Info($msg) { Write-Host "  [ii] $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "  [XX] $msg" -ForegroundColor Red }

# --- Native command helper ----------------------------------------
# $ErrorActionPreference = "Stop" (above) makes PowerShell 5.1 promote ANY line a
# native command writes to stderr into a *terminating* NativeCommandError. `git pull`
# prints its progress to stderr, so a SUCCESSFUL pull used to be reported as failed.
# Native commands run through this helper; the exit code lands in $LASTEXITCODE.

# Parameter named $NativeCall, NOT $Command: a scriptblock's variables resolve against
# the RUNTIME scope chain at invocation, so a helper parameter sharing a name with a
# variable inside the caller's scriptblock would silently shadow it.
function Invoke-NativeInteractive {
    param([Parameter(Mandatory = $true)][scriptblock]$NativeCall)
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try { & $NativeCall } finally { $script:ErrorActionPreference = $prev }
}

# Detect mode
if ((Test-Path "$ProjectDir\claude-user-config") -and (Test-Path "$ProjectDir\scripts\install-plugins.sh")) {
    $Mode = "cc-setup"
} else {
    $Mode = "project"
}

Write-Host ""
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host "|  Claude Code -- pp-update                    |" -ForegroundColor Cyan
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host ""
Info "Mode: $Mode"
Info "Dir : $ProjectDir"
Write-Host ""

# ---- cc-setup clone mode -----------------------------------------

if ($Mode -eq "cc-setup") {
    if (Test-Path "$ProjectDir\.git") {
        Info "Pulling latest cc-setup..."
        Push-Location $ProjectDir
        try {
            Invoke-NativeInteractive { git pull --ff-only }
            if ($LASTEXITCODE -eq 0) {
                Log "cc-setup up to date"
            } else {
                Warn "git pull failed (local changes? non-fast-forward?) -- continuing with current checkout"
            }
        } finally {
            Pop-Location
        }
    } else {
        Warn "Not a git clone -- skipping pull"
    }

    Write-Host ""
    Info "Refreshing user-scope config (~\.claude) via Git Bash..."

    # Need bash to run install-plugins.sh. Locate it.
    $bashPath = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitDir = Split-Path -Parent (Split-Path -Parent (Get-Command git).Source)
        $candidate = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $candidate) { $bashPath = $candidate }
    }
    if (-not $bashPath) {
        foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
            if (Test-Path $p) { $bashPath = $p; break }
        }
    }

    if ($bashPath) {
        Invoke-NativeInteractive { & $bashPath "$ProjectDir\scripts\install-plugins.sh" }
    } else {
        Fail "Git Bash not found -- cannot run install-plugins.sh"
        Info "Install Git for Windows: https://git-scm.com/downloads/win"
        exit 1
    }

    Write-Host ""
    if (Test-Path "$ProjectDir\scripts\apply-self-edit-safeguard-fix.sh") {
        Info "Applying self-edit-safeguard protocol to cc-setup itself..."
        Invoke-NativeInteractive { & $bashPath "$ProjectDir\scripts\apply-self-edit-safeguard-fix.sh" "$ProjectDir" }
    }

    Write-Host ""
    Log "pp-update complete."
    Write-Host ""
    Info "To refresh a bootstrapped project's .claude\ files, cd into it and run pp-update there."
    exit 0
}

# ---- Bootstrapped-project mode -----------------------------------

Info "Refreshing project files from GitHub..."
Write-Host ""

foreach ($dir in @("scripts", ".claude\agents", ".claude\commands", ".claude\snapshots", ".vscode")) {
    New-Item -ItemType Directory -Path (Join-Path $ProjectDir $dir) -Force | Out-Null
}

# Scripts (includes apply-self-edit-safeguard-fix.sh — protocol patcher, runs under Git Bash)
foreach ($file in @("setup.ps1", "start.ps1", "update.ps1", "fix-profile.ps1", "apply-self-edit-safeguard-fix.sh")) {
    Write-Host "  scripts\$file"
    Invoke-WebRequest "$RepoUrl/scripts/$file" -OutFile (Join-Path $ProjectDir "scripts\$file") -UseBasicParsing
}

# Agents
foreach ($agent in @("lead", "frontend", "backend", "devops", "skeptic", "qa", "researcher")) {
    Write-Host "  .claude\agents\$agent.md"
    Invoke-WebRequest "$RepoUrl/.claude/agents/$agent.md" -OutFile (Join-Path $ProjectDir ".claude\agents\$agent.md") -UseBasicParsing
}

# Commands
foreach ($cmd in @("prime", "build-with-agent-team", "deploy", "research")) {
    Write-Host "  .claude\commands\$cmd.md"
    Invoke-WebRequest "$RepoUrl/.claude/commands/$cmd.md" -OutFile (Join-Path $ProjectDir ".claude\commands\$cmd.md") -UseBasicParsing
}

# Root-level canonical docs (AGENTS.md = PROMPT_FREE_PROTOCOL canonical; CLAUDE.md loads it)
foreach ($rootDoc in @("AGENTS.md", "CLAUDE.md")) {
    Write-Host "  $rootDoc"
    try {
        Invoke-WebRequest "$RepoUrl/$rootDoc" -OutFile (Join-Path $ProjectDir $rootDoc) -UseBasicParsing
    } catch { Warn "    (missing remotely -- skipped)" }
}

# Protocol mirror inside .claude\ (agent-facing)
Write-Host "  .claude\PROMPT_FREE_PROTOCOL.md"
try {
    Invoke-WebRequest "$RepoUrl/.claude/PROMPT_FREE_PROTOCOL.md" -OutFile (Join-Path $ProjectDir ".claude\PROMPT_FREE_PROTOCOL.md") -UseBasicParsing
} catch { Warn "    (missing remotely -- skipped)" }

# VS Code workspace auto-approve
Write-Host "  .vscode\settings.json"
try {
    Invoke-WebRequest "$RepoUrl/.vscode/settings.json" -OutFile (Join-Path $ProjectDir ".vscode\settings.json") -UseBasicParsing
} catch { Warn "    (missing remotely -- skipped)" }

# Frontend set -- only refresh if already present
if (Test-Path (Join-Path $ProjectDir ".claude\skills")) {
    Info "Frontend skills detected -- refreshing..."
    foreach ($skill in @("premium-design", "scroll-animations", "section-transitions", "design-system-extraction")) {
        Write-Host "  .claude\skills\$skill.md"
        try {
            Invoke-WebRequest "$RepoUrl/.claude/skills/$skill.md" -OutFile (Join-Path $ProjectDir ".claude\skills\$skill.md") -UseBasicParsing
        } catch { Warn "    (missing remotely -- skipped)" }
    }
}

# Design research docs live at research\design\ (outside .claude\ — protected-path safeguard avoidance)
if ((Test-Path (Join-Path $ProjectDir "research\design")) -or (Test-Path (Join-Path $ProjectDir ".claude\research"))) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir "research\design") | Out-Null
    foreach ($doc in @("bold-design-principles", "premium-design-system-template", "scroll-driven-ui-roadmap-template", "scroll-scrubbed-video", "section-transitions-spec", "video-smoothing")) {
        Write-Host "  research\design\$doc.md"
        try {
            Invoke-WebRequest "$RepoUrl/research/design/$doc.md" -OutFile (Join-Path $ProjectDir "research\design\$doc.md") -UseBasicParsing
        } catch { Warn "    (missing remotely -- skipped)" }
    }
}

if (Test-Path (Join-Path $ProjectDir "libraries\scroll-animations")) {
    foreach ($lib in @("README.md", "animations.ts", "easings.ts", "scroll-animations.ts", "tailwind-theme-reference.js")) {
        Write-Host "  libraries\scroll-animations\$lib"
        try {
            Invoke-WebRequest "$RepoUrl/libraries/scroll-animations/$lib" -OutFile (Join-Path $ProjectDir "libraries\scroll-animations\$lib") -UseBasicParsing
        } catch { Warn "    (missing remotely -- skipped)" }
    }
}

Write-Host ""
Log "Project files refreshed."
Write-Host ""

# Auto-apply the self-edit-safeguard protocol so the refreshed project is safe to run immediately.
# Idempotent — no-op when already patched. Requires Git Bash on Windows.
if (Test-Path "$ProjectDir\scripts\apply-self-edit-safeguard-fix.sh") {
    $bashPath = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitDir = Split-Path -Parent (Split-Path -Parent (Get-Command git).Source)
        $candidate = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $candidate) { $bashPath = $candidate }
    }
    if (-not $bashPath) {
        foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
            if (Test-Path $p) { $bashPath = $p; break }
        }
    }
    if ($bashPath) {
        Info "Applying self-edit-safeguard protocol (idempotent)..."
        Invoke-NativeInteractive { & $bashPath "$ProjectDir\scripts\apply-self-edit-safeguard-fix.sh" "$ProjectDir" }
        Log "Protocol applied / verified"
    } else {
        Warn "Git Bash not found -- skipping safeguard apply (install Git for Windows to enable)"
    }
    Write-Host ""
}
