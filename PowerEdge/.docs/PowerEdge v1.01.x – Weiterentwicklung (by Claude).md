# PowerEdge v1.01.x – Weiterentwicklung (by Claude)

> **Projektkontext:** PowerEdge v1.01.01 ist eine PowerShell-basierte WPF-Anwendung mit integrierter Microsoft Edge WebView2-Engine. Sie dient als Host-Umgebung für lokale Web-Apps (SPAs, HTML-Seiten) und wird aus `PowerEdge.ps1` gestartet. Die Konfiguration wird aus `data\config.json` geladen. Helper-Funktionen werden via Dot-Sourcing aus `data\fxlib\` eingebunden, der HTTP-Server wird aus `data\core\localserver.ps1` importiert.

---

## Inhaltsverzeichnis

1. [Thema 1 – Local HTTP Server](#1-local-http-server)
2. [Thema 2 – Helper-Funktionen & Scope](#2-helper-funktionen--scope)
3. [Thema 3 – GUI/WebView2 & Modi-Konzept](#3-guiwebview2--modi-konzept)
4. [Thema 4 – WPF-Modus & externe Anwendungen](#4-wpf-modus--externe-anwendungen)
5. [Thema 5 – Terminal-Modus](#5-terminal-modus)
6. [Gesamtempfehlung & Architektur-Roadmap](#6-gesamtempfehlung--architektur-roadmap)

---

## 1. Local HTTP Server

### 1.1 Analyse des aktuellen Problems

Der aktuelle Ansatz sieht vor, `localserver.ps1` mittels Dot-Sourcing in `PowerEdge.ps1` zu laden und dann eine `[LocalServer]`-Instanz zu erstellen. Der Server startet erfolgreich – `home.html` wird jedoch nicht angezeigt.

Nach Analyse von `PowerEdge.ps1` und `localserver.ps1` lässt sich das Kernproblem identifizieren:

**Das zentrale Problem ist ein Runspace-Scope-Konflikt in Kombination mit einem Race Condition zwischen Serverstart und WebView2-Initialisierung.**

Konkret:

- Der LocalServer wird im **Haupt-Runspace** von `PowerEdge.ps1` gestartet und läuft in einem **Background-Runspace** (`MTA`).
- Das WPF-Fenster mit WebView2 wird in einem **separaten STA-Runspace** (`$uiRunspace`) ausgeführt.
- Die Variable `$global:homeURL` (`http://localhost:8080/home.html`) wird im Haupt-Runspace gesetzt – sie ist jedoch **im STA-UI-Runspace nicht sichtbar**, da globale Variablen nicht automatisch zwischen Runspaces übertragen werden.
- Der Code übergibt `$resolvedHtmlPath` via `$syncHash.HtmlPath` korrekt. Allerdings wird die Server-Start-Wartezeit (`Start-Sleep -Milliseconds 5000`) **vor** dem Aufbau des `$syncHash` ausgeführt, aber die WebView2-Initialisierung (`EnsureCoreWebView2Async`) beginnt erst nach dem `Window_Loaded`-Event im STA-Runspace. Es ist möglich, dass der HttpListener zu diesem Zeitpunkt noch nicht bereit ist oder dass die URL `http://localhost:8080/home.html` zwar korrekt gesetzt ist, aber der `[LocalServer]` den Datei-Mapping-Pfad `data\host\home.html` (gemäß `config.json`) gegen den `RootPath` auflösen muss.
- **Kritischer Befund:** In `config.json` ist `"home": "home.html"` gesetzt und `"webdata": "data\\host"`. Der `$global:hostroot` zeigt auf `data\host`, und `$global:homeURL` lautet `http://localhost:8080/home.html`. Der Server bekommt als `RootPath` den `$global:hostroot`-Pfad. Der Request für `/home.html` sollte also korrekt auf `data\host\home.html` auflösen. **Das Problem liegt wahrscheinlich darin, dass `$Script:MimeTypes` (definiert mit `$Script:` Scope im localserver.ps1-Script) beim Dot-Sourcing in einem anderen Scope landet und beim Übertragen als Argument in den Background-Runspace entweder `$null` ist oder leer, weil der Script-Scope des Dot-Source-Aufrufs nicht mit dem Scope übereinstimmt, in dem die Klasse `[LocalServer]` die Variable referenziert.**

**Ursache im Detail:**

```powershell
# In localserver.ps1 – Script-Level:
$Script:MimeTypes = [Dictionary[string, string]]::new(...)

# In der Start()-Methode der Klasse:
$capturedMimeTypes = $Script:MimeTypes  
# <- Dieser Zugriff auf $Script: innerhalb einer CLASS-Methode
#    referenziert den Script-Scope des Skripts, in dem die KLASSE
#    definiert wurde – nicht den Scope des Aufrufers.
#    Nach Dot-Sourcing kann dieser Scope unerwartet sein.
```

Wenn `$capturedMimeTypes` leer oder `$null` ist, werden alle MIME-Types zu `application/octet-stream` – das kann in WebView2 dazu führen, dass HTML-Dateien nicht als HTML interpretiert und damit nicht gerendert werden.

### 1.2 Sofortlösung (Workaround)

Folgender Fix in `localserver.ps1` macht `MimeTypes` zu einer statischen Klassen-Eigenschaft statt einer Script-Level-Variable, wodurch das Scope-Problem entfällt:

