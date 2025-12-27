<div align="center">

# ModernUI v1.00.02 Final Release

![ModernUI Poster](./ModernUI-Poster.png)

**Build**: 251227 (December 27, 2025)  
**Status**: ✅ Stable, Production-Ready

</div>

---

ModernUI is a modern WPF-based UI framework for PowerShell, designed to
bring a clean, Windows 11 inspired experience to PowerShell
applications.

This README describes **ModernUI v1.00.02 Final Release** as part of the
`PowerShell.Lib` repository.

---

## 1. Overview

- **Name**: ModernUI
- **Version**: 1.00.02
- **Build**: 251227 (December 27, 2025)
- **Status**: Stable, production-ready
- **Technology**: PowerShell 7+, WPF (.NET Framework 4.8)
- **Purpose**: Provide a reusable, modern WPF UI shell for PowerShell
  scripts.

ModernUI focuses on:

- A frameless main window with custom graphics
- PNG-based visual controls (fully customizable)
- Config-driven behaviour (no code changes needed for customization)
- External XAML layout (clear separation of concerns)
- Structured logging system (file-based, configurable)
- **Working hover effects** on interactive controls

---

## 2. Features in v1.00.02

### 2.1 External XAML Layout

- The main window layout is defined in `ModernUI/WPF/ModernUI.xaml`.
- The PowerShell script (`ModernUI.ps1`) loads this XAML file at runtime
  using the configuration in `config.json` (`screen.mainwin`).
- **Benefit**: Clean separation between layout (XAML) and behavior
  (PowerShell).

### 2.2 Config-Driven Behaviour

`config.json` is the central configuration point for ModernUI:

- **app** – basic metadata such as name, version, description, developer
  and website.
- **debug** – controls logging behaviour (file name, enabled flag,
  datetime format, severity labels/icons).
- **window** – window title, size and startup location.
- **paths** – image file names for icons, background and the main
  application screen preview.
- **screen** – which XAML files to use for main and additional windows.

**Benefit**: Change any configuration without touching code.

### 2.3 Logging System

- All relevant runtime information can be written to a log file.
- Controlled via `config.debug`:
  - `enabled`: `"true"` or `"false"`.
  - `file`: log file name (e.g. `runtime.log`).
  - `datetime`: timestamp format for log entries.
  - `severityLevel`: labels for different severities.
- The `Write-LogEntry` function creates entries in the form:

  ```text
  [yyyy.MM.dd ; HH:mm:ss] [INFO]   -> Example message
  ```

- **Benefit**: Production-ready logging that can be toggled on/off via
  config or code comment-out.

### 2.4 Label-Based Close Button with Fully Working Hover Effect ✨

- The close button in the title bar is a `Label` hosting an `Image`.
- Two PNG files are used:
  - Normal state: `paths.winaxnCloseImage`
  - Hover state: `paths.winaxnCloseHover`
- **Hover behaviour**: Implemented via `MouseEnter`/`MouseLeave` events
  attached directly to the Image element.
- **Click behaviour**: Implemented via `PreviewMouseLeftButtonDown` and
  closes the window reliably.
- **Visual feedback**:
  - Cursor changes to hand pointer on hover
  - Tooltip displays "Close Application"
  - Smooth image transitions
  - No visual glitches or blank states

**Implementation notes**:
- Fresh `BitmapImage` instances created on each hover transition
- Images are not frozen (allows dynamic updates)
- Events attached to Image element (avoids parent interference)
- Paths stored globally for dynamic reloading

### 2.5 Main Window Content

The main window displays:

- A large centered title: **ModernUI**
- A version label below the title, using `app.version` (e.g.
  `v1.00.02`)
- A central image area displaying `appscreen.png` from the `PNG` folder
- Window icon in the title bar
- Background image for visual polish
- Credits:
  - `Written by Praetoriani`
  - `Now available on GitHub`
- Draggable title bar (click and drag to move window)

### 2.6 Image Handling Infrastructure

- `Resolve-ImagePath`: Locates PNG files in the `PNG/` directory
- `Load-BitmapImage`: Loads and caches image files
- `Get-FreshBitmapImage`: Creates new instances for dynamic rendering
- All images validated at startup
- Missing images logged with detailed error messages
- Images cached for performance but fresh instances created when needed

---

## 3. File Structure

```text
ModernUI/
  ModernUI.ps1         # Main PowerShell script (fully functional)
  config.json          # Central configuration (all runtime settings)
  VERSION              # Current version string (1.00.02)
  VERSION.md           # Version description (detailed)
  BUGFIXES.md          # Bugfix documentation (complete)
  CHANGELOG.md         # Changes in v1.00.02 (comprehensive)
  QUICKSTART.md        # How to start and use ModernUI
  README.md            # This file
  ModernUI-Poster.png  # Poster image (project branding)
  PNG/                 # PNG assets used by the UI
    appicon.png        # Window icon
    ModernUI-WinBG.png # Background image
    appscreen.png      # Main screen preview image
    axn-winclose-normal.png  # Close button normal state
    axn-winclose-hover.png   # Close button hover state
  WPF/
    ModernUI.xaml      # Main window layout (external)
```

