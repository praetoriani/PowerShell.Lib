#Requires -Version 5.0

<#
.SYNOPSIS
    ScanProfileSwitcher - Scanner Profile Management Application
    
.DESCRIPTION
    PowerShell-based GUI application for switching between TWAIN scanner profiles.
    Supports Standard (single-sided) and Duplex (double-sided) scanning configurations.
    
.NOTES
    Version:        1.1.3
    Author:         System Administrator
    Created:        2025-12-20
    Updated:        2025-12-21
    Required:       PowerShell 5.0+, Windows 10/11
    Execution:      User context (No Admin privileges required)
    
.EXAMPLE
    C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1
    C:\Windows\System32\conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1"
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
    
    Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction SilentlyContinue
    [WindowHelper]::MinimizeConsole()
}
catch {
    # Non-critical
}

# ============================================================================
# GLOBAL VARIABLES & CONFIGURATION
# ============================================================================

$ErrorActionPreference = 'Continue'
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
[string]$Global:OriginalProfile = 'STANDARD'
[string]$Global:CurrentProfile = 'STANDARD'
[string]$Global:SelectedProfile = 'STANDARD'

# Error messages with proper newlines
[hashtable]$Global:ErrorMessages = @{
    'CONFIG_LOAD_ERROR'         = @(
        'Die Konfigurations-Datei config.json konnte',
        'nicht erfolgreich geladen/verarbeitet werden!',
        'Das Programm wird jetzt beendet.'
    )
    'USER_DETERMINATION_ERROR'  = @(
        'Der angemeldete Windows-Benutzer konnte',
        'nicht eindeutig/zuverlässig ermittelt werden!',
        'Das Programm wird jetzt beendet.'
    )
    'TWAIN_PATH_NOT_FOUND'      = @(
        'Es existiert kein Verzeichnis für Scanner-Profile!',
        'Ein gültiger TWAIN-Treiber MUSS installiert sein!',
        'Das Programm wird jetzt beendet.'
    )
    'TWAIN_FILES_NOT_FOUND'     = @(
        'Die erforderlichen Profil-Dateien (ini-Dateien)',
        'existieren nicht im Ordner für Scanner-Profile!',
        'Das Programm wird jetzt beendet.'
    )
    'PROFILE_SWAP_ERROR'        = @(
        'Während dem Speichern des Scanner-Profils',
        'ist ein schwerer Laufzeit-Fehler aufgetreten!',
        'Das Programm wird jetzt beendet.'
    )
    'CONFIG_SAVE_ERROR'         = @(
        'Während dem Speichern der config.json-Datei',
        'ist ein schwerer Laufzeit-Fehler aufgetreten!',
        'Das Programm wird jetzt beendet.'
    )
    'UNKNOWN_ERROR'             = @(
        'Ein unbekannter Laufzeit-Fehler ist aufgetreten!',
        'Das Programm wird jetzt beendet.'
    )
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
        Add-Content -Path $Global:ErrorLogFile -Value $logEntry -Force -ErrorAction SilentlyContinue
    }
    catch {
        # Failsafe
    }
}

function Format-ErrorMessage {
    param([Parameter(Mandatory=$true)][string]$ErrorKey)
    
    try {
        if ($Global:ErrorMessages.ContainsKey($ErrorKey)) {
            $lines = $Global:ErrorMessages[$ErrorKey]
            if ($lines -is [array]) {
                return $lines -join "`n"
            }
            return $lines
        }
        return $Global:ErrorMessages['UNKNOWN_ERROR'] -join "`n"
    }
    catch {
        return 'Ein Fehler ist aufgetreten.'
    }
}

function Set-HasChanges {
    $Global:HasChanges = ($Global:SelectedProfile -ne $Global:OriginalProfile)
}

