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

.PARAMETER WebAppPath
    Full or relative path to the local HTML file to be loaded inside the Edge WebView2 instance.
    If omitted, PowerEdge looks for a default 'index.html' inside the .\webapp\ subdirectory.

.PARAMETER WindowTitle
    Optional custom window title. Defaults to "PowerEdge" if not specified.

.EXAMPLE
    .\PowerEdge.ps1 -WebAppPath ".\webapp\index.html"

.EXAMPLE
    .\PowerEdge.ps1 -WebAppPath "C:\MyApps\dashboard.html" -WindowTitle "My Dashboard"

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
    [string]$WebAppPath = "",

    [Parameter(Mandatory = $false)]
    [string]$WindowTitle = "PowerEdge"
)

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL APPLICATION VARIABLES (mandatory per App Development Guidelines)
# ─────────────────────────────────────────────────────────────────────────────
$global:AppName   = "PowerEdge"
$global:AppVers   = "1.00.02"
$global:AppPath   = $PSScriptRoot
$global:AppIcon   = Join-Path $PSScriptRoot "poweredge.ico"

# Internal path constants
$global:GuiDir    = Join-Path $PSScriptRoot ".gui"
$global:WebAppDir = Join-Path $PSScriptRoot "webapp"
$global:LibDir    = Join-Path $PSScriptRoot "lib"
$global:XamlFile  = Join-Path $global:GuiDir "main.window.xml"

