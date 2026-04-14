<p align="center">
  <img src=".logo/PowerEdge-Original-Poster-Slogan.png" width="640" alt="PowerEdge - A PowerShell WPF Host for Microsoft Edge WebView2">
</p>

---

# PowerEdge v1.01.01

> **A PowerShell/WPF application that hosts a Microsoft Edge (WebView2) instance**
> to display locally stored web applications (HTML files) in a modern, frameless window.

---

## Overview

PowerEdge bridges the gap between PowerShell and modern web UIs. It opens a sleek, custom-styled WPF window embedding a full Microsoft Edge WebView2 browser instance, then loads a local HTML file (your web application) inside it. This makes it ideal for displaying PowerShell-generated dashboards, admin UIs, or any HTML/JS/CSS-based web app without requiring a system-wide browser installation.

As of v1.01.01, PowerEdge supports an integrated HTTP server (LocalServer HttpListener), a config-driven architecture via `config.json`, VPDLX logging engine integration, and a modular function library.

---

## Directory Structure

```
PowerEdge\
|
|-- data\
|   |-- config.json                  <- Application configuration (all paths, server settings)
|   |
|   |-- core\                        <- Core modules and WebView2 DLLs
|   |   |-- VPDLX\                   <- VPDLX logging engine module
|   |   |   `-- VPDLX.psd1           <- Module manifest (loaded at startup)
|   |   |-- lib\                     <- WebView2 SDK DLLs
|   |   |   |-- Microsoft.Web.WebView2.Core.dll
|   |   |   `-- Microsoft.Web.WebView2.Wpf.dll
|   |   `-- localserver.ps1          <- LocalServer HttpListener (HTTP server)
|   |
|   |-- fxlib\                       <- PowerShell function library (dot-sourced at startup)
|   |   `-- *.ps1
|   |
|   |-- host\                        <- Web application root (served by HTTP server)
|   |   `-- home.html                <- Default landing page
|   |
|   `-- ui\
|       `-- main.window.xml          <- WPF/XAML UI definition (loaded externally)
|
|-- pe.store\                        <- WebView2 user data directory (auto-created)
|
|-- PowerEdge.ps1                    <- Main entry point / launcher
|-- PowerEdge.ico                    <- Application icon
|-- CHANGELOG.md                     <- Version history
`-- README.md                        <- This file
```

---

## Requirements

