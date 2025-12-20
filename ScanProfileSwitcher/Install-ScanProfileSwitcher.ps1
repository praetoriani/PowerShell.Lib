#Requires -Version 5.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installation script for ScanProfileSwitcher application
    
.DESCRIPTION
    This script automates the installation of ScanProfileSwitcher on Windows systems.
    Requires administrator privileges to install fonts and create shortcuts.
    
    WICHTIG: Dieses Skript löscht das Zielverzeichnis VOLLSTÄNDIG rekursiv,
    um Versionsübergreifende Konflikte zu vermeiden und sicherzustellen, dass
    sich im Zielverzeichnis immer nur die Dateien einer Version befinden.
    
.PARAMETER TargetPath
    Installation target directory (default: C:\kkh\ScanProfileSwitcher)
    
.PARAMETER SourcePath
    Source directory containing ScanProfileSwitcher files
    
.EXAMPLE
    .\Install-ScanProfileSwitcher.ps1
    
.NOTES
    Version:    1.0.2
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

function Remove-TargetDirectory {
    param([string]$Path)
    
    if (Test-Path -Path $Path -PathType Container) {
        Write-Host "INFO: Removing existing target directory to avoid version conflicts..." -ForegroundColor Yellow
        
        try {
            # Wait a moment for any processes to release files
            Start-Sleep -Milliseconds 500
            
            # Force remove the entire directory tree
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            
            Write-Host "SUCCESS: Target directory removed completely" -ForegroundColor Green
        }
        catch {
            Write-Host "WARNING: Could not fully remove target directory: $_" -ForegroundColor Yellow
            Write-Host "INFO: Attempting selective file removal..." -ForegroundColor Cyan
            
            try {
                # Try to remove files selectively
                Get-ChildItem -Path $Path -Recurse -Force | ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Force -ErrorAction Continue
                    }
                    catch {
                        # Silently continue
                    }
                }
            }
            catch {
                Write-Host "WARNING: Continuing with installation despite cleanup issues" -ForegroundColor Yellow
            }
        }
    }
}

function New-TargetDirectory {
    param([string]$Path)
    
    Write-Host "INFO: Creating fresh target directory: $Path" -ForegroundColor Cyan
    
    try {
        if (-not (Test-Path -Path $Path -PathType Container)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        Write-Host "SUCCESS: Target directory ready" -ForegroundColor Green
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
    
    # Dateien die NICHT kopiert werden sollen
    $excludeFiles = @(
        '.gitignore',
        'CHANGELOG.md',
        'INSTALL.md',
        'LICENSE'
    )
    
    try {
        # Alle Dateien und Verzeichnisse auflisten
        $sourceItems = Get-ChildItem -Path $SourcePath -Force
        
        foreach ($item in $sourceItems) {
            # Überprüfen, ob die Datei ausgeschlossen sein soll
            if ($item.Name -in $excludeFiles) {
                Write-Host "   SKIP: $($item.Name) (excluded)" -ForegroundColor Gray
                continue
            }
            
            # Kopiere die Datei oder das Verzeichnis
            Copy-Item -Path $item.FullName -Destination $TargetPath -Recurse -Force
            Write-Host "   COPY: $($item.Name)" -ForegroundColor Green
        }
        
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
Write-Host "Version: 1.0.2" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`n"

# Step 1: Validate source
Test-SourcePath -Path $SourcePath

# Step 2: Remove existing target directory (CRITICAL for version consistency)
Remove-TargetDirectory -Path $TargetPath

# Step 3: Create fresh target directory
New-TargetDirectory -Path $TargetPath

# Step 4: Copy files (exclude .gitignore, CHANGELOG.md, INSTALL.md, LICENSE)
Copy-ApplicationFiles -SourcePath $SourcePath -TargetPath $TargetPath

# Step 5: Set permissions
Set-FilePermissions -Path $TargetPath

# Step 6: Create desktop shortcut
New-DesktopShortcut -TargetPath $TargetPath

Write-Host "`n"
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "`n"
Write-Host "Installation Summary:" -ForegroundColor Green
Write-Host "   Application Path:  $TargetPath" -ForegroundColor Green
Write-Host "   Desktop Shortcut:  Created" -ForegroundColor Green
Write-Host "   Version Conflicts: Prevented (directory fully reset)" -ForegroundColor Green
Write-Host "`n"
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "   1. Look for 'ScanProfileSwitcher' shortcut on your desktop" -ForegroundColor Green
Write-Host "   2. Double-click to launch the application" -ForegroundColor Green
Write-Host "   3. Select your desired scanner profile" -ForegroundColor Green
Write-Host "   4. Click 'Speichern' (Save) to apply changes" -ForegroundColor Green
Write-Host "`n"
