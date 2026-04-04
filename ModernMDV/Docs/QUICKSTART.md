# ModernMDV — Quickstart Guide

***

## Requirements
- PowerShell 7.0 or higher
- .NET Framework 4.8+ **or** .NET 6+
- Windows 10 / 11

***

## First Run
```powershell
# Standard launch
.\ModernMDV.ps1

# Open a file directly on startup
.\ModernMDV.ps1 -MarkdownFile "C:\Docs\README.md"
```

***

## Adding Your Graphics
Place all PNG files (20×20 px, 32-bit RGBA) in the `./PNG/` folder:

| File name                 | Used for                   |
|---------------------------|----------------------------|
| appicon.png               | Window icon (title bar)    |
| axn-winclose-normal.png   | Close button (normal)      |
| axn-winclose-hover.png    | Close button (hover)       |
| axn-winmin-normal.png     | Minimize (normal)          |
| axn-winmin-hover.png      | Minimize (hover)           |
| axn-winmax-normal.png     | Maximize (normal)          |
| axn-winmax-hover.png      | Maximize (hover)           |
| axn-openfile-normal.png   | Open File (normal)         |
| axn-openfile-hover.png    | Open File (hover)          |
| axn-info-normal.png       | Info/About (normal)        |
| axn-info-hover.png        | Info/About (hover)         |
| axn-help-normal.png       | Help (normal)              |
| axn-help-hover.png        | Help (hover)               |
| axn-settings-normal.png   | Settings (normal)          |
| axn-settings-hover.png    | Settings (hover)           |

***

## Migrating to Base64 (UI.lib)
```powershell
# Convert a PNG to Base64 and copy to clipboard
[Convert]::ToBase64String(
    [IO.File]::ReadAllBytes(".\PNG\axn-winclose-normal.png")
) | Set-Clipboard
```
Paste the result into the matching `$UILib_*` variable in `.\Lib\UI.lib`.
Once all variables are filled, the `./PNG/` folder is no longer needed.

***

## Keyboard Shortcuts
| Shortcut   | Action              |
|------------|---------------------|
| Ctrl+O     | Open Markdown file  |
| Ctrl+W     | Close current file  |
| Ctrl+,     | Open Settings       |
| F1         | Open Help           |
| Alt+F4     | Quit application    |

***
Made with 💖 in Munich (Bavaria, Germany)
