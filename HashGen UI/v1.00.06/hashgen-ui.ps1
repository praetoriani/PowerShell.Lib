<#
.SYNOPSIS
    HashGen UI - A cryptographic hash generator with graphical user interface

.DESCRIPTION
    HashGen UI is a PowerShell-based tool that uses SHA algorithms to create checksums for files.
    It provides a complete graphical interface based on XAML/WPF and supports SHA256, SHA384, and SHA512 algorithms.
    The program offers the ability to display the generated hash value temporarily in the program interface
    or alternatively save the created hash value to a file.

.NOTES
    Creation Date: 17.10.2025
    Last Update:   19.10.2025
    Version:       1.00.00
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    REQUIREMENTS & DEPENDENCIES:
    - PowerShell 5.1 or higher
    - Windows Presentation Framework (WPF)
    - .NET Framework 4.5 or higher
    - Windows 10/11 operating system
#>

# ============================================================================
# GLOBAL APPLICATION VARIABLES
# ============================================================================

$global:AppName  = "HashGen UI"
$global:AppVers  = "1.00.00"
$global:AppPath  = $PSScriptRoot
$global:AppIcon  = Join-Path $AppPath "appicon.ico"

# Configuration variables (loaded from config.json)
$global:LangPack    = ""
$global:HashFile    = ""
$global:DebugMode   = ""
$global:DebugFile   = ""
$global:Language    = $null
$global:SystemReady = $false

# ============================================================================
# FUNCTION: HideConsoleWin
# ============================================================================
<#
.DESCRIPTION
    Hides/minimizes the PowerShell console window since this is a GUI application.
    Enhanced to handle alternative console applications like ConEmu.
#>
function HideConsoleWin {
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    try {
        # Check if type already exists before adding
        $typeExists = $null -ne ([System.Management.Automation.PSTypeName]'Console.Window').Type
        
        if (-not $typeExists) {
            try {
                Add-Type -Name Window -Namespace Console -MemberDefinition '
                [DllImport("Kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
                ' -ErrorAction Stop
            }
            catch {
                # If Add-Type fails for any reason, log it but continue
                $status.code = -1
                $status.msg = "Failed to add Console.Window type: $($_.Exception.Message)"
                return $status
            }
        }
        
        # Get console window handle
        $consolePtr = [Console.Window]::GetConsoleWindow()
        
        # Check if we got a valid handle
        if ($consolePtr -eq [IntPtr]::Zero) {
            $status.code = 1
            $status.msg = "Console window handle is zero (possibly running in alternative terminal like ConEmu)"
            return $status
        }
        
        # Try to hide the window
        $result = [Console.Window]::ShowWindow($consolePtr, 0)
        
        if (-not $result) {
            $status.code = 1
            $status.msg = "ShowWindow returned false (console may not be hideable in this environment)"
            return $status
        }
    }
    catch {
        $status.code = -1
        $status.msg = "Failed to hide console window: $($_.Exception.Message)"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: GracefulExit
# ============================================================================
<#
.DESCRIPTION
    Handles fatal errors by logging them to app.error.log and exiting the application.
    
.PARAMETER message
    The error message to log before exiting.
#>
function GracefulExit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$message
    )
    
    $errorLogPath = Join-Path $global:AppPath "app.error.log"
    $timestamp = Get-Date -Format "yyyy.MM.dd - HH:mm:ss"
    $logEntry = "[$timestamp] $message"
    
    try {
        # Create or append to error log
        if (-not (Test-Path $errorLogPath)) {
            New-Item -Path $errorLogPath -ItemType File -Force | Out-Null
        }
        
        Add-Content -Path $errorLogPath -Value $logEntry -Encoding UTF8
    }
    catch {
        # If we can't even write to the error log, there's nothing more we can do
        Write-Host "FATAL: Cannot write to error log: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Exit the application
    exit 1
}

# ============================================================================
# FUNCTION: WriteDebugLog
# ============================================================================
<#
.DESCRIPTION
    Writes debug information to the log file if debugging is enabled.
    
.PARAMETER message
    The message to log.
    
.PARAMETER level
    The log level (INFO, WARN, ERROR, DEBUG).
#>
function WriteDebugLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$level = "INFO"
    )
    
    # Only log if debug mode is enabled
    if ($global:DebugMode -eq "enabled" -and $global:DebugFile -ne "") {
        $logPath = Join-Path $global:AppPath $global:DebugFile
        $timestamp = Get-Date -Format "yyyy.MM.dd - HH:mm:ss"
        
        # Format severity level with consistent spacing for alignment
        $formattedLevel = switch ($level) {
            "INFO"  { "[INFO] " }
            "WARN"  { "[WARN] " }
            "ERROR" { "[ERROR]" }
            "DEBUG" { "[DEBUG]" }
        }
        
        $logEntry = "[$timestamp] $formattedLevel $message"
        
        try {
            Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
        }
        catch {
            # Silently fail if we can't write to debug log
        }
    }
}

# ============================================================================
# FUNCTION: WriteDebugLogDirect
# ============================================================================
<#
.DESCRIPTION
    Writes debug information directly to log file without checking global settings.
    Used for early logging before config is loaded.
    
.PARAMETER message
    The message to log.
    
.PARAMETER level
    The log level (INFO, WARN, ERROR, DEBUG).
#>
function WriteDebugLogDirect {
    param(
        [Parameter(Mandatory=$true)]
        [string]$message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$level = "INFO"
    )
    
    $logPath = Join-Path $global:AppPath "hashgen-ui.log"
    $timestamp = Get-Date -Format "yyyy.MM.dd - HH:mm:ss"
    
    # Format severity level with consistent spacing for alignment
    $formattedLevel = switch ($level) {
        "INFO"  { "[INFO] " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERROR]" }
        "DEBUG" { "[DEBUG]" }
    }
    
    $logEntry = "[$timestamp] $formattedLevel $message"
    
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    }
    catch {
        # Silently fail if we can't write to debug log
    }
}

