<#
.SYNOPSIS
    PowerEdge v1.00.00 - A WPF host application that embeds a Microsoft Edge (WebView2) instance
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
    Last Update:   12.04.2026
    Version:       1.00.00
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    REQUIREMENTS & DEPENDENCIES:
    - PowerShell 5.1 or higher (PowerShell 7.x recommended)
    - .NET Framework 4.7.2 or higher (for WPF)
    - Microsoft Edge WebView2 Runtime (must be installed on the system)
      Download: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
    - Microsoft.Web.WebView2 NuGet package DLLs placed in .\lib\ subdirectory
      (Microsoft.Web.WebView2.Core.dll + Microsoft.Web.WebView2.Wpf.dll)
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
$global:AppName  = "PowerEdge"
$global:AppVers  = "1.00.00"
$global:AppPath  = $PSScriptRoot
$global:AppIcon  = Join-Path $PSScriptRoot "poweredge.ico"

# Internal path constants
$global:GuiDir   = Join-Path $PSScriptRoot ".gui"
$global:WebAppDir = Join-Path $PSScriptRoot "webapp"
$global:LibDir   = Join-Path $PSScriptRoot "lib"
$global:XamlFile = Join-Path $global:GuiDir "main.window.xml"

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
        and has an .html or .htm extension. Does NOT enforce directory whitelisting
        for maximum flexibility in v1.00.00 (planned for v1.01.00).
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

    # Determine which path to use: user-provided or default fallback
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        $targetPath = Join-Path $global:WebAppDir "index.html"
        Write-Verbose "PowerEdge: No WebAppPath provided. Using default: $targetPath"
    }
    else {
        # Resolve relative paths against the script root
        if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
            $targetPath = Join-Path $global:AppPath $InputPath
        }
        else {
            $targetPath = $InputPath
        }
    }

    # Canonicalize the path to prevent directory traversal
    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($targetPath)
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Path canonicalization failed for '$targetPath': $($_.Exception.Message)"
        return $status
    }

    # Validate that the file exists
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        $status.code = -1
        $status.msg  = "PowerEdge: HTML file not found at resolved path: '$resolvedPath'"
        return $status
    }

    # Validate file extension (only .html and .htm are permitted)
    $ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($ext -notin @(".html", ".htm")) {
        $status.code = -1
        $status.msg  = "PowerEdge: Invalid file extension '$ext'. Only .html and .htm are permitted."
        return $status
    }

    # Return success with the resolved path in the msg field
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

    # Check that the XAML file exists
    if (-not (Test-Path -LiteralPath $XamlFilePath -PathType Leaf)) {
        $status.code = -1
        $status.msg  = "PowerEdge: XAML definition file not found: '$XamlFilePath'"
        return $status
    }

    # Load and parse the XML content
    try {
        [xml]$xamlDoc = Get-Content -LiteralPath $XamlFilePath -Raw -Encoding UTF8
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Failed to parse XAML file '$XamlFilePath': $($_.Exception.Message)"
        return $status
    }

    # Return the parsed XmlDocument via a wrapper object
    $status.code = 0
    $status.msg  = ""
    # Attach the XML document as a note property for retrieval
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
        If the DLLs are not found there, falls back to checking the GAC/standard
        assembly resolution. Returns a status object indicating success or failure.
    .EXAMPLE
        $result = Import-WebView2Assemblies
    .NOTES
        Version: 1.00.00 | Author: Praetoriani
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $status = New-StatusObject -Code -1 -Msg ""

    $coreDll = Join-Path $global:LibDir "Microsoft.Web.WebView2.Core.dll"
    $wpfDll  = Join-Path $global:LibDir "Microsoft.Web.WebView2.Wpf.dll"

    $dllsInLib = (Test-Path -LiteralPath $coreDll) -and (Test-Path -LiteralPath $wpfDll)

    if ($dllsInLib) {
        # Load from local .\lib\ directory
        try {
            Add-Type -Path $coreDll -ErrorAction Stop
            Write-Verbose "PowerEdge: Loaded WebView2.Core from lib\."
        }
        catch {
            # Assembly might already be loaded — that is acceptable
            Write-Verbose "PowerEdge: WebView2.Core load note: $($_.Exception.Message)"
        }
        try {
            Add-Type -Path $wpfDll -ErrorAction Stop
            Write-Verbose "PowerEdge: Loaded WebView2.Wpf from lib\."
        }
        catch {
            Write-Verbose "PowerEdge: WebView2.Wpf load note: $($_.Exception.Message)"
        }
    }
    else {
        # DLLs not in .\lib\ — attempt to resolve via NuGet package cache or PATH
        Write-Verbose "PowerEdge: WebView2 DLLs not found in .\lib\. Attempting standard resolution."
        $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages\microsoft.web.webview2"
        if (Test-Path $nugetCache) {
            # Find the latest version folder
            $latestVer = Get-ChildItem $nugetCache -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestVer) {
                $nugetCore = Join-Path $latestVer.FullName "lib\net45\Microsoft.Web.WebView2.Core.dll"
                $nugetWpf  = Join-Path $latestVer.FullName "lib\net45\Microsoft.Web.WebView2.Wpf.dll"
                # Try net45, then check for other TFMs
                $wpfCandidates = Get-ChildItem (Join-Path $latestVer.FullName "lib") -Recurse -Filter "Microsoft.Web.WebView2.Wpf.dll" -ErrorAction SilentlyContinue
                if ($wpfCandidates) {
                    foreach ($candidate in $wpfCandidates) {
                        try { Add-Type -Path $candidate.FullName -ErrorAction Stop; break } catch {}
                    }
                }
            }
        }
    }

    # Verify the type is resolvable after loading attempts
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
    Write-Host "  2. Extract and place these files into .\lib\:" -ForegroundColor Cyan
    Write-Host "     - Microsoft.Web.WebView2.Core.dll" -ForegroundColor Cyan
    Write-Host "     - Microsoft.Web.WebView2.Wpf.dll" -ForegroundColor Cyan
    Write-Host "  3. Ensure the WebView2 Runtime is installed on this machine." -ForegroundColor Cyan
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

