#Requires -Version 5.0

<#
.SYNOPSIS
    ScanProfileSwitcher - Scanner Profile Management Application
    
.DESCRIPTION
    PowerShell-based GUI application for switching between TWAIN scanner profiles.
    Supports Standard (single-sided) and Duplex (double-sided) scanning configurations.
    
.NOTES
    Version:        1.0.7
    Author:         System Administrator
    Created:        2025-12-20
    Updated:        2025-12-20
    Required:       PowerShell 5.0+, Windows 10/11
    Execution:      User context (No Admin privileges required)
    
.EXAMPLE
    C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1
#>

# ============================================================================
# ASSEMBLY LOADING - MUST BE FIRST!
# ============================================================================

# Load required assemblies BEFORE any type declarations
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName PresentationCore
}
catch {
    Write-Host "FEHLER: Erforderliche .NET Assemblies konnten nicht geladen werden!" -ForegroundColor Red
    Write-Host "System.Windows.* Assemblies sind erforderlich." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================================
# CONSOLE MINIMIZATION VIA P/INVOKE
# ============================================================================

try {
    # Define C# code for Windows API P/Invoke
    $csharpCode = @'
using System;
using System.Runtime.InteropServices;

public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    public static void MinimizeConsole() {
        try {
            IntPtr hWnd = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle;
            ShowWindow(hWnd, 6);
        }
        catch {
            // Silently fail if console cannot be minimized
        }
    }
}
'@
    
    # Compile the C# code
    Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction Stop
    
    # Call the minimization function
    [WindowHelper]::MinimizeConsole()
}
catch {
    Write-Host "Warnung: Console konnte nicht minimiert werden: $_" -ForegroundColor Yellow
    # Non-critical - continue execution
}

# ============================================================================
# GLOBAL VARIABLES & CONFIGURATION
# ============================================================================

# Suppress console output - redirect to error log only
$ErrorActionPreference = 'Stop'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

# Get current logged-in user
[string]$Global:CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($Global:CurrentUser -match '\\(.+)$') {
    $Global:CurrentUser = $Matches[1]
}

# Application paths
[string]$Global:AppRoot = 'C:\kkh\ScanProfileSwitcher'
[string]$Global:GUIPath = Join-Path -Path $Global:AppRoot -ChildPath 'GUI'
[string]$Global:ConfigFile = Join-Path -Path $Global:AppRoot -ChildPath 'config.json'
[string]$Global:ErrorLogFile = Join-Path -Path $Global:AppRoot -ChildPath 'error.log'

# Scanner profile paths
[string]$Global:ScannerProfilePath = "C:\Users\$Global:CurrentUser\AppData\Local\Scanner\Twain"
[string]$Global:ProfileIniName = 'profile.ini'
[string]$Global:ProfileIniStandardName = 'profile.ini.standard'
[string]$Global:ProfileIniDuplexName = 'profile.ini.duplex'

# Full paths for INI files
[string]$Global:ProfileIniPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath $Global:ProfileIniName
[string]$Global:ProfileIniStandardPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath $Global:ProfileIniStandardName
[string]$Global:ProfileIniDuplexPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath $Global:ProfileIniDuplexName

# Global configuration object - MUST BE HASHTABLE, NOT PSCustomObject
[hashtable]$Global:Config = @{}

# UI Windows
[System.Windows.Window]$Global:MainWindow = $null
[System.Windows.Window]$Global:PopupWindow = $null

# Application state
[bool]$Global:HasChanges = $false
[string]$Global:CurrentProfile = 'STANDARD'
[string]$Global:SelectedProfile = 'STANDARD'

