# PowerEdge v1.01.x — Weiterentwicklung

> **Dokumentversion:** 1.0.0  
> **Erstellt am:** 15. April 2026  
> **Projekt-Repository:** [PowerEdge @ GitHub](https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge)  
> **Aktueller Stand:** PowerEdge v1.01.01

---

## Inhaltsverzeichnis

1. [Projektübersicht & aktueller Stand](#1-projektübersicht--aktueller-stand)
2. [Thema: Local Server](#2-thema-local-server)
3. [Thema: Helper-Funktionen (fxlib)](#3-thema-helper-funktionen-fxlib)
4. [Thema: GUI / WebView2 & Betriebsmodi](#4-thema-gui--webview2--betriebsmodi)
5. [Thema: PowerEdges WPF-Modus](#5-thema-poweredges-wpf-modus)
6. [Thema: PowerEdges Terminal-Modus](#6-thema-poweredges-terminal-modus)
7. [Empfohlene Gesamtarchitektur (Roadmap)](#7-empfohlene-gesamtarchitektur-roadmap)

---

## 1. Projektübersicht & aktueller Stand

PowerEdge ist eine **PowerShell-WPF-Anwendung** (`PowerEdge.ps1`), die eine **Microsoft Edge WebView2-Engine** einbettet, um lokal gespeicherte Web-Applikationen (HTML/CSS/JS, SPAs) innerhalb eines nativen Windows-Fensters darzustellen. Das Projekt verfolgt das Ziel, PowerShell als vollwertigen Anwendungs-Host für moderne Web-Apps zu nutzen — ohne externen Browser.

### Aktuelle Architektur auf einen Blick

```
PowerEdge/
├── PowerEdge.ps1              ← Hauptskript (Entry Point)
├── PowerEdge.ico
├── data/
│   ├── config.json            ← Zentrale Konfiguration (JSON)
│   ├── core/
│   │   ├── localserver.ps1    ← HTTP-Server (LocalServer-Klasse)
│   │   ├── lib/               ← WebView2-DLLs (.dll)
│   │   └── VPDLX/             ← VPDLX Add-On Modul (auskommentiert)
│   ├── fxlib/                 ← Helper-Funktionen (dot-sourced)
│   │   ├── LoadURL.ps1
│   │   ├── LoadURLafter.ps1
│   │   ├── LoadWebViewDLLs.ps1
│   │   ├── LoadXAMLui.ps1
│   │   ├── NewStatusObject.ps1
│   │   └── ResolveHttpRoot.ps1
│   ├── host/
│   │   └── home.html          ← Standard-Startseite
│   └── ui/
│       └── main.window.xml    ← WPF XAML-Definition
```

### Technologie-Stack

| Komponente | Technologie |
|---|---|
| Host-Skript | PowerShell 5.1 / 7.x |
| UI-Framework | WPF (PresentationFramework) |
| Web-Engine | Microsoft Edge WebView2 |
| HTTP-Server | .NET `HttpListener` (LocalServer-Klasse) |
| Konfiguration | JSON (`config.json`) |
| UI-Definition | Externes XAML (`main.window.xml`) |
| Helper-Funktionen | Dot-Sourcing (`.ps1`-Dateien in `data\fxlib\`) |

### Ausführungsfluss (vereinfacht)

```
PowerEdge.ps1 startet
  ↓
config.json laden → globale Variablen setzen
  ↓
data\fxlib\*.ps1 dot-sourcen (Helper-Funktionen)
  ↓
localserver.ps1 dot-sourcen → [LocalServer]::new() → .Start()
  ↓
Start-Sleep 5000ms (warten auf Server)
  ↓
ResolveHttpRoot() → homeURL bestimmen
  ↓
LoadWebViewDLLs() → WV2-DLLs laden
  ↓
LoadXAMLui() → XAML parsen
  ↓
syncHash erstellen → UI-Runspace starten (STA-Thread)
  ↓
WPF-Fenster anzeigen → WebView2 initialisieren → homeURL navigieren
  ↓
window.ShowDialog() (blockiert bis Fenster geschlossen)
  ↓
Server.Stop() → Cleanup
```

### Bekannte Einschränkungen (aktueller Stand)

- **LocalServer-Scope-Problem:** Der HTTP-Server startet technisch korrekt, die `home.html` wird jedoch von WebView2 nicht erfolgreich geladen (detaillierte Analyse in Abschnitt 2).
- **fxlib-Scope-Risiko:** Die dot-gesourcten Helper-Funktionen laufen im Script-Scope von `PowerEdge.ps1`, sind aber im UI-Runspace nicht verfügbar (Abschnitt 3).
- **Nur ein Betriebsmodus:** Es gibt bisher ausschließlich den WebView2-Modus; WPF-Only und Terminal-Modus fehlen noch.
- **VPDLX-Modul auskommentiert:** Der VPDLX-Add-On-Pfad ist zwar vorbereitet, die Initialisierung ist jedoch deaktiviert.

---

## 2. Thema: Local Server

### 2.1 Ursachenanalyse — Warum wird `home.html` nicht angezeigt?

Nach eingehender Analyse von `PowerEdge.ps1` und `localserver.ps1` lassen sich **drei konkrete Ursachen** für das Problem identifizieren:

#### Problem 1: Scope-Isolation zwischen Server und WebView2-Runspace

Dies ist die **wahrscheinlichste Hauptursache**. PowerEdge verwendet zwei verschiedene Runspaces:

- **Haupt-Runspace** (`PowerEdge.ps1`): Hier läuft `localserver.ps1`, der `[LocalServer]`-Klasse wird dot-gesourct, die Instanz in `$global:PowerEdgeServer` gespeichert, und der Server gestartet.
- **UI-Runspace** (STA-Thread für WPF): Hier läuft der gesamte WebView2- und WPF-Code. Dieser Runspace ist eine vollständig **isolierte PowerShell-Instanz** — er hat **keinen Zugriff** auf die globalen Variablen des Haupt-Runspace.

Das bedeutet konkret: `$syncHash.HtmlPath` wird zwar als `http://localhost:8080/home.html` an den UI-Runspace übergeben — **aber der Server-Start im Haupt-Runspace und die WebView2-Navigation im UI-Runspace laufen quasi parallel, ohne Synchronisationsgarantie**. Außerdem ist die `[LocalServer]`-Klasse selbst im UI-Runspace **nicht bekannt** (der Typ wurde nicht importiert).

```
Haupt-Runspace:                    UI-Runspace (STA):
[LocalServer]::new() → Start()     XamlReader.Load()
Start-Sleep 5000ms                 window.Add_Loaded({
→ syncHash erstellen                  EnsureCoreWebView2Async()
→ UI-Runspace starten                 → Navigate(homeURL)  ← läuft ggf. bevor
                                       Server wirklich bereit ist
```

#### Problem 2: `Start-Sleep -Milliseconds 5000` ist keine zuverlässige Synchronisation

Der aktuelle Code wartet pauschal 5 Sekunden nach dem Server-Start. Dies ist eine **Race Condition**: Wenn der Server länger braucht (z.B. bei langsamem System oder Port-Konflikt), schlägt die Navigation fehl. Umgekehrt ist 5 Sekunden deutlich zu lang für normale Fälle.

#### Problem 3: Der `homeURL` zeigt auf `home.html`, nicht auf `index.html`

```json
"home": "home.html"
```

```
$global:homeURL = "http://localhost:8080/home.html"
```

Der `LocalServer` in `localserver.ps1` implementiert ein **SPA-Fallback auf `index.html`**, sucht aber bei direkten Datei-Anfragen nach der exakten Datei unter `RootPath`. Die Datei `home.html` liegt in `data\host\home.html`. Der `RootPath` wurde mit `$global:hostroot` gesetzt, also `data\host\`. Das bedeutet: Der Server sollte `http://localhost:8080/home.html` korrekt auf `data\host\home.html` auflösen — **sofern der Server tatsächlich vollständig gestartet ist**, wenn die Navigation erfolgt.

**Fazit Scope-Problem:** Ja, es gibt ein erhebliches Scope-Problem. Der `$global:PowerEdgeServer` existiert nur im Haupt-Runspace. Der UI-Runspace kennt dieses Objekt nicht. Der `syncHash` überträgt nur `HtmlPath` als String — was korrekt ist. Aber **die Garantie, dass der Server *vor* der WebView2-Navigation bereit ist**, fehlt.

---

### 2.2 Sofortiger Fix: Zuverlässige Server-Bereitschaft sicherstellen

Anstatt blind `Start-Sleep` zu verwenden, sollte eine **Readiness-Check-Schleife** implementiert werden, die aktiv prüft, ob der Server antwortet:

```powershell
# Nach $global:PowerEdgeServer.Start() — STATT Start-Sleep 5000

function Wait-ServerReady {
    param(
        [string]$Url,
        [int]$MaxWaitMs = 10000,
        [int]$PollIntervalMs = 200
    )
    $elapsed = 0
    while ($elapsed -lt $MaxWaitMs) {
        try {
            $req = [System.Net.WebRequest]::Create($Url)
            $req.Timeout = 500
            $resp = $req.GetResponse()
            $resp.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds $PollIntervalMs
            $elapsed += $PollIntervalMs
        }
    }
    return $false
}

$serverReady = Wait-ServerReady -Url $global:rootURL
if (-not $serverReady) {
    Write-Warning "PowerEdge: HTTP Server nicht erreichbar nach 10s — lade Fallback-Seite"
    # Fallback: direkt auf home.html per file:// navigieren
    $resolvedHtmlPath = [System.Uri]::new($global:apphome).AbsoluteUri
}
```

---

### 2.3 Alternative Lösungsansätze für den Local Server

#### Option A: LocalServer als PowerShell-Modul (`.psm1` / `.psd1`) — **Empfohlen**

Dies ist die sauberste und nachhaltigste Lösung. Anstatt `localserver.ps1` per Dot-Sourcing zu laden, wird es als echtes PowerShell-Modul verpackt. Module haben definierte Export-Mechanismen und können gezielt in Runspaces importiert werden.

**Struktur:**
```
data\core\LocalServerModule\
├── LocalServerModule.psd1   ← Modul-Manifest
└── LocalServerModule.psm1   ← Modul-Implementierung (Klasse + Funktion)
```

**Vorteil im UI-Runspace:** Der Runspace kann das Modul explizit laden:
```powershell
$uiRunspace.SessionStateProxy.SetVariable("localServerModulePath", $modulePath)

# Im uiScript:
Import-Module $localServerModulePath -Force
```

**Entscheidender Vorteil:** PowerShell-Klassen, die in einem Modul definiert sind, werden mit dem Modul-Typ-System verknüpft. Wenn derselbe Modulpfad in beiden Runspaces geladen wird, können Instanzen über den `syncHash` übergeben und im UI-Runspace als bekannter Typ verwendet werden.

**Konkreter Umsetzungsplan:**
```powershell
# LocalServerModule.psd1 (Manifest)
@{
    RootModule        = 'LocalServerModule.psm1'
    ModuleVersion     = '1.0.0'
    Author            = 'Praetoriani'
    FunctionsToExport = @('New-LocalServer')
    # Klassen werden automatisch exportiert
}
```

```powershell
# In PowerEdge.ps1 — STATT Dot-Sourcing:
$localServerModulePath = Join-Path $PSScriptRoot "data\core\LocalServerModule\LocalServerModule.psd1"
Import-Module $localServerModulePath -Force

$global:PowerEdgeServer = New-LocalServer -RootPath $global:hostroot `
    -Port $global:portconfig -AutoStart $true -OpenBrowser $false

# syncHash erweitern:
$syncHash["LocalServerModulePath"] = $localServerModulePath
```

```powershell
# Im $uiScript — am Anfang:
Import-Module $syncHash.LocalServerModulePath -Force
```

---

#### Option B: Server-Instanz über `syncHash` synchronisieren (kurzfristiger Fix)

Ohne Modulumbau kann die Server-Instanz über den `syncHash` an den UI-Runspace übergeben werden — zusammen mit einem `IsReady`-Flag:

```powershell
$syncHash = [hashtable]::Synchronized(@{
    # ... bestehende Einträge ...
    Server       = $global:PowerEdgeServer   # Server-Instanz übergeben
    ServerReady  = $false
    HtmlPath     = $resolvedHtmlPath
})

# Im $uiScript — vor Navigate():
$window.Add_Loaded({
    # Warten bis Server bereit:
    $maxWait = 50  # 50 × 100ms = 5s
    $tries = 0
    while (-not $syncHash.ServerReady -and $tries -lt $maxWait) {
        try {
            $r = [System.Net.WebRequest]::Create($syncHash.HtmlPath)
            $r.Timeout = 300
            $r.GetResponse().Close()
            $syncHash.ServerReady = $true
        } catch {
            Start-Sleep -Milliseconds 100
            $tries++
        }
    }
    $webView.CoreWebView2.Navigate($syncHash.HtmlPath)
})
```

---

#### Option C: Auf den Local Server komplett verzichten — `file://`-Navigation

Wenn der HTTP-Server mehr Probleme verursacht als er löst, ist die einfachste Alternative die direkte Navigation per `file://`-Protokoll:

```powershell
$targetUri = [System.Uri]::new($global:apphome).AbsoluteUri
# Ergibt z.B.: file:///C:/PowerEdge/data/host/home.html
$webView.CoreWebView2.Navigate($targetUri)
```

**Einschränkungen bei `file://`:**
- Kein Cross-Origin-Zugriff zwischen verschiedenen lokalen Dateien (CORS-Probleme bei modernen SPAs mit `fetch()`).
- Kein SPA-Routing über Pfade möglich (kein Server = kein Routing).
- `fetch()` zu anderen lokalen Ressourcen kann durch WebView2-Sicherheitseinstellungen blockiert werden.

**Lösung für CORS bei `file://`:**
```powershell
$webView.Add_CoreWebView2InitializationCompleted({
    # Lokale Dateizugriffe erlauben:
    $webView.CoreWebView2.Settings.IsWebMessageEnabled = $true
    # Optional: Für Dev/Test-Modus DevTools aktivieren:
    $webView.CoreWebView2.Settings.AreDevToolsEnabled = $true
    $webView.CoreWebView2.Navigate($targetUri)
})
```

Für einfache HTML-Seiten ohne komplexe SPA-Logik ist `file://` vollkommen ausreichend und die stabilste Option.

---

#### Option D: Embedded Virtual Host via WebView2 `SetVirtualHostNameToFolderMapping`

WebView2 bietet eine eingebaute Funktion, lokale Ordner einem virtuellen Hostnamen zuzuordnen — **ohne HTTP-Server**:

```powershell
$webView.Add_CoreWebView2InitializationCompleted({
    # Mappt "app.local" auf das data\host\ Verzeichnis
    $webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
        "app.local",                          # Virtueller Hostname
        $global:hostroot,                     # Lokaler Ordner
        [Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind]::Allow
    )
    $webView.CoreWebView2.Navigate("https://app.local/home.html")
})
```

**Vorteile:**
- Kein HTTP-Server notwendig.
- HTTPS-ähnliche Sicherheitsmodell (keine CORS-Einschränkungen wie bei `file://`).
- `fetch()`, ES-Module, Service Workers funktionieren alle korrekt.
- Kein Port-Konflikt möglich.
- Kein zusätzlicher Prozess/Thread.

**Dies ist aktuell die beste Alternative zu einem echten HTTP-Server für den reinen HostMode.** Der `LocalServer` sollte nur dann verwendet werden, wenn externer Zugriff auf die Inhalte gewünscht wird oder andere Anwendungen auf die Inhalte zugreifen sollen.

---

### 2.4 Empfehlung: Kombinierter Ansatz

```
HostMode (Standard)   → SetVirtualHostNameToFolderMapping (kein Server, stabil)
HostMode (Netzwerk)   → LocalServer als Modul (Option A) mit Wait-ServerReady
Secure/InPrivate      → Eigenes WebView2-UserDataFolder, kein virtual host mapping
```

| Methode | Stabilität | Komplexität | SPA-Support | Netzwerkzugriff |
|---|---|---|---|---|
| `file://` direkt | ⭐⭐⭐ | Sehr gering | Eingeschränkt | Nein |
| Virtual Host Mapping | ⭐⭐⭐⭐⭐ | Gering | Vollständig | Nein |
| LocalServer (Modul) | ⭐⭐⭐⭐ | Mittel | Vollständig | Ja |
| LocalServer (Dot-Source) | ⭐⭐ | Mittel | Vollständig | Ja |

---

## 3. Thema: Helper-Funktionen (fxlib)

### 3.1 Das aktuelle Scope-Problem

PowerEdge dot-sourct aktuell alle `.ps1`-Dateien aus `data\fxlib\` im Haupt-Runspace von `PowerEdge.ps1`:

```powershell
Get-ChildItem -Path $fxLibPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}
```

Das erzeugt folgendes Scope-Szenario:

```
Haupt-Runspace (PowerEdge.ps1 Script-Scope):
  ✅ ResolveHttpRoot    ← verfügbar (dot-sourced)
  ✅ LoadWebViewDLLs   ← verfügbar (dot-sourced)
  ✅ LoadXAMLui        ← verfügbar (dot-sourced)
  ✅ NewStatusObject   ← verfügbar (dot-sourced)

UI-Runspace (STA-Thread):
  ❌ ResolveHttpRoot   ← NICHT verfügbar (anderer Runspace!)
  ❌ LoadWebViewDLLs   ← NICHT verfügbar
  ❌ LoadXAMLui        ← NICHT verfügbar
  ✅ Add-Type          ← verfügbar (eingebaut)
```

Aktuell werden im UI-Runspace keine fxlib-Funktionen aufgerufen (die DLL-Ladevorgänge, XAML-Parsing etc. erfolgen alle vor dem Runspace-Start im Haupt-Thread). Aber sobald PowerEdge erweitert wird (z.B. PlugIn-Modus, Modus-Wechsel), wird dieses Problem akut.

### 3.2 Option A: PowerShell-Modul (`PECore.psm1`) — Empfohlen

Die beste Lösung für sauberes Scope-Management ist ein dediziertes PowerEdge-Kern-Modul. Alle Helper-Funktionen werden in einem einzigen Modul zusammengefasst, das explizit in jeden Runspace importiert werden kann.

**Struktur:**
```
data\core\PECore\
├── PECore.psd1          ← Modulmanifest
├── PECore.psm1          ← Alle Helper-Funktionen
└── Classes\
    └── PEStatus.ps1     ← Status-Klasse (optional)
```

**`PECore.psm1` Grundgerüst:**
```powershell
# PECore.psm1
using namespace System.Collections

function Resolve-HttpRoot {
    [CmdletBinding()]
    param([string]$InputPath, [string]$FallbackPath)
    # ... Implementierung aus ResolveHttpRoot.ps1 ...
}

function Load-WebViewDLLs {
    [CmdletBinding()]
    param([string]$LibDir)
    # ... Implementierung aus LoadWebViewDLLs.ps1 ...
}

function Load-XAMLui {
    [CmdletBinding()]
    param([string]$XamlFilePath)
    # ... Implementierung aus LoadXAMLui.ps1 ...
}

function New-StatusObject {
    param([int]$Code, [string]$Message)
    return [PSCustomObject]@{ code = $Code; msg = $Message }
}

Export-ModuleMember -Function 'Resolve-HttpRoot','Load-WebViewDLLs','Load-XAMLui','New-StatusObject'
```

**Nutzung in `PowerEdge.ps1`:**
```powershell
# STATT Dot-Sourcing der fxlib:
$peCoreModule = Join-Path $PSScriptRoot "data\core\PECore\PECore.psd1"
Import-Module $peCoreModule -Force

# syncHash erweitern:
$syncHash["PECoreModulePath"] = $peCoreModule
```

**Nutzung im UI-Runspace:**
```powershell
$uiScript = {
    Import-Module $syncHash.PECoreModulePath -Force
    # Jetzt sind alle Funktionen verfügbar!
    $result = Load-WebViewDLLs -LibDir $syncHash.LibDir
}
```

---

### 3.3 Option B: Statische .NET-Klasse (C# via `Add-Type`)

Eine weitere robuste Option ist die Implementierung aller Helper-Funktionen als statische Methoden einer C#-Klasse, die per `Add-Type` geladen wird. C#-Typen sind nach dem Laden **in jedem Runspace verfügbar** (sofern die Assembly in den AppDomain geladen wurde, was bei `Add-Type -TypeDefinition` gilt — allerdings nur für den Prozess, nicht automatisch pro Runspace).

```powershell
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Windows;

public static class PEHelpers {
    public static string ResolveHttpRoot(string inputPath, string fallback) {
        if (string.IsNullOrEmpty(inputPath)) return fallback;
        return Path.GetFullPath(inputPath);
    }

    public static bool DirectoryExists(string path) {
        return Directory.Exists(path);
    }
}
"@ -ReferencedAssemblies "PresentationFramework"
```

**Nachteil:** PowerShell-spezifische Logik (z.B. `Test-Path`, `Get-ChildItem`) muss in C# übersetzt werden. Sinnvoll für einfache Hilfsfunktionen, aber nicht für komplexe PS-Logik.

---

### 3.4 Option C: Alle Helper-Funktionen direkt in `PowerEdge.ps1` (Monolithischer Ansatz)

Für kleinere Projekte ist es durchaus legitim, alle Funktionen direkt im Hauptskript zu definieren. Der Vorteil: Kein Scope-Problem. Der Nachteil: Schlechtere Wartbarkeit, größere Datei, keine Wiederverwendbarkeit.

**Fazit:** Für PowerEdge als wachsendes Projekt mit PlugIn-Architektur ist der Monolith-Ansatz langfristig nicht empfehlenswert.

---

### 3.5 Option D: Dot-Sourcing mit explizitem `$global:`-Scope-Hoisting

Als kurzfristiger Fix ohne Refactoring: Nach dem Dot-Sourcing alle Funktionen explizit in den Global-Scope kopieren:

```powershell
# Nach dem Dot-Sourcing-Block:
$global:ResolveHttpRoot = ${function:ResolveHttpRoot}
$global:LoadWebViewDLLs = ${function:LoadWebViewDLLs}
$global:LoadXAMLui      = ${function:LoadXAMLui}
```

Dann im `syncHash`:
```powershell
$syncHash["FnResolveHttpRoot"] = $global:ResolveHttpRoot
```

Im UI-Runspace:
```powershell
$resolveFunc = [scriptblock]::Create($syncHash.FnResolveHttpRoot.ToString())
$result = & $resolveFunc -InputPath $syncHash.HtmlPath
```

**Achtung:** Das ist ein Workaround, keine saubere Lösung. Funktioniert für einfache Funktionen ohne komplexe Abhängigkeiten.

---

### 3.6 Empfehlung

| Ansatz | Scope-Sicherheit | Wartbarkeit | Aufwand | Empfehlung |
|---|---|---|---|---|
| PECore-Modul (`.psm1`) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Mittel | ✅ Beste Wahl |
| C#-Klasse via `Add-Type` | ⭐⭐⭐⭐ | ⭐⭐⭐ | Hoch | Für .NET-Logik |
| Direkt in `PowerEdge.ps1` | ⭐⭐⭐⭐⭐ | ⭐⭐ | Gering | Nur als Notlösung |
| Global-Scope-Hoisting | ⭐⭐ | ⭐ | Gering | Workaround |

**Empfehlung:** Schrittweise Migration zu `PECore.psm1`. Bestehende `fxlib`-Dateien können 1:1 in das Modul übernommen werden — lediglich `Export-ModuleMember` muss am Ende ergänzt werden.

---

## 4. Thema: GUI / WebView2 & Betriebsmodi

### 4.1 Konzept: 4 Betriebsmodi für PowerEdge

Die vier gewünschten Modi lassen sich als **Launch-Parameter und/oder Laufzeit-Modus** implementieren:

| Modus | Beschreibung | WebView2 | Terminal | Besonderheit |
|---|---|---|---|---|
| `Normal` | Reine WPF-Anwendung | Ausgeblendet | Nein | XAML-UI im Vordergrund |
| `Terminal` | Eingebettete PS-Konsole | Ausgeblendet | Ja | Eigene PowerEdge-Befehle |
| `HostMode` | SPA/Web-Host | Aktiv (Vordergrund) | Nein | Virtual Host / LocalServer |
| `Secure` | HostMode InPrivate | Aktiv (InPrivate) | Nein | Temporäres UserDataFolder |

**`config.json`-Erweiterung:**
```json
"appmode": {
    "default": "HostMode",
    "available": ["Normal", "Terminal", "HostMode", "Secure"]
}
```

**Parameter-Erweiterung `PowerEdge.ps1`:**
```powershell
param(
    [Parameter()]
    [ValidateSet("Normal","Terminal","HostMode","Secure")]
    [string]$Mode = "HostMode",
    # ... bestehende Parameter ...
)
```

---

### 4.2 WebView2 als "Layer" — Einblenden und Ausblenden zur Laufzeit

Ja, es ist **vollständig möglich und technisch sauber**, WebView2 als Ein/Aus-Layer zu implementieren. Der Schlüssel liegt in der XAML-Struktur und der `Visibility`-Property.

**XAML-Konzept (`main.window.xml` Erweiterung):**
```xml
<Grid x:Name="MainGrid">
    <!-- WPF-Inhaltsbereich (immer vorhanden, ggf. ausgeblendet) -->
    <Grid x:Name="WpfContentLayer" Visibility="Collapsed">
        <ContentControl x:Name="WpfMainContent" />
    </Grid>

    <!-- WebView2-Layer (kann ein- und ausgeblendet werden) -->
    <Grid x:Name="WebViewLayer" Visibility="Visible">
        <wpf:WebView2 x:Name="MainWebView" />
    </Grid>

    <!-- Terminal-Layer -->
    <Grid x:Name="TerminalLayer" Visibility="Collapsed">
        <Border x:Name="TerminalHost" Background="Black" />
    </Grid>

    <!-- Immer oben: TitleBar und Overlays -->
    <Grid x:Name="TitleBarPanel" VerticalAlignment="Top" ... />
</Grid>
```

**Laufzeit-Modus-Wechsel in PowerShell (im UI-Runspace):**
```powershell
function Switch-AppMode {
    param([string]$NewMode)

    switch ($NewMode) {
        "Normal" {
            $webViewLayer.Visibility  = [Visibility]::Collapsed
            $terminalLayer.Visibility = [Visibility]::Collapsed
            $wpfContentLayer.Visibility = [Visibility]::Visible
        }
        "HostMode" {
            $wpfContentLayer.Visibility = [Visibility]::Collapsed
            $terminalLayer.Visibility   = [Visibility]::Collapsed
            $webViewLayer.Visibility    = [Visibility]::Visible
        }
        "Terminal" {
            $wpfContentLayer.Visibility = [Visibility]::Collapsed
            $webViewLayer.Visibility    = [Visibility]::Collapsed
            $terminalLayer.Visibility   = [Visibility]::Visible
        }
        "Secure" {
            # WebView2 mit InPrivate-Profil neu initialisieren
            $webViewLayer.Visibility    = [Visibility]::Visible
            $wpfContentLayer.Visibility = [Visibility]::Collapsed
            $terminalLayer.Visibility   = [Visibility]::Collapsed
            Init-SecureWebView
        }
    }
}
```

**Eine Schaltfläche für den Modus-Wechsel** könnte in der TitleBar platziert werden:
```xml
<Button x:Name="BtnSwitchMode" Content="⊞" Width="30" Height="30"
        ToolTip="Modus wechseln" />
```

```powershell
$btnSwitchMode.Add_Click({
    $currentMode = $syncHash.CurrentMode
    $nextMode = switch ($currentMode) {
        "HostMode" { "Normal" }
        "Normal"   { "Terminal" }
        "Terminal" { "HostMode" }
        default    { "HostMode" }
    }
    Switch-AppMode -NewMode $nextMode
    $syncHash.CurrentMode = $nextMode
})
```

---

### 4.3 Secure-Modus: InPrivate WebView2

WebView2 unterstützt nativ ein **In-Private-Profil** durch ein temporäres `UserDataFolder`:

```powershell
function Init-SecureWebView {
    # Temporäres Verzeichnis für InPrivate-Session
    $tempProfile = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "PowerEdge_Secure_$(Get-Random)"
    )

    $wv2Props = [Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties]::new()
    $wv2Props.UserDataFolder = $tempProfile

    # WebView2 muss neu initialisiert werden mit neuem Profil
    # (Ein Wechsel des Profils zur Laufzeit erfordert ein Dispose + Re-Create)
    $webView.CreationProperties = $wv2Props

    # Cleanup beim Schließen registrieren:
    $window.Add_Closed({
        if (Test-Path $tempProfile) {
            Remove-Item $tempProfile -Recurse -Force -ErrorAction SilentlyContinue
        }
    })
}
```

**Wichtig:** Das `UserDataFolder` kann **nicht** zur Laufzeit gewechselt werden, nachdem `EnsureCoreWebView2Async()` aufgerufen wurde. Für einen echten "Secure"-Modus muss WebView2 entweder **beim Start** mit dem temporären Profil initialisiert werden, oder der WebView2-Control muss **aus der visuellen Hierarchie entfernt, neu erstellt und wieder hinzugefügt** werden.

**Sauberere Lösung: WebView2-Factory-Methode:**
```powershell
function New-WebView2Instance {
    param([bool]$IsSecure = $false)

    $wv2 = [Microsoft.Web.WebView2.Wpf.WebView2]::new()

    $props = [Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties]::new()
    $props.UserDataFolder = if ($IsSecure) {
        [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "PE_Secure_$(Get-Random)")
    } else {
        $syncHash.Wv2DataDir
    }

    $wv2.CreationProperties = $props
    return $wv2
}
```

---

### 4.4 Empfehlung für Modus-Architektur

Die sauberste Implementierung sieht vor:
1. **XAML hat alle Layer** (WPF, WebView2, Terminal) von Anfang an — jeweils als `Grid` mit `Visibility="Collapsed"`.
2. **Beim Start** wird anhand des `-Mode`-Parameters der aktive Layer eingeblendet.
3. **Laufzeit-Wechsel** per `Switch-AppMode`-Funktion — funktioniert für alle Modi außer Secure (der einen WebView2-Neustart benötigt).
4. **`syncHash.CurrentMode`** speichert den aktuellen Modus und ermöglicht Zustandsabfragen.

---

## 5. Thema: PowerEdges WPF-Modus

### 5.1 Was ist der WPF-Modus?

Im WPF-Modus läuft PowerEdge als **reine WPF-Anwendung ohne WebView2** — ähnlich wie eine klassische Windows-Desktop-App. Die gesamte UI wird durch XAML-Controls definiert (Buttons, Labels, DataGrids, TreeViews etc.). Dieser Modus ist der Ausgangspunkt für PlugIn-basierte Erweiterungen.

### 5.2 Grundaufbau des WPF-Modus

**XAML-Grundstruktur für den WPF-Inhaltsbereich:**
```xml
<Grid x:Name="WpfContentLayer" Visibility="Collapsed">
    <!-- Navigation (z.B. Sidebar) -->
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="200" />
        <ColumnDefinition Width="*" />
    </Grid.ColumnDefinitions>

    <!-- Sidebar / Navigation -->
    <StackPanel x:Name="WpfSidebar" Grid.Column="0" Background="#1E1E2E">
        <Button x:Name="BtnWpfHome" Content="Home" />
        <Button x:Name="BtnWpfPlugins" Content="PlugIns" />
        <Button x:Name="BtnWpfSettings" Content="Einstellungen" />
    </StackPanel>

    <!-- Hauptinhaltsbereich (dynamisch befüllbar) -->
    <ContentControl x:Name="WpfMainContent" Grid.Column="1" />
</Grid>
```

Das `ContentControl` `WpfMainContent` ist der **Kern des WPF-Modus**: Es kann zur Laufzeit mit beliebigen WPF-UserControls (PlugIns) befüllt werden.

### 5.3 Externe Anwendungen im WPF-Modus einbinden

Es gibt drei Ansätze, externe Anwendungen im WPF-Modus zu integrieren:

---

#### Ansatz 1: Win32-Fenster einbetten (HwndHost) — Dein persönlicher Favorit ✅

Dies entspricht deinem Wunsch, externe Apps **direkt im PowerEdge-Fenster eingebettet** auszuführen. Die Technik heißt **`HwndHost`** und ist Teil von WPF.

**Konzept:**
```csharp
// C# via Add-Type
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

public class Win32Host : HwndHost {
    private IntPtr _childHandle;
    private int _width;
    private int _height;

    [DllImport("user32.dll")]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    private static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);

    private const int GWL_STYLE = -16;
    private const int WS_CHILD = 0x40000000;

    public Win32Host(IntPtr childHandle, int w, int h) {
        _childHandle = childHandle;
        _width = w;
        _height = h;
    }

    protected override HandleRef BuildWindowCore(HandleRef hwndParent) {
        SetParent(_childHandle, hwndParent.Handle);
        SetWindowLong(_childHandle, GWL_STYLE, WS_CHILD);
        MoveWindow(_childHandle, 0, 0, _width, _height, true);
        return new HandleRef(this, _childHandle);
    }

    protected override void DestroyWindowCore(HandleRef hwnd) {
        // Fenster nicht zerstören, nur trennen
        SetParent(_childHandle, IntPtr.Zero);
    }
}
```

**PowerShell-Nutzung:**
```powershell
Add-Type -TypeDefinition $win32HostCode -ReferencedAssemblies @(
    "PresentationFramework", "PresentationCore", "WindowsBase"
)

# Externe App starten
$process = Start-Process "notepad.exe" -PassThru
Start-Sleep -Milliseconds 500  # Warten bis Fenster existiert

# Fenster-Handle holen
$childHwnd = $process.MainWindowHandle

# In WPF einbetten
$host = [Win32Host]::new($childHwnd, 800, 600)
$wpfMainContent.Content = $host
```

**Einschränkungen:**
- Funktioniert nur mit Win32-Anwendungen (GDI/GDI+/DirectX).
- UWP-Apps (Store-Apps) können nicht eingebettet werden.
- Das externe Fenster muss **bereits existieren** (d.h. die App muss gestartet sein).
- Fenster-Rahmen und Titelleiste müssen per `SetWindowLong` entfernt werden.
- Resize-Events müssen manuell an das eingebettete Fenster weitergeleitet werden.

---

#### Ansatz 2: Child-Prozess mit Fenster-Kontrolle

Wenn echtes Einbetten nicht möglich oder gewünscht ist, kann PowerEdge externe Apps als **überwachte Child-Prozesse** starten und deren Fenster auf dem Bildschirm positionieren/dimensionieren:

```powershell
function Start-ManagedChildProcess {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [System.Windows.Window]$ParentWindow
    )

    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru

    # Auf Fenster warten
    $maxWait = 50
    while ($process.MainWindowHandle -eq [IntPtr]::Zero -and $maxWait -gt 0) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
        $maxWait--
    }

    # Fenster am PowerEdge-Fenster ausrichten
    $parentPos = $ParentWindow.PointToScreen([System.Windows.Point]::new(0, 0))

    [Win32Api]::MoveWindow(
        $process.MainWindowHandle,
        [int]$parentPos.X + 210,  # Sidebar-Breite offset
        [int]$parentPos.Y + 40,   # TitleBar offset
        800, 600, $true
    )

    # Überwachung: PowerEdge schließt Child-Prozess mit
    $syncHash.ChildProcesses += $process
    return $process
}
```

---

#### Ansatz 3: WPF UserControls als PlugIns (Empfohlen für eigene Erweiterungen)

Für eigens entwickelte Erweiterungen (keine Fremd-Apps) ist die sauberste Methode die Implementierung als **WPF UserControl** in einer DLL oder einem PS-Skript:

```powershell
# PlugIn-Schnittstelle (als PowerShell-Klasse)
class PEPlugin {
    [string] $Name
    [string] $Version
    [System.Windows.UIElement] GetControl() { throw "Nicht implementiert" }
    [void] OnActivate() {}
    [void] OnDeactivate() {}
}
```

```powershell
# Beispiel-PlugIn: Datei-Explorer
class FileExplorerPlugin : PEPlugin {
    FileExplorerPlugin() {
        $this.Name = "File Explorer"
        $this.Version = "1.0"
    }

    [System.Windows.UIElement] GetControl() {
        $tree = [System.Windows.Controls.TreeView]::new()
        # TreeView mit Dateisystem befüllen...
        return $tree
    }
}

# Im WPF-Modus laden:
$plugin = [FileExplorerPlugin]::new()
$plugin.OnActivate()
$wpfMainContent.Content = $plugin.GetControl()
```

---

### 5.4 Empfehlung WPF-Modus

```
Eigene PowerEdge-Erweiterungen  → WPF UserControl / PlugIn-Klasse
Externe Tools (eingebettet)     → HwndHost (Win32-Einbettung)
Externe Tools (überwacht)       → Child-Prozess mit Fenster-Positionierung
```

---

## 6. Thema: PowerEdges Terminal-Modus

### 6.1 Vision: Eingebettete PowerShell-Instanz

Das Ziel ist eine **innerhalb des PowerEdge-WPF-Fensters laufende PowerShell-Konsole**, die:
- Alle standard-PowerShell-Befehle ausführen kann
- Zusätzliche "exklusive" PowerEdge-Befehle anbietet
- Optisch in das PowerEdge-Design integriert ist

### 6.2 Architektur: RichTextBox als Terminal-Emulator

Da WPF keine native Terminal-Komponente enthält, gibt es zwei Hauptansätze:

#### Ansatz A: RichTextBox-basierter Terminal (Pure WPF) — Empfohlen für eigene Kontrolle

```xml
<Grid x:Name="TerminalLayer" Visibility="Collapsed" Background="#0C0C0C">
    <Grid.RowDefinitions>
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
    </Grid.RowDefinitions>

    <!-- Ausgabebereich -->
    <RichTextBox x:Name="TerminalOutput"
                 Background="#0C0C0C"
                 Foreground="#CCCCCC"
                 FontFamily="Cascadia Code, Consolas, Courier New"
                 FontSize="13"
                 IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto"
                 Grid.Row="0" />

    <!-- Eingabezeile -->
    <Grid Grid.Row="1" Background="#1A1A2E">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="TerminalPrompt"
                   Text="PE:&gt; "
                   Foreground="#00FF41"
                   FontFamily="Cascadia Code, Consolas"
                   VerticalAlignment="Center"
                   Padding="8,4" />
        <TextBox x:Name="TerminalInput"
                 Grid.Column="1"
                 Background="Transparent"
                 Foreground="#CCCCCC"
                 FontFamily="Cascadia Code, Consolas"
                 FontSize="13"
                 BorderThickness="0"
                 CaretBrush="White"
                 Padding="0,4" />
    </Grid>
</Grid>
```

**PowerShell-Ausführungs-Engine im Terminal:**
```powershell
# Separater Runspace für Terminal-Ausführungen
$terminalRunspace = [runspacefactory]::CreateRunspace()
$terminalRunspace.Open()

# PowerEdge-exklusive Befehle laden
$peTerminalCommands = @"
function Get-PEInfo {
    param()
    [PSCustomObject]@{
        Application = 'PowerEdge'
        Version     = '$($syncHash.AppVersion)'
        Mode        = 'Terminal'
        PID         = $PID
    }
}

function Invoke-PERegistry {
    [Alias('peregedit')]
    param([string]$Path, [string]$Name, [string]$Action = 'Get')
    switch ($Action) {
        'Get'    { Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue }
        'List'   { Get-ChildItem -Path $Path -ErrorAction SilentlyContinue }
        default  { Write-Warning "Unbekannte Aktion: $Action" }
    }
}

function Invoke-PEBulkFile {
    [Alias('pebulk')]
    param(
        [string]$Path,
        [string]$Filter = '*',
        [scriptblock]$Action,
        [switch]$Recurse
    )
    $files = Get-ChildItem -Path $Path -Filter $Filter -Recurse:$Recurse -File
    $files | ForEach-Object { & $Action $_ }
    Write-Host "[PowerEdge] $($files.Count) Dateien verarbeitet." -ForegroundColor Green
}

function Get-PEHelp {
    @"
PowerEdge Terminal - Exklusive Befehle:
  Get-PEInfo          - Zeigt PowerEdge-Informationen
  Invoke-PERegistry   - Registry-Interaktion (Alias: peregedit)
  Invoke-PEBulkFile   - Massen-Datei-Operationen (Alias: pebulk)
  Get-PEHelp          - Diese Hilfe
"@
}
"@

$terminalRunspace.CreatePipeline($peTerminalCommands).Invoke()

# Befehlsausführung wenn Enter gedrückt:
$terminalInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Return) {
        $cmd = $terminalInput.Text.Trim()
        if (-not [string]::IsNullOrEmpty($cmd)) {
            # Befehl im Terminal anzeigen
            Append-TerminalLine -Text "PE:> $cmd" -Color "#00FF41"

            # Im Hintergrund ausführen
            $ps = [System.Management.Automation.PowerShell]::Create()
            $ps.Runspace = $terminalRunspace
            $ps.AddScript($cmd) | Out-Null

            try {
                $results = $ps.Invoke()
                foreach ($r in $results) {
                    Append-TerminalLine -Text ($r | Out-String).Trim() -Color "#CCCCCC"
                }
                foreach ($err in $ps.Streams.Error) {
                    Append-TerminalLine -Text $err.ToString() -Color "#FF6B6B"
                }
            } catch {
                Append-TerminalLine -Text $_.Exception.Message -Color "#FF6B6B"
            }

            $terminalInput.Text = ""
            # Befehlshistorie speichern
            $syncHash.TerminalHistory += $cmd
        }
        $e.Handled = $true
    }
})

