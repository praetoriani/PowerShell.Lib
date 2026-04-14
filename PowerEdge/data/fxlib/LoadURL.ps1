<#
.SYNOPSIS
    LoadURL - Navigates the PowerEdge WebView2 instance to a new URL or local file.

.DESCRIPTION
    LoadURL navigates the active WebView2 control (MainWebView) to the specified
    URL or local file path. The function accesses the WebView2 CoreWebView2
    object via the synchronized hashtable that PowerEdge.ps1 shares with the
    UI runspace.

    Supported input formats:
      - Absolute URIs   : https://example.com
      - Local file paths: C:\MyApp\index.html  (auto-converted to file:///...)
      - Relative file paths are resolved relative to the PowerEdge script root.

.PARAMETER WebView
    The WebView2 control object (Microsoft.Web.WebView2.Wpf.WebView2).
    Must have completed CoreWebView2 initialization before calling this function.

.PARAMETER URL
    The target URL or local file path to navigate to.

.OUTPUTS
    PSCustomObject with properties:
      .code  [int]    0 = success, non-zero = error
      .msg   [string] Human-readable result or error description

.EXAMPLE
    $result = LoadURL -WebView $webView -URL "https://example.com"

.EXAMPLE
    $result = LoadURL -WebView $webView -URL "C:\MyApp\dashboard.html"

.NOTES
    Version:  1.00.02
    Author:   Praetoriani
    Created:  14.04.2026
#>
function LoadURL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$WebView,

        [Parameter(Mandatory = $true)]
        [string]$URL
    )

    # Validate WebView2 readiness
    if ($null -eq $WebView) {
        return [PSCustomObject]@{ code = 1; msg = "LoadURL: WebView parameter is null." }
    }
    if ($null -eq $WebView.CoreWebView2) {
        return [PSCustomObject]@{ code = 2; msg = "LoadURL: CoreWebView2 is not initialized. Call EnsureCoreWebView2Async first." }
    }
    if ([string]::IsNullOrWhiteSpace($URL)) {
        return [PSCustomObject]@{ code = 3; msg = "LoadURL: URL parameter is null or empty." }
    }

    try {
        # Determine if input is a URI or a file system path
        $isAbsoluteUri = $false
        try {
            $parsedUri = [System.Uri]::new($URL)
            $isAbsoluteUri = $parsedUri.IsAbsoluteUri
        }
        catch { $isAbsoluteUri = $false }

        if ($isAbsoluteUri -and $parsedUri.Scheme -match '^(https?|file)$') {
            # Already a valid absolute URI (http/https/file) - use as-is
            $targetUri = $parsedUri.AbsoluteUri
        }
        else {
            # Treat as file system path - convert to file:/// URI
            if (-not [System.IO.Path]::IsPathRooted($URL)) {
                $URL = Join-Path $PSScriptRoot $URL
            }
            $resolvedPath = [System.IO.Path]::GetFullPath($URL)
            if (-not (Test-Path -LiteralPath $resolvedPath)) {
                return [PSCustomObject]@{ code = 4; msg = "LoadURL: File not found: $resolvedPath" }
            }
            $targetUri = [System.Uri]::new($resolvedPath).AbsoluteUri
        }

        # Perform navigation
        $WebView.CoreWebView2.Navigate($targetUri)
        return [PSCustomObject]@{ code = 0; msg = "LoadURL: Navigation initiated to '$targetUri'." }
    }
    catch {
        return [PSCustomObject]@{ code = 99; msg = "LoadURL: Unexpected error: $($_.Exception.Message)" }
    }
}
