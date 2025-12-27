# ModernUI - QUICKSTART (v1.00.02)

This quickstart guide helps you run and understand **ModernUI v1.00.02**
inside the `PowerShell.Lib` repository.

---

## 1. Prerequisites

- **Operating System:** Windows 10 or Windows 11
- **PowerShell:** PowerShell 7.x (PowerShell Core)
- **.NET Framework:** 4.8 (for WPF)
- **Repository:** `PowerShell.Lib` cloned locally

---

## 2. Directory structure

The relevant ModernUI files are located here:

```text
PowerShell.Lib/
  ModernUI/
    ModernUI.ps1
    config.json
    VERSION
    VERSION.md
    BUGFIXES.md
    CHANGELOG.md
    QUICKSTART.md
    README.md
    PNG/
      appicon.png
      ModernUI-WinBG.png
      appscreen.png
      axn-winclose-normal.png
      axn-winclose-hover.png
      ...
    WPF/
      ModernUI.xaml
```

---

## 3. Configuration (config.json)

`config.json` is the central configuration file for ModernUI. Important
sections:

- `app`
  - `version`: `"1.00.02"`
  - `name`: `"ModernUI"`
  - `description`, `developer`, `website` for metadata.

- `debug`
  - `file`: Name of the log file (e.g. `"runtime.log"`).
  - `enabled`: `"true"` or `"false"`.
  - `datetime`: Timestamp format used in log entries.
  - `severityLevel`: Labels and icons for `INFO`, `WARN`, `ERROR`,
    `DEBUG`.

- `window`
  - Basic window configuration (title, width, height, startup location).

- `paths`
  - PNG file names for window icon, background and window control icons.
  - `appscreenImage` defines which image is used for the main screen
    preview.

- `screen`
  - XAML files for the main window and additional popups.

**Tip:** Keep `config.json` under version control and treat it as a
primary part of the application.

---

## 4. Running ModernUI

1. Open a PowerShell 7 console.
2. Navigate to the ModernUI folder:

   ```powershell
   Set-Location "<path-to-repo>\PowerShell.Lib\ModernUI"
   ```

3. Run the ModernUI script:

   ```powershell
   .\ModernUI.ps1
   ```

4. The main window should open with:
   - A frameless Modern UI styled window.
   - Background image from `config.paths.backgroundImage`.
   - A centered title `ModernUI` and version label `v1.00.02`.
   - An app screen preview showing `appscreen.png`.
   - Footer text: `Written by Praetoriani` and
     `Now available on GitHub`.

If logging is enabled in `config.json`, a log file (e.g. `runtime.log`)
will be created in the ModernUI root directory.

---

## 5. Logging behaviour

- When `debug.enabled` is set to `"true"`:
  - The log file defined in `debug.file` is created (or overwritten) at
    start.
  - All important events are written using `Write-LogEntry`.

- When `debug.enabled` is set to `"false"`:
  - No log file is created.
  - The script will only output minimal information to the console.

Log entries follow this structure:

```text
[yyyy.MM.dd ; HH:mm:ss] [ℹ️ INFO]  → Example message
```

Format and icons are fully controlled by `config.json`.

---

## 6. Close button behaviour

- The close button in the title bar is implemented as a `Label` with an
  `Image` child.
- The normal and hover icons are configured via:
  - `paths.winaxnCloseImage`
  - `paths.winaxnCloseHover`
- On hover, the image switches to the hover icon.
- On leaving the button, the image switches back to the normal icon.
- On click (preview mouse left button down), the window closes and the
  event is marked as handled.

---

## 7. Customising ModernUI

You can adjust the look and behaviour of ModernUI without changing the
PowerShell code in many cases:

- Change PNG files in the `PNG` folder.
- Adjust image file names and window properties in `config.json`.
- Extend or modify the layout in `WPF/ModernUI.xaml`.

If you add new windows (e.g. Help or About screens):

- Place the XAML files in `ModernUI/WPF/`.
- Reference them in `config.screen`.
- Load them from PowerShell similarly to the main window.

---

## 8. Where to look next

- **`ModernUI.ps1`** – main entry point, logging, XAML loading and
  resource wiring.
- **`WPF/ModernUI.xaml`** – visual layout of the main window.
- **`config.json`** – core configuration for the application.
- **`CHANGELOG.md`** – overview of what changed in v1.00.02.
- **`BUGFIXES.md`** – details about fixed issues in this version.
