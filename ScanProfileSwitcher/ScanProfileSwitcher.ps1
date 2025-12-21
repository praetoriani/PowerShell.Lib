#Requires -Version 5.0

<#
.SYNOPSIS
    ScanProfileSwitcher - Scanner Profile Management Application
    
.DESCRIPTION
    PowerShell-based GUI application for switching between TWAIN scanner profiles.
    Supports Standard (single-sided) and Duplex (double-sided) scanning configurations.
    
.NOTES
    Version:        1.1.1
    Author:         System Administrator
    Created:        2025-12-20
    Updated:        2025-12-21
    Required:       PowerShell 5.0+, Windows 10/11
    Execution:      User context (No Admin privileges required)
    
.EXAMPLE
    C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1
#>

# ============================================================================
# ASSEMBLY LOADING - MUST BE FIRST!
# ============================================================================

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName PresentationCore
}
catch {
    Write-Host "FEHLER: Erforderliche .NET Assemblies konnten nicht geladen werden!" -ForegroundColor Red
    exit 1
}

# ============================================================================
# CONSOLE MINIMIZATION VIA P/INVOKE
# ============================================================================

try {
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
            // Silently fail
        }
    }
}
'@
    
    Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction Stop
    [WindowHelper]::MinimizeConsole()
}
catch {
    # Non-critical
}

# ============================================================================
# GLOBAL VARIABLES & CONFIGURATION
# ============================================================================

<#
    PowerShell Execution Preferences - COMPREHENSIVE EXPLANATION:
    
    $ErrorActionPreference = 'Stop'
        - IMPACT: Immediately terminates script execution when ANY error occurs
        - USE CASE: Ensures critical failures don't go unnoticed
        - BEHAVIOR: Throws terminating errors that are caught by try-catch blocks
        - ALTERNATIVE: 'Continue' would ignore errors, 'SilentlyContinue' suppresses output
    
    $InformationPreference = 'SilentlyContinue'
        - IMPACT: Suppresses Write-Information output messages
        - USE CASE: Keeps console/logs clean from non-critical informational messages
        - BEHAVIOR: Write-Information calls produce no output
        - NOTE: Only affects Write-Information, not Write-Host
    
    $ProgressPreference = 'SilentlyContinue'
        - IMPACT: Suppresses progress bar output from long-running cmdlets
        - USE CASE: Copy-Item, Download operations, file transfers show progress by default
        - BEHAVIOR: Prevents progress UI rendering, improves performance
        - NOTE: Also suppresses Write-Progress calls
    
    $WarningPreference = 'SilentlyContinue'
        - IMPACT: Suppresses Write-Warning output messages
        - USE CASE: Keeps console clean from warnings that don't require user action
        - BEHAVIOR: Write-Warning calls produce no output
        - ALTERNATIVE: 'Continue' would display warnings, 'Inquire' would prompt
    
    $VerbosePreference = 'SilentlyContinue'
        - IMPACT: Suppresses Write-Verbose output messages
        - USE CASE: Hide detailed debugging/tracing information from normal users
        - BEHAVIOR: Write-Verbose calls produce no output
        - USER CONTROL: User can override with -Verbose parameter on function calls
        - DEVELOPMENT: Set to 'Continue' temporarily for debugging
#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

[string]$Global:CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($Global:CurrentUser -match '\\(.+)$') {
    $Global:CurrentUser = $Matches[1]
}

[string]$Global:AppRoot = 'C:\kkh\ScanProfileSwitcher'
[string]$Global:GUIPath = Join-Path -Path $Global:AppRoot -ChildPath 'GUI'
[string]$Global:ConfigFile = Join-Path -Path $Global:AppRoot -ChildPath 'config.json'
[string]$Global:ErrorLogFile = Join-Path -Path $Global:AppRoot -ChildPath 'error.log'

[string]$Global:ScannerProfilePath = "C:\Users\$Global:CurrentUser\AppData\Local\Scanner\Twain"
[string]$Global:ProfileIniPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath 'profile.ini'
[string]$Global:ProfileIniStandardPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath 'profile.ini.standard'
[string]$Global:ProfileIniDuplexPath = Join-Path -Path $Global:ScannerProfilePath -ChildPath 'profile.ini.duplex'

[hashtable]$Global:Config = @{}
[System.Windows.Window]$Global:MainWindow = $null

[bool]$Global:HasChanges = $false
[bool]$Global:IsClosingFromButton = $false
[bool]$Global:IsExiting = $false
[string]$Global:CurrentProfile = 'STANDARD'
[string]$Global:SelectedProfile = 'STANDARD'

