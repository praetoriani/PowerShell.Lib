<#
.SYNOPSIS
    WinISO Image Mounter - External function library (data\fxlib\Functions.ps1).

.DESCRIPTION
    This file is dot-sourced automatically by WinIsoImageMounter.ps1 at startup
    (identical pattern to PowerEdge.ps1, which loads every *.ps1 file found in
    data\fxlib). It contains every helper function used by the main script:

        - Import-XamlWindow      : loads the external XAML UI definition
        - Get-LanguageTable      : loads and returns the external JSON language file
        - Show-FieldError        : applies the red "error" visual to a TextBox
        - Clear-FieldError       : restores a TextBox to its normal visual state
        - Select-WimFile         : shows the native "Open File" dialog (*.wim only)
        - Select-MountFolder     : shows the native "Browse Folder" dialog
        - Invoke-DismMount       : runs DISM in a new, visible console window
        - Set-ConsoleWindowState : minimizes/hides the PowerShell console window

    Keeping these functions in a separate, externally loaded file (instead of
    embedding them inline in the main script) mirrors the modular structure of
    PowerEdge and keeps WinIsoImageMounter.ps1 short and easy to read.

.NOTES
    Author:  praetoriani
    Version: 1.00.00
    Date:    18.08.2026
#>

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Set-ConsoleWindowState
# Minimizes the PowerShell console window via a P/Invoke call to user32.dll.
# Pattern taken from PowerEdge.ps1 (GetConsoleWindow + ShowWindow).
# ─────────────────────────────────────────────────────────────────────────────
function Set-ConsoleWindowState {
    [CmdletBinding()]
    param(
        # 0 = Hide, 2 = Minimize (SW_SHOWMINIMIZED), 6 = Minimize (SW_MINIMIZE)
        [int]$Mode = 6
    )

    if (-not ("WinIsoNativeMethods" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinIsoNativeMethods {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@ -ErrorAction SilentlyContinue
    }

    try {
        $consoleHandle = [WinIsoNativeMethods]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero) {
            [WinIsoNativeMethods]::ShowWindow($consoleHandle, $Mode) | Out-Null
        }
    }
    catch {
        Write-Verbose "WinIsoImageMounter: Could not change console window state: $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Import-XamlWindow
# Loads an external XAML file and returns the constructed WPF Window object.
# Uses XmlDocument + XamlReader, exactly like PowerEdge's LoadXAMLui routine.
# ─────────────────────────────────────────────────────────────────────────────
function Import-XamlWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlFilePath
    )

    if (-not (Test-Path -LiteralPath $XamlFilePath)) {
        throw "WinIsoImageMounter: XAML file not found: $XamlFilePath"
    }

    try {
        [xml]$xamlDoc = Get-Content -LiteralPath $XamlFilePath -Raw
        $reader = [System.Xml.XmlNodeReader]::new($xamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        if ($null -eq $window) {
            throw "XamlReader returned null while parsing $XamlFilePath"
        }

        return $window
    }
    catch {
        throw "WinIsoImageMounter: Failed to load XAML UI ('$XamlFilePath'): $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Get-LanguageTable
# Loads the requested JSON language file and returns it as a nested hashtable.
# Falls back to 'en-us' if the requested language file does not exist.
# ─────────────────────────────────────────────────────────────────────────────
function Get-LanguageTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LangDirectory,

        [Parameter(Mandatory = $false)]
        [string]$LanguageCode = "en-us"
    )

    $requestedFile = Join-Path $LangDirectory "$LanguageCode.json"
    $fallbackFile  = Join-Path $LangDirectory "en-us.json"

    $targetFile = if (Test-Path -LiteralPath $requestedFile) { $requestedFile } else { $fallbackFile }

    if (-not (Test-Path -LiteralPath $targetFile)) {
        throw "WinIsoImageMounter: No language file found (looked for '$requestedFile' and '$fallbackFile')."
    }

    try {
        return Get-Content -LiteralPath $targetFile -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "WinIsoImageMounter: Failed to parse language file '$targetFile': $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Show-FieldError / Clear-FieldError
# Implements the "visual effect instead of a message box" error concept
# requested for this application: instead of a MessageBox, the affected
# TextBox simply turns red until the user corrects the input.
# ─────────────────────────────────────────────────────────────────────────────
function Show-FieldError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.TextBox]$TextBox
    )

    $errorBg     = $TextBox.FindResource("BrushInputError")
    $errorBorder = $TextBox.FindResource("BrushInputErrorBrdr")

    $TextBox.Background  = $errorBg
    $TextBox.BorderBrush = $errorBorder
}

function Clear-FieldError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.TextBox]$TextBox
    )

    $normalBg     = $TextBox.FindResource("BrushInputBg")
    $normalBorder = $TextBox.FindResource("BrushInputBorder")

    $TextBox.Background  = $normalBg
    $TextBox.BorderBrush = $normalBorder
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Select-WimFile
# Shows the native Windows "Open File" common dialog, restricted to *.wim.
# On Windows 10/11 this dialog is rendered by the OS as the modern Explorer-
# style file picker (System.Windows.Forms.OpenFileDialog already uses the
# current shell common-item-dialog on all supported Windows versions).
# ─────────────────────────────────────────────────────────────────────────────
function Select-WimFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DialogTitle,

        [Parameter(Mandatory = $true)]
        [string]$FilterName
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title            = $DialogTitle
    $dialog.Filter            = "$FilterName|*.wim"
    $dialog.CheckFileExists   = $true
    $dialog.Multiselect       = $false
    $dialog.RestoreDirectory  = $true

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($dialog.FileName)) {
        return $dialog.FileName
    }

    # No selection / Cancel pressed -> caller clears the TextBox
    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Select-MountFolder