# Error messages dictionary
[hashtable]$Global:ErrorMessages = @{
    'CONFIG_LOAD_ERROR'      = 'Die Konfigurations-Datei konnte nicht geladen werden. Das Programm wird beendet.'
    'USER_DETERMINATION_ERROR' = 'Der angemeldete Benutzer konnte nicht ermittelt werden. Das Programm wird beendet.'
    'TWAIN_PATH_NOT_FOUND'   = 'Das Verzeichnis fuer Scanner-Profile konnte nicht gefunden werden. Das Programm wird beendet.'
    'TWAIN_FILES_NOT_FOUND'  = 'Die erforderlichen Scanner-Profil-Dateien wurden nicht gefunden. Das Programm wird beendet.'
    'PROFILE_SWAP_ERROR'     = 'Die Aenderungen am Scanner-Profil konnten nicht gespeichert werden. Das Programm wird beendet.'
    'CONFIG_SAVE_ERROR'      = 'Die Konfiguration konnte nicht gespeichert werden. Das Programm wird beendet.'
    'UNKNOWN_ERROR'          = 'Ein unerwarteter Fehler ist aufgetreten. Das Programm wird beendet.'
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    try {
        $timestamp = Get-Date -Format 'dd.MM.yyyy ; HH:mm:ss'
        $logEntry = "[ $timestamp ] $Message"
        
        if ($ErrorRecord) {
            $logEntry += "`r`n  Exception: $($ErrorRecord.Exception.Message)"
            $logEntry += "`r`n  Script: $($ErrorRecord.InvocationInfo.ScriptName)"
            $logEntry += "`r`n  Line: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        }
        
        Add-Content -Path $Global:ErrorLogFile -Value $logEntry -Force -ErrorAction Stop
    }
    catch {
        # Failsafe: if logging fails, at least try to show error dialog
        Write-Host "Fehler beim Schreiben in Fehlerprotokoll: $_" -ForegroundColor Red
    }
}

function Get-XamlContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XamlFileName
    )
    
    try {
        $xamlPath = Join-Path -Path $Global:GUIPath -ChildPath $XamlFileName
        
        if (-not (Test-Path -Path $xamlPath -PathType Leaf)) {
            throw "XAML-Datei nicht gefunden: $xamlPath"
        }
        
        [xml]$xaml = Get-Content -Path $xamlPath -Raw -ErrorAction Stop
        return $xaml
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Laden der XAML-Datei '$XamlFileName'" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
        exit 1
    }
}

function New-WPFWindow {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$Xaml
    )
    
    try {
        $xmlNodeReader = New-Object System.Xml.XmlNodeReader $Xaml
        $window = [System.Windows.Markup.XamlReader]::Load($xmlNodeReader)
        
        if (-not $window) {
            throw "XamlReader hat null zurueckgegeben"
        }
        
        return $window
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Erstellen des WPF-Fensters" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
        exit 1
    }
}

function Get-ConfigurationFile {
    try {
        if (-not (Test-Path -Path $Global:ConfigFile -PathType Leaf)) {
            throw "Konfigurationsdatei nicht gefunden: $Global:ConfigFile"
        }
        
        $configContent = Get-Content -Path $Global:ConfigFile -Raw -ErrorAction Stop
        $configObject = $configContent | ConvertFrom-Json -ErrorAction Stop
        
        # CRITICAL FIX: Convert PSCustomObject to Hashtable to avoid type conversion errors
        $configHashtable = @{}
        $configObject.PSObject.Properties | ForEach-Object {
            $configHashtable[$_.Name] = $_.Value
        }
        
        return $configHashtable
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Laden der Konfigurationsdatei" -ErrorRecord $_
        throw $_
    }
}

function Set-ConfigurationFile {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Configuration
    )
    
    try {
        # Convert hashtable to object for JSON serialization
        $configObject = New-Object PSObject
        $Configuration.GetEnumerator() | ForEach-Object {
            $configObject | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }
        
        $configJson = $configObject | ConvertTo-Json -Depth 10 -ErrorAction Stop
        Set-Content -Path $Global:ConfigFile -Value $configJson -Force -ErrorAction Stop
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Speichern der Konfigurationsdatei" -ErrorRecord $_
        throw $_
    }
}

function Test-ScannerProfileFiles {
    try {
        $requiredFiles = @(
            $Global:ProfileIniStandardPath,
            $Global:ProfileIniDuplexPath
        )
        
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path -Path $file -PathType Leaf)) {
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler bei der Ueberpruefung der Scanner-Profile" -ErrorRecord $_
        return $false
    }
}

<#
.SYNOPSIS
    Sets window size from configuration dynamically
    
.PARAMETER Window
    The WPF window to resize
    
.PARAMETER WindowKey
    The key in config.json windows section (e.g. 'main-app-win')
