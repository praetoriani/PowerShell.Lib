<#
.SYNOPSIS
    Creates a new PowerShell module scaffold including directory structure,
    a module manifest (.psd1) and a root module file (.psm1).

.DESCRIPTION
    New-PSModule.ps1 automates the initial setup of a new PowerShell module.
    It accepts parameters via the command line or, if mandatory parameters are
    missing or invalid, prompts the user interactively until valid input is
    provided.

    The script performs the following steps:
      1. Validates all input parameters (name, version format, author, target).
      2. Creates the module directory inside the specified target folder.
      3. Generates a stub root module file  (<ModuleName>.psm1).
      4. Creates a module manifest          (<ModuleName>.psd1).
      5. Reports success or error details to the console.

.PARAMETER ModuleName
    The name for the new PowerShell module. Must start with a letter and may
    contain letters, digits, hyphens, or underscores. A dot (.) may be used
    as a namespace separator (e.g. "MyCompany.MyModule"). Required.

.PARAMETER ModuleVers
    The version string for the module.
    Accepted formats:  A.BB.CC  (e.g. 1.00.00)  or  A.B.C  (e.g. 1.0.0)
    Each segment must be a number between 0 and 99.
    Defaults to "1.00.00" when omitted.

.PARAMETER AuthorName
    The full name of the module author. Required.

.PARAMETER Target
    Path to an existing directory in which the module folder will be created.
    Required.