# ============================================================================
# FUNCTION: ValidatePath
# ============================================================================
<#
.DESCRIPTION
    Validates and canonicalizes file paths to prevent directory traversal attacks.
    
.PARAMETER path
    The path to validate.
    
.PARAMETER baseDir
    The base directory to restrict paths to (optional).
#>
function ValidatePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$path,
        
        [Parameter(Mandatory=$false)]
        [string]$baseDir = ""
    )
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    try {
        # Check for null or empty path
        if ([string]::IsNullOrWhiteSpace($path)) {
            $status.code = -1
            $status.msg = "Path cannot be null or empty"
            return $status
        }
        
        # Get the full canonical path
        $fullPath = [System.IO.Path]::GetFullPath($path)
        
        # If a base directory is specified, ensure the path is within it
        if (-not [string]::IsNullOrWhiteSpace($baseDir)) {
            $baseFullPath = [System.IO.Path]::GetFullPath($baseDir)
            if (-not $fullPath.StartsWith($baseFullPath, [StringComparison]::OrdinalIgnoreCase)) {
                $status.code = -1
                $status.msg = "Path is outside the allowed directory"
                return $status
            }
        }
        
        # Check for suspicious patterns
        $suspiciousPatterns = @("\.\.\\", "\.\./", "~", "%")
        foreach ($pattern in $suspiciousPatterns) {
            if ($path -like "*$pattern*") {
                $status.code = -1
                $status.msg = "Path contains suspicious patterns"
                return $status
            }
        }
    }
    catch {
        $status.code = -1
        $status.msg = "Path validation failed: $($_.Exception.Message)"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: PerformSysCheck
# ============================================================================
<#
.DESCRIPTION
    Performs a complete system check to ensure all required program components exist.
#>
function PerformSysCheck {
    WriteDebugLog -message "Starting system check..." -level "INFO"
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    # Define required files
    $requiredFiles = @(
        "data\config.json",
        "data\lang\en-us.json",
        "data\lang\de-de.json",
        "data\ui\hashgen-ui.error.xaml",
        "data\ui\hashgen-ui.info.xaml",
        "data\ui\hashgen-ui.main.xaml",
        "data\ui\hashgen-ui.output.xaml",
        "data\ui\hashgen-ui.warn.xaml"
    )
    
    # Check each required file
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $global:AppPath $file
        
        if (-not (Test-Path $filePath)) {
            $errorMsg = "CRITICAL: Required file missing: $file"
            WriteDebugLog -message $errorMsg -level "ERROR"
            GracefulExit -message $errorMsg
        }
    }
    
    # Create output directory if it doesn't exist
    $outputDir = Join-Path $global:AppPath "output"
    if (-not (Test-Path $outputDir)) {
        try {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            WriteDebugLog -message "Created output directory" -level "INFO"
        }
        catch {
            $errorMsg = "CRITICAL: Failed to create output directory: $($_.Exception.Message)"
            WriteDebugLog -message $errorMsg -level "ERROR"
            GracefulExit -message $errorMsg
        }
    }
    
    # Set system ready flag
    $global:SystemReady = $true
    WriteDebugLog -message "System check completed successfully" -level "INFO"
    
    return $status
}

# ============================================================================
# FUNCTION: LoadAppConfig
# ============================================================================
<#
.DESCRIPTION
    Loads and validates the application configuration from data\config.json.
