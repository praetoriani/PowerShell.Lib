# 🔧 SysDaemon

A comprehensive PowerShell-based system daemon for managing Windows scheduled tasks with multilingual support and enterprise-grade security features.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.00.10-brightgreen.svg)](CHANGELOG.md)

## 📋 What is SysDaemon?

**SysDaemon** is a professional-grade PowerShell framework designed to simplify the creation and management of Windows scheduled tasks that run under SYSTEM context. It provides a command-line interface for creating, executing, and terminating system-level automation tasks with comprehensive logging and multilingual support.

### 🎯 Key Features

- **🔐 SYSTEM Context Execution**: Tasks run with full system privileges
- **🌍 Multilingual Support**: English and German language packs included
- **🛡️ Security-First Design**: Automatic task disabling after operations
- **📊 Comprehensive Logging**: Detailed UTF-8 log files with severity levels  
- **🔧 COM-Based Operations**: Robust task scheduler manipulation
- **⚡ Zero-Console Operation**: Silent background execution
- **📖 Enterprise Documentation**: Complete inline code documentation
- **🔒 Complete Silent Validation**: No console errors, all parameter validation logged

## 🚀 What can SysDaemon be used for?

SysDaemon is perfect for creating **system-level automation tasks** that need to run without user interaction:

- **🔄 System Maintenance**: Automated cleanup, updates, and monitoring
- **📁 File Operations**: Bulk file processing, synchronization, archiving
- **🗄️ Database Tasks**: Cleanup routines, backups, data processing
- **🔒 Security Operations**: Log analysis, compliance checks, monitoring
- **☁️ Cloud Integration**: API calls, data synchronization, reporting
- **📈 Monitoring & Alerts**: Health checks, performance monitoring
- **🔧 Configuration Management**: Automated system configuration updates

## 💻 System Requirements

### Prerequisites
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher (PowerShell 7+ supported)
- **Privileges**: Administrator rights required for setup
- **Services**: Windows Task Scheduler service must be running

### Dependencies
- `.NET Framework 4.7.2+` (typically pre-installed)
- `Task Scheduler Service` (enabled by default)
- `XML Template File` (RunSystemJob.xml - provided separately)

## 📦 Current Version

**Version 1.00.10** - Stable Release  
*Released: October 5, 2025*

This version includes **complete silent parameter validation** with manual `$args` processing to eliminate ALL console error messages while providing comprehensive error logging.

## 🌐 Supported Languages

| Language | Code | File | Status |
|----------|------|------|--------|
| English (US) | `en-us` | `en-us.json` | ✅ Complete |
| German (DE) | `de-de` | `de-de.json` | ✅ Complete |
| Italian (IT) | `it-it` | `it-it.json` | 🔄 Planned |
| French (FR) | `fr-fr` | `fr-fr.json` | 🔄 Planned |
| Spanish (ES) | `es-es` | `es-es.json` | 🔄 Planned |

## 🛠️ How SysDaemon Works

### Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  User Command   │───▶│  sysdaemon.main  │───▶│ Windows Task    │
│  (PowerShell)   │    │  (Management)    │    │ Scheduler       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Language Pack   │    │ sysdaemon.job   │
                       │  (Localization)  │    │ (Your Script)   │
                       └──────────────────┘    └─────────────────┘
```

### Core Components

1. **`sysdaemon.main.ps1`** - Management interface and task orchestration
2. **`sysdaemon.job.ps1`** - Your custom automation script (**customize this!**)
3. **`en-us.json` / `de-de.json`** - Language packs for localized output
4. **`RunSystemJob.xml`** - Task Scheduler XML template (required)

### Workflow Process

1. **Setup**: Create scheduled task from XML template
2. **Execution**: Run your custom script under SYSTEM context
3. **Security**: Automatically disable task after execution
4. **Cleanup**: Remove tasks and empty folders when done

## 🎮 Usage Examples

### Basic Operations

```powershell
# Create a new scheduled task (English)
.\sysdaemon.main.ps1 -axn "add-job"

# Create a new scheduled task (German)
.\sysdaemon.main.ps1 -axn "add-job" -LangPack "de-de.json"

# Execute the task once
.\sysdaemon.main.ps1 -axn "exec-job"

