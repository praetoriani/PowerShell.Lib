# Power.Ctrl.app 🚀

> **Version:** v1.00.10  
> **Author:** Praetoriani  
> **Date:** 28.09.2025

A modern, minimalist PowerShell WPF application for quick Windows system control with elegant Dark Mode interface.

## 📋 Overview

**Power.Ctrl.app** is a user-friendly system control application that provides four essential Windows actions through a modern graphical interface:
- 🔒 **Lock workstation**
- 👤 **Log off user**
- 🔄 **Restart computer**
- ⚡ **Shut down computer**

## ✨ Features

- 🎨 **Modern Dark Mode UI** - Sleek, dark WPF interface
- 🌍 **Full Localization** - German/English with automatic language detection
- 📍 **Flexible Positioning** - Center, Lower-Left, Lower-Right
- ✅ **Confirmation Dialogs** - Security prompts before system actions
- 📝 **Optional Logging** - Detailed logging with timestamps
- 🎯 **Shell32.dll Icons** - Native Windows system symbols
- ⚡ **Robust Architecture** - Stable WPF Application management
- 💻 **Windows 11 Ready** - Optimized for modern Windows versions

## 🔧 System Requirements

- **Operating System:** Windows 10/11
- **PowerShell:** Version 5.0 or higher
- **.NET Framework:** 4.7.2 or higher (usually pre-installed)
- **Permissions:** Administrator rights recommended for all system actions

## 📦 Installation & Launch

### Quick Start
1. Copy all files to a folder of your choice
2. Open PowerShell as Administrator
3. Navigate to folder: `cd C:\Path\To\Power.Ctrl.app`
4. Launch application: `.\Power.Ctrl.app.ps1`

### Initial Setup
If PowerShell execution policies prevent this:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## ⚙️ Configuration

All settings are configured via **global variables** in the main script:

### Language 🌍
```powershell
$global:globalLanguage = "de-de"  # or "en-us"
```

### Window Position 📍
```powershell
$global:globalWindowPosition = "center"  # "lowerleft", "lowerright"
```

### Confirmation Dialogs ✅
```powershell
$global:globalShowConfirmationDialog = $true  # $false for direct execution
```

### Logging System 📝
```powershell
$global:globalCreateLogFile = $false  # $true for logging
```

## 📁 Files & Structure

```
Power.Ctrl.app/
├── Power.Ctrl.app.ps1     # Main application
├── app-ui-main.xaml       # Main window interface
├── app-ui-popup.xaml      # Confirmation dialog
├── de-de.json            # German localization
├── en-us.json            # English localization
├── Power.Ctrl.app.log    # Log file (when enabled)
└── README-EN.md          # This file
```

## 🎮 Usage

### Main Window
- **4 large buttons** with icons for each system action
- **Tooltips** when hovering over buttons
- **Automatic language detection** based on configuration

### Confirmation Dialog
- **Yes/No buttons** for security confirmation
- **Specific messages** depending on chosen action
- **ESC** or **X-button** = Return to main window

### Keyboard Shortcuts
- **ESC** - Exit application (in main window)
- **Alt+F4** - Exit application

## 📋 Log System

When logging is enabled (`$globalCreateLogFile = $true`):
- **File:** `Power.Ctrl.app.log` in application folder
- **Format:** `[DD.MM.YYYY ; HH:MM:SS] Message`
- **Content:** All console outputs with timestamps
- **Rotation:** New file with each start (old one deleted)

### Example Log:
```
[28.09.2025 ; 21:05:33] Starting Power.Ctrl.app v1.00.10
[28.09.2025 ; 21:05:34] Main window loaded successfully
[28.09.2025 ; 21:05:45] Action requested: lock
[28.09.2025 ; 21:05:47] User confirmed action
[28.09.2025 ; 21:05:47] Workstation locked successfully
```

## 🔍 Troubleshooting

### ❌ PowerShell Execution Policies
**Problem:** `Execution of scripts is disabled on this system`
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ Missing .NET Framework Assemblies
**Problem:** `Type "System.Windows.Application" was not found`
- Run Windows Update
- Install .NET Framework 4.7.2 or higher

### ❌ Icons Not Displaying
**Problem:** Gray rectangles instead of icons
- Restart Windows
- Run application as Administrator
- Check Shell32.dll integrity: `sfc /scannow`

### ❌ Inaccurate Window Positioning
**Problem:** Windows not positioned exactly
- Check screen resolution/scaling
- Verify Windows Display settings
- Multiple monitors: Define primary monitor

### ❌ Language Files Not Found
**Problem:** `Language file not found`
- Ensure `de-de.json` and `en-us.json` are in the same folder
- Check file permissions
- Use paths without special characters

### ❌ Logging Not Working
**Problem:** Log file not created
- Check write permissions in application folder
- Configure `$globalCreateLogFile = $true`
- Run application as Administrator

## 🛡️ Security

- **Confirmation dialogs** prevent accidental system actions
- **No network connections** - Purely local application
- **Shell32.dll integration** - Uses only Windows-native resources
- **Clean PowerShell execution** - No hidden processes

## 🔄 Updates & Maintenance

- **Automatic Updates:** Not available
- **Manual Updates:** Download new version and replace files
- **Configuration:** Preserved during updates (global variables)
- **Compatibility:** Backward compatible with previous configurations

## 📞 Support & Contact

**Power.Ctrl.app** is an open-source project. For questions or issues:

- 📖 **Documentation:** See `Changelog.md` for version history
- 🔧 **Configuration:** All settings in global variables
- 🛠️ **Troubleshooting:** See section above

## 📜 License

This project is available under an open-source license. Use at your own responsibility.

---

**Developed with ❤️ for the Windows PowerShell Community**