<#
.SYNOPSIS
    SysDaemon - System daemon script for managing Windows scheduled tasks with PowerShell
    
.DESCRIPTION
    SysDaemon is a comprehensive PowerShell script designed to manage Windows scheduled tasks 
    through command-line parameters. It provides functionality to create, delete, execute, and 
    terminate scheduled tasks running under SYSTEM context. The script supports multilingual 
    operation through JSON language packs and maintains detailed logging of all operations.
    
    Key Features:
    - Multi-language support via JSON language packs
    - Administrative privilege validation
    - Automatic console window minimization
    - Comprehensive error handling and logging
    - Security features: automatic task disabling after operations
    - COM-based task scheduler manipulation for maximum compatibility
    - UTF-8 BOM encoding support for international characters
    - Complete silent parameter validation with no console output
    
.USAGE
    .\sysdaemon.main.ps1 -axn "add-job" [-LangPack "en-us.json"]
    .\sysdaemon.main.ps1 -axn "del-job" [-LangPack "de-de.json"] 
    .\sysdaemon.main.ps1 -axn "exec-job"
    .\sysdaemon.main.ps1 -axn "kill-job"
    
.PARAMETER axn
    Specifies the action to perform. Valid values (case insensitive):
    - "add-job": Creates a new scheduled task from XML template
    - "del-job": Deletes the scheduled task and cleans up empty folders
    - "exec-job": Executes the scheduled task once and disables it for security
    - "kill-job": Stops running task and sets historic trigger to prevent future execution
    
.PARAMETER LangPack
    Specifies the language pack file to use for localized messages (case insensitive).
    Default: "en-us.json"
    Supported: "en-us.json", "de-de.json"
    Future: Extensible for additional language packs
    
.EXAMPLE
    .\sysdaemon.main.ps1 -axn "add-job"
    Creates a new scheduled task using default English language pack
    
.EXAMPLE
    .\sysdaemon.main.ps1 -axn "exec-job" -LangPack "de-de.json"
    Executes the scheduled task with German language output
    
.NOTES
    Creation Date:  04.10.2025
    Last Update:    05.10.2025
    Version:        1.00.10
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
    
    Dependencies:
    - Windows PowerShell 5.1 or PowerShell Core 6+
    - Administrative privileges required
    - Task Scheduler service must be running
    - XML template file (RunSystemJob.xml) required for add-job
    - Language pack JSON files (en-us.json, de-de.json, etc.)
    
    Security Features:
    - Automatic task disabling after creation and execution
    - COM-based trigger manipulation to avoid PowerShell collection limitations
    - Comprehensive privilege validation
    - Secure error handling without information disclosure
    - Complete silent parameter validation with comprehensive logging
    
    Parameter Validation:
    - Only -axn and -LangPack parameters are permitted
    - All parameter validation errors are logged silently to sysdaemon.main.log
    - No console error output - all errors are handled gracefully
    - Case-insensitive parameter names and values
#>

# NO PARAM BLOCK - We handle parameters manually to avoid PowerShell's built-in validation
# This is the key to preventing console error messages

# Global version variable for dynamic use in language packs and error reporting
$Global:SysDaemonVersion = "1.00.10"

# Import required .NET types for Win32 API console window management
# This allows us to minimize the PowerShell console window to prevent user distraction
Add-Type -Name Window -Namespace Console -MemberDefinition @'
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@

function ConsoleWindowToTaskbar {
    <#
    .SYNOPSIS
        Minimizes the PowerShell console window to the taskbar
        
    .DESCRIPTION
        Uses Win32 API calls to minimize the console window, providing a cleaner
        user experience when running as a background daemon. Errors are silently
        ignored as window management is not critical to core functionality.
        
    .NOTES
        ShowWindow constants:
        0 = SW_HIDE, 1 = SW_SHOWNORMAL, 2 = SW_SHOWMINIMIZED, 3 = SW_SHOWMAXIMIZED
    #>
    try {
        # Get handle to current console window
        $consolePtr = [Console.Window]::GetConsoleWindow()
        
        # Minimize window (SW_SHOWMINIMIZED = 2)
        [void][Console.Window]::ShowWindow($consolePtr, 2)
    } catch {
        # Silently ignore minimization errors - not critical to core functionality
        # This ensures the script continues even if window management fails
    }
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Tests if the current PowerShell session is running with administrative privileges
        
    .DESCRIPTION
        Uses .NET security principal classes to determine if the current user context
        has administrative rights. This is required for scheduled task operations.
        
    .OUTPUTS
        System.Boolean - True if running as administrator, False otherwise
        
    .NOTES
        This function is critical for security validation as scheduled task operations
        require elevated privileges in Windows.
    #>
    try {
        # Get current Windows identity
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        
        # Create principal object to check roles
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        
        # Check if user is in the built-in Administrators role
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        # Return false on any error to ensure security (fail-safe)
        return $false
    }
}

