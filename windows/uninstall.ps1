# Colors for output
$RED = [System.ConsoleColor]::Red
$GREEN = [System.ConsoleColor]::Green
$YELLOW = [System.ConsoleColor]::Yellow
$NC = [System.ConsoleColor]::White

# Function to get user confirmation with Y as default
function Get-UserConfirmation {
    param (
        [string]$prompt
    )
    Write-Host "$prompt (Y/n) [Enter = Y]: " -ForegroundColor $GREEN -NoNewline
    $response = Read-Host
    return [string]::IsNullOrEmpty($response) -or $response -match '^[Yy]'
}

# Base directory for araise
$ARAISE_DIR = "$env:USERPROFILE\.araise"
$BIN_DIR = "$env:USERPROFILE\AppData\Local\bin"

Write-Host "Warning: This will completely remove Araise Package Manager and all installed packages" -ForegroundColor $YELLOW
if (Get-UserConfirmation "Continue with uninstallation?") {
    Write-Host "Uninstalling Araise Package Manager..." -ForegroundColor $YELLOW

    # Remove from PATH
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($userPath.Split(';') | Where-Object { $_ -notlike "*$BIN_DIR*" }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

    # Remove environment variable
    [Environment]::SetEnvironmentVariable('ARAISE_ORG', $null, 'User')

    # Remove from PowerShell profile
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE
        $newContent = @()
        $inAraiseBlock = $false
        
        foreach ($line in $profileContent) {
            if ($line -match '# ─── Araise Package Manager Integration ───') {
                $inAraiseBlock = $true
                continue
            }
            if ($inAraiseBlock -and $line -match '# ────────────────────────────────────────────────────────────────────') {
                $inAraiseBlock = $false
                continue
            }
            if (-not $inAraiseBlock) {
                $newContent += $line
            }
        }
        
        $newContent | Set-Content $PROFILE
        Write-Host "Removed Araise from PowerShell profile" -ForegroundColor $GREEN
    }

    # Remove all Araise files and directories
    if (Test-Path $ARAISE_DIR) {
        Remove-Item -Recurse -Force $ARAISE_DIR
        Write-Host "Removed Araise directory and all installed packages" -ForegroundColor $GREEN
    }

    # Remove from local bin if exists
    if (Test-Path "$BIN_DIR\araise.ps1") {
        Remove-Item -Force "$BIN_DIR\araise.ps1"
        Write-Host "Removed Araise from $BIN_DIR" -ForegroundColor $GREEN
    }

    Write-Host "Araise Package Manager has been completely removed from your system" -ForegroundColor $GREEN
    Write-Host "Restart PowerShell or run:`n  . `$PROFILE" -ForegroundColor $YELLOW
} else {
    Write-Host "Uninstallation cancelled" -ForegroundColor $YELLOW
    exit 0
}