```powershell
class LocalServer {
    # Als statisches Member der Klasse – kein Scope-Problem
    static [Dictionary[string,string]] $MimeTypes = [LocalServer]::BuildMimeTypes()
    
    static [Dictionary[string,string]] BuildMimeTypes() {
        $d = [Dictionary[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $d['.html'] = 'text/html; charset=utf-8'
        $d['.css']  = 'text/css; charset=utf-8'
        $d['.js']   = 'application/javascript; charset=utf-8'
        # ... weitere Einträge ...
        return $d
    }
    
    [void] Start() {
        # Kein $Script:MimeTypes mehr nötig – direkt über Klasse zugreifbar:
        $capturedMimeTypes = [LocalServer]::MimeTypes
        # ...
    }
}
```

Alternativ als schneller Test: Die `$capturedMimeTypes`-Variable explizit als `$global:` setzen und vor dem Dot-Sourcing initialisieren.

### 1.3 Scope-Analyse: Wie wahrscheinlich sind Scope-Probleme?

**Sehr wahrscheinlich.** PowerShell-Klassen (`class`-Keyword) haben ein eigenes, von normalen Script-Scopes entkoppeltes Verhalten:

| Situation | Scope-Verhalten |
|---|---|
| Normale Funktion in Dot-Source-Skript | Landet im aufrufenden Scope (korrekt) |
| Variable mit `$Script:` in einer Klasse | Referenziert den Scope des Skripts, wo die Klasse *definiert* ist – nicht den Aufrufer |
| Klassen-Instanz über Runspace-Grenze | Klassen-Typen sind runspace-spezifisch – können nicht direkt übertragen werden |
| `$global:` Variablen | Sichtbar nur innerhalb desselben Runspace |

Der Runspace-basierte Ansatz von PowerEdge verschärft das Problem erheblich, weil drei verschiedene Runspaces existieren:
1. **Haupt-Runspace** – `PowerEdge.ps1` läuft hier, Dot-Sourcing findet hier statt
2. **LocalServer-Background-Runspace** (MTA) – hier läuft der HTTP-Request-Loop
3. **WPF/UI-Runspace** (STA) – hier läuft das WPF-Fenster mit WebView2

Globale Variablen und Klassen-Typen sind **nicht automatisch** zwischen diesen Runspaces geteilt.

### 1.4 Alternative Implementierungsansätze

#### Option A: PowerShell-Modul (Empfohlen)

Das LocalServer-Konzept in ein **Binary-freies PowerShell-Modul** (`.psm1` + `.psd1`) umwandeln:

```
data\core\LocalServer\
├── LocalServer.psd1   (Modul-Manifest)
└── LocalServer.psm1   (enthält die Klasse + Hilfsfunktionen)
```

**Vorteile:**
- Module werden in alle Runspaces importiert, die `Import-Module` ausführen
- Der Klassen-Typ ist korrekt registriert und scope-sicher
- Klar definierte `Export-ModuleMember`-Grenzen

**Implementierung in `PowerEdge.ps1`:**

```powershell
# Statt Dot-Sourcing:
Import-Module -Name "$PSScriptRoot\data\core\LocalServer\LocalServer.psd1" -Force

# Im STA-UI-Runspace:
$uiRunspace.SessionStateProxy.SetVariable("localServerModulePath", $localServerModulePath)

$uiScript = {
    Import-Module $localServerModulePath -Force
    # Klassen-Typ ist jetzt korrekt verfügbar
}
```

> **Wichtige Einschränkung:** PowerShell-Klassen in Modulen sind erst ab PowerShell 5.1 vollständig unterstützt. Klassen-Typen, die in einem Modul definiert sind, müssen in jedem Runspace separat importiert werden – das Modul muss in jedem Runspace explizit via `Import-Module` geladen werden.

#### Option B: Vollständig externer Prozess (Alternative ohne localserver.ps1)

Den HTTP-Server als **separaten Prozess** auslagern, der unabhängig von PowerEdges Runspace-Struktur läuft:

```powershell
# Server als separaten PowerShell-Prozess starten
$serverScript = "$PSScriptRoot\data\core\localserver.ps1"
$serverProcess = Start-Process -FilePath "pwsh.exe" `
    -ArgumentList "-NoProfile -File `"$serverScript`" -RootPath `"$global:hostroot`" -Port 8080" `
    -PassThru -WindowStyle Hidden

# Beim Beenden:
$serverProcess.Kill()
```

**Vorteile:**
- Absolut keine Scope-Probleme
- Server läuft unabhängig, Absturz des UI beeinflusst den Server nicht
- Einfache IPC via HTTP möglich

**Nachteile:**
- Kein direkter Zugriff auf PowerShell-Objekte zwischen Prozessen
- Prozessmanagement notwendig (PID speichern, sauber beenden)

#### Option C: Statischer Datei-Server via .NET direkt in PowerEdge

Statt eines separaten Scripts: Den HttpListener **direkt im Haupt-Script** initialisieren und die Klasse via `Add-Type`-Inline-C# definieren:

```powershell
Add-Type -TypeDefinition @"
using System;
using System.Net;
using System.IO;
using System.Threading;

public class StaticFileServer {
    private HttpListener _listener;
    private string _root;
    private Thread _thread;
    private bool _running;

    public StaticFileServer(string root, string prefix) {
        _root = root;
        _listener = new HttpListener();
        _listener.Prefixes.Add(prefix);
    }