function TextPlaceholdersReplacer {
    <#
    .SYNOPSIS
        Safely replaces a single placeholder ({0}) in text strings
        
    .DESCRIPTION
        Performs string replacement without using regex to avoid potential
        regex injection or parsing issues. Handles empty/null replacement values gracefully.
        
    .PARAMETER Text
        The source text containing placeholder(s) to replace
        
    .PARAMETER Replacement
        The value to substitute for {0} placeholder. Can be empty or null.
        
    .OUTPUTS
        System.String - Text with placeholder replaced
        
    .EXAMPLE
        TextPlaceholdersReplacer "Hello {0}!" "World"
        Returns: "Hello World!"
        
    .NOTES
        This function is used extensively for localized message formatting.
        Simple string replacement is used instead of -replace operator for security.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$false)]
        [string]$Replacement = ""
    )
    
    # Use simple string replacement instead of regex to avoid security issues
    # The Replace method is safer than -replace operator for dynamic content
    $result = $Text
    if ($Replacement) {
        $result = $result.Replace("{0}", $Replacement)
    }
    return $result
}

function MultipleTextPlaceholdersReplacer {
    <#
    .SYNOPSIS
        Replaces multiple indexed placeholders ({0}, {1}, {2}, etc.) in text strings
        
    .DESCRIPTION
        Performs sequential replacement of multiple placeholders using indexed
        substitution. Each placeholder {n} is replaced with the corresponding
        array element from the Replacements parameter.
        
    .PARAMETER Text
        The source text containing indexed placeholders to replace
        
    .PARAMETER Replacements
        Array of replacement values. Index 0 replaces {0}, index 1 replaces {1}, etc.
        
    .OUTPUTS
        System.String - Text with all indexed placeholders replaced
        
    .EXAMPLE
        MultipleTextPlaceholdersReplacer "Error {0} in file {1}" @("404", "config.json")
        Returns: "Error 404 in file config.json"
        
    .NOTES
        This function enables complex localized messages with multiple dynamic values.
        Replacement is performed sequentially to ensure predictable results.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$false)]
        [string[]]$Replacements = @()
    )
    
    $result = $Text
    
    # Process each replacement in sequence
    for ($i = 0; $i -lt $Replacements.Length; $i++) {
        $placeholder = "{$i}"
        $result = $result.Replace($placeholder, $Replacements[$i])
    }
    
    return $result
}

function Write-LogEntry {
    <#
    .SYNOPSIS
        Writes timestamped log entries with severity level classification
        
    .DESCRIPTION
        Creates standardized log entries with consistent formatting including
        timestamp, severity level, and message content. All entries are written
        to the script-level log file with UTF-8 encoding.
        
    .PARAMETER Message
        The log message content to write
        
    .PARAMETER Level
        Severity level: INFO, WARN, ERROR, or DEBUG
        Default: INFO
        
    .NOTES
        Log format: [YYYY.MM.DD - HH:mm:ss] [LEVEL] Message
        
        Severity Levels:
        - DEBUG: Detailed diagnostic information
        - INFO:  General informational messages
        - WARN:  Warning conditions that don't prevent operation
        - ERROR: Error conditions that may cause operation failure
        
        UTF-8 encoding ensures international character support in log files.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    # Skip logging if log file is not initialized (fail-safe)
    if (-not $script:LogFile) {
        return
    }
    
    # Generate timestamp in consistent format
    $timestamp = Get-Date -Format "yyyy.MM.dd - HH:mm:ss"
    
    # Format severity level with consistent spacing for alignment
    $formattedLevel = switch ($Level) {
        "INFO"  { "[INFO] " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERROR]" }
        "DEBUG" { "[DEBUG]" }
    }
    
    # Construct complete log entry
    $logEntry = "[$timestamp] $formattedLevel $Message"
    
    try {
        # Write to log file with UTF-8 encoding for international character support
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        # Silently ignore logging failures to prevent infinite error loops
        # This ensures the script continues even if disk space or permissions issues occur
    }
}

