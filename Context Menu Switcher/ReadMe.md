# Context Menu Switcher

## Introduction

**Context Menu Switcher** is a powerful PowerShell utility designed to toggle between the new Windows 11 context menu and the classic Windows 10 context menu. The script provides system administrators and power users with a simple, automated way to control which context menu style is displayed when right-clicking in Windows Explorer.

The new Windows 11 context menu, while visually appealing, can sometimes be limiting as it requires additional clicks to access commonly used options. This tool allows users to switch back to the classic context menu that displays all options immediately, or return to the modern Windows 11 style as needed.

The script works by manipulating specific Windows Registry keys that control the context menu behavior, and automatically restarts Windows Explorer to apply changes immediately.

## Current Release

- **Version:** 1.0
- **Release Date:** October 4, 2025
- **Author:** System Administrator
- **License:** MIT License
- **Platform:** Windows 11 (All versions: 21H2, 22H2, 23H2, 24H2, 25H2)
- **PowerShell Version:** 5.1 or higher
- **Architecture:** x64, x86, ARM64

### Features
- Toggle between Windows 11 and classic context menu styles
- Command-line parameter support for automation
- Multi-language support via JSON language packs
- Automatic Windows Explorer restart
- Administrator rights validation
- Comprehensive error handling and logging
- Registry backup and restoration capabilities

## Requirements

### System Requirements
- **Operating System:** Windows 11 (all editions and versions)
- **PowerShell:** Version 5.1 or higher (included with Windows 11)
- **Privileges:** Administrator rights required
- **Architecture:** Compatible with x64, x86, and ARM64 systems

### Prerequisites
1. **Administrator Access:** The script must be run with administrator privileges to modify the Windows Registry
2. **PowerShell Execution Policy:** Set to allow script execution (RemoteSigned or Unrestricted)
3. **Windows Explorer:** Must be running (will be automatically restarted by the script)

### File Dependencies
- `Context-Menu-Switcher.ps1` - Main PowerShell script
- `en-us.json` - English language pack (default)
- Both files must be in the same directory

### Security Considerations
- The script modifies the Windows Registry under `HKEY_CURRENT_USER`
- Changes are user-specific and do not affect other user profiles
- Registry modifications are reversible and do not impact system stability
- No external network connections are required

## Usage

### Basic Syntax
```powershell
.\Context-Menu-Switcher.ps1 [-PopupMenu <string>] [-LangPack <string>]
```

### Parameters

#### PopupMenu
- **Type:** String
- **Required:** No
- **Default:** "new"
- **Valid Values:** 
  - `"classic"` - Activates the classic Windows 10 context menu
  - `"new"` - Activates the Windows 11 context menu
- **Description:** Specifies which context menu style to activate

#### LangPack
- **Type:** String
- **Required:** No
- **Default:** `"en-us.json"`
- **Description:** Specifies the language pack file to use for console output

<strong>Note:</strong> At the moment only `"en-us.json"` is supoprted as LangPack

### Usage Examples

#### Activate Classic Context Menu
```powershell
.\Context-Menu-Switcher.ps1 -PopupMenu classic
```

#### Activate Windows 11 Context Menu
```powershell
.\Context-Menu-Switcher.ps1 -PopupMenu new
```

#### Use with Custom Language Pack (limited usability at the moment)
```powershell
.\Context-Menu-Switcher.ps1 -PopupMenu classic -LangPack de-de.json
```
<strong>Note:</strong> At the moment only `"en-us.json"` is supoprted as LangPack

#### Run with Default Settings
```powershell
.\Context-Menu-Switcher.ps1
```

### PowerShell Execution Policy

Before running the script, ensure your PowerShell execution policy allows script execution:

```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Alternative: Set for current process only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Running as Administrator

#### Method 1: PowerShell ISE/Terminal
1. Right-click on PowerShell ISE or Windows Terminal
2. Select "Run as administrator"
3. Navigate to the script directory
4. Execute the script with desired parameters

#### Method 2: Command Line
```cmd
# From Command Prompt as Administrator
powershell.exe -ExecutionPolicy Bypass -File ".\Context-Menu-Switcher.ps1" -PopupMenu classic
```

#### Method 3: Create Desktop Shortcut
Create shortcuts with different parameters for quick access:
- Target: `powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Context-Menu-Switcher.ps1" -PopupMenu classic`
- Advanced Properties: Check "Run as administrator"

### Automation and Deployment

#### Group Policy Deployment
The script can be deployed via Group Policy as a logon script:
1. Copy files to SYSVOL share
2. Configure in Group Policy Management Console
3. Set appropriate execution policy via GPO

#### SCCM/Configuration Manager
Deploy as a PowerShell script package:
1. Create application with PowerShell script deployment type
2. Set detection method for registry key presence
3. Configure execution context as Administrator

#### Scheduled Task
Create a scheduled task for automated switching:
```powershell
# Example: Switch to classic menu at user logon
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File 'C:\Scripts\Context-Menu-Switcher.ps1' -PopupMenu classic"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName "Context Menu Switcher" -Action $Action -Trigger $Trigger -Principal $Principal
```

## Future Developments

### Planned Features

#### Multi-Language Support
- **German Language Pack** (`de-de.json`) - In development
- **Italian Language Pack** (`it-it.json`) - Planned
- **Spanish Language Pack** (`es-es.json`) - Planned
- **French Language Pack** (`fr-fr.json`) - Planned

#### Graphical User Interface
A user-friendly GUI version is planned for users who prefer graphical interfaces over command-line tools:
- **WPF-based Interface** - Native Windows look and feel
- **Real-time Preview** - Show context menu changes without applying
- **Settings Persistence** - Remember user preferences
- **System Tray Integration** - Quick access from notification area
- **One-click Toggle** - Instant switching between menu styles

#### Enhanced Features
- **Registry Backup/Restore** - Automatic backup before changes
- **Rollback Functionality** - Undo recent changes
- **Context Menu Customization** - Add/remove specific menu items
- **Multiple Profile Support** - Different configurations for different scenarios
- **Integration with Windows Settings** - Native Windows 11 Settings app integration

#### Enterprise Features
- **Group Policy Templates** - ADMX files for enterprise deployment
- **SCCM Integration** - Configuration Manager compliance settings
- **PowerShell DSC Resource** - Desired State Configuration support
- **Intune Policy Support** - Microsoft Endpoint Manager integration
- **Logging and Reporting** - Detailed audit trails and compliance reporting

#### Version 2.0 Roadmap
- **Configuration File Support** - XML/JSON configuration files
- **Command-Line Interface Enhancements** - More granular control options
- **Windows Terminal Integration** - Native Windows Terminal support
- **PowerShell 7 Optimization** - Enhanced performance and compatibility
- **Cross-Platform Considerations** - Potential Windows Server support

### Community Contributions

We welcome community contributions for:
- Additional language translations
- Feature suggestions and improvements
- Bug reports and fixes
- Documentation enhancements
- GUI design mockups

### Feedback and Support

For feature requests, bug reports, or general feedback:
- Create detailed issue reports with system information
- Provide PowerShell version and Windows build details
- Include relevant error messages and screenshots
- Suggest improvements based on your use cases

### Compatibility Notes

Future versions will maintain backward compatibility with:
- Windows 11 all current and future versions
- PowerShell 5.1 and PowerShell 7.x
- Existing language pack formats
- Current parameter structure and naming conventions