[hashtable]$Global:ErrorMessages = @{
    'CONFIG_LOAD_ERROR'         = 'Die Konfigurations-Datei config.json konnte&#x0a;nicht erfolgreich geladen/verarbeitet werden!&#x0a;Das Programm wird jetzt beendet.'
    'USER_DETERMINATION_ERROR'  = 'Der angemeldete Windows-Benutzer konnte&#x0a;nicht eindeutig/zuverlässig ermittelt werden!&#x0a;Das Programm wird jetzt beendet.'
    'TWAIN_PATH_NOT_FOUND'      = 'Es existiert kein Verzeichnis für Scanner-Profile!&#x0a;Ein gültiger TWAIN-Treiber MUSS installiert sein!&#x0a;Das Programm wird jetzt beendet.'
    'TWAIN_FILES_NOT_FOUND'     = 'Die erforderlichen Profil-Dateien (ini-Dateien)&#x0a;existieren nicht im Ordner für Scanner-Profile!&#x0a;Das Programm wird jetzt beendet.'
    'PROFILE_SWAP_ERROR'        = 'Während dem Speichern des Scanner-Profils&#x0a;ist ein schwerer Laufzeit-Fehler aufgetreten!&#x0a;Das Programm wird jetzt beendet.'
    'CONFIG_SAVE_ERROR'         = 'Während dem Speichern der config.json-Datei&#x0a;ist ein schwerer Laufzeit-Fehler aufgetreten!&#x0a;Das Programm wird jetzt beendet.'
    'UNKNOWN_ERROR'             = 'Ein unbekannter Laufzeit-Fehler ist aufgetreten!&#x0a;Das Programm wird jetzt beendet.'
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
        $logEntry = "[$timestamp]  $Message"
        if ($ErrorRecord) {
            $logEntry += "`r`n  Exception: $($ErrorRecord.Exception.Message)"
        }
        Add-Content -Path $Global:ErrorLogFile -Value $logEntry -Force -ErrorAction Stop
    }
    catch {
        # Failsafe
    }
}

function Get-XamlContent {
    param([Parameter(Mandatory=$true)][string]$XamlFileName)
    
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
        exit 1
    }
}

function New-WPFWindow {
    param([Parameter(Mandatory=$true)][xml]$Xaml)
    
    try {
        $xmlNodeReader = New-Object System.Xml.XmlNodeReader $Xaml
        $window = [System.Windows.Markup.XamlReader]::Load($xmlNodeReader)
        return $window
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Erstellen des WPF-Fensters" -ErrorRecord $_
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
        
        $configHashtable = @{}
        $configObject.PSObject.Properties | ForEach-Object {
            # Konvertiere auch verschachtelte Objekte zu Hashtables
            if ($_.Value -is [System.Management.Automation.PSCustomObject]) {
                $innerHashtable = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $innerHashtable[$_.Name] = $_.Value
                }
                $configHashtable[$_.Name] = $innerHashtable
            } else {
                $configHashtable[$_.Name] = $_.Value
            }
        }
        
        return $configHashtable
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Laden der Konfigurationsdatei" -ErrorRecord $_
        throw $_
    }
}

function Set-ConfigurationFile {
    param([Parameter(Mandatory=$true)][hashtable]$Configuration)
    
    try {
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
        if (-not (Test-Path -Path $Global:ProfileIniStandardPath -PathType Leaf) -or
            -not (Test-Path -Path $Global:ProfileIniDuplexPath -PathType Leaf)) {
            return $false
        }
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler bei der Ueberpruefung der Scanner-Profile" -ErrorRecord $_
        return $false
    }
}

function Set-WindowSize {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Window]$Window,
        
        [Parameter(Mandatory=$true)]
        [string]$WindowKey
    )
    
    try {
        # Hole die Konfiguration - KRITISCH: Nutze Hashtable direkt!
        $windows = $Global:Config['windows']
        
        if ($windows -and $windows[$WindowKey]) {
            $winCfg = $windows[$WindowKey]
            
            # RIGOROUS: Setze Width und Height EXPLIZIT
            if ($null -ne $winCfg['width']) {
                $Window.Width = [double]$winCfg['width']
            }
            if ($null -ne $winCfg['height']) {
                $Window.Height = [double]$winCfg['height']
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Setzen der Fenstergroesse fuer $WindowKey" -ErrorRecord $_
    }
}

# ============================================================================
# DIALOG FUNCTIONS (VEREINFACHT)
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
        Set-WindowSize -Window $errorWindow -WindowKey 'popup-error'
        
        $messageBlock = $errorWindow.FindName('MessageText')
        if ($messageBlock) { $messageBlock.Text = $Message }
        
        $okButton = $errorWindow.FindName('OkButton')
        if ($okButton) {
            $okButton.Add_Click({ $errorWindow.Close(); exit 1 })
        }
        
        $errorWindow.Topmost = $true
        if ($OwnerWindow) { $errorWindow.Owner = $OwnerWindow }
        [void]$errorWindow.ShowDialog()
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Fehler-Dialogs" -ErrorRecord $_
        exit 1
    }
}

