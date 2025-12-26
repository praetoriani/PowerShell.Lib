# ModernUI v1.00.00

**Modern UI Framework for PowerShell WPF**

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-1.00.00-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)]()

---

## Overview

ModernUI is a lightweight, modern user interface framework for PowerShell WPF applications. It provides a frameless window design with Windows 11-style aesthetics, including smooth animations, hover effects, and modern color schemes.

**Key Features:**
- ✅ Frameless window design (WindowStyle="None")
- ✅ Draggable title bar
- ✅ Hover effects on UI controls
- ✅ Background image support
- ✅ Config-driven image loading
- ✅ Clean, production-ready code
- ✅ Proper event handler scoping for PowerShell
- ✅ Cross-thread safe image loading

---

## Quick Start

### Prerequisites

- Windows 10 or Windows 11
- PowerShell 7.0+ (or 5.1 with .NET Framework 4.8+)
- .NET Framework 4.8+
- PNG image files in the `PNG/` directory

### Installation

```powershell
# Clone the repository
git clone https://github.com/praetoriani/PowerShell.Lib.git
cd PowerShell.Lib\ModernUI

# Run the application
.\ModernUI.ps1
```

### Expected Behavior

After starting the application:
- ✅ Window opens immediately
- ✅ Background image displays correctly
- ✅ Window title bar shows with icon
- ✅ Close button visible in top-right corner
- ✅ Window is draggable via title bar
- ✅ Close button hover effect works (PNG swaps)
- ✅ No console errors

---

## Project Structure

```
ModernUI/
├── ModernUI.ps1                    # Main PowerShell script
├── config.json                     # Configuration file
├── ModernUI.xaml                   # XAML window definition (not used directly)
├── PNG/
│   ├── appicon.png                 # Window icon
│   ├── ModernUI-WinBG.png          # Background image
│   ├── axn-winclose-normal.png     # Close button normal state
│   └── axn-winclose-hover.png      # Close button hover state
├── README.md                       # This file
├── CHANGELOG.md                    # Version history and changes
└── BUGFIXES.md                     # Known issues and fixes
```

---

## Configuration

### config.json

The `config.json` file controls image paths and window properties:

```json
{
  "version": "1.00.00",
  "application": "ModernUI",
  "paths": {
    "baseImagePath": "./PNG",
    "windowIcon": "appicon.png",
    "backgroundImage": "ModernUI-WinBG.png",
    "closeButtonNormalPath": "axn-winclose-normal.png",
    "closeButtonHoverPath": "axn-winclose-hover.png"
  }
}
```

**Path Notes:**
- All paths are relative to the `ModernUI/` directory
- Use forward slashes (`/`) in JSON
- PNG directory must exist with all required images
- Images should be properly formatted and accessible

---

## Architecture

### Component Overview

#### 1. Assembly Loading
Loads required WPF and .NET assemblies:
- `System.Windows.Forms`
- `PresentationFramework`
- `PresentationCore`
- `WindowsBase`
- `System.Xaml`

#### 2. Configuration Loading
- Reads `config.json` with UTF-8 encoding
- Parses JSON into PowerShell objects
- Expands relative paths to absolute paths

#### 3. Image Loading
- Uses `System.Windows.Media.Imaging.BitmapImage`
- Implements proper BeginInit/EndInit pattern
- Calls `Freeze()` for cross-thread safety
- Uses `BitmapCacheOption.OnLoad` for memory efficiency

#### 4. WPF UI Initialization
- Creates window from XAML
- Binds event handlers in PowerShell (not XAML)
- Sets static images (icon, background)
- Registers dynamic event handlers (hover effects)

#### 5. Event Handling
- Title bar drag (MouseLeftButtonDown)
- Close button hover effects (MouseEnter/MouseLeave)
- Close button click (Close window)
- OK button click (logging only)

---

## Critical Concepts

### 1. Event Handler Scoping

PowerShell event handlers run in an isolated scope. Local function variables are **NOT** accessible:

```powershell
# ❌ WRONG - $window is null in event handler
function Register-Events {
    param($window)
    $closeButton.Add_Click({
        $window.Close()  # ERROR: $window is $null
    })
}

# ✅ CORRECT - Use script-scoped variables
function Register-Events {
    param($window)
    $script:WindowReference = $window  # Store in script scope
    $closeButton.Add_Click({
        $script:WindowReference.Close()  # OK: accessible
    })
}
```

**Available Scopes in Event Handlers:**
- ✅ `$Global:` - Always accessible
- ✅ `$script:` - Always accessible (same script)
- ✅ `param($sender, $e)` - Event parameters
- ❌ Local variables - NOT accessible
- ❌ Function parameters - NOT accessible

### 2. Window.DragMove()

Must be called during `MouseLeftButtonDown` event:

```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    $script:WindowReference.DragMove()  # Only works here
})
```

**Requirements:**
- `WindowStyle="None"` in XAML
- Must be in MouseLeftButtonDown handler
- Try-catch recommended for safety
- Window reference must be in script scope

### 3. BitmapImage Creation

Proper 5-step initialization:

```powershell
$bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()                                           # Step 1
$bitmap.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)  # Step 2
$bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad  # Step 3
$bitmap.EndInit()                                             # Step 4
$bitmap.Freeze()                                              # Step 5 (critical!)
```

