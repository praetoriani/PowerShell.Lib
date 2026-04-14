<#
.SYNOPSIS
    ModernUI v2.0 - XML-Edition Demo
    Vollständig XML-basiertes Design - keine PNG für das Fenster.
.NOTES
    Version: 2.0.0 | Datum: 14.04.2026
    Anforderungen: PowerShell 5.1+ | .NET Framework 4.8+
#>

param([string]$WindowTitle = "ModernUI - XML-Design Demo")

# ── Globale Konstanten ────────────────────────────────────────────────────
$global:AppName  = "ModernUI"
$global:AppVers  = "2.0.0"
$global:XamlFile = Join-Path $PSScriptRoot "WPF\ModernXUI.xaml"

# ── Konsolenfenster minimieren ────────────────────────────────────────────
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
    $h = [WinApi]::GetConsoleWindow()
    [WinApi]::ShowWindow($h, 6) | Out-Null
} catch {}

# ── WPF-Assemblies laden ──────────────────────────────────────────────────
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ── XAML prüfen und laden ─────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $global:XamlFile)) {
    Write-Error "XAML-Datei nicht gefunden: '$($global:XamlFile)'"
    exit 1
}

try {
    [xml]$xamlDoc = Get-Content -LiteralPath $global:XamlFile -Raw -Encoding UTF8
} catch {
    Write-Error "XAML konnte nicht geparst werden: $($_.Exception.Message)"
    exit 1
}

# ── Synchronisierter Hashtable für Runspace-Kommunikation ─────────────────
$syncHash = [hashtable]::Synchronized(@{
    XamlDoc     = $xamlDoc
    WindowTitle = $WindowTitle
    AppName     = $global:AppName
    AppVers     = $global:AppVers
    ExitCode    = 0
    ErrorMsg    = ""
})

# ── UI im STA-Runspace starten (WPF-Pflicht) ──────────────────────────────
$uiRunspace                = [runspacefactory]::CreateRunspace()
$uiRunspace.ApartmentState = "STA"
$uiRunspace.ThreadOptions  = "ReuseThread"
$uiRunspace.Open()
$uiRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

$uiScript = {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    try {
        $reader = [System.Xml.XmlNodeReader]::new($syncHash.XamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        if ($null -eq $window) {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "XamlReader hat null zurückgegeben."
            return
        }

        # Dynamische Werte setzen
        $window.Title = $syncHash.WindowTitle

        # UI-Elemente per Name holen
        $btnClose      = $window.FindName("BtnClose")
        $btnMinimize   = $window.FindName("BtnMinimize")
        $btnMaximize   = $window.FindName("BtnMaximize")
        $titleBarPanel = $window.FindName("TitleBarPanel")
        $statusText    = $window.FindName("StatusText")
        $titleText     = $window.FindName("TitleText")
        $versionText   = $window.FindName("VersionText")
        $titleBarText  = $window.FindName("TitleBarText")

        if ($null -ne $titleText)    { $titleText.Text    = $syncHash.AppName }
        if ($null -ne $versionText)  { $versionText.Text  = "v$($syncHash.AppVers)" }
        if ($null -ne $titleBarText) { $titleBarText.Text = $syncHash.WindowTitle }

        # Fenstersteuerungsbuttons
        if ($null -ne $btnClose) {
            $btnClose.Add_Click({
                if ($null -ne $statusText) { $statusText.Text = "Wird geschlossen..." }
                $window.Close()
            })
        }

        if ($null -ne $btnMinimize) {
            $btnMinimize.Add_Click({
                $window.WindowState = [System.Windows.WindowState]::Minimized
            })
        }

        if ($null -ne $btnMaximize) {
            $btnMaximize.Add_Click({
                if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                    $window.WindowState = [System.Windows.WindowState]::Normal
                } else {
                    $window.WindowState = [System.Windows.WindowState]::Maximized
                }
            })
        }

        # Titelleiste als Ziehgriff
        if ($null -ne $titleBarPanel) {
            $titleBarPanel.Add_MouseLeftButtonDown({
                param($sender, $e)
                if ($e.Source -isnot [System.Windows.Controls.Button]) {
                    try { $window.DragMove() } catch {}
                }
            })
        }

        # Fenster in den Vordergrund
        $window.Topmost = $true
        $window.Add_Loaded({
            $window.Activate()
            $window.Focus()
            $window.Topmost = $false
            if ($null -ne $statusText) {
                $statusText.Text = "Bereit  ·  Alle Systeme aktiv"
            }
        })

        $window.ShowDialog() | Out-Null
    } catch {
        $syncHash.ExitCode = -1
        $syncHash.ErrorMsg = "Fehler im UI-Runspace: $($_.Exception.Message)"
    }
}

$ps                  = [System.Management.Automation.PowerShell]::Create()
$ps.Runspace         = $uiRunspace
$ps.AddScript($uiScript) | Out-Null
$handle              = $ps.BeginInvoke()
$ps.EndInvoke($handle)
$ps.Dispose()
$uiRunspace.Close()
$uiRunspace.Dispose()

if ($syncHash.ExitCode -ne 0) {
    Write-Error "[ModernUI] $($syncHash.ErrorMsg)"
    exit 1
}

exit 0