# WebView2 user-data folder: placed inside the project directory so the
# current user always has read/write access. WebView2 stores its browser
# cache, cookies, and profile data here.
$global:Wv2DataDir = Join-Path $PSScriptRoot "pe.store"

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Standard status return object (mandatory per App Development Guidelines)
# ─────────────────────────────────────────────────────────────────────────────
function New-StatusObject {
    <#
    .SYNOPSIS
        Creates a standardized status/return object used by all functions.
    .DESCRIPTION
        Returns a PSCustomObject with 'code' (int) and 'msg' (string).
        code = 0  → success, msg is empty string
        code = -1 → failure, msg contains error description
    .PARAMETER Code
        Integer status code. 0 = success, -1 = error.
    .PARAMETER Msg
        Descriptive message. Empty on success, error description on failure.
    .EXAMPLE
        $result = New-StatusObject -Code 0 -Msg ""
    .NOTES
        Version: 1.00.00 | Author: Praetoriani
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(-99, 99)]
        [int]$Code = -1,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Msg = ""
    )
    return [PSCustomObject]@{
        code = $Code
        msg  = $Msg
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Validate and resolve the WebApp HTML file path
# ─────────────────────────────────────────────────────────────────────────────
function Resolve-WebAppPath {
    <#
    .SYNOPSIS
        Validates and canonicalizes the path to the HTML file to be loaded.
    .DESCRIPTION
        Accepts a user-provided path or falls back to the default webapp\index.html.
        Performs path canonicalization and validates that the resolved path exists
        and has an .html or .htm extension.
    .PARAMETER InputPath
        Raw path string as provided by the user or empty string for default fallback.
    .EXAMPLE
        $result = Resolve-WebAppPath -InputPath ".\webapp\index.html"
    .NOTES
        Version: 1.00.00 | Author: Praetoriani
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$InputPath = ""
    )

    $status = New-StatusObject -Code -1 -Msg ""

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        $targetPath = Join-Path $global:WebAppDir "index.html"
        Write-Verbose "PowerEdge: No WebAppPath provided. Using default: $targetPath"
    }
    else {
        if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
            $targetPath = Join-Path $global:AppPath $InputPath
        }
        else {
            $targetPath = $InputPath
        }
    }

    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($targetPath)
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Path canonicalization failed for '$targetPath': $($_.Exception.Message)"
        return $status
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        $status.code = -1
        $status.msg  = "PowerEdge: HTML file not found at resolved path: '$resolvedPath'"
        return $status
    }

    $ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($ext -notin @(".html", ".htm")) {
        $status.code = -1
        $status.msg  = "PowerEdge: Invalid file extension '$ext'. Only .html and .htm are permitted."
        return $status
    }

    $status.code = 0
    $status.msg  = $resolvedPath
    return $status
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Load and validate the external XAML UI definition
# ─────────────────────────────────────────────────────────────────────────────
function Import-XamlDefinition {
    <#
    .SYNOPSIS
        Loads the external XAML XML file and parses it into an XmlDocument.
    .DESCRIPTION
        Reads the WPF XAML definition from the .gui\main.window.xml file.
        Validates that the file exists and is well-formed XML before returning it.
        Per the mandatory App Development Guidelines, XAML must never be inline.
    .PARAMETER XamlFilePath
        Full path to the XAML XML file.
    .EXAMPLE
        $result = Import-XamlDefinition -XamlFilePath $global:XamlFile
    .NOTES
        Version: 1.00.00 | Author: Praetoriani
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$XamlFilePath
    )

    $status = New-StatusObject -Code -1 -Msg ""

    if (-not (Test-Path -LiteralPath $XamlFilePath -PathType Leaf)) {
        $status.code = -1
        $status.msg  = "PowerEdge: XAML definition file not found: '$XamlFilePath'"
        return $status
    }

    try {
        [xml]$xamlDoc = Get-Content -LiteralPath $XamlFilePath -Raw -Encoding UTF8
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Failed to parse XAML file '$XamlFilePath': $($_.Exception.Message)"
        return $status
    }

    $status.code = 0
    $status.msg  = ""
    $status | Add-Member -NotePropertyName "XmlDoc" -NotePropertyValue $xamlDoc
    return $status
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTION: Load WebView2 assemblies from .\lib\ directory
# ─────────────────────────────────────────────────────────────────────────────
function Import-WebView2Assemblies {
    <#
    .SYNOPSIS
        Loads the Microsoft WebView2 WPF assemblies from the .\lib\ directory.
    .DESCRIPTION
        Attempts to load Microsoft.Web.WebView2.Core.dll and
        Microsoft.Web.WebView2.Wpf.dll from the .\lib\ subdirectory.
        If the DLLs are not found there, falls back to checking the NuGet
        package cache. Returns a status object indicating success or failure.
    .EXAMPLE
        $result = Import-WebView2Assemblies
    .NOTES
        Version: 1.00.01 | Author: Praetoriani
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $status = New-StatusObject -Code -1 -Msg ""

    $coreDll = Join-Path $global:LibDir "Microsoft.Web.WebView2.Core.dll"
    $wpfDll  = Join-Path $global:LibDir "Microsoft.Web.WebView2.Wpf.dll"

    $dllsInLib = (Test-Path -LiteralPath $coreDll) -and (Test-Path -LiteralPath $wpfDll)

    if ($dllsInLib) {
        # ── Load Microsoft.Web.WebView2.Core.dll ──────────────────────────────
        try {
            Add-Type -Path $coreDll -ErrorAction Stop
            Write-Verbose "PowerEdge: Loaded WebView2.Core from lib\."
        }
        catch [System.Reflection.ReflectionTypeLoadException] {
            $loaderMsgs = ($_.Exception.LoaderExceptions | ForEach-Object { $_.Message }) -join "; "
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (ReflectionTypeLoadException). " +
                           "Verify the DLL targets net462 and that WebView2Loader.dll is present in .\lib\. " +
                           "LoaderExceptions: $loaderMsgs"
            return $status
        }
        catch [System.BadImageFormatException] {
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (BadImageFormatException). " +
                           "The DLL architecture does not match the PowerShell process (x86/x64 mismatch), " +
                           "or the file is not a valid .NET assembly. Details: $($_.Exception.Message)"
            return $status
        }
        catch [System.IO.FileLoadException] {
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (FileLoadException). " +
                           "The file may be blocked by Windows security (Zone.Identifier). " +
                           "Run 'Get-ChildItem .\lib\*.dll | Unblock-File' and retry. " +
                           "Details: $($_.Exception.Message)"
            return $status
        }
        catch {
            if ($_.Exception.Message -match "already loaded|already exists") {
                Write-Verbose "PowerEdge: WebView2.Core was already loaded in this session - continuing."
            }
            else {
                $status.code = -1
                $status.msg  = "PowerEdge: Unexpected error while loading WebView2.Core: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
                return $status
            }
        }

        # ── Load Microsoft.Web.WebView2.Wpf.dll ──────────────────────────────
        try {
            Add-Type -Path $wpfDll -ErrorAction Stop
            Write-Verbose "PowerEdge: Loaded WebView2.Wpf from lib\."
        }
        catch [System.Reflection.ReflectionTypeLoadException] {
            $loaderMsgs = ($_.Exception.LoaderExceptions | ForEach-Object { $_.Message }) -join "; "
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Wpf could not be loaded (ReflectionTypeLoadException). " +
                           "Verify the DLL targets net462 and that WebView2Loader.dll is present in .\lib\. " +
                           "LoaderExceptions: $loaderMsgs"
            return $status
        }
        catch [System.BadImageFormatException] {
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Wpf could not be loaded (BadImageFormatException). " +
                           "Architecture mismatch (x86/x64) or invalid assembly. Details: $($_.Exception.Message)"
            return $status
        }
        catch [System.IO.FileLoadException] {
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Wpf could not be loaded (FileLoadException). " +
                           "The file may be blocked by Windows security (Zone.Identifier). " +
                           "Run 'Get-ChildItem .\lib\*.dll | Unblock-File' and retry. " +
                           "Details: $($_.Exception.Message)"
            return $status
        }
        catch {
            if ($_.Exception.Message -match "already loaded|already exists") {
                Write-Verbose "PowerEdge: WebView2.Wpf was already loaded in this session - continuing."
            }
            else {
                $status.code = -1
                $status.msg  = "PowerEdge: Unexpected error while loading WebView2.Wpf: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
                return $status
            }
        }
    }
    else {
        Write-Verbose "PowerEdge: WebView2 DLLs not found in .\lib\. Attempting standard resolution."
        $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages\microsoft.web.webview2"
        if (Test-Path $nugetCache) {
            $latestVer = Get-ChildItem $nugetCache -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestVer) {
                $wpfCandidates = Get-ChildItem (Join-Path $latestVer.FullName "lib") -Recurse -Filter "Microsoft.Web.WebView2.Wpf.dll" -ErrorAction SilentlyContinue
                if ($wpfCandidates) {
                    foreach ($candidate in $wpfCandidates) {
                        try { Add-Type -Path $candidate.FullName -ErrorAction Stop; break } catch {}
                    }
                }
            }
        }
    }

    # ── Final type-resolution check ───────────────────────────────────────────
    try {
        $null = [Microsoft.Web.WebView2.Wpf.WebView2]
        $status.code = 0
        $status.msg  = ""
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Microsoft.Web.WebView2.Wpf.WebView2 type could not be resolved. " +
                       "Please place WebView2 DLLs into .\lib\ or install the NuGet package. " +
                       "Error: $($_.Exception.Message)"
    }

    return $status
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN EXECUTION BLOCK
# ─────────────────────────────────────────────────────────────────────────────