# Step 4: Build the WPF window from the XAML definition in an STA runspace
# WPF requires a Single-Thread Apartment (STA) thread to operate.
# We use a synchronized hashtable to pass data between the calling thread and the UI thread.
$syncHash = [hashtable]::Synchronized(@{
    HtmlPath    = $resolvedHtmlPath
    WindowTitle = $WindowTitle
    XamlDoc     = $xamlDoc
    AppIcon     = $global:AppIcon
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

    try {
        # Parse XAML and create the Window object
        $reader = [System.Xml.XmlNodeReader]::new($syncHash.XamlDoc)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        if ($null -eq $window) {
            $syncHash.ExitCode = -1
            $syncHash.ErrorMsg = "PowerEdge: XamlReader returned null — XAML parsing failed."
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
        $webView    = $window.FindName("MainWebView")
        $titleBar   = $window.FindName("TitleBarText")
        $btnClose   = $window.FindName("BtnClose")
        $btnMinimize = $window.FindName("BtnMinimize")
        $btnMaximize = $window.FindName("BtnMaximize")
        $statusText = $window.FindName("StatusText")
        $loadingOverlay = $window.FindName("LoadingOverlay")

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
        $titleBarPanel = $window.FindName("TitleBarPanel")
        if ($null -ne $titleBarPanel) {
            $titleBarPanel.Add_MouseLeftButtonDown({
                param($sender, $e)
                $window.DragMove()
            })
        }

        # WebView2: Navigate to the local HTML file once the control is initialized
        if ($null -ne $webView) {
            # Update status text
            if ($null -ne $statusText) {
                $statusText.Text = "Loading web application..."
            }

            # Hook into CoreWebView2InitializationCompleted to navigate after init
            $webView.Add_CoreWebView2InitializationCompleted({
                param($sender, $e)
                if ($e.IsSuccess) {
                    # Convert local file path to a file:// URI
                    $fileUri = [System.Uri]::new($syncHash.HtmlPath)
                    $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)

                    # Hide loading overlay once navigation starts
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

            # Trigger async WebView2 initialization
            $webView.EnsureCoreWebView2Async($null) | Out-Null
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