function Get-XamlContent {
    param([Parameter(Mandatory=$true)][string]$XamlFileName)
    
    try {
        $xamlPath = Join-Path -Path $Global:GUIPath -ChildPath $XamlFileName
        if (-not (Test-Path -Path $xamlPath -PathType Leaf)) {
            Write-ErrorLog -Message "XAML-Datei nicht gefunden: $xamlPath"
            return $null
        }
        [xml]$xaml = Get-Content -Path $xamlPath -Raw -ErrorAction SilentlyContinue
        return $xaml
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Laden der XAML-Datei '$XamlFileName'" -ErrorRecord $_
        return $null
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
        return $null
    }
}

function Get-ConfigurationFile {
    try {
        if (-not (Test-Path -Path $Global:ConfigFile -PathType Leaf)) {
            Write-ErrorLog -Message "Konfigurationsdatei nicht gefunden: $Global:ConfigFile"
            return $null
        }
        
        $configContent = Get-Content -Path $Global:ConfigFile -Raw -ErrorAction SilentlyContinue
        if (-not $configContent) {
            Write-ErrorLog -Message "Konfigurationsdatei ist leer: $Global:ConfigFile"
            return $null
        }
        
        $configObject = $configContent | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $configObject) {
            Write-ErrorLog -Message "Konfigurationsdatei konnte nicht als JSON geparst werden"
            return $null
        }
        
        $configHashtable = @{}
        $configObject.PSObject.Properties | ForEach-Object {
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
        return $null
    }
}

function Set-ConfigurationFile {
    param([Parameter(Mandatory=$true)][hashtable]$Configuration)
    
    try {
        $configObject = New-Object PSObject
        $Configuration.GetEnumerator() | ForEach-Object {
            $configObject | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }
        $configJson = $configObject | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue
        Set-Content -Path $Global:ConfigFile -Value $configJson -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Speichern der Konfigurationsdatei" -ErrorRecord $_
        return $false
    }
}

function Test-ScannerProfileFiles {
    try {
        if ((Test-Path -Path $Global:ProfileIniStandardPath -PathType Leaf) -and
            (Test-Path -Path $Global:ProfileIniDuplexPath -PathType Leaf)) {
            return $true
        }
        Write-ErrorLog -Message "Scanner-Profildateien nicht vorhanden"
        return $false
    }
    catch {
        Write-ErrorLog -Message "Fehler bei der Überprüfung der Scanner-Profile" -ErrorRecord $_
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
        $windows = $Global:Config['windows']
        if ($windows -and $windows[$WindowKey]) {
            $winCfg = $windows[$WindowKey]
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
# DIALOG FUNCTIONS - TWO STRATEGIES FOR GUARANTEED CLEAN EXIT
# ============================================================================

function Show-ErrorDialog-Startup {
    param([Parameter(Mandatory=$true)][string]$Message)
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-error.xaml'
        if (-not $xaml) { exit 1 }
        
        $errorWindow = New-WPFWindow -Xaml $xaml
        if (-not $errorWindow) { exit 1 }
        
        Set-WindowSize -Window $errorWindow -WindowKey 'popup-error'
        
        $messageBlock = $errorWindow.FindName('MessageText')
        if ($messageBlock) { $messageBlock.Text = $Message }
        
        $okButton = $errorWindow.FindName('OkButton')
        if ($okButton) { $okButton.Add_Click({ $errorWindow.Close() }) }
        
        $errorWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $errorWindow.Topmost = $true
        
        [void]$errorWindow.ShowDialog()
        exit 1
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Fehler-Dialogs (Startup)" -ErrorRecord $_
        exit 1
    }
}

function Show-ErrorDialog-Runtime {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][System.Windows.Window]$OwnerWindow = $null
    )
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-error.xaml'
        if (-not $xaml) { [System.Windows.Application]::Current.Shutdown(1); exit 1 }
        
        $errorWindow = New-WPFWindow -Xaml $xaml
        if (-not $errorWindow) { [System.Windows.Application]::Current.Shutdown(1); exit 1 }
        
        Set-WindowSize -Window $errorWindow -WindowKey 'popup-error'
        
        $messageBlock = $errorWindow.FindName('MessageText')
        if ($messageBlock) { $messageBlock.Text = $Message }
        
        $okButton = $errorWindow.FindName('OkButton')
        if ($okButton) { $okButton.Add_Click({ $errorWindow.Close() }) }
        
        $errorWindow.Topmost = $true
        if ($OwnerWindow) {
            $errorWindow.Owner = $OwnerWindow
            $errorWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
        } else {
            $errorWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        }
        
        [void]$errorWindow.ShowDialog()
        [System.Windows.Application]::Current.Shutdown(1)
    }
    catch {
        Write-ErrorLog -Message "Fehler bei Anzeige des Fehler-Dialogs (Runtime)" -ErrorRecord $_
        [System.Windows.Application]::Current.Shutdown(1)
    }
}