    public void Start() {
        _listener.Start();
        _running = true;
        _thread = new Thread(Loop);
        _thread.IsBackground = true;
        _thread.Start();
    }

    private void Loop() {
        while (_running) {
            try {
                var ctx = _listener.GetContext();
                // ... Datei servieren
            } catch { break; }
        }
    }

    public void Stop() { _running = false; _listener.Stop(); }
}
"@
```

**Vorteil:** Der C#-Typ ist nach `Add-Type` in allen Runspaces desselben Prozesses verfügbar (Assembly wird in die AppDomain geladen). Kein Scope-Problem.

#### Option D: Kein lokaler Server – direkte Datei-URI

Für den Fall, dass kein HTTP-Server nötig ist (keine SPA-Routing-Anforderungen, keine API-Calls):

```powershell
# Direkt als file://-URI laden
$fileUri = [System.Uri]::new($resolvedHtmlPath).AbsoluteUri
# Ergebnis: "file:///C:/Pfad/zu/home.html"
$webView.CoreWebView2.Navigate($fileUri)
```

**Einschränkungen:** `file://`-URIs haben in WebView2 standardmäßig eingeschränkte CORS-Regeln. Für reine statische Seiten ohne externe Abhängigkeiten funktioniert es problemlos.

### 1.5 Empfehlung für den Local Server

**Beste Option: Modul (Option A) kombiniert mit statischem C#-Typ (Option C) als Fallback.**

Konkret empfohlen wird folgende Strategie:

1. `localserver.ps1` bleibt bestehen, aber `$Script:MimeTypes` wird zu einer **statischen Klassen-Eigenschaft** umgebaut (Sofortlösung aus 1.2).
2. Mittel- bis langfristig: Umwandlung in ein `LocalServer.psm1`-Modul mit explizitem `Import-Module` in jedem Runspace.
3. Als robuste Alternative für Produktivbetrieb: Der C#-Inline-Ansatz (Option C), da `Add-Type`-Typen prozessweit verfügbar sind und keine Runspace-Grenzen kennen.

---

## 2. Helper-Funktionen & Scope

### 2.1 Aktueller Stand und Problematik

Aktuell lädt `PowerEdge.ps1` alle `.ps1`-Dateien aus `data\fxlib\` via Dot-Sourcing:

```powershell
Get-ChildItem -Path $fxLibPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}
```

Diese Funktionen (`ResolveHttpRoot`, `LoadWebViewDLLs`, `LoadXAMLui`, `LoadURL`, etc.) werden im **Haupt-Runspace** verfügbar gemacht. Sie werden in `PowerEdge.ps1` aufgerufen, **bevor** der UI-Runspace (`$uiRunspace`) gestartet wird – das ist korrekt und funktioniert grundsätzlich.

**Das Problem entsteht, wenn Funktionen aus `fxlib` auch im UI-Runspace (STA) benötigt werden.** Der STA-Runspace hat keinen Zugriff auf im Haupt-Runspace dot-gesourcte Funktionen. Aktuell werden die Funktionen nur im Hauptskript benötigt (vor dem UI-Runspace-Start), daher tritt das Problem derzeit nur subtil auf – wird aber bei Erweiterungen massiv relevant.

### 2.2 Die 4 realistischen Optionen im Vergleich

| Ansatz | Scope-Sicherheit | Wartbarkeit | Erweiterbarkeit | Empfehlung |
|---|---|---|---|---|
| **Dot-Sourcing (Status quo)** | Nur im Haupt-Runspace | Mittel | Niedrig | Für Übergangsphase |
| **PowerShell-Modul** | Pro-Runspace (expliziter Import) | Hoch | Hoch | ✅ Langfristig empfohlen |
| **Statische C#-Klasse via `Add-Type`** | Prozessweit | Mittel | Mittel | Für Low-Level-Funktionen |
| **PowerShell-Klasse in eigenem Namespace** | Nur im definierenden Runspace | Mittel | Mittel | Eingeschränkt |

### 2.3 Option 1: PowerShell-Modul (Empfohlen)

Ein dediziertes Modul `PowerEdge.Core` fasst alle Helper-Funktionen zusammen:

```
data\core\PowerEdge.Core\
├── PowerEdge.Core.psd1      (Manifest)
├── PowerEdge.Core.psm1      (Haupt-Modul-Datei, lädt Sub-Skripte)
└── functions\
    ├── ResolveHttpRoot.ps1
    ├── LoadWebViewDLLs.ps1
    ├── LoadXAMLui.ps1
    ├── LoadURL.ps1
    └── NewStatusObject.ps1
```

**`PowerEdge.Core.psm1`:**

```powershell
$functionsPath = Join-Path $PSScriptRoot "functions"
Get-ChildItem -Path $functionsPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function 'ResolveHttpRoot','LoadWebViewDLLs','LoadXAMLui','LoadURL','NewStatusObject'
```

**In `PowerEdge.ps1`:**

```powershell
# Statt der ForEach Dot-Sourcing-Schleife:
$coreModulePath = Join-Path $PSScriptRoot "data\core\PowerEdge.Core\PowerEdge.Core.psd1"
Import-Module -Name $coreModulePath -Force -ErrorAction Stop
```

**Im UI-Runspace, falls Funktionen dort benötigt werden:**

```powershell
$uiRunspace.SessionStateProxy.SetVariable("coreModulePath", $coreModulePath)
$uiScript = {
    Import-Module $coreModulePath -Force
    # Jetzt stehen alle Funktionen zur Verfügung
}
```

### 2.4 Option 2: Statische Klasse für Helper-Funktionen

Alle Helper-Funktionen als **statische Methoden einer C#-Klasse** via `Add-Type`:

```powershell
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Collections;

