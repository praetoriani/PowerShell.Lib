# UI-Preview-Tool

A small, standalone WPF tool for PowerShell developers to **quickly preview XAML/XML files** without having to run the full application.

The typical use case: you change just a few pixels in your PowerShell GUI (for example, moving a button a bit further to the right) and want to see immediately whether it looks better – without restarting the whole application.

---

## Why this tool?

| Script | Strength | Weakness |
|--------|----------|----------|
| `WPF-XAML-Preview.ps1` | Loads XAML reliably (minimal, safe cleanup) | No own UI – only a file dialog + O/Q console menu |
| `XML-XAML-Preview.ps1` | Has a small UI | Often fails because it cleans up **too aggressively** (removes `xmlns`, bindings, styles, resource dictionaries) and thereby breaks valid XAML |
| **`UI-Preview-Tool.ps1`** | **Own, nice WPF UI** + robust, **layered** XAML cleanup | – |

The core problem of `XML-XAML-Preview.ps1` was the excessive cleanup. `UI-Preview-Tool.ps1` instead adopts the proven, minimally invasive approach of `WPF-XAML-Preview.ps1` and only escalates the cleanup **when loading actually fails**.

---

## Features

- **Inline preview** – The content of `Window`/`UserControl` is rendered directly in the tool (window resources such as styles are preserved).
- **Auto-reload** – When you change the file on disk, the preview reloads automatically (with 400 ms debounce). Perfect for fast iteration.
- **Zoom** – Fit-to-window, zoom in/out, reset to 100 %. By default the preview is shown at **100 %**.
- **Centered preview** – The content is centered horizontally and vertically in the preview area (it still scrolls when it is larger than the area).
- **Drag & drop** – Simply drag a file into the window.
- **Recent files** – Recently opened files (stored in `ui-preview-recent.json`), including a **Clear History** button to empty the list.
- **Show as Window** – Additionally display Window-based XAML as a real, separate window.
- **View Code** – Shows the raw code of the current file in a read-only quick-view window (view only, not editable).
- **Robust, layered XAML cleanup** – removes event handlers, `x:Class`, `mc:Ignorable`, `d:` attributes, custom namespaces and unresolvable bindings – only as much as necessary.
- **Keyboard shortcuts** – `Ctrl+O` (open), `Ctrl+R` / `F5` (reload).

---

## Requirements

- Windows 10/11
- Windows PowerShell 5.1 **or** PowerShell 7+ (Windows)
- No additional modules needed – only the WPF assemblies built into Windows.

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
2. The preview appears immediately in the right-hand area – by default at **100 % zoom** and **centered** in the preview area.
3. **Auto-reload** is enabled by default: save your XAML file in your editor and the preview updates automatically.
4. Use the zoom buttons (`-`, `+`, `Fit`, `100%`) to adjust the display.
5. `Show as Window` additionally opens Window-based XAML as a real window.
6. `View Code` shows the raw code of the current file in a read-only window.
7. `Clear History` (bottom of the left-hand panel) empties the recent files list.

---

## How the XAML cleanup works

XAML files from Visual Studio or PowerShell projects often contain references that do not exist in a standalone preview (code-behind methods, custom controls, data contexts). The tool cleans up the XAML in **three stages** – it starts minimal and only escalates on errors:

| Stage | Removes |
|-------|---------|
| **0 (always)** | `x:Class`, `mc:Ignorable`, `d:` attributes, event handlers (`Click`, `Loaded`, `TextChanged`, ...), `x:Name` → `Name` |
| **1 (on error)** | Custom namespace declarations (`xmlns:local="clr-namespace:..."`) and custom elements (`<local:MyControl/>`) |
| **2 (on error)** | Bindings (`{Binding ...}`, `{TemplateBinding ...}`) and resource references (`{StaticResource ...}`, `{DynamicResource ...}`) |

As a result, **standard WPF controls, styles and layouts** (Grid, StackPanel, TabControl, DataGrid, ...) are rendered unchanged – exactly what was broken in `XML-XAML-Preview.ps1` by the aggressive cleanup.

---

## Project structure

```
UI-Preview-Tool/
├── UI-Preview-Tool.ps1              ← The tool (English code, commented)
├── README.md                       ← English overview
├── Documentation.de.md             ← German manual
├── Documentation.en.md             ← English manual (this file)
├── .gitignore                      ← Only repo-relevant files
├── Example-Test.xaml               ← Demo file
├── Complex-Layout-Test.xaml        ← Demo file
├── Simple-Form-Demo.xaml           ← Demo file
├── DataGrid-Demo.xaml              ← Demo file
└── ui-preview-recent.json           ← Created automatically (recent files)
```

---

## Technical notes

- **Inline preview:** A `Window` or `UserControl` cannot be embedded inside another window. The tool therefore extracts the content (`Content`) and renders it in the preview area. Window resources are carried over into the preview container so that styles still apply.
- **Centering:** The preview container sits inside a `Grid` whose `MinWidth`/`MinHeight` are bound to the ScrollViewer's size via XAML binding. This keeps the content centered when it is smaller than the area, while still allowing scrolling when it is larger.
- **Auto-reload:** A `FileSystemWatcher` monitors the file. Because its events arrive on a background thread, they are marshaled to the UI thread via the WPF `Dispatcher` and debounced with a `DispatcherTimer` (400 ms).
- **Zoom:** The preview is scaled via a `ScaleTransform` (LayoutTransform). "Fit" measures the natural size of the content and scales it to fit the viewport.
- **Recent files:** The list is stored as JSON next to the script. Files that no longer exist are automatically filtered out when loading.

---

## Error handling

- Invalid or unloadable XAML files produce a clear error message in the status bar (highlighted in red).
- The tool automatically tries all three cleanup stages before giving up.
- Loading errors do not abort the preview – the tool remains usable.

---

## License

This project is licensed under the **Apache License 2.0**. See the `LICENSE` file in the repository.

---

## Version

**v1.02.00**

- Author: praetoriani (https://github.com/praetoriani)
- Contributor: paladin-xerox (https://github.com/paladin-xerox)

### Changes in v1.02.00

- Renamed the tool to **UI-Preview-Tool**.
- Published as a standalone folder in the `PowerShell.Lib` repository.
- Added README, English/German documentation, `.gitignore` and a GitHub workflow.
- Translated the demo XAML files to English and added new demo files.

### Changes in v1.01.00

- Preview starts at **100 % zoom** by default (instead of Fit).
- Preview is displayed **centered horizontally and vertically** in the preview area.
- New **Clear History** button to empty the recent files list.
- New **View Code** option to view the raw code in a read-only window.