function Show-CloseDialog {
    param([Parameter(Mandatory=$true)][System.Windows.Window]$OwnerWindow)
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-close.xaml'
        $closeWindow = New-WPFWindow -Xaml $xaml
        Set-WindowSize -Window $closeWindow -WindowKey 'popup-close'
        
        $yesButton = $closeWindow.FindName('YesButton')
        if ($yesButton) { $yesButton.Add_Click({ $closeWindow.DialogResult = $true; $closeWindow.Close() }) }
        
        $noButton = $closeWindow.FindName('NoButton')
        if ($noButton) { $noButton.Add_Click({ $closeWindow.DialogResult = $false; $closeWindow.Close() }) }
        
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
    param([Parameter(Mandatory=$true)][System.Windows.Window]$OwnerWindow)
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-warn.xaml'
        $warnWindow = New-WPFWindow -Xaml $xaml
        Set-WindowSize -Window $warnWindow -WindowKey 'popup-warn'
        
        $yesButton = $warnWindow.FindName('YesButton')
        if ($yesButton) { $yesButton.Add_Click({ $warnWindow.DialogResult = $true; $warnWindow.Close() }) }
        
        $noButton = $warnWindow.FindName('NoButton')
        if ($noButton) { $noButton.Add_Click({ $warnWindow.DialogResult = $false; $warnWindow.Close() }) }
        
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
    param([Parameter(Mandatory=$true)][System.Windows.Window]$OwnerWindow)
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-save.xaml'
        $saveWindow = New-WPFWindow -Xaml $xaml
        Set-WindowSize -Window $saveWindow -WindowKey 'popup-save'
        
        $okButton = $saveWindow.FindName('OkButton')
        if ($okButton) { $okButton.Add_Click({ $saveWindow.Close() }) }
        
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
    param([Parameter(Mandatory=$true)][ValidateSet('STANDARD', 'DUPLEX')][string]$TargetProfile)
    
    try {
        $sourceFile = if ($TargetProfile -eq 'STANDARD') { $Global:ProfileIniStandardPath } else { $Global:ProfileIniDuplexPath }
        $sourceContent = Get-Content -Path $sourceFile -Raw -ErrorAction Stop
        
        if (Test-Path -Path $Global:ProfileIniPath -PathType Leaf) {
            Remove-Item -Path $Global:ProfileIniPath -Force -ErrorAction Stop
        }
        
        Set-Content -Path $Global:ProfileIniPath -Value $sourceContent -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Austausch des Scanner-Profils ($TargetProfile)" -ErrorRecord $_
        return $false
    }
}

