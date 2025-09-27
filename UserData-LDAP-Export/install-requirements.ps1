<#
.SYNOPSIS
    RSAT ActiveDirectory Module Installation Script
.DESCRIPTION
    Installiert die erforderlichen ActiveDirectory PowerShell-Module fuer verschiedene Windows-Versionen
.NOTES
    Creation Date:  21.09.2025
    Version:        1.01.00
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
#>

#Requires -RunAsAdministrator

function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )

    $color = switch ($Status) {
        "ERROR"   { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO"    { "Cyan" }
        default   { "White" }
    }

    Write-Host "[$Status] $Message" -ForegroundColor $color
}

# Header ausgeben
Write-Status "=== RSAT ActiveDirectory Module Installation ===" "INFO"
Write-Status "This script will install the required ActiveDirectory PowerShell module" "INFO"

# Betriebssystem ermitteln
$osVersion = [System.Environment]::OSVersion.Version
$registryPath = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$windowsVersion = (Get-ItemProperty $registryPath).ProductName

Write-Status "Detected OS: $windowsVersion" "INFO"
Write-Status "OS Version: $($osVersion.Major).$($osVersion.Minor)" "INFO"

# Pruefe ob bereits installiert
Write-Status "Checking for existing ActiveDirectory module..." "INFO"
$adModule = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue

if ($adModule) {
    Write-Status "ActiveDirectory module is already installed!" "SUCCESS"
    Write-Status "Module Version: $($adModule.Version)" "INFO"
    Write-Status "Module Path: $($adModule.ModuleBase)" "INFO"

    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -notmatch "^[Yy]") {
        Write-Status "Installation cancelled by user" "WARNING"
        exit 0
    }
} else {
    Write-Status "ActiveDirectory module not found - installation required" "WARNING"
}

# Pruefe Administrator-Rechte
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Status "This script requires Administrator privileges!" "ERROR"
    Write-Status "Please run PowerShell as Administrator and try again." "ERROR"
    Read-Host "Press any key to exit"
    exit 1
}

# Installation basierend auf Windows-Version
Write-Status "Starting installation process..." "INFO"

try {
    if ($osVersion.Major -ge 10) {
        # Windows 10/11 Installation
        Write-Status "Installing ActiveDirectory tools via Windows Capabilities..." "INFO"

        # Pruefe verfuegbare Capabilities
        $capabilities = Get-WindowsCapability -Online -Name "*ActiveDirectory*"
        $adCapability = $capabilities | Where-Object { $_.Name -like "*DS-LDS*" }

        if ($adCapability) {
            Write-Status "Found capability: $($adCapability.Name)" "INFO"
            Write-Status "Current state: $($adCapability.State)" "INFO"

            if ($adCapability.State -eq "Installed") {
                Write-Status "ActiveDirectory capability is already installed!" "SUCCESS"
            } else {
                Write-Status "Installing ActiveDirectory capability..." "INFO"
                Add-WindowsCapability -Online -Name $adCapability.Name
                Write-Status "ActiveDirectory capability installed successfully!" "SUCCESS"
            }
        } else {
            Write-Status "Specific capability not found, trying direct installation..." "WARNING"
            Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
            Write-Status "ActiveDirectory tools installed via direct capability name!" "SUCCESS"
        }
    } elseif ($windowsVersion -like "*Server*") {
        # Windows Server Installation
        Write-Status "Installing ActiveDirectory PowerShell module via Windows Features..." "INFO"

        $feature = Get-WindowsFeature -Name "RSAT-AD-PowerShell" -ErrorAction SilentlyContinue

        if ($feature -and $feature.InstallState -eq "Installed") {
            Write-Status "RSAT-AD-PowerShell feature is already installed!" "SUCCESS"
        } else {
            Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
            Write-Status "RSAT-AD-PowerShell feature installed successfully!" "SUCCESS"
        }
    } else {
        # Aeltere Windows-Versionen
        Write-Status "Unsupported Windows version for automatic installation!" "ERROR"
        Write-Status "Please download RSAT manually from Microsoft Download Center" "INFO"
        Read-Host "Press any key to exit"
        exit 1
    }
} catch {
    Write-Status "Installation failed: $($_.Exception.Message)" "ERROR"
    Write-Status "Please try manual installation or contact your administrator" "ERROR"
    Read-Host "Press any key to exit"
    exit 1
}

# Verifikation der Installation
Write-Status "Verifying installation..." "INFO"
$adModuleCheck = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue

if ($adModuleCheck) {
    Write-Status "ActiveDirectory module found!" "SUCCESS"
    Write-Status "Version: $($adModuleCheck.Version)" "INFO"
    Write-Status "Path: $($adModuleCheck.ModuleBase)" "INFO"

    try {
        # Teste Import
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Status "ActiveDirectory module imported successfully!" "SUCCESS"

        # Teste grundlegende Funktionalitaet
        $testCommand = Get-Command Get-ADUser -ErrorAction Stop
        Write-Status "Get-ADUser command available!" "SUCCESS"

        Write-Status "" "INFO"
        Write-Status "=== INSTALLATION COMPLETED SUCCESSFULLY ===" "SUCCESS"
        Write-Status "The UserData-LDAP-Export.ps1 script should now work properly!" "SUCCESS"
    } catch {
        Write-Status "Module verification failed: $($_.Exception.Message)" "ERROR"
        Write-Status "The module was installed but may not be working correctly" "WARNING"
        Write-Status "Please reboot your computer and try again" "WARNING"
    }
} else {
    Write-Status "ActiveDirectory module not found after installation!" "ERROR"
    Write-Status "Installation may have failed or requires a reboot" "WARNING"
}

Write-Status "" "INFO"
Write-Status "Installation process completed." "INFO"
Read-Host "Press any key to exit"