public static class PowerEdgeHelper {
    
    public static Hashtable NewStatusObject(int code, string msg) {
        var ht = new Hashtable();
        ht["code"] = code;
        ht["msg"] = msg;
        return ht;
    }

    public static Hashtable ResolveHttpRoot(string inputPath, string hostroot, string homeUrl) {
        // Logik hier...
        return NewStatusObject(0, inputPath);
    }
}
"@

# Aufruf überall im Prozess – runspace-agnostisch:
$result = [PowerEdgeHelper]::NewStatusObject(0, "OK")
```

**Vorteil:** Der Typ ist nach dem ersten `Add-Type`-Aufruf **prozessweit** verfügbar – in allen Runspaces ohne erneuten Import.

**Nachteil:** C#-Syntax, kein PowerShell-native Look & Feel, weniger flexibel für dynamische Logik.

### 2.5 Option 3: `$syncHash` als Funktionen-Carrier

Für die aktuelle Architektur eine pragmatische Brücke: Funktionen als `[scriptblock]`-Objekte in den `$syncHash` packen und im UI-Runspace ausführen:

```powershell
# Im Haupt-Script:
$syncHash["fn_LoadURL"] = ${function:LoadURL}

# Im UI-Runspace:
$loadUrlFn = [scriptblock]::Create($syncHash["fn_LoadURL"])
$result = & $loadUrlFn -WebView $webView -Url "http://localhost:8080/"
```

**Wann sinnvoll:** Als Übergangslösung oder für einzelne Funktionen, die sporadisch im UI-Runspace gebraucht werden.

### 2.6 Empfehlung für Helper-Funktionen

**Beste Option für PowerEdge: Hybridansatz.**

- **Sofort:** Dot-Sourcing beibehalten, aber alle Funktionen mit klarer Namenskonvention (`PE-` Prefix) versehen, um Konflikte zu vermeiden.
- **Kurzfristig:** Ein `PowerEdge.Core`-Modul (Option 1) erstellen. Das ist der sauberste und wartbarste Weg. Alle Runspaces, die Helper-Funktionen benötigen, führen `Import-Module` aus.
- **Für Performance-kritische oder Low-Level-Funktionen:** `Add-Type`-C#-Klasse (Option 2), da prozessweit verfügbar.

---

## 3. GUI/WebView2 & Modi-Konzept

### 3.1 Vision: 4 Basismodi

Die geplanten 4 Modi sind technisch umsetzbar. Hier die Definition und Implementierbarkeit:

| Modus | Beschreibung | WPF | WebView2 | Machbarkeit |
|---|---|---|---|---|
| **Normal** | Reine WPF-Anwendung, kein WV2 | ✅ Aktiv | ❌ Hidden/Collapsed | ✅ Einfach |
| **Terminal** | Eingebettete PowerShell-Konsole | ✅ Aktiv | ❌ Hidden | ⚠️ Komplex |
| **HostMode** | WebView2 als SPA-Host | ✅ Aktiv | ✅ Aktiv | ✅ Aktueller Stand |
| **Secure** | WebView2 im InPrivate-Modus | ✅ Aktiv | ✅ InPrivate | ✅ Erweiterung |

### 3.2 WebView2 als "Layer" – Das Sichtbarkeits-Konzept

**Ja, WebView2 kann als ausblend- und einblendbarer Layer funktionieren.** Die technische Umsetzung in WPF/XAML ist straightforward:

```xml
<!-- In main.window.xml: WebView2 als Layer in einem Grid -->
<Grid x:Name="ContentArea">
    <!-- WPF-Mode Inhalt (immer vorhanden, wird bei WebView-Mode unsichtbar) -->
    <Grid x:Name="WpfModeLayer" Visibility="Visible">
        <!-- Normale WPF-Controls hier -->
    </Grid>
    
    <!-- WebView2 als überlagernder Layer -->
    <wv2:WebView2 x:Name="MainWebView" 
                  Visibility="Collapsed"
                  Panel.ZIndex="10"/>
    
    <!-- Terminal-Layer -->
    <Grid x:Name="TerminalLayer" Visibility="Collapsed" Panel.ZIndex="5">
        <!-- Terminal-Host-Control hier -->
    </Grid>
