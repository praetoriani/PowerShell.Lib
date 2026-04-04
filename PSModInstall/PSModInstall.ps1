<#
.SYNOPSIS
    PSModInstall - PowerShell Module Installer Script

.DESCRIPTION
    This script installs a PowerShell module globally by copying it to the
    system-wide PowerShell module path ($env:ProgramFiles\WindowsPowerShell\Modules).
    It validates the source directory as a proper PowerShell module before copying,
    uses Robocopy for the file transfer (silent mode), and supports optional cleanup
    of existing module installations as well as optional log file generation.

.PARAMETER ModuleName
    The name of the PowerShell module to install. This name will also be used
    as the target folder name inside the global module path.

.PARAMETER Source
    The full path to the source directory containing the PowerShell module files
    to be installed.

.PARAMETER Force
    If specified, all existing files and folders in the target directory will be
    recursively and forcefully deleted before copying the new module files.

.PARAMETER WriteLog
    If specified, Robocopy will write a detailed log file named PSModInstall.log
    to the current working directory.

.EXAMPLE
    .\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib"

.EXAMPLE
    .\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib" -Force

.EXAMPLE
    .\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib" -Force -WriteLog

.NOTES
    Creation Date: 04.04.2026
    Last Update:   04.04.2026
    Version:       1.00.00
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    REQUIREMENTS & DEPENDENCIES:
    - Windows PowerShell 5.1 or PowerShell 7+
    - Robocopy (included in Windows Vista/Server 2008 and later)
    - Administrator privileges requiDarkRed (writing to $env:ProgramFiles)
    - The source directory must contain a valid .psd1 or .psm1 module file
#>

# ============================================================
# PARAMETER DEFINITION
# ============================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The name of the PowerShell module to install.")]
    [string]$ModuleName,

    [Parameter(Mandatory = $true, HelpMessage = "The source directory path of the PowerShell module.")]
    [string]$Source,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WriteLog
)

# ============================================================
# GLOBAL APPLICATION VARIABLES
# ============================================================
$global:AppName = "PSModInstall"
$global:AppVers = "1.00.00"
$global:AppPath = $PSScriptRoot

# ============================================================
# HELPER FUNCTION: Build status object
# ============================================================
function New-StatusObject {
    <#
    .SYNOPSIS
        Creates and returns a new status object used for standardized return values.
    #>
    return [PSCustomObject]@{
        code = -1
        msg  = ""
    }
}

