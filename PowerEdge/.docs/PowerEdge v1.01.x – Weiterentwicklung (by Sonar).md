# PowerEdge v1.01.x — Weiterentwicklung
> **Dokumentation by Sonar** | Stand: April 2026 | Bezugsprojekt: [PowerEdge auf GitHub](https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge)

---

## Inhaltsverzeichnis

1. [Projektüberblick & aktueller Stand](#1-projektüberblick--aktueller-stand)
2. [Thema: Local HTTP Server](#2-thema-local-http-server)
3. [Thema: Helper-Funktionen & Dot-Sourcing](#3-thema-helper-funktionen--dot-sourcing)
4. [Thema: GUI/WebView2 & Moduswechsel](#4-thema-guiwebview2--moduswechsel)
5. [Thema: WPF-Modus (Pure WPF/XAML)](#5-thema-wpf-modus-pure-wpfxaml)
6. [Thema: Terminal-Modus](#6-thema-terminal-modus)
7. [Empfohlene Gesamtarchitektur](#7-empfohlene-gesamtarchitektur)

---

## 1. Projektüberblick & aktueller Stand

PowerEdge ist eine PowerShell-basierte WPF-Desktopanwendung (Version `v1.01.01`), die eine eingebettete **Microsoft Edge WebView2**-Instanz hostet. Das Projekt erlaubt es, lokale HTML/SPA-Anwendungen in einem nativen Windows-Fenster auszuführen — ähnlich wie Electron, aber vollständig in PowerShell und .NET WPF realisiert.

### Aktuelle Projektstruktur

```
PowerEdge/
├── PowerEdge.ps1           ← Haupteinstiegspunkt
├── PowerEdge.ico
├── CHANGELOG.md
├── README.md
└── data/
    ├── config.json         ← Zentrale Konfigurationsdatei
    ├── core/
    │   ├── localserver.ps1 ← Integrierter HTTP-Server (LocalServer-Klasse)
    │   ├── lib/            ← WebView2 DLL-Dateien
    │   └── VPDLX/          ← VPDLX Add-On Modul (derzeit auskommentiert)
    ├── fxlib/              ← Helper-Funktionen (Dot-Sourcing)
    │   ├── LoadURL.ps1
    │   ├── LoadURLafter.ps1
    │   ├── LoadWebViewDLLs.ps1
    │   ├── LoadXAMLui.ps1
    │   ├── NewStatusObject.ps1
    │   └── ResolveHttpRoot.ps1
    ├── host/               ← Web-Root (statische Dateien / SPAs)
    └── ui/
        └── main.window.xml ← WPF XAML-Definition
```

### Kern-Mechanismus (vereinfacht)

```
PowerEdge.ps1 startet
  │
  ├── Lädt config.json → globale Variablen
  ├── Dot-sourced alle *.ps1 aus data\fxlib\
  ├── Dot-sourced localserver.ps1 → [LocalServer]-Klasse wird definiert
  ├── Erstellt $global:PowerEdgeServer = [LocalServer]::new(...)
  ├── $global:PowerEdgeServer.Start()  ← Startet HTTP-Server in separatem Runspace
  ├── Erstellt einen STA-Runspace für die WPF-UI
  └── UI-Runspace:
        ├── Lädt WPF-Fenster aus XAML
        ├── Initialisiert WebView2
        └── Navigiert zu http://localhost:8080/home.html
```

---

## 2. Thema: Local HTTP Server

### 2.1 Root-Ursache: Das Scope-Problem

**Ja, Scope-Probleme sind die wahrscheinlichste Ursache** dafür, dass `home.html` nicht angezeigt wird. Hier ist die genaue Kette des Problems:

Der HTTP-Server wird in `PowerEdge.ps1` über Dot-Sourcing geladen und gestartet:

```powershell
. "$($global:servercore)"                                     # ← Dot-Source
$global:PowerEdgeServer = [LocalServer]::new($global:hostroot, $global:rootURL)
$global:PowerEdgeServer.SpaFallback = $true
$global:PowerEdgeServer.Start()
Start-Sleep -Milliseconds 5000
```

Danach wird die WPF-Oberfläche in einem **komplett separaten Runspace** gestartet:

```powershell
$uiRunspace = [runspacefactory]::CreateRunspace()
$uiRunspace.ApartmentState = "STA"
$uiRunspace.Open()
$uiRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
```

Zwischen diesem UI-Runspace und dem Haupt-Skript-Scope gibt es **keinerlei gemeinsame Variablen** — außer dem `$syncHash`. Schaut man sich `$syncHash` genau an:

```powershell
$syncHash = [hashtable]::Synchronized(@{
    HtmlPath    = $resolvedHtmlPath   # ← Wird hier gesetzt
    ...
})
```

`$resolvedHtmlPath` wird **vor** dem Server-Start gesetzt und in `ResolveHttpRoot` aufgelöst. Wenn `$httpRoot` leer ist, springt der Code nach dem Server-Start in diesen Block:

```powershell
if ($global:useserver -eq $true) {
    if ([string]::IsNullOrEmpty($httpRoot)) {
        $resolvedHtmlPath = $global:homeURL   # ← http://localhost:8080/home.html
    }
}
```

Das Problem: `$resolvedHtmlPath` wird hier neu gesetzt, **aber `$syncHash.HtmlPath` wurde bereits davor befüllt** (mit dem Ergebnis von `ResolveHttpRoot`, also einem lokalen Dateipfad, nicht der HTTP-URL). Der `$syncHash` enthält daher möglicherweise den falschen Pfad.

> **Sofortiger Fix:** `$syncHash.HtmlPath` **nach** dem bedingten URL-Überschreiben befüllen, nicht davor:
>
> ```powershell
> # ERST nach der URL-Korrektur den syncHash befüllen:
> $syncHash = [hashtable]::Synchronized(@{
>     HtmlPath = $resolvedHtmlPath   # ← jetzt korrekt die homeURL
>     ...
> })
> ```

### 2.2 Weiteres potenzielles Problem: Timing

`Start-Sleep -Milliseconds 5000` (5 Sekunden Wartezeit) ist ein pragmatischer Ansatz, aber kein zuverlässiges Mittel. Je nach System-Last kann der HTTP-Server noch nicht bereit sein. Besser ist eine aktive Überprüfung:

```powershell
# Warte aktiv bis der Server antwortet (max. 10 Sekunden)
$maxWait = 10000
$waited = 0
$interval = 200
while ($waited -lt $maxWait) {
    try {
        $test = [System.Net.WebRequest]::Create($global:rootURL)
        $test.Timeout = 500
        $resp = $test.GetResponse()
        $resp.Close()
        break  # Server ist bereit
    } catch {
        Start-Sleep -Milliseconds $interval
        $waited += $interval
    }
}
```

### 2.3 Alternativer Ansatz A: Server-Logik als PowerShell-Modul (`.psm1`)

Anstatt `localserver.ps1` per Dot-Sourcing zu laden, kann die gesamte `LocalServer`-Klasse in ein **eigenständiges PowerShell-Modul** verpackt werden.

**Vorteile:**
- Saubere Kapselung: Klassen, MIME-Types und Hilfsfunktionen leben im Modul-Scope
- `Import-Module` funktioniert zuverlässig in jedem Scope
- Kein Scope-Verlust durch Runspace-Grenzen (solange der Server außerhalb des UI-Runspace gestartet wird)
- Wiederverwendbarkeit in anderen Projekten

**Struktur:**

```
data\core\
└── LocalServer\
    ├── LocalServer.psd1   ← Modul-Manifest
    └── LocalServer.psm1   ← Enthält [LocalServer]-Klasse und Hilfsfunktionen
```

**`LocalServer.psm1` (Grundgerüst):**

```powershell
using namespace System.Net
using namespace System.IO
using namespace System.Collections.Generic

# MIME-Types als Modul-Variable
$Script:MimeTypes = [Dictionary[string,string]]::new(...)

class LocalServer {
    # ... exakt wie in localserver.ps1
}

function New-LocalServer { ... }

Export-ModuleMember -Function New-LocalServer
```

**Aufruf in `PowerEdge.ps1`:**

```powershell
Import-Module (Join-Path $PSScriptRoot "data\core\LocalServer\LocalServer.psd1") -ErrorAction Stop
$global:PowerEdgeServer = [LocalServer]::new($global:hostroot, $global:rootURL)
```

> **Wichtig:** `using module` ist bei PowerShell-Klassen die robustere Variante, aber `Import-Module` plus explizites Typladen funktioniert für diesen Anwendungsfall zuverlässig.

### 2.4 Alternativer Ansatz B: WebView2 direkt mit `file://`-URIs (ohne HTTP-Server)

Wenn kein Server-Modus benötigt wird, kann WebView2 HTML-Dateien **direkt über `file://`-URIs** laden. Das ist der einfachste Ansatz.

```powershell
$targetUri = [System.Uri]::new("C:\...\data\host\home.html").AbsoluteUri
# → "file:///C:/Users/.../data/host/home.html"
$webView.CoreWebView2.Navigate($targetUri)
```

**Einschränkungen von `file://`:**
- Kein `fetch()` zu anderen lokalen Dateien ohne CORS-Umgehung
- Kein `localStorage`/`sessionStorage` in manchen Szenarien
- Kein `Service Worker`-Support
- Angular, React, Vue Build-Outputs funktionieren **nur eingeschränkt**

**Empfehlung:** Für einfache, statische HTML-Seiten (wie `home.html`) ist `file://` völlig ausreichend. Für SPAs mit Routing, API-Calls oder Service Worker **muss** ein HTTP-Server vorhanden sein.

### 2.5 Alternativer Ansatz C: WebView2 Virtual Host Mapping

WebView2 bietet eine eingebaute Funktion, um einen **virtuellen Hostnamen** auf ein lokales Verzeichnis zu mappen — **ohne** einen echten HTTP-Server:

```powershell
$webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
    "poweredge.local",                    # ← Virtueller Hostname
    $global:hostroot,                     # ← Lokaler Pfad
    [Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind]::Allow
)
$webView.CoreWebView2.Navigate("https://poweredge.local/home.html")
```

**Vorteile:**
- Kein separater HTTP-Server nötig
- `https://`-Schema → volle Web-API-Unterstützung (fetch, localStorage, Service Worker)
- Kein Port-Konflikt möglich
- Kein Runspace-Boundary-Problem
- Perfekt für SPAs

**Nachteile:**
- Nur innerhalb von WebView2 gültig (kein externer Browser-Zugriff)
- Nur im WebView2/HostMode sinnvoll

> **Empfehlung: Dies ist die sauberste und modernste Lösung für PowerEdge im HostMode.** Der gesamte `localserver.ps1` kann für den WebView2-Modus durch Virtual Host Mapping ersetzt werden.

### 2.6 Entscheidungsmatrix

| Ansatz | Komplexität | SPA-Support | Kein HTTP-Server | Empfehlung |
|---|---|---|---|---|
| `localserver.ps1` (Bugfix) | Mittel | ✅ | ❌ | Für externe Browser-Zugriffe |
| Als Modul kapseln | Mittel | ✅ | ❌ | Wenn Server beibehalten werden soll |
| `file://`-URI direkt | Gering | ⚠️ Eingeschränkt | ✅ | Nur für einfache HTML-Seiten |
| **Virtual Host Mapping** | **Gering** | **✅ Voll** | **✅** | **Empfohlen für HostMode** |

---

## 3. Thema: Helper-Funktionen & Dot-Sourcing

### 3.1 Das eigentliche Scope-Problem

Dot-Sourcing (`.$_.FullName`) in PowerEdge lädt die Helper-Funktionen in den **Script-Scope von `PowerEdge.ps1`**. Das ist grundsätzlich korrekt — alle gedot-sourceten Funktionen (`ResolveHttpRoot`, `LoadWebViewDLLs`, `LoadXAMLui` etc.) sind danach im selben Scope verfügbar und werden in `PowerEdge.ps1` erfolgreich aufgerufen.

Das eigentliche Problem entsteht, wenn diese Funktionen **im UI-Runspace** benötigt werden. Der `$uiScript`-Block, der in einem separaten Runspace läuft, hat **keinen Zugriff** auf die gedot-sourceten Funktionen — er kann nur auf `$syncHash`-Daten zugreifen.

```powershell
# Dies schlägt im UI-Runspace fehl:
$uiScript = {
    $result = LoadWebViewDLLs   # ← FEHLER: Funktion existiert nicht in diesem Runspace
}
```

### 3.2 Option A: Dot-Sourcing beibehalten + Funktionen in syncHash injizieren

Die einfachste Sofort-Lösung ist, benötigte Funktionen als **ScriptBlock** in den `$syncHash` einzubetten:

```powershell
# In PowerEdge.ps1, nach dem Dot-Sourcing:
$syncHash.FnLoadDLLs = ${function:LoadWebViewDLLs}

# Im UI-Runspace:
$uiScript = {
    $fn = [scriptblock]::Create($syncHash.FnLoadDLLs)
    & $fn
}
```

> Dieser Ansatz ist pragmatisch, aber wartungsintensiv. Er eignet sich als Übergangslösung.

### 3.3 Option B: Eigenes PowerEdge-Modul (`PowerEdge.Core.psm1`)

Dies ist die **empfohlene langfristige Lösung**. Alle Helper-Funktionen werden in einem einzigen PowerShell-Modul zusammengefasst:

```
data\core\
└── PowerEdge.Core\
    ├── PowerEdge.Core.psd1
    └── PowerEdge.Core.psm1
```

**`PowerEdge.Core.psm1`:**

```powershell
function Invoke-NewStatusObject { ... }
function Invoke-ResolveHttpRoot { ... }
function Invoke-LoadXAMLui      { ... }
function Invoke-LoadWebViewDLLs { ... }
function Invoke-LoadURL         { ... }

Export-ModuleMember -Function *
```

**Aufruf in `PowerEdge.ps1`:**

```powershell
Import-Module (Join-Path $PSScriptRoot "data\core\PowerEdge.Core\PowerEdge.Core.psd1") -Global -Force
```

**Aufruf im UI-Runspace:**

```powershell
$uiScript = {
    Import-Module $syncHash.CoreModulePath -Global -Force
    $result = Invoke-LoadWebViewDLLs -LibDir $syncHash.LibDir
}
# syncHash muss den Pfad mitliefern:
$syncHash.CoreModulePath = Join-Path $PSScriptRoot "data\core\PowerEdge.Core\PowerEdge.Core.psd1"
```

**Vorteile:**
- Einheitlicher Import-Mechanismus für Haupt-Scope und UI-Runspace
- Versionierbar über das Manifest (`.psd1`)
- Einzelne Functions können gezielt exportiert werden
- Kein verstecktes Scope-Problem mehr

### 3.4 Option C: Statische Klasse als Utility-Container

Eine Alternative zu einem Modul ist die Definition aller Helper-Funktionen als **statische Methoden einer PowerShell-Klasse**:

```powershell
class PowerEdgeUtils {
    static [hashtable] NewStatusObject([int]$code, [string]$msg) {
        return @{ code = $code; msg = $msg }
    }

    static [hashtable] ResolveHttpRoot([string]$InputPath) {
        # ... Logik
    }

    static [hashtable] LoadWebViewDLLs([string]$LibDir) {
        # ... Logik
    }
}
```

**Nutzung:**

```powershell
$result = [PowerEdgeUtils]::ResolveHttpRoot($httpRoot)
```

**Vorteile:**
- Typsicherheit durch Methodensignaturen
- Keine Namespace-Kollisionen
- Auch im UI-Runspace nutzbar, wenn die Klassen-Definition in den Runspace übertragen wird (z.B. via `$syncHash.ClassDef`)

**Nachteil:**
- PowerShell-Klassen unterstützen kein Nachladen aus Dateien ohne `using module` — im Runspace-Kontext ist das umständlicher als ein normales Modul.

### 3.5 Fazit und Empfehlung

| Methode | Scope-Sicherheit | Runspace-Kompatibel | Wartbarkeit | Empfehlung |
|---|---|---|---|---|
| Dot-Sourcing (aktuell) | ⚠️ Nur Script-Scope | ❌ Nicht im UI-Runspace | Mittel | Für Übergangslösungen |
| ScriptBlock in syncHash | ⚠️ Umständlich | ✅ | Gering | Kurzfristiger Workaround |
| **Modul (`.psm1`)** | **✅ Global importierbar** | **✅ Via Re-Import** | **Hoch** | **Empfohlen** |
| Statische Klasse | ✅ | ⚠️ Aufwändig | Mittel | Für typsichere Szenarien |

---

## 4. Thema: GUI/WebView2 & Moduswechsel

### 4.1 Konzept: Die vier Betriebsmodi

PowerEdge kann in vier Modi betrieben werden:

| Modus | Beschreibung | WebView2 | WPF-Controls |
|---|---|---|---|
| `Normal` | Reine WPF-Anwendung | ❌ Ausgeblendet/nicht geladen | ✅ Aktiv |
| `Terminal` | PowerShell-Konsole eingebettet | ❌ | ✅ + Terminal-Control |
| `HostMode` | WebView2 als SPA-Host | ✅ Sichtbar | Optional |
| `Secure` | HostMode + InPrivate-Profil | ✅ InPrivate | Optional |

### 4.2 Parameterbasierter Modusstart

Der sauberste Weg für die erste Implementierung ist ein `-Mode`-Parameter:

```powershell
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Normal", "Terminal", "HostMode", "Secure")]
    [string]$Mode = "HostMode",
    ...
)

$syncHash.AppMode = $Mode
```

Im UI-Runspace entscheidet `$syncHash.AppMode`, welche Controls geladen und welche ausgeblendet werden.

### 4.3 WebView2 als ausblendbare Ebene (Layer-Konzept)

Das Layer-Konzept ist technisch **vollständig umsetzbar** in WPF. Der Trick besteht darin, WebView2 und WPF-Controls in einem gemeinsamen `Grid` zu platzieren und jeweils über `Visibility` zu schalten:

```xml
<Grid x:Name="MainGrid">
    <!-- WPF-Layer (immer im DOM, aber ausblendbar) -->
    <ContentPresenter x:Name="WpfLayer"
                      Visibility="Collapsed"/>

    <!-- WebView2-Layer (immer im DOM, aber ausblendbar) -->
    <wv2:WebView2 x:Name="MainWebView"
                  Visibility="Collapsed"/>

    <!-- Terminal-Layer -->
    <Border x:Name="TerminalLayer"
            Visibility="Collapsed"/>
</Grid>
```

**Wechsel-Logik im PowerShell-Code:**

```powershell
function Switch-AppMode {
    param([string]$NewMode)

    # Alle Layer ausblenden
    $wpfLayer.Visibility     = [Visibility]::Collapsed
    $webViewLayer.Visibility = [Visibility]::Collapsed
    $terminalLayer.Visibility= [Visibility]::Collapsed

    switch ($NewMode) {
        "Normal"   { $wpfLayer.Visibility      = [Visibility]::Visible }
        "HostMode" { $webViewLayer.Visibility  = [Visibility]::Visible }
        "Secure"   {
            $webViewLayer.Visibility = [Visibility]::Visible
            # InPrivate-Profil aktivieren (siehe 4.4)
        }
        "Terminal" { $terminalLayer.Visibility = [Visibility]::Visible }
    }
}
```

**Button-Handler für Moduswechsel:**

```powershell
$btnSwitchMode.Add_Click({
    $currentMode = $syncHash.AppMode
    $newMode = if ($currentMode -eq "HostMode") { "Normal" } else { "HostMode" }
    Switch-AppMode -NewMode $newMode
    $syncHash.AppMode = $newMode
})
```

> **Antwort auf die Frage:** Ja, das Umschalten zwischen WPF und WebView2 während des laufenden Betriebs ist **problemlos möglich** — WebView2 muss dafür nicht neu gestartet werden. Ein einfaches `Visibility`-Toggle genügt.

### 4.4 Secure-Modus: InPrivate-Profil für WebView2

WebView2 unterstützt InPrivate-Modus über ein separates `UserDataFolder` ohne persistierten Zustand:

```powershell
# Beim Initialisieren (vor EnsureCoreWebView2Async):
$wv2Props = [Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties]::new()

if ($syncHash.AppMode -eq "Secure") {
    # Temporäres Profil in einem Temp-Ordner (wird beim Beenden gelöscht)
    $tempProfile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "PowerEdge_InPrivate")
    $wv2Props.UserDataFolder = $tempProfile
    # Optional: Nach dem Schließen den Ordner löschen
} else {
    $wv2Props.UserDataFolder = $syncHash.Wv2DataDir
}

$webView.CreationProperties = $wv2Props
```

> **Hinweis:** WebView2 kann nur **ein** `UserDataFolder` pro Instanz haben. Für einen echten Moduswechsel zwischen Normal und Secure zur Laufzeit müsste WebView2 neu erstellt werden. Einfacher ist es, den Modus beim Start über den `-Mode`-Parameter festzulegen.

### 4.5 Modus-Selektor-Dialog

Ein elegantes UX-Konzept: PowerEdge zeigt beim Start einen kleinen Auswahl-Dialog (Splash-Screen) mit den vier Modi. Dieser wird als leichtgewichtiges WPF-Fenster realisiert:

```powershell
# Vor dem Hauptfenster: Modus-Auswahl
$modeSelector = New-ModeSelector  # Gibt gewählten Modus zurück
$selectedMode = $modeSelector.ShowDialog()
```

Oder alternativ als CLI-Parameter für Skriptautomatisierung:

```powershell
.\PowerEdge.ps1 -Mode HostMode -httpRoot ".\data\host\index.html"
```

---

## 5. Thema: WPF-Modus (Pure WPF/XAML)

### 5.1 Was ist der WPF-Modus?

Im WPF-Modus wird WebView2 **nicht geladen oder ausgeblendet**. PowerEdge agiert als klassische .NET WPF-Desktopanwendung. Dieser Modus ist die Basis für Plugin-Erweiterungen, Diagnose-Tools und administrative Oberflächen.

### 5.2 Dynamische Content-Area

Das WPF-Hauptfenster benötigt eine **Content-Region**, die je nach aktivem Plugin oder Funktion unterschiedliche Views laden kann. In WPF realisiert man das mit einem `ContentPresenter` oder einem `Frame`-Control:

```xml
<Grid>
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>  <!-- TitleBar -->
        <RowDefinition Height="Auto"/>  <!-- MenuBar / Toolbar -->
        <RowDefinition Height="*"/>     <!-- Content-Area -->
        <RowDefinition Height="Auto"/>  <!-- StatusBar -->
    </Grid.RowDefinitions>

    <!-- Content-Area: nimmt beliebige WPF-Controls auf -->
    <ContentPresenter x:Name="MainContent" Grid.Row="2"/>
</Grid>
```

**Wechsel zwischen Views:**

```powershell
# Eine neue View (UserControl) laden
$myView = [System.Windows.Controls.TextBlock]::new()
$myView.Text = "Plugin X aktiv"
$MainContent.Content = $myView
```

### 5.3 Externe Anwendungen einbetten (Win32-Fenster in WPF)

Das ist eines der interessantesten Szenarien: eine externe `.exe` direkt **im PowerEdge-Fenster** einbetten. Windows erlaubt das über das Reparenting von Fenstern via Win32-API.

**Prinzip:**

1. Externe Anwendung starten (als Prozess)
2. Fenster-Handle (HWND) des Prozesses ermitteln
3. Das externe Fenster zum Kind von PowerEdges WPF-Fenster machen (`SetParent`)
4. Fensterstil anpassen (`SetWindowLong`)

```powershell
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Embed {
    [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int GWL_STYLE = -16;
    public const int WS_CHILD  = 0x40000000;
}
"@

# Prozess starten
$proc = Start-Process "notepad.exe" -PassThru
Start-Sleep -Milliseconds 800  # Fenster warten lassen

# In WPF-Fenster einbetten
$hostHwnd = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
[Win32Embed]::SetParent($proc.MainWindowHandle, $hostHwnd) | Out-Null
[Win32Embed]::SetWindowLong($proc.MainWindowHandle, [Win32Embed]::GWL_STYLE, [Win32Embed]::WS_CHILD) | Out-Null
[Win32Embed]::MoveWindow($proc.MainWindowHandle, 0, 60, 1200, 700, $true) | Out-Null
```

**Wichtige Einschränkungen:**
- Funktioniert zuverlässig mit Win32-Anwendungen (Notepad, CMD, Explorer-Fenster)
- UWP-/WinUI-Apps können **nicht** eingebettet werden (sie laufen in einem isolierten Container)
- WPF-Apps anderer Hersteller funktionieren grundsätzlich, können aber Rendering-Artefakte zeigen
- Das externe Fenster hat nach dem Reparenting keinen eigenen Titelbalken mehr

### 5.4 Child-Prozess-Überwachung (Alternative zur Einbettung)

Als Alternative zur direkten Einbettung kann PowerEdge externe Prozesse als **überwachte Kind-Prozesse** führen:

```powershell
$childProc = Start-Process "tool.exe" -PassThru

# Überwachungs-Job
$watchJob = Start-Job -ScriptBlock {
    param($procId)
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($p) { $p.WaitForExit() }
    return $procId
} -ArgumentList $childProc.Id

# Im Haupt-Thread: Job-Ergebnis prüfen
Register-EngineEvent -SourceIdentifier "PowerShell.Exiting" -Action {
    if (-not $childProc.HasExited) { $childProc.Kill() }
}
```

**Vorteile des Child-Prozess-Ansatzes:**
- Kein Win32-Hacking nötig
- Prozess kann in eigenem Fenster laufen (oder versteckt im Hintergrund)
- PowerEdge behält volle Kontrolle (Start, Stop, Neustart)
- Auch für CLI-Tools ohne GUI geeignet

### 5.5 Empfehlung: HwndHost für saubere WPF-Integration

Für eine saubere, WPF-konforme Einbettung externer Fenster empfiehlt sich die Verwendung von `HwndHost` aus `System.Windows.Interop`:

```csharp
// In einem Add-Type Block:
public class ExternalAppHost : HwndHost {
    private IntPtr _childHwnd;

    public ExternalAppHost(IntPtr childHwnd) {
        _childHwnd = childHwnd;
    }

    protected override HandleRef BuildWindowCore(HandleRef hwndParent) {
        SetParent(_childHwnd, hwndParent.Handle);
        // Style anpassen...
        return new HandleRef(this, _childHwnd);
    }

    protected override void DestroyWindowCore(HandleRef hwnd) {
        // Cleanup
    }
}
```

```powershell
$host = [ExternalAppHost]::new($proc.MainWindowHandle)
$borderContainer.Child = $host  # In WPF-Border einbetten
```

> Diese Methode integriert sich sauber in den WPF Layout-Mechanismus, reagiert korrekt auf Resize-Events und wird von Microsoft explizit für diesen Use Case empfohlen.

---

## 6. Thema: Terminal-Modus

### 6.1 Grundkonzept

Der Terminal-Modus soll eine **eingebettete PowerShell-Konsole** innerhalb von PowerEdge darstellen, ergänzt um exklusive PowerEdge-Befehle. Dieses Konzept ist technisch umsetzbar, erfordert aber einen durchdachten Ansatz.

### 6.2 Option A: Windows Terminal / Konsolenfenster via HwndHost einbetten

Analog zur externen Anwendungseinbettung (Abschnitt 5.3) kann ein PowerShell-Konsolenfenster oder Windows Terminal eingebettet werden:

```powershell
# PowerShell-Konsole in einem neuen Fenster starten und einbetten
$psProc = Start-Process "pwsh.exe" -ArgumentList "-NoExit" -PassThru
Start-Sleep -Milliseconds 1500

$hwnd = $psProc.MainWindowHandle
# ... HwndHost-Einbettung wie in Abschnitt 5.3
```

**Problem:** Die eingebettete Konsole ist eine eigenständige PowerShell-Instanz ohne Zugriff auf PowerEdge-Funktionen und -Variablen.

**Lösung:** Beim Start ein Profil-Skript mitgeben, das PowerEdge-Befehle definiert:

```powershell
$profileScript = @"
Import-Module '$($global:coreModulePath)' -Global
Write-Host 'PowerEdge Terminal v1.01.x' -ForegroundColor Cyan
Write-Host 'Exklusive Befehle: Get-PERegistry, Invoke-PEFileBatch, ...' -ForegroundColor Yellow
"@

$tmpProfile = [System.IO.Path]::GetTempFileName() + ".ps1"
$profileScript | Set-Content $tmpProfile

$psProc = Start-Process "pwsh.exe" -ArgumentList "-NoExit", "-File", $tmpProfile -PassThru
```

### 6.3 Option B: Pseudo-Terminal mit WPF RichTextBox (Eigenbau-Terminal)

Eine vollständig in WPF implementierte Terminal-Emulation mit `RichTextBox` und `TextBox` als Eingabezeile:

```xml
<Grid x:Name="TerminalLayer">
    <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Ausgabebereich -->
    <RichTextBox x:Name="TerminalOutput"
                 Background="#1E1E1E"
                 Foreground="#CCCCCC"
                 FontFamily="Cascadia Code, Consolas"
                 IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto"/>

    <!-- Eingabezeile -->
    <DockPanel Grid.Row="1" Background="#252526">
        <TextBlock Text="PS> " Foreground="#4EC9B0"
                   VerticalAlignment="Center" Margin="5,0"/>
        <TextBox x:Name="TerminalInput"
                 Background="Transparent"
                 Foreground="White"
                 CaretBrush="White"
                 BorderThickness="0"/>
    </DockPanel>
</Grid>
```

**PowerShell-Backend:**

```powershell
$TerminalInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Return) {
        $cmd = $TerminalInput.Text.Trim()
        $TerminalInput.Clear()

        # Exklusive PowerEdge-Befehle prüfen
        if ($cmd -match "^pe-") {
            Invoke-PECommand -Command $cmd -OutputBox $TerminalOutput
        } else {
            # Standard-PowerShell in separatem Runspace ausführen
            Invoke-CommandInRunspace -Command $cmd -OutputBox $TerminalOutput
        }
    }
})
```

**Befehlsausführung in separatem Runspace:**

```powershell
function Invoke-CommandInRunspace {
    param([string]$Command, $OutputBox)

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript($Command) | Out-Null

    $OutputBox.Dispatcher.Invoke({
        $para = [System.Windows.Documents.Paragraph]::new()
        $para.Inlines.Add([System.Windows.Documents.Run]::new("> $Command`n"))
        $OutputBox.Document.Blocks.Add($para)
    })

    $result = $ps.Invoke()
    $output = $result | Out-String

    $OutputBox.Dispatcher.Invoke({
        $para = [System.Windows.Documents.Paragraph]::new()
        $para.Inlines.Add([System.Windows.Documents.Run]::new($output))
        $OutputBox.Document.Blocks.Add($para)
        $OutputBox.ScrollToEnd()
    })

    $ps.Dispose()
    $rs.Close()
}
```

### 6.4 Exklusive PowerEdge-Terminal-Befehle

Folgende Kategorien für exklusive Befehle wären denkbar:

**Registry-Befehle:**
```
pe-reg get   HKLM:\SOFTWARE\PowerEdge\Settings
pe-reg set   HKLM:\SOFTWARE\PowerEdge\Settings\Mode -Value "Terminal"
pe-reg watch HKLM:\SOFTWARE\PowerEdge\Settings  (Live-Monitoring)
```

**Massen-Datei-Operationen:**
```
pe-file rename  -Path "C:\Data" -Filter "*.txt" -Pattern "old" -Replace "new"
pe-file batch   -Operations ".\batch_config.json"
pe-file hash    -Path "C:\Important" -Algorithm SHA256 -Export "hashes.csv"
```

**Windows-System-Befehle:**
```
pe-sys info       (Systeminformationen kompakt)
pe-sys service    list|start|stop|restart <servicename>
pe-sys process    list|kill|watch <processname>
pe-sys network    status|flush-dns|test <host>
```

**PowerEdge-interne Befehle:**
```
pe-mode   switch <Normal|HostMode|Secure>
pe-load   <url>         (Im HostMode: URL laden)
pe-plugin list|load|unload <pluginname>
```

### 6.5 Option C: Windows Terminal Control (WinUI 3 Integration)

Microsoft bietet das **Windows Terminal Control** als WinUI 3-Komponente an. Die Integration in WPF ist möglich über die **XAML Islands**-Technologie, ist aber komplex und erfordert .NET 6+ und zusätzliche NuGet-Pakete.

**Empfehlung für PowerEdge:** Für v1.01.x ist Option B (Eigenbau-Terminal mit RichTextBox) der pragmatischste Ansatz. Option A (Eingebettete pwsh.exe) ist schneller zu implementieren, bietet aber weniger Kontrolle. Option C (Windows Terminal Control) ist langfristig die beste User Experience, aber der Aufwand ist erheblich.

---

## 7. Empfohlene Gesamtarchitektur

### 7.1 Zielarchitektur für PowerEdge v1.02.x

```
PowerEdge/
├── PowerEdge.ps1              ← Hauptskript (schlank, nur Orchestrierung)
├── data/
│   ├── config.json
│   ├── core/
│   │   ├── PowerEdge.Core/    ← Neues Modul (ersetzt fxlib + integriert LocalServer)
│   │   │   ├── PowerEdge.Core.psd1
│   │   │   └── PowerEdge.Core.psm1
│   │   ├── LocalServer/       ← Optional: separates Server-Modul
│   │   │   ├── LocalServer.psd1
│   │   │   └── LocalServer.psm1
│   │   └── lib/               ← WebView2 DLLs
│   ├── host/                  ← Web-Root
│   ├── ui/
│   │   ├── main.window.xml    ← Erweitertes XAML mit allen Layern
│   │   └── mode-select.xml    ← Modus-Auswahl-Dialog
│   └── plugins/               ← Plugin-Verzeichnis (zukünftig)
```

### 7.2 Empfohlene Lösungen je Thema (Kurzübersicht)

| Thema | Empfehlung | Priorität |
|---|---|---|
| Local Server / home.html | `$syncHash`-Befüllungs-Bug fixen + Virtual Host Mapping für HostMode | 🔴 Sofort |
| Helper-Funktionen Scope | Modul `PowerEdge.Core.psm1` einführen | 🟠 Kurzfristig |
| Modi-Konzept | `-Mode`-Parameter + Layer-Visibility in XAML | 🟡 Mittelfristig |
| Secure-Modus | Separates temp. UserDataFolder für InPrivate | 🟡 Mittelfristig |
| WPF-Modus | HwndHost für externe App-Einbettung | 🟢 Langfristig |
| Terminal-Modus | RichTextBox-Terminal mit pe-Befehlsprefix | 🟢 Langfristig |

### 7.3 Sofort umsetzbarer Fix für das home.html-Problem

Die minimale Änderung in `PowerEdge.ps1`, die das Problem mit `home.html` behebt:

```powershell
# ──────────────────────────────────────────────────────────────
# SCHRITT 1: Standardauflösung des Pfades
$pathResult = ResolveHttpRoot -InputPath $httpRoot
if ($pathResult.code -ne 0) { Write-Error $pathResult.msg; exit 1 }
$resolvedHtmlPath = $pathResult.msg

# SCHRITT 2: Server-URL hat Vorrang (MUSS nach ResolveHttpRoot stehen)
if ($global:useserver -eq $true -and [string]::IsNullOrEmpty($httpRoot)) {
    $resolvedHtmlPath = $global:homeURL   # ← http://localhost:8080/home.html
}

# SCHRITT 3: ERST JETZT den syncHash mit dem korrekten Pfad befüllen
$syncHash = [hashtable]::Synchronized(@{
    HtmlPath = $resolvedHtmlPath   # ← Jetzt garantiert die richtige URL
    ...
})
# ──────────────────────────────────────────────────────────────
```

---

*Dokumentation erstellt von Sonar für das PowerEdge-Projekt (v1.01.01)*
*Datum: April 2026*
*GitHub: [https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge](https://github.com/praetoriani/PowerShell.Lib/tree/main/PowerEdge)*
