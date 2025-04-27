# Araise Package Manager PowerShell CLI

# Base paths
$SCRIPT_DIR = $PSScriptRoot
if (-not $SCRIPT_DIR) {
    $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $SCRIPT_DIR) {
    $SCRIPT_DIR = $PWD.Path
}

$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$ARAISE_DIR = Join-Path $env:USERPROFILE ".araise"
$FORGE_ORG = "Araise25"
$FORGE_REPO = "arAIse_PM"

# Colors for output
$RED = [System.ConsoleColor]::Red
$GREEN = [System.ConsoleColor]::Green
$YELLOW = [System.ConsoleColor]::Yellow
$BLUE = [System.ConsoleColor]::Blue
$MAGENTA = [System.ConsoleColor]::Magenta
$CYAN = [System.ConsoleColor]::Cyan
$NC = [System.ConsoleColor]::White
$BOLD = [System.ConsoleColor]::White

# Create necessary directories
New-Item -ItemType Directory -Force -Path "$ARAISE_DIR\packages" | Out-Null

# Function to detect if we're in development mode
function Test-DevelopmentMode {
    return (Test-Path (Join-Path $PROJECT_ROOT "common\packages.json"))
}

# Function to show help
function Show-Help {
    Write-Host "Araise Package Manager" -ForegroundColor $MAGENTA
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
    Write-Host "Usage:" -ForegroundColor $BOLD
    Write-Host "  araise [package]           - Run installed package (will install if not present)" -ForegroundColor $GREEN
    Write-Host "  araise install [package]   - Install a package" -ForegroundColor $GREEN
    Write-Host "  araise uninstall [package] - Uninstall a package" -ForegroundColor $GREEN
    Write-Host "  araise list                - List installed packages" -ForegroundColor $GREEN
    Write-Host "  araise update              - Update package list" -ForegroundColor $GREEN
    Write-Host "  araise available           - Show available packages" -ForegroundColor $GREEN
    Write-Host "  araise help                - Show this help message" -ForegroundColor $GREEN
    Write-Host "  uninstall-araise          - Remove Araise Package Manager" -ForegroundColor $RED
    if (Test-DevelopmentMode) {
        Write-Host "  araise test                - Run local tests" -ForegroundColor $GREEN
    }
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
}

# Function to show process control information
function Show-ProcessControlInfo {
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
    Write-Host "Process Control Information:" -ForegroundColor $YELLOW
    Write-Host " Ctrl + C" -ForegroundColor $BOLD -NoNewline
    Write-Host "   - Stop the process" -ForegroundColor $NC
    Write-Host " Ctrl + Z" -ForegroundColor $BOLD -NoNewline
    Write-Host "   - Suspend the process" -ForegroundColor $NC
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
}

# Function to get user confirmation with Y as default
function Get-UserConfirmation {
    param (
        [string]$prompt
    )
    Write-Host "$prompt (Y/n) [Enter = Y]: " -ForegroundColor $GREEN -NoNewline
    $response = Read-Host
    return [string]::IsNullOrEmpty($response) -or $response -match '^[Yy]'
}

# Function to show local packages
function Show-LocalPackages {
    Write-Host "Available Local Packages" -ForegroundColor $MAGENTA
    Write-Host "------------------------------------------" -ForegroundColor $CYAN

    if (Test-Path $LOCAL_PACKAGES) {
        $packages = Get-Content $LOCAL_PACKAGES | ConvertFrom-Json
        if ($packages.packages.Count -eq 0) {
            Write-Host "No packages available in local registry!" -ForegroundColor $YELLOW
        }
        else {
            foreach ($package in $packages.packages) {
                Write-Host "* $($package.name) v$($package.version)" -ForegroundColor $GREEN
                Write-Host "  Description: $($package.description)" -ForegroundColor $WHITE
                Write-Host "------------------------------------------" -ForegroundColor $CYAN
            }
        }
    }
    else {
        Write-Host "Local package registry not found at: $LOCAL_PACKAGES" -ForegroundColor $YELLOW
    }

    Write-Host "------------------------------------------" -ForegroundColor $CYAN
}

