<#
.SYNOPSIS
    PowerEdge v1.00.02 - A WPF host application that embeds a Microsoft Edge (WebView2) instance
    to display locally stored web applications (HTML files).

.DESCRIPTION
    PowerEdge opens a modern WPF application window with an embedded Microsoft Edge WebView2 control.
    It accepts a path to a local HTML file and loads it inside the Edge instance, providing a clean,
    frameless application experience for PowerShell-based web app hosting.

    The XAML/XML UI definition is loaded from an external file (.gui\main.window.xml) in accordance
    with the mandatory App Development Guidelines.

.PARAMETER httpRoot
    Full or relative path to the local HTML file to be loaded inside the Edge WebView2 instance.
    If omitted, PowerEdge looks for a default 'index.html' inside the .\data\web\ subdirectory.

.PARAMETER WindowTitle
    Optional custom window title. Defaults to "PowerEdge" if not specified.

.PARAMETER Hidden
    Optional switch. When set, PowerEdge starts hidden (not visible).
    This parameter can ONLY be used in combination with the -Timeout parameter!
    Use case: Pre-load the application in the background for faster subsequent display.

.PARAMETER Timeout
    Optional integer (milliseconds). Specifies the duration PowerEdge remains hidden.
    After this time elapses, the window becomes visible automatically.
    This parameter MUST be specified when -Hidden is used.

.EXAMPLE
    .\PowerEdge.ps1 -httpRoot ".\data\web\index.html"

.EXAMPLE
    .\PowerEdge.ps1 -httpRoot "C:\MyApps\dashboard.html" -WindowTitle "My Dashboard"

.EXAMPLE
    .\PowerEdge.ps1 -httpRoot ".\data\web\index.html" -Hidden -Timeout 5000
    # Starts hidden, becomes visible after 5 seconds

.NOTES
    Creation Date: 12.04.2026
    Last Update:   14.04.2026
    Version:       1.00.02
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    REQUIREMENTS & DEPENDENCIES:
    - PowerShell 5.1 or higher (PowerShell 7.x recommended)
    - .NET Framework 4.7.2 or higher (for WPF)
    - Microsoft Edge WebView2 Runtime (must be installed on the system)
      Download: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
    - Microsoft.Web.WebView2 NuGet package DLLs placed in .\lib\ subdirectory
      (Microsoft.Web.WebView2.Core.dll + Microsoft.Web.WebView2.Wpf.dll)

    CHANGELOG:
    v1.00.02 - Fixed: WebView2 no longer tries to create its user-data folder
               inside C:\Windows\System32\WindowsPowerShell\v1.0\ (no write
               access). A CoreWebView2Environment is now explicitly created
               with the user-data folder set to:
                   <script dir>\.wv2data
               This folder is inside the PowerEdge project directory where
               the current user always has write permission.
               The environment object is passed to EnsureCoreWebView2Async()
               so WebView2 uses the correct, writable location.
               Fixes: "Das Datenverzeichnis konnte nicht erstellt werden"
                      (HRESULT 0x80080005, CO_E_SERVER_EXEC_FAILURE)
               Fixed: Corrupted code block in UI runspace that referenced
                      undefined "AppIcon" command - cleaned up garbled lines
                      in the TitleBarLogo assignment section.
               Added: -Hidden and -Timeout parameters for delayed window visibility.
               Added: LoadURL and LoadURLafter functions in fxlib.

    v1.00.01 - Fixed: EnsureCoreWebView2Async() is now called inside the
               Window.Loaded event handler instead of before ShowDialog().
               The WebView2 control requires the WPF dispatcher/event loop
               to be running before EnsureCoreWebView2Async can be invoked.
               Calling it before ShowDialog() caused the error:
               "EnsureCoreWebView2Async cannot be used before the
                application's event loop has started running."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$httpRoot = "",

    [Parameter(Mandatory = $false)]
    [string]$WindowTitle = "PowerEdge",

    [Parameter(Mandatory = $false)]
    [switch]$Hidden,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 0
)