</Grid>
```

In PowerShell wird dann der aktive Layer via `Visibility`-Property umgeschaltet:

```powershell
function Switch-PowerEdgeMode {
    param([string]$Mode)  # "Normal" | "Terminal" | "HostMode" | "Secure"
    
    $window.Dispatcher.Invoke({
        $wpfLayer    = $window.FindName("WpfModeLayer")
        $wv2Control  = $window.FindName("MainWebView")
        $termLayer   = $window.FindName("TerminalLayer")
        
        # Alle Layer ausblenden
        $wpfLayer.Visibility   = [System.Windows.Visibility]::Collapsed
        $wv2Control.Visibility = [System.Windows.Visibility]::Collapsed
        $termLayer.Visibility  = [System.Windows.Visibility]::Collapsed
        
        switch ($Mode) {
            "Normal"   { $wpfLayer.Visibility   = [System.Windows.Visibility]::Visible }
            "Terminal" { $termLayer.Visibility  = [System.Windows.Visibility]::Visible }
            "HostMode" { $wv2Control.Visibility = [System.Windows.Visibility]::Visible }
            "Secure"   {
                $wv2Control.Visibility = [System.Windows.Visibility]::Visible
                # InPrivate-Profil setzen (siehe 3.3)
            }
        }
    })
}
```

### 3.3 Implementierung des Secure-Modus (InPrivate)

WebView2 unterstützt InPrivate-Browsing über ein separates `CoreWebView2Environment` mit einem anderen `UserDataFolder` oder via `IsInPrivateModeEnabled`:

```powershell
# Secure/InPrivate Profil
$secureProps = [Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties]::new()
$secureProps.UserDataFolder = Join-Path $env:TEMP "PowerEdge_InPrivate_$(Get-Random)"
$secureProps.IsInPrivateModeEnabled = $true  # ab WebView2 SDK 1.0.1264+
$webView.CreationProperties = $secureProps
```

> **Hinweis:** `IsInPrivateModeEnabled` ist erst ab WebView2 Runtime ≥ 101 verfügbar. Für ältere Versionen: einfach einen separaten temporären `UserDataFolder` nutzen und nach dem Beenden löschen.

### 3.4 Dynamisches Wechseln zwischen Modi im laufenden Betrieb

**Ja, das ist vollständig möglich** – mit folgenden Einschränkungen:

- **WPF ↔ WebView2:** Kein Problem. Die `Visibility`-Änderung reicht aus. WebView2 bleibt initialisiert (was gut ist – Re-Initialisierung kostet Zeit).
- **Normal → HostMode:** WebView2 einblenden, URL navigieren.
- **HostMode → Normal:** WebView2 ausblenden, WPF-Layer einblenden. Optionales `webView.CoreWebView2.Navigate("about:blank")` um Speicher freizugeben.
- **HostMode → Secure:** Hier ist eine Neuinitialisierung von WebView2 mit neuem Environment nötig, weil das `CoreWebView2Environment` nach der Initialisierung nicht mehr geändert werden kann. Die einfachste Lösung: **zwei WebView2-Instanzen** im XAML, eine für Normal/HostMode, eine für Secure.

```xml
<wv2:WebView2 x:Name="MainWebView"   Visibility="Collapsed"/>
<wv2:WebView2 x:Name="SecureWebView" Visibility="Collapsed"/>
```

### 3.5 Modus-Auswahl beim Start (Parameter-basiert)

Ein `-StartMode`-Parameter in `PowerEdge.ps1`:

```powershell
param(
    [ValidateSet("Normal","Terminal","HostMode","Secure")]
    [string]$StartMode = "HostMode"
)

$syncHash["StartMode"] = $StartMode
```

Alternativ: Ein **Startbildschirm** (Splash/Launcher) als WPF-Dialog, der dem Nutzer die 4 Modi zur Auswahl anbietet, bevor das Hauptfenster geöffnet wird.

### 3.6 Empfehlung für GUI/Modi-Konzept

Das Layer-Prinzip ist der **sauberste und empfohlene Ansatz**. Die Implementierung in XAML via `Visibility="Collapsed"` und ein zentrales `Switch-PowerEdgeMode`-Dispatcher-Invoke ist technisch sauber und leicht erweiterbar. Empfohlene Reihenfolge der Implementierung:

1. XAML mit 3 Layern erweitern (WPF, WebView2, Terminal-Placeholder)
2. `Switch-PowerEdgeMode`-Funktion implementieren
3. Toolbar/Schaltflächen für Moduswechsel hinzufügen
4. Secure-Modus via zweite WebView2-Instanz implementieren

---

## 4. WPF-Modus & externe Anwendungen

### 4.1 Grundkonzept des reinen WPF-Modus

Im WPF-Modus läuft PowerEdge ohne WebView2 als vollständige XAML-WPF-Anwendung. Dies ist der natürlichste Betriebsmodus für PowerShell-WPF-Apps. Der Modus eignet sich hervorragend für:

- Native Windows-UI-Panels (Einstellungen, Dashboard, Datei-Explorer-artige Views)
- Plugin-Hosts, die eigene WPF-Controls einbinden
- Administrative Tools ohne Web-Overhead

### 4.2 Externe Anwendungen einbetten: Win32 Window-Hosting

Die technisch interessanteste und von dir favorisierte Option – externe Anwendungen direkt im PowerEdge-Fenster eingebettet darstellen – ist via **Win32-API Window-Hosting** umsetzbar:

```powershell
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32WindowEmbedder {
    [DllImport("user32.dll")]
    public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    public const int GWL_STYLE    = -16;
    public const int WS_CHILD     = 0x40000000;
    public const int WS_BORDER    = 0x00800000;
}
"@