function Update-ProfileConfiguration {
    param([Parameter(Mandatory=$true)][ValidateSet('STANDARD', 'DUPLEX')][string]$Profile)
    
    try {
        $config = Get-ConfigurationFile
        $config['currentProfile'] = $Profile
        Set-ConfigurationFile -Configuration $config
        $Global:CurrentProfile = $Profile
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Aktualisieren der Konfiguration" -ErrorRecord $_
        return $false
    }
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Invoke-StartupValidation {
    try {
        $config = Get-ConfigurationFile
        if (-not $config -or $config.Count -eq 0) {
            Write-ErrorLog -Message "Konfigurationsdatei konnte nicht geladen werden"
            return $false
        }
        
        $Global:Config = $config
        $Global:CurrentProfile = $config['currentProfile'] -as [string]
        $Global:SelectedProfile = $Global:CurrentProfile
        
        if (-not (Test-Path -Path $Global:ScannerProfilePath -PathType Container)) {
            Write-ErrorLog -Message "Scanner-Profilpfad nicht gefunden: $Global:ScannerProfilePath"
            return $false
        }
        
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
# MAIN WINDOW
# ============================================================================

function Show-MainWindow {
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'main-app-win.xaml'
        $Global:MainWindow = New-WPFWindow -Xaml $xaml
        
        # RIGOROUS: Setze Fenstergrößen EXPLIZIT von config.json
        Set-WindowSize -Window $Global:MainWindow -WindowKey 'main-app-win'
        
        $standardCheckbox = $Global:MainWindow.FindName('StandardCheckbox')
        $duplexCheckbox = $Global:MainWindow.FindName('DuplexCheckbox')
        $saveButton = $Global:MainWindow.FindName('SaveButton')
        $exitButton = $Global:MainWindow.FindName('CloseButton')
        
        if ($standardCheckbox -and $duplexCheckbox) {
            if ($Global:CurrentProfile -eq 'STANDARD') {
                $standardCheckbox.IsChecked = $true
                $duplexCheckbox.IsChecked = $false
            } else {
                $standardCheckbox.IsChecked = $false
                $duplexCheckbox.IsChecked = $true
            }
        }
        
        if ($standardCheckbox) {
            $standardCheckbox.Add_Unchecked({
                if (-not $duplexCheckbox.IsChecked) { $standardCheckbox.IsChecked = $true }
            })
            $standardCheckbox.Add_Checked({
                $duplexCheckbox.IsChecked = $false
                if ($Global:SelectedProfile -ne 'STANDARD') {
                    $Global:SelectedProfile = 'STANDARD'
                    $Global:HasChanges = $true
                }
            })
        }
        
        if ($duplexCheckbox) {
            $duplexCheckbox.Add_Unchecked({
                if (-not $standardCheckbox.IsChecked) { $duplexCheckbox.IsChecked = $true }
            })
            $duplexCheckbox.Add_Checked({
                $standardCheckbox.IsChecked = $false
                if ($Global:SelectedProfile -ne 'DUPLEX') {
                    $Global:SelectedProfile = 'DUPLEX'
                    $Global:HasChanges = $true
                }
            })
        }
        
        if ($saveButton) {
            $saveButton.Add_Click({
                if ($Global:HasChanges) {
                    if (Invoke-ProfileSwap -TargetProfile $Global:SelectedProfile) {
                        if (Update-ProfileConfiguration -Profile $Global:SelectedProfile) {
                            $Global:HasChanges = $false
                            Show-SaveDialog -OwnerWindow $Global:MainWindow
                        }
                    } else {
                        Show-ErrorDialog -Message $Global:ErrorMessages['PROFILE_SWAP_ERROR'] -OwnerWindow $Global:MainWindow
                    }
                }
            })
        }
        
        # SCENARIO 1 & 2: Exit Button Handler (Beenden-Button im Hauptfenster)
        if ($exitButton) {
            $exitButton.Add_Click({
                $Global:IsClosingFromButton = $true
                
                if ($Global:HasChanges) {
                    # Szenario 2: Änderungen gemacht → popup-warn.xaml anzeigen
                    if (Show-WarningDialog -OwnerWindow $Global:MainWindow) {
                        # Benutzer hat "Ja" geklickt → Programm schließen
                        $Global:IsExiting = $true
                        $Global:MainWindow.Close()
                    }
                    # Falls "Nein" → Fenster bleibt offen
                } else {
                    # Szenario 1: Keine Änderungen → Programm sofort schließen
                    $Global:IsExiting = $true
                    $Global:MainWindow.Close()
                }
                
                $Global:IsClosingFromButton = $false
            })
        }
        
        # SCENARIO 1 & 2: Title Bar Close Button Handler (Schließen-Button in der Titelleiste)
        $Global:MainWindow.Add_Closing({
            param($sender, $e)
            
            # Nur wenn das Programm nicht ohnehin beendet wird
            if (-not $Global:IsExiting) {
                # Wenn nicht vom Exit-Button aufgerufen
                if (-not $Global:IsClosingFromButton) {
                    if ($Global:HasChanges) {
                        # Szenario 2: Änderungen gemacht → popup-close.xaml anzeigen
                        $e.Cancel = $true
                        if (Show-CloseDialog -OwnerWindow $Global:MainWindow) {
                            # Benutzer hat "Ja" geklickt → Fenster schließen lassen
                            $Global:IsExiting = $true
                            $e.Cancel = $false
                        }
                        # Falls "Nein" → e.Cancel = $true bleibt, Fenster bleibt offen
                    } else {
                        # Szenario 1: Keine Änderungen → Programm ohne Rückfrage schließen
                        $e.Cancel = $false
                        $Global:IsExiting = $true
                    }
                }
            }
            
            # Wenn IsExiting gesetzt ist und Close aufgerufen wurde, einfach durchlassen
            if ($Global:IsExiting) {
                $e.Cancel = $false
            }
        })
        
        $Global:MainWindow.ShowDialog() | Out-Null
        
        # Sauberer Exit nach ShowDialog
        exit 0
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Anzeigen des Hauptfensters" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
        exit 1
    }
}

# ============================================================================
# MAIN
# ============================================================================

function Invoke-ScanProfileSwitcher {
    try {
        if (Test-Path -Path $Global:ErrorLogFile -PathType Leaf) {
            Remove-Item -Path $Global:ErrorLogFile -Force -ErrorAction SilentlyContinue
        }
        
        if (-not (Invoke-StartupValidation)) {
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
        
        Show-MainWindow
    }
    catch {
        Write-ErrorLog -Message "Kritischer Fehler in Hauptanwendung" -ErrorRecord $_
        Show-ErrorDialog -Message $Global:ErrorMessages['UNKNOWN_ERROR']
        exit 1
    }
}

Invoke-ScanProfileSwitcher