# ─────────────────────────────────────────────────────────────────────────────
# PARAMETER VALIDATION
# ─────────────────────────────────────────────────────────────────────────────
if ($Hidden -and $Timeout -le 0) {
    Write-Error "PowerEdge: The -Hidden parameter can only be used in combination with -Timeout (milliseconds > 0)."
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL APPLICATION VARIABLES (mandatory per App Development Guidelines)
# ─────────────────────────────────────────────────────────────────────────────

# Load Configuration from JSON
$configFile = Join-Path $PSScriptRoot "data\config.json"
if (Test-Path $configFile) {
    try {
        $global:AppConfig = Get-Content $configFile -Raw | ConvertFrom-Json -ErrorAction Stop
        $global:AppName   = $global:AppConfig.appinfo.name
        $global:AppVers   = $global:AppConfig.appinfo.version
    }
    catch {
        Write-Error "PowerEdge: Failed to load config.json: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Error "PowerEdge: Configuration file not found: $configFile"
    exit 1
}

$global:AppPath    = $PSScriptRoot
$global:AppIcon    = Join-Path $PSScriptRoot "PowerEdge.ico"

# Internal path constants
$global:GuiDir     = Join-Path $PSScriptRoot $global:AppConfig.appcore.uidata
$global:WebAppDir  = Join-Path $PSScriptRoot $global:AppConfig.appcore.webdata
$global:LibDir     = Join-Path $PSScriptRoot $global:AppConfig.appcore.libdata
$global:XamlFile   = Join-Path $global:GuiDir "main.window.xml"

# WebView2 user-data folder
$global:Wv2DataDir = Join-Path $PSScriptRoot $global:AppConfig.appcore.wv2root

# DOTSOURCING EXTERNAL FUNCTIONS (data\fxlib)
$fxLibPath = Join-Path $PSScriptRoot "data\fxlib"
if (Test-Path $fxLibPath) {
    Get-ChildItem -Path $fxLibPath -Filter "*.ps1" | ForEach-Object {
        try   { . $_.FullName }
        catch { Write-Warning "PowerEdge: Failed to dotsource $($_.Name): $($_.Exception.Message)" }
    }
}
else {
    Write-Error "PowerEdge: Function library directory not found: $fxLibPath"
    exit 1
}

# MAIN EXECUTION BLOCK

# Hide the console window immediately
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
    [WinApi]::ShowWindow($consoleHandle, 0) | Out-Null # SW_MINIMIZE = 6 | SW_HIDE  = 0
}
catch { Write-Verbose "PowerEdge: Could not minimize console window: $($_.Exception.Message)" }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xml

Write-Verbose "PowerEdge $global:AppVers starting..."

$pathResult = ResolveHttpRoot -InputPath $httpRoot
if ($pathResult.code -ne 0) { Write-Error $pathResult.msg; exit 1 }
$resolvedHtmlPath = $pathResult.msg

$wv2Result = LoadWebViewDLLs
if ($wv2Result.code -ne 0) { Write-Error $wv2Result.msg; exit 1 }

$xamlResult = LoadXAMLui -XamlFilePath $global:XamlFile
if ($xamlResult.code -ne 0) { Write-Error $xamlResult.msg; exit 1 }
$xamlDoc = $xamlResult.XmlDoc

if (-not (Test-Path -LiteralPath $global:Wv2DataDir -PathType Container)) {
    try   { New-Item -ItemType Directory -Path $global:Wv2DataDir -Force -ErrorAction Stop | Out-Null }
    catch { Write-Error "PowerEdge: Could not create WebView2 data dir: $($_.Exception.Message)"; exit 1 }
}

$syncHash = [hashtable]::Synchronized(@{
    HtmlPath    = $resolvedHtmlPath
    WindowTitle = $WindowTitle
    XamlDoc     = $xamlDoc
    AppIcon     = $global:AppIcon
    LibDir      = $global:LibDir
    Wv2DataDir  = $global:Wv2DataDir
    Hidden      = $Hidden.IsPresent
    Timeout     = $Timeout
    ExitCode    = 0
    ErrorMsg    = ""
})

$uiRunspace = [runspacefactory]::CreateRunspace()
$uiRunspace.ApartmentState = "STA"
$uiRunspace.ThreadOptions  = "ReuseThread"
$uiRunspace.Open()
$uiRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

$uiScript = {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $libDir  = $syncHash.LibDir
    $coreDll = Join-Path $libDir "Microsoft.Web.WebView2.Core.dll"
    $wpfDll  = Join-Path $libDir "Microsoft.Web.WebView2.Wpf.dll"
    if (Test-Path -LiteralPath $coreDll) { try { Add-Type -Path $coreDll -ErrorAction Stop } catch {} }
    if (Test-Path -LiteralPath $wpfDll)  { try { Add-Type -Path $wpfDll  -ErrorAction Stop } catch {} }

    try {
        $reader = [System.Xml.XmlNodeReader]::new($syncHash.XamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        if ($null -eq $window) {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "PowerEdge: XamlReader returned null."
            return
        }

        $window.Title = $syncHash.WindowTitle
        if (Test-Path -LiteralPath $syncHash.AppIcon -ErrorAction SilentlyContinue) {
            $window.Icon = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($syncHash.AppIcon))
        }

        $webView        = $window.FindName("MainWebView")
        $titleBar       = $window.FindName("TitleBarText")
        $btnClose       = $window.FindName("BtnClose")
        $btnMinimize    = $window.FindName("BtnMinimize")
        $btnMaximize    = $window.FindName("BtnMaximize")
        $statusText     = $window.FindName("StatusText")
        $loadingOverlay = $window.FindName("LoadingOverlay")
        $titleBarPanel  = $window.FindName("TitleBarPanel")
        $titleBarLogo   = $window.FindName("TitleBarLogo")

        if ($null -ne $titleBarLogo -and (Test-Path -LiteralPath $syncHash.AppIcon -ErrorAction SilentlyContinue)) {
            $titleBarLogo.Source = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($syncHash.AppIcon))
        }
        if ($null -ne $titleBar)    { $titleBar.Text = $syncHash.WindowTitle }
        if ($null -ne $btnClose)    { $btnClose.Add_Click({ $window.Close() }) }
        if ($null -ne $btnMinimize) { $btnMinimize.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized }) }
        if ($null -ne $btnMaximize) {
            $btnMaximize.Add_Click({
                if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                    $window.WindowState = [System.Windows.WindowState]::Normal
                } else { $window.WindowState = [System.Windows.WindowState]::Maximized }
            })
        }
        if ($null -ne $titleBarPanel) {
            $titleBarPanel.Add_MouseLeftButtonDown({ param($s,$e) $window.DragMove() })
        }

        if ($null -ne $webView) {
            $window.Add_Loaded({
                if ($null -ne $statusText) { $statusText.Text = "Loading web application..." }
                $wv2DataDir = $syncHash.Wv2DataDir
                try {
                    $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync(
                        [string]$null, $wv2DataDir,
                        [Microsoft.Web.WebView2.Core.CoreWebView2EnvironmentOptions]$null)
                    $wv2Env = $envTask.GetAwaiter().GetResult()
                }
                catch {
                    if ($null -ne $statusText) { $statusText.Text = "WebView2 env failed: $($_.Exception.Message)" }
                    return
                }
                $webView.Add_CoreWebView2InitializationCompleted({
                    param($sender, $e)
                    if ($e.IsSuccess) {
                        $fileUri = [System.Uri]::new($syncHash.HtmlPath)
                        $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)
                        if ($null -ne $loadingOverlay) { $loadingOverlay.Visibility = [System.Windows.Visibility]::Collapsed }
                        if ($null -ne $statusText)     { $statusText.Text = "Ready" }
                    } else {
                        if ($null -ne $statusText) { $statusText.Text = "WebView2 init failed: $($e.InitializationException.Message)" }
                    }
                })
                $webView.EnsureCoreWebView2Async($wv2Env) | Out-Null
            })
        } else {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "PowerEdge: Named element 'MainWebView' not found in XAML."
        }

        # Handle -Hidden / -Timeout: start window hidden, reveal after delay
        if ($syncHash.Hidden -eq $true -and $syncHash.Timeout -gt 0) {
            $window.Visibility = [System.Windows.Visibility]::Hidden
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMilliseconds($syncHash.Timeout)
            $capturedWindow = $window
            $capturedTimer  = $timer
            $timer.Add_Tick({
                $capturedWindow.Visibility = [System.Windows.Visibility]::Visible
                $capturedWindow.Activate()
                $capturedWindow.Focus()
                $capturedTimer.Stop()
            })
            $timer.Start()
        } else {
            $window.Topmost = $true
            $window.Add_Loaded({ $window.Activate(); $window.Focus(); $window.Topmost = $false })
        }

        $window.ShowDialog() | Out-Null
    }
    catch {
        $syncHash.ExitCode = -1
        $syncHash.ErrorMsg = "PowerEdge: Unhandled exception in UI runspace: $($_.Exception.Message)"
    }
}

$psInstance = [System.Management.Automation.PowerShell]::Create()
$psInstance.Runspace = $uiRunspace
$psInstance.AddScript($uiScript) | Out-Null
$asyncHandle = $psInstance.BeginInvoke()
$psInstance.EndInvoke($asyncHandle)
$psInstance.Dispose()
$uiRunspace.Close()
$uiRunspace.Dispose()

if ($syncHash.ExitCode -ne 0) {
    Write-Error $syncHash.ErrorMsg
    exit 1
}

Write-Verbose "PowerEdge: Application closed cleanly."
exit 0
