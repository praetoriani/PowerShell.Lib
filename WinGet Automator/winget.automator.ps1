<#
.SYNOPSIS
    WinGet Automator - Automated Application Update Tool
.DESCRIPTION
    This PowerShell application automatically updates predefined programs using WinGet 
    based on configuration stored in JSON files. It supports multi-language interfaces
    and detailed logging capabilities. The application reads configuration from JSON files,
    loads language packs for localized messages, and processes application updates through
    the Windows Package Manager (WinGet) with comprehensive error handling and logging.
.USAGE EXAMPLE
    .\winget.automator.ps1
    The script runs without parameters and uses configuration from data\config\app-config.json
.NOTES
    Creation Date:  06.10.2025
    Last Update:    06.10.2025
    Version:        1.00.01
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
#>

# Global application variables
$global:AppName = "WinGet Automator"
$global:AppVers = "1.00.01"
$global:AppPath = $PSScriptRoot
$global:AppIcon = Join-Path $AppPath "appicon.ico"

# Global configuration variables
$global:Language = ""
$global:UpdateFile = ""
$global:CreateDebugLog = 1
$global:CreateUpdateLog = 1
$global:LanguageStrings = @{}

function Write-LogEntry {
    <#
    .SYNOPSIS
        Writes structured log entries with timestamp and severity levels to the main log file
    .DESCRIPTION
        This function creates formatted log entries with timestamps in the format [YYYY.MM.DD ; HH:MM:SS]
        and severity flags [INFO], [DEBUG], [WARN], [ERROR]. The function ensures proper alignment
        of log entries and writes to the main log file only when debug logging is enabled.
    .PARAMETER Message
        The log message text to be written
    .PARAMETER Severity
        The severity level of the log entry. Valid values: INFO, DEBUG, WARN, ERROR
    .OUTPUTS
        None. Writes directly to log file.
    .USAGE EXAMPLE
        Write-LogEntry "Application started successfully" "INFO"
        Write-LogEntry "Configuration file not found" "ERROR"
    .NOTES
        The function automatically handles UTF8 encoding and appends to existing log files.
        Severity flags are formatted with proper spacing for visual alignment in log files.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "DEBUG", "WARN", "ERROR")]
        [string]$Severity = "INFO"
    )
    
    # Create timestamp in format [YYYY.MM.DD ; HH:MM:SS]
    $timestamp = Get-Date -Format "[yyyy.MM.dd ; HH:mm:ss]"
    
    # Format severity flag with proper spacing for alignment
    switch ($Severity) {
        "INFO"  { $severityFlag = "[INFO] " }
        "DEBUG" { $severityFlag = "[DEBUG]" }
        "WARN"  { $severityFlag = "[WARN] " }
        "ERROR" { $severityFlag = "[ERROR]" }
    }
    
    # Create log entry
    $logEntry = "$timestamp $severityFlag $Message"
    
    # Write to main log file if debug logging is enabled
    if ($global:CreateDebugLog -eq 1) {
        $logFile = Join-Path $global:AppPath "winget.automator.log"
        $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
}

function New-UpdateLogFile {
    <#
    .SYNOPSIS
        Creates a new update log file with timestamp-based filename
    .DESCRIPTION
        This function generates a unique log file name using the current date and time
        in the format YYYYMMDD-HHMMSS.log and creates the necessary directory structure
        under data\logs if it doesn't exist.
    .OUTPUTS
        String. Returns the full path to the created log file.
    .USAGE EXAMPLE
        $logFile = New-UpdateLogFile
        Write-Output "Log file created at: $logFile"
    .NOTES
        The function automatically creates the logs directory structure if missing.
        Each execution creates a unique filename to prevent conflicts.
    #>
    
    # Generate timestamp for unique filename
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFileName = "$timestamp.log"
    $logPath = Join-Path $global:AppPath "data\logs"
    
    # Create logs directory if it doesn't exist
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    return Join-Path $logPath $logFileName
}

