# PowerEdge v1.00.00

> **A PowerShell/WPF application that hosts a Microsoft Edge (WebView2) instance**  
> to display locally stored web applications (HTML files) in a modern, frameless window.

---

## Overview

PowerEdge bridges the gap between PowerShell and modern web UIs. It opens a sleek, custom-styled WPF window embedding a full Microsoft Edge WebView2 browser instance, then loads a local HTML file (your web application) inside it. This makes it ideal for displaying PowerShell-generated dashboards, admin UIs, or any HTML/JS/CSS-based web app without requiring a system-wide browser installation.

---

## Directory Structure

```
PowerEdge\
│
├── .gui\
│   └── main.window.xml          ← WPF/XAML UI definition (loaded externally)
│
├── lib\                         ← Place WebView2 DLLs here (see Setup below)
│   ├── Microsoft.Web.WebView2.Core.dll
│   └── Microsoft.Web.WebView2.Wpf.dll
│
├── webapp\
│   └── index.html               ← Default demo web application
│
├── PowerEdge.ps1                ← Main entry point / launcher
└── README.md                    ← This file
```

---

## Requirements

| Requirement                        | Version / Notes                                               |
|------------------------------------|---------------------------------------------------------------|
| PowerShell                         | 5.1 or higher (7.x recommended)                              |
| .NET Framework / .NET              | 4.7.2 or higher (WPF dependency)                             |
| **Microsoft Edge WebView2 Runtime**| Must be installed — [Download here][wv2-runtime]             |
| **WebView2 SDK DLLs** (in `.\lib\`)| From NuGet package `Microsoft.Web.WebView2` — [NuGet link][wv2-nuget] |
| Windows                            | Windows 10 / 11                                              |

---

## Setup — Getting the WebView2 DLLs

PowerEdge requires two DLL files from the [Microsoft.Web.WebView2][wv2-nuget] NuGet package.

### Option A — Manual Download (Recommended for v1.00.00)

1. Go to: https://www.nuget.org/packages/Microsoft.Web.WebView2
2. Click **Download package** (`.nupkg` file)
3. Rename the `.nupkg` file to `.zip` and extract it
4. Navigate into the extracted folder: `lib\net45\`
5. Copy these two files into `PowerEdge\lib\`:
   - `Microsoft.Web.WebView2.Core.dll`
   - `Microsoft.Web.WebView2.Wpf.dll`

### Option B — Via NuGet CLI

```powershell
# Run in the PowerEdge root directory
nuget install Microsoft.Web.WebView2 -OutputDirectory .\nuget-packages
# Then copy the DLLs from .\nuget-packages\Microsoft.Web.WebView2.x.x.x\lib\net45\ into .\lib\
```

### Option C — Via dotnet CLI

```powershell
dotnet add package Microsoft.Web.WebView2
# DLLs will be in: %USERPROFILE%\.nuget\packages\microsoft.web.webview2\<version>\lib\net45\
```

> **WebView2 Runtime:** The runtime is usually already installed on Windows 11 systems.  
> If not, download from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/

---

## Usage

### Launch with default demo app

```powershell
.\PowerEdge.ps1
# Loads .\webapp\index.html by default
```

### Launch with a custom HTML file

```powershell
.\PowerEdge.ps1 -WebAppPath ".\webapp\my-dashboard.html"
```

### Launch with a custom window title

```powershell
.\PowerEdge.ps1 -WebAppPath "C:\Tools\admin-panel.html" -WindowTitle "Admin Panel"
```

### Verbose output for debugging

```powershell
.\PowerEdge.ps1 -WebAppPath ".\webapp\index.html" -Verbose
```

---

## UI Controls

| Control             | Action                         |
|---------------------|--------------------------------|
| Title bar drag      | Move the window                |
| Yellow dot button   | Minimize window                |
| Green dot button    | Maximize / Restore window      |
| Red dot button      | Close application              |

---

## Customizing Your Web App

Place your HTML file in `.\webapp\` (or any accessible path) and launch PowerEdge pointing to it.  
The WebView2 instance supports the full modern web stack:

- HTML5, CSS3, JavaScript (ES2023+)
- Web APIs (Fetch, LocalStorage, WebSockets, etc.)
- Any JS framework (React, Vue, Angular, etc.) loaded via CDN or local files

---

## Architecture

```
PowerEdge.ps1  (Orchestrator)
    │
    ├── Resolves HTML path  (Resolve-WebAppPath)
    ├── Loads WebView2 DLLs (Import-WebView2Assemblies)
    ├── Parses XAML         (Import-XamlDefinition)
    │       └── .gui\main.window.xml
    │
    └── Launches STA Runspace
            └── WPF Window (Window.ShowDialog)
                    └── WebView2 control
                            └── file:// URI → local HTML file
```

All functions return a standardized `PSCustomObject` status object:
- `code = 0` → Success
- `code = -1` → Error (details in `.msg`)

---

## Roadmap

| Version    | Planned Features                                              |
|------------|---------------------------------------------------------------|
| **1.00.00**| Core functionality: WPF window + WebView2 + local HTML load   |
| **1.01.00**| Config file support, window state persistence, custom icon    |
| **1.02.00**| PowerShell ↔ JavaScript bridge (PostWebMessageAsJson)         |
| **1.10.00**| Multi-tab support, navigation history, bookmarks              |
| **2.00.00**| Profile-aware launch (integration with PSAppRocket)           |

---

## Author

**Praetoriani** — https://github.com/praetoriani

[wv2-runtime]: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
[wv2-nuget]: https://www.nuget.org/packages/Microsoft.Web.WebView2
