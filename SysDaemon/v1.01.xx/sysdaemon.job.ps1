<#
.SYNOPSIS
 SysDaemon Job Script - Executes system maintenance tasks under SYSTEM privileges
 
.DESCRIPTION
 This script is executed by the SysDaemon scheduled task running under SYSTEM context.
 It performs system-level maintenance operations with enhanced security features
 including integrity validation, secure logging, and controlled execution environment.
 
.NOTES
 Creation Date: 04.10.2025
 Last Update: 06.10.2025
 Version: 1.01.00
 Author: Praetoriani
 Website: https://github.com/praetoriani
 
 Security Features:
 - Self-integrity validation before execution
 - Secure execution environment setup
 - Comprehensive audit logging
 - Error handling with security context
 - Automatic cleanup and resource management
 
 Execution Context:
 - Runs under SYSTEM account with full privileges
 - No user interaction or console output
 - All operations logged to sysdaemon.job.log
 - UTF-8 BOM encoding for international character support
#>

# Global version variable for consistency with main daemon
$Global:SysDaemonJobVersion = "1.01.00"

# Initialize secure execution environment
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "sysdaemon.job.log"

function Write-JobLogEntry {
 <#
 .SYNOPSIS
 Writes timestamped log entries for job operations
 
 .DESCRIPTION
 Creates standardized log entries for job execution with enhanced security
 features including sensitive data sanitization and structured logging.
 
 .PARAMETER Message
 The log message content to write
 
 .PARAMETER Level
 Severity level: INFO, WARN, ERROR, or DEBUG
 #>
 param(
 [Parameter(Mandatory=$true)]
 [string]$Message,
 
 [Parameter(Mandatory=$false)]
 [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
 [string]$Level = "INFO"
 )
 
 # Sanitize message to remove sensitive data patterns
 $sanitizedMessage = $Message
 $sensitivePatterns = @(
 '(?i)(password|pwd|secret|key|token)\s*[=:]\s*[^\s]+',
 '(?i)(username|user|login)\s*[=:]\s*[^\s]+',
 '[A-Za-z0-9+/]{20,}={0,2}', # Base64 patterns
 '\$\([^)]+\)' # PowerShell variable expansion
 )
 
 foreach ($pattern in $sensitivePatterns) {
 $sanitizedMessage = $sanitizedMessage -replace $pattern, '[REDACTED]'
 }
 
 $timestamp = Get-Date -Format "yyyy.MM.dd - HH:mm:ss"
 $formattedLevel = switch ($Level) {
 "INFO" { "[INFO] " }
 "WARN" { "[WARN] " }
 "ERROR" { "[ERROR]" }
 "DEBUG" { "[DEBUG]" }
 }
 
 $logEntry = "[$timestamp] $formattedLevel $sanitizedMessage"
 
 try {
 Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
 } catch {
 # Silently ignore logging failures to prevent job interruption
 }
}

function Test-JobExecutionSecurity {
 <#
 .SYNOPSIS
 Validates job execution environment security
 
 .DESCRIPTION
 Performs security checks to ensure the job is running in a safe environment
 with proper privileges and security context.
 
 .OUTPUTS
 System.Boolean - True if environment is secure, False otherwise
 #>
 
 try {
 # Verify execution context
 $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
 $principal = [System.Security.Principal.WindowsPrincipal]::new($currentUser)
 
 if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
 Write-JobLogEntry "Job is not running with administrative privileges" "ERROR"
 return $false
 }
 
 # Verify SYSTEM context
 if ($currentUser.Name -ne "NT AUTHORITY\SYSTEM") {
 Write-JobLogEntry "WARNING: Job is not running under SYSTEM account: $($currentUser.Name)" "WARN"
 }
 
 # Verify script integrity if hash file exists
 $scriptPath = $MyInvocation.MyCommand.Path
 $hashFilePath = "$scriptPath.sha256"
 
 if (Test-Path $hashFilePath) {
 try {
 $expectedHash = Get-Content $hashFilePath -Raw -ErrorAction Stop | Where-Object { $_ -match '^[A-Fa-f0-9]{64}$' }
 if ($expectedHash) {
 $actualHash = Get-FileHash $scriptPath -Algorithm SHA256
 if ($actualHash.Hash -ne $expectedHash.Trim()) {
 Write-JobLogEntry "CRITICAL: Job script integrity check failed - Hash mismatch" "ERROR"
 return $false
 }
 Write-JobLogEntry "Job script integrity verified successfully" "DEBUG"
 } else {
 Write-JobLogEntry "Invalid SHA256 hash format in integrity file" "WARN"
 }
 } catch {
 Write-JobLogEntry "Error reading job script hash file: $($_.Exception.Message)" "WARN"
 }
 }
 
 Write-JobLogEntry "Job execution environment security validation passed" "DEBUG"
 return $true
 
 } catch {
 Write-JobLogEntry "Critical error during security validation: $($_.Exception.Message)" "ERROR"
 return $false
 }
}

# ================================================================================
# JOB INITIALIZATION AND SECURITY VALIDATION
# ================================================================================

