# Context Menu Switcher
# A PowerShell script to toggle between Windows 11 and classic context menu
# Version: 1.00.01
# Author: Praetoriani
# Date: 2025-10-04

<#
.SYNOPSIS
    Context Menu Switcher - Toggle between Windows 11 and classic context menu

.DESCRIPTION
    This PowerShell script allows you to switch between the new Windows 11 context menu
    and the classic Windows 10 context menu by manipulating the Windows Registry.
    The script supports parameters for automated deployment and includes language pack support.
    Compatible with PowerShell 5.1 and higher.

.PARAMETER PopupMenu
    Specifies which context menu style to activate
    Valid values: "classic", "new"
    Default: "new"

.PARAMETER LangPack
    Specifies the language pack file to use for text output
    Default: "en-us.json"

.EXAMPLE
    .\Context-Menu-Switcher.ps1 -PopupMenu classic
    Activates the classic Windows 10 context menu

.EXAMPLE
    .\Context-Menu-Switcher.ps1 -PopupMenu new
    Activates the Windows 11 context menu

.EXAMPLE
    .\Context-Menu-Switcher.ps1 -PopupMenu classic -LangPack en-us.json
    Activates classic menu with specific language pack

.NOTES
    - Requires Administrator privileges for registry modification
    - Compatible with Windows 11 all versions
    - Compatible with PowerShell 5.1 and higher
    - Explorer restart is required for changes to take effect
#>

# Script parameters
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("classic", "new", "")]
    [string]$PopupMenu = "",
    
    [Parameter(Mandatory=$false)]
    [string]$LangPack = "en-us.json"
)

# Global variables initialization
$global:ContextMenuStyle = "new"  # Default value
$global:LangPack = "en-us.json"   # Default language pack

# Registry path for context menu modification
$global:RegistryPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
$global:RegistrySubPath = "InprocServer32"

# Language pack storage
$global:Messages = @{}

# Function to detect PowerShell version and provide compatibility
function Get-PowerShellVersion {
    return $PSVersionTable.PSVersion.Major
}

# Function to convert JSON to hashtable with PowerShell 5.1 compatibility
function ConvertFrom-JsonToHashtable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$JsonString
    )
    
    # PowerShell 6.0 and higher support -AsHashtable parameter
    if ((Get-PowerShellVersion) -ge 6) {
        return $JsonString | ConvertFrom-Json -AsHashtable
    }
    else {
        # PowerShell 5.1 fallback: Convert to PSCustomObject first, then to hashtable
        $jsonObject = $JsonString | ConvertFrom-Json
        $hashtable = @{}
        
        # Convert PSCustomObject properties to hashtable entries
        $jsonObject.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = $_.Value
        }
        
        return $hashtable
    }
}

# Function to load language pack from JSON file
function Load-LanguagePack {
    param(
        [string]$LanguageFile
    )
    
    try {
        # Get the directory where the script is located
        $ScriptDirectory = Split-Path -Parent $MyInvocation.ScriptName
        $LanguageFilePath = Join-Path -Path $ScriptDirectory -ChildPath $LanguageFile
        
        # Check if language file exists
        if (Test-Path $LanguageFilePath) {
            # Load JSON content and convert to hashtable with version compatibility
            $JsonContent = Get-Content -Path $LanguageFilePath -Raw -Encoding UTF8
            $global:Messages = ConvertFrom-JsonToHashtable -JsonString $JsonContent
            return $true
        }
        else {
            # Language file not found - use fallback messages
            Initialize-FallbackMessages
            Write-Host $global:Messages.language_file_not_found -ForegroundColor DarkRed
            return $false
        }
    }
    catch {
        # Error loading language pack - use fallback messages and show error
        Initialize-FallbackMessages
        Write-Host "$($global:Messages.language_pack_error) $($_.Exception.Message)" -ForegroundColor DarkRed
        return $false
    }
}

# Function to initialize fallback messages when language pack fails to load
function Initialize-FallbackMessages {
    $global:Messages = @{
        script_title = "Context Menu Switcher"
        script_running = "Running Context Menu Switcher..."
        wrong_param = "Wrong parameter found! Using default value."
        classic_activated = "Classic Context Menu activated successfully!"
        windows11_activated = "Windows 11 Context Menu activated successfully!"
        script_finished = "Context Menu Switcher finished."
        registry_error = "Error modifying registry:"
        explorer_restart_required = "Explorer restart required for changes to take effect."
        explorer_restarting = "Restarting Windows Explorer..."
        explorer_restarted = "Windows Explorer restarted successfully."
        current_style = "Current Context Menu Style:"
        switching_to_classic = "Switching to Classic Context Menu..."
        switching_to_windows11 = "Switching to Windows 11 Context Menu..."
        registry_key_created = "Registry key created successfully."
        registry_key_deleted = "Registry key deleted successfully."
        language_pack_loaded = "Language pack loaded successfully."
        language_file_not_found = "Language file not found. Using default English messages."
        language_pack_error = "Error loading language pack:"
        admin_rights_required = "Administrator rights required for registry modification."
        operation_completed = "Operation completed successfully."
    }
}