function Exit-WithLog {
    <#
    .SYNOPSIS
        Safely exits the script with proper logging and cleanup
        
    .DESCRIPTION
        Provides a centralized exit mechanism that ensures proper logging of
        termination conditions. Handles cases where language packs may not
        be loaded by providing fallback termination messages.
        
    .PARAMETER Message
        The final message to log before termination
        
    .PARAMETER Level
        Severity level for the final message (default: ERROR)
        
    .PARAMETER ExitCode
        Numeric exit code for the process (default: 1 for error)
        
    .NOTES
        Exit codes:
        0 = Success
        1 = General error
        2 = Parameter validation error
        3 = Permission denied
        
        This function ensures clean termination even when language packs fail to load.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "ERROR",
        
        [Parameter(Mandatory=$false)]
        [int]$ExitCode = 1
    )
    
    # Log the primary exit message
    Write-LogEntry $Message $Level
    
    # Log termination details with fallback for missing language packs
    if ($script:LangTexts) {
        # Use localized termination message if language pack is available
        $terminationMessage = TextPlaceholdersReplacer $script:LangTexts.ScriptTerminationMessage $ExitCode.ToString()
        Write-LogEntry $terminationMessage "DEBUG"
    } else {
        # Fallback to hardcoded English when no language pack is available
        # This is the only scenario where hardcoded text is acceptable
        Write-LogEntry "Script execution terminated with exit code: $ExitCode" "DEBUG"
    }
    
    # Terminate script with specified exit code
    exit $ExitCode
}

function Remove-EmptyTaskFolder {
    <#
    .SYNOPSIS
        Removes empty task scheduler folders after task deletion
        
    .DESCRIPTION
        Performs cleanup of empty task scheduler folders using COM objects
        for direct interaction with Task Scheduler service. Provides detailed
        logging of cleanup operations and handles errors gracefully.
        
    .PARAMETER FolderPath
        The task scheduler folder path to check and potentially remove
        
    .NOTES
        This function uses COM objects instead of PowerShell cmdlets for
        better compatibility and error handling. The folder is only removed
        if it contains no scheduled tasks.
        
        COM Object: Schedule.Service provides direct access to Task Scheduler
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath
    )
    
    try {
        # Check if folder contains any scheduled tasks
        $tasksInFolder = @(Get-ScheduledTask -TaskPath $FolderPath -ErrorAction SilentlyContinue)
        
        if ($tasksInFolder.Count -eq 0) {
            # Folder is empty - proceed with removal using COM objects
            $folderEmptyMessage = TextPlaceholdersReplacer $LangTexts.TaskFolderEmptyMessage $FolderPath
            Write-LogEntry $folderEmptyMessage "DEBUG"
            
            # Initialize COM object for Task Scheduler
            $taskService = New-Object -ComObject("Schedule.Service")
            $taskService.Connect()
            $rootFolder = $taskService.GetFolder("\")
            
            # Remove the folder (path must not include leading/trailing slashes)
            $folderName = $FolderPath.Trim('\')
            $rootFolder.DeleteFolder($folderName, 0)
            
            Write-LogEntry $LangTexts.TaskFolderDeleted "INFO"
        } else {
            # Folder contains tasks - log warning and skip removal
            $folderNotEmptyMessage = TextPlaceholdersReplacer $LangTexts.TaskFolderNotEmpty $tasksInFolder.Count.ToString()
            Write-LogEntry $folderNotEmptyMessage "WARN"
        }
    } catch {
        # Log cleanup errors but continue script execution
        $folderDeleteErrorMessage = TextPlaceholdersReplacer $LangTexts.TaskFolderDeleteError $_.Exception.Message
        Write-LogEntry $folderDeleteErrorMessage "WARN"
    }
}

function Get-LanguagePackLoadedMessage {
    <#
    .SYNOPSIS
        Provides multilingual language pack loading success messages
        
    .DESCRIPTION
        Determines the appropriate language for "Language pack loaded successfully"
        message based on the loaded language pack file. Supports extensible
        language detection for future language pack additions.
        
    .PARAMETER LangPackFile
        The filename of the successfully loaded language pack
        
    .OUTPUTS
        System.String - Localized success message in the appropriate language
        
    .NOTES
        Current supported languages:
        - en-us.json: English
        - de-de.json: German
        
        Future extensibility: Additional language mappings can be easily added
        to the switch statement for new language pack files.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$LangPackFile
    )
    
    # Determine appropriate language for the success message based on loaded pack
    # This provides immediate feedback in the user's chosen language
    switch ($LangPackFile.ToLower()) {
        "en-us.json" { 
            return "Language pack loaded successfully: $LangPackFile" 
        }
        "de-de.json" { 
            return "Sprachpaket erfolgreich geladen: $LangPackFile" 
        }
        "it-it.json" { 
            # Future Italian support
            return "Pacchetto linguistico caricato con successo: $LangPackFile" 
        }
        "fr-fr.json" { 
            # Future French support
            return "Pack de langue chargé avec succès: $LangPackFile" 
        }
        "es-es.json" { 
            # Future Spanish support
            return "Paquete de idioma cargado exitosamente: $LangPackFile" 
        }
        default { 
            # Fallback to English for unknown language packs
            return "Language pack loaded successfully: $LangPackFile" 
        }
    }
}