# Initialize job log file
try {
 if (Test-Path $LogFile) {
 # Rotate log file if it gets too large (>5MB)
 $logFileInfo = Get-Item $LogFile
 if ($logFileInfo.Length -gt 5MB) {
 $backupLogFile = "$LogFile.backup"
 if (Test-Path $backupLogFile) {
 Remove-Item $backupLogFile -Force
 }
 Move-Item $LogFile $backupLogFile -Force
 New-Item -Path $LogFile -ItemType File -Force | Out-Null
 Write-JobLogEntry "Log file rotated due to size limit" "INFO"
 }
 } else {
 New-Item -Path $LogFile -ItemType File -Force | Out-Null
 }
} catch {
 # Cannot proceed without logging capability
 exit 1
}

Write-JobLogEntry "SysDaemon Job Script v$Global:SysDaemonJobVersion - Execution Started" "INFO"
Write-JobLogEntry "Script Directory: $ScriptDir" "DEBUG"
Write-JobLogEntry "Log File: $LogFile" "DEBUG"

# Perform security validation before executing job tasks
if (-not (Test-JobExecutionSecurity)) {
 Write-JobLogEntry "Job execution aborted due to security validation failure" "ERROR"
 exit 1
}

# ================================================================================
# MAIN JOB EXECUTION LOGIC
# ================================================================================

try {
 Write-JobLogEntry "Beginning system maintenance tasks" "INFO"
 
 # Example system maintenance tasks - customize as needed
 
 # Task 1: System file cleanup
 Write-JobLogEntry "Starting system file cleanup" "DEBUG"
 try {
 $tempPaths = @(
 "$env:TEMP\*",
 "$env:WINDIR\Temp\*",
 "$env:LOCALAPPDATA\Temp\*"
 )
 
 $totalFilesRemoved = 0
 $totalSpaceReclaimed = 0
 
 foreach ($tempPath in $tempPaths) {
 if (Test-Path (Split-Path $tempPath -Parent)) {
 $tempFiles = Get-ChildItem $tempPath -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
 foreach ($file in $tempFiles) {
 try {
 $fileSize = $file.Length
 Remove-Item $file.FullName -Recurse -Force -ErrorAction Stop
 $totalFilesRemoved++
 $totalSpaceReclaimed += $fileSize
 } catch {
 Write-JobLogEntry "Could not remove file: $($file.FullName) - $($_.Exception.Message)" "WARN"
 }
 }
 }
 }
 
 $spaceReclaimedMB = [math]::Round($totalSpaceReclaimed / 1MB, 2)
 Write-JobLogEntry "System cleanup completed: $totalFilesRemoved files removed, $spaceReclaimedMB MB reclaimed" "INFO"
 
 } catch {
 Write-JobLogEntry "Error during system cleanup: $($_.Exception.Message)" "ERROR"
 }
 
 # Task 2: Event log maintenance
 Write-JobLogEntry "Starting event log maintenance" "DEBUG"
 try {
 $eventLogs = @("Application", "System", "Security")
 foreach ($logName in $eventLogs) {
 try {
 $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
 if ($log.RecordCount -gt 10000) {
 # Log is getting large - this is just informational
 Write-JobLogEntry "Event log '$logName' has $($log.RecordCount) records" "INFO"
 }
 } catch {
 Write-JobLogEntry "Could not access event log '$logName': $($_.Exception.Message)" "WARN"
 }
 }
 Write-JobLogEntry "Event log maintenance completed" "DEBUG"
 } catch {
 Write-JobLogEntry "Error during event log maintenance: $($_.Exception.Message)" "ERROR"
 }
 
 # Task 3: System health check
 Write-JobLogEntry "Performing system health check" "DEBUG"
 try {
 # Check disk space
 $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
 foreach ($drive in $drives) {
 $freeSpacePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)
 if ($freeSpacePercent -lt 10) {
 Write-JobLogEntry "WARNING: Drive $($drive.DeviceID) has only $freeSpacePercent% free space" "WARN"
 } else {
 Write-JobLogEntry "Drive $($drive.DeviceID) has $freeSpacePercent% free space" "DEBUG"
 }
 }
 
 # Check system uptime
 $bootTime = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
 $bootDateTime = [Management.ManagementDateTimeConverter]::ToDateTime($bootTime)
 $uptime = (Get-Date) - $bootDateTime
 Write-JobLogEntry "System uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" "INFO"
 
 Write-JobLogEntry "System health check completed" "DEBUG"
 } catch {
 Write-JobLogEntry "Error during system health check: $($_.Exception.Message)" "ERROR"
 }
 
 Write-JobLogEntry "All system maintenance tasks completed successfully" "INFO"
 
} catch {
 Write-JobLogEntry "Critical error during job execution: $($_.Exception.Message)" "ERROR"
 Write-JobLogEntry "Detailed error information: $($_.Exception.ToString())" "ERROR"
 exit 1
}

# ================================================================================
# JOB COMPLETION AND CLEANUP
# ================================================================================

Write-JobLogEntry "SysDaemon Job Script execution completed successfully" "INFO"
Write-JobLogEntry "Job finished at: $(Get-Date -Format 'yyyy.MM.dd - HH:mm:ss')" "DEBUG"

# Exit with success code
exit 0