#>
function Set-WindowSize {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Window]$Window,
        
        [Parameter(Mandatory=$true)]
        [string]$WindowKey
    )
    
    try {
        # Get window configuration from config
        $windowConfig = $Global:Config['windows']
        
        if ($windowConfig -and $windowConfig[$WindowKey]) {
            $winCfg = $windowConfig[$WindowKey]
            
            # Set width and height from config
            if ($winCfg['width']) {
                $Window.Width = $winCfg['width']
            }
            if ($winCfg['height']) {
                $Window.Height = $winCfg['height']
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Setzen der Fenstergroesse fuer $WindowKey" -ErrorRecord $_
    }
}

# ============================================================================
# DIALOG FUNCTIONS
# ============================================================================

function Show-ErrorDialog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [System.Windows.Window]$OwnerWindow = $null
    )
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-error.xaml'
        $errorWindow = New-WPFWindow -Xaml $xaml
        
        # Apply window sizing from config
        Set-WindowSize -Window $errorWindow -WindowKey 'popup-error'
        
        # Find message text block and set content
        $messageBlock = $errorWindow.FindName('MessageText')
        if ($messageBlock) {
            $messageBlock.Text = $Message
        }
        
        # Find OK button and add click handler
        $okButton = $errorWindow.FindName('OkButton')
        if ($okButton) {
            $okButton.Add_Click({
                $errorWindow.Close()
                exit 1
            })
        }
        
        $errorWindow.Topmost = $true
        
        if ($OwnerWindow) {
            $errorWindow.Owner = $OwnerWindow
        }
        
        [void]$errorWindow.ShowDialog()
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Fehler-Dialogs" -ErrorRecord $_
        exit 1
    }
}

function Show-CloseDialog {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Window]$OwnerWindow
    )
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-close.xaml'
        $closeWindow = New-WPFWindow -Xaml $xaml
        
        # Apply window sizing from config
        Set-WindowSize -Window $closeWindow -WindowKey 'popup-close'
        
        $result = $false
        
        # Wire Yes button
        $yesButton = $closeWindow.FindName('YesButton')
        if ($yesButton) {
            $yesButton.Add_Click({
                $result = $true
                $closeWindow.DialogResult = $true
                $closeWindow.Close()
            })
        }
        
        # Wire No button
        $noButton = $closeWindow.FindName('NoButton')
        if ($noButton) {
            $noButton.Add_Click({
                $result = $false
                $closeWindow.DialogResult = $false
                $closeWindow.Close()
            })
        }
        
        $closeWindow.Owner = $OwnerWindow
        $closeWindow.ShowDialog() | Out-Null
        
        return $closeWindow.DialogResult -eq $true
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Schliessen-Dialogs" -ErrorRecord $_
        return $false
    }
}

function Show-WarningDialog {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Window]$OwnerWindow
    )
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-warn.xaml'
        $warnWindow = New-WPFWindow -Xaml $xaml
        
        # Apply window sizing from config
        Set-WindowSize -Window $warnWindow -WindowKey 'popup-warn'
        
        $result = $false
        
        # Wire Yes button
        $yesButton = $warnWindow.FindName('YesButton')
        if ($yesButton) {
            $yesButton.Add_Click({
                $result = $true
                $warnWindow.DialogResult = $true
                $warnWindow.Close()
            })
        }
        
        # Wire No button
        $noButton = $warnWindow.FindName('NoButton')
        if ($noButton) {
            $noButton.Add_Click({
                $result = $false
                $warnWindow.DialogResult = $false
                $warnWindow.Close()
            })
        }
        
        $warnWindow.Owner = $OwnerWindow
        $warnWindow.ShowDialog() | Out-Null
        
        return $warnWindow.DialogResult -eq $true
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Warnungs-Dialogs" -ErrorRecord $_
        return $false
    }
}

function Show-SaveDialog {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Window]$OwnerWindow
    )
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-save.xaml'
        $saveWindow = New-WPFWindow -Xaml $xaml
        
        # Apply window sizing from config
        Set-WindowSize -Window $saveWindow -WindowKey 'popup-save'
        
        # Wire OK button to close only save dialog and return to main
        $okButton = $saveWindow.FindName('OkButton')
        if ($okButton) {
            $okButton.Add_Click({
                $saveWindow.Close()
                # Return to main window - do NOT close main window
            })
        }
        
        $saveWindow.Owner = $OwnerWindow
        $saveWindow.ShowDialog() | Out-Null
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Speichern-Dialogs" -ErrorRecord $_
    }
}

# ============================================================================
# PROFILE MANAGEMENT FUNCTIONS
# ============================================================================