function Parse-CommandLineArguments {
    <#
    .SYNOPSIS
        Manually parses command line arguments to avoid PowerShell's built-in parameter validation
        
    .DESCRIPTION
        Processes the $args array to extract and validate parameters. This approach bypasses
        PowerShell's built-in parameter binding which would cause console errors before our
        code executes. All validation errors are logged silently.
        
    .PARAMETER Arguments
        Array of command line arguments from $args
        
    .OUTPUTS
        System.Collections.Hashtable - Parsed and validated parameters
        
    .NOTES
        This function enables complete control over parameter validation and error handling.
        It supports case-insensitive parameter names and provides comprehensive validation
        with detailed error logging for troubleshooting.
        
        Supported parameters:
        -axn: Required action parameter
        -LangPack: Optional language pack parameter
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Arguments
    )
    
    # Initialize result hashtable
    $parsedParams = @{
        axn = ""
        LangPack = "en-us.json"  # Default value
    }
    
    $validActions = @('add-job', 'del-job', 'exec-job', 'kill-job')
    $validLangPacks = @('en-us.json', 'de-de.json')
    $allowedParams = @('-axn', '-langpack')
    
    # Process arguments in pairs (parameter name, parameter value)
    for ($i = 0; $i -lt $Arguments.Length; $i++) {
        $currentArg = $Arguments[$i]
        
        # Check if this looks like a parameter (starts with -)
        if ($currentArg -and $currentArg.StartsWith('-')) {
            $paramName = $currentArg.ToLower()
            
            # Check if this is a known parameter
            if ($paramName -notin $allowedParams) {
                $unknownParamMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorUnknownParameter $currentArg
                Write-LogEntry $unknownParamMessage "ERROR"
                $allowedParamsMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorAllowedParameters ($allowedParams -join ', ')
                Write-LogEntry $allowedParamsMessage "ERROR"
                Write-LogEntry $script:LangTexts.ErrorParameterUsageExample "ERROR"
                Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
            }
            
            # Get the parameter value (next argument)
            if ($i + 1 -lt $Arguments.Length) {
                $paramValue = $Arguments[$i + 1]
                $i++  # Skip the value in next iteration
                
                # Validate parameter value is not another parameter
                if ($paramValue.StartsWith('-')) {
                    $missingValueMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorMissingParameterValue $currentArg
                    Write-LogEntry $missingValueMessage "ERROR"
                    Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
                }
            } else {
                # Parameter provided but no value
                $missingValueMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorMissingParameterValue $currentArg
                Write-LogEntry $missingValueMessage "ERROR"
                Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
            }
            
            # Process specific parameters
            switch ($paramName) {
                '-axn' {
                    if ([string]::IsNullOrWhiteSpace($paramValue)) {
                        Write-LogEntry $script:LangTexts.ErrorEmptyAxnParameter "ERROR"
                        Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
                    }
                    
                    $axnLower = $paramValue.Trim().ToLower()
                    if ($axnLower -notin $validActions) {
                        $invalidActionMessage = MultipleTextPlaceholdersReplacer $script:LangTexts.ErrorInvalidAxnValue @($paramValue, ($validActions -join ', '))
                        Write-LogEntry $invalidActionMessage "ERROR"
                        Write-LogEntry $script:LangTexts.ErrorParameterUsageExample "ERROR"
                        Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
                    }
                    
                    $parsedParams.axn = $axnLower
                }
                
                '-langpack' {
                    if ([string]::IsNullOrWhiteSpace($paramValue)) {
                        Write-LogEntry $script:LangTexts.ErrorEmptyLangPackParameter "ERROR"
                        Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
                    }
                    
                    # Basic format validation (should end with .json)
                    $langPackLower = $paramValue.Trim().ToLower()
                    if (-not $langPackLower.EndsWith('.json')) {
                        $invalidLangPackMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorInvalidLangPackFormat $paramValue
                        Write-LogEntry $invalidLangPackMessage "ERROR"
                        Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
                    }
                    
                    $parsedParams.LangPack = $langPackLower
                }
            }
        } else {
            # Found a non-parameter argument - this is not allowed
            $unexpectedArgMessage = TextPlaceholdersReplacer $script:LangTexts.ErrorUnexpectedArgument $currentArg
            Write-LogEntry $unexpectedArgMessage "ERROR"
            Write-LogEntry $script:LangTexts.ErrorParameterUsageExample "ERROR"
            Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
        }
    }
    
    # Validate required parameters
    if ([string]::IsNullOrWhiteSpace($parsedParams.axn)) {
        Write-LogEntry $script:LangTexts.ErrorMissingAction "ERROR"
        Write-LogEntry $script:LangTexts.ErrorParameterUsageExample "ERROR"
        Exit-WithLog $script:LangTexts.ErrorInvalidParameterUsage "ERROR" 2
    }
    
    return $parsedParams
}