| Requirement                              | Version / Notes                                                       |
|------------------------------------------|-----------------------------------------------------------------------|
| PowerShell                               | 5.1 or higher (7.x recommended)                                       |
| .NET Framework / .NET                    | 4.7.2 or higher (WPF dependency)                                      |
| **Microsoft Edge WebView2 Runtime**      | Must be installed — [Download here][wv2-runtime]                      |
| **WebView2 SDK DLLs** (in `data\core\lib\`) | From NuGet package `Microsoft.Web.WebView2` — [NuGet link][wv2-nuget] |
| Windows                                  | Windows 10 / 11                                                       |

---

## Setup — Getting the WebView2 DLLs

PowerEdge requires two DLL files from the [Microsoft.Web.WebView2][wv2-nuget] NuGet package.

### Option A — Manual Download

1. Go to: https://www.nuget.org/packages/Microsoft.Web.WebView2
2. Click **Download package** (`.nupkg` file)
3. Rename the `.nupkg` file to `.zip` and extract it
4. Navigate into the extracted folder: `lib\net45\`
5. Copy these two files into `PowerEdge\data\core\lib\`:
   - `Microsoft.Web.WebView2.Core.dll`
   - `Microsoft.Web.WebView2.Wpf.dll`

### Option B — Via NuGet CLI

```powershell
# Run in the PowerEdge root directory
nuget install Microsoft.Web.WebView2 -OutputDirectory .\nuget-packages
# Then copy the DLLs from .\nuget-packages\Microsoft.Web.WebView2.x.x.x\lib\net45\ into .\data\core\lib\
```

### Option C — Via dotnet CLI

```powershell
dotnet add package Microsoft.Web.WebView2
# DLLs will be in: %USERPROFILE%\.nuget\packages\microsoft.web.webview2\<version>\lib\net45\
```

> **WebView2 Runtime:** The runtime is usually already installed on Windows 11 systems.
> If not, download from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/

---

## Configuration

All paths, server settings, and application metadata are defined in `data\config.json`. PowerEdge reads this file at startup and makes the configuration available globally as `$peCore`.

Key settings in `config.json`:

| Key                      | Description                                          |
|--------------------------|------------------------------------------------------|
| `appinfo.name`           | Application name                                     |
| `appinfo.version`        | Application version                                  |
| `appcore.uidata`         | Relative path to the UI data directory               |
| `appcore.webdata`        | Relative path to the web/host directory              |
| `appcore.libdata`        | Relative path to the WebView2 DLL directory          |
| `httpserver.active`      | `true` / `false` — Enable/disable the HTTP server    |
| `httpserver.domain`      | Server hostname (e.g. `localhost`)                   |
| `httpserver.port`        | Server port (e.g. `8080`)                            |
| `httpserver.home`        | Default home page filename (e.g. `home.html`)        |
| `addon`                  | Array of add-on module paths (e.g. VPDLX)            |

---

## Usage

### Launch with HTTP server (default when `httpserver.active = true`)

```powershell
.\PowerEdge.ps1
# Loads home page via http://localhost:8080/home.html
```

### Launch with a specific HTML file

```powershell
.\PowerEdge.ps1 -httpRoot ".\data\host\my-dashboard.html"
```

### Launch with a custom window title

```powershell
.\PowerEdge.ps1 -httpRoot ".\data\host\index.html" -WindowTitle "My Dashboard"
```

### Launch hidden, reveal after delay

```powershell
.\PowerEdge.ps1 -Hidden -Timeout 3000
# Starts hidden in the background, becomes visible after 3 seconds
```

### Verbose output for debugging

```powershell
.\PowerEdge.ps1 -Verbose
```

---

## UI Controls

| Control            | Action                        |
|--------------------|-------------------------------|
| Title bar drag     | Move the window               |
| Yellow dot button  | Minimize window               |
| Green dot button   | Maximize / Restore window     |
| Red dot button     | Close application             |

---

## Architecture

```
PowerEdge.ps1 (Orchestrator)
|
|-- Loads config.json -> $peCore
|-- Imports VPDLX logging module (data\core\VPDLX\VPDLX.psd1)
|-- Dot-sources function library (data\fxlib\*.ps1)
|
|-- [if httpserver.active == true]
|   `-- Starts LocalServer HttpListener (data\core\localserver.ps1)
|       Serves files from data\host\ on http://localhost:8080/
|
|-- Launches STA Runspace
    `-- WPF Window (data\ui\main.window.xml)
        `-- WebView2 control
            `-- Navigates to http://localhost:8080/home.html
                OR file:// URI (if HTTP server is disabled)
```

All functions return a standardized `PSCustomObject` status object:
- `code = 0` -> Success
- `code = -1` -> Error (details in `.msg`)

---

## Roadmap

| Version       | Status      | Features                                                                             |
|---------------|-------------|--------------------------------------------------------------------------------------|
| **1.00.00**   | Released    | Core functionality: WPF window + WebView2 + local HTML load                          |
| **1.00.01**   | Released    | Config file support, external XAML, modular function library                         |
| **1.00.02**   | Released    | HTTP server integration, improved startup, window polish                             |
| **1.01.01**   | **Current** | VPDLX logging engine integration, HTTP server conditional startup, updated home.html |
| **1.02.00**   | Planned     | PowerShell <-> JavaScript bridge (PostWebMessageAsJson)                              |
| **2.00.00**   | Planned     | Profile-aware launch (integration with PSAppRocket)                                  |

---

## Author

**Praetoriani** — https://github.com/praetoriani

[wv2-runtime]: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
[wv2-nuget]: https://www.nuget.org/packages/Microsoft.Web.WebView2