function Invoke-ProfileSwap {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('STANDARD', 'DUPLEX')]
        [string]$TargetProfile
    )
    
    try {
        # Determine source profile file
        $sourceFile = if ($TargetProfile -eq 'STANDARD') {
            $Global:ProfileIniStandardPath
        } else {
            $Global:ProfileIniDuplexPath
        }
        
        # Read source file content
        $sourceContent = Get-Content -Path $sourceFile -Raw -ErrorAction Stop
        
        # Remove existing profile.ini if it exists
        if (Test-Path -Path $Global:ProfileIniPath -PathType Leaf) {
            Remove-Item -Path $Global:ProfileIniPath -Force -ErrorAction Stop
        }
        
        # Write content to new profile.ini
        Set-Content -Path $Global:ProfileIniPath -Value $sourceContent -Force -ErrorAction Stop
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Austausch des Scanner-Profils ($TargetProfile)" -ErrorRecord $_
        return $false
    }
}

function Update-ProfileConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('STANDARD', 'DUPLEX')]
        [string]$Profile
    )
    
    try {
        # Load current configuration
        $config = Get-ConfigurationFile
        
        # Update profile setting
        $config['currentProfile'] = $Profile
        
        # Save updated configuration
        Set-ConfigurationFile -Configuration $config
        
        # Update global variable
        $Global:CurrentProfile = $Profile
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Aktualisieren der Konfiguration" -ErrorRecord $_
        return $false
    }
}

# ============================================================================
# INITIALIZATION & VALIDATION FUNCTIONS
# ============================================================================

function Invoke-StartupValidation {
    try {
        # Validate configuration file can be loaded
        $config = Get-ConfigurationFile
        if (-not $config -or $config.Count -eq 0) {
            Write-ErrorLog -Message "Konfigurationsdatei konnte nicht geladen werden"
            return $false
        }
        
        # Store config in global variable as HASHTABLE
        $Global:Config = $config
        $Global:CurrentProfile = $config['currentProfile'] -as [string]
        $Global:SelectedProfile = $Global:CurrentProfile
        
        # Validate scanner profile path exists
        if (-not (Test-Path -Path $Global:ScannerProfilePath -PathType Container)) {
            Write-ErrorLog -Message "Scanner-Profilpfad nicht gefunden: $Global:ScannerProfilePath"
            return $false
        }
        
        # Validate all required INI files exist
        if (-not (Test-ScannerProfileFiles)) {
            Write-ErrorLog -Message "Erforderliche Scanner-Profildateien nicht gefunden"
            return $false
        }
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Startup-Validierung" -ErrorRecord $_
        return $false
    }
}

# ============================================================================
# MAIN APPLICATION WINDOW FUNCTIONS
# ============================================================================

