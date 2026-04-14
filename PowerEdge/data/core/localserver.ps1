
<#
.SYNOPSIS
    LocalServer - A lightweight PowerShell HTTP server for hosting local SPAs and web apps.

.DESCRIPTION
    This script defines the [LocalServer] class, which wraps the .NET HttpListener to provide
    a simple, stable HTTP server that runs as a background job. It can serve static files,
    SPAs (Single Page Applications), and standard HTML pages from a specified root directory.

    The server handles:
      - Static file serving (HTML, CSS, JS, JSON, images, fonts, etc.)
      - SPA fallback routing (all unknown routes serve index.html for client-side routing)
      - MIME type detection based on file extension
      - Directory listing (optional)
      - Graceful start/stop lifecycle management
      - Background execution via PowerShell Runspace (non-blocking)

.USAGE
    Dot-source this file to load the class:
        . .\localserver.ps1

    Then create and start an instance:
        $server = [LocalServer]::new("C:\MyApp", "http://localhost:8080/")
        $server.Start()

    To stop the server:
        $server.Stop()

    To check if the server is running:
        $server.IsRunning()

.NOTES
    Author      : localserver.ps1
    Requires    : PowerShell 5.1+ or PowerShell 7+
    Permissions : May require elevated privileges on Windows for non-localhost bindings.
                  Run 'netsh http add urlacl url=http://+:PORT/ user=DOMAIN\USER' for
                  non-localhost prefixes on Windows without elevation.
#>

using namespace System.Net
using namespace System.IO
using namespace System.Text
using namespace System.Collections.Generic