# Function to list installed packages
function List-Packages {
    Write-Host "Installed Packages" -ForegroundColor $MAGENTA -BackgroundColor $BOLD
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
    
    $installed = $false
    Get-ChildItem "$ARAISE_DIR\packages" -Directory | ForEach-Object {
        Write-Host "* $($_.Name)" -ForegroundColor $GREEN
        $installed = $true
    }
    
    if (-not $installed) {
        Write-Host "No packages installed yet!" -ForegroundColor $YELLOW
    }
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
}

function Install-Package {
    param (
        [string]$packageName
    )

    Write-Host "Installing package: $packageName" -ForegroundColor $YELLOW

    if (Test-DevelopmentMode) {
        $packagesFile = $LOCAL_PACKAGES
    } else {
        $packagesFile = Join-Path $ARAISE_DIR "packages.json"
    }

    # Initialize progress bar
    $progress = @{
        Activity = "Installing $packageName"
        Status = "Initializing..."
        PercentComplete = 0
    }
    Write-Progress @progress

    if (-not (Test-PackageExists $packageName)) {
        $progress.Status = "Checking package registry..."
        Write-Progress @progress
        Write-Host "Package $packageName not found in registry" -ForegroundColor $YELLOW
        if (-not (Test-DevelopmentMode)) {
            if (Get-UserConfirmation "Would you like to update the package registry?") {
                if (Update-Packages) {
                    if (Test-PackageExists $packageName) {
                        Write-Host "Package $packageName is now available!" -ForegroundColor $GREEN
                    } else {
                        Write-Progress -Activity "Installing $packageName" -Completed
                        Write-Host "ERROR: Package $packageName not found even after update!" -ForegroundColor $RED
                        return $false
                    }
                } else {
                    Write-Progress -Activity "Installing $packageName" -Completed
                    Write-Host "ERROR: Failed to update registry" -ForegroundColor $RED
                    return $false
                }
            } else {
                Write-Progress -Activity "Installing $packageName" -Completed
                Write-Host "Installation cancelled" -ForegroundColor $YELLOW
                return $false
            }
        }
    }

    $progress.PercentComplete = 20
    $progress.Status = "Checking installation location..."
    Write-Progress @progress

    $packageDir = Join-Path $ARAISE_DIR "packages\$packageName"
    if (Test-Path $packageDir) {
        Write-Host "WARNING: A folder for $packageName already exists at:" -ForegroundColor $YELLOW
        Write-Host "  $packageDir" -ForegroundColor $CYAN
        if (Get-UserConfirmation "Do you want to delete and reinstall it?") {
            try {
                $progress.Status = "Removing existing installation..."
                Write-Progress @progress
                Remove-Item -Recurse -Force $packageDir
                Write-Host "Old package folder removed." -ForegroundColor $GREEN
            } catch {
                Write-Progress -Activity "Installing $packageName" -Completed
                Write-Host "ERROR: Failed to delete existing package folder!" -ForegroundColor $RED
                Write-Host "Details: $_" -ForegroundColor $YELLOW
                return $false
            }
        } else {
            Write-Progress -Activity "Installing $packageName" -Completed
            Write-Host "Installation cancelled by user." -ForegroundColor $YELLOW
            return $false
        }
    }

    $progress.PercentComplete = 40
    $progress.Status = "Loading package data..."
    Write-Progress @progress

    $packageData = (Get-Content $packagesFile | ConvertFrom-Json).packages |
        Where-Object { $_.name -eq $packageName }

    $installCmds = $null
    if ($packageData.installCommand) {
        if ($packageData.installCommand.windows) {
            $installCmds = $packageData.installCommand.windows
            Write-Host "Using Windows-specific installation commands" -ForegroundColor $CYAN
        } else {
            Write-Progress -Activity "Installing $packageName" -Completed
            Write-Host "ERROR: No Windows installation commands found for package" -ForegroundColor $RED
            Write-Host "This package may not be compatible with Windows" -ForegroundColor $YELLOW
            return $false
        }
    }

    $progress.PercentComplete = 50
    $progress.Status = "Creating package directory..."
    Write-Progress @progress

    $currentLocation = Get-Location
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
    Set-Location -Path $packageDir

    try {
        $cmdCount = $installCmds.Count
        for ($i = 0; $i -lt $cmdCount; $i++) {
            $cmd = $installCmds[$i]
            $progress.PercentComplete = 50 + (($i + 1) / $cmdCount * 50)
            $progress.Status = "Executing command $($i + 1) of $cmdCount..."
            Write-Progress @progress

            if ($cmd) {
                Write-Host "Executing: $cmd" -ForegroundColor $YELLOW
        
                # Check if the command is a PowerShell built-in command or alias
                $cmdName = ($cmd -split ' ')[0] 
                $isBuiltInCmd = $null -ne (Get-Command $cmdName -ErrorAction SilentlyContinue -CommandType Cmdlet,Function,Alias)
        
                if ($isBuiltInCmd) {
                    # Execute PowerShell built-in commands directly
                    try {
                        Invoke-Expression $cmd
                        if ($LASTEXITCODE -ne 0) {
                            Write-Host "ERROR: Installation command failed - $cmd" -ForegroundColor $RED
                            Write-Host "Command exited with code $LASTEXITCODE" -ForegroundColor $YELLOW
                            Set-Location -Path $currentLocation
                            Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
                            return $false
                        }
                    }
                    catch {
                        Write-Host "ERROR: Installation command failed - $cmd" -ForegroundColor $RED
                        Write-Host "Details: $_" -ForegroundColor $YELLOW
                        Set-Location -Path $currentLocation
                        Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
                        return $false
                    }
                } else {
                    # For external commands use Start-Process
                    $parts = $cmd -split ' ', 2
                    $exe = $parts[0]
                    $argsString = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            
                    $process = Start-Process -FilePath $exe -ArgumentList $argsString -NoNewWindow -Wait -PassThru -RedirectStandardOutput "stdout.log" -RedirectStandardError "stderr.log"
            
                    if ($process.ExitCode -ne 0) {
                        $stdout = Get-Content "stdout.log" -Raw
                        $stderr = Get-Content "stderr.log" -Raw
                        Write-Host "ERROR: Installation command failed - $cmd" -ForegroundColor $RED
                        Write-Host "STDOUT:`n$stdout" -ForegroundColor $WHITE
                        Write-Host "STDERR:`n$stderr" -ForegroundColor $YELLOW
                        Write-Host "Directory: $packageDir" -ForegroundColor $YELLOW
                        Set-Location -Path $currentLocation
                        Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
                        return $false
                    }
                }
            }
        }

        Write-Progress -Activity "Installing $packageName" -Completed
        Write-Host "Installation completed successfully!" -ForegroundColor $GREEN
        return $true
    }
    catch {
        Write-Progress -Activity "Installing $packageName" -Completed
        Write-Host "ERROR: Installation failed!" -ForegroundColor $RED
        Write-Host "Details: $_" -ForegroundColor $YELLOW
        return $false
    }
    finally {
        Set-Location -Path $currentLocation
    }
}

