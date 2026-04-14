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
    $result = NewStatusObject -Code 0 -Msg ""
.NOTES
    Version: 1.00.02 | Author: Praetoriani
#>
function NewStatusObject {
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