# Terminate and disable the task
.\sysdaemon.main.ps1 -axn "kill-job"

# Delete the task completely
.\sysdaemon.main.ps1 -axn "del-job"
```

### Advanced Usage

```powershell
# Execute with German localization and logging
.\sysdaemon.main.ps1 -axn "exec-job" -LangPack "de-de.json"

# Parameter order doesn't matter
.\sysdaemon.main.ps1 -LangPack "de-de.json" -axn "add-job"

# Check log file for execution details
Get-Content .\sysdaemon.main.log -Tail 20

# Verify task creation
Get-ScheduledTask -TaskPath "\sysdaemon\" -TaskName "RunSystemJob"
```

## ⚙️ Configuration

### Customizing Your Job Script

**⚠️ IMPORTANT**: The provided `sysdaemon.job.ps1` is only a demo! You **must** customize it:

```powershell
# Replace the demo content in sysdaemon.job.ps1 with your tasks:

# Example: File cleanup task
Get-ChildItem "C:\Temp" -Recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item -Force

# Example: Database maintenance
Invoke-SqlCmd -Query "EXEC sp_UpdateStats" -ServerInstance "localhost"

# Example: System monitoring
$services = Get-Service | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'}
if ($services) {
    # Send alert or restart services
}
```

### Language Pack Structure

Create custom language packs by following this JSON structure:

```json
{
    "StartupMessage": "SysDaemon v{0} started successfully",
    "ErrorMissingAction": "Missing required parameter 'axn'",
    "TaskCreatedSuccessfully": "Scheduled task created successfully"
}
```

## 🔒 Parameter Validation & Security

### ⚠️ **CRITICAL: Complete Silent Parameter Validation**

**SysDaemon v1.00.10** implements **revolutionary silent parameter validation** that completely eliminates PowerShell's built-in console error messages:

#### ✅ **Technical Solution**
- **Manual `$args` Processing**: Bypasses PowerShell's built-in parameter binding
- **No `param()` Block**: Prevents console errors from appearing before our code runs
- **Custom Parsing Function**: `Parse-CommandLineArguments` handles all validation
- **Complete Error Logging**: All validation failures logged to `sysdaemon.main.log`

#### ✅ **Allowed Parameters Only**
- **`-axn`**: Action parameter (required, case insensitive)
- **`-LangPack`**: Language pack file (optional, case insensitive)

#### ✅ **Valid Values for -axn (Case Insensitive)**
- `"add-job"`: Create scheduled task
- `"del-job"`: Delete scheduled task  
- `"exec-job"`: Execute scheduled task
- `"kill-job"`: Stop and disable scheduled task

#### ✅ **Valid Values for -LangPack (Case Insensitive)**
- `"en-us.json"`: English language pack
- `"de-de.json"`: German language pack

#### ❌ **All Invalid Usage Now Silent**
```powershell
# ❌ These all fail SILENTLY (only log file entries)
.\sysdaemon.main.ps1 -action "add-job"           # Unknown parameter
.\sysdaemon.main.ps1 -axn "run-job"              # Invalid value
.\sysdaemon.main.ps1 -axn "add-job" -langID "en" # Unknown parameter
.\sysdaemon.main.ps1 -axn                        # Missing value
.\sysdaemon.main.ps1                             # Missing required parameter
.\sysdaemon.main.ps1 unexpected                  # Unexpected argument
```

#### 🛡️ **Silent Error Handling Benefits**
- **No Console Output**: Zero error messages displayed to user
- **Complete Logging**: All errors documented in `sysdaemon.main.log`
- **Enterprise Ready**: Perfect for automation and scheduled execution
- **Security Focus**: No information disclosure through console errors
- **Debugging Friendly**: Detailed error analysis available in log file

## 🔍 Troubleshooting

### Common Issues

#### ❌ "Administrative privileges required"
**Solution**: Run PowerShell as Administrator
```powershell
# Right-click PowerShell → "Run as Administrator"
```

#### ❌ "XML file not found"
**Problem**: Missing `RunSystemJob.xml` template  
**Solution**: Ensure the XML template file exists in the script directory

#### ❌ "Language pack not found"
**Problem**: Missing language pack files  
**Solution**: Verify `en-us.json` exists (minimum requirement)

#### ❌ **Script Runs But Nothing Happens**
**Problem**: Invalid parameters or parameter values  
**Solution**: Check the log file for detailed error information

```powershell
# Check for any errors
Get-Content .\sysdaemon.main.log | Select-String "ERROR"

