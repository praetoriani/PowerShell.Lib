<#
.SYNOPSIS
    Loads the Microsoft WebView2 WPF assemblies from the .\lib\ directory.
.DESCRIPTION
    Attempts to load Microsoft.Web.WebView2.Core.dll and
    Microsoft.Web.WebView2.Wpf.dll from the .\lib\ subdirectory.
    If the DLLs are not found there, falls back to checking the NuGet
    package cache. Returns a status object indicating success or failure.
.EXAMPLE
    $result = LoadWebViewDLLs
.NOTES
    Version: 1.00.01 | Author: Praetoriani
#>
function LoadWebViewDLLs {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $status = NewStatusObject -Code -1 -Msg ""

    $coreDll = Join-Path $global:libpath "Microsoft.Web.WebView2.Core.dll"
    $wpfDll  = Join-Path $global:libpath "Microsoft.Web.WebView2.Wpf.dll"

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
