<#
.SYNOPSIS
    LoadURLafter - Navigates the PowerEdge WebView2 instance to a new URL after a delay.

.DESCRIPTION
    LoadURLafter works exactly like LoadURL, but delays the navigation by a
    specified number of milliseconds before loading the target URL.

    A WPF DispatcherTimer is used to schedule the navigation on the UI thread,
    which ensures thread safety when called from within the STA UI runspace.

    Supported input formats:
      - Absolute URIs   : https://example.com
      - Local file paths: C:\MyApp\index.html  (auto-converted to file:///...)
      - Relative file paths are resolved relative to the PowerEdge script root.

.PARAMETER WebView
    The WebView2 control object (Microsoft.Web.WebView2.Wpf.WebView2).
    Must have completed CoreWebView2 initialization before calling this function.

.PARAMETER URL
    The target URL or local file path to navigate to after the delay.

.PARAMETER DelayMs
    The delay in milliseconds before the navigation is triggered.
    Must be greater than 0.

.OUTPUTS
    PSCustomObject with properties:
      .code  [int]    0 = success (timer started), non-zero = error
      .msg   [string] Human-readable result or error description

.EXAMPLE
    # Navigate to a new page after 3 seconds
    $result = LoadURLafter -WebView $webView -URL "https://example.com" -DelayMs 3000

.EXAMPLE
    # Load a local file after 2 seconds
    $result = LoadURLafter -WebView $webView -URL "C:\MyApp\page2.html" -DelayMs 2000

.NOTES
    Version:  1.00.02
    Author:   Praetoriani
    Created:  14.04.2026
#>
function LoadURLafter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$WebView,

        [Parameter(Mandatory = $true)]
        [string]$URL,

        [Parameter(Mandatory = $true)]
        [int]$DelayMs
    )

    # Validate parameters
    if ($null -eq $WebView) {
        return [PSCustomObject]@{ code = 1; msg = "LoadURLafter: WebView parameter is null." }
    }
    if ($null -eq $WebView.CoreWebView2) {
        return [PSCustomObject]@{ code = 2; msg = "LoadURLafter: CoreWebView2 is not initialized. Call EnsureCoreWebView2Async first." }
    }
    if ([string]::IsNullOrWhiteSpace($URL)) {
        return [PSCustomObject]@{ code = 3; msg = "LoadURLafter: URL parameter is null or empty." }
    }
    if ($DelayMs -le 0) {
        return [PSCustomObject]@{ code = 4; msg = "LoadURLafter: DelayMs must be greater than 0." }
    }

    try {
        # Resolve the target URI (same logic as LoadURL)
        $isAbsoluteUri = $false
        try {
            $parsedUri    = [System.Uri]::new($URL)
            $isAbsoluteUri = $parsedUri.IsAbsoluteUri
        }
        catch { $isAbsoluteUri = $false }

        if ($isAbsoluteUri -and $parsedUri.Scheme -match '^(https?|file)$') {
            $targetUri = $parsedUri.AbsoluteUri
        }
        else {
            if (-not [System.IO.Path]::IsPathRooted($URL)) {
                $URL = Join-Path $PSScriptRoot $URL
            }
            $resolvedPath = [System.IO.Path]::GetFullPath($URL)
            if (-not (Test-Path -LiteralPath $resolvedPath)) {
                return [PSCustomObject]@{ code = 5; msg = "LoadURLafter: File not found: $resolvedPath" }
            }
            $targetUri = [System.Uri]::new($resolvedPath).AbsoluteUri
        }

        # Create a DispatcherTimer to trigger navigation after DelayMs milliseconds
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds($DelayMs)

        # Capture variables for the timer tick closure
        $capturedWebView = $WebView
        $capturedUri     = $targetUri
        $capturedTimer   = $timer

        $timer.Add_Tick({
            $capturedWebView.CoreWebView2.Navigate($capturedUri)
            $capturedTimer.Stop()
        })

        $timer.Start()
        return [PSCustomObject]@{ code = 0; msg = "LoadURLafter: Navigation to '$targetUri' scheduled in ${DelayMs}ms." }
    }
    catch {
        return [PSCustomObject]@{ code = 99; msg = "LoadURLafter: Unexpected error: $($_.Exception.Message)" }
    }
}