# Function to check if script is running with administrator privileges
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to restart Windows Explorer process
function Restart-Explorer {
    try {
        Write-Host $global:Messages.explorer_restarting -ForegroundColor White
        
        # Stop Explorer process
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        
        # Wait a moment for process to terminate
        Start-Sleep -Seconds 2
        
        # Start Explorer again
        Start-Process "explorer.exe"
        
        Write-Host $global:Messages.explorer_restarted -ForegroundColor White
    }
    catch {
        Write-Host "$($global:Messages.registry_error) $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# Function to activate classic context menu
function Enable-ClassicContextMenu {
    try {
        Write-Host $global:Messages.switching_to_classic -ForegroundColor White
        
        # Create registry key if it doesn't exist
        if (-not (Test-Path $global:RegistryPath)) {
            New-Item -Path $global:RegistryPath -Force | Out-Null
            Write-Host $global:Messages.registry_key_created -ForegroundColor White
        }
        
        # Create InprocServer32 subkey with empty default value
        $SubkeyPath = Join-Path -Path $global:RegistryPath -ChildPath $global:RegistrySubPath
        New-Item -Path $SubkeyPath -Force | Out-Null
        Set-ItemProperty -Path $SubkeyPath -Name "(Default)" -Value "" -Force
        
        Write-Host $global:Messages.classic_activated -ForegroundColor White
        
        # Set global variable
        $global:ContextMenuStyle = "classic"
        
        return $true
    }
    catch {
        Write-Host "$($global:Messages.registry_error) $($_.Exception.Message)" -ForegroundColor DarkRed
        return $false
    }
}

# Function to activate Windows 11 context menu
function Enable-Windows11ContextMenu {
    try {
        Write-Host $global:Messages.switching_to_windows11 -ForegroundColor White
        
        # Remove registry key if it exists
        if (Test-Path $global:RegistryPath) {
            Remove-Item -Path $global:RegistryPath -Recurse -Force
            Write-Host $global:Messages.registry_key_deleted -ForegroundColor White
        }
        
        Write-Host $global:Messages.windows11_activated -ForegroundColor White
        
        # Set global variable
        $global:ContextMenuStyle = "new"
        
        return $true
    }
    catch {
        Write-Host "$($global:Messages.registry_error) $($_.Exception.Message)" -ForegroundColor DarkRed
        return $false
    }
}

# Function to validate and process parameters
function Process-Parameters {
    param(
        [string]$MenuStyle,
        [string]$LanguageFile
    )
    
    # Set language pack variable
    $global:LangPack = $LanguageFile
    
    # Validate PopupMenu parameter
    if ($MenuStyle -eq "classic" -or $MenuStyle -eq "new") {
        $global:ContextMenuStyle = $MenuStyle
    }
    else {
        # Invalid parameter - use default and show warning
        if ($MenuStyle -ne "") {
            Write-Host $global:Messages.wrong_param -ForegroundColor White
        }
        $global:ContextMenuStyle = "new"  # Default value
    }
}

# Main script execution
function Main {
    # Initialize fallback messages first (in case language pack fails)
    Initialize-FallbackMessages
    
    # Display script header first
    Write-Host $global:Messages.script_title -ForegroundColor White
    Write-Host $("*" * 50) -ForegroundColor White
    
    # Load language pack and show messages after header
    $languageLoadSuccess = Load-LanguagePack -LanguageFile $LangPack
    
    # Show language pack success message only if it loaded successfully
    if ($languageLoadSuccess) {
        Write-Host $global:Messages.language_pack_loaded -ForegroundColor White
    }
    
    Write-Host $global:Messages.script_running -ForegroundColor White
    
    # Check administrator rights
    if (-not (Test-AdminRights)) {
        Write-Host $global:Messages.admin_rights_required -ForegroundColor DarkRed
        exit 1
    }
    
    # Process parameters
    Process-Parameters -MenuStyle $PopupMenu -LanguageFile $LangPack
    
    # Display current operation
    Write-Host "$($global:Messages.current_style) $($global:ContextMenuStyle)" -ForegroundColor White
    
    # Execute the appropriate function based on ContextMenuStyle
    $operationSuccess = $false
    
    if ($global:ContextMenuStyle -eq "classic") {
        $operationSuccess = Enable-ClassicContextMenu
    }
    else {
        $operationSuccess = Enable-Windows11ContextMenu
    }
    
    # Restart Explorer if operation was successful
    if ($operationSuccess) {
        Write-Host $global:Messages.explorer_restart_required -ForegroundColor White
        Restart-Explorer
        Write-Host $global:Messages.operation_completed -ForegroundColor White
    }
    
    # Display completion message
    Write-Host $("*" * 50) -ForegroundColor White
    Write-Host $global:Messages.script_finished -ForegroundColor White
}

# Execute main function
Main