# Externe App starten und ihr Fenster in PowerEdge einbetten
function Embed-ExternalApp {
    param(
        [string]$ExePath,
        [System.Windows.Controls.Border]$Container  # WPF-Container-Element
    )
    
    $process = Start-Process -FilePath $ExePath -PassThru
    Start-Sleep -Milliseconds 500  # Warten bis Fenster bereit
    
    # HWND des Container-Elements holen
    $hwndContainer = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
    
    # Stil des externen Fensters anpassen (Rahmen entfernen)
    [Win32WindowEmbedder]::SetWindowLong(
        $process.MainWindowHandle,
        [Win32WindowEmbedder]::GWL_STYLE,
        [Win32WindowEmbedder]::WS_CHILD
    )
    
    # Parent auf PowerEdge-Container setzen
    [Win32WindowEmbedder]::SetParent($process.MainWindowHandle, $hwndContainer)
    
    # Größe anpassen
    $size = $Container.RenderSize
    [Win32WindowEmbedder]::MoveWindow(
        $process.MainWindowHandle, 0, 0, 
        [int]$size.Width, [int]$size.Height, $true
    )
    
    return $process
}
```

**Wichtige Einschränkungen beim Win32-Embedding:**
- Funktioniert am zuverlässigsten mit Win32-nativen Apps (Notepad, Explorer, cmd.exe)
- WPF/UWP/WinUI-Apps haben komplexeres Window-Handling und können sich gegen Embedding sperren
- DPI-Scaling muss manuell berücksichtigt werden
- Fenster-Resize muss aktiv per Event-Handler weiterpropagiert werden

### 4.3 Externe Anwendungen als Child-Prozess (überwachter Sub-Prozess)

Für Apps, die sich nicht einbetten lassen, ist die **überwachte Child-Prozess-Variante** robust und einfacher:

```powershell
function Start-ManagedChildProcess {
    param(
        [string]$ExePath,
        [string]$Arguments = "",
        [scriptblock]$OnExit = $null
    )
    
    $psi = [System.Diagnostics.ProcessStartInfo]::new($ExePath, $Arguments)
    $psi.UseShellExecute = $false
    
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true
    
    if ($null -ne $OnExit) {
        $capturedCallback = $OnExit
        $proc.Add_Exited({
            $window.Dispatcher.Invoke($capturedCallback)
        })
    }
    
    $proc.Start() | Out-Null
    return $proc
}

# Beispiel: Notepad als überwachter Child starten
$notepadProc = Start-ManagedChildProcess -ExePath "notepad.exe" -OnExit {
    # Wird aufgerufen wenn Notepad geschlossen wird
    $statusText.Text = "Child process exited"
}
```

PowerEdge kann so die Kontrolle über den Lebenszyklus externer Anwendungen behalten, ohne ihr Fenster einzubetten.

### 4.4 WPF-PlugIn-System: Dynamische UserControl-Erweiterungen

Für ein echtes Plugin-System im WPF-Modus bietet sich das **dynamische Laden von WPF-UserControls** an:

```powershell
# PlugIn lädt XAML dynamisch und registriert sich
function Register-PowerEdgePlugin {
    param(
        [string]$PluginPath,
        [System.Windows.Controls.ContentControl]$Host
    )
    
    $xamlFile = Get-ChildItem -Path $PluginPath -Filter "*.xml" | Select-Object -First 1
    if ($null -ne $xamlFile) {
        $xaml = [xml](Get-Content $xamlFile.FullName)
        $reader = [System.Xml.XmlNodeReader]::new($xaml)
        $control = [System.Windows.Markup.XamlReader]::Load($reader)
        $Host.Content = $control
    }
}
```

### 4.5 Empfehlung für den WPF-Modus

**Empfohlene Strategie:** Beide Varianten koexistieren lassen:

1. **Eingebettetes Fenster** (Win32-Embedding) für kompatible externe Apps – als optionaler Modus.
2. **Child-Prozess-Modus** als Standard – robuster, keine Win32-Fallstricke.
3. **XAML-UserControl-Plugins** für native PowerEdge-Erweiterungen – die sauberste Langzeitoption.

Im XAML sollte ein dedizierter `ContentControl` oder `Frame` als Plugin-Host-Area definiert werden, in den sowohl eingebettete externe Fenster (via `HwndHost`) als auch native WPF-Controls geladen werden können.

---

## 5. Terminal-Modus

### 5.1 Konzept: Eingebettete PowerShell-Instanz

Die Idee – eine PowerShell-Instanz direkt in der WPF-Anwendung eingebettet darzustellen – ist technisch umsetzbar und bietet spannende Möglichkeiten. Es gibt zwei grundlegend verschiedene Ansätze.

### 5.2 Ansatz A: Pseudo-Terminal mit WPF-RichTextBox

Der simplere, aber vollständig PowerShell-native Ansatz: Eine `RichTextBox` oder ein `TextBox`-basiertes Control emuliert eine Terminal-Oberfläche, im Hintergrund läuft ein PowerShell-Runspace:

```xml
<!-- Terminal-Layer XAML -->
<Grid x:Name="TerminalLayer" Visibility="Collapsed" Background="#0C0C0C">
    <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    
    <!-- Output-Area -->
    <RichTextBox x:Name="TerminalOutput" 
                 Grid.Row="0"
                 Background="#0C0C0C" Foreground="#CCCCCC"
                 FontFamily="Cascadia Code, Consolas, Courier New"
                 FontSize="14"
                 IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto"/>
    
    <!-- Input-Area -->
    <Grid Grid.Row="1" Background="#0C0C0C">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="TerminalPrompt" 
                   Foreground="#00FF00" 
                   VerticalAlignment="Center"
                   Margin="5,0"
                   Text="PE> "/>
        <TextBox x:Name="TerminalInput" 
                 Grid.Column="1"
                 Background="Transparent" Foreground="White"
                 BorderThickness="0"
                 FontFamily="Cascadia Code, Consolas"/>
    </Grid>