#>
function LoadAppConfig {
    WriteDebugLog -message "Loading application configuration..." -level "INFO"
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    $configPath = Join-Path $global:AppPath "data\config.json"
    
    try {
        # Load JSON configuration
        $configContent = Get-Content -Path $configPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        
        # Validate and load langpack setting
        if ($config.PSObject.Properties.Name -contains "langpack" -and -not [string]::IsNullOrWhiteSpace($config.langpack)) {
            $langPath = Join-Path $global:AppPath "data\lang\$($config.langpack)"
            
            if (Test-Path $langPath) {
                $global:LangPack = $config.langpack
                WriteDebugLog -message "Language pack set to: $($config.langpack)" -level "INFO"
            }
            else {
                $global:LangPack = "en-us.json"
                WriteDebugLog -message "Specified language pack not found, defaulting to en-us.json" -level "WARN"
            }
        }
        else {
            $global:LangPack = "en-us.json"
            WriteDebugLog -message "No language pack specified, defaulting to en-us.json" -level "INFO"
        }
        
        # Validate and load hashfile setting
        if ($config.PSObject.Properties.Name -contains "hashfile" -and -not [string]::IsNullOrWhiteSpace($config.hashfile)) {
            # Basic validation: check if it's a valid filename
            if ($config.hashfile -match '^[a-zA-Z0-9_\-\.]+$') {
                $global:HashFile = $config.hashfile
                WriteDebugLog -message "Hash output file set to: $($config.hashfile)" -level "INFO"
            }
            else {
                $global:HashFile = "disabled"
                WriteDebugLog -message "Invalid hashfile name, output disabled" -level "WARN"
            }
        }
        else {
            $global:HashFile = "disabled"
            WriteDebugLog -message "No hash output file specified, output disabled" -level "INFO"
        }
        
        # Validate and load debugger settings
        if ($config.PSObject.Properties.Name -contains "debugger") {
            $debugger = $config.debugger
            
            # Check usagemode
            if ($debugger.PSObject.Properties.Name -contains "usagemode") {
                if ($debugger.usagemode -eq "enabled" -or $debugger.usagemode -eq "disabled") {
                    $global:DebugMode = $debugger.usagemode
                }
                else {
                    $global:DebugMode = "enabled"
                }
            }
            else {
                $global:DebugMode = "enabled"
            }
            
            # Check debugfile
            if ($global:DebugMode -eq "enabled") {
                if ($debugger.PSObject.Properties.Name -contains "debugfile" -and -not [string]::IsNullOrWhiteSpace($debugger.debugfile)) {
                    if ($debugger.debugfile -match '^[a-zA-Z0-9_\-\.]+\.log$') {
                        $global:DebugFile = $debugger.debugfile
                    }
                    else {
                        $global:DebugFile = "hashgen-ui.log"
                    }
                }
                else {
                    $global:DebugFile = "hashgen-ui.log"
                }
                WriteDebugLog -message "Debug mode enabled, log file: $($global:DebugFile)" -level "INFO"
            }
            else {
                $global:DebugFile = ""
                WriteDebugLog -message "Debug mode disabled" -level "INFO"
                
                # Delete log file if debugging is disabled
                $logPath = Join-Path $global:AppPath "hashgen-ui.log"
                if (Test-Path $logPath) {
                    try {
                        Remove-Item -Path $logPath -Force
                        # Can't log this since debugging is disabled
                    }
                    catch {
                        # Silently fail
                    }
                }
            }
        }
        else {
            $global:DebugMode = "enabled"
            $global:DebugFile = "hashgen-ui.log"
            WriteDebugLog -message "No debugger config found, using defaults" -level "INFO"
        }
    }
    catch {
        $errorMsg = "CRITICAL: Failed to load configuration: $($_.Exception.Message)"
        WriteDebugLog -message $errorMsg -level "ERROR"
        GracefulExit -message $errorMsg
    }
    
    return $status
}

# ============================================================================
# FUNCTION: LoadLanguage
# ============================================================================
<#
.DESCRIPTION
    Loads the language pack specified in the configuration.
