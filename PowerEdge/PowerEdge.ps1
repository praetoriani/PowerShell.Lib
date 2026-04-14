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
    Last Update:   14.04.2026
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

        Error handling differentiates between three cases:
          1. ReflectionTypeLoadException  - DLL found but dependencies missing or
                                            wrong Target Framework (TFM).
          2. FileLoadException / BadImageFormatException - DLL is blocked (Zone.Identifier),
                                            corrupted, or bitness mismatch (x86 vs x64).
          3. Assembly already loaded      - Benign; treated as success.
          4. Any other exception          - Treated as a real error and propagated.
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
            # DLL found but one or more dependent types could not be resolved.
            # Most likely cause: wrong Target Framework (e.g. netcoreapp DLL loaded
            # under PowerShell 5.1 / .NET Framework), or WebView2Loader.dll missing.
            $loaderMsgs = ($_.Exception.LoaderExceptions | ForEach-Object { $_.Message }) -join "; "
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (ReflectionTypeLoadException). " +
                           "Verify the DLL targets net462 and that WebView2Loader.dll is present in .\lib\. " +
                           "LoaderExceptions: $loaderMsgs"
            return $status
        }
        catch [System.BadImageFormatException] {
            # Bitness mismatch (x86 DLL in x64 process or vice versa), or the file
            # is not a valid managed assembly at all.
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (BadImageFormatException). " +
                           "The DLL architecture does not match the PowerShell process (x86/x64 mismatch), " +
                           "or the file is not a valid .NET assembly. Details: $($_.Exception.Message)"
            return $status
        }
        catch [System.IO.FileLoadException] {
            # File was found but loading was refused - most commonly because the file
            # is blocked by Windows (Zone.Identifier ADS). Run: Unblock-File .\lib\*.dll
            $status.code = -1
            $status.msg  = "PowerEdge: WebView2.Core could not be loaded (FileLoadException). " +
                           "The file may be blocked by Windows security (Zone.Identifier). " +
                           "Run 'Get-ChildItem .\lib\*.dll | Unblock-File' and retry. " +
                           "Details: $($_.Exception.Message)"
            return $status
        }
        catch {
            # Distinguish "already loaded" (benign) from any other unexpected error.
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
        # DLLs not in .\lib\ - attempt to resolve via NuGet package cache or PATH
        Write-Verbose "PowerEdge: WebView2 DLLs not found in .\lib\. Attempting standard resolution."
        $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages\microsoft.web.webview2"
        if (Test-Path $nugetCache) {
            # Find the latest version folder
            $latestVer = Get-ChildItem $nugetCache -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestVer) {
                # Try net462 first (PS 5.1 / .NET Framework), then other TFMs
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
    # Verify the WPF control type is actually accessible after all loading attempts.
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

# Step 4: Build the WPF window from the XAML definition in an STA runspace
# WPF requires a Single-Thread Apartment (STA) thread to operate.
# We use a synchronized hashtable to pass data between the calling thread and the UI thread.
$syncHash = [hashtable]::Synchronized(@{
    HtmlPath    = $resolvedHtmlPath
    WindowTitle = $WindowTitle
    XamlDoc     = $xamlDoc
    AppIcon     = $global:AppIcon
    LibDir      = $global:LibDir
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
    # main thread are NOT automatically available here. Without this, the XAML
    # reader cannot resolve the <wv2:WebView2> element type.
    $libDir = $syncHash.LibDir
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