**Why Freeze()?**
- Makes bitmap immutable
- Enables cross-thread access
- Required for event handler usage
- Improves performance

### 4. Control.Tag Property for Event Data

Store references in `.Tag` for event handler access:

```powershell
# During initialization
$button.Tag = @{
    NormalPath = $normalImagePath
    HoverPath = $hoverImagePath
    ImageControl = $imageElement
}

# In event handler
$closeButton.Add_MouseEnter({
    param($sender, $e)
    # $sender = $closeButton
    $hoverPath = $sender.Tag.HoverPath
    $imageControl = $sender.Tag.ImageControl
})
```

---

## Troubleshooting

### Problem: Background image not displaying

**Symptoms:**
- Gray/blank window background
- No error messages

**Solutions:**
1. Verify image file exists: `ModernUI-WinBG.png` in `PNG/` directory
2. Check file format: Must be valid PNG
3. Verify config.json paths are correct
4. Check file permissions

**Debugging:**
```powershell
# Test image path resolution
$bgPath = Join-Path $PSScriptRoot "PNG" | Join-Path -ChildPath "ModernUI-WinBG.png"
Test-Path $bgPath -PathType Leaf
```

### Problem: Close button hover causes crash

**Symptoms:**
- Application closes when hovering over close button
- Error: "The property 'Source' was not found for this object"

**Root Cause:**
- Image control reference not in script scope
- Event handler cannot access local variables

**Solution:**
- Store image control in `$script:CloseButtonImageControl`
- Access via `$script:` prefix in event handler
- Never use `.FindName()` inside event handlers

### Problem: Window cannot be dragged

**Symptoms:**
- Title bar click does not move window
- No error messages

**Root Cause:**
- Window reference not available in event handler
- DragMove() not called in MouseLeftButtonDown handler

**Solution:**
- Store window in `$script:WindowReference`
- Call `$script:WindowReference.DragMove()` in handler
- Wrap in try-catch for safety

### Problem: JSON parsing error

**Symptoms:**
- Error message about JSON conversion
- Config fails to load

**Solutions:**
1. Verify UTF-8 encoding (no BOM)
2. Check for escaped backslashes (use forward slashes)
3. Validate JSON syntax at [jsonlint.com](https://www.jsonlint.com/)
4. Ensure no trailing commas

---

## PowerShell-WPF Best Practices

### 1. Never Use Event Handlers in XAML

```xaml
<!-- ❌ WRONG -->
<Window MouseMove="Window_MouseMove" />
<Button Click="Button_Click" />

<!-- ✅ CORRECT -->
<Window x:Name="MyWindow" />
<Button x:Name="MyButton" />
```

Bind event handlers in PowerShell instead:

```powershell
$button = $window.FindName("MyButton")
$button.Add_Click({ ... })
```

### 2. Use x:Name Instead of Event Attributes

Every control that needs event handling must have `x:Name`:

```xaml
<Grid x:Name="MainGrid" />
<Border x:Name="TitleBar" />
<Button x:Name="CloseButton" />
<Image x:Name="BackgroundImage" />
```

Access in PowerShell:

```powershell
$mainGrid = $window.FindName("MainGrid")
$titleBar = $window.FindName("TitleBar")
$closeButton = $window.FindName("CloseButton")
```

### 3. Always Use script: Scope for Event Data

```powershell
# Store references needed in event handlers
$script:WindowReference = $window
$script:ImageControl = $window.FindName("MyImage")
$script:EventData = @{ ... }

# Access in event handlers
$button.Add_Click({
    $script:WindowReference.Close()
    $script:ImageControl.Source = ...
})
```

### 4. Use $sender Parameter for Control Access

```powershell
$closeButton.Add_MouseEnter({
    param($sender, $e)
    # $sender is the close button
    $sender.Opacity = 0.8
})
```

### 5. Implement Try-Catch in Event Handlers

```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    try {
        $script:WindowReference.DragMove()
    }
    catch {
        Write-Warning "Error: $_"
    }
})
```

---

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Windows 10 (Build 1909+) | Windows 11 |
| **PowerShell** | 5.1 | 7.4+ |
| **.NET Framework** | 4.8 | 4.8 (latest) |
| **RAM** | 512 MB | 2 GB+ |
| **Disk Space** | 10 MB | 50 MB |

---

## Performance

**Startup Time:** ~2 seconds
**Memory Usage:** 80-120 MB
**CPU Usage:** <5% (idle)

---

## License

MIT License - Free for personal and commercial use

```
MIT License

Copyright (c) 2025 Marc Sczepanski (praetoriani)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Support

**Found an issue?**

1. Check [BUGFIXES.md](./BUGFIXES.md) for known issues
2. Review [CHANGELOG.md](./CHANGELOG.md) for recent changes
3. Create an issue on [GitHub Issues](https://github.com/praetoriani/PowerShell.Lib/issues)

**Questions?**

- GitHub: [@praetoriani](https://github.com/praetoriani)
- Email: marc.sczepanski@gmail.com
- Location: Freising, Bavaria, Germany

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for complete version history.

---

## Author

**Marc Sczepanski (praetoriani)**
- Full Stack Developer
- PowerShell & .NET Expert
- Location: Freising, Bavaria, Germany
- GitHub: [praetoriani](https://github.com/praetoriani)

---

**Status:** Production Ready ✅  
**Last Updated:** December 26, 2025  
**Version:** 1.00.00 (Stable Release)