.EXAMPLE
    .\New-PSModule.ps1 -ModuleName "Contoso.Utilities" -ModuleVers "1.00.00" `
                       -AuthorName "Jane Doe" -Target "C:\Projects\Modules"

.EXAMPLE
    .\New-PSModule.ps1
    Runs in fully interactive mode.

.NOTES
    Author   : M
    Version  : 1.2.0
    Requires : PowerShell 5.1 or later
#>

[CmdletBinding()]
param (
    # Module name - validated later; allow empty string so interactive mode works.
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$ModuleName = "",

    # Module version - defaults to 1.00.00.
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$ModuleVers = "1.00.00",

    # Author name - validated later.
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$AuthorName = "",

    # Target directory - validated later.
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$Target = ""
)

# ==============================================================================
#  REGION: Constants
# ==============================================================================

# Module name: one or more dot-separated segments, each starting with a letter
# followed by letters, digits, hyphens or underscores.
Set-Variable -Name 'RX_MODULE_NAME' `
    -Value '^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z][A-Za-z0-9_-]*)*$' `
    -Option Constant

# Version: A.B.C or A.BB.CC where every part is 0-99.
Set-Variable -Name 'RX_VERSION' `
    -Value '^[0-9]\.[0-9]{1,2}\.[0-9]{1,2}$' `
    -Option Constant

# ==============================================================================
#  REGION: Validation Functions
#  All functions accept ANY string (including empty) and return $true / $false.
#  They never throw - invalid input is reported via Write-Warning.
# ==============================================================================

function Test-ModuleName {
    param ([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Warning "Module name must not be empty."
        return $false
    }
    if ($Value -notmatch $RX_MODULE_NAME) {
        Write-Warning (
            "Invalid module name: '$Value'. " +
            "Each segment must start with a letter and may contain " +
            "letters, digits, hyphens or underscores. " +
            "Segments are separated by a dot (e.g. 'MyCompany.MyModule')."
        )
        return $false
    }
    return $true
}

function Test-ModuleVersion {
    param ([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Warning "Version must not be empty."
        return $false
    }
    if ($Value -notmatch $RX_VERSION) {
        Write-Warning (
            "Invalid version: '$Value'. " +
            "Use format A.BB.CC (e.g. 1.00.00) or A.B.C (e.g. 1.0.0). " +
            "Each part must be a number from 0 to 99."
        )
        return $false
    }
    return $true
}

function Test-AuthorName {
    param ([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Warning "Author name must not be empty."
        return $false
    }
    return $true
}

function Test-TargetPath {
    param ([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Warning "Target path must not be empty."
        return $false
    }
    if (-not (Test-Path -LiteralPath $Value -PathType Container)) {
        Write-Warning "Target directory '$Value' does not exist. Please create it first."
        return $false
    }
    return $true
}

# ==============================================================================
#  REGION: Interactive Input Helper
# ==============================================================================

function Read-ValidInput {
    <#
    .SYNOPSIS
        Prompts the user repeatedly until the supplied validation function
        returns $true, then returns the accepted value.
    .PARAMETER Prompt
        Text shown at the input cursor.
    .PARAMETER ValidateFn
        Name of a validation function (string). The function must accept a
        single [string] parameter and return [bool].
    .PARAMETER Default
        Value pre-filled when the user presses Enter without typing anything.
    #>
    param (
        [string]$Prompt,
        [string]$ValidateFn,
        [string]$Default = ""
    )

    while ($true) {
        $display = if ($Default -ne "") { "$Prompt [default: $Default]" } else { $Prompt }
        $raw     = (Read-Host -Prompt $display).Trim()

        # Use the default when the user submitted an empty line
        if ($raw -eq "" -and $Default -ne "") {
            $raw = $Default
        }

        # Call the named validation function dynamically
        $ok = & $ValidateFn $raw
        if ($ok) { return $raw }
        # Validation printed a warning - loop and ask again
    }
}

# ==============================================================================
#  REGION: Wait-ForEnter  (called at every exit point)
# ==============================================================================

function Wait-ForEnter {
    Write-Host ""
    Write-Host "Please press <Enter> to exit ..." -ForegroundColor DarkGray
    $null = Read-Host
}

# ==============================================================================
#  REGION: Banner
# ==============================================================================

Write-Host ""
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host "|   New-PSModule  -  Module Scaffold Creator   |" -ForegroundColor Cyan
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host ""

# ==============================================================================
#  REGION: Collect & Validate Parameters
#  Each block:
#    1. Runs the relevant Test-* function against the current variable value.
#    2. If the test fails (empty OR invalid), enters interactive mode and loops
#       until a valid value is entered.
# ==============================================================================

# -- ModuleName ----------------------------------------------------------------
if (-not (Test-ModuleName $ModuleName)) {
    $ModuleName = Read-ValidInput `
        -Prompt     "  Module name (e.g. MyCompany.MyModule)" `
        -ValidateFn "Test-ModuleName"
}

# -- ModuleVers ----------------------------------------------------------------
if (-not (Test-ModuleVersion $ModuleVers)) {
    $ModuleVers = Read-ValidInput `
        -Prompt     "  Module version (e.g. 1.00.00)" `
        -ValidateFn "Test-ModuleVersion" `
        -Default    "1.00.00"
}

# -- AuthorName ----------------------------------------------------------------
if (-not (Test-AuthorName $AuthorName)) {
    $AuthorName = Read-ValidInput `
        -Prompt     "  Author name" `
        -ValidateFn "Test-AuthorName"
}

# -- Target --------------------------------------------------------------------
if (-not (Test-TargetPath $Target)) {
    $Target = Read-ValidInput `
        -Prompt     "  Target directory (must exist)" `
        -ValidateFn "Test-TargetPath"
}

# ==============================================================================
#  REGION: Derive Paths  (only reached when all variables are valid)
# ==============================================================================

$moduleDirectory = Join-Path -Path $Target          -ChildPath $ModuleName
$manifestPath    = Join-Path -Path $moduleDirectory -ChildPath ($ModuleName + ".psd1")
$rootModulePath  = Join-Path -Path $moduleDirectory -ChildPath ($ModuleName + ".psm1")

# ==============================================================================
#  REGION: Summary & Confirmation
# ==============================================================================

