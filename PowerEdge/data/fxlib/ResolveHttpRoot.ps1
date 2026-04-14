<#
.SYNOPSIS
    Validates and canonicalizes the path to the HTML file to be loaded.
.DESCRIPTION
    Accepts a user-provided path or falls back to the default data\web\index.html.
    Performs path canonicalization and validates that the resolved path exists
    and has an .html or .htm extension.
.PARAMETER InputPath
    Raw path string as provided by the user or empty string for default fallback.
.EXAMPLE
    $result = ResolveHttpRoot -InputPath ".\data\web\index.html"
.NOTES
    Version: 1.00.02 | Author: Praetoriani
#>
function ResolveHttpRoot {
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