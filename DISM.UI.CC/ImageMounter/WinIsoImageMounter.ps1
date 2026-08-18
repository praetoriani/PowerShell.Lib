<#
.SYNOPSIS
    WinISO Image Mounter v1.00.00 - Mounts a Windows Image (*.wim) file into a
    target directory using DISM, presented through a PowerEdge-style dark WPF UI.

.DESCRIPTION
    WinISO Image Mounter opens a single, non-resizable, always-centered WPF
    window (frameless, custom title bar, close button only) that lets the
    user pick a *.wim file and a target mount directory, then mounts the
    image via "DISM /Mount-Wim" inside a separate, visible console window.

    Every UI text is loaded from an external JSON language file
    (data\lang\<code>.json, default: en-us.json) and the entire window layout
    is loaded from an external XAML file (data\ui\main.window.xml) - no
    inline XAML and no hardcoded UI strings exist anywhere in this script.

    Validation errors are NOT shown as message boxes. Instead, the affected
    input field simply turns red (see Show-FieldError in data\fxlib\Functions.ps1)
    until the user provides a valid value.

.PARAMETER Language
    Optional language code (e.g. "en-us", "de-de"). Defaults to the value
    configured in data\config.json ("defaultlanguage"), which itself
    defaults to "en-us".

.EXAMPLE
    .\WinIsoImageMounter.ps1

.EXAMPLE
    .\WinIsoImageMounter.ps1 -Language de-de

.NOTES
    Creation Date: 18.08.2026
    Version:       1.00.00
    Author:        praetoriani

    REQUIREMENTS:
    - PowerShell 5.1 or higher (PowerShell 7.x recommended - see Select-MountFolder
      in Functions.ps1 for why 7.x gives the more modern folder-picker dialog)
    - .NET Framework 4.7.2+ / .NET 5+ (for WPF)
    - Windows ADK / Windows itself must provide DISM.exe (included by default
      on all Windows 10/11 client and server editions)
    - Administrative privileges are required for "DISM /Mount-Wim" to succeed
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Language = ""
)

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL PATH CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
$global:approot   = $PSScriptRoot
$global:appicon   = Join-Path $PSScriptRoot "WinIsoImageMounter.ico"
$configFile       = Join-Path $PSScriptRoot "data\config.json"

# ─────────────────────────────────────────────────────────────────────────────
# LOAD CONFIGURATION (data\config.json)
# ─────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $configFile)) {
    Write-Error "WinIsoImageMounter: Configuration file not found: $configFile"
    exit 1
}

try {
    $global:AppConfig = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Error "WinIsoImageMounter: Failed to parse config.json: $($_.Exception.Message)"
    exit 1
}

$global:uipath   = Join-Path $PSScriptRoot $global:AppConfig.appcore.uidata
$global:langpath = Join-Path $PSScriptRoot $global:AppConfig.appcore.langdata
$global:fxpath   = Join-Path $PSScriptRoot $global:AppConfig.appcore.fxdata
$global:mainwin  = Join-Path $global:uipath "main.window.xml"
$global:wimIndex = $global:AppConfig.dism.wimIndex

if ([string]::IsNullOrWhiteSpace($Language)) {
    $Language = $global:AppConfig.appconfig.defaultlanguage
}

# ─────────────────────────────────────────────────────────────────────────────
# DOT-SOURCE EXTERNAL FUNCTION LIBRARY (data\fxlib) - same pattern as PowerEdge
# ─────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $global:fxpath)) {
    Write-Error "WinIsoImageMounter: Function library directory not found: $global:fxpath"
    exit 1
}