# Function to run a package
function Run-Package {
    param (
        [string]$packageName
    )
    
    $packageDir = Join-Path $ARAISE_DIR "packages\$packageName"
    
    if (-not (Test-Path $packageDir)) {
        Write-Host "Package $packageName is not installed" -ForegroundColor $YELLOW
        if (Get-UserConfirmation "Would you like to install it now?") {
            Write-Host "Installing $packageName..." -ForegroundColor $CYAN
            if (-not (Install-Package $packageName)) {
                Write-Host "Installation failed. Cannot run package." -ForegroundColor $RED
                return $false
            }
            Write-Host "`nInstallation successful! Now attempting to run the package..." -ForegroundColor $GREEN
        } else {
            Write-Host "Operation cancelled. Please install the package first using:" -ForegroundColor $YELLOW
            Write-Host "  araise install $packageName" -ForegroundColor $CYAN
            return $false
        }
    }
    
    if (Test-DevelopmentMode) {
        $packagesFile = $LOCAL_PACKAGES
    } else {
        $packagesFile = Join-Path $ARAISE_DIR "packages.json"
    }
    
    if (-not (Test-Path $packagesFile)) {
        Write-Host "ERROR: Package registry not found!" -ForegroundColor $RED
        Write-Host "Try running 'araise update' to fix this" -ForegroundColor $YELLOW
        return $false
    }
    
    $packageData = (Get-Content $packagesFile | ConvertFrom-Json).packages | 
        Where-Object { $_.name -eq $packageName }
    
    if (-not $packageData) {
        Write-Host "ERROR: Package $packageName not found in registry!" -ForegroundColor $RED
        Write-Host "Try running 'araise update' to refresh the package list" -ForegroundColor $YELLOW
        return $false
    }
    
    # Get platform-specific commands
    $runCmds = $null
    if ($packageData.commands) {
        if ($packageData.commands.windows) {
            $runCmds = $packageData.commands.windows
            Write-Host "Using Windows-specific commands" -ForegroundColor $CYAN
        } else {
            Write-Host "ERROR: No Windows-specific commands found for $packageName" -ForegroundColor $RED
            Write-Host "This package may not be compatible with Windows" -ForegroundColor $YELLOW
            return $false
        }
    } else {
        Write-Host "ERROR: No commands defined for $packageName" -ForegroundColor $RED
        return $false
    }
    
    Write-Host "`nReady to run package: $packageName" -ForegroundColor $YELLOW
    if ($packageData.description) {
        Write-Host "Description: $($packageData.description)" -ForegroundColor $CYAN
    }
    Show-ProcessControlInfo
    if (-not (Get-UserConfirmation "`nContinue?")) {
        Write-Host "Operation cancelled by user" -ForegroundColor $YELLOW
        return $false
    }
    
    Write-Host "`nRunning package: $packageName" -ForegroundColor $YELLOW
    Push-Location $packageDir
    try {
        foreach ($cmd in $runCmds) {
            if ($cmd) {
                Write-Host "Executing: $cmd" -ForegroundColor $YELLOW
                $output = Invoke-Expression $cmd 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $errorMsg = if ($output) { $output } else { "Command exited with code $LASTEXITCODE" }
                    Write-Host "ERROR: Command failed - $cmd" -ForegroundColor $RED
                    Write-Host "Details: $errorMsg" -ForegroundColor $YELLOW
                    Write-Host "Directory: $packageDir" -ForegroundColor $YELLOW
                    return $false
                }
            }
        }
        return $true
    }
    catch {
        Write-Host "ERROR: Command failed" -ForegroundColor $RED
        Write-Host "Details: $_" -ForegroundColor $YELLOW
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor $YELLOW
        Write-Host "Directory: $packageDir" -ForegroundColor $YELLOW
        return $false
    }
    finally {
        Pop-Location
    }
}

