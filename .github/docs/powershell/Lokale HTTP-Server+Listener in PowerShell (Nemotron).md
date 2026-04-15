# Lokale HTTP-Server/Listener in PowerShell

> **Dokumentation:** Konzepte, Implementierung, Architektur & Sicherheit  
> **Zielgruppe:** PowerShell-Entwickler, IT-Professionals, Full-Stack-Entwickler  
> **Stand:** April 2026

---

## Inhaltsverzeichnis

1. [Szenario & Use Cases](#1-szenario--use-cases)
2. [HTTP-Server vs. HTTP-Listener – Die Unterschiede](#2-http-server-vs-http-listener--die-unterschiede)
3. [Möglichkeiten zur SPA-Bereitstellung mit PowerShell](#3-möglichkeiten-zur-spa-bereitstellung-mit-powershell)
4. [Control-Bridge: Server-Steuerung von außen](#4-control-bridge-server-steuerung-von-außen)
5. [Custom-Domains statt localhost](#5-custom-domains-statt-localhost)
6. [Architektur: Skript vs. Modul](#6-architektur-skript-vs-modul)
7. [Grundfunktionen & Implementierungsaufwand](#7-grundfunktionen--implementierungsaufwand)
8. [Sicherheit](#8-sicherheit)

---

## 1. Szenario & Use Cases

### Worum geht es?

Stell dir vor, du hast eine moderne Web-Applikation – z. B. ein Angular-Dashboard, eine React-SPA oder eine statische HTML-Website – fertig entwickelt und möchtest diese auf einem **Windows-Rechner lokal betreiben**, ohne dafür einen vollwertigen Webserver wie IIS, Apache oder nginx installieren zu müssen. Genau das ist der Kern dieses Dokuments.

Ein lokaler HTTP-Server in PowerShell stellt Dateien aus einem definierten Wurzelverzeichnis über das HTTP-Protokoll bereit, sodass jeder Browser auf demselben Rechner (oder im selben Netzwerk) die Anwendung über eine URL wie `http://localhost:8080/` aufrufen kann – vollständig, ohne Einschränkungen.

### Typische Anwendungsfälle

| Szenario | Beschreibung |
|---|---|
| **Lokale SPA-Entwicklung** | Angular, React oder Vue-Apps lokal testen, ohne `ng serve` oder `npm start` |
| **Offline-Webanwendungen** | Dashboards, Tools oder Dokumentationen ohne Internetverbindung bereitstellen |
| **Interne Tools** | Firmeninterne Lightweight-Apps ohne Server-Infrastruktur |
| **Kiosk-Systeme** | Auf dedizierten Rechnern (z. B. Info-Terminal) eine Webanwendung starten |
| **Automatisierung & CI** | Schnelles Testen von Build-Artefakten in CI/CD-Pipelines |
| **Portable Anwendungen** | Eine WebApp als portable `.zip`-Datei inkl. eigenem Server ausliefern |
| **API-Stubs / Mocking** | Lokale REST-API-Endpunkte simulieren für Frontend-Tests |
| **PWA-Hosting** | Progressive Web Apps lokal registrieren (ServiceWorker benötigt HTTP-Kontext) |

### Vorteile gegenüber klassischen Ansätzen

- **Keine Installation nötig:** PowerShell und .NET sind auf jedem modernen Windows-System vorhanden.
- **Vollständige Kontrolle:** Kein komplexes Konfigurationsformat – alles in vertrautem PowerShell-Code.
- **Portabilität:** Das Modul/Skript lässt sich mit der Anwendung zusammen ausliefern.
- **Kein Overhead:** Kein IIS-Dienst, kein Prozess-Daemon – nur ein einziger PowerShell-Prozess.
- **Erweiterbarkeit:** Routing, API-Endpunkte, Authentifizierung – vollständig selbst steuerbar.
- **Kein Netzwerk-Exposure:** Der Server hört standardmäßig nur auf `localhost`, ist also von außen nicht erreichbar (es sei denn, explizit konfiguriert).

---

## 2. HTTP-Server vs. HTTP-Listener – Die Unterschiede

### Der Begriff "HTTP-Listener"

Ein **HTTP-Listener** (in .NET: `System.Net.HttpListener`) ist eine **Klasse der .NET-Standardbibliothek**, die es einer Anwendung ermöglicht, auf einem bestimmten Port auf eingehende HTTP-Anfragen zu warten (*to listen = lauschen*). Er ist das **technische Fundament**, auf dem ein HTTP-Server aufgebaut wird.

Der Listener ist gewissermaßen das "Ohr" – er empfängt Anfragen, gibt Kontextobjekte zurück (`HttpListenerContext`), aber **tut selbst nichts mit den Daten**. Was mit einer eingehenden Anfrage passiert – ob eine Datei gelesen, ein API-Ergebnis zurückgesendet oder ein Fehler gemeldet wird – das entscheidet der Code *um* den Listener herum.

```powershell
# Minimaler HTTP-Listener in PowerShell – 10 Zeilen
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()

$context  = $listener.GetContext()    # blockiert, bis eine Anfrage kommt
$response = $context.Response
$buffer   = [System.Text.Encoding]::UTF8.GetBytes("Hello World")
$response.OutputStream.Write($buffer, 0, $buffer.Length)
$response.OutputStream.Close()

$listener.Stop()
```

### Der Begriff "HTTP-Server"

Ein **HTTP-Server** ist das **vollständige System**, das auf Basis eines Listeners gebaut wird. Er enthält zusätzlich:

- **Routing-Logik:** Welche URL liefert welche Datei/Antwort?
- **MIME-Type-Mapping:** Welcher Content-Type-Header wird für `.js`, `.css`, `.wasm` etc. gesetzt?
- **Fehlerbehandlung:** Was passiert bei 404, 500 etc.?
- **Logging:** Werden Anfragen protokolliert?
- **Lifecycle-Management:** Starten, Stoppen, Neustarten des Dienstes.
- **Sicherheitslogik:** Zugriffsbeschränkungen, Header-Sanitizing etc.

### Tabellarischer Vergleich

| Merkmal | HTTP-Listener (`HttpListener`) | HTTP-Server (vollständig) |
|---|---|---|
| **Ebene** | .NET-Klasse / Low-Level-API | Applikations-Ebene |
| **Liefert** | Roh-Anfrage/Antwort-Objekte | Vollständige Request-Response-Verarbeitung |
| **Routing** | Nein | Ja |
| **MIME-Types** | Nein | Ja |
| **Datei-Serving** | Nein | Ja |
| **Analogie** | Ein Lauscher am Türspion | Der vollständige Empfangsbereich mit Rezeption |
| **In PowerShell** | `[System.Net.HttpListener]` | Eigenes Skript/Modul um den Listener |

> **Fazit:** In PowerShell *implementierst du selbst* den HTTP-Server – der `HttpListener` ist dabei das einzige .NET-Werkzeug, das du brauchst. Alle anderen Funktionen baust du drumherum.

---

## 3. Möglichkeiten zur SPA-Bereitstellung mit PowerShell

### Das Kernproblem bei SPAs

Single Page Applications (Angular, React, Vue etc.) haben im Vergleich zu klassischen Websites eine wichtige Eigenschaft: **Client-seitiges Routing**. Ruft der Nutzer z. B. `http://localhost:8080/dashboard/users` direkt auf, existiert diese Datei physisch nicht im `dist`-Ordner. Nur die `index.html` existiert – der Rest wird durch JavaScript im Browser aufgelöst.

Ein naiver Datei-Server würde in diesem Fall einen **404-Fehler** zurückgeben. Ein SPA-tauglicher Server muss daher bei jeder Anfrage, die keine echte Datei trifft, stattdessen die `index.html` ausliefern (**History API Fallback**).

### Ansatz 1: `System.Net.HttpListener` (Empfohlen)

Dies ist der **direkteste und leistungsfähigste Weg**. Du verwendest die eingebaute .NET-Klasse direkt in PowerShell.

**Vorteile:**
- Kein Fremd-Tool erforderlich
- Vollständige Kontrolle über Headers, MIME-Types, Status-Codes
- Unterstützt SPA-Fallback, API-Endpunkte, Custom-Routing
- Läuft als Background-Job oder Runspace (unsichtbar)

**Kernlogik für SPA-Hosting:**

```powershell
function Resolve-FilePath {
    param([string]$RootPath, [string]$UrlPath)

    # URL-Pfad in Dateipfad übersetzen
    $relativePath = $UrlPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $fullPath = Join-Path $RootPath $relativePath

    # Existiert die Datei? Direkt zurückgeben
    if (Test-Path $fullPath -PathType Leaf) { return $fullPath }

    # Ist es ein Verzeichnis? index.html suchen
    if (Test-Path $fullPath -PathType Container) {
        $indexPath = Join-Path $fullPath "index.html"
        if (Test-Path $indexPath) { return $indexPath }
    }

    # SPA-Fallback: Alle unbekannten Pfade -> index.html im Root
    $fallback = Join-Path $RootPath "index.html"
    if (Test-Path $fallback) { return $fallback }

    return $null  # 404
}
```

**MIME-Type-Tabelle (Auszug für vollständiges MIME-Mapping):**

```powershell
$MimeTypes = @{
    # Web-Grundlagen
    '.html'   = 'text/html; charset=utf-8'
    '.htm'    = 'text/html; charset=utf-8'
    '.css'    = 'text/css; charset=utf-8'
    '.js'     = 'application/javascript; charset=utf-8'
    '.mjs'    = 'application/javascript; charset=utf-8'
    '.json'   = 'application/json; charset=utf-8'
    '.map'    = 'application/json'

    # Bilder
    '.png'    = 'image/png'
    '.jpg'    = 'image/jpeg'
    '.jpeg'   = 'image/jpeg'
    '.gif'    = 'image/gif'
    '.svg'    = 'image/svg+xml'
    '.ico'    = 'image/x-icon'
    '.webp'   = 'image/webp'
    '.avif'   = 'image/avif'

    # Schriften
    '.woff'   = 'font/woff'
    '.woff2'  = 'font/woff2'
    '.ttf'    = 'font/ttf'
    '.otf'    = 'font/otf'
    '.eot'    = 'application/vnd.ms-fontobject'

    # Audio/Video
    '.mp4'    = 'video/mp4'
    '.webm'   = 'video/webm'
    '.mp3'    = 'audio/mpeg'
    '.ogg'    = 'audio/ogg'

    # Dokumente & Daten
    '.pdf'    = 'application/pdf'
    '.xml'    = 'application/xml'
    '.csv'    = 'text/csv'
    '.txt'    = 'text/plain; charset=utf-8'

    # WebAssembly
    '.wasm'   = 'application/wasm'

    # Manifest & PWA
    '.webmanifest' = 'application/manifest+json'
}
```

### Ansatz 2: PowerShell-Job mit `Start-Job`

Für sehr einfache Szenarien kann der Server als PowerShell-Hintergrund-Job gestartet werden.

```powershell
$job = Start-Job -ScriptBlock {
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:8080/")
    $listener.Start()
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        # ... Request verarbeiten ...
    }
}
```

**Nachteil:** Jobs laufen in separaten Prozessen, Kommunikation über Pipelines ist umständlich, und Performance bei vielen Anfragen leidet.

### Ansatz 3: PowerShell-Runspace (Empfohlen für Hintergrundbetrieb)

Runspaces sind **leichtgewichtige Threads innerhalb desselben Prozesses** und damit deutlich effizienter als Jobs:

```powershell
$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$runspace.Open()

$ps = [System.Management.Automation.PowerShell]::Create()
$ps.Runspace = $runspace
$ps.AddScript({
    param($RootPath, $Port)
    # Server-Logik hier
}).AddArgument("C:\WebApp").AddArgument(8080)

$handle = $ps.BeginInvoke()
```

**Vorteile gegenüber Jobs:**
- Gleicher Prozess, direkter Speicherzugriff möglich
- Kein separater PowerShell-Prozess
- Schneller Start, geringerer Overhead
- Einfacheres Lifecycle-Management

### Ansatz 4: Externe Tools (Alternativen)

Falls eine vollständige PowerShell-Implementierung zu aufwändig ist, existieren Alternativen:

| Tool | Beschreibung | Steuerbar via PS? |
|---|---|---|
| `http-server` (npm/npx) | Simpler Node.js-Server | Ja (Prozess-Start) |
| `python -m http.server` | Python-Built-in | Ja, aber kein SPA-Fallback |
| **Caddy** | Moderner Webserver als einzelne Exe | Ja (Start/Stop) |
| **IIS Express** | Teil von VS/WebMatrix | Ja (via COM) |

---

## 4. Control-Bridge: Server-Steuerung von außen

### Die Idee

Du möchtest einen laufenden, unsichtbaren Server-Prozess von einem **anderen Skript oder Programm** aus steuern können – ohne direkte Prozess-Interaktion, Shared Memory oder andere komplexe IPC-Mechanismen. Die eleganteste Lösung: **Der Server stellt sich selbst eine interne Steuerungs-API bereit.**

### Konzept: Interne Admin-Endpunkte

Der Server lauscht nicht nur auf normale Web-Anfragen, sondern reserviert einen **speziellen URL-Pfad** (z. B. `/ctrl/`) als Steuerungsschnittstelle. Nur Anfragen von `localhost` werden akzeptiert:

```powershell
# Im Server: Admin-Endpunkte definieren
if ($request.Url.AbsolutePath -like '/ctrl/*') {
    # Sicherheitsprüfung: Nur localhost erlauben
    if ($request.RemoteEndPoint.Address -ne [System.Net.IPAddress]::Loopback) {
        Send-Response $response 403 "Forbidden"
        continue
    }

    switch ($request.Url.AbsolutePath) {
        '/ctrl/status'  { Send-JsonResponse $response @{ running = $true; pid = $PID } }
        '/ctrl/stop'    { Send-Response $response 200 "Stopping"; $listener.Stop() }
        '/ctrl/reload'  { Reload-Configuration; Send-Response $response 200 "Reloaded" }
        '/ctrl/rootdir' { Send-JsonResponse $response @{ root = $script:RootPath } }
    }
}
```

### Steuer-Skript (Client-Seite)

Ein zweites, unabhängiges PowerShell-Skript kann den Server über diese API steuern:

```powershell
# server-control.ps1
param(
    [ValidateSet('status','stop','reload')]
    [string]$Action = 'status',
    [int]$Port = 8080
)

$baseUrl = "http://localhost:$Port/ctrl"

try {
    $result = Invoke-RestMethod -Uri "$baseUrl/$Action" -Method Get
    Write-Host "Server-Antwort: $($result | ConvertTo-Json)"
} catch {
    Write-Warning "Server antwortet nicht. Läuft er auf Port $Port?"
}
```

### Alternative: Named Pipes (ohne HTTP)

Für robustere IPC-Kommunikation (unabhängig vom HTTP-Port) können Named Pipes verwendet werden:

```powershell
# Server-Seite: Pipe-Listener in eigenem Runspace
$pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new(
    "LocalWebServerControl",
    [System.IO.Pipes.PipeDirection]::InOut
)

# Client-Seite: Pipe-Client
$pipeClient = [System.IO.Pipes.NamedPipeClientStream]::new(
    ".", "LocalWebServerControl",
    [System.IO.Pipes.PipeDirection]::InOut
)
$pipeClient.Connect(3000)  # Timeout: 3 Sekunden
```

**Named Pipes** sind besonders geeignet, wenn der HTTP-Port anderweitig belegt ist oder die Steuerungskommunikation vollständig vom Web-Traffic getrennt sein soll.

### Kommunikation via Prozess-ID

Die direkte Steuerung über eine Prozess-ID ist in PowerShell **nicht nativ möglich** (kein Shared Memory, keine einfache Signal-API wie in Linux). Der empfohlene Weg ist daher:

1. Der Server schreibt beim Start seine PID und den Control-Port in eine **Status-Datei** (z. B. `%TEMP%\localserver.pid`).
2. Das Steuer-Skript liest diese Datei und baut darüber die HTTP-Verbindung auf.

```powershell
# Server schreibt beim Start:
@{
    PID         = $PID
    Port        = $Port
    ControlPort = $ControlPort
    StartedAt   = (Get-Date -Format 'o')
    RootPath    = $RootPath
} | ConvertTo-Json | Set-Content "$env:TEMP\localserver.json"

# Steuer-Skript liest:
$serverInfo = Get-Content "$env:TEMP\localserver.json" | ConvertFrom-Json
$controlUrl = "http://localhost:$($serverInfo.ControlPort)/ctrl"
```

---

## 5. Custom-Domains statt localhost

### Technische Grundlage

Windows verwendet für die Namensauflösung zuerst die **`hosts`-Datei** (`C:\Windows\System32\drivers\etc\hosts`), bevor DNS-Server befragt werden. Das bedeutet: Indem du einen Eintrag wie `127.0.0.1 localweb` in diese Datei schreibst, wird `http://localweb/` auf deinem Rechner zu `127.0.0.1` aufgelöst – also zu deinem eigenen Server.

### Schritt-für-Schritt: Custom-Domain einrichten

**1. hosts-Datei bearbeiten (Administratorrechte erforderlich):**

```powershell
# Als Administrator ausführen:
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1`tlocalweb"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1`twebengine"
```

**2. HttpListener auf den Custom-Hostnamen binden:**

```powershell
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localweb:80/")    # Custom-Domain
$listener.Prefixes.Add("http://localhost:8080/")  # Zusätzlich localhost
$listener.Start()
```

**3. URL ACL via `netsh` registrieren (für Port 80, falls kein Admin-Kontext):**

```powershell
# Einmalig ausführen (Adminrechte):
netsh http add urlacl url="http://localweb:80/" user="DOMÄNE\Benutzername"
```

### Einschränkungen & Hinweise

- **Port 80** erfordert Administratorrechte oder eine `netsh`-URL-Reservierung.
- **Namensauflösung gilt nur lokal** – andere Rechner im Netzwerk kennen den Hostnamen nicht (ohne eigenen DNS-Eintrag).
- Browser zeigen möglicherweise Sicherheitswarnungen bei unbekannten Hostnamen ohne HTTPS.
- Für mehrere virtuelle Hostnamen können **mehrere Prefixes** am selben `HttpListener` registriert werden.
- **Empfehlung Port:** Für Custom-Domains Port 80 (erfordert Adminrechte) oder einen High-Port (>1024, z. B. 8080) mit URL-Rewrite.

---

## 6. Architektur: Skript vs. Modul

### Einzelnes Skript vs. PowerShell-Modul

Die Entscheidung zwischen einem einzelnen `.ps1`-Skript und einem vollständigen PowerShell-Modul (`.psm1` + Manifest `.psd1`) hat weitreichende Auswirkungen auf Wartbarkeit, Wiederverwendbarkeit und Professionalität.

| Aspekt | Einzelnes Skript | PowerShell-Modul |
|---|---|---|
| **Einstiegshürde** | Sehr niedrig | Moderat (Manifest, Struktur) |
| **Wiederverwendbarkeit** | Gering | Hoch (`Import-Module`) |
| **Dependency-Check** | Manuell | Im Modul-Loader integrierbar |
| **Versionierung** | Schwierig | Eingebaut (`.psd1`) |
| **Verteilung** | Dateikopie | PSGallery / NuGet |
| **Autark-Betrieb** | Bedingt | Vollständig möglich |
| **Testbarkeit** | Schwierig | Mit Pester-Tests |

### Empfohlene Modulstruktur

```
LocalWebServer/
├── LocalWebServer.psd1          # Modul-Manifest (Version, Author, Dependencies)
├── LocalWebServer.psm1          # Haupt-Modul (exportiert public functions)
│
├── Private/                     # Interne Funktionen (nicht exportiert)
│   ├── Start-HttpListener.ps1
│   ├── Invoke-RequestHandler.ps1
│   ├── Get-MimeType.ps1
│   ├── Send-FileResponse.ps1
│   ├── Send-ErrorResponse.ps1
│   ├── Start-ControlBridge.ps1
│   └── Test-SystemRequirements.ps1
│
├── Public/                      # Öffentliche API (exportiert)
│   ├── Start-LocalWebServer.ps1
│   ├── Stop-LocalWebServer.ps1
│   ├── Restart-LocalWebServer.ps1
│   ├── Get-LocalWebServerStatus.ps1
│   └── Set-LocalWebServerConfig.ps1
│
├── Config/
│   └── MimeTypes.json           # MIME-Type-Definitionen ausgelagert
│
└── Tests/
    ├── Start-LocalWebServer.Tests.ps1
    └── MimeType.Tests.ps1
```

### Das Modul-Manifest (`.psd1`)

```powershell
@{
    ModuleVersion     = '1.0.0'
    GUID              = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author            = 'Dein Name'
    Description       = 'Lokaler HTTP-Server für Web-Apps und SPAs'
    PowerShellVersion = '5.1'
    RootModule        = 'LocalWebServer.psm1'

    FunctionsToExport = @(
        'Start-LocalWebServer',
        'Stop-LocalWebServer',
        'Restart-LocalWebServer',
        'Get-LocalWebServerStatus',
        'Set-LocalWebServerConfig'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('HTTP', 'WebServer', 'SPA', 'LocalServer')
        }
    }
}
```

### Vorteile des Modul-Ansatzes im Detail

**Selbst-check beim Laden (`Test-SystemRequirements.ps1`):**

```powershell
function Test-SystemRequirements {
    $issues = @()

    # .NET-Version prüfen
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 oder höher erforderlich."
    }

    # Port-Verfügbarkeit prüfen
    $portInUse = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($portInUse) {
        $issues += "Port 8080 ist bereits belegt (PID: $($portInUse.OwningProcess))."
    }

    # Adminrechte für Port < 1024
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $issues += "Keine Administratorrechte. Port 80 nicht verfügbar."
    }

    if ($issues.Count -gt 0) {
        $issues | ForEach-Object { Write-Warning $_ }
        return $false
    }
    return $true
}
```

---

## 7. Grundfunktionen & Implementierungsaufwand

### Pflichtfunktionen für einen vollständigen Server

Folgende Funktionen sind **zwingend erforderlich**, um die beschriebenen Anforderungen zu erfüllen:

| Funktion | Beschreibung | Komplexität |
|---|---|---|
| **HttpListener-Setup** | Listener initialisieren, Prefix registrieren, starten/stoppen | ⭐ Einfach |
| **Datei-Serving** | Dateien aus Root-Verzeichnis lesen und als Bytes senden | ⭐ Einfach |
| **MIME-Type-Mapping** | Dateiendung → Content-Type-Header | ⭐ Einfach |
| **SPA-Fallback** | Unbekannte Pfade → `index.html` | ⭐⭐ Mittel |
| **404/500-Handling** | Fehlerseiten senden | ⭐ Einfach |
| **Hintergrundbetrieb** | Runspace/Job für unsichtbaren Betrieb | ⭐⭐ Mittel |
| **Control-Bridge** | Admin-API-Endpunkte für externe Steuerung | ⭐⭐ Mittel |
| **Request-Logging** | Anfragen protokollieren | ⭐ Einfach |
| **Config-Management** | Root-Pfad, Port etc. konfigurierbar | ⭐⭐ Mittel |
| **Graceful Shutdown** | Laufende Anfragen vor Stop abschließen | ⭐⭐⭐ Komplex |
| **Range-Requests** | Für Video-Streaming (Byte-Range) | ⭐⭐⭐ Komplex |
| **Caching-Headers** | `Cache-Control`, `ETag`, `Last-Modified` | ⭐⭐ Mittel |
| **Gzip-Komprimierung** | Antworten komprimieren | ⭐⭐⭐ Komplex |

### Vollständiger Server-Kern (Referenz-Implementierung)

```powershell
function Start-LocalWebServer {
    [CmdletBinding()]
    param(
        [string]$RootPath  = ".",
        [int]$Port         = 8080,
        [switch]$Background,
        [switch]$SpaMode
    )

    $RootPath = Resolve-Path $RootPath

    $serverBlock = {
        param($RootPath, $Port, $SpaMode, $MimeTypes)

        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://localhost:$Port/")
        $listener.Start()

        Write-Host "[LocalWebServer] Gestartet auf http://localhost:$Port/"
        Write-Host "[LocalWebServer] Root: $RootPath"

        while ($listener.IsListening) {
            try {
                $context  = $listener.GetContext()
                $request  = $context.Request
                $response = $context.Response

                $urlPath = [Uri]::UnescapeDataString($request.Url.AbsolutePath)

                # Control-Endpunkte
                if ($urlPath -like '/ctrl/*') {
                    $isLocal = $request.RemoteEndPoint.Address.Equals(
                        [System.Net.IPAddress]::Loopback)
                    if (-not $isLocal) {
                        $response.StatusCode = 403
                        $response.OutputStream.Close()
                        continue
                    }
                    switch ($urlPath) {
                        '/ctrl/stop' {
                            $response.StatusCode = 200
                            $buf = [Text.Encoding]::UTF8.GetBytes('{"status":"stopping"}')
                            $response.OutputStream.Write($buf, 0, $buf.Length)
                            $response.OutputStream.Close()
                            $listener.Stop()
                            return
                        }
                        '/ctrl/status' {
                            $json = '{"status":"running","pid":' + $PID + '}'
                            $buf = [Text.Encoding]::UTF8.GetBytes($json)
                            $response.ContentType = 'application/json'
                            $response.OutputStream.Write($buf, 0, $buf.Length)
                            $response.OutputStream.Close()
                            continue
                        }
                    }
                }

                # Dateipfad auflösen
                $rel  = $urlPath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
                $full = Join-Path $RootPath $rel

                # Path-Traversal verhindern
                if (-not $full.StartsWith($RootPath)) {
                    $response.StatusCode = 403
                    $response.OutputStream.Close()
                    continue
                }

                # Verzeichnis -> index.html
                if (Test-Path $full -PathType Container) {
                    $full = Join-Path $full "index.html"
                }

                # SPA-Fallback
                if ($SpaMode -and -not (Test-Path $full -PathType Leaf)) {
                    $full = Join-Path $RootPath "index.html"
                }

                if (Test-Path $full -PathType Leaf) {
                    $ext  = [IO.Path]::GetExtension($full).ToLower()
                    $mime = if ($MimeTypes[$ext]) { $MimeTypes[$ext] } else { 'application/octet-stream' }
                    $data = [IO.File]::ReadAllBytes($full)

                    $response.StatusCode  = 200
                    $response.ContentType = $mime
                    $response.ContentLength64 = $data.LongLength

                    # Security-Header
                    $response.Headers.Add("X-Content-Type-Options", "nosniff")
                    $response.Headers.Add("X-Frame-Options", "SAMEORIGIN")

                    $response.OutputStream.Write($data, 0, $data.Length)
                } else {
                    $response.StatusCode = 404
                    $buf = [Text.Encoding]::UTF8.GetBytes("<h1>404 - Not Found</h1>")
                    $response.ContentType = "text/html"
                    $response.OutputStream.Write($buf, 0, $buf.Length)
                }

                $response.OutputStream.Close()

            } catch {
                Write-Warning "[LocalWebServer] Fehler: $_"
            }
        }

        $listener.Close()
    }

    if ($Background) {
        $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $rs.Open()
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript($serverBlock).AddArgument($RootPath).AddArgument($Port) `
           .AddArgument($SpaMode.IsPresent).AddArgument($MimeTypes) | Out-Null
        $handle = $ps.BeginInvoke()

        # PID-Datei schreiben
        @{ PID = $PID; Port = $Port; RootPath = $RootPath } |
            ConvertTo-Json | Set-Content "$env:TEMP\localwebserver.json"

        Write-Host "[LocalWebServer] Läuft im Hintergrund (PID: $PID, Port: $Port)"
        return @{ Runspace = $rs; PowerShell = $ps; Handle = $handle }
    } else {
        & $serverBlock $RootPath $Port $SpaMode.IsPresent $MimeTypes
    }
}
```

### Realistischer Implementierungsaufwand

Der folgende Zeitplan gilt für einen erfahrenen PowerShell-Entwickler:

| Phase | Umfang | Geschätzter Aufwand |
|---|---|---|
| **Phase 1:** Basis-Listener | Dateien servieren, MIME-Types, 404 | 2–4 Stunden |
| **Phase 2:** SPA-Support | Fallback-Logik, Routing | 1–2 Stunden |
| **Phase 3:** Hintergrundbetrieb | Runspace, PID-File, Lifecycle | 3–5 Stunden |
| **Phase 4:** Control-Bridge | Admin-API, Named Pipes | 3–6 Stunden |
| **Phase 5:** Modul-Struktur | Manifest, Public/Private, Tests | 4–8 Stunden |
| **Phase 6:** Sicherheit | Path-Traversal, Header, Rate-Limiting | 3–5 Stunden |
| **Phase 7:** Stabilisierung | Edge-Cases, Error-Handling, Logging | 4–8 Stunden |
| **Gesamt** | Stabiles v1.0-Modul | **~20–38 Stunden** |

---

## 8. Sicherheit

### Risikobewertung eines lokalen HTTP-Servers

Auch wenn der Server nur lokal läuft, gibt es reale Angriffsvektoren. Folgende Bedrohungsszenarien sind relevant:

| Bedrohung | Beschreibung | Risiko |
|---|---|---|
| **Path Traversal** | `GET /../../Windows/system32/...` liest Systemdateien | 🔴 Hoch |
| **SSRF durch andere Apps** | Andere lokale Programme könnten den Server missbrauchen | 🟡 Mittel |
| **DNS Rebinding** | Externe Website ändert DNS auf 127.0.0.1 und greift auf Server zu | 🟡 Mittel |
| **Port-Scanning** | Andere Prozesse auf dem Rechner erkennen den Server | 🟢 Niedrig |
| **Malicious File Execution** | Dateien werden ausgeliefert, nicht ausgeführt – kein direktes Risiko | 🟢 Niedrig |
| **Header-Injection** | Unsanitisierte User-Inputs in Antwort-Headern | 🟡 Mittel |

### Maßnahme 1: Path-Traversal-Schutz (Kritisch!)

Das ist die **wichtigste Sicherheitsmaßnahme**. Ohne sie könnte ein Angreifer (oder eine böswillige Webanwendung) beliebige Dateien vom System lesen:

```powershell
function Resolve-SafePath {
    param([string]$RootPath, [string]$UrlPath)

    # URL dekodieren und normalisieren
    $decoded  = [Uri]::UnescapeDataString($UrlPath)
    $relative = $decoded.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)

    # Gefährliche Sequenzen entfernen
    $relative = $relative -replace '\.\.[\\/]', ''

    # Vollständigen Pfad bilden
    $fullPath = [IO.Path]::GetFullPath((Join-Path $RootPath $relative))

    # KRITISCH: Sicherstellen, dass der Pfad innerhalb des Root-Verzeichnisses bleibt
    $rootNormalized = [IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($rootNormalized, [StringComparison]::OrdinalIgnoreCase)) {
        return $null  # Zugriff verweigert!
    }

    return $fullPath
}
```

### Maßnahme 2: Security-Header

HTTP-Security-Header schützen den Browser des Nutzers und verhindern bestimmte Angriffsvektoren:

```powershell
function Add-SecurityHeaders {
    param($Response)

    # Verhindert MIME-Type-Sniffing
    $Response.Headers.Add("X-Content-Type-Options", "nosniff")

    # Verhindert Einbettung in iFrames externer Seiten
    $Response.Headers.Add("X-Frame-Options", "SAMEORIGIN")

    # Aktiviert XSS-Filter des Browsers
    $Response.Headers.Add("X-XSS-Protection", "1; mode=block")

    # Verhindert Referrer-Leaks
    $Response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin")

    # Content Security Policy (anpassen je nach App!)
    $Response.Headers.Add("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'")

    # Nur localhost – kein HSTS nötig (kein HTTPS lokal)
    # Bei HTTPS: $Response.Headers.Add("Strict-Transport-Security", "max-age=31536000")
}
```

### Maßnahme 3: Localhost-Only-Binding

Der Listener sollte **niemals** auf `http://+:8080/` (alle Interfaces) gebunden werden, wenn er nur lokal verfügbar sein soll:

```powershell
# UNSICHER: Alle Netzwerk-Interfaces
$listener.Prefixes.Add("http://+:8080/")       # ❌ Erreichbar im gesamten Netzwerk!

# SICHER: Nur Loopback
$listener.Prefixes.Add("http://localhost:8080/")  # ✅ Nur lokal erreichbar
$listener.Prefixes.Add("http://127.0.0.1:8080/")  # ✅ Explizit Loopback
```

### Maßnahme 4: Rate-Limiting (Basis-Implementierung)

Schützt vor einfachen DoS-Angriffen (z. B. von einer schlecht programmierten lokalen App):

```powershell
$requestCounts = @{}
$rateLimitWindow = 60   # Sekunden
$rateLimitMax    = 200  # Anfragen pro Minute pro IP

function Test-RateLimit {
    param([string]$ClientIp)

    $now = [DateTime]::UtcNow
    if (-not $requestCounts[$ClientIp]) {
        $requestCounts[$ClientIp] = @{ Count = 0; WindowStart = $now }
    }

    $entry = $requestCounts[$ClientIp]

    # Fenster zurücksetzen wenn abgelaufen
    if (($now - $entry.WindowStart).TotalSeconds -ge $rateLimitWindow) {
        $entry.Count = 0
        $entry.WindowStart = $now
    }

    $entry.Count++
    return $entry.Count -le $rateLimitMax
}
```

### Maßnahme 5: DNS-Rebinding-Schutz

DNS-Rebinding ist ein Angriff, bei dem eine externe Website über DNS-Manipulation Anfragen an deinen lokalen Server stellen kann. Schutz: **Host-Header validieren**:

```powershell
function Test-ValidHost {
    param([string]$HostHeader, [int]$Port)
    $allowedHosts = @("localhost", "127.0.0.1", "::1", "localhost:$Port", "127.0.0.1:$Port")
    return $allowedHosts -contains $HostHeader.ToLower()
}

# Im Request-Handler:
if (-not (Test-ValidHost $request.Headers["Host"] $Port)) {
    $response.StatusCode = 400
    $response.OutputStream.Close()
    continue
}
```

### Maßnahme 6: Ausführung als eingeschränkter Benutzer

Wenn der Server als Hintergrundprozess laufen soll, empfiehlt es sich, ihn **nicht** mit Administratorrechten zu starten:

- Port > 1024 (z. B. 8080) wählen – dann sind keine Adminrechte nötig.
- Keine globalen Variablen oder System-Pfade im Server-Code verwenden.
- Das Root-Verzeichnis in einem Benutzer-Ordner wählen (`$env:USERPROFILE\WebRoot`).

### Sicherheits-Checkliste

```
[ ] Path-Traversal-Schutz implementiert und getestet
[ ] Nur auf localhost gebunden (kein + oder 0.0.0.0)
[ ] Security-Header in allen Antworten gesetzt
[ ] Host-Header-Validierung (DNS-Rebinding-Schutz)
[ ] Control-API nur von 127.0.0.1 erreichbar
[ ] Kein Verzeichnis-Listing (kein automatisches Auflisten von Ordnerinhalten)
[ ] Fehler-Responses geben keine Systempfade preis
[ ] Rate-Limiting aktiv
[ ] Logging für verdächtige Anfragen aktiviert
[ ] Server läuft ohne Administratorrechte (Port > 1024)
```

---

## Anhang: Schnellstart-Referenz

### Minimaler Server in 20 Zeilen

```powershell
$root = "C:\MeineWebApp\dist"
$port = 8080
$mime = @{ '.html'='text/html'; '.js'='application/javascript'; '.css'='text/css'; '.json'='application/json' }

$l = [System.Net.HttpListener]::new()
$l.Prefixes.Add("http://localhost:$port/")
$l.Start()
Write-Host "Server läuft: http://localhost:$port/"

while ($l.IsListening) {
    $ctx  = $l.GetContext()
    $path = Join-Path $root $ctx.Request.Url.AbsolutePath.TrimStart('/')
    if (Test-Path $path -PathType Container) { $path = Join-Path $path "index.html" }
    if (-not (Test-Path $path)) { $path = Join-Path $root "index.html" }
    $ext  = [IO.Path]::GetExtension($path).ToLower()
    $data = [IO.File]::ReadAllBytes($path)
    $ctx.Response.ContentType = if ($mime[$ext]) { $mime[$ext] } else { 'application/octet-stream' }
    $ctx.Response.OutputStream.Write($data, 0, $data.Length)
    $ctx.Response.OutputStream.Close()
}
```

### Nützliche Ressourcen

- [System.Net.HttpListener – Microsoft Docs](https://learn.microsoft.com/de-de/dotnet/api/system.net.httplistener)
- [SimplePowerShellHTTPServer – GitHub](https://github.com/lpowell/SimplePowerShellHTTPServer)
- [PowerShell HTTP Server Beispiele – 4sysops](https://4sysops.com/archives/building-a-web-server-with-powershell/)
- [HttpListener in PowerShell – MSXFAQ](https://www.msxfaq.de/powershell/pshttpserver.htm)
- [Runspaces in PowerShell – Roy Ashbrook](https://royashbrook.com/2021/04/19/getting-data-out-of-powershell-jobs-runspaces-in-realtime/)

---

*Dokumentation erstellt: April 2026*