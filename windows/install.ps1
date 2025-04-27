<#
.SYNOPSIS
    Install or update the Araise Package Manager on Windows.

.DESCRIPTION
    Can be executed straight from a repo checkout **or** via the one‑liner:
        iwr -useb https://raw.githubusercontent.com/Araise25/arAIse_PM/main/windows/install.ps1 | iex
#>

# ─────────────────────────────────────────────────────────────────────────────
# Global safety
# ─────────────────────────────────────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Trap { Write-Error "Unhandled error: $_"; Exit 1 }

# ─────────────────────────────────────────────────────────────────────────────
# Colour helpers
# ─────────────────────────────────────────────────────────────────────────────
$script:RED     = [ConsoleColor]::Red
$script:GREEN   = [ConsoleColor]::Green
$script:YELLOW  = [ConsoleColor]::Yellow
$script:NC      = [ConsoleColor]::White      # reserved / not used

function Write-Color {
    param (
        [string]        $Message,
        [ConsoleColor]  $Color = $NC
    )
    Write-Host $Message -ForegroundColor $Color
}

# ─────────────────────────────────────────────────────────────────────────────
# Paths & constants
# ─────────────────────────────────────────────────────────────────────────────
$SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Source) {
    Split-Path -Parent $MyInvocation.MyCommand.Source
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}

$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$ARAISE_DIR   = Join-Path $env:USERPROFILE ".araise"
$BIN_DIR      = Join-Path $ARAISE_DIR "bin"

$FORGE_ORG  = "Araise25"
$FORGE_REPO = "arAIse_PM"
$BRANCH     = "main"
$BASE_URL   = "https://raw.githubusercontent.com/$FORGE_ORG/$FORGE_REPO/$BRANCH"

# ─────────────────────────────────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────────────────────────────────
function Test-LocalInstall {
    $markers = @(
        "common\packages.json",
        "windows\cli.ps1",
        "windows\uninstall.ps1"
    ) | ForEach-Object { Join-Path $PROJECT_ROOT $_ }

    foreach ($file in $markers) {
        if (-not (Test-Path $file -PathType Leaf)) {
            Write-Color "Missing local file: $file" $YELLOW
            return $false
        }
    }
    return $true
}

function Ensure-Dir ([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Fetch-Remote ([string]$RelativeUrl,[string]$Destination) {
    Invoke-WebRequest -UseBasicParsing -Uri "$BASE_URL/$RelativeUrl" `
                      -OutFile $Destination -ErrorAction Stop
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation helpers
# ─────────────────────────────────────────────────────────────────────────────
function Install-CliScripts {
    param([bool]$Local)

    Ensure-Dir $ARAISE_DIR

    $cliDest       = Join-Path $ARAISE_DIR "cli.ps1"
    $uninstallDest = Join-Path $ARAISE_DIR "uninstall.ps1"

    if ($Local) {
        Copy-Item -Force -Path (Join-Path $PROJECT_ROOT "windows\cli.ps1")       -Destination $cliDest
        Copy-Item -Force -Path (Join-Path $PROJECT_ROOT "windows\uninstall.ps1") -Destination $uninstallDest
    } else {
        Fetch-Remote "windows/cli.ps1"       $cliDest
        Fetch-Remote "windows/uninstall.ps1" $uninstallDest
    }
}

function Install-PackagesJson {
    param([bool]$Local)

    $dest = Join-Path $ARAISE_DIR "packages.json"
    if ($Local) {
        Copy-Item -Force -Path (Join-Path $PROJECT_ROOT "common\packages.json") -Destination $dest
    } else {
        try { Fetch-Remote "common/packages.json" $dest }
        catch {
            Write-Color "Remote packages.json unavailable, creating empty one" $YELLOW
            '{"packages":[]}' | Out-File $dest
        }
    }
}

function New-Launcher {
    Ensure-Dir $BIN_DIR
    $launcherPath = Join-Path $BIN_DIR "araise.ps1"
    $cliPath      = Join-Path $ARAISE_DIR "cli.ps1"

@"
#!/usr/bin/env pwsh
`$ErrorActionPreference = 'Stop'
& '$cliPath' @args
"@ | Set-Content -Encoding UTF8 -Path $launcherPath -Force
}

function Update-Profile {
    # Block added to $PROFILE; provides both 'araise' and 'uninstall-araise'
    $block = @"

# ─── Araise Package Manager Integration ─────────────────────────────
function Invoke-Araise {
    if (`$args.Count -eq 0) {
        & "`$env:USERPROFILE\.araise\bin\araise.ps1"
    } else {
        & "`$env:USERPROFILE\.araise\bin\araise.ps1" @args
    }
}
Set-Alias -Name araise -Value Invoke-Araise

function Invoke-AraiseUninstall {
    & "`$env:USERPROFILE\.araise\uninstall.ps1"
}
Set-Alias -Name uninstall-araise -Value Invoke-AraiseUninstall
# ────────────────────────────────────────────────────────────────────
"@

    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Create profile if it doesn't exist
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    # Append the block to the profile
    Add-Content -Path $PROFILE -Value $block

    Write-Color "Updated PowerShell profile with Araise integration" $GREEN
}

# ─────────────────────────────────────────────────────────────────────────────
# Main orchestration
# ─────────────────────────────────────────────────────────────────────────────
function Install-Windows {

    Write-Color "Installing Araise Package Manager..." $GREEN

    $isLocal = Test-LocalInstall
    Write-Color "Installation type: $(if ($isLocal) { 'Local' } else { 'Remote' })" $YELLOW

    Install-CliScripts   -Local:$isLocal
    Install-PackagesJson -Local:$isLocal

    # Fresh registry.json each time
    '{"packages":{}}' | Out-File (Join-Path $ARAISE_DIR "registry.json") -Force

    New-Launcher
    Update-Profile

    # Cleanup legacy file
    $old = Join-Path $ARAISE_DIR "forge.ps1"
    if (Test-Path $old) {
        Remove-Item $old -Force
        Write-Color "Removed legacy forge.ps1" $YELLOW
    }

    Write-Color "`nAraise Package Manager installed successfully!" $GREEN
    Write-Color "Restart PowerShell or run:`n  . `$PROFILE" $YELLOW
    Write-Color "`nThen type 'araise help' to get started." $GREEN
}

Install-Windows
