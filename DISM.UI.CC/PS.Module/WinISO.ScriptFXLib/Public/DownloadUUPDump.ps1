function DownloadUUPDump {
    <#
    .SYNOPSIS
        Downloads a UUPDump package ZIP file from uupdump.net.

    .DESCRIPTION
        DownloadUUPDump queries the UUP Dump API to find the correct build based on the
        provided OS type, version, architecture and optional build number. It then
        downloads the corresponding ZIP archive (which contains the uup_download_windows.cmd
        conversion script and all required files) to the specified target path.

        This function exclusively supports Windows 11 Pro and Windows 11 Home editions.
        For all other editions (Pro for Workstations, Education, Enterprise, IoT Enterprise),
        use the GetUUPDumpPackage function instead.

        The function ensures:
        - The target directory structure is created automatically if it does not exist
        - Any pre-existing ZIP file at the target path is deleted before downloading
        - The downloaded ZIP file is verified for completeness via HTTP Content-Length comparison
        - All relevant download metadata is written to the module-scope $script:uupdump
          variable via WinISOcore upon successful completion

    .PARAMETER OStype
        Specifies the operating system name. Currently only 'Windows11' is supported.

    .PARAMETER OSvers
        Specifies the OS version. Valid values: '24H2' (default) or '25H2'.

    .PARAMETER OSarch
        Specifies the target architecture. Valid values: 'amd64' or 'arm64'.

    .PARAMETER Edition
        Specifies the Windows edition to download.
        Valid values: 'Pro' (default) or 'Home'.
        Note: For other editions use GetUUPDumpPackage instead.

    .PARAMETER BuildNo
        Optional. A specific build number in the format '00000.0000' (digits and exactly one dot).
        If omitted, the latest available retail build is selected automatically.

    .PARAMETER Target
        Full path to the target ZIP file including filename.
        The directory structure is created automatically if it does not exist.

    .PARAMETER IncludeNetFX
        Switch parameter. When specified, .NET Framework 3.5 integration is included in the
        UUP conversion package (NetFx3=1 in ConvertConfig.ini).
        Default behavior: .NET Framework 3.5 is included (enabled by default).

    .PARAMETER ExcludeNetFX
        Switch parameter. When specified, .NET Framework 3.5 integration is explicitly
        excluded from the UUP conversion package (NetFx3=0 in ConvertConfig.ini).
        Note: If neither IncludeNetFX nor ExcludeNetFX is specified, .NET FX 3.5 is
        included by default (matching the standard UUPDump behavior).

    .PARAMETER UseESD
        Switch parameter. When specified, the ISO is created with an install.esd file
        instead of install.wim (wim2esd=1 in ConvertConfig.ini).
        Default behavior: install.wim is used (UseESD not set).

    .OUTPUTS
        PSCustomObject with fields:
        .code  >>  0 = Success | -1 = Error
        .msg   >>  Description of the result or error
        .data  >>  Full path to the downloaded ZIP file on success, $null on failure

    .EXAMPLE
        $result = DownloadUUPDump -OStype 'Windows11' -OSvers '24H2' -OSarch 'amd64' `
                                  -Edition 'Pro' `
                                  -Target 'C:\WinISO\uupdump\Win11_Pro_24H2.zip'
        if ($result.code -eq 0) { Write-Host "Downloaded: $($result.data)" }

    .EXAMPLE
        $result = DownloadUUPDump -OStype 'Windows11' -OSvers '24H2' -OSarch 'amd64' `
                                  -Edition 'Home' -BuildNo '26100.3476' `
                                  -Target 'C:\WinISO\uupdump\Win11_Home_24H2_26100.3476.zip'

    .EXAMPLE
        # Download Windows 11 Pro 24H2 with .NET FX 3.5 included and WIM format (default settings)
        $result = DownloadUUPDump -OStype 'Windows11' -OSvers '24H2' -OSarch 'amd64' `
                                  -Edition 'Pro' -IncludeNetFX `
                                  -Target 'C:\WinISO\uupdump\Win11_Pro_24H2.zip'

    .EXAMPLE
        # Download Windows 11 Pro 25H2, no .NET FX 3.5, with ESD format
        $result = DownloadUUPDump -OStype 'Windows11' -OSvers '25H2' -OSarch 'amd64' `
                                  -Edition 'Pro' -ExcludeNetFX -UseESD `
                                  -Target 'C:\WinISO\uupdump\Win11_Pro_25H2_ESD.zip'

    .NOTES
        Version:      1.00.05
        Dependencies:
        - Private function OPSreturn must be available (loaded via module)
        - WinISOcore must be available for $script:uupdump write-back
        - Requires internet access to api.uupdump.net and uupdump.net
        - Requires PowerShell 5.1 or higher
        - Requires .NET 4.7.2+ (System.Web.HttpUtility)
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "OS type. Currently only 'Windows11' is supported.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Windows11')]
        [string]$OStype,

        [Parameter(Mandatory = $true, HelpMessage = "OS version. Valid values: '24H2' or '25H2'.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('24H2', '25H2')]
        [string]$OSvers,

        [Parameter(Mandatory = $true, HelpMessage = "Target architecture. Valid values: 'amd64' or 'arm64'.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('amd64', 'arm64')]
        [string]$OSarch,

        [Parameter(Mandatory = $false, HelpMessage = "Windows edition: 'Pro' (default) or 'Home'. For other editions use GetUUPDumpPackage.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Pro', 'Home')]
        [string]$Edition = 'Pro',

        [Parameter(Mandatory = $false, HelpMessage = "Optional build number in format '00000.0000'.")]
        [AllowEmptyString()]
        [string]$BuildNo = '',

        [Parameter(Mandatory = $true, HelpMessage = "Full path to the target ZIP file including filename.")]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter(Mandatory = $false, HelpMessage = "Include .NET Framework 3.5 in the conversion package (default behavior).")]
        [switch]$IncludeNetFX,

        [Parameter(Mandatory = $false, HelpMessage = "Explicitly exclude .NET Framework 3.5 from the conversion package.")]
        [switch]$ExcludeNetFX,

        [Parameter(Mandatory = $false, HelpMessage = "Create ISO with install.esd instead of install.wim.")]
        [switch]$UseESD
    )

    # Retrieve module-scope variables via WinISOcore
    $appinfo = WinISOcore -Scope 'env' -GlobalVar 'appinfo' -Permission 'read' -Unwrap
    $appenv  = WinISOcore -Scope 'env' -GlobalVar 'appenv'  -Permission 'read' -Unwrap
    $appcore = WinISOcore -Scope 'env' -GlobalVar 'appcore' -Permission 'read' -Unwrap
    $uupdump = WinISOcore -Scope 'env' -GlobalVar 'uupdump' -Permission 'read' -Unwrap

    # Internal API and base URL constants for UUP Dump
    $UUP_API_URL  = 'https://api.uupdump.net'
    $UUP_BASE_URL = 'https://uupdump.net'

    # ----------------------------------------------------------------
    # STEP 1 >> Validate conflicting switch parameters
    # ----------------------------------------------------------------
    if ($IncludeNetFX.IsPresent -and $ExcludeNetFX.IsPresent) {
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Parameters 'IncludeNetFX' and 'ExcludeNetFX' are mutually exclusive. Specify only one or neither.")
    }

    # Resolve NetFX setting:
    # - IncludeNetFX set explicitly -> '1'
    # - ExcludeNetFX set explicitly -> '0'
    # - Neither set (default)       -> '1'  (matches standard UUPDump behavior)
    $NetFXValue = '1'
    if ($ExcludeNetFX.IsPresent) {
        $NetFXValue = '0'
    }

    # Resolve ESD setting
    $ESDValue = if ($UseESD.IsPresent) { '1' } else { '0' }

    # ----------------------------------------------------------------
    # STEP 2 >> Map Edition parameter to UUPDump internal edition identifier
    # ----------------------------------------------------------------
    # Maps user-friendly edition name to UUPDump internal edition ID (used in GET URL)
    # and to the human-readable display name (stored in $script:uupdump)
    switch ($Edition) {
        'Pro'  {
            $UUPEditionID    = 'professional'
            $EditionDisplay  = 'Professional'
        }
        'Home' {
            $UUPEditionID    = 'core'
            $EditionDisplay  = 'Home'
        }
    }

    # ----------------------------------------------------------------
    # STEP 3 >> Validate optional BuildNo parameter format (if provided)
    # ----------------------------------------------------------------
    if (-not [string]::IsNullOrWhiteSpace($BuildNo)) {
        # BuildNo must match format: digits DOT digits  (e.g. 26100.3476)
        if ($BuildNo -notmatch '^\d{5}\.\d{4}$') {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Parameter 'BuildNo' must be in format '00000.0000' (e.g. '26100.3476'). Provided value: '$BuildNo'")
        }
    }

    # ----------------------------------------------------------------
    # STEP 4 >> Validate and prepare the target path / directory
    # ----------------------------------------------------------------
    try {
        # Ensure the target path has a .zip extension
        if ([System.IO.Path]::GetExtension($Target).ToLower() -ne '.zip') {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Parameter 'Target' must point to a .zip file. Provided: '$Target'")
        }

        $TargetDir = [System.IO.Path]::GetDirectoryName($Target)

        if ([string]::IsNullOrWhiteSpace($TargetDir)) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Could not determine target directory from path: '$Target'")
        }

        # Create directory structure if it does not exist yet
        if (-not (Test-Path -Path $TargetDir -PathType Container)) {
            $null = New-Item -Path $TargetDir -ItemType Directory -Force -ErrorAction Stop
        }

        # Delete pre-existing ZIP at target path to guarantee a fresh download
        if (Test-Path -Path $Target -PathType Leaf) {
            Remove-Item -Path $Target -Force -ErrorAction Stop
        }
    }
    catch {
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Error preparing target path '$Target': $($_.Exception.Message)")
    }

    # ----------------------------------------------------------------
    # STEP 5 >> Build the UUP Dump API search query
    # ----------------------------------------------------------------
    $BuildUUID    = $null
    $BuildNumber  = $null

    try {
        # Compose search term: e.g. "Windows 11 24H2 amd64"
        $SearchTerm = "Windows 11 $OSvers $OSarch"

        $ApiSearchUrl = "$UUP_API_URL/listid.php"
        $SearchBody   = @{ search = $SearchTerm }

        $ApiResponse = Invoke-RestMethod -Uri $ApiSearchUrl -Method Get -Body $SearchBody -ErrorAction Stop

        if ($ApiResponse.response.error) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! UUP Dump API returned error: $($ApiResponse.response.error)")
        }

        if (-not $ApiResponse.response.builds) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! UUP Dump API returned no builds for search term: '$SearchTerm'")
        }

        # Filter builds: retail only (exclude Preview / Insider builds)
        $Builds = $ApiResponse.response.builds.PSObject.Properties | Where-Object {
            $_.Value.title   -like "*Windows 11*"    -and
            $_.Value.title   -like "*$OSvers*"       -and
            $_.Value.arch    -eq $OSarch             -and
            $_.Value.title   -notlike "*preview*"    -and
            $_.Value.title   -notlike "*Insider*"
        } | Sort-Object { $_.Value.created } -Descending

        if ($Builds.Count -eq 0) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! No matching retail builds found for: OS='$OStype' Version='$OSvers' Arch='$OSarch'")
        }

        # If a specific BuildNo was requested, try to find it; otherwise use the latest
        if (-not [string]::IsNullOrWhiteSpace($BuildNo)) {
            $MatchingBuild = $Builds | Where-Object { $_.Value.build -eq $BuildNo } | Select-Object -First 1

            if (-not $MatchingBuild) {
                return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Build number '$BuildNo' was not found for: OS='$OStype' Version='$OSvers' Arch='$OSarch'")
            }

            $BuildUUID   = $MatchingBuild.Value.uuid
            $BuildTitle  = $MatchingBuild.Value.title
            $BuildNumber = $MatchingBuild.Value.build
        }
        else {
            # Use the most recent retail build
            $BuildUUID   = $Builds[0].Value.uuid
            $BuildTitle  = $Builds[0].Value.title
            $BuildNumber = $Builds[0].Value.build
        }
    }
    catch {
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Error querying UUP Dump API: $($_.Exception.Message)")
    }

    # ----------------------------------------------------------------
    # STEP 6 >> Build the UUP Dump download URL and POST body
    # ----------------------------------------------------------------
    try {
        # Ensure HttpUtility is available for URL encoding
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

        $DownloadParams = @{
            id      = $BuildUUID
            pack    = 'de-de'
            edition = $UUPEditionID
        }

        # Build query string with URL-encoded values
        $QueryString = ($DownloadParams.GetEnumerator() | ForEach-Object {
            "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))"
        }) -join '&'

        $DownloadUrl = "$UUP_BASE_URL/get.php?$QueryString"

        # POST body tells UUP Dump which conversion options to include in the package
        # autodl=2: Download and convert to ISO (standard single-edition mode)
        $PostBody = @{
            autodl  = '2'           # Download and convert to ISO
            updates = '0'           # Do not integrate cumulative updates
            cleanup = '0'           # Do not run cleanup after conversion
            netfx   = $NetFXValue   # .NET Framework 3.5 integration (parameterized)
            esd     = $ESDValue     # ESD vs WIM format (parameterized)
        }
    }
    catch {
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Error building download URL for build '$BuildTitle' (UUID: $BuildUUID): $($_.Exception.Message)")
    }

    # ----------------------------------------------------------------
    # STEP 7 >> Perform the HTTP POST download with completeness verification
    # ----------------------------------------------------------------
    try {
        # Use Invoke-WebRequest to capture both the file and the response headers
        $WebResponse = Invoke-WebRequest -Uri $DownloadUrl -Method Post -Body $PostBody `
                                         -OutFile $Target -UseBasicParsing -PassThru -ErrorAction Stop

        # Verify that the file was actually written to disk
        if (-not (Test-Path -Path $Target -PathType Leaf)) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Download completed but ZIP file was not found at: '$Target'")
        }

        $WrittenSize = (Get-Item -Path $Target).Length

        # Cross-check file size against Content-Length header if it was provided by the server
        $ContentLength = 0
        if ($WebResponse.Headers['Content-Length']) {
            [long]::TryParse($WebResponse.Headers['Content-Length'], [ref]$ContentLength) | Out-Null
        }

        if ($ContentLength -gt 0 -and $WrittenSize -ne $ContentLength) {
            # Size mismatch - remove the incomplete file and report failure
            Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! ZIP file appears incomplete. Expected=$ContentLength bytes / Written=$WrittenSize bytes. Incomplete file was removed.")
        }

        if ($WrittenSize -eq 0) {
            Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Downloaded ZIP file has 0 bytes. Incomplete file was removed.")
        }
    }
    catch {
        # Clean up any partial file that may have been written before the error
        if (Test-Path -Path $Target -PathType Leaf) {
            Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
        }
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Error during download of build '$BuildTitle' (UUID: $BuildUUID): $($_.Exception.Message)")
    }

    # -------------------------------------------------------------------------
    # SUCCESS >> ZIP file downloaded and verified
    # -------------------------------------------------------------------------
    $FinalSizeKB = [math]::Round($WrittenSize / 1KB, 2)
    $ZipFileName = [System.IO.Path]::GetFileName($Target)

    # ----------------------------------------------------------------
    # STEP 8 >> Write all relevant download metadata to module-scope $script:uupdump
    #           All keys MUST be written successfully for the function to report success.
    # ----------------------------------------------------------------
    $WriteOps = @(
        @{ VarKeyID = 'ostype';   SetNewVal = $OStype        },
        @{ VarKeyID = 'osvers';   SetNewVal = $OSvers        },
        @{ VarKeyID = 'osarch';   SetNewVal = $OSarch        },
        @{ VarKeyID = 'edition';  SetNewVal = $EditionDisplay },
        @{ VarKeyID = 'buildno';  SetNewVal = $BuildNumber   },
        @{ VarKeyID = 'kbsize';   SetNewVal = $FinalSizeKB   },
        @{ VarKeyID = 'zipname';  SetNewVal = $ZipFileName   }
    )

    foreach ($Op in $WriteOps) {
        $WriteResult = WinISOcore -Scope 'env' -GlobalVar 'uupdump' -Permission 'write' `
                                  -VarKeyID $Op.VarKeyID -SetNewVal $Op.SetNewVal
        if ($WriteResult.code -ne 0) {
            return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Download succeeded but could not write '$($Op.VarKeyID)' to `$script:uupdump. Reason: $($WriteResult.msg)")
        }
    }

    # Also clear multiedition field to prevent stale data from a previous GetUUPDumpPackage call
    $ClearMulti = WinISOcore -Scope 'env' -GlobalVar 'uupdump' -Permission 'write' `
                              -VarKeyID 'multiedition' -SetNewVal ''
    if ($ClearMulti.code -ne 0) {
        return (OPSreturn -Code -1 -Message "Function DownloadUUPDump failed! Download succeeded but could not clear 'multiedition' in `$script:uupdump. Reason: $($ClearMulti.msg)")
    }

    return (OPSreturn -Code 0 -Message "DownloadUUPDump successfully finished! Edition: '$EditionDisplay' | Build: '$BuildTitle' | BuildNo: $BuildNumber | UUID: $BuildUUID | NetFX: $NetFXValue | ESD: $ESDValue | File: '$Target' ($FinalSizeKB KB)" -Data $Target)
}