</Grid>
```

**PowerShell-Backend für das Terminal:**

```powershell
# Dedizierter Runspace für den Terminal-Modus
$terminalRunspace = [runspacefactory]::CreateRunspace()
$terminalRunspace.ApartmentState = "MTA"
$terminalRunspace.Open()

function Invoke-TerminalCommand {
    param([string]$Command, [System.Windows.Controls.RichTextBox]$Output)
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $terminalRunspace
    
    # PowerEdge-spezifische Custom-Commands hinzufügen
    Register-PowerEdgeTerminalCommands -Runspace $terminalRunspace
    
    $ps.AddScript($Command) | Out-Null
    
    $result = $ps.Invoke()
    $errors = $ps.Streams.Error
    
    # Output in RichTextBox schreiben (via Dispatcher)
    $window.Dispatcher.Invoke({
        foreach ($item in $result) {
            $para = [System.Windows.Documents.Paragraph]::new()
            $para.Inlines.Add($item.ToString())
            $Output.Document.Blocks.Add($para)
        }
        foreach ($err in $errors) {
            $para = [System.Windows.Documents.Paragraph]::new()
            $run = [System.Windows.Documents.Run]::new($err.ToString())
            $run.Foreground = [System.Windows.Media.Brushes]::Red
            $para.Inlines.Add($run)
            $Output.Document.Blocks.Add($para)
        }
        $Output.ScrollToEnd()
    })
    
    $ps.Dispose()
}

# Key-Handler für Enter-Taste
$terminalInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Return) {
        $cmd = $terminalInput.Text
        $terminalInput.Text = ""
        Invoke-TerminalCommand -Command $cmd -Output $terminalOutput
    }
})
```

### 5.3 Ansatz B: Echtes Terminal via Windows Terminal Embedding (WinPTY/ConPTY)

Für eine vollständige Terminal-Emulation (mit ANSI-Farben, Cursor-Movement, etc.) kann PowerEdge das **Windows ConPTY API** nutzen:

```powershell
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class ConPtyHelper {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern int CreatePseudoConsole(
        COORD size, IntPtr hInput, IntPtr hOutput,
        uint dwFlags, out IntPtr phPC);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct COORD { public short X; public short Y; }
    
    // ... weitere P/Invoke Signaturen
}
"@
```

Dieser Ansatz ist deutlich komplexer, bietet aber ein vollständiges VT100/ANSI-Terminal-Erlebnis.

**Pragmatische Alternative:** Windows Terminal (`wt.exe`) als eingebettetes Fenster via Win32-Embedding (wie in Abschnitt 4.2 beschrieben):

```powershell
# Windows Terminal als eingebettetes Fenster starten
$wtProcess = Start-Process "wt.exe" -ArgumentList `
    "-w 0 new-tab --profile PowerShell --startingDirectory $PSScriptRoot" `
    -PassThru