# Minimize the console window immediately (mandatory per App Development Guidelines)
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
}
catch {
    Write-Verbose "PowerEdge: Could not minimize console window: $($_.Exception.Message)"
}

# Load required .NET assemblies for WPF
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xml

Write-Verbose "PowerEdge $global:AppVers starting..."

# Step 1: Resolve and validate the WebApp HTML path
$pathResult = Resolve-WebAppPath -InputPath $WebAppPath
if ($pathResult.code -ne 0) {
    Write-Error $pathResult.msg
    exit 1
}
$resolvedHtmlPath = $pathResult.msg
Write-Verbose "PowerEdge: Resolved HTML path: $resolvedHtmlPath"

# Step 2: Load the WebView2 assemblies
$wv2Result = Import-WebView2Assemblies
if ($wv2Result.code -ne 0) {
    Write-Error $wv2Result.msg
    Write-Host ""
    Write-Host "SETUP INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "  1. Download WebView2 SDK DLLs from NuGet:" -ForegroundColor Cyan
    Write-Host "     https://www.nuget.org/packages/Microsoft.Web.WebView2" -ForegroundColor Cyan
    Write-Host "  2. Extract the NuGet package (.nupkg is a ZIP) and copy these files" -ForegroundColor Cyan
    Write-Host "     from the 'lib\net462\' subfolder into .\lib\:" -ForegroundColor Cyan
    Write-Host "     - Microsoft.Web.WebView2.Core.dll" -ForegroundColor Cyan
    Write-Host "     - Microsoft.Web.WebView2.Wpf.dll" -ForegroundColor Cyan
    Write-Host "  3. Copy the native loader from 'runtimes\win-x64\native\' into .\lib\:" -ForegroundColor Cyan
    Write-Host "     - WebView2Loader.dll" -ForegroundColor Cyan
    Write-Host "  4. Unblock all DLLs to remove Windows security restrictions:" -ForegroundColor Cyan
    Write-Host "     Get-ChildItem .\lib\*.dll | Unblock-File" -ForegroundColor Cyan
    Write-Host "  5. Ensure the WebView2 Runtime is installed on this machine." -ForegroundColor Cyan
    Write-Host "     Runtime installer: https://developer.microsoft.com/en-us/microsoft-edge/webview2/" -ForegroundColor Cyan
    exit 1
}
Write-Verbose "PowerEdge: WebView2 assemblies loaded successfully."