# ============================================================================
# SCRIPT INITIALIZATION AND CONFIGURATION
# ============================================================================

# Initialize core script variables with proper path resolution
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "sysdaemon.main.log"
$TaskName = "RunSystemJob"
$TaskFolderPath = "\sysdaemon\"
$XMLFile = Join-Path $ScriptDir "RunSystemJob.xml"

# Minimize console window for cleaner user experience
ConsoleWindowToTaskbar

# Initialize log file with cleanup of previous runs
try {
    # Remove existing log file to start fresh
    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force -ErrorAction Stop
    }
    
    # Create new empty log file
    New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
} catch {
    # Critical failure - cannot proceed without logging capability
    # Exit immediately with error code 1
    exit 1
}

# ============================================================================
# ENHANCED LANGUAGE PACK LOADING WITH STRICT VALIDATION
# ============================================================================

# Set default language pack for initial loading (before parameter parsing)
$requestedLangPack = "en-us.json"
$validLangPacks = @("en-us.json", "de-de.json")

# Determine language pack loading strategy
$langPacksToTry = @("en-us.json")  # Always start with English for error messages

# Attempt to load initial language pack for error message handling
$LangTexts = $null
$loadedLangPack = ""

foreach ($langPackFile in $langPacksToTry) {
    $LangPackPath = Join-Path $ScriptDir $langPackFile
    Write-LogEntry "Attempting to load initial language pack: $LangPackPath" "DEBUG"
    
    if (Test-Path $LangPackPath) {
        try {
            # Load and parse JSON language pack
            $rawContent = Get-Content $LangPackPath -Raw -ErrorAction Stop
            $LangTexts = ConvertFrom-Json $rawContent -ErrorAction Stop
            $loadedLangPack = $langPackFile
            
            # Use multilingual success message based on loaded language pack
            $successMessage = Get-LanguagePackLoadedMessage $langPackFile
            Write-LogEntry $successMessage "INFO"
            break
        } catch {
            # Log JSON parsing or file read errors
            Write-LogEntry "Error loading language pack $langPackFile : $($_.Exception.Message)" "ERROR"
            $LangTexts = $null
        }
    } else {
        # Log missing language pack files
        Write-LogEntry "Language pack file not found: $LangPackPath" "ERROR"
    }
}

# Critical validation: Exit if no language pack could be loaded
if (-not $LangTexts) {
    # This is the only scenario where hardcoded English text is acceptable
    Write-LogEntry "CRITICAL ERROR: No language pack could be loaded. All required language files are missing or corrupted." "ERROR"
    Write-LogEntry "Required files: en-us.json, de-de.json (at least en-us.json must be available)" "ERROR"
    Write-LogEntry "Script execution terminated due to missing language pack files." "ERROR"
    Write-LogEntry "Script execution terminated with exit code: 1" "DEBUG"
    exit 1
}

# ============================================================================
# MANUAL PARAMETER PROCESSING AND VALIDATION
# ============================================================================

# Parse command line arguments manually to avoid PowerShell's built-in parameter binding
$parsedParameters = Parse-CommandLineArguments -Arguments $args

# Extract validated parameters
$axn = $parsedParameters.axn
$LangPack = $parsedParameters.LangPack

