# Changelog 📝

All notable changes to **Power.Ctrl.app** are documented here.

> **Current Version:** v1.00.10  
> **Development Period:** 28.09.2025

## [v1.00.10] - 2025-09-28 🎯

### ✅ **Enhanced** 
- **Pixel-perfect Window Positioning** - Implemented tested offset values (-6px, +6px) for precise positioning
- **Default Settings Optimization** - Logging now disabled by default (`$globalCreateLogFile = $false`)
- **Perfect Corner Alignment** - Windows now position exactly at screen edges for `lowerleft` and `lowerright`

### 🔧 **Changed**
- **Window Positioning Logic** - Fine-tuned offsets for accurate placement above taskbar
- **Standard Configuration** - Logging disabled by default for better performance

---

## [v1.00.09] - 2025-09-28 📝

### 🆕 **Added**
- **Complete Logging System** - Optional file logging with timestamps (`Power.Ctrl.app.log`)
- **Taskbar-Aware Positioning** - Windows positioned precisely above taskbar using WorkingArea
- **Advanced Window Management** - Precise positioning for `lowerleft` and `lowerright` options

### ✅ **Enhanced**
- **Log File Management** - Automatic deletion/creation based on `$globalCreateLogFile` setting
- **Console Output Logging** - All console messages logged to file when enabled
- **Timestamp Format** - `[DD.MM.YYYY ; HH:MM:SS]` format for log entries
- **Working Area Detection** - Automatic taskbar height calculation and compensation

---

## [v1.00.08] - 2025-09-28 🌍

### ✅ **Enhanced**
- **100% Localization** - All console messages now fully localized (including early startup)
- **UI Color Optimization** - Lighter button colors (#FF6A6A6A) for better icon contrast
- **Fallback Message System** - Early startup messages with language-aware fallbacks

### 🔧 **Changed**
- **Button Colors** - Background: #FF6A6A6A, Border: #FF8A8A8A, Hover: #FF7A7A7A
- **Icon Visibility** - Improved contrast and readability with lighter button background
- **Console Messages** - No more hardcoded English messages during startup

---

## [v1.00.07] - 2025-09-28 ⚡

### 🆕 **Added**
- **Robust Application Management** - Intelligent WPF Application instance handling
- **Graceful Shutdown System** - `Environment.Exit()` for clean application termination
- **Event-Driven Guards** - `$isShuttingDown` flag prevents post-shutdown events

### 🔧 **Fixed**
- **Application Instance Conflicts** - Proper reuse of existing WPF Application instances
- **Shutdown Event Handling** - No more window operations after application closure
- **Memory Management** - Clean WPF Application lifecycle with proper cleanup

---

## [v1.00.06] - 2025-09-28 🏗️

### 🆕 **Added**
- **Central WPF Application Instance** - Single Application.Run() for proper message loop
- **Modal Popup Behavior** - ShowDialog() for confirmation windows
- **Application State Management** - Proper WPF application lifecycle handling

### 🔧 **Fixed**
- **Message Loop Issues** - Corrected WPF event processing architecture
- **Window Interaction** - Popup windows now respond properly to user input
- **Application Exit** - Clean shutdown without frozen windows

---

## [v1.00.05] - 2025-09-28 🎨

### 🆕 **Added**
- **Modern Dark Mode Interface** - Complete WPF UI with dark theme styling
- **Shell32.dll Icon Integration** - Native Windows icons for all action buttons
- **XAML-Based UI** - Separate UI files for main window and popup dialogs
- **Enhanced Button Styling** - Hover effects, rounded corners, professional appearance

### ✅ **Enhanced**
- **Visual Polish** - Modern button designs with visual feedback
- **Icon Extraction** - Dynamic icon loading from Windows system resources
- **UI Responsiveness** - Improved user interaction and visual cues

---

## [v1.00.04] - 2025-09-28 📐

### 🆕 **Added**
- **Window Positioning System** - Three position options: center, lowerleft, lowerright
- **Global Configuration Variables** - Easy customization through script variables
- **Screen Awareness** - Dynamic positioning based on screen dimensions

### ✅ **Enhanced**
- **User Experience** - Configurable window placement for different user preferences
- **Flexibility** - Easy switching between positioning modes via global variables

---

## [v1.00.03] - 2025-09-28 💻

### 🆕 **Added**
- **Console Window Management** - Automatic hiding/showing of PowerShell console
- **Win32 API Integration** - ShowWindowAsync for console window control
- **Professional Appearance** - Hidden console creates cleaner user experience

### 🔧 **Technical**
- **P/Invoke Implementation** - Direct Windows API calls for console manipulation
- **Handle Management** - Safe console window handle acquisition and usage

---

## [v1.00.02] - 2025-09-28 ✅

### 🆕 **Added**
- **Confirmation Dialog System** - Safety prompts before executing system actions
- **Configurable Confirmation** - Option to enable/disable confirmation dialogs
- **Action-Specific Messages** - Tailored confirmation text for each system action

### ✅ **Enhanced**
- **Safety Features** - Prevents accidental system actions
- **User Control** - Configurable confirmation behavior
- **User Experience** - Clear, action-specific confirmation messages

---

## [v1.00.01] - 2025-09-28 🌍

### 🆕 **Added**
- **Complete Localization System** - Support for multiple languages via JSON files
- **German Language Pack** - Full German localization (`de-de.json`)
- **English Language Pack** - Full English localization (`en-us.json`)
- **Dynamic Language Loading** - Automatic language selection based on configuration

### ✅ **Enhanced**
- **Internationalization** - Support for different languages and cultures
- **JSON-Based Translations** - Easy addition of new languages
- **Fallback System** - Graceful handling when language files are missing

---

## [v1.00.00] - 2025-09-28 🚀

### 🎉 **Initial Release**
- **Core System Actions** - Lock, Logoff, Restart, Shutdown functionality
- **PowerShell Foundation** - Pure PowerShell implementation with cmdlet integration
- **Basic WPF Interface** - Functional Windows Presentation Foundation GUI
- **Error Handling** - Robust exception handling and error reporting

### 🏗️ **Architecture**
- **Modular Design** - Separated functions for different system operations
- **WPF Integration** - Modern Windows GUI framework implementation
- **System Integration** - Native Windows system command utilization

---

## 🏷️ Version Schema

Power.Ctrl.app follows semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** - Major architectural changes or breaking changes
- **MINOR** - New features, significant enhancements
- **PATCH** - Bug fixes, small improvements, optimizations

## 📊 Development Statistics

- **Total Versions:** 11 (v1.00.00 → v1.00.10)
- **Development Time:** 1 day (28.09.2025)
- **Major Features Added:** 10+
- **Files Created:** 5 core files + documentation
- **Languages Supported:** 2 (German, English)

## 🎯 Future Roadmap

**Power.Ctrl.app v1.00.10** represents a stable, feature-complete version. Future enhancements might include:

- Additional system actions
- More language packs
- Advanced scheduling features
- System monitoring capabilities
- Plugin architecture

---

**Developed with ❤️ for the Windows PowerShell Community**