# Shows the native Windows "Browse Folder" dialog.
#
# IMPORTANT (documented in the developer guide as well): .NET's
# FolderBrowserDialog automatically renders as the modern Windows 11
# Explorer-style folder picker when the script is executed under
# PowerShell 7.x (pwsh.exe, .NET 5+). Under Windows PowerShell 5.1
# (.NET Framework, powershell.exe) it renders as the classic tree-view
# dialog, because .NET Framework never received the modern re-implementation.
# Run this application with pwsh.exe if a pixel-perfect Windows 11 look
# is required for the folder picker as well.
# ─────────────────────────────────────────────────────────────────────────────
function Select-MountFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DialogTitle
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description         = $DialogTitle
    $dialog.UseDescriptionForTitle = $true
    $dialog.ShowNewFolderButton  = $true

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($dialog.SelectedPath)) {
        return $dialog.SelectedPath
    }

    # No selection / Cancel pressed -> caller clears the TextBox
    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Invoke-DismMount
# Mounts the given WIM file into the given directory using DISM.exe, executed
# inside a NEW, VISIBLE console window so the user can watch the DISM output.
# The call blocks (-Wait) until DISM finishes, then the console window closes
# by itself because "cmd /c" returns as soon as the wrapped command exits.
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-DismMount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimFilePath,

        [Parameter(Mandatory = $true)]
        [string]$MountDirectory,

        [Parameter(Mandatory = $false)]
        [int]$WimIndex = 1
    )

    $dismArgs = "/c DISM /Mount-Wim /WimFile:`"$WimFilePath`" /index:$WimIndex /MountDir:`"$MountDirectory`""

    try {
        $process = Start-Process -FilePath "cmd.exe" `
                                  -ArgumentList $dismArgs `
                                  -WindowStyle Normal `
                                  -Wait `
                                  -PassThru `
                                  -ErrorAction Stop

        return @{
            Success  = ($process.ExitCode -eq 0)
            ExitCode = $process.ExitCode
        }
    }
    catch {
        return @{
            Success  = $false
            ExitCode = -1
            Message  = $_.Exception.Message
        }
    }
}