# Function to uninstall a package
function Uninstall-Package {
    param (
        [string]$packageName
    )
    
    $packageDir = "$ARAISE_DIR\packages\$packageName"
    
    if (-not (Test-Path $packageDir)) {
        Write-Host "ERROR: Package $packageName not installed!" -ForegroundColor $RED
        return $false
    }
    
    Write-Host "Uninstalling $packageName" -ForegroundColor $YELLOW
    Remove-Item -Recurse -Force $packageDir
    Write-Host "SUCCESS: Package uninstalled successfully!" -ForegroundColor $GREEN
}

# Function to show available packages
function Show-AvailablePackages {
    Write-Host "Available Packages" -ForegroundColor $MAGENTA -BackgroundColor $BOLD
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
    
    if (Test-DevelopmentMode) {
        $packagesFile = $LOCAL_PACKAGES
    } else {
        $packagesFile = "$ARAISE_DIR\packages.json"
    }
    
    if (-not (Test-Path $packagesFile)) {
        Write-Host "No packages available!" -ForegroundColor $YELLOW
        Write-Host "Please run 'araise update' to update the registry" -ForegroundColor $CYAN
        Write-Host "------------------------------------------" -ForegroundColor $CYAN
        return $false
    }
    
    $content = Get-Content $packagesFile -Raw
    Write-Host ($content.Substring(0, [Math]::Min(100, $content.Length))) -ForegroundColor $CYAN
    
    try {
        $packages = Get-Content $packagesFile | ConvertFrom-Json
        Write-Host "Debug: JSON parsed successfully" -ForegroundColor $YELLOW
        Write-Host "Debug: Found $($packages.packages.Count) packages" -ForegroundColor $YELLOW
    }
    catch {
        Write-Host "ERROR: Invalid packages.json file" -ForegroundColor $RED
        Write-Host "Debug: JSON parsing error: $_" -ForegroundColor $YELLOW
        Write-Host "Please run 'araise update' to fix the registry" -ForegroundColor $CYAN
        Write-Host "------------------------------------------" -ForegroundColor $CYAN
        return $false
    }

    if ($packages.packages.Count -eq 0) {
        Write-Host "Package registry is empty" -ForegroundColor $YELLOW
        Write-Host "Please run 'araise update' to update the registry" -ForegroundColor $CYAN
        Write-Host "------------------------------------------" -ForegroundColor $CYAN
        return $false
    }

    # Show Apps
    Write-Host "`nApplications:" -ForegroundColor $YELLOW
    $apps = $packages.packages | Where-Object { $_.type -eq "app" }
    Write-Host "Debug: Found $($apps.Count) apps" -ForegroundColor $YELLOW
    if ($apps) {
        $apps | ForEach-Object {
            Write-Host "  * $($_.name) - $($_.description)" -ForegroundColor $GREEN
        }
    } else {
        Write-Host "  No applications available" -ForegroundColor $CYAN
    }
    
    Write-Host "`nWeb Applications:" -ForegroundColor $YELLOW
    $webapps = $packages.packages | Where-Object { $_.type -eq "webapp" }
    Write-Host "Debug: Found $($webapps.Count) web apps" -ForegroundColor $YELLOW
    if ($webapps) {
        $webapps | ForEach-Object {
            Write-Host "  * $($_.name) - $($_.description) [$($_.url)]" -ForegroundColor $GREEN
        }
    } else {
        Write-Host "  No web applications available" -ForegroundColor $CYAN
    }
    
    Write-Host "------------------------------------------" -ForegroundColor $CYAN
}