Get-ChildItem -Path $global:fxpath -Filter "*.ps1" | ForEach-Object {
    try {
        . $_.FullName
    }
    catch {
        Write-Error "WinIsoImageMounter: Failed to dot-source $($_.Name): $($_.Exception.Message)"
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MINIMIZE THE CONSOLE WINDOW IMMEDIATELY (P/Invoke, same pattern as PowerEdge)
# ─────────────────────────────────────────────────────────────────────────────
Set-ConsoleWindowState -Mode 6   # 6 = SW_MINIMIZE

# ─────────────────────────────────────────────────────────────────────────────
# LOAD WPF ASSEMBLIES
# ─────────────────────────────────────────────────────────────────────────────
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xml

# ─────────────────────────────────────────────────────────────────────────────
# LOAD LANGUAGE TABLE (data\lang\<code>.json)
# ─────────────────────────────────────────────────────────────────────────────
try {
    $lang = Get-LanguageTable -LangDirectory $global:langpath -LanguageCode $Language
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# LOAD THE EXTERNAL XAML UI (data\ui\main.window.xml)
# ─────────────────────────────────────────────────────────────────────────────
try {
    $window = Import-XamlWindow -XamlFilePath $global:mainwin
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

# Apply the application icon (if present)
if (Test-Path -LiteralPath $global:appicon) {
    try {
        $iconImage = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($global:appicon))
        $window.Icon = $iconImage
    }
    catch {
        Write-Verbose "WinIsoImageMounter: Could not set window icon: $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# RESOLVE NAMED XAML ELEMENTS
# ─────────────────────────────────────────────────────────────────────────────
$titleBarPanel  = $window.FindName("TitleBarPanel")
$titleBarText   = $window.FindName("TitleBarText")
$titleBarLogo   = $window.FindName("TitleBarLogo")
$btnClose       = $window.FindName("BtnClose")

$lblInstructions = $window.FindName("LblInstructions")
$lblImageFile     = $window.FindName("LblImageFile")
$lblMountPoint    = $window.FindName("LblMountPoint")

$txtImageFile    = $window.FindName("TxtImageFile")
$btnOpenImage    = $window.FindName("BtnOpenImage")
$txtMountPoint   = $window.FindName("TxtMountPoint")
$btnBrowseMount  = $window.FindName("BtnBrowseMount")

$btnMount        = $window.FindName("BtnMount")
$btnCancel       = $window.FindName("BtnCancel")
$btnExit         = $window.FindName("BtnExit")

$statusText      = $window.FindName("StatusText")

# ─────────────────────────────────────────────────────────────────────────────
# APPLY LOCALIZED TEXTS FROM THE LANGUAGE TABLE
# ─────────────────────────────────────────────────────────────────────────────
$window.Title              = $lang.window.title
$titleBarText.Text         = $lang.window.title
$lblInstructions.Text      = $lang.labels.instructions
$lblImageFile.Text         = $lang.labels.imageFile
$lblMountPoint.Text        = $lang.labels.mountPoint
$btnOpenImage.ToolTip      = $lang.buttons.openTooltip
$btnBrowseMount.ToolTip    = $lang.buttons.browseTooltip
$btnMount.Content          = $lang.buttons.mount
$btnCancel.Content         = $lang.buttons.cancel
$btnExit.Content           = $lang.buttons.exit
$statusText.Text           = $lang.status.ready

if (Test-Path -LiteralPath $global:appicon) {
    try {
        $titleBarLogo.Source = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($global:appicon))
    }
    catch {
        Write-Verbose "WinIsoImageMounter: Could not set title bar logo: $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: RESET THE FORM TO ITS INITIAL STATE
# ─────────────────────────────────────────────────────────────────────────────
function Reset-FormState {
    $txtImageFile.Text  = ""
    $txtMountPoint.Text = ""
    Clear-FieldError -TextBox $txtImageFile
    Clear-FieldError -TextBox $txtMountPoint
    $statusText.Text = $lang.status.ready
}

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - WINDOW CHROME
# ─────────────────────────────────────────────────────────────────────────────
$btnClose.Add_Click({ $window.Close() })

$titleBarPanel.Add_MouseLeftButtonDown({
    param($senderObj, $eventArgs)
    $window.DragMove()
})

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - IMAGE FILE PICKER
# ─────────────────────────────────────────────────────────────────────────────
$btnOpenImage.Add_Click({
    Clear-FieldError -TextBox $txtImageFile

    $selectedFile = Select-WimFile -DialogTitle $lang.dialogs.fileDialogTitle `
                                    -FilterName  $lang.dialogs.fileDialogFilterName

    if ($null -ne $selectedFile) {
        $txtImageFile.Text = $selectedFile
    }
    else {
        # No selection / Cancel -> clear the field, as requested
        $txtImageFile.Text = ""
    }
})

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - MOUNT POINT FOLDER PICKER
# ─────────────────────────────────────────────────────────────────────────────
$btnBrowseMount.Add_Click({
    Clear-FieldError -TextBox $txtMountPoint

    $selectedFolder = Select-MountFolder -DialogTitle $lang.dialogs.folderDialogTitle

    if ($null -ne $selectedFolder) {
        $txtMountPoint.Text = $selectedFolder
    }
    else {
        # No selection / Cancel -> clear the field, as requested
        $txtMountPoint.Text = ""
    }
})

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - CANCEL BUTTON (clears both input fields)
# ─────────────────────────────────────────────────────────────────────────────
$btnCancel.Add_Click({
    Reset-FormState
})

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - EXIT BUTTON (closes immediately, no confirmation)
# ─────────────────────────────────────────────────────────────────────────────
$btnExit.Add_Click({
    $window.Close()
})

# ─────────────────────────────────────────────────────────────────────────────
# EVENT WIRING - MOUNT BUTTON
# Validates both fields; on any error the affected field turns red instead of
# showing a message box, and the mount process is aborted. Only if both
# fields are valid, DISM is invoked in a new, visible console window.
# ─────────────────────────────────────────────────────────────────────────────
$btnMount.Add_Click({

    $imagePath = $txtImageFile.Text
    $mountDir  = $txtMountPoint.Text

    $hasError = $false

    # Validate the image file field
    if ([string]::IsNullOrWhiteSpace($imagePath) -or
        -not (Test-Path -LiteralPath $imagePath -PathType Leaf) -or
        ([System.IO.Path]::GetExtension($imagePath).ToLowerInvariant() -ne ".wim")) {
        Show-FieldError -TextBox $txtImageFile
        $hasError = $true
    }
    else {
        Clear-FieldError -TextBox $txtImageFile
    }

    # Validate the mount point field
    if ([string]::IsNullOrWhiteSpace($mountDir) -or
        -not (Test-Path -LiteralPath $mountDir -PathType Container)) {
        Show-FieldError -TextBox $txtMountPoint
        $hasError = $true
    }
    else {
        Clear-FieldError -TextBox $txtMountPoint
    }

    if ($hasError) {
        return
    }

    # Both fields are valid -> disable the form and run DISM
    $btnMount.IsEnabled       = $false
    $btnCancel.IsEnabled      = $false
    $btnOpenImage.IsEnabled   = $false
    $btnBrowseMount.IsEnabled = $false
    $statusText.Text          = $lang.status.mounting

    $mountResult = Invoke-DismMount -WimFilePath $imagePath `
                                     -MountDirectory $mountDir `
                                     -WimIndex $global:wimIndex

    # Re-enable the form and reset it to its initial state, regardless of
    # the DISM exit code (per the specified behaviour).
    $btnMount.IsEnabled       = $true
    $btnCancel.IsEnabled      = $true
    $btnOpenImage.IsEnabled   = $true
    $btnBrowseMount.IsEnabled = $true

    Reset-FormState
})

# ─────────────────────────────────────────────────────────────────────────────
# SHOW THE WINDOW (centered via WindowStartupLocation="CenterScreen" in XAML)
# ─────────────────────────────────────────────────────────────────────────────
$window.Topmost = $true
$window.Add_Loaded({
    $window.Activate()
    $window.Focus()
    $window.Topmost = $false
})

$window.ShowDialog() | Out-Null

Write-Verbose "WinIsoImageMounter: Application closed cleanly."
exit 0
