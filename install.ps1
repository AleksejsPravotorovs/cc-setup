# +==================================================================+
# |  Claude Code -- One-liner bootstrap (Windows)                    |
# |  irm https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.ps1 | iex
# +==================================================================+

$ErrorActionPreference = "Stop"

$repo = "https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main"

Write-Host ""
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host "|  Claude Code -- Downloading files    |" -ForegroundColor Cyan
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host ""

# Create directory structure
foreach ($dir in @("scripts", ".claude\agents", ".claude\commands", ".claude\snapshots")) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# --- Scripts ---
foreach ($file in @("setup.ps1", "start.ps1", "update.ps1", "fix-profile.ps1", "setup.bat", "start.bat")) {
    Write-Host "  Downloading scripts\$file..."
    Invoke-WebRequest "$repo/scripts/$file" -OutFile "scripts\$file" -UseBasicParsing
}

# --- Agents ---
foreach ($agent in @("lead", "frontend", "backend", "devops", "skeptic", "qa", "researcher")) {
    Write-Host "  Downloading .claude\agents\$agent.md..."
    Invoke-WebRequest "$repo/.claude/agents/$agent.md" -OutFile ".claude\agents\$agent.md" -UseBasicParsing
}

# --- Commands ---
foreach ($cmd in @("prime", "build-with-agent-team", "deploy", "research")) {
    Write-Host "  Downloading .claude\commands\$cmd.md..."
    Invoke-WebRequest "$repo/.claude/commands/$cmd.md" -OutFile ".claude\commands\$cmd.md" -UseBasicParsing
}

# --- Config files (only if not already present) ---
foreach ($file in @(".claude\settings.json", "CLAUDE.md", "AGENTS.md")) {
    if (-not (Test-Path $file)) {
        Write-Host "  Downloading $file..."
        Invoke-WebRequest "$repo/$file" -OutFile $file -UseBasicParsing
    } else {
        Write-Host "  Skipping $file (already exists)"
    }
}

# --- Frontend design add-on (opt-in) ---
Write-Host ""
Write-Host "Optional: frontend design add-on"
Write-Host "  * 4 skills        premium-design, scroll-animations, section-transitions, design-system-extraction"
Write-Host "  * 6 research docs bold-design, scroll-driven UI, video smoothing, section transitions, ..."
Write-Host "  * scroll-animations TS library (animations.ts, easings.ts, ...)"
Write-Host ""
$installFrontend = Read-Host "Install frontend design set? (y/n)"
Write-Host ""

if ($installFrontend -eq "y") {
    foreach ($dir in @(".claude\skills", "research\design", "libraries\scroll-animations")) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    foreach ($skill in @("premium-design", "scroll-animations", "section-transitions", "design-system-extraction")) {
        Write-Host "  Downloading .claude\skills\$skill.md..."
        Invoke-WebRequest "$repo/.claude/skills/$skill.md" -OutFile ".claude\skills\$skill.md" -UseBasicParsing
    }

    foreach ($doc in @("bold-design-principles", "premium-design-system-template", "scroll-driven-ui-roadmap-template", "scroll-scrubbed-video", "section-transitions-spec", "video-smoothing")) {
        Write-Host "  Downloading research\design\$doc.md..."
        Invoke-WebRequest "$repo/research/design/$doc.md" -OutFile "research\design\$doc.md" -UseBasicParsing
    }

    foreach ($lib in @("README.md", "animations.ts", "easings.ts", "scroll-animations.ts", "tailwind-theme-reference.js")) {
        Write-Host "  Downloading libraries\scroll-animations\$lib..."
        Invoke-WebRequest "$repo/libraries/scroll-animations/$lib" -OutFile "libraries\scroll-animations\$lib" -UseBasicParsing
    }
}

Write-Host ""
Write-Host "  Files downloaded."
Write-Host "  Running setup..."
Write-Host ""

# setup.ps1 is interactive and shells out to native tools (winget, npm, wsl, code)
# that write to stderr. Under $ErrorActionPreference = "Stop", PowerShell 5.1 turns
# those stderr lines into a terminating NativeCommandError and kills the bootstrap,
# so the preference is relaxed for the handoff. Nothing follows this call.
$ErrorActionPreference = "Continue"
& powershell -ExecutionPolicy Bypass -NoProfile -File ".\scripts\setup.ps1"