function Load-Configuration {
    <#
    .SYNOPSIS
        Loads and validates the main configuration from app-config.json
    .DESCRIPTION
        This function reads the main configuration file, validates all parameters,
        and sets global variables with appropriate fallback values. It handles
        missing parameters gracefully and ensures all configuration values are valid.
    .OUTPUTS
        Boolean. Returns $true if configuration loaded successfully, $false otherwise.
    .USAGE EXAMPLE
        if (Load-Configuration) {
            Write-Output "Configuration loaded successfully"
        } else {
            Write-Output "Failed to load configuration"
        }
    .NOTES
        The function validates create-debug-log and create-update-log parameters to ensure
        they are either 0 or 1. Invalid values are replaced with defaults and logged as warnings.
    #>
    
    Write-LogEntry "Starting configuration loading process" "INFO"
    
    # Define path to configuration file
    $configPath = Join-Path $global:AppPath "data\config\app-config.json"
    
    # Check if configuration file exists
    if (-not (Test-Path $configPath)) {
        Write-LogEntry "Configuration file not found at: $configPath" "ERROR"
        return $false
    }
    
    try {
        # Load and parse JSON configuration
        $configContent = Get-Content -Path $configPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        
        # Set language (default to en-us.json if not specified or invalid)
        if ($config.PSObject.Properties['language'] -and $config.language) {
            $global:Language = $config.language
        } else {
            $global:Language = "en-us.json"
            Write-LogEntry "Language parameter missing or invalid, using default: en-us.json" "WARN"
        }
        
        # Set update file (default to app-updates.json if not specified)
        if ($config.PSObject.Properties['update-file'] -and $config.'update-file') {
            $global:UpdateFile = $config.'update-file'
        } else {
            $global:UpdateFile = "app-updates.json"
            Write-LogEntry "Update-file parameter missing, using default: app-updates.json" "WARN"
        }
        
        # Set create-debug-log (validate 0 or 1, default to 1)
        if ($config.PSObject.Properties['create-debug-log'] -and ($config.'create-debug-log' -eq 0 -or $config.'create-debug-log' -eq 1)) {
            $global:CreateDebugLog = $config.'create-debug-log'
        } else {
            $global:CreateDebugLog = 1
            Write-LogEntry "Create-debug-log parameter missing or invalid, using default: 1" "WARN"
        }
        
        # Set create-update-log (validate 0 or 1, default to 1)
        if ($config.PSObject.Properties['create-update-log'] -and ($config.'create-update-log' -eq 0 -or $config.'create-update-log' -eq 1)) {
            $global:CreateUpdateLog = $config.'create-update-log'
        } else {
            $global:CreateUpdateLog = 1
            Write-LogEntry "Create-update-log parameter missing or invalid, using default: 1" "WARN"
        }
        
        Write-LogEntry "Configuration loaded successfully" "INFO"
        Write-LogEntry "Language: $global:Language" "DEBUG"
        Write-LogEntry "Update File: $global:UpdateFile" "DEBUG"
        Write-LogEntry "Create Debug Log: $global:CreateDebugLog" "DEBUG"
        Write-LogEntry "Create Update Log: $global:CreateUpdateLog" "DEBUG"
        
        return $true
    }
    catch {
        Write-LogEntry "Failed to load configuration: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Load-LanguageFile {
    <#
    .SYNOPSIS
        Loads language strings from JSON language pack files
    .DESCRIPTION
        This function attempts to load the specified language file and falls back
        to en-us.json if the primary language file is not available. It populates
        the global LanguageStrings hashtable for use throughout the application.
    .OUTPUTS
        Boolean. Returns $true if language file loaded successfully, $false otherwise.
    .USAGE EXAMPLE
        if (Load-LanguageFile) {
            Write-Output $global:LanguageStrings.app_starting
        }
    .NOTES
        The function implements automatic fallback to English if the specified
        language file cannot be found or loaded. This ensures the application
        can continue running with at least basic language support.
    #>
    
    Write-LogEntry "Starting language file loading process" "INFO"
    
    # Define path to language file
    $langPath = Join-Path $global:AppPath "data\lang\$global:Language"
    
    # Check if language file exists
    if (-not (Test-Path $langPath)) {
        Write-LogEntry "Language file not found at: $langPath, trying fallback" "WARN"
        
        # Try fallback to en-us.json
        $fallbackPath = Join-Path $global:AppPath "data\lang\en-us.json"
        if (-not (Test-Path $fallbackPath)) {
            Write-LogEntry "Fallback language file not found at: $fallbackPath" "ERROR"
            return $false
        }
        $langPath = $fallbackPath
        $global:Language = "en-us.json"
    }
    
    try {
        # Load and parse JSON language file
        $langContent = Get-Content -Path $langPath -Raw -Encoding UTF8
        $global:LanguageStrings = $langContent | ConvertFrom-Json
        
        Write-LogEntry "Language file loaded successfully: $global:Language" "INFO"
        return $true
    }
    catch {
        Write-LogEntry "Failed to load language file: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Load-UpdateFile {
    <#
    .SYNOPSIS
        Loads the application update list from JSON configuration file
    .DESCRIPTION
        This function reads the update file containing the list of applications
        to be updated. It supports fallback to app-updates.json if the specified
        file is not available and validates the JSON structure.
    .OUTPUTS
        PSCustomObject. Returns the parsed JSON object containing application list, or $null on failure.
    .USAGE EXAMPLE
        $appList = Load-UpdateFile
        if ($appList) {
            foreach ($app in $appList.PSObject.Properties) {
                Write-Output "App: $($app.Value)"
            }
        }
    .NOTES
        The function implements fallback functionality and comprehensive error handling
        to ensure robustness when dealing with missing or corrupted update files.
    #>
    
    Write-LogEntry $global:LanguageStrings.updatefile_loading "INFO"
    
    # Define path to update file
    $updatePath = Join-Path $global:AppPath "data\config\$global:UpdateFile"
    
    # Check if update file exists
    if (-not (Test-Path $updatePath)) {
        Write-LogEntry "Update file not found at: $updatePath, trying fallback" "WARN"
        
        # Try fallback to app-updates.json
        $fallbackPath = Join-Path $global:AppPath "data\config\app-updates.json"
        if (-not (Test-Path $fallbackPath)) {
            Write-LogEntry "Fallback update file not found at: $fallbackPath" "ERROR"
            return $null
        }
        $updatePath = $fallbackPath
    }
    
    try {
        # Load and parse JSON update file
        $updateContent = Get-Content -Path $updatePath -Raw -Encoding UTF8
        $updateData = $updateContent | ConvertFrom-Json
        
        Write-LogEntry $global:LanguageStrings.updatefile_loaded "INFO"
        return $updateData
    }
    catch {
        Write-LogEntry "Failed to load update file: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Test-WinGetAvailability {
    <#
    .SYNOPSIS
        Verifies that WinGet is available and functional on the system
    .DESCRIPTION
        This function checks if the Windows Package Manager (WinGet) is installed
        and accessible by attempting to execute the winget --version command.
        It validates both command availability and successful execution.
    .OUTPUTS
        Boolean. Returns $true if WinGet is available and functional, $false otherwise.
    .USAGE EXAMPLE
        if (Test-WinGetAvailability) {
            Write-Output "WinGet is ready for use"
        } else {
            Write-Output "WinGet is not available"
        }
    .NOTES
        The function captures and logs the WinGet version information when available
        and provides detailed error information when WinGet is not accessible.
    #>
    
    Write-LogEntry $global:LanguageStrings.winget_checking "INFO"
    
    try {
        # Try to run winget command to check availability
        $wingetVersion = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-LogEntry "$($global:LanguageStrings.winget_available), version: $wingetVersion" "INFO"
            return $true
        } else {
            Write-LogEntry "WinGet command failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-LogEntry "$($global:LanguageStrings.winget_not_available): $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Update-Applications {
    <#
    .SYNOPSIS
        Processes and updates all applications from the configuration list using WinGet
    .DESCRIPTION
        This function iterates through the application list and executes WinGet install
        commands with the required parameters (--silent, --accept-package-agreements,
        --accept-source-agreements). It creates detailed update logs when enabled and
        handles errors gracefully to ensure all applications are processed.
    .PARAMETER AppList
        PSCustomObject containing the application list loaded from JSON configuration
    .OUTPUTS
        None. Processes applications and writes to log files.
    .USAGE EXAMPLE
        $appList = Load-UpdateFile
        Update-Applications -AppList $appList
    .NOTES
        The function continues processing even if individual applications fail to install.
        All WinGet output and errors are captured and logged to separate update log files
        when update logging is enabled in the configuration.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$AppList
    )
    
    Write-LogEntry $global:LanguageStrings.update_starting "INFO"
    
    # Create update log file if logging is enabled
    $updateLogFile = $null
    if ($global:CreateUpdateLog -eq 1) {
        $updateLogFile = New-UpdateLogFile
        Write-LogEntry "$($global:LanguageStrings.logfile_created): $updateLogFile" "INFO"
    }
    
    # Process each application in the list
    foreach ($property in $AppList.PSObject.Properties) {
        $appId = $property.Value
        $itemNumber = $property.Name
        
        Write-LogEntry "$($global:LanguageStrings.processing_app): $appId (Item: $itemNumber)" "INFO"
        
        try {
            # Build winget install command with required parameters
            $wingetArgs = @(
                "install"
                $appId
                "--silent"
                "--accept-package-agreements"
                "--accept-source-agreements"
            )
            
            # Log to update file if enabled
            if ($global:CreateUpdateLog -eq 1 -and $updateLogFile) {
                $timestamp = Get-Date -Format "[yyyy.MM.dd ; HH:mm:ss]"
                "$timestamp [INFO]  Starting installation of: $appId" | Out-File -FilePath $updateLogFile -Append -Encoding UTF8
            }
            
            # Execute winget command
            $result = & winget @wingetArgs 2>&1
            
            # Log detailed output to update file if enabled
            if ($global:CreateUpdateLog -eq 1 -and $updateLogFile) {
                $timestamp = Get-Date -Format "[yyyy.MM.dd ; HH:mm:ss]"
                "$timestamp [DEBUG] WinGet output for $appId`: $result" | Out-File -FilePath $updateLogFile -Append -Encoding UTF8
                
                if ($LASTEXITCODE -eq 0) {
                    "$timestamp [INFO]  $($global:LanguageStrings.install_success): $appId" | Out-File -FilePath $updateLogFile -Append -Encoding UTF8
                } else {
                    "$timestamp [ERROR] $($global:LanguageStrings.install_error) $appId with exit code: $LASTEXITCODE" | Out-File -FilePath $updateLogFile -Append -Encoding UTF8
                }
            }
            
        }
        catch {
            Write-LogEntry "$($global:LanguageStrings.install_error) $appId`: $($_.Exception.Message)" "ERROR"
            
            # Log error to update file if enabled
            if ($global:CreateUpdateLog -eq 1 -and $updateLogFile) {
                $timestamp = Get-Date -Format "[yyyy.MM.dd ; HH:mm:ss]"
                "$timestamp [ERROR] Exception processing $appId`: $($_.Exception.Message)" | Out-File -FilePath $updateLogFile -Append -Encoding UTF8
            }
        }
    }
    
    Write-LogEntry $global:LanguageStrings.update_completed "INFO"
}

function Main {
    <#
    .SYNOPSIS
        Main execution function that orchestrates the entire application workflow
    .DESCRIPTION
        This function manages the complete application lifecycle including configuration
        loading, language pack initialization, update file processing, WinGet validation,
        and application updates. It ensures proper error handling and logging throughout
        the execution process.
    .OUTPUTS
        None. Executes the complete application workflow.
    .USAGE EXAMPLE
        Main
    .NOTES
        The function implements a sequential workflow where each step must succeed
        before proceeding to the next. Critical failures result in application
        termination with appropriate error codes and logging.
    #>
    
    # Clear/create main log file at start
    $logFile = Join-Path $global:AppPath "winget.automator.log"
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }
    
    # Initial startup message in English (before language pack is loaded)
    Write-LogEntry "Application starting - using English until language pack is loaded" "INFO"
    Write-LogEntry "WinGet Automator v$global:AppVers started" "INFO"
    
    # Step 1: Load configuration
    if (-not (Load-Configuration)) {
        Write-LogEntry "Configuration loading failed, exiting application" "ERROR"
        exit 1
    }
    
    # Step 2: Load language file
    if (-not (Load-LanguageFile)) {
        Write-LogEntry "Language file loading failed, exiting application" "ERROR"
        exit 1
    }
    
    # Step 3: Load update file
    $appList = Load-UpdateFile
    if ($null -eq $appList) {
        Write-LogEntry $global:LanguageStrings.updatefile_error ", exiting application" "ERROR"
        exit 1
    }
    
    # Step 4: Check WinGet availability
    if (-not (Test-WinGetAvailability)) {
        Write-LogEntry $global:LanguageStrings.winget_not_available ", exiting application" "ERROR"
        exit 1
    }
    
    # Step 5: Update applications
    Update-Applications -AppList $appList
    
    Write-LogEntry $global:LanguageStrings.execution_completed "INFO"
}

# Start main execution
Main