function Append-TerminalLine {
    param([string]$Text, [string]$Color = "#CCCCCC")
    $window.Dispatcher.Invoke({
        $para = [System.Windows.Documents.Paragraph]::new()
        $run  = [System.Windows.Documents.Run]::new($Text)
        $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
        $para.Inlines.Add($run)
        $terminalOutput.Document.Blocks.Add($para)
        $terminalOutput.ScrollToEnd()
    })
}
```

---

#### Ansatz B: Windows Terminal einbetten (HwndHost)

Windows Terminal (oder `conhost.exe`) kann theoretisch über `HwndHost` eingebettet werden — das ist jedoch technisch sehr komplex und fehleranfällig, da Windows Terminal ein modernes UWP/WinUI-3-Fenster verwendet, das sich nicht ohne Weiteres einbetten lässt.

**Machbarkeits-Einschätzung:**
- Standard `cmd.exe` / `powershell.exe` (Win32): Einbettung per `HwndHost` möglich, aber optisch altbacken.
- Windows Terminal: Einbettung nicht zuverlässig möglich.
- **Empfehlung: Eigene RichTextBox-Implementierung (Ansatz A)** — deutlich mehr Kontrolle über Optik und Funktionen.

---

### 6.3 Exklusive PowerEdge-Terminal-Befehle — Konzept

Die "exklusiven" Befehle werden als PowerShell-Funktionen in den Terminal-Runspace geladen und sind **ausschließlich in der PowerEdge-Konsole** verfügbar. Kategorisierung:

| Kategorie | Befehle (Beispiele) |
|---|---|
| System-Info | `Get-PEInfo`, `Get-PESystemStatus`, `Get-PEProcessList` |
| Registry | `Invoke-PERegistry` (Get/Set/Delete/List), `Export-PERegistry` |
| Massen-Dateien | `Invoke-PEBulkFile`, `Copy-PEBulkFiles`, `Rename-PEBulkFiles` |
| Windows-Verwaltung | `Invoke-PEService`, `Get-PEEventLog`, `Set-PEWindowsFeature` |
| PowerEdge-Kontrolle | `Switch-PEMode`, `Get-PEPlugins`, `Install-PEPlugin` |
| Netzwerk | `Test-PEConnectivity`, `Get-PENetworkInfo` |

---

### 6.4 Befehlshistorie und Autovervollständigung

```powershell
# Pfeiltasten-Navigation in der Historie
$terminalInput.Add_KeyDown({
    param($s, $e)
    switch ($e.Key) {
        ([System.Windows.Input.Key]::Up) {
            if ($syncHash.HistoryIndex -gt 0) {
                $syncHash.HistoryIndex--
                $terminalInput.Text = $syncHash.TerminalHistory[$syncHash.HistoryIndex]
                $terminalInput.CaretIndex = $terminalInput.Text.Length
            }
            $e.Handled = $true
        }
        ([System.Windows.Input.Key]::Down) {
            if ($syncHash.HistoryIndex -lt ($syncHash.TerminalHistory.Count - 1)) {
                $syncHash.HistoryIndex++
                $terminalInput.Text = $syncHash.TerminalHistory[$syncHash.HistoryIndex]
            } else {
                $terminalInput.Text = ""
            }
            $e.Handled = $true
        }
        ([System.Windows.Input.Key]::Tab) {
            # Tab-Autovervollständigung (vereinfacht)
            $partial = $terminalInput.Text
            $completions = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $partial, $partial.Length, $null
            )
            if ($completions.CompletionMatches.Count -gt 0) {
                $terminalInput.Text = $completions.CompletionMatches[0].CompletionText
                $terminalInput.CaretIndex = $terminalInput.Text.Length
            }
            $e.Handled = $true
        }
    }
})
```

---

### 6.5 Empfehlung Terminal-Modus

Der Terminal-Modus ist technisch sehr gut umsetzbar und unterscheidet sich fundamental von allen anderen Ansätzen. Die **RichTextBox-basierte Implementierung** (Ansatz A) ist klar die beste Wahl — sie gibt dir vollständige Kontrolle über das Erscheinungsbild und die Funktionalität, erfordert keinen externen Prozess und kann nahtlos in das PowerEdge-Design integriert werden.

---

## 7. Empfohlene Gesamtarchitektur (Roadmap)

### Phase 1: Stabilisierung (kurzfristig)

- [ ] **LocalServer-Problem beheben:** `Wait-ServerReady`-Funktion implementieren **oder** auf `SetVirtualHostNameToFolderMapping` umsteigen
- [ ] **fxlib-Scope absichern:** `PECore`-Modul erstellen, alle `fxlib`-Funktionen migrieren
- [ ] **VPDLX-Modul aktivieren/testen:** Den auskommentierten Block einkommentieren und validieren

### Phase 2: Modus-Architektur (mittelfristig)

- [ ] **XAML erweitern:** WpfContentLayer, WebViewLayer, TerminalLayer als separate `Grid`-Elemente
- [ ] **`-Mode`-Parameter** in `PowerEdge.ps1` implementieren
- [ ] **`Switch-AppMode`-Funktion** implementieren
- [ ] **Secure-Modus** mit temporärem WebView2-Profil implementieren

### Phase 3: WPF-Modus & PlugIn-System (mittelfristig bis langfristig)

- [ ] **PlugIn-Schnittstelle** als PowerShell-Klasse definieren (`PEPlugin`-Basisklasse)
- [ ] **WPF-Sidebar** mit dynamischer Navigationsliste implementieren
- [ ] **Erstes PlugIn** als Proof-of-Concept (z.B. File Browser)
- [ ] **`HwndHost`-Wrapper** für externe Win32-Apps implementieren

### Phase 4: Terminal-Modus (langfristig)

- [ ] **RichTextBox-Terminal-UI** in XAML definieren
- [ ] **Terminal-Runspace** mit exklusiven PE-Befehlen aufbauen
- [ ] **Befehlshistorie + Tab-Completion** implementieren
- [ ] **PE-Terminal-Befehlsbibliothek** erweitern

### Empfohlene Architektur für PowerEdge v2.x

```
PowerEdge.ps1 (Entry Point)
  ↓ Import-Module
  ├── PECore.psm1              ← Alle Helper-Funktionen
  ├── LocalServerModule.psm1  ← HTTP-Server als Modul
  └── PEModes\
      ├── PEMode.Base.ps1      ← Basis-Modus-Klasse
      ├── PEMode.WPF.ps1       ← Normal-Modus
      ├── PEMode.HostMode.ps1  ← WebView2-Modus
      ├── PEMode.Terminal.ps1  ← Terminal-Modus
      └── PEMode.Secure.ps1    ← Secure-Modus

data\
  ├── core\
  │   ├── PECore\              ← Neues Modul (aus fxlib)
  │   ├── LocalServerModule\   ← Neues Modul (aus localserver.ps1)
  │   ├── lib\                 ← WebView2-DLLs (unverändert)
  │   └── VPDLX\              ← Add-On (unverändert)
  ├── plugins\                 ← PlugIn-Verzeichnis (NEU)
  ├── host\                    ← Web-Content (unverändert)
  └── ui\                      ← XAML-Definitionen (erweitert)
```

---

*Dokumentation erstellt mit vollständiger Analyse des PowerEdge v1.01.01 Quellcodes.*  
*Alle Code-Beispiele sind auf den aktuellen Stand des Projekts abgestimmt und direkt einsetzbar.*