# Step 3: Load the external XAML UI definition
$xamlResult = Import-XamlDefinition -XamlFilePath $global:XamlFile
if ($xamlResult.code -ne 0) {
    Write-Error $xamlResult.msg
    exit 1
}
$xamlDoc = $xamlResult.XmlDoc
Write-Verbose "PowerEdge: XAML definition loaded from '$global:XamlFile'."

# Step 4: Ensure the WebView2 user-data directory exists and is writable.
# WebView2 needs a dedicated folder to store its browser profile (cache,
# cookies, settings). By default it tries to create this folder next to the
# host executable, which in our case is powershell.exe inside
# C:\Windows\System32\WindowsPowerShell\v1.0\ - a location the current user
# cannot write to. We therefore create the folder explicitly inside the
# PowerEdge project directory (.wv2data) where write access is guaranteed.
if (-not (Test-Path -LiteralPath $global:Wv2DataDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $global:Wv2DataDir -Force -ErrorAction Stop | Out-Null
        Write-Verbose "PowerEdge: Created WebView2 user-data directory: $global:Wv2DataDir"
    }
    catch {
        Write-Error "PowerEdge: Could not create WebView2 user-data directory '$global:Wv2DataDir': $($_.Exception.Message)"
        exit 1
    }
}

# Step 5: Build the WPF window from the XAML definition in an STA runspace.
# WPF requires a Single-Thread Apartment (STA) thread to operate.
# We use a synchronized hashtable to pass data between the calling thread
# and the UI thread.
$syncHash = [hashtable]::Synchronized(@{
    HtmlPath    = $resolvedHtmlPath
    WindowTitle = $WindowTitle
    XamlDoc     = $xamlDoc
    AppIcon     = $global:AppIcon
    LibDir      = $global:LibDir
    Wv2DataDir  = $global:Wv2DataDir
    ExitCode    = 0
    ErrorMsg    = ""
})

$uiRunspace = [runspacefactory]::CreateRunspace()
$uiRunspace.ApartmentState = "STA"
$uiRunspace.ThreadOptions  = "ReuseThread"
$uiRunspace.Open()
$uiRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