# View recent log entries
Get-Content .\sysdaemon.main.log -Tail 20

# Check parameter validation specifically
Select-String -Path .\sysdaemon.main.log -Pattern "Unknown parameter|Invalid.*parameter|Missing.*parameter"
```

#### ❌ "Task already exists"
**Problem**: Previous task installation  
**Solution**: Use `del-job` first, then `add-job`

```powershell
.\sysdaemon.main.ps1 -axn "del-job"
.\sysdaemon.main.ps1 -axn "add-job"
```

### Log Analysis Examples

**English Error Messages:**
```log
[2025.10.05 - 17:30:15] [ERROR] Unknown parameter specified: -action
[2025.10.05 - 17:30:15] [ERROR] Only the following parameters are allowed: -axn, -langpack
[2025.10.05 - 17:30:15] [ERROR] Usage: .\sysdaemon.main.ps1 -axn "add-job" [-LangPack "en-us.json"]
```

**German Error Messages:**
```log
[2025.10.05 - 17:30:22] [ERROR] Ungültiger Wert 'run-job' für -axn Parameter. Muss einer der folgenden sein: add-job, del-job, exec-job, kill-job
[2025.10.05 - 17:30:22] [ERROR] Verwendung: .\sysdaemon.main.ps1 -axn "add-job" [-LangPack "de-de.json"]
```

### Performance Optimization

- **Large Scripts**: Consider breaking complex tasks into multiple smaller jobs
- **Resource Usage**: Monitor system resources during task execution
- **Scheduling**: Use appropriate trigger configurations in the XML template

## 🔒 Security Considerations

- **SYSTEM Context**: Tasks run with full system privileges - use responsibly
- **Auto-Disable**: Tasks are automatically disabled after execution for security
- **Silent Error Handling**: Parameter errors are logged silently to prevent information disclosure
- **Complete Validation**: All parameter combinations and values are thoroughly validated
- **Log Security**: Log files may contain sensitive information - secure appropriately
- **Script Validation**: Always validate and test your custom job scripts thoroughly

## 📚 Advanced Features

### Manual Parameter Processing
SysDaemon v1.00.10 uses revolutionary parameter processing:

```powershell
# NO param() block - prevents PowerShell built-in validation
# Manual $args processing in Parse-CommandLineArguments function
$parsedParameters = Parse-CommandLineArguments -Arguments $args
```

### COM-Based Task Manipulation
SysDaemon uses COM objects to avoid PowerShell collection limitations:

```powershell
# Automatic COM fallback for trigger modifications
$taskService = New-Object -ComObject("Schedule.Service")
$taskService.Connect()
```

### Multilingual Error Messages
All error messages respect the chosen language pack:

```powershell
# German error output
[ERROR] Ungültiger Action-Parameter 'run-job'. Muss einer der folgenden sein: add-job, del-job, exec-job, kill-job

# English error output  
[ERROR] Invalid action parameter 'run-job'. Must be one of: add-job, del-job, exec-job, kill-job
```

### Case Insensitive Operation
All parameters and values are case insensitive:

```powershell
# These all work identically
.\sysdaemon.main.ps1 -axn "ADD-JOB" -LangPack "EN-US.JSON"
.\sysdaemon.main.ps1 -AXN "add-job" -langpack "en-us.json"
.\sysdaemon.main.ps1 -Axn "Add-Job" -LANGPACK "En-Us.Json"
```

## 🤝 Contributing

We welcome contributions! Areas for development:

- **New Language Packs**: Add support for additional languages
- **Enhanced Features**: Improved scheduling options and management features  
- **Documentation**: More examples and use cases
- **Testing**: Comprehensive test scenarios and edge cases

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Praetoriani**  
- GitHub: [@praetoriani](https://github.com/praetoriani)
- Project: SysDaemon v1.00.10

---

⭐ **Star this repository if SysDaemon helps you automate your Windows systems!**

📖 **Check out our [CHANGELOG](CHANGELOG.md) for detailed version history**