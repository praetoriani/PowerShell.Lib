# ModernUI v1.00.02

ModernUI is a modern WPF-based UI framework for PowerShell, designed to
bring a clean, Windows 11 inspired experience to PowerShell
applications.

This README describes **ModernUI v1.00.02** as part of the
`PowerShell.Lib` repository.

---

## 1. Overview

- **Name:** ModernUI
- **Version:** 1.00.02
- **Technology:** PowerShell 7+, WPF (.NET Framework 4.8)
- **Purpose:** Provide a reusable, modern WPF UI shell for PowerShell
  scripts.

ModernUI focuses on:

- A frameless main window
- PNG-based visual controls
- Config-driven behaviour
- External XAML layout
- Structured logging

---

## 2. Features in v1.00.02

### 2.1 External XAML layout

- The main window layout is defined in `ModernUI/WPF/ModernUI.xaml`.
- The PowerShell script (`ModernUI.ps1`) loads this XAML file at runtime
  using the configuration in `config.json` (`screen.mainwin`).

### 2.2 Config-driven behaviour

`config.json` is the central configuration point for ModernUI:

- **app** – basic metadata such as name, version, description, developer
  and website.
- **debug** – controls logging behaviour (file name, enabled flag,
  datetime format, severity labels/icons).
- **window** – window title, size and startup location.
- **paths** – image file names for icons, background and the main
  application screen preview.
- **screen** – which XAML files to use for main and additional windows.

### 2.3 Logging system

- All relevant runtime information can be written to a log file.
- Controlled via `config.debug`:
  - `enabled`: `"true"` or `"false"`.
  - `file`: log file name (e.g. `runtime.log`).
  - `datetime`: timestamp format for log entries.
  - `severityLevel`: labels/icons for different severities.
- The `Write-LogEntry` function creates entries in the form:

  ```text
  [yyyy.MM.dd ; HH:mm:ss] [ℹ️ INFO]  → Example message
  ```

### 2.4 Label-based close button with hover

- The close button in the title bar is a `Label` hosting an `Image`.
- Two PNG files are used:
  - Normal state: `paths.winaxnCloseImage`.
  - Hover state: `paths.winaxnCloseHover`.
- Hover behaviour is implemented via `MouseEnter`/`MouseLeave` events.
- Click behaviour is implemented via `PreviewMouseLeftButtonDown` and
  closes the window.

### 2.5 Main window content

The main window displays:

- A large centered title: **ModernUI**
- A version label below the title, using `app.version` (e.g. `v1.00.02`)
- A central image area displaying `appscreen.png` from the `PNG` folder
- Credits:
  - `Written by Praetoriani`
  - `Now available on GitHub`

---

## 3. File structure

```text
ModernUI/
  ModernUI.ps1         # Main PowerShell script
  config.json          # Central configuration
  VERSION              # Current version string (1.00.02)
  VERSION.md           # Version description
  BUGFIXES.md          # Bugfix documentation for v1.00.02
  CHANGELOG.md         # Changes introduced in v1.00.02
  QUICKSTART.md        # How to start and use ModernUI
  README.md            # This file
  ModernUI-Poster.png  # Poster image (kept as part of the project)
  PNG/                 # PNG assets used by the UI
    appicon.png
    ModernUI-WinBG.png
    appscreen.png
    axn-winclose-normal.png
    axn-winclose-hover.png
    ...
  WPF/
    ModernUI.xaml      # Main window layout
```

`FIXES.md` is no longer part of the ModernUI documentation.

---

## 4. Getting started

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

4. The ModernUI main window should appear with the background image,
   title, version label, app screen preview and credits.

If logging is enabled in `config.json`, a log file (for example
`runtime.log`) will be created in the ModernUI folder.

---

## 5. Customisation

You can customise ModernUI without changing the PowerShell code in many
cases:

- Change PNG assets in the `PNG` folder.
- Update `config.json` to point to different images, adjust window
  properties or modify logging behaviour.
- Modify `WPF/ModernUI.xaml` to change the layout or add more controls.

For more complex scenarios (additional windows, new logic), you can:

- Add new XAML files to `ModernUI/WPF/`.
- Reference them in `config.screen`.
- Load them from PowerShell similarly to the main window.

---

## 6. Poster

The `ModernUI-Poster.png` file is intentionally kept as part of the
project and can be used for documentation, presentations or as visual
branding for the ModernUI framework.

---

## 7. Additional documentation

- `CHANGELOG.md` – detailed list of changes for v1.00.02.
- `BUGFIXES.md` – list of fixed issues in this version.
- `QUICKSTART.md` – practical guide on running and configuring ModernUI.
- `VERSION.md` – concise version description and affected files.

All ModernUI documentation for this version uses English naming and
labels.