# Function to update packages
function Update-Packages {
    if (Test-DevelopmentMode) {
        $localPackagesJson = Join-Path $PROJECT_ROOT "common\packages.json"
        if (Test-Path $localPackagesJson) {
            Copy-Item -Path $localPackagesJson -Destination "$ARAISE_DIR\packages.json" -Force
            Write-Host "Use araise available to list available packages" -ForegroundColor $GREEN
            Write-Host "SUCCESS: Package registry updated from local files!" -ForegroundColor $GREEN
            return $true
        } else {
            Write-Host "ERROR: Local packages.json not found at: $localPackagesJson" -ForegroundColor $RED
            return $false
        }
    }
    
    $packagesFile = "$ARAISE_DIR\packages.json"
    $remoteUrl = "https://raw.githubusercontent.com/$FORGE_ORG/$FORGE_REPO/main/common/packages.json"
    $tempFile = "$env:TEMP\packages.json.tmp"
    
    Write-Host "Updating package registry..." -ForegroundColor $YELLOW

    
    try {
        # Create ARAISE_DIR if it doesn't exist
        if (-not (Test-Path $ARAISE_DIR)) {
            New-Item -ItemType Directory -Force -Path $ARAISE_DIR | Out-Null
        }

        # Download to temp file first
        $ProgressPreference = 'SilentlyContinue'  # Speeds up download
        Invoke-WebRequest -Uri $remoteUrl -OutFile $tempFile

        # Verify the downloaded content
        $content = Get-Content $tempFile -Raw
        try {
            $json = $content | ConvertFrom-Json
            
            # Verify expected structure
            if (-not $json.packages) {
                throw "Invalid JSON structure: 'packages' property not found"
            }

            # If validation successful, move to final location
            Move-Item -Path $tempFile -Destination $packagesFile -Force
            Write-Host "SUCCESS: Package registry updated!" -ForegroundColor $GREEN
            return $true
        }
        catch {
            Write-Host "ERROR: Invalid JSON content received" -ForegroundColor $RED
            Write-Host "Debug: First 100 characters of content:" -ForegroundColor $YELLOW
            Write-Host ($content.Substring(0, [Math]::Min(100, $content.Length))) -ForegroundColor $CYAN
            Write-Host "JSON Error: $_" -ForegroundColor $RED
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    catch {
        Write-Host "ERROR: Failed to update package registry" -ForegroundColor $RED
        Write-Host "Network Error: $_" -ForegroundColor $RED
        Write-Host "Debug: HTTP Request failed to: $remoteUrl" -ForegroundColor $YELLOW
        
        # Clean up temp file if it exists
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'  # Reset preference
    }
}

# Function to test if package exists in registry
function Test-PackageExists {
    param (
        [string]$packageName
    )
    
    $packagesFile = if (Test-DevelopmentMode) {
        $LOCAL_PACKAGES
    } else {
        Join-Path $ARAISE_DIR "packages.json"
    }
    
    if (-not (Test-Path $packagesFile)) {
        return $false
    }
    
    try {
        $packages = Get-Content $packagesFile | ConvertFrom-Json
        return ($null -ne ($packages.packages | Where-Object { $_.name -eq $packageName }))
    }
    catch {
        Write-Host "ERROR: Failed to parse packages.json" -ForegroundColor $RED
        Write-Host "Debug: $_" -ForegroundColor $YELLOW
        return $false
    }
}

# Main command handling
$command = if ($args.Count -gt 0) { $args[0] } else { $null }

if (-not $command) {
    Show-Help
    exit 0
}
# Handle no arguments case
if (-not $command) {
    Show-Help
    exit 0
}

# Process commands
switch ($command.ToLower()) {
    "help" { 
        Show-Help 
    }
    "install" {
        if ($args.Length -lt 2) {
            Write-Host "ERROR: Package name required" -ForegroundColor $RED
            Write-Host "Usage: araise install <package-name>" -ForegroundColor $YELLOW
            exit 1
        }
        Install-Package $args[1]
    }
    "uninstall" {
        if ($args.Length -lt 2) {
            Write-Host "ERROR: Package name required" -ForegroundColor $RED
            Write-Host "Usage: araise uninstall <package-name>" -ForegroundColor $YELLOW
            exit 1
        }
        Uninstall-Package $args[1]
    }
    "list" { List-Packages }
    "update" { Update-Packages }
    "available" { Show-AvailablePackages }
    "test" {
        if (Test-DevelopmentMode) {
            Run-Tests
        } else {
            Write-Host "Test command only available in development mode" -ForegroundColor $RED
        }
    }
    default {
        # Try to run package
        $packageDir = Join-Path $ARAISE_DIR "packages\$command"
        if (-not (Test-Path $packageDir)) {
            Write-Host "Package $command is not installed" -ForegroundColor $YELLOW
            if (Get-UserConfirmation "Would you like to install it now?") {
                if (Install-Package $command) {
                    Run-Package $command
                }
            } else {
                Write-Host "Operation cancelled" -ForegroundColor $YELLOW
            }
        } else {
            Run-Package $command
        }
    }
}