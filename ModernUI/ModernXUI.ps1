<#
.SYNOPSIS
    ModernUI v2.0 - XML-Edition Demo
    Vollstandig XML-basiertes Design - keine PNG fuer das Fenster.

.DESCRIPTION
    Diese Demo zeigt, wie das ModernUI-Design-Konzept (dunkel, stylisch, modern)
    komplett uber eine externe XAML/XML-Datei realisiert wird - ganz ohne PNGs
    fuer das Fenster selbst.

    Architektur:
      - UI vollstandig in ./WPF/ModernXUI.xaml definiert
      - Alle Farben, Stile, Animationen, Hover-Effekte: reines XAML
      - PowerShell-Skript nur fuer Logik & Event-Handler zustandig
      - Frameless Window mit AllowsTransparency + DropShadowEffect
      - Sanfte Einblendanimation (ScaleTransform + Opacity Fade-In)
      - macOS-inspirierte Traffic-Light Fenstersteuerungsbuttons

    Verzeichnisstruktur:
      ModernUI\
      |-- ModernXUI.ps1          <- dieses Skript
      |-- WPF\
          |-- ModernXUI.xaml     <- komplettes UI-Design (kein PNG!)

.NOTES
    Anforderungen : PowerShell 5.1+ | .NET Framework 4.8+
    Version       : 2.0.0 (XML-Edition)
    Datum         : 14.04.2026
#>

param(
    [string]$WindowTitle = "ModernUI - XML-Design Demo"
)

# =============================================================================
# GLOBALE KONSTANTEN
# =============================================================================
$global:AppName  = "ModernUI"
$global:AppVers  = "2.0.0"
$global:AppPath  = $PSScriptRoot
$global:XamlFile = Join-Path $PSScriptRoot "WPF\ModernXUI2.xaml"

# =============================================================================
# HILFSFUNKTION: Standardisiertes Status-Objekt
# =============================================================================
function New-StatusObject {
    param(
        [int]   $Code = -1,
        [string]$Msg  = ""
    )
    return [PSCustomObject]@{ code = $Code; msg = $Msg }
}

# =============================================================================
# KONSOLENFENSTER MINIMIEREN
# =============================================================================
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@ -ErrorAction SilentlyContinue

try {
    $consoleHandle = [WinApi]::GetConsoleWindow()
    [WinApi]::ShowWindow($consoleHandle, 6) | Out-Null  # SW_MINIMIZE = 6
} catch { }

# =============================================================================
# WPF-ASSEMBLIES LADEN
# =============================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xml

# =============================================================================
# XAML LADEN UND VALIDIEREN
# =============================================================================
if (-not (Test-Path -LiteralPath $global:XamlFile -PathType Leaf)) {
    Write-Error "[ModernUI] XAML-Datei nicht gefunden: '$($global:XamlFile)'"
    exit 1
}

try {
    [xml]$xamlDoc = Get-Content -LiteralPath $global:XamlFile -Raw -Encoding UTF8
} catch {
    Write-Error "[ModernUI] XAML konnte nicht geparst werden: $($_.Exception.Message)"
    exit 1
}

# =============================================================================
# SYNCHRONISIERTER HASHTABLE FUER RUNSPACE-KOMMUNIKATION
# =============================================================================
$syncHash = [hashtable]::Synchronized(@{
    XamlDoc     = $xamlDoc
    WindowTitle = $WindowTitle
    AppName     = $global:AppName
    AppVers     = $global:AppVers
    ExitCode    = 0
    ErrorMsg    = ""
})

# =============================================================================
# UI IM STA-RUNSPACE STARTEN (WPF BENOETIGT ZWINGEND STA-THREAD)
# =============================================================================
$uiRunspace                  = [runspacefactory]::CreateRunspace()
$uiRunspace.ApartmentState   = "STA"
$uiRunspace.ThreadOptions    = "ReuseThread"
$uiRunspace.Open()
$uiRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

$uiScript = {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    try {
        # Fenster aus XAML erstellen
        $reader = [System.Xml.XmlNodeReader]::new($syncHash.XamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        if ($null -eq $window) {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "XamlReader hat null zurueckgegeben."
            return
        }

        # Dynamische Eigenschaften setzen
        $window.Title = $syncHash.WindowTitle

        # UI-Elemente per Name abrufen
        $btnClose      = $window.FindName("BtnClose")
        $btnMinimize   = $window.FindName("BtnMinimize")
        $btnMaximize   = $window.FindName("BtnMaximize")
        $titleBarPanel = $window.FindName("TitleBarPanel")
        $statusText    = $window.FindName("StatusText")
        $titleText     = $window.FindName("TitleText")
        $versionText   = $window.FindName("VersionText")
        $titleBarText  = $window.FindName("TitleBarText")

        # App-Name und Version aus syncHash setzen
        if ($null -ne $titleText)    { $titleText.Text    = $syncHash.AppName }
        if ($null -ne $versionText)  { $versionText.Text  = "v$($syncHash.AppVers)" }
        if ($null -ne $titleBarText) { $titleBarText.Text = $syncHash.WindowTitle }

        # Schliessen-Button
        if ($null -ne $btnClose) {
            $btnClose.Add_Click({
                if ($null -ne $statusText) { $statusText.Text = "Wird geschlossen..." }
                $window.Close()
            })
        }

        # Minimieren-Button
        if ($null -ne $btnMinimize) {
            $btnMinimize.Add_Click({
                $window.WindowState = [System.Windows.WindowState]::Minimized
            })
        }

        # Maximieren/Wiederherstellen-Button
        if ($null -ne $btnMaximize) {
            $btnMaximize.Add_Click({
                if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                    $window.WindowState = [System.Windows.WindowState]::Normal
                } else {
                    $window.WindowState = [System.Windows.WindowState]::Maximized
                }
            })
        }

        # Titelleiste als Ziehgriff (DragMove)
        if ($null -ne $titleBarPanel) {
            $titleBarPanel.Add_MouseLeftButtonDown({
                param($sender, $e)
                if ($e.Source -isnot [System.Windows.Controls.Button]) {
                    try { $window.DragMove() } catch { }
                }
            })
        }

        # Fenster in den Vordergrund bringen
        $window.Topmost = $true
        $window.Add_Loaded({
            $window.Activate()
            $window.Focus()
            $window.Topmost = $false
            if ($null -ne $statusText) {
                $statusText.Text = "Bereit  -  Alle Systeme aktiv"
            }
        })

        # Fenster anzeigen (blockiert bis geschlossen)
        $window.ShowDialog() | Out-Null

    } catch {
        $syncHash.ExitCode = -1
        $syncHash.ErrorMsg = "Fehler im UI-Runspace: $($_.Exception.Message)"
    }
}

# Runspace starten und auf Abschluss warten
$psInstance           = [System.Management.Automation.PowerShell]::Create()
$psInstance.Runspace  = $uiRunspace
$psInstance.AddScript($uiScript) | Out-Null
$asyncHandle          = $psInstance.BeginInvoke()
$psInstance.EndInvoke($asyncHandle)

# Aufraeumen
$psInstance.Dispose()
$uiRunspace.Close()
$uiRunspace.Dispose()

# Fehlerbehandlung
if ($syncHash.ExitCode -ne 0) {
    Write-Error "[ModernUI] $($syncHash.ErrorMsg)"
    exit 1
}

exit 0
