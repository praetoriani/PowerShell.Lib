# PowerEdge Changelog

All notable changes to the PowerEdge project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.01.01] - 2026-04-14

### Added
- **Integrated VPDLX module**: PowerEdge now officially includes the Virtual PowerShell Data-Logger Extension as a core component. The module is loaded at runtime and available globally.
- **Standalone HTTP-Server**: Implemented a fully functional, non-blocking HTTP server using the `LocalServer` class. This allows PowerEdge to host complex SPAs and local web content with high performance.
- **Enhanced Home Page**: The default `home.html` has been completely redesigned. It now features:
  - Real-time HTTP-Server status and configuration details.
  - Integration indicators for VPDLX and WebView2 (including logos).
  - Detailed System Information (Windows version, PowerShell/ .NET/ WinGet versions, RAM, and performance status).
  - Modernized "Production Ready" UI layout with refined CSS.

### Fixed
- **Shutdown logic**: Added cleanup routines to ensure the HTTP server stops gracefully when the PowerEdge window is closed.
- **URL Routing**: Improved handling of target URIs to support both local file paths and the internal HTTP server URL prefixes.

### Changed
- **Version bump**: Project updated to version **v1.01.01** across all files.
- **Modularization**: Moved VPDLX and LocalServer into the `data/core/` structure for better project organization.

---

## [1.00.02] - 2026-04-14

### Added
- **-Hidden** parameter: Allows PowerEdge to start hidden (window not visible).
  - Can only be used in combination with the `-Timeout` parameter.
  - Use case: Pre-load the application in the background for faster subsequent display.
- **-Timeout** parameter: Specifies duration (in milliseconds) PowerEdge remains hidden.
  - After timeout expires, the window becomes visible automatically.
  - Mandatory when `-Hidden` is used.
- **LoadURL** function (`data/fxlib/LoadURL.ps1`):
  - Navigates the WebView2 control to a new URL or local HTML file.
  - Supports absolute URIs, local file paths, and relative paths.
- **LoadURLafter** function (`data/fxlib/LoadURLafter.ps1`):
  - Works like `LoadURL` but delays navigation by a specified number of milliseconds.
  - Uses WPF DispatcherTimer for thread-safe delayed navigation.

### Fixed
- **WebView2 user-data folder issue:**
  - WebView2 no longer tries to create its user-data folder inside `C:\Windows\System32\WindowsPowerShell\v1.0\` (no write access).
  - A `CoreWebView2Environment` is now explicitly created with the user-data folder set to `\.wv2data` (inside PowerEdge project directory).
  - Fixes error: "Das Datenverzeichnis konnte nicht erstellt werden" (HRESULT 0x80080005, CO_E_SERVER_EXEC_FAILURE).
- **Corrupted code block in UI runspace:**
  - Cleaned up garbled lines in the TitleBarLogo assignment section that referenced undefined "AppIcon" command.
- **Version display corrected:**
  - Fixed incorrect version string `v1.00.03` → `v1.00.02` in:
    - `data/ui/main.window.xml` (header comment, CHANGES section, status bar).
- **TitleBarPanel transparency fix:**
  - Added `Background="Transparent"` to TitleBarPanel (Grid) in WPF.
  - Prevents hit-testing issues where mouse events pass through transparent areas.
  - Added `x:Name="TitleBarBorder"` to the Row-0 Border for reliable event handling.
- **Typography.CharacterSpacing removed from logo TextBlock:**
  - Property not reliably supported on TextBlock elements under PowerShell 5.1 / .NET Framework 4.x.
  - Removed entirely to ensure compatibility; minimal visual impact at 13px font size.

### Changed
- Updated XAML UI file (`data/ui/main.window.xml`):
  - Header comment now reflects version 1.00.02.
  - Status bar displays "PowerEdge v1.00.02" instead of v1.00.03.
- Updated `PowerEdge.ps1` CHANGELOG section to document all v1.00.02 changes.

---

## [1.00.01] - 2026-04-12

### Fixed
- **EnsureCoreWebView2Async() timing issue:**
  - `EnsureCoreWebView2Async()` is now called inside the `Window.Loaded` event handler instead of before `ShowDialog()`.
  - The WebView2 control requires the WPF dispatcher/event loop to be running before `EnsureCoreWebView2Async` can be invoked.
  - Calling it before `ShowDialog()` caused the error: _"EnsureCoreWebView2Async cannot be used before the application's event loop has started running."_

---

## [1.00.00] - 2026-04-12

### Added
- **Initial release of PowerEdge:**
  - Modern WPF application window with embedded Microsoft Edge WebView2 control.
  - Loads local HTML files in a frameless, dark-themed window.
  - External XAML UI definition (`data/ui/main.window.xml`).
  - Modular function library (`data/fxlib/`) for reusable PowerShell code.
  - Configuration file (`data/config.json`) for application metadata.
  - Support for custom window titles via `-WindowTitle` parameter.
  - Custom title bar with minimize, maximize, and close buttons (macOS-style traffic lights).
  - Loading overlay with animated spinner during WebView2 initialization.
  - Status bar showing current state and version.

---

**Author:** Praetoriani
**Repository:** [https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge](https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge)