function Show-MainWindow {
    try {
        # Load main window XAML
        [xml]$xaml = Get-XamlContent -XamlFileName 'main-app-win.xaml'
        $Global:MainWindow = New-WPFWindow -Xaml $xaml
        
        # Apply window sizing from config DYNAMICALLY
        Set-WindowSize -Window $Global:MainWindow -WindowKey 'main-app-win'
        
        # Get UI controls
        $standardCheckbox = $Global:MainWindow.FindName('StandardCheckbox')
        $duplexCheckbox = $Global:MainWindow.FindName('DuplexCheckbox')
        $saveButton = $Global:MainWindow.FindName('SaveButton')
        $closeButton = $Global:MainWindow.FindName('CloseButton')
        
        # Initialize checkbox states based on current profile
        if ($standardCheckbox -and $duplexCheckbox) {
            if ($Global:CurrentProfile -eq 'STANDARD') {
                $standardCheckbox.IsChecked = $true
                $duplexCheckbox.IsChecked = $false
            } else {
                $standardCheckbox.IsChecked = $false
                $duplexCheckbox.IsChecked = $true
            }
        }
        
        # CRITICAL FIX: Prevent unchecking both checkboxes
        # Wire checkbox UNCHECKED handlers to prevent deselection
        if ($standardCheckbox) {
            $standardCheckbox.Add_Unchecked({
                if (-not $duplexCheckbox.IsChecked) {
                    # Prevent unchecking if duplex is not checked
                    $standardCheckbox.IsChecked = $true
                }
            })
            
            $standardCheckbox.Add_Checked({
                # Uncheck duplex when standard is checked
                $duplexCheckbox.IsChecked = $false
                if ($Global:SelectedProfile -ne 'STANDARD') {
                    $Global:SelectedProfile = 'STANDARD'
                    $Global:HasChanges = $true
                }
            })
        }
        
        if ($duplexCheckbox) {
            $duplexCheckbox.Add_Unchecked({
                if (-not $standardCheckbox.IsChecked) {
                    # Prevent unchecking if standard is not checked
                    $duplexCheckbox.IsChecked = $true
                }
            })
            
            $duplexCheckbox.Add_Checked({
                # Uncheck standard when duplex is checked
                $standardCheckbox.IsChecked = $false
                if ($Global:SelectedProfile -ne 'DUPLEX') {
                    $Global:SelectedProfile = 'DUPLEX'
                    $Global:HasChanges = $true
                }
            })
        }
        
        # Wire Save button
        if ($saveButton) {
            $saveButton.Add_Click({
                if ($Global:HasChanges) {
                    # Attempt profile swap
                    if (Invoke-ProfileSwap -TargetProfile $Global:SelectedProfile) {
                        # Update configuration
                        if (Update-ProfileConfiguration -Profile $Global:SelectedProfile) {
                            $Global:HasChanges = $false
                            Show-SaveDialog -OwnerWindow $Global:MainWindow
                        } else {
                            Write-ErrorLog -Message "Fehler beim Speichern der Konfiguration"
                            Show-ErrorDialog -Message $Global:ErrorMessages['CONFIG_SAVE_ERROR'] -OwnerWindow $Global:MainWindow
                        }
                    } else {
                        Write-ErrorLog -Message "Fehler beim Austausch des Scanner-Profils"
                        Show-ErrorDialog -Message $Global:ErrorMessages['PROFILE_SWAP_ERROR'] -OwnerWindow $Global:MainWindow
                    }
                }
            })
        }
        
        # Wire Close button - check for unsaved changes
        if ($closeButton) {
            $closeButton.Add_Click({
                if ($Global:HasChanges) {
                    # Show warning dialog if changes exist
                    if (Show-WarningDialog -OwnerWindow $Global:MainWindow) {
                        # User confirmed to close without saving
                        $Global:MainWindow.Close()
                    }
                    # If user clicked No, don't close
                } else {
                    # No changes - close immediately
                    $Global:MainWindow.Close()
                }
            })
        }
        
        # Wire window close button (X button in title bar)
        $Global:MainWindow.Add_Closing({
            param($sender, $e)
            
            if ($Global:HasChanges) {
                $e.Cancel = $true
                if (Show-WarningDialog -OwnerWindow $Global:MainWindow) {
                    $e.Cancel = $false
                }
            }
        })
        
        # Show main window
        $Global:MainWindow.ShowDialog() | Out-Null
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Anzeigen des Hauptfensters" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
    }
}

# ============================================================================
# MAIN FUNCTION - ORCHESTRATES APPLICATION FLOW
# ============================================================================

function Invoke-ScanProfileSwitcher {
    try {
        # Remove old error log if it exists
        if (Test-Path -Path $Global:ErrorLogFile -PathType Leaf) {
            Remove-Item -Path $Global:ErrorLogFile -Force -ErrorAction SilentlyContinue
        }
        
        # ========================================================================
        # PHASE 1: STARTUP VALIDATION
        # ========================================================================
        
        # Validate all requirements
        if (-not (Invoke-StartupValidation)) {
            # Determine which error occurred and show appropriate message
            if (-not (Test-Path -Path $Global:ConfigFile -PathType Leaf)) {
                Show-ErrorDialog -Message $Global:ErrorMessages['CONFIG_LOAD_ERROR']
            } elseif (-not (Test-Path -Path $Global:ScannerProfilePath -PathType Container)) {
                Show-ErrorDialog -Message $Global:ErrorMessages['TWAIN_PATH_NOT_FOUND']
            } elseif (-not (Test-ScannerProfileFiles)) {
                Show-ErrorDialog -Message $Global:ErrorMessages['TWAIN_FILES_NOT_FOUND']
            } else {
                Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
            }
            exit 1
        }
        
        # ========================================================================
        # PHASE 2: DISPLAY MAIN APPLICATION WINDOW
        # ========================================================================
        
        Show-MainWindow
    }
    catch {
        Write-ErrorLog -Message "Kritischer Fehler in Hauptanwendung" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
        exit 1
    }
}

# ============================================================================
# APPLICATION ENTRY POINT
# ============================================================================

# Execute main application
Invoke-ScanProfileSwitcher