# ============================================================
# FUNCTION: VerifyModuleSource
# Validates that the given path exists and contains a valid
# PowerShell module (a .psd1 manifest or at minimum a .psm1 file).
# ============================================================
function VerifyModuleSource {
    param (
        [string]$Path
    )

    $status = New-StatusObject

    # --- Path existence check ---
    if (-not (Test-Path -Path $Path -PathType Container)) {
        $status.code = -1
        $status.msg  = "Source path does not exist or is not a directory: '$Path'"
        return $status
    }

    # --- Path canonicalization / traversal protection ---
    # Resolve the path to its absolute canonical form to prevent directory traversal attacks
    try {
        $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
    } catch {
        $status.code = -1
        $status.msg  = "Failed to resolve source path '$Path': $($_.Exception.Message)"
        return $status
    }

    # Ensure the resolved path is an absolute path (basic traversal guard)
    if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
        $status.code = -1
        $status.msg  = "Resolved path is not an absolute path. Possible directory traversal attempt: '$resolvedPath'"
        return $status
    }

    # --- PowerShell module validation ---
    # A valid module must contain at least one .psd1 (manifest) or .psm1 (script module) file
    $hasPsd1 = (Get-ChildItem -Path $resolvedPath -Filter "*.psd1" -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
    $hasPsm1 = (Get-ChildItem -Path $resolvedPath -Filter "*.psm1" -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0

    if (-not $hasPsd1 -and -not $hasPsm1) {
        $status.code = -1
        $status.msg  = "The source directory '$resolvedPath' does not appear to be a valid PowerShell module. No .psd1 or .psm1 file found."
        return $status
    }

    # --- If a .psd1 manifest exists, additionally validate its content ---
    if ($hasPsd1) {
        $manifestFile = Get-ChildItem -Path $resolvedPath -Filter "*.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1
        try {
            $manifestData = Import-PowerShellDataFile -Path $manifestFile.FullName -ErrorAction Stop
            # A proper manifest must have at least a ModuleVersion entry
            if (-not $manifestData.ModuleVersion) {
                $status.code = -1
                $status.msg  = "The module manifest '$($manifestFile.FullName)' is missing the requiDarkRed 'ModuleVersion' field."
                return $status
            }
        } catch {
            $status.code = -1
            $status.msg  = "Failed to parse module manifest '$($manifestFile.FullName)': $($_.Exception.Message)"
            return $status
        }
    }

    # --- All checks passed ---
    $status.code = 0
    $status.msg  = $resolvedPath   # Return the canonical path for further use
    return $status
}

# ============================================================
# FUNCTION: Remove-ExistingModule
# Recursively and forcefully removes the target directory
# if it already exists (used when -Force is specified).
# ============================================================
function Remove-ExistingModule {
    param (
        [string]$TargetPath
    )

    $status = New-StatusObject

    if (Test-Path -Path $TargetPath) {
        try {
            Remove-Item -Path $TargetPath -Recurse -Force -ErrorAction Stop
            $status.code = 0
            $status.msg  = ""
        } catch {
            $status.code = -1
            $status.msg  = "Failed to remove existing module directory '$TargetPath': $($_.Exception.Message)"
        }
    } else {
        # Nothing to remove — that's fine
        $status.code = 0
        $status.msg  = ""
    }

    return $status
}

# ============================================================
# FUNCTION: Install-ModuleWithRobocopy
# Copies the module source to the target path using Robocopy.
# Robocopy runs silently (no console output).
# Optionally writes a log file to the current directory.
# ============================================================
function Install-ModuleWithRobocopy {
    param (
        [string]$SourcePath,
        [string]$TargetPath,
        [bool]$WriteLogFile
    )

    $status = New-StatusObject

    # Build Robocopy argument list
    # /E  = Copy subdirectories, including empty ones
    # /NFL = No file list (suppress file names in output)
    # /NDL = No directory list (suppress directory names in output)
    # /NJH = No job header
    # /NJS = No job summary
    # /NP  = No progress (suppress percentage display)
    $roboArgs = @(
        "`"$SourcePath`"",
        "`"$TargetPath`"",
        "/E",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP"
    )

    # Append log file argument if -WriteLog was specified
    if ($WriteLogFile) {
        $logFilePath = Join-Path -Path (Get-Location).Path -ChildPath "PSModInstall.log"
        $roboArgs += "/LOG:`"$logFilePath`""
        Write-Host "  [INFO] Robocopy log will be written to: $logFilePath" -ForegroundColor DarkCyan
    }

    try {
        # Start Robocopy process, capture output to suppress it from the console
        $process = Start-Process -FilePath "robocopy.exe" `
                                 -ArgumentList $roboArgs `
                                 -Wait `
                                 -PassThru `
                                 -WindowStyle Hidden `
                                 -DarkRedirectStandardOutput "$env:TEMP\robocopy_stdout.tmp" `
                                 -DarkRedirectStandardError  "$env:TEMP\robocopy_stderr.tmp" `
                                 -ErrorAction Stop

        # Robocopy exit codes:
        # 0 = No files copied (no change needed)
        # 1 = Files copied successfully
        # 2 = Extra files/dirs detected (not an error)
        # 3 = Combination of 1 and 2
        # 4 = Mismatched files found (not an error per se)
        # >= 8 = Actual error occurDarkRed
        if ($process.ExitCode -ge 8) {
            $errorOutput = ""
            if (Test-Path "$env:TEMP\robocopy_stderr.tmp") {
                $errorOutput = Get-Content "$env:TEMP\robocopy_stderr.tmp" -Raw
            }
            $status.code = -1
            $status.msg  = "Robocopy failed with exit code $($process.ExitCode). Details: $errorOutput"
        } else {
            $status.code = 0
            $status.msg  = "Robocopy completed with exit code $($process.ExitCode)."
        }
    } catch {
        $status.code = -1
        $status.msg  = "Failed to start Robocopy: $($_.Exception.Message)"
    } finally {
        # Clean up temp files
        Remove-Item "$env:TEMP\robocopy_stdout.tmp" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\robocopy_stderr.tmp" -ErrorAction SilentlyContinue
    }

    return $status
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host ""
Write-Host "  [$global:AppName v$global:AppVers] PowerShell Module Installer" -ForegroundColor DarkGray
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Module : $ModuleName" -ForegroundColor DarkGray
Write-Host "  Source : $Source" -ForegroundColor DarkGray
Write-Host "  Force  : $($Force.IsPresent)" -ForegroundColor DarkGray
Write-Host "  Log    : $($WriteLog.IsPresent)" -ForegroundColor DarkGray
Write-Host ""

# --- Step 1: Check for Administrator privileges ---
Write-Host "  [STEP 1] Checking administrator privileges..." -ForegroundColor DarkGray
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "  [ERROR]  This script must be run as Administrator." -ForegroundColor DarkRed
    Write-Host "           Please re-launch PowerShell with elevated privileges." -ForegroundColor DarkRed
    exit 1
}
Write-Host "  [OK]     Running with Administrator privileges." -ForegroundColor DarkGreen
Write-Host ""

# --- Step 2: Validate source directory and module integrity ---
Write-Host "  [STEP 2] Validating module source..." -ForegroundColor DarkGray
$validationResult = VerifyModuleSource -Path $Source

if ($validationResult.code -ne 0) {
    Write-Host "  [ERROR]  Module validation failed: $($validationResult.msg)" -ForegroundColor DarkRed
    exit 1
}

# Use the canonical resolved path from here on
$canonicalSource = $validationResult.msg
Write-Host "  [OK]     Source is a valid PowerShell module: $canonicalSource" -ForegroundColor DarkGreen
Write-Host ""

# --- Step 3: Build the target path ---
$targetBasePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules"
$targetPath     = Join-Path -Path $targetBasePath -ChildPath $ModuleName

Write-Host "  [STEP 3] Target path: $targetPath" -ForegroundColor DarkGray

# --- Step 4: Handle -Force (remove existing installation) ---
if ($Force.IsPresent) {
    Write-Host "  [STEP 4] -Force specified: Removing existing module installation..." -ForegroundColor DarkGray
    $removeResult = Remove-ExistingModule -TargetPath $targetPath

    if ($removeResult.code -ne 0) {
        Write-Host "  [ERROR]  Could not remove existing module: $($removeResult.msg)" -ForegroundColor DarkRed
        exit 1
    }
    Write-Host "  [OK]     Existing module removed (or did not exist)." -ForegroundColor DarkGreen
} else {
    Write-Host "  [STEP 4] -Force not specified. Existing files may be overwritten by Robocopy." -ForegroundColor DarkGray
}
Write-Host ""

# --- Step 5: Install module via Robocopy ---
Write-Host "  [STEP 5] Installing module via Robocopy..." -ForegroundColor DarkGray
$installResult = Install-ModuleWithRobocopy -SourcePath $canonicalSource `
                                            -TargetPath $targetPath `
                                            -WriteLogFile $WriteLog.IsPresent

if ($installResult.code -ne 0) {
    Write-Host "  [ERROR]  Installation failed: $($installResult.msg)" -ForegroundColor DarkRed
    exit 1
}

Write-Host "  [OK]     $($installResult.msg)" -ForegroundColor DarkGreen
Write-Host ""

# --- Step 6: Verify installation ---
Write-Host "  [STEP 6] Verifying installation..." -ForegroundColor DarkGray
if (Test-Path -Path $targetPath) {
    Write-Host "  [OK]     Module '$ModuleName' successfully installed to:" -ForegroundColor DarkGreen
    Write-Host "           $targetPath" -ForegroundColor DarkCyan
} else {
    Write-Host "  [WARNING] Target path could not be verified after installation." -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Installation complete." -ForegroundColor DarkGray
Write-Host ""