function Show-CloseDialog {
    param([Parameter(Mandatory=$true)][System.Windows.Window]$OwnerWindow)
    
    try {
        [xml]$xaml = Get-XamlContent -XamlFileName 'popup-close.xaml'
        if (-not $xaml) { return $false }
        
        $closeWindow = New-WPFWindow -Xaml $xaml
        if (-not $closeWindow) { return $false }
        
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
        if (-not $xaml) { return $false }
        
        $warnWindow = New-WPFWindow -Xaml $xaml
        if (-not $warnWindow) { return $false }
        
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
        if (-not $xaml) { return }
        
        $saveWindow = New-WPFWindow -Xaml $xaml
        if (-not $saveWindow) { return }
        
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
        
        if (-not (Test-Path -Path $sourceFile -PathType Leaf)) {
            Write-ErrorLog -Message "Quelldatei nicht vorhanden: $sourceFile"
            return $false
        }
        
        $sourceContent = Get-Content -Path $sourceFile -Raw -ErrorAction SilentlyContinue
        
        if (-not $sourceContent) {
            Write-ErrorLog -Message "Quelldatei leer oder nicht lesbar: $sourceFile"
            return $false
        }
        
        if (Test-Path -Path $Global:ProfileIniPath -PathType Leaf) {
            Remove-Item -Path $Global:ProfileIniPath -Force -ErrorAction SilentlyContinue
        }
        
        Set-Content -Path $Global:ProfileIniPath -Value $sourceContent -Force -ErrorAction SilentlyContinue
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
        if (-not $config) {
            Write-ErrorLog -Message "Fehler: Konfigurationsdatei konnte nicht für Speichern gelesen werden"
            return $false
        }
        
        $config['currentProfile'] = $Profile
        if (Set-ConfigurationFile -Configuration $config) {
            $Global:CurrentProfile = $Profile
            return $true
        }
        
        Write-ErrorLog -Message "Fehler: Konfigurationsdatei konnte nicht geschrieben werden"
        return $false
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Speichern der Konfiguration" -ErrorRecord $_
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
        $Global:OriginalProfile = $config['currentProfile'] -as [string]
        $Global:CurrentProfile = $Global:OriginalProfile
        $Global:SelectedProfile = $Global:OriginalProfile
        
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
        if (-not $xaml) {
            Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'UNKNOWN_ERROR')
            return
        }
        
        $Global:MainWindow = New-WPFWindow -Xaml $xaml
        if (-not $Global:MainWindow) {
            Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'UNKNOWN_ERROR')
            return
        }
        
        Set-WindowSize -Window $Global:MainWindow -WindowKey 'main-app-win'
        
        $standardCheckbox = $Global:MainWindow.FindName('StandardCheckbox')
        $duplexCheckbox = $Global:MainWindow.FindName('DuplexCheckbox')
        $saveButton = $Global:MainWindow.FindName('SaveButton')
        $exitButton = $Global:MainWindow.FindName('CloseButton')
        
        if ($standardCheckbox -and $duplexCheckbox) {
            if ($Global:OriginalProfile -eq 'STANDARD') {
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
                $Global:SelectedProfile = 'STANDARD'
                Set-HasChanges
            })
        }
        
        if ($duplexCheckbox) {
            $duplexCheckbox.Add_Unchecked({
                if (-not $standardCheckbox.IsChecked) { $duplexCheckbox.IsChecked = $true }
            })
            $duplexCheckbox.Add_Checked({
                $standardCheckbox.IsChecked = $false
                $Global:SelectedProfile = 'DUPLEX'
                Set-HasChanges
            })
        }
        
        if ($saveButton) {
            $saveButton.Add_Click({
                if ($Global:HasChanges) {
                    if (-not (Invoke-ProfileSwap -TargetProfile $Global:SelectedProfile)) {
                        Write-ErrorLog -Message "Fehler beim Speichern: Scanner-Profil konnte nicht getauscht werden"
                        Show-ErrorDialog-Runtime -Message (Format-ErrorMessage -ErrorKey 'PROFILE_SWAP_ERROR') -OwnerWindow $Global:MainWindow
                        return
                    }
                    
                    if (-not (Update-ProfileConfiguration -Profile $Global:SelectedProfile)) {
                        Write-ErrorLog -Message "Fehler beim Speichern: Konfiguration konnte nicht geschrieben werden"
                        Show-ErrorDialog-Runtime -Message (Format-ErrorMessage -ErrorKey 'CONFIG_SAVE_ERROR') -OwnerWindow $Global:MainWindow
                        return
                    }
                    
                    $Global:OriginalProfile = $Global:SelectedProfile
                    $Global:HasChanges = $false
                    Show-SaveDialog -OwnerWindow $Global:MainWindow
                }
            })
        }
        
        if ($exitButton) {
            $exitButton.Add_Click({
                $Global:IsClosingFromButton = $true
                
                if ($Global:HasChanges) {
                    if (Show-WarningDialog -OwnerWindow $Global:MainWindow) {
                        $Global:IsExiting = $true
                        $Global:MainWindow.Close()
                    }
                } else {
                    $Global:IsExiting = $true
                    $Global:MainWindow.Close()
                }
                
                $Global:IsClosingFromButton = $false
            })
        }
        
        $Global:MainWindow.Add_Closing({
            param($sender, $e)
            
            if (-not $Global:IsExiting -and -not $Global:IsClosingFromButton) {
                if ($Global:HasChanges) {
                    $e.Cancel = $true
                    if (Show-CloseDialog -OwnerWindow $Global:MainWindow) {
                        $Global:IsExiting = $true
                        $e.Cancel = $false
                    }
                } else {
                    $e.Cancel = $false
                    $Global:IsExiting = $true
                }
            }
            
            if ($Global:IsExiting) {
                $e.Cancel = $false
            }
        })
        
        [void]$Global:MainWindow.ShowDialog()
        exit 0
    }
    catch {
        Write-ErrorLog -Message "Fehler beim Anzeigen des Hauptfensters" -ErrorRecord $_
        Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'UNKNOWN_ERROR')
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
                Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'CONFIG_LOAD_ERROR')
            } elseif (-not (Test-Path -Path $Global:ScannerProfilePath -PathType Container)) {
                Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'TWAIN_PATH_NOT_FOUND')
            } elseif (-not (Test-ScannerProfileFiles)) {
                Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'TWAIN_FILES_NOT_FOUND')
            } else {
                Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'UNKNOWN_ERROR')
            }
            return
        }
        
        Show-MainWindow
    }
    catch {
        Write-ErrorLog -Message "Kritischer Fehler in Hauptanwendung" -ErrorRecord $_
        Show-ErrorDialog-Startup -Message (Format-ErrorMessage -ErrorKey 'UNKNOWN_ERROR')
    }
}

Invoke-ScanProfileSwitcher
