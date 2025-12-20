#Requires -Version 5.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installation script for ScanProfileSwitcher application
    
.DESCRIPTION
    This script automates the installation of ScanProfileSwitcher on Windows systems.
    Requires administrator privileges to install fonts and create shortcuts.
    
.PARAMETER TargetPath
    Installation target directory (default: C:\kkh\ScanProfileSwitcher)
    
.PARAMETER SourcePath
    Source directory containing ScanProfileSwitcher files
    
.EXAMPLE
    .\Install-ScanProfileSwitcher.ps1
    
.NOTES
    Version:    1.0.1
    Requires:   Administrator privileges
    Execution:  Admin context
#>

param(
    [string]$TargetPath = 'C:\kkh\ScanProfileSwitcher',
    [string]$SourcePath = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

# ============================================================================
# ERROR HANDLING
# ============================================================================

$ErrorActionPreference = 'Stop'

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script requires administrator privileges" -ForegroundColor Red
    Write-Host "INFO: Please run PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

function Test-SourcePath {
    param([string]$Path)
    
    Write-Host "INFO: Checking source directory: $Path" -ForegroundColor Cyan
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Host "ERROR: Source path does not exist: $Path" -ForegroundColor Red
        exit 1
    }
    
    $requiredFiles = @(
        'ScanProfileSwitcher.ps1',
        'config.json'
    )
    
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path -Path $Path -ChildPath $file
        if (-not (Test-Path -Path $filePath -PathType Leaf)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        Write-Host "ERROR: Missing required files:" -ForegroundColor Red
        $missingFiles | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
        exit 1
    }
    
    Write-Host "SUCCESS: Source directory valid" -ForegroundColor Green
}

function New-TargetDirectory {
    param([string]$Path)
    
    Write-Host "INFO: Creating target directory: $Path" -ForegroundColor Cyan
    
    try {
        if (Test-Path -Path $Path -PathType Container) {
            Write-Host "INFO: Target directory already exists, will overwrite files" -ForegroundColor Yellow
        }
        else {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Host "SUCCESS: Target directory created" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "ERROR: Could not create target directory: $_" -ForegroundColor Red
        exit 1
    }
}

function Copy-ApplicationFiles {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )
    
    Write-Host "INFO: Copying application files..." -ForegroundColor Cyan
    
    try {
        Copy-Item -Path "$SourcePath\*" -Destination $TargetPath -Recurse -Force
        Write-Host "SUCCESS: Files copied successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Could not copy files: $_" -ForegroundColor Red
        exit 1
    }
}

function New-DesktopShortcut {
    param([string]$TargetPath)
    
    Write-Host "INFO: Creating desktop shortcut..." -ForegroundColor Cyan
    
    try {
        $desktopPath = [System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'))
        $shortcutPath = Join-Path -Path $desktopPath -ChildPath 'ScanProfileSwitcher.lnk'
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = 'C:\Windows\System32\conhost.exe'
        $appPath = Join-Path -Path $TargetPath -ChildPath 'ScanProfileSwitcher.ps1'
        $shortcut.Arguments = '--headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "' + $appPath + '"'
        $shortcut.IconLocation = 'C:\Windows\System32\shell32.dll,128'
        $shortcut.WorkingDirectory = $TargetPath
        $shortcut.Save()
        
        Write-Host "SUCCESS: Desktop shortcut created" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: Could not create desktop shortcut: $_" -ForegroundColor Yellow
    }
}

function Set-FilePermissions {
    param([string]$Path)
    
    Write-Host "INFO: Setting file permissions..." -ForegroundColor Cyan
    
    try {
        $acl = Get-Acl -Path $Path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
            'FullControl',
            'ContainerInherit,ObjectInherit',
            'None',
            'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl -Path $Path -AclObject $acl
        
        Write-Host "SUCCESS: File permissions configured" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: Could not set file permissions: $_" -ForegroundColor Yellow
    }
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

Write-Host "`n"
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "ScanProfileSwitcher Installation Script" -ForegroundColor Cyan
Write-Host "Version: 1.0.1" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`n"

# Step 1: Validate source
Test-SourcePath -Path $SourcePath

# Step 2: Create target directory
New-TargetDirectory -Path $TargetPath

# Step 3: Copy files
Copy-ApplicationFiles -SourcePath $SourcePath -TargetPath $TargetPath

# Step 4: Set permissions
Set-FilePermissions -Path $TargetPath

# Step 5: Create desktop shortcut
New-DesktopShortcut -TargetPath $TargetPath

Write-Host "`n"
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "`n"
Write-Host "Installation Summary:" -ForegroundColor Green
Write-Host "   Application Path:  $TargetPath" -ForegroundColor Green
Write-Host "   Desktop Shortcut:  Created" -ForegroundColor Green
Write-Host "`n"
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "   1. Look for 'ScanProfileSwitcher' shortcut on your desktop" -ForegroundColor Green
Write-Host "   2. Double-click to launch the application" -ForegroundColor Green
Write-Host "   3. Select your desired scanner profile" -ForegroundColor Green
Write-Host "   4. Click 'Speichern' (Save) to apply changes" -ForegroundColor Green
Write-Host "`n"
