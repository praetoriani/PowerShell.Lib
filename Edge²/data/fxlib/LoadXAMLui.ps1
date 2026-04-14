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
    $result = LoadXAMLui -XamlFilePath $global:XamlFile
.NOTES
    Version: 1.00.02 | Author: Praetoriani
#>
function LoadXAMLui {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$XamlFilePath
    )

    $status = NewStatusObject -Code -1 -Msg ""

    if (-not (Test-Path -LiteralPath $XamlFilePath -PathType Leaf)) {
        $status.code = -1
        $status.msg  = "PowerEdge: XAML definition file not found: '$XamlFilePath'"
        return $status
    }

    try {
        [xml]$xamlDoc = Get-Content -LiteralPath $XamlFilePath -Raw -Encoding UTF8
    }
    catch {
        $status.code = -1
        $status.msg  = "PowerEdge: Failed to parse XAML file '$XamlFilePath': $($_.Exception.Message)"
        return $status
    }

    $status.code = 0
    $status.msg  = ""
    $status | Add-Member -NotePropertyName "XmlDoc" -NotePropertyValue $xamlDoc
    return $status
}
