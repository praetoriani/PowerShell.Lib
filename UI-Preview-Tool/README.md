# UI-Preview-Tool

A small, standalone **WPF preview tool** for PowerShell developers to quickly view **XAML/XML files** without running the full application.

> **The problem it solves:** When you build PowerShell GUIs, you often tweak the layout (e.g. "does this button look better a few pixels further to the right?"). Launching the whole application just to check a small change is slow and tedious. **UI-Preview-Tool** lets you open a XAML/XML file and see an instant, live preview.

---

## Table of Contents

- [Features](#features)
- [Why this tool?](#why-this-tool)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Demo files](#demo-files)
- [How the XAML cleanup works](#how-the-xaml-cleanup-works)
- [Documentation](#documentation)
- [License](#license)
- [Credits](#credits)

---

## Features

- **Inline preview** – Renders the content of `Window`/`UserControl` directly in the tool (window resources such as styles are preserved).
- **Auto-reload** – When the file changes on disk, the preview reloads automatically (400 ms debounce). Perfect for fast iteration.
- **Zoom** – Fit-to-window, zoom in/out, reset to 100 %. The preview starts at **100 %** by default.
- **Centered preview** – Content is centered horizontally and vertically in the preview area (still scrolls when larger than the area).
- **Drag & drop** – Drag a file into the window to open it.
- **Recent files** – Recently opened files are remembered (stored in `ui-preview-recent.json`), with a **Clear History** button.
- **Show as Window** – Display Window-based XAML as a real, separate window.
- **View Code** – View the raw code of the current file in a read-only quick-view window.
- **Robust, layered XAML cleanup** – Removes event handlers, `x:Class`, `mc:Ignorable`, `d:` attributes, custom namespaces and unresolvable bindings – only as much as necessary.
- **Keyboard shortcuts** – `Ctrl+O` (open), `Ctrl+R` / `F5` (reload).

---

## Why this tool?

| Script | Strength | Weakness |
|--------|----------|----------|
| `WPF-XAML-Preview.ps1` | Loads XAML reliably (minimal, safe cleanup) | No own UI – only a file dialog + O/Q console menu |
| `XML-XAML-Preview.ps1` | Has a small UI | Often fails because it cleans up **too aggressively** (removes `xmlns`, bindings, styles, resource dictionaries) and thereby breaks valid XAML |
| **`UI-Preview-Tool.ps1`** | **Own, nice WPF UI** + robust, **layered** XAML cleanup | – |

The core problem of `XML-XAML-Preview.ps1` was the excessive cleanup. `UI-Preview-Tool.ps1` instead adopts the proven, minimally invasive approach of `WPF-XAML-Preview.ps1` and only escalates the cleanup **when loading actually fails**.

---

## Requirements

- Windows 10/11
- Windows PowerShell 5.1 **or** PowerShell 7+ (Windows)
- No additional modules needed – only the WPF assemblies built into Windows.

---

## Installation

1. Download or clone this folder into your `PowerShell.Lib` repository (or anywhere you like).
2. No installation required – just run the script.

---

## Usage

### Start

```powershell
# From the script's folder:
.\UI-Preview-Tool.ps1

# Or from anywhere:
powershell -File "C:\Path\To\UI-Preview-Tool.ps1"
```

On startup the console window is hidden and the tool's interface is shown. When the tool is closed, the console is restored.

### Operation

1. **Open a file** via the `Open...` button, `Ctrl+O`, or drag & drop into the window.
2. The preview appears immediately in the right-hand area – by default at **100 % zoom** and **centered**.
3. **Auto-reload** is enabled by default: save your XAML file in your editor and the preview updates automatically.
4. Use the zoom buttons (`-`, `+`, `Fit`, `100%`) to adjust the display.
5. `Show as Window` additionally opens Window-based XAML as a real window.
6. `View Code` shows the raw code of the current file in a read-only window.
7. `Clear History` (bottom of the left-hand panel) empties the recent files list.

---

## Demo files

The folder includes several demo XAML files you can open to try the tool:

| File | What it shows |
|------|---------------|
| `Example-Test.xaml` | A simple window with header, bullet list and sample controls |
| `Complex-Layout-Test.xaml` | A two-column layout with navigation, tabs, a DataGrid and a status bar |
| `Simple-Form-Demo.xaml` | A basic input form with labels, text boxes and buttons |
| `DataGrid-Demo.xaml` | A window demonstrating a DataGrid with a toolbar |

---

## How the XAML cleanup works

XAML files from Visual Studio or PowerShell projects often contain references that do not exist in a standalone preview (code-behind methods, custom controls, data contexts). The tool cleans up the XAML in **three stages** – it starts minimal and only escalates on errors:

| Stage | Removes |
|-------|---------|
| **0 (always)** | `x:Class`, `mc:Ignorable`, `d:` attributes, event handlers (`Click`, `Loaded`, `TextChanged`, ...), `x:Name` → `Name` |
| **1 (on error)** | Custom namespace declarations (`xmlns:local="clr-namespace:..."`) and custom elements (`<local:MyControl/>`) |
| **2 (on error)** | Bindings (`{Binding ...}`, `{TemplateBinding ...}`) and resource references (`{StaticResource ...}`, `{DynamicResource ...}`) |

As a result, **standard WPF controls, styles and layouts** (Grid, StackPanel, TabControl, DataGrid, ...) are rendered unchanged.

---

## Documentation

- **English:** [`Documentation.en.md`](Documentation.en.md)
- **German:** [`Documentation.de.md`](Documentation.de.md)

---

## License

This project is licensed under the **Apache License 2.0**. See the [`LICENSE`](LICENSE) file in the repository for details.

---

## Credits

- **Author:** [praetoriani](https://github.com/praetoriani)
- **Contributor:** [paladin-xerox](https://github.com/paladin-xerox)