# If user requested a different language pack, reload with that pack
if ($LangPack.ToLower() -ne $loadedLangPack.ToLower()) {
    Write-LogEntry "User requested different language pack: $LangPack" "DEBUG"
    
    # Try to load the requested language pack
    $requestedLangPackPath = Join-Path $ScriptDir $LangPack
    if (Test-Path $requestedLangPackPath) {
        try {
            $rawContent = Get-Content $requestedLangPackPath -Raw -ErrorAction Stop
            $LangTexts = ConvertFrom-Json $rawContent -ErrorAction Stop
            $loadedLangPack = $LangPack
            
            $successMessage = Get-LanguagePackLoadedMessage $LangPack
            Write-LogEntry $successMessage "INFO"
        } catch {
            # Fall back to English if requested language pack fails to load
            $fallbackMessage = TextPlaceholdersReplacer $LangTexts.LanguagePackFallbackMessage $LangPack
            Write-LogEntry $fallbackMessage "WARN"
        }
    } else {
        # Requested language pack not found - log warning but continue with English
        $fallbackMessage = TextPlaceholdersReplacer $LangTexts.LanguagePackFallbackMessage $LangPack
        Write-LogEntry $fallbackMessage "WARN"
    }
}

# ============================================================================
# CORE SCRIPT STARTUP AND VALIDATION
# ============================================================================

# Log startup sequence with localized messages
$initMessage = TextPlaceholdersReplacer $LangTexts.InitializingMessage $Global:SysDaemonVersion
Write-LogEntry $initMessage "DEBUG"

$scriptDirMessage = TextPlaceholdersReplacer $LangTexts.ScriptDirectoryMessage $ScriptDir
Write-LogEntry $scriptDirMessage "DEBUG"

$logFileMessage = TextPlaceholdersReplacer $LangTexts.LogFileMessage $LogFile
Write-LogEntry $logFileMessage "DEBUG"

# Critical security check: Validate administrative privileges
Write-LogEntry $LangTexts.AdminCheckMessage "DEBUG"
if (-not (Test-IsAdministrator)) {
    Exit-WithLog $LangTexts.AdminRequiredMessage "ERROR" 3
}
Write-LogEntry $LangTexts.AdminPrivilegesConfirmed "DEBUG"

# Log successful parameter validation
$paramValidationMessage = MultipleTextPlaceholdersReplacer $LangTexts.ParameterValidationMessage @($parsedParameters.axn, $axn)
Write-LogEntry $paramValidationMessage "DEBUG"

# Log successful startup
$startupMessage = TextPlaceholdersReplacer $LangTexts.StartupMessage $Global:SysDaemonVersion
Write-LogEntry $startupMessage "INFO"

# ============================================================================
# MAIN ACTION PROCESSING WITH ENHANCED ERROR HANDLING
# ============================================================================

$beginMessage = TextPlaceholdersReplacer $LangTexts.BeginProcessingMessage $axn
Write-LogEntry $beginMessage "DEBUG"