Write-Host ""
Write-Host "  ----------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Summary of module to be created:" -ForegroundColor White
Write-Host ""
Write-Host "  Name    : " -NoNewline; Write-Host $ModuleName      -ForegroundColor Yellow
Write-Host "  Version : " -NoNewline; Write-Host $ModuleVers      -ForegroundColor Yellow
Write-Host "  Author  : " -NoNewline; Write-Host $AuthorName      -ForegroundColor Yellow
Write-Host "  Path    : " -NoNewline; Write-Host $moduleDirectory  -ForegroundColor Yellow
Write-Host ""
Write-Host "  ----------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$confirm = (Read-Host "  Proceed? [Y/n]").Trim().ToLower()
if ($confirm -eq "n") {
    Write-Host ""
    Write-Host "  Operation cancelled by user." -ForegroundColor DarkYellow
    Wait-ForEnter
    exit 0
}

# ==============================================================================
#  REGION: Module Scaffold Creation
# ==============================================================================

try {

    # --------------------------------------------------------------------------
    #  Step 1 - Create module directory
    # --------------------------------------------------------------------------
    Write-Host ""
    Write-Host "  [1/3] Creating module directory ..." -ForegroundColor Cyan

    New-Item -ItemType Directory -Path $moduleDirectory -Force | Out-Null

    Write-Host ("          " + $moduleDirectory) -ForegroundColor DarkGray
    Write-Host "          OK" -ForegroundColor Green

    # --------------------------------------------------------------------------
    #  Step 2 - Create root module stub (.psm1)
    # --------------------------------------------------------------------------
    Write-Host ("  [2/3] Creating root module file (" + $ModuleName + ".psm1) ...") -ForegroundColor Cyan

    # Build content line by line to avoid here-string / special-char issues.
    $psm1 = "# " + $ModuleName + ".psm1"                                    + "`r`n"
    $psm1 += "# Root module file - add your functions and exports here."     + "`r`n"
    $psm1 += "#"                                                              + "`r`n"
    $psm1 += "# Example:"                                                    + "`r`n"
    $psm1 += "#   . " + '$PSScriptRoot' + "\Public\Get-Example.ps1"          + "`r`n"
    $psm1 += "#   Export-ModuleMember -Function 'Get-Example'"               + "`r`n"
    $psm1 += ""                                                               + "`r`n"
    $psm1 += "# --------------- Add your module logic below ---------------"  + "`r`n"
    $psm1 += ""                                                               + "`r`n"

    if (-not (Test-Path -LiteralPath $rootModulePath)) {
        Set-Content -LiteralPath $rootModulePath -Value $psm1 -Encoding UTF8
        Write-Host ("          " + $rootModulePath) -ForegroundColor DarkGray
        Write-Host "          OK" -ForegroundColor Green
    }
    else {
        Write-Host ("          SKIPPED - already exists: " + $rootModulePath) -ForegroundColor DarkYellow
    }

    # --------------------------------------------------------------------------
    #  Step 3 - Create module manifest (.psd1)
    # --------------------------------------------------------------------------
    Write-Host ("  [3/3] Creating module manifest (" + $ModuleName + ".psd1) ...") -ForegroundColor Cyan

    New-ModuleManifest `
        -Path          $manifestPath `
        -ModuleVersion $ModuleVers `
        -Author        $AuthorName `
        -Guid          ([guid]::NewGuid()) `
        -RootModule    ($ModuleName + ".psm1")

    Write-Host ("          " + $manifestPath) -ForegroundColor DarkGray
    Write-Host "          OK" -ForegroundColor Green

    # --------------------------------------------------------------------------
    #  Success
    # --------------------------------------------------------------------------
    Write-Host ""
    Write-Host "  ----------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Module scaffold created successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Files created:" -ForegroundColor White
    Write-Host ("    " + $rootModulePath) -ForegroundColor DarkGray
    Write-Host ("    " + $manifestPath)   -ForegroundColor DarkGray
    Write-Host "  ----------------------------------------------" -ForegroundColor DarkGray

}
catch {
    Write-Host ""
    Write-Host "  ==============================================" -ForegroundColor Red
    Write-Host "  ERROR: Module creation failed." -ForegroundColor Red
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "  ==============================================" -ForegroundColor Red
}
finally {
    Wait-ForEnter
}