$uiScript = {
    # Import WPF assemblies inside the runspace
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Re-load WebView2 assemblies inside the STA runspace.
    # Each runspace is an isolated AppDomain context; assemblies loaded in the
    # main thread are NOT automatically available here.
    $libDir  = $syncHash.LibDir
    $coreDll = Join-Path $libDir "Microsoft.Web.WebView2.Core.dll"
    $wpfDll  = Join-Path $libDir "Microsoft.Web.WebView2.Wpf.dll"
    if (Test-Path -LiteralPath $coreDll) {
        try { Add-Type -Path $coreDll -ErrorAction Stop } catch {}
    }
    if (Test-Path -LiteralPath $wpfDll) {
        try { Add-Type -Path $wpfDll -ErrorAction Stop } catch {}
    }

    try {
        # Parse XAML and create the Window object
        $reader = [System.Xml.XmlNodeReader]::new($syncHash.XamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        if ($null -eq $window) {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "PowerEdge: XamlReader returned null - XAML parsing failed."
            return
        }

        # Set dynamic window properties
        $window.Title = $syncHash.WindowTitle

        # Set the application icon if it exists
        if (Test-Path -LiteralPath $syncHash.AppIcon -ErrorAction SilentlyContinue) {
            $window.Icon = [System.Windows.Media.Imaging.BitmapImage]::new(
                [System.Uri]::new($syncHash.AppIcon)
            )
        }

        # Retrieve named controls from the XAML tree
        $webView        = $window.FindName("MainWebView")
        $titleBar       = $window.FindName("TitleBarText")
        $btnClose       = $window.FindName("BtnClose")
        $btnMinimize    = $window.FindName("BtnMinimize")
        $btnMaximize    = $window.FindName("BtnMaximize")
        $statusText     = $window.FindName("StatusText")
        $loadingOverlay = $window.FindName("LoadingOverlay")
        $titleBarPanel  = $window.FindName("TitleBarPanel")

        # Update title bar label
        if ($null -ne $titleBar) {
            $titleBar.Text = $syncHash.WindowTitle
        }

        # Wire up window control buttons
        if ($null -ne $btnClose) {
            $btnClose.Add_Click({ $window.Close() })
        }
        if ($null -ne $btnMinimize) {
            $btnMinimize.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized })
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

        # Allow dragging the custom title bar
        if ($null -ne $titleBarPanel) {
            $titleBarPanel.Add_MouseLeftButtonDown({
                param($sender, $e)
                $window.DragMove()
            })
        }

        if ($null -ne $webView) {
            $window.Add_Loaded({
                # Update status text
                if ($null -ne $statusText) {
                    $statusText.Text = "Loading web application..."
                }

                # ── FIX v1.00.02 ─────────────────────────────────────────────
                # Build an explicit CoreWebView2Environment that points the
                # user-data folder to <script dir>\.wv2data.
                # Without this, WebView2 defaults to a folder next to
                # powershell.exe (C:\Windows\System32\...\powershell.exe.WebView2)
                # which is not writable for normal users, causing:
                #   "Das Datenverzeichnis konnte nicht erstellt werden."
                #   HRESULT 0x80080005 (CO_E_SERVER_EXEC_FAILURE)
                # ─────────────────────────────────────────────────────────────────────
                $wv2DataDir = $syncHash.Wv2DataDir

                # CoreWebView2Environment.CreateAsync() is a .NET Task; we
                # use .GetAwaiter().GetResult() to block synchronously on the
                # STA thread so the environment object is ready before we
                # pass it to EnsureCoreWebView2Async.
                try {
                    $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync(
                        [string]$null,   # browserExecutableFolder  - null = use installed Edge
                        $wv2DataDir,     # userDataFolder           - our writable project subdir
                        [Microsoft.Web.WebView2.Core.CoreWebView2EnvironmentOptions]$null
                    )
                    $wv2Env = $envTask.GetAwaiter().GetResult()
                }
                catch {
                    if ($null -ne $statusText) {
                        $statusText.Text = "WebView2 environment creation failed: $($_.Exception.Message)"
                    }
                    return
                }

                # Register the initialization-completed handler BEFORE calling
                # EnsureCoreWebView2Async so no event is ever missed.
                $webView.Add_CoreWebView2InitializationCompleted({
                    param($sender, $e)
                    if ($e.IsSuccess) {
                        $fileUri = [System.Uri]::new($syncHash.HtmlPath)
                        $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)

                        if ($null -ne $loadingOverlay) {
                            $loadingOverlay.Visibility = [System.Windows.Visibility]::Collapsed
                        }
                        if ($null -ne $statusText) {
                            $statusText.Text = "Ready"
                        }
                    }
                    else {
                        if ($null -ne $statusText) {
                            $statusText.Text = "WebView2 initialization failed: $($e.InitializationException.Message)"
                        }
                    }
                })

                # Pass the explicit environment so WebView2 uses .wv2data
                # instead of the unwritable default location.
                $webView.EnsureCoreWebView2Async($wv2Env) | Out-Null
            })
        }
        else {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "PowerEdge: Named element 'MainWebView' not found in XAML. Check main.window.xml."
        }

        # Show the window and start the WPF message loop
        $window.ShowDialog() | Out-Null

    }
    catch {
        $syncHash.ExitCode = -1
        $syncHash.ErrorMsg = "PowerEdge: Unhandled exception in UI runspace: $($_.Exception.Message)"
    }
}

# Execute the UI script in the STA runspace
$psInstance = [System.Management.Automation.PowerShell]::Create()
$psInstance.Runspace = $uiRunspace
$psInstance.AddScript($uiScript) | Out-Null
$asyncHandle = $psInstance.BeginInvoke()

# Wait for the UI runspace to complete (i.e., window was closed)
$psInstance.EndInvoke($asyncHandle)

# Clean up resources
$psInstance.Dispose()
$uiRunspace.Close()
$uiRunspace.Dispose()

# Report any errors that occurred inside the runspace
if ($syncHash.ExitCode -ne 0) {
    Write-Error $syncHash.ErrorMsg
    exit 1
}

Write-Verbose "PowerEdge: Application closed cleanly."
exit 0