#>
function LoadLanguage {
    WriteDebugLog -message "Loading language pack: $($global:LangPack)" -level "INFO"
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    $langPath = Join-Path $global:AppPath "data\lang\$($global:LangPack)"
    
    try {
        if (-not (Test-Path $langPath)) {
            # Try fallback to en-us.json
            $langPath = Join-Path $global:AppPath "data\lang\en-us.json"
            
            if (-not (Test-Path $langPath)) {
                $errorMsg = "CRITICAL: No language pack available (not even en-us.json)"
                WriteDebugLog -message $errorMsg -level "ERROR"
                GracefulExit -message $errorMsg
            }
        }
        
        # Load language pack
        $langContent = Get-Content -Path $langPath -Raw -Encoding UTF8
        $global:Language = $langContent | ConvertFrom-Json
        
        WriteDebugLog -message "Language pack loaded successfully" -level "INFO"
    }
    catch {
        $errorMsg = "CRITICAL: Failed to load language pack: $($_.Exception.Message)"
        WriteDebugLog -message $errorMsg -level "ERROR"
        GracefulExit -message $errorMsg
    }
    
    return $status
}

# ============================================================================
# FUNCTION: LoadXAML
# ============================================================================
<#
.DESCRIPTION
    Loads and parses a XAML file for WPF windows.
    
.PARAMETER xamlFile
    The name of the XAML file to load (relative to data\ui\).