Start-Sleep -Milliseconds 1000
# wt.exe HWND in PowerEdge-Container einbetten
Embed-ExternalApp -Process $wtProcess -Container $terminalContainer
```

### 5.4 Exklusive PowerEdge Terminal-Befehle

Das Herzstück des Terminal-Modus: custom Commands, die **nur in der PowerEdge-Konsole** verfügbar sind. Umsetzung via Runspace-gebundene Custom Functions:

```powershell
function Register-PowerEdgeTerminalCommands {
    param([System.Management.Automation.Runspaces.Runspace]$Runspace)
    
    $commands = @{
        # Registry-Befehle
        "pe-reg-get"     = 'function pe-reg-get { param($Path,$Name) Get-ItemProperty -Path $Path -Name $Name }'
        "pe-reg-set"     = 'function pe-reg-set { param($Path,$Name,$Value) Set-ItemProperty -Path $Path -Name $Name -Value $Value }'
        
        # Massen-Datei-Interaktionen
        "pe-bulk-rename" = 'function pe-bulk-rename { param($Path,$Pattern,$Replace) Get-ChildItem $Path | Rename-Item -NewName { $_.Name -replace $Pattern, $Replace } }'
        "pe-bulk-hash"   = 'function pe-bulk-hash { param($Path,[string]$Algorithm="SHA256") Get-ChildItem $Path -File | Get-FileHash -Algorithm $Algorithm }'
        
        # Windows-Systemkommandos
        "pe-svc-list"    = 'function pe-svc-list { param($Filter="*") Get-Service | Where-Object Name -like $Filter | Format-Table Name,Status,StartType }'
        "pe-proc-tree"   = 'function pe-proc-tree { Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 | Format-Table Name,Id,CPU,WorkingSet }'
        
        # PowerEdge-interne Kommandos
        "pe-mode"        = 'function pe-mode { param([ValidateSet("Normal","Terminal","HostMode","Secure")][string]$Mode) $syncHash["RequestModeSwitch"] = $Mode }'
        "pe-version"     = 'function pe-version { Write-Output "PowerEdge $($syncHash[''AppVersion'']) - Terminal Mode" }'
        "pe-help"        = 'function pe-help { @("pe-reg-get","pe-reg-set","pe-bulk-rename","pe-bulk-hash","pe-svc-list","pe-proc-tree","pe-mode","pe-version") | ForEach-Object { Write-Output "  $_" } }'
    }
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $Runspace
    
    foreach ($cmd in $commands.Values) {
        $ps.AddScript($cmd) | Out-Null
    }
    $ps.Invoke() | Out-Null
    $ps.Dispose()
}
```

### 5.5 Tab-Completion & Syntax-Highlighting

Für eine professionelle Terminal-Erfahrung können Tab-Completion und einfaches Syntax-Highlighting implementiert werden:

```powershell
# Tab-Completion via PowerShell API
$terminalInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Tab) {
        $e.Handled = $true
        $input = $terminalInput.Text
        $completions = [System.Management.Automation.CommandCompletion]::CompleteInput(
            $input, $input.Length, $null,
            [System.Management.Automation.PowerShell]::Create()
        )
        if ($completions.CompletionMatches.Count -gt 0) {
            $terminalInput.Text = $completions.CompletionMatches[0].CompletionText
            $terminalInput.CaretIndex = $terminalInput.Text.Length
        }
    }
})
```

### 5.6 Empfehlung für den Terminal-Modus

**Beste Option für PowerEdge: Ansatz A (Pseudo-Terminal mit WPF-RichTextBox) als Phase 1, optional Ansatz B (ConPTY/Windows Terminal Embedding) als Phase 2.**

Begründung: Ansatz A ist vollständig in PowerShell/WPF umsetzbar, gibt maximale Kontrolle über das UI-Design und lässt sich perfekt mit den exklusiven `pe-`-Commands integrieren. Die Limitierungen (kein ANSI-Farbsupport im Standard) können durch color-coding in der RichTextBox kompensiert werden. Phase 2 kann dann bei Bedarf als optionaler "Raw Terminal"-Modus hinzugefügt werden.

---

## 6. Gesamtempfehlung & Architektur-Roadmap

### 6.1 Übergeordnete Architektur-Empfehlung

Alle diskutierten Themen konvergieren auf eine zentrale Empfehlung: **PowerEdge braucht eine klare Trennung zwischen Startup-Scope (Haupt-Runspace), UI-Scope (STA-Runspace) und Service-Scope (Background-Runspaces).**

Die empfohlene Ziel-Architektur:

```
PowerEdge.ps1 (Haupt-Runspace)
│
├── Import-Module PowerEdge.Core       ← alle Helper-Funktionen als Modul
├── Import-Module PowerEdge.LocalServer ← HTTP-Server als Modul
│
├── [LocalServer] startet (Background-Runspace, MTA)
│
└── $uiRunspace (STA-Runspace)
    ├── Import-Module PowerEdge.Core   ← Modul erneut importieren!
    ├── WPF Window + XAML
    ├── Layer-System (WPF / WebView2 / Terminal)
    └── Terminal-Runspace (MTA) [optional]
        └── Register-PowerEdgeTerminalCommands
```

### 6.2 Priorisierte Roadmap

| Priorität | Aufgabe | Aufwand | Impact |
|---|---|---|---|
| 🔴 **1 (Sofort)** | LocalServer MimeTypes-Fix (statische Klassen-Eigenschaft) | Klein | Behebt das Home.html-Problem |
| 🔴 **2 (Sofort)** | Race Condition prüfen: `Start-Sleep` erhöhen oder Server-Ready-Check | Klein | Stabilität |
| 🟡 **3 (Kurzfristig)** | `PowerEdge.Core`-Modul für fxlib-Funktionen | Mittel | Scope-Sicherheit |
| 🟡 **4 (Kurzfristig)** | XAML Layer-System (Normal/HostMode/Secure) | Mittel | Modi-Unterstützung |
| 🟢 **5 (Mittelfristig)** | Terminal-Modus (Phase 1: RichTextBox-Pseudo-Terminal) | Mittel | Feature-Erweiterung |
| 🟢 **6 (Mittelfristig)** | WPF-Modus mit Child-Prozess-Management | Mittel | Plugin-Grundlage |
| 🔵 **7 (Langfristig)** | Vollständiges Plugin-System mit XAML-UserControls | Groß | Erweiterbarkeit |
| 🔵 **8 (Langfristig)** | ConPTY/Windows Terminal Embedding (Terminal Phase 2) | Groß | Premium-Terminal |

### 6.3 Kritische Erkenntnisse zusammengefasst

- **Scope-Probleme sind real und betreffen primär den `$Script:`-Scope in PowerShell-Klassen sowie globale Variablen über Runspace-Grenzen hinweg.** Das ist die wahrscheinlichste Ursache für das Home.html-Problem.
- **Module sind der sauberste Weg** für scope-sichere, wiederverwendbare Funktionen in einer Multi-Runspace-Architektur.
- **Das Layer-Konzept für die 4 Modi ist technisch elegant** und mit WPF-Visibility-Switching einfach umsetzbar.
- **Der Terminal-Modus ist das ambitionierteste Feature**, aber der RichTextBox-basierte Ansatz macht ihn realistisch umsetzbar ohne externe Abhängigkeiten.
- **Win32-Window-Embedding** für externe Apps funktioniert gut für native Win32-Apps, ist aber fragil für moderne Anwendungen – Child-Prozess-Überwachung ist die robustere Default-Option.

---

*Dokument erstellt: April 2026 | PowerEdge Version: 1.01.01 | Autor: Claude (Analyse & Dokumentation)*