# ------------------------------------------------------------------------------------
# MIME TYPE MAP
# Maps file extensions to their corresponding MIME/Content-Type strings.
# Extend this dictionary to support additional file types.
# ------------------------------------------------------------------------------------
$Script:MimeTypes = [Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@{
    # Web core
    '.html'  = 'text/html; charset=utf-8'
    '.htm'   = 'text/html; charset=utf-8'
    '.css'   = 'text/css; charset=utf-8'
    '.js'    = 'application/javascript; charset=utf-8'
    '.mjs'   = 'application/javascript; charset=utf-8'
    '.json'  = 'application/json; charset=utf-8'
    '.map'   = 'application/json; charset=utf-8'
    '.ts'    = 'application/typescript; charset=utf-8'
    '.jsx'   = 'application/javascript; charset=utf-8'
    '.tsx'   = 'application/javascript; charset=utf-8'

    # Documents / data
    '.xml'   = 'application/xml; charset=utf-8'
    '.txt'   = 'text/plain; charset=utf-8'
    '.csv'   = 'text/csv; charset=utf-8'
    '.md'    = 'text/markdown; charset=utf-8'
    '.pdf'   = 'application/pdf'

    # Images
    '.png'   = 'image/png'
    '.jpg'   = 'image/jpeg'
    '.jpeg'  = 'image/jpeg'
    '.gif'   = 'image/gif'
    '.webp'  = 'image/webp'
    '.avif'  = 'image/avif'
    '.ico'   = 'image/x-icon'
    '.svg'   = 'image/svg+xml; charset=utf-8'
    '.bmp'   = 'image/bmp'
    '.tiff'  = 'image/tiff'

    # Fonts
    '.woff'  = 'font/woff'
    '.woff2' = 'font/woff2'
    '.ttf'   = 'font/ttf'
    '.otf'   = 'font/otf'
    '.eot'   = 'application/vnd.ms-fontobject'

    # Media
    '.mp4'   = 'video/mp4'
    '.webm'  = 'video/webm'
    '.ogg'   = 'video/ogg'
    '.mp3'   = 'audio/mpeg'
    '.wav'   = 'audio/wav'
    '.flac'  = 'audio/flac'

    # Archives / downloads
    '.zip'   = 'application/zip'
    '.gz'    = 'application/gzip'
    '.tar'   = 'application/x-tar'

    # Manifest / PWA
    '.webmanifest' = 'application/manifest+json'
}.GetEnumerator() | ForEach-Object { $Script:MimeTypes[$_.Key] = $_.Value }


# ------------------------------------------------------------------------------------
# CLASS: LocalServer
# ------------------------------------------------------------------------------------
class LocalServer {

    # ---- Public properties ---------------------------------------------------------

    # The absolute path to the web root directory to serve files from.
    [string] $RootPath

    # The URL prefix to listen on (e.g. "http://localhost:8080/").
    # Must end with a trailing slash.
    [string] $Prefix

    # If $true, unresolved URL paths fall back to serving index.html from the root.
    # This enables client-side routing for SPAs (React, Angular, Vue, etc.).
    [bool] $SpaFallback = $true

    # If $true, requests to a directory will return a simple HTML directory listing.
    # Only used when no index.html exists in that directory.
    [bool] $EnableDirectoryListing = $false

    # Optional custom response headers added to every response.
    # Example: $server.CustomHeaders["X-Frame-Options"] = "DENY"
    [Dictionary[string, string]] $CustomHeaders

    # ---- Private properties --------------------------------------------------------

    # The underlying .NET HttpListener instance.
    hidden [HttpListener] $_listener

    # The PowerShell Runspace used to run the request loop in a background thread.
    hidden [System.Management.Automation.Runspaces.Runspace] $_runspace

    # Tracks the async result from the Runspace pipeline invoke.
    hidden [System.IAsyncResult] $_asyncResult

    # The PowerShell pipeline object running inside the background Runspace.
    hidden [System.Management.Automation.PowerShell] $_pipeline

    # Shared thread-safe flag used to signal the background loop to stop.
    hidden [System.Threading.CancellationTokenSource] $_cts


    # ---- Constructor ---------------------------------------------------------------

    <#
    .SYNOPSIS
        Creates a new LocalServer instance.

    .PARAMETER rootPath
        The file system path to the directory to serve (web root).

    .PARAMETER prefix
        The HTTP URL prefix to listen on (default: "http://localhost:8080/").
        The prefix MUST end with a trailing slash.
    #>
    LocalServer([string]$rootPath, [string]$prefix = "http://localhost:8080/") {
        if (-not [System.IO.Directory]::Exists($rootPath)) {
            throw [System.IO.DirectoryNotFoundException]::new(
                "The specified root path does not exist: '$rootPath'"
            )
        }

        if (-not $prefix.EndsWith('/')) {
            throw [System.ArgumentException]::new(
                "The URL prefix must end with a trailing slash ('/'). Got: '$prefix'"
            )
        }

        $this.RootPath     = [System.IO.Path]::GetFullPath($rootPath)
        $this.Prefix       = $prefix
        $this.CustomHeaders = [Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # Default security headers — can be overridden via $server.CustomHeaders
        $this.CustomHeaders["X-Content-Type-Options"] = "nosniff"
        $this.CustomHeaders["X-Frame-Options"]        = "SAMEORIGIN"
        $this.CustomHeaders["Referrer-Policy"]        = "strict-origin-when-cross-origin"
    }


    # ---- Public Methods ------------------------------------------------------------

    <#
    .SYNOPSIS
        Starts the HTTP server in a background Runspace (non-blocking).

    .DESCRIPTION
        Initialises the .NET HttpListener, starts it, then spawns a background
        PowerShell Runspace that runs the request-handling loop. The calling thread
        is NOT blocked; control returns immediately after Start() completes.
    #>
    [void] Start() {
        if ($this.IsRunning()) {
            Write-Warning "[LocalServer] Server is already running on $($this.Prefix)"
            return
        }

        # -- Initialise and start the .NET HttpListener --
        $this._listener = [HttpListener]::new()
        $this._listener.Prefixes.Add($this.Prefix)

        try {
            $this._listener.Start()
        }
        catch [HttpListenerException] {
            throw [System.Exception]::new(
                "Failed to start HttpListener on '$($this.Prefix)'. " +
                "Ensure the port is not already in use and that you have permission " +
                "to bind to this address. Inner exception: $($_.Exception.Message)"
            )
        }

        # -- Create a CancellationTokenSource so we can gracefully stop the loop --
        $this._cts = [System.Threading.CancellationTokenSource]::new()

        # -- Capture properties needed inside the background script --
        # (Cannot reference $this directly across Runspace boundaries.)
        $capturedListener  = $this._listener
        $capturedRootPath  = $this.RootPath
        $capturedSpa       = $this.SpaFallback
        $capturedDirList   = $this.EnableDirectoryListing
        $capturedHeaders   = $this.CustomHeaders
        $capturedMimeTypes = $Script:MimeTypes
        $capturedCts       = $this._cts

        # -- Build the background script block that processes incoming requests --
        $requestLoop = {
            param(
                $Listener,
                $RootPath,
                $SpaFallback,
                $EnableDirectoryListing,
                $CustomHeaders,
                $MimeTypes,
                $Cts
            )

            # Helper: resolve a safe absolute file path from a URL path segment.
            # Returns $null if the resolved path escapes the root (path traversal guard).
            function Resolve-SafePath {
                param([string]$Root, [string]$UrlPath)

                # Decode percent-encoding and strip leading slash
                $decoded  = [Uri]::UnescapeDataString($UrlPath).TrimStart('/')
                # Normalise path separators for the OS
                $relative = $decoded.Replace('/', [IO.Path]::DirectorySeparatorChar)
                $full     = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, $relative))

                # Path traversal guard: resolved path must still be under Root
                if (-not $full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $null
                }
                return $full
            }

            # Helper: write a plain-text or HTML error response.
            function Write-ErrorResponse {
                param($Context, [int]$StatusCode, [string]$Message)
                $body  = [Text.Encoding]::UTF8.GetBytes("<html><body><h1>$StatusCode</h1><p>$Message</p></body></html>")
                $resp  = $Context.Response
                $resp.StatusCode        = $StatusCode
                $resp.ContentType       = 'text/html; charset=utf-8'
                $resp.ContentLength64   = $body.Length
                try {
                    $resp.OutputStream.Write($body, 0, $body.Length)
                } catch {}
                $resp.OutputStream.Close()
            }

            # Helper: generate a simple HTML directory listing page.
            function Get-DirectoryListing {
                param([string]$DirPath, [string]$UrlPath)

                $items = [System.Collections.Generic.List[string]]::new()
                $items.Add("<html><head><meta charset='utf-8'><title>Index of $UrlPath</title>")
                $items.Add("<style>body{font-family:monospace;padding:2rem}a{display:block;margin:.2rem 0}</style>")
                $items.Add("</head><body><h2>Index of $UrlPath</h2><hr>")

                # Parent directory link (if not at root)
                if ($UrlPath -ne '/') {
                    $parent = ($UrlPath.TrimEnd('/') -replace '/[^/]+$', '') -replace '^$', '/'
                    $items.Add("<a href='$parent'>[..]</a>")
                }

                # Subdirectories
                [IO.Directory]::GetDirectories($DirPath) | Sort-Object | ForEach-Object {
                    $name = [IO.Path]::GetFileName($_)
                    $items.Add("<a href='$UrlPath$name/'>[$name/]</a>")
                }
                # Files
                [IO.Directory]::GetFiles($DirPath) | Sort-Object | ForEach-Object {
                    $name = [IO.Path]::GetFileName($_)
                    $items.Add("<a href='$UrlPath$name'>$name</a>")
                }

                $items.Add("<hr></body></html>")
                return ($items -join "`n")
            }

            # ---- Main request loop ------------------------------------------------
            Write-Host "[LocalServer] Listening on $($Listener.Prefixes -join ', ')" -ForegroundColor Cyan
            Write-Host "[LocalServer] Serving files from: $RootPath" -ForegroundColor Cyan
            Write-Host "[LocalServer] SPA fallback: $SpaFallback | Directory listing: $EnableDirectoryListing" -ForegroundColor Cyan

            while (-not $Cts.IsCancellationRequested -and $Listener.IsListening) {

                # GetContext() blocks until a request arrives.
                # We use BeginGetContext/EndGetContext with a WaitHandle so we can
                # periodically check the cancellation token without a tight spin.
                $asyncResult = $Listener.BeginGetContext($null, $null)
                $signaled    = $asyncResult.AsyncWaitHandle.WaitOne(500) # 500ms timeout

                if (-not $signaled) {
                    # Timeout — loop back and re-check the cancellation token
                    continue
                }

                if ($Cts.IsCancellationRequested) { break }

                $context = $null
                try {
                    $context = $Listener.EndGetContext($asyncResult)
                } catch {
                    # Listener was stopped between BeginGetContext and EndGetContext
                    break
                }

                $request  = $context.Request
                $response = $context.Response
                $method   = $request.HttpMethod
                $urlPath  = $request.Url.AbsolutePath   # e.g. "/index.html" or "/assets/app.js"

                Write-Host "[LocalServer] $method $urlPath" -ForegroundColor Gray

                # -- Apply custom response headers to every response --
                foreach ($headerKV in $CustomHeaders.GetEnumerator()) {
                    try { $response.AddHeader($headerKV.Key, $headerKV.Value) } catch {}
                }

                # -- Only handle GET and HEAD requests --
                if ($method -notin @('GET','HEAD')) {
                    Write-ErrorResponse -Context $context -StatusCode 405 -Message "Method Not Allowed"
                    continue
                }

                try {
                    # -- Resolve the URL path to a file system path --
                    $fsPath = Resolve-SafePath -Root $RootPath -UrlPath $urlPath

                    if ($null -eq $fsPath) {
                        Write-ErrorResponse -Context $context -StatusCode 403 -Message "Forbidden"
                        continue
                    }

                    # -- Directory handling --
                    if ([IO.Directory]::Exists($fsPath)) {
                        # Check for index.html inside the directory
                        $indexFile = [IO.Path]::Combine($fsPath, 'index.html')
                        if ([IO.File]::Exists($indexFile)) {
                            $fsPath = $indexFile
                        }
                        elseif ($EnableDirectoryListing) {
                            # Serve directory listing
                            $listing = Get-DirectoryListing -DirPath $fsPath -UrlPath $urlPath
                            $body    = [Text.Encoding]::UTF8.GetBytes($listing)
                            $response.StatusCode       = 200
                            $response.ContentType      = 'text/html; charset=utf-8'
                            $response.ContentLength64  = $body.Length
                            if ($method -eq 'GET') {
                                $response.OutputStream.Write($body, 0, $body.Length)
                            }
                            $response.OutputStream.Close()
                            continue
                        }
                        else {
                            # No index.html and directory listing disabled - 403
                            Write-ErrorResponse -Context $context -StatusCode 403 -Message "Forbidden"
                            continue
                        }
                    }

                    # -- File not found handling --
                    if (-not [IO.File]::Exists($fsPath)) {
                        if ($SpaFallback) {
                            # SPA fallback: serve root index.html for unknown paths
                            # so the SPA's client-side router can handle them.
                            $spaIndex = [IO.Path]::Combine($RootPath, 'index.html')
                            if ([IO.File]::Exists($spaIndex)) {
                                Write-Host "[LocalServer]  -> SPA fallback: serving index.html" -ForegroundColor DarkYellow
                                $fsPath = $spaIndex
                            }
                            else {
                                Write-ErrorResponse -Context $context -StatusCode 404 -Message "Not Found (SPA index.html missing)"
                                continue
                            }
                        }
                        else {
                            Write-ErrorResponse -Context $context -StatusCode 404 -Message "Not Found"
                            continue
                        }
                    }

                    # -- Serve the file --
                    $ext      = [IO.Path]::GetExtension($fsPath).ToLowerInvariant()
                    $mimeType = 'application/octet-stream'  # safe default
                    if ($MimeTypes.ContainsKey($ext)) {
                        $mimeType = $MimeTypes[$ext]
                    }

                    $fileBytes = [IO.File]::ReadAllBytes($fsPath)

                    $response.StatusCode      = 200
                    $response.ContentType     = $mimeType
                    $response.ContentLength64 = $fileBytes.Length

                    # For HEAD requests we skip writing the body
                    if ($method -eq 'GET') {
                        $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
                    }
                    $response.OutputStream.Close()

                }
                catch {
                    Write-Warning "[LocalServer] Error handling request for '$urlPath': $($_.Exception.Message)"
                    try {
                        Write-ErrorResponse -Context $context -StatusCode 500 -Message "Internal Server Error"
                    } catch {}
                }
            }

            Write-Host "[LocalServer] Request loop exited." -ForegroundColor Yellow
        }  # end $requestLoop script block

        # -- Create a dedicated Runspace (background thread) for the request loop --
        $this._runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $this._runspace.ApartmentState = [System.Threading.ApartmentState]::MTA
        $this._runspace.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $this._runspace.Open()

        # -- Build the pipeline and pass captured variables as parameters --
        $this._pipeline = [System.Management.Automation.PowerShell]::Create()
        $this._pipeline.Runspace = $this._runspace
        $this._pipeline.AddScript($requestLoop) | Out-Null
        $this._pipeline.AddArgument($capturedListener)  | Out-Null
        $this._pipeline.AddArgument($capturedRootPath)  | Out-Null
        $this._pipeline.AddArgument($capturedSpa)       | Out-Null
        $this._pipeline.AddArgument($capturedDirList)   | Out-Null
        $this._pipeline.AddArgument($capturedHeaders)   | Out-Null
        $this._pipeline.AddArgument($capturedMimeTypes) | Out-Null
        $this._pipeline.AddArgument($capturedCts)       | Out-Null

        # BeginInvoke starts the pipeline asynchronously; the calling thread returns.
        $this._asyncResult = $this._pipeline.BeginInvoke()

        Write-Host "[LocalServer] Server started. Open $($this.Prefix) in your browser." -ForegroundColor Green
    }


    <#
    .SYNOPSIS
        Stops the HTTP server and releases all resources.

    .DESCRIPTION
        Signals the background request loop to stop, stops and closes the HttpListener,
        and disposes of the background Runspace.
    #>
    [void] Stop() {
        if (-not $this.IsRunning()) {
            Write-Warning "[LocalServer] Server is not currently running."
            return
        }

        Write-Host "[LocalServer] Stopping server..." -ForegroundColor Yellow

        # Signal the background loop to stop gracefully
        if ($null -ne $this._cts) {
            $this._cts.Cancel()
        }

        # Stop the .NET HttpListener (this also unblocks any pending GetContext calls)
        try {
            if ($null -ne $this._listener -and $this._listener.IsListening) {
                $this._listener.Stop()
                $this._listener.Close()
            }
        } catch { <# Ignore errors during shutdown #> }

        # Wait for the background pipeline to finish (with a 3-second timeout)
        if ($null -ne $this._pipeline -and $null -ne $this._asyncResult) {
            $finished = $this._asyncResult.AsyncWaitHandle.WaitOne(3000)
            if (-not $finished) {
                Write-Warning "[LocalServer] Background pipeline did not stop within 3 seconds."
            }
            try { $this._pipeline.EndInvoke($this._asyncResult) } catch { <# ignore #> }
            $this._pipeline.Dispose()
        }

        # Close the Runspace
        try {
            if ($null -ne $this._runspace) {
                $this._runspace.Close()
                $this._runspace.Dispose()
            }
        } catch { <# ignore #> }

        # Clean up references
        $this._listener  = $null
        $this._pipeline  = $null
        $this._runspace  = $null
        $this._asyncResult = $null
        $this._cts       = $null

        Write-Host "[LocalServer] Server stopped." -ForegroundColor Yellow
    }


    <#
    .SYNOPSIS
        Returns $true if the server is currently running (HttpListener is active).
    #>
    [bool] IsRunning() {
        return ($null -ne $this._listener -and $this._listener.IsListening)
    }


    <#
    .SYNOPSIS
        Opens the server's base URL in the system's default browser.

    .DESCRIPTION
        Launches the configured prefix URL in the default web browser.
        Works on Windows (with 'start'), macOS ('open'), and Linux ('xdg-open').
    #>
    [void] OpenInBrowser() {
        $url = $this.Prefix
        if (-not $this.IsRunning()) {
            Write-Warning "[LocalServer] Server is not running. Start it first before opening in browser."
            return
        }
        Write-Host "[LocalServer] Opening $url in default browser..." -ForegroundColor Cyan
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            Start-Process $url
        }
        elseif ($IsMacOS) {
            & open $url
        }
        else {
            & xdg-open $url
        }
    }


    <#
    .SYNOPSIS
        Returns a status summary string for the server instance.
    #>
    [string] ToString() {
        $status = if ($this.IsRunning()) { "Running" } else { "Stopped" }
        return "[LocalServer] Status=$status | Prefix=$($this.Prefix) | Root=$($this.RootPath) | SPA=$($this.SpaFallback)"
    }
}


# ------------------------------------------------------------------------------------
# CONVENIENCE FUNCTION: New-LocalServer
# ------------------------------------------------------------------------------------
<#
.SYNOPSIS
    Factory function to create and optionally start a LocalServer instance.

.DESCRIPTION
    A helper function for use after dot-sourcing localserver.ps1.
    Creates a [LocalServer] instance with sensible defaults and optionally
    starts the server and opens the browser immediately.

.PARAMETER RootPath
    The file system path to the web root directory to serve.

.PARAMETER Port
    The TCP port to listen on (default: 8080).

.PARAMETER HostName
    The hostname to bind to (default: "localhost").

.PARAMETER SpaFallback
    If $true (default), unknown URL paths fall back to index.html for SPA routing.

.PARAMETER EnableDirectoryListing
    If $true, requests to directories without index.html show a file listing.

.PARAMETER AutoStart
    If $true (default), automatically calls Start() on the returned instance.

.PARAMETER OpenBrowser
    If $true (default), opens the server URL in the default browser after starting.

.EXAMPLE
    . .\localserver.ps1
    $server = New-LocalServer -RootPath "C:\MyApp\dist" -Port 3000
    # Server is running at http://localhost:3000/

.EXAMPLE
    . .\localserver.ps1
    $server = New-LocalServer -RootPath ".\public" -Port 9000 -SpaFallback $false -OpenBrowser $false
    $server.Start()
#>
function New-LocalServer {
    [CmdletBinding()]
    [OutputType([LocalServer])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $RootPath,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int] $Port = 8080,

        [Parameter()]
        [string] $HostName = "localhost",

        [Parameter()]
        [bool] $SpaFallback = $true,

        [Parameter()]
        [bool] $EnableDirectoryListing = $false,

        [Parameter()]
        [bool] $AutoStart = $true,

        [Parameter()]
        [bool] $OpenBrowser = $true
    )

    $prefix = "http://${HostName}:${Port}/"
    $server = [LocalServer]::new($RootPath, $prefix)
    $server.SpaFallback             = $SpaFallback
    $server.EnableDirectoryListing  = $EnableDirectoryListing

    if ($AutoStart) {
        $server.Start()
        if ($OpenBrowser) {
            Start-Sleep -Milliseconds 400   # brief pause to ensure listener is ready
            $server.OpenInBrowser()
        }
    }

    return $server
}