switch ($axn) {
    "add-job" {
        Write-LogEntry $LangTexts.StartAddJob "INFO"
        
        # Validate XML template file existence
        if (-not (Test-Path $XMLFile)) {
            $errorMessage = TextPlaceholdersReplacer $LangTexts.ErrorXMLNotFound $XMLFile
            Exit-WithLog $errorMessage "ERROR"
        }
        $xmlFoundMessage = TextPlaceholdersReplacer $LangTexts.XMLTemplateFileFound $XMLFile
        Write-LogEntry $xmlFoundMessage "DEBUG"
        
        try {
            # Check for and remove any existing task
            Write-LogEntry $LangTexts.CheckingExistingTask "DEBUG"
            $existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
            if ($existingTask) {
                Write-LogEntry $LangTexts.DeleteExistingTask "WARN"
                Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Confirm:$false -ErrorAction Stop
                Write-LogEntry $LangTexts.ExistingTaskRemoved "DEBUG"
            } else {
                Write-LogEntry $LangTexts.NoExistingTaskFound "DEBUG"
            }
            
            # Import task definition from XML template
            $xmlContent = Get-Content $XMLFile -Raw -ErrorAction Stop
            Write-LogEntry $LangTexts.ImportingTask "INFO"
            Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Xml $xmlContent -User "SYSTEM" -ErrorAction Stop | Out-Null
            Write-LogEntry $LangTexts.TaskRegisteredFromXML "DEBUG"
            
            # Update task arguments with absolute script path
            $fullScriptPath = Join-Path $ScriptDir "sysdaemon.job.ps1"
            $newArguments = "--headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File `"$fullScriptPath`""
            $updatingArgumentsMessage = TextPlaceholdersReplacer $LangTexts.UpdatingTaskArguments $fullScriptPath
            Write-LogEntry $updatingArgumentsMessage "DEBUG"
            
            # Apply updated arguments to task
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction Stop
            $task.Actions[0].Arguments = $newArguments
            Set-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
            Write-LogEntry $LangTexts.TaskArgumentsUpdated "DEBUG"
            
            # SECURITY FEATURE: Disable task after creation to prevent accidental execution
            Write-LogEntry $LangTexts.DisablingTaskAfterCreation "DEBUG"
            Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
            Write-LogEntry $LangTexts.TaskDisabledAfterCreation "INFO"
            
            Write-LogEntry $LangTexts.TaskCreatedSuccessfully "INFO"
        } catch {
            # Comprehensive error logging for troubleshooting
            $errorMessage = TextPlaceholdersReplacer $LangTexts.ErrorCreatingTask $_.Exception.Message
            Write-LogEntry $errorMessage "ERROR"
            $detailedErrorMessage = TextPlaceholdersReplacer $LangTexts.DetailedErrorMessage $_.Exception.ToString()
            Write-LogEntry $detailedErrorMessage "ERROR"
            exit 1
        }
    }
    
    "del-job" {
        Write-LogEntry $LangTexts.StartDeleteJob "INFO"
        
        try {
            # Locate and delete scheduled task
            Write-LogEntry $LangTexts.SearchingTaskToDelete "DEBUG"
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
            if ($task) {
                Write-LogEntry $LangTexts.TaskFoundProceedingDeletion "DEBUG"
                Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Confirm:$false -ErrorAction Stop
                Write-LogEntry $LangTexts.TaskDeletedSuccessfully "INFO"
                
                # Cleanup: Remove empty task folder if no other tasks exist
                Remove-EmptyTaskFolder -FolderPath $TaskFolderPath
            } else {
                Write-LogEntry $LangTexts.TaskNotFound "WARN"
            }
        } catch {
            # Comprehensive error logging for troubleshooting
            $errorMessage = TextPlaceholdersReplacer $LangTexts.ErrorDeletingTask $_.Exception.Message
            Write-LogEntry $errorMessage "ERROR"
            $detailedErrorMessage = TextPlaceholdersReplacer $LangTexts.DetailedErrorMessage $_.Exception.ToString()
            Write-LogEntry $detailedErrorMessage "ERROR"
            exit 1
        }
    }
    
    "exec-job" {
        Write-LogEntry $LangTexts.StartExecuteJob "INFO"
        
        try {
            # Locate scheduled task for execution
            Write-LogEntry $LangTexts.LocatingTaskForExecution "DEBUG"
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
            if ($task) {
                Write-LogEntry $LangTexts.TaskFoundCheckingState "DEBUG"
                $taskState = $task.State
                $currentTaskStateMessage = TextPlaceholdersReplacer $LangTexts.CurrentTaskState $taskState
                Write-LogEntry $currentTaskStateMessage "DEBUG"
                
                # Enable task for execution
                Write-LogEntry $LangTexts.EnablingScheduledTask "DEBUG"
                Enable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                Write-LogEntry $LangTexts.TaskEnabled "INFO"
                
                # Execute the scheduled task
                Write-LogEntry $LangTexts.StartingTaskExecution "DEBUG"
                Start-ScheduledTask -InputObject $task -ErrorAction Stop
                Write-LogEntry $LangTexts.TaskStartedSuccessfully "INFO"
                
                # SECURITY FEATURE: Wait briefly for task to start, then disable it
                Write-LogEntry $LangTexts.WaitingForTaskToStart "DEBUG"
                Start-Sleep -Seconds 2
                
                # Disable task to prevent accidental future executions
                Write-LogEntry $LangTexts.DisablingTaskForSecurity "DEBUG"
                Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                Write-LogEntry $LangTexts.TaskDisabledForSecurity "INFO"
                
            } else {
                # Task not found - cannot execute
                Write-LogEntry $LangTexts.TaskNotFound "ERROR"
                Write-LogEntry $LangTexts.CannotExecuteNonExistentTask "ERROR"
                exit 1
            }
        } catch {
            # Comprehensive error logging for troubleshooting
            $errorMessage = TextPlaceholdersReplacer $LangTexts.ErrorExecutingTask $_.Exception.Message
            Write-LogEntry $errorMessage "ERROR"
            $detailedErrorMessage = TextPlaceholdersReplacer $LangTexts.DetailedErrorMessage $_.Exception.ToString()
            Write-LogEntry $detailedErrorMessage "ERROR"
            exit 1
        }
    }
    
    "kill-job" {
        Write-LogEntry $LangTexts.StartKillJob "INFO"
        
        try {
            # Locate scheduled task for termination
            Write-LogEntry $LangTexts.LocatingTaskForTermination "DEBUG"
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
            if ($task) {
                Write-LogEntry $LangTexts.TaskFoundCheckingExecutionStatus "DEBUG"
                
                # Check current task execution status
                $taskInfo = Get-ScheduledTaskInfo -InputObject $task -ErrorAction Stop
                $lastResultMessage = TextPlaceholdersReplacer $LangTexts.TaskLastResult $taskInfo.LastTaskResult.ToString()
                Write-LogEntry $lastResultMessage "DEBUG"
                $lastRunTimeMessage = TextPlaceholdersReplacer $LangTexts.TaskLastRunTime $taskInfo.LastRunTime.ToString()
                Write-LogEntry $lastRunTimeMessage "DEBUG"
                
                # Stop task if currently running
                if ($taskInfo.LastTaskResult -eq 267009) { # SCHED_S_TASK_RUNNING
                    Write-LogEntry $LangTexts.TaskCurrentlyRunning "DEBUG"
                    Stop-ScheduledTask -InputObject $task -ErrorAction Stop
                    Write-LogEntry $LangTexts.TaskStopped "INFO"
                } else {
                    Write-LogEntry $LangTexts.TaskNotCurrentlyRunning "DEBUG"
                }
                
                # Use COM objects to modify trigger and avoid PowerShell collection limitations
                Write-LogEntry $LangTexts.ConfiguringTriggerHistoricDate "DEBUG"
                try {
                    # Initialize COM objects for Task Scheduler manipulation
                    $taskService = New-Object -ComObject("Schedule.Service")
                    $taskService.Connect()
                    $rootFolder = $taskService.GetFolder($TaskFolderPath.TrimEnd('\'))
                    $comTask = $rootFolder.GetTask($TaskName)
                    
                    # Modify task definition to prevent future execution
                    $taskDefinition = $comTask.Definition
                    
                    # Clear existing triggers and set historic one-time trigger
                    $taskDefinition.Triggers.Clear()
                    $newTrigger = $taskDefinition.Triggers.Create(1) # TASK_TRIGGER_TIME
                    $newTrigger.StartBoundary = "1982-06-22T08:00:00"  # Historic date
                    $newTrigger.Enabled = $true
                    
                    # Apply updated task definition
                    $rootFolder.RegisterTaskDefinition($TaskName, $taskDefinition, 4, $null, $null, 3) | Out-Null
                    Write-LogEntry $LangTexts.TriggerUpdatedHistoricExecution "DEBUG"
                    
                    # Disable task as final security measure
                    Write-LogEntry $LangTexts.DisablingScheduledTask "DEBUG"
                    Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                    Write-LogEntry $LangTexts.TaskDisabledAndConfigured "INFO"
                    
                } catch {
                    # Fallback if COM operations fail
                    $comErrorMessage = TextPlaceholdersReplacer $LangTexts.COMOperationFailed $_.Exception.Message
                    Write-LogEntry $comErrorMessage "WARN"
                    
                    # Simple fallback: just disable the task
                    Write-LogEntry $LangTexts.FallbackDisablingTask "DEBUG"
                    Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                    Write-LogEntry $LangTexts.TaskDisabled "INFO"
                }
            } else {
                # Task not found - nothing to kill
                Write-LogEntry $LangTexts.TaskNotFound "WARN"
                Write-LogEntry $LangTexts.NoTaskToKill "DEBUG"
            }
        } catch {
            # Comprehensive error logging for troubleshooting
            try {
                $errorMessage = TextPlaceholdersReplacer $LangTexts.ErrorKillingTask $_.Exception.Message
                Write-LogEntry $errorMessage "ERROR"
            } catch {
                # Ultimate fallback if even error message replacement fails
                $fallbackErrorMessage = TextPlaceholdersReplacer $LangTexts.ErrorDuringKillJobOperation $_.Exception.Message
                Write-LogEntry $fallbackErrorMessage "ERROR"
            }
            $detailedErrorMessage = TextPlaceholdersReplacer $LangTexts.DetailedErrorMessage $_.Exception.ToString()
            Write-LogEntry $detailedErrorMessage "ERROR"
            exit 1
        }
    }
}

# ============================================================================
# SCRIPT COMPLETION AND CLEANUP
# ============================================================================

# Log successful completion
Write-LogEntry $LangTexts.ScriptCompleted "INFO"
Write-LogEntry $LangTexts.ScriptFinishedMessage "DEBUG"