#>
function LoadXAML {
    param(
        [Parameter(Mandatory=$true)]
        [string]$xamlFile
    )
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
        xaml = $null
    }
    
    $xamlPath = Join-Path $global:AppPath "data\ui\$xamlFile"
    
    try {
        # Validate path
        $pathCheck = ValidatePath -path $xamlPath -baseDir (Join-Path $global:AppPath "data\ui")
        if ($pathCheck.code -ne 0) {
            $status.code = -1
            $status.msg = "Path validation failed: $($pathCheck.msg)"
            return $status
        }
        
        # Load XAML content
        [xml]$xamlContent = Get-Content -Path $xamlPath -Raw -Encoding UTF8
        
        # Parse XAML
        $reader = New-Object System.Xml.XmlNodeReader $xamlContent
        $status.xaml = [Windows.Markup.XamlReader]::Load($reader)
        
        WriteDebugLog -message "XAML loaded successfully: $xamlFile" -level "DEBUG"
    }
    catch {
        $status.code = -1
        $status.msg = "Failed to load XAML: $($_.Exception.Message)"
        WriteDebugLog -message $status.msg -level "ERROR"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: LoadIconFromDLL
# ============================================================================
<#
.DESCRIPTION
    Extracts an icon from a DLL file (like imageres.dll) and converts it to a BitmapImage.
    
.PARAMETER dllPath
    Path to the DLL file.
    
.PARAMETER iconIndex
    Index of the icon to extract.
#>
function LoadIconFromDLL {
    param(
        [Parameter(Mandatory=$true)]
        [string]$dllPath,
        
        [Parameter(Mandatory=$true)]
        [int]$iconIndex
    )
    
    $status = [PSCustomObject]@{
        code  = 0
        msg   = ""
        image = $null
    }
    
    try {
        Add-Type -AssemblyName System.Drawing
        
        # Check if type already exists before adding
        $typeExists = $null -ne ([System.Management.Automation.PSTypeName]'Win32Functions.IconExtractor').Type
        
        if (-not $typeExists) {
            try {
                Add-Type -MemberDefinition @"
                [DllImport("shell32.dll", CharSet = CharSet.Auto)]
                public static extern IntPtr ExtractIcon(IntPtr hInst, string lpszExeFileName, int nIconIndex);
"@ -Name IconExtractor -Namespace Win32Functions -ErrorAction Stop
                
                WriteDebugLog -message "IconExtractor type added successfully" -level "DEBUG"
            }
            catch {
                $status.code = -1
                $status.msg = "Failed to add IconExtractor type: $($_.Exception.Message)"
                WriteDebugLog -message $status.msg -level "ERROR"
                return $status
            }
        }
        else {
            WriteDebugLog -message "IconExtractor type already exists, skipping Add-Type" -level "DEBUG"
        }
        
        $hIcon = [Win32Functions.IconExtractor]::ExtractIcon([IntPtr]::Zero, $dllPath, $iconIndex)
        
        if ($hIcon -ne [IntPtr]::Zero) {
            $icon = [System.Drawing.Icon]::FromHandle($hIcon)
            $bitmap = $icon.ToBitmap()
            
            # Convert to BitmapImage for WPF
            $memoryStream = New-Object System.IO.MemoryStream
            $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $memoryStream.Position = 0
            
            $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmapImage.BeginInit()
            $bitmapImage.StreamSource = $memoryStream
            $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmapImage.EndInit()
            $bitmapImage.Freeze()
            
            $status.image = $bitmapImage
            
            WriteDebugLog -message "Icon extracted successfully from index $iconIndex" -level "DEBUG"
            
            # Cleanup
            $icon.Dispose()
            $bitmap.Dispose()
        }
        else {
            $status.code = -1
            $status.msg = "Failed to extract icon from DLL"
            WriteDebugLog -message $status.msg -level "WARN"
        }
    }
    catch {
        $status.code = -1
        $status.msg = "Error loading icon: $($_.Exception.Message)"
        WriteDebugLog -message $status.msg -level "ERROR"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: ShowDialogWindow
# ============================================================================
<#
.DESCRIPTION
    Shows a dialog window (info, warning, or error) with a message.
    
.PARAMETER dialogType
    The type of dialog: info, warn, or error.
    
.PARAMETER message
    The message to display.
#>
function ShowDialogWindow {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("info", "warn", "error")]
        [string]$dialogType,
        
        [Parameter(Mandatory=$true)]
        [string]$message
    )
    
    $xamlFile = "hashgen-ui.$dialogType.xaml"
    $xamlResult = LoadXAML -xamlFile $xamlFile
    
    if ($xamlResult.code -ne 0) {
        WriteDebugLog -message "Failed to load dialog XAML: $($xamlResult.msg)" -level "ERROR"
        return
    }
    
    $dialog = $xamlResult.xaml
    
    # Set window title
    $titleKey = $dialogType
    if ($dialogType -eq "warn") {
        $titleKey = "warning"
    }
    $dialog.Title = $global:Language.$titleKey.title
    
    # Get UI elements
    $messageText = $dialog.FindName("$($dialogType.Substring(0,1).ToUpper() + $dialogType.Substring(1))MessageText")
    $icon = $dialog.FindName("$($dialogType.Substring(0,1).ToUpper() + $dialogType.Substring(1))Icon")
    $okButton = $dialog.FindName("OKButton")
    
    # Set message text
    if ($messageText) {
        $messageText.Text = $message
    }
    
    # Load appropriate icon
    $iconIndex = switch ($dialogType) {
        "info"  { 76 }
        "warn"  { 79 }
        "error" { 93 }
    }
    
    $iconResult = LoadIconFromDLL -dllPath "C:\Windows\System32\imageres.dll" -iconIndex $iconIndex
    if ($iconResult.code -eq 0 -and $icon) {
        $icon.Source = $iconResult.image
        
        # Set window icon (title bar icon)
        try {
            $dialog.Icon = $iconResult.image
            WriteDebugLog -message "Window icon set for $dialogType dialog" -level "DEBUG"
        }
        catch {
            WriteDebugLog -message "Failed to set window icon: $($_.Exception.Message)" -level "WARN"
        }
    }
    else {
        WriteDebugLog -message "Failed to load icon for $dialogType dialog: $($iconResult.msg)" -level "WARN"
    }
    
    # Set button text
    if ($okButton) {
        if ($dialogType -eq "warn") {
            $okButton.Content = $global:Language.warning.ok_button
        }
        else {
            $okButton.Content = $global:Language.$titleKey.ok_button
        }
        $okButton.Add_Click({ $dialog.Close() })
    }
    
    # Remove line breaks from message for logging
    $logMessage = $message -replace "`r`n", " " -replace "`n", " "
    WriteDebugLog -message "Showing $dialogType dialog: $logMessage" -level "INFO"
    
    # Show dialog
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
# FUNCTION: ComputeFileHash
# ============================================================================
<#
.DESCRIPTION
    Computes the hash value for a file using the specified algorithm.
    
.PARAMETER filePath
    Path to the file to hash.
    
.PARAMETER algorithm
    The hash algorithm to use (SHA256, SHA384, or SHA512).
#>
function ComputeFileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("SHA256", "SHA384", "SHA512")]
        [string]$algorithm
    )
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
        hash = ""
    }
    
    try {
        # Validate file exists
        if (-not (Test-Path $filePath)) {
            $status.code = -1
            $status.msg = "File not found: $filePath"
            return $status
        }
        
        # Validate path
        $pathCheck = ValidatePath -path $filePath
        if ($pathCheck.code -ne 0) {
            $status.code = -1
            $status.msg = "Path validation failed: $($pathCheck.msg)"
            return $status
        }
        
        # Compute hash
        WriteDebugLog -message "Computing $algorithm hash for: $filePath" -level "INFO"
        $hashResult = Get-FileHash -Path $filePath -Algorithm $algorithm
        $status.hash = $hashResult.Hash
        
        WriteDebugLog -message "Hash computed successfully: $($status.hash)" -level "INFO"
    }
    catch {
        $status.code = -1
        $status.msg = "Hash computation failed: $($_.Exception.Message)"
        WriteDebugLog -message $status.msg -level "ERROR"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: WriteHashToFile
# ============================================================================
<#
.DESCRIPTION
    Writes hash information to an output file.
    
.PARAMETER filePath
    The original file path.
    
.PARAMETER fileName
    The file name.
    
.PARAMETER algorithm
    The hash algorithm used.
    
.PARAMETER hashValue
    The computed hash value.
    
.PARAMETER outputFile
    The output file to write to.
#>
function WriteHashToFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath,
        
        [Parameter(Mandatory=$true)]
        [string]$fileName,
        
        [Parameter(Mandatory=$true)]
        [string]$algorithm,
        
        [Parameter(Mandatory=$true)]
        [string]$hashValue,
        
        [Parameter(Mandatory=$true)]
        [string]$outputFile
    )
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    try {
        $outputPath = Join-Path $global:AppPath "output\$outputFile"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Build output content
        $output = @"
$($global:Language.output_file.file_label) $fileName
$($global:Language.output_file.path_label) $filePath
$($global:Language.output_file.algo_label) $algorithm
$($global:Language.output_file.hash_label) $hashValue
$($global:Language.output_file.created_label) $timestamp
"@
        
        # Write to file (overwrite if exists)
        $output | Out-File -FilePath $outputPath -Encoding UTF8 -Force
        
        WriteDebugLog -message "Hash written to file: $outputPath" -level "INFO"
    }
    catch {
        $status.code = -1
        $status.msg = "Failed to write to output file: $($_.Exception.Message)"
        WriteDebugLog -message $status.msg -level "ERROR"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: ProcessFileList
# ============================================================================
<#
.DESCRIPTION
    Processes a filelist.txt file and generates hashes for all listed files.
    Maintains the original order from filelist.txt in the output JSON.
    
.PARAMETER fileListPath
    Path to the filelist.txt file.
    
.PARAMETER algorithm
    The hash algorithm to use.
#>
function ProcessFileList {
    param(
        [Parameter(Mandatory=$true)]
        [string]$fileListPath,
        
        [Parameter(Mandatory=$true)]
        [string]$algorithm
    )
    
    $status = [PSCustomObject]@{
        code = 0
        msg  = ""
    }
    
    try {
        WriteDebugLog -message "Processing file list: $fileListPath" -level "INFO"
        
        # Read file list
        $fileLines = Get-Content -Path $fileListPath -Encoding UTF8
        
        # Initialize ordered hashtable to maintain order
        $hashOutput = [ordered]@{}
        $fileCounter = 1
        
        # Process each line
        foreach ($line in $fileLines) {
            $line = $line.Trim()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            $fileName = [System.IO.Path]::GetFileName($line)
            
            # Create entry key with counter (Datei 001, Datei 002, etc.)
            $entryKey = "Datei {0:D3}" -f $fileCounter
            
            # Check if file exists
            if (-not (Test-Path $line)) {
                WriteDebugLog -message "File not found in list: $line" -level "WARN"
                
                # Show error dialog WITHOUT path (path logged only)
                ShowDialogWindow -dialogType "error" -message $global:Language.error.file_not_found
                
                # Add error entry to output
                $hashOutput[$entryKey] = @{
                    algo = $algorithm
                    path = $line
                    hash = "error"
                }
                
                $fileCounter++
                continue
            }
            
            # Compute hash
            $hashResult = ComputeFileHash -filePath $line -algorithm $algorithm
            
            if ($hashResult.code -eq 0) {
                # Add successful entry
                $hashOutput[$entryKey] = @{
                    algo = $algorithm
                    path = $line
                    hash = $hashResult.hash
                }
                
                WriteDebugLog -message "Hash computed for: $fileName" -level "INFO"
            }
            else {
                WriteDebugLog -message "Hash failed for: $fileName - $($hashResult.msg)" -level "ERROR"
                
                # Show error dialog
                ShowDialogWindow -dialogType "error" -message "$($global:Language.error.hash_failed)`n$fileName"
                
                # Add error entry
                $hashOutput[$entryKey] = @{
                    algo = $algorithm
                    path = $line
                    hash = "error"
                }
            }
            
            $fileCounter++
        }
        
        # Write output to hash-filelist.json with proper formatting
        $outputPath = Join-Path $global:AppPath "output\hash-filelist.json"
        $hashOutput | ConvertTo-Json -Depth 3 | Out-File -FilePath $outputPath -Encoding UTF8 -Force
        
        WriteDebugLog -message "File list processing completed, output written to hash-filelist.json" -level "INFO"
        
        # Show completion info dialog
        ShowDialogWindow -dialogType "info" -message $global:Language.info.filelist_complete
    }
    catch {
        $status.code = -1
        $status.msg = "File list processing failed: $($_.Exception.Message)"
        WriteDebugLog -message $status.msg -level "ERROR"
    }
    
    return $status
}

# ============================================================================
# FUNCTION: CreateHash
# ============================================================================
<#
.DESCRIPTION
    Main hash creation function. Handles both single files and file lists.
    
.PARAMETER filePath
    The path to the file or filelist.txt (CAN BE EMPTY).
    
.PARAMETER algorithm
    The hash algorithm to use.
#>
function CreateHash {
    param(
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$filePath = "",
        
        [Parameter(Mandatory=$true)]
        [string]$algorithm
    )
    
    WriteDebugLog -message "CreateHash called with filePath: '$filePath' and algorithm: $algorithm" -level "DEBUG"
    
    # Check if file is selected - SHOW WARNING DIALOG
    if ([string]::IsNullOrWhiteSpace($filePath)) {
        WriteDebugLog -message "No file selected by user" -level "WARN"
        ShowDialogWindow -dialogType "warn" -message $global:Language.warning.no_file_selected
        return
    }
    
    # Check if file exists - SHOW ERROR DIALOG WITHOUT PATH
    if (-not (Test-Path $filePath)) {
        WriteDebugLog -message "Selected file not found: $filePath" -level "ERROR"
        ShowDialogWindow -dialogType "error" -message $global:Language.error.file_not_found
        return
    }
    
    # Check if this is a filelist.txt
    $fileName = [System.IO.Path]::GetFileName($filePath)
    if ($fileName -eq "filelist.txt") {
        # Process file list
        ProcessFileList -fileListPath $filePath -algorithm $algorithm
        return
    }
    
    # Compute hash for single file
    $hashResult = ComputeFileHash -filePath $filePath -algorithm $algorithm
    
    if ($hashResult.code -ne 0) {
        # Show ERROR dialog (path is logged, not shown in dialog)
        WriteDebugLog -message "Hash computation failed for: $filePath" -level "ERROR"
        ShowDialogWindow -dialogType "error" -message $global:Language.error.hash_failed
        return
    }
    
    # Check output mode
    if ($global:HashFile -eq "disabled") {
        # Show output in GUI
        $xamlResult = LoadXAML -xamlFile "hashgen-ui.output.xaml"
        
        if ($xamlResult.code -ne 0) {
            ShowDialogWindow -dialogType "error" -message "Failed to load output window"
            return
        }
        
        $outputWindow = $xamlResult.xaml
        $outputWindow.Title = $global:Language.output.title
        
        # Set window icon if appicon.ico exists
        if (Test-Path $global:AppIcon) {
            try {
                $outputWindow.Icon = $global:AppIcon
                WriteDebugLog -message "Output window icon set to: $($global:AppIcon)" -level "DEBUG"
            }
            catch {
                WriteDebugLog -message "Failed to set output window icon: $($_.Exception.Message)" -level "WARN"
            }
        }
        
        # Get UI elements
        $introText = $outputWindow.FindName("OutputIntroText")
        $hashTextBox = $outputWindow.FindName("HashValueTextBox")
        $copyButton = $outputWindow.FindName("CopyButton")
        $closeButton = $outputWindow.FindName("CloseButton")
        
        # Build formatted output (same as file output)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $formattedOutput = @"
$($global:Language.output_file.file_label) $fileName
$($global:Language.output_file.path_label) $filePath
$($global:Language.output_file.algo_label) $algorithm
$($global:Language.output_file.hash_label) $($hashResult.hash)
$($global:Language.output_file.created_label) $timestamp
"@
        
        # Set content
        if ($introText) { $introText.Text = $global:Language.output.intro_text }
        if ($hashTextBox) { $hashTextBox.Text = $formattedOutput }
        
        # Button events
        if ($copyButton) {
            $copyButton.Content = $global:Language.output.copy_button
            $copyButton.Add_Click({
                [System.Windows.Clipboard]::SetText($hashTextBox.Text)
                ShowDialogWindow -dialogType "info" -message $global:Language.info.copied_clipboard
            })
        }
        
        if ($closeButton) {
            $closeButton.Content = $global:Language.output.close_button
            $closeButton.Add_Click({ $outputWindow.Close() })
        }
        
        WriteDebugLog -message "Displaying hash output window" -level "DEBUG"
        
        # Show window
        $outputWindow.ShowDialog() | Out-Null
    }
    else {
        # Write to file
        $writeResult = WriteHashToFile -filePath $filePath -fileName $fileName -algorithm $algorithm -hashValue $hashResult.hash -outputFile $global:HashFile
        
        if ($writeResult.code -eq 0) {
            ShowDialogWindow -dialogType "info" -message $global:Language.info.hash_saved
        }
        else {
            ShowDialogWindow -dialogType "error" -message $global:Language.error.output_write_failed
        }
    }
}

# ============================================================================
# FUNCTION: ShowGUI
# ============================================================================
<#
.DESCRIPTION
    Displays the main GUI window.
#>
function ShowGUI {
    WriteDebugLog -message "Initializing main GUI..." -level "INFO"
    
    # Load main window XAML
    $xamlResult = LoadXAML -xamlFile "hashgen-ui.main.xaml"
    
    if ($xamlResult.code -ne 0) {
        $errorMsg = "CRITICAL: Failed to load main window XAML: $($xamlResult.msg)"
        WriteDebugLog -message $errorMsg -level "ERROR"
        GracefulExit -message $errorMsg
    }
    
    $mainWindow = $xamlResult.xaml
    
    # Set window title
    $mainWindow.Title = "$($global:Language.app.title) $($global:Language.app.version)"
    
    # Set window icon if appicon.ico exists
    if (Test-Path $global:AppIcon) {
        try {
            $mainWindow.Icon = $global:AppIcon
            WriteDebugLog -message "Main window icon set to: $($global:AppIcon)" -level "DEBUG"
        }
        catch {
            WriteDebugLog -message "Failed to set main window icon: $($_.Exception.Message)" -level "WARN"
        }
    }
    else {
        WriteDebugLog -message "appicon.ico not found at: $($global:AppIcon)" -level "DEBUG"
    }
    
    # Get UI elements
    $introText = $mainWindow.FindName("IntroText")
    $filePathTextBox = $mainWindow.FindName("FilePathTextBox")
    $browseButton = $mainWindow.FindName("BrowseButton")
    $algoLabel = $mainWindow.FindName("AlgoLabel")
    $algoComboBox = $mainWindow.FindName("AlgoComboBox")
    $generateButton = $mainWindow.FindName("GenerateButton")
    $exitButton = $mainWindow.FindName("ExitButton")
    
    # Set localized text
    if ($introText) { $introText.Text = $global:Language.main.intro_text }
    if ($browseButton) { $browseButton.Content = $global:Language.main.browse_button }
    if ($algoLabel) { $algoLabel.Text = $global:Language.main.algo_label }
    if ($generateButton) { $generateButton.Content = $global:Language.main.generate_button }
    if ($exitButton) { $exitButton.Content = $global:Language.main.exit_button }
    
    # Browse button click event
    if ($browseButton) {
        $browseButton.Add_Click({
            Add-Type -AssemblyName System.Windows.Forms
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "All Files (*.*)|*.*"
            $openFileDialog.Title = "Select a file"
            
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $filePathTextBox.Text = $openFileDialog.FileName
                WriteDebugLog -message "File selected: $($openFileDialog.FileName)" -level "DEBUG"
            }
        })
    }
    
    # Generate button click event
    if ($generateButton) {
        $generateButton.Add_Click({
            $selectedFile = $filePathTextBox.Text
            $selectedAlgo = $algoComboBox.SelectedItem.Content
            
            CreateHash -filePath $selectedFile -algorithm $selectedAlgo
        })
    }
    
    # Exit button click event
    if ($exitButton) {
        $exitButton.Add_Click({
            WriteDebugLog -message "Application closed by user" -level "INFO"
            $mainWindow.Close()
        })
    }
    
    # Show main window
    WriteDebugLog -message "Displaying main window" -level "INFO"
    $mainWindow.ShowDialog() | Out-Null
}

# ============================================================================
# FUNCTION: MainWorker
# ============================================================================
<#
.DESCRIPTION
    Main application workflow function that coordinates the startup sequence.
#>
function MainWorker {
    # Hide console window FIRST and log directly (before config is loaded)
    $hideResult = HideConsoleWin
    if ($hideResult.code -eq 0) {
        WriteDebugLogDirect -message "Console window hidden successfully" -level "DEBUG"
    }
    elseif ($hideResult.code -eq 1) {
        WriteDebugLogDirect -message "HideConsoleWin: $($hideResult.msg)" -level "WARN"
    }
    else {
        WriteDebugLogDirect -message "HideConsoleWin failed: $($hideResult.msg)" -level "ERROR"
    }
    
    # Perform system check
    PerformSysCheck | Out-Null
    
    # Load configuration (this sets up $global:DebugMode and $global:DebugFile)
    LoadAppConfig | Out-Null
    
    # Load language pack
    LoadLanguage | Out-Null
    
    # Show main GUI
    ShowGUI
}

# ============================================================================
# APPLICATION ENTRY POINT
# ============================================================================

# Load required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Start application
MainWorker