---

## 4. Getting Started

### 4.1 Requirements

- Windows 10 or 11
- PowerShell 7.x
- .NET Framework 4.8

### 4.2 Running ModernUI

1. Open a PowerShell 7 console.
2. Navigate to the ModernUI folder inside the cloned repository:

   ```powershell
   Set-Location "<path-to-repo>\PowerShell.Lib\ModernUI"
   ```

3. Run the script:

   ```powershell
   .\ModernUI.ps1
   ```

4. The ModernUI main window should appear with:
   - Background image
   - Title ("ModernUI")
   - Version label ("v1.00.02")
   - App screen preview image
   - Credits text
   - Working close button in the top right

If logging is enabled in `config.json`, a log file (for example
`runtime.log`) will be created in the ModernUI folder.

### 4.3 Testing the Hover Effect

1. Run `ModernUI.ps1`
2. Move your cursor over the close button (X) in the top right
3. Observe:
   - Image changes to hover state
   - Cursor changes to hand pointer
   - Tooltip shows "Close Application"
4. Move cursor away – image returns to normal state
5. Click close button to close the application

---

## 5. Customisation

You can customise ModernUI without changing the PowerShell code in many
cases:

### Simple Changes (Config Only)

- Change PNG assets in the `PNG` folder
- Update `config.json` to point to different images
- Adjust window properties (title, size, position)
- Modify logging behaviour (enabled, file name, timestamp format)

### Medium Changes (XAML Only)

- Modify `WPF/ModernUI.xaml` to change the layout
- Add or remove UI elements
- Adjust colors, fonts, spacing

### Complex Changes (Code)

- Add new functions for additional logic
- Add new XAML files to `ModernUI/WPF/`
- Reference them in `config.screen`
- Load them from PowerShell similarly to the main window

---

## 6. Technical Highlights

### Hover Effect Implementation (The Solution)

```powershell
# The key to working hover effects in PowerShell WPF:

# 1. Create fresh images on each transition
$freshImage = Get-FreshBitmapImage -ImagePath $imagePath

# 2. Attach events directly to the Image element
$image.Add_MouseEnter({ param($sender, $e)
  $sender.Source = Get-FreshBitmapImage -ImagePath $hoverPath
})

# 3. Use $sender parameter for the triggering element
# 4. Never use .Freeze() on images that need dynamic updates
```

**Why this works**:
- Fresh instances avoid rendering issues
- Direct event attachment avoids parent interference  
- `$sender` parameter is reliable and direct
- No frozen images means dynamic updates work

### Logging Pattern

```powershell
# Simple call
Write-LogEntry -Severity "INFO" -Message "Application started"

# Output (fully configurable format)
[yyyy.MM.dd ; HH:mm:ss] [INFO] -> Application started

# Can be disabled by commenting out the function call
# Write-LogEntry -Severity "DEBUG" -Message "Debug info"
```

---

## 7. Poster

The `ModernUI-Poster.png` file is intentionally kept as part of the
project and can be used for documentation, presentations or as visual
branding for the ModernUI framework.

---

## 8. Additional Documentation

- **CHANGELOG.md** – Complete list of features and changes in v1.00.02
- **BUGFIXES.md** – Detailed documentation of fixed issues
- **QUICKSTART.md** – Practical guide on running and configuring ModernUI
- **VERSION.md** – Version details and technical highlights

All ModernUI documentation for this version uses English for consistency
and clarity.

---

## 9. Quality Assurance

**v1.00.02 Final Release** has been thoroughly tested:

✅ Application startup and resource loading  
✅ Close button normal state display  
✅ Close button hover effect (image swap)  
✅ Multiple hover transitions (reliability)  
✅ Close button click functionality  
✅ Window drag-to-move title bar  
✅ Logging system (when enabled)  
✅ Configuration loading and validation  
✅ Error handling and recovery  
✅ Memory management  

**Status**: Production-ready, stable, fully documented.

---

## 10. Future Development

With v1.00.02 as a solid foundation, future versions could include:

- Additional window support (dialogs, settings windows)
- Theme switching (light/dark modes)
- Animation framework for transitions
- Custom control library
- Advanced configuration options
- Multi-language support
- Touch/pen input support

---

## Summary

**ModernUI v1.00.02 Final Release** is a complete, tested, production-ready
WPF framework for PowerShell. It provides all the basics needed for modern
UI development in PowerShell with a focus on reliability, configurability,
and clean code architecture.

**Happy building! 🚀**
