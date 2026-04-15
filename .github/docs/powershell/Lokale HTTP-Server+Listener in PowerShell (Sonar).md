# Lokale HTTP-Server / HTTP-Listener in PowerShell

> **Dokumentation** | Erstellt: April 2026  
> **Zielgruppe:** PowerShell-Entwickler mit Grundkenntnissen in .NET und Webentwicklung  
> **Thema:** Aufbau, Betrieb und Absicherung eines lokalen HTTP-Servers auf Basis von `System.Net.HttpListener`

---

## Inhaltsverzeichnis

1. [Szenario & Use Cases](#1-szenario--use-cases)
2. [HTTP-Server vs. HTTP-Listener – Was ist der Unterschied?](#2-http-server-vs-http-listener)
3. [Möglichkeiten zur lokalen SPA-Bereitstellung mit PowerShell](#3-möglichkeiten-zur-lokalen-spa-bereitstellung)
4. [Inter-Prozess-Kommunikation & Steuerung via API-Endpunkt](#4-inter-prozess-kommunikation--steuerung-via-api-endpunkt)
5. [Eigene lokale Domain statt `localhost`](#5-eigene-lokale-domain-statt-localhost)
6. [Einzelskript vs. PowerShell-Modul – Architekturentscheidung](#6-einzelskript-vs-powershell-modul)
7. [Grundfunktionen & Entwicklungsaufwand](#7-grundfunktionen--entwicklungsaufwand)
8. [Sicherheit](#8-sicherheit)
9. [Anhang: Vollständiges Grundgerüst (Modul-Skelett)](#9-anhang-vollständiges-grundgerüst)

---

## 1. Szenario & Use Cases

### Warum ein lokaler HTTP-Server?

Moderne Webanwendungen – insbesondere **Single Page Applications (SPAs)** wie Angular-, React- oder Vue-basierte Apps – können **nicht einfach per `file://`-Protokoll** im Browser geöffnet werden. Sie benötigen zwingend einen HTTP(S)-Server, da Browser bei `file://` zahlreiche Sicherheitsbeschränkungen erzwingen:

- **CORS-Fehler** (Cross-Origin Resource Sharing) blockieren API-Aufrufe
- **ES-Module** (`import`/`export`) und `fetch()`-Aufrufe funktionieren nicht
- **Service Worker** und PWA-Funktionalitäten sind deaktiviert
- **Web Crypto API**, **IndexedDB**, **Notifications** etc. sind eingeschränkt

Ein **lokaler HTTP-Server** umgeht all diese Einschränkungen, indem er Dateien über das `http://`-Protokoll ausliefert – genau so, wie es ein echter Webserver wie Apache oder nginx tun würde.

### Konkrete Anwendungsfälle

| Szenario | Beschreibung |
|---|---|
| **Offline-SPA-Hosting** | Eine Angular/React-App lokal ohne Internet und ohne IIS/Apache betreiben |
| **Interne Tooling-Dashboards** | Admin-UIs, Monitoring-Panels oder Konfigurations-Interfaces lokal ausliefern |
| **Lokale Dokumentation** | Statische HTML-Dokumentation (z. B. aus `mkdocs`, `docusaurus`) lokal hosten |
| **Entwicklung & Testing** | Lokale API-Mocks und statische Endpunkte für Entwicklungszwecke |
| **Kiosk-Anwendungen** | Vollbildbrowser-Kiosksysteme, die eine lokal gespeicherte Web-UI rendern |
| **Enterprise-Desktopanwendungen** | Native .NET/PowerShell-Programme mit einer Browser-basierten UI (Electron-Ersatz) |
| **Portable Anwendungspakete** | Eine Web-App als ZIP/MSI ausliefern, die sich selbst per PowerShell-Server startet |

### Vorteile gegenüber Alternativen

- **Keine Installation nötig:** `System.Net.HttpListener` ist Teil von .NET und in jeder modernen PowerShell-Instanz verfügbar – weder Apache, IIS noch Node.js sind erforderlich.
- **Keine Administratorrechte** für `localhost`-Bindungen (ab Windows Vista/7, wenn korrekt konfiguriert)
- **Vollständige Kontrolle:** MIME-Types, Routing, Header, Logging – alles anpassbar
- **Portabel:** Das Modul/Skript kann direkt mit der Web-App mitgeliefert werden
- **Ressourcenschonend:** Minimalster Ressourcenverbrauch gegenüber vollständigen Webservern
- **Hintergrundbetrieb:** Läuft unsichtbar als PowerShell-Background-Job oder Runspace

---

## 2. HTTP-Server vs. HTTP-Listener

Diese Unterscheidung ist fundamental, um die eigene Lösung richtig einzuordnen.

### HTTP-Listener (`System.Net.HttpListener`)

Ein **HTTP-Listener** ist eine **Low-Level-.NET-Klasse**, die direkt auf dem Windows HTTP Server API (HTTP.SYS) aufsetzt. Er:

- Lauscht auf einem oder mehreren definierten URL-Präfixen (z. B. `http://localhost:8080/`)
- **Nimmt eingehende HTTP-Anfragen entgegen** und stellt sie als `HttpListenerContext`-Objekte bereit
- **Enthält keinerlei Logik** – er verarbeitet nichts, er sendet nichts zurück, er kennt keine Dateien
- Ist ein **Baustein**, kein fertiges Produkt

```powershell
# Minimales Beispiel: Nur der Listener – noch kein Server
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
$context = $listener.GetContext()   # Blockiert, bis eine Anfrage kommt
$listener.Stop()
```

**Analogie:** Ein HTTP-Listener ist wie ein Telefonapparat. Er klingelt, wenn jemand anruft. Was du mit dem Anruf machst – das entscheidest du selbst.

### HTTP-Server

Ein **HTTP-Server** ist die **vollständige Implementierung**, die auf einem HTTP-Listener aufbaut und folgende Logik hinzufügt:

- **Routing:** Welche URL entspricht welcher Datei/Logik?
- **MIME-Type-Erkennung:** Welcher Content-Type-Header wird gesendet?
- **Datei-Serving:** Dateien aus einem Verzeichnis lesen und als Byte-Stream senden
- **Fehlerbehandlung:** 404, 403, 500-Responses
- **Loop:** Dauerhaftes Warten auf neue Anfragen (nicht nur eine einzelne)
- **Hintergrundbetrieb:** Ausführung in einem separaten Thread/Job/Runspace

**Analogie:** Der Server ist das komplette Callcenter – mit Personal, Warteschleife, Skripten und Eskalationsprozessen. Der Listener ist nur das Telefon darin.

### Gegenüberstellung

| Merkmal | HTTP-Listener | HTTP-Server |
|---|---|---|
| **Was es ist** | .NET-Klasse (`HttpListener`) | Deine PowerShell-Implementierung |
| **Logik** | Keine – nur Empfang | Routing, MIME, Serving, Fehler |
| **Zustand** | Zustandslos | Verwaltet Verbindungen, Konfiguration |
| **Komplexität** | ~5 Zeilen PowerShell | 100–500+ Zeilen (je nach Features) |
| **Verwendung** | Als Baustein im Server | Nutzt Listener intern |
| **Analogie** | TCP-Socket/Telefon | Apache/nginx/IIS |

> **Fazit:** Du wirst einen HTTP-Listener als Fundament verwenden, um darüber einen vollständigen HTTP-Server zu implementieren.

---

## 3. Möglichkeiten zur lokalen SPA-Bereitstellung

Es gibt verschiedene technische Ansätze, um SPAs über PowerShell lokal bereitzustellen. Jede Option hat spezifische Vor- und Nachteile:

### Option A: `System.Net.HttpListener` (Empfohlen)

Der **native .NET-Weg** – kein externes Tool, kein Modul von Drittanbietern.

**Vorteile:**
- In jeder PowerShell-Instanz verfügbar (PowerShell 5.1+ und PowerShell 7+)
- Vollständige Kontrolle über alle HTTP-Aspekte
- Läuft nativ als Background-Job oder Runspace
- Unterstützt beliebige MIME-Types, Custom Headers, API-Endpunkte
- Kein Administratorzugang notwendig (nur für `localhost`)

**Nachteile:**
- Manuelle Implementierung aller Serverlogik nötig
- Kein HTTP/2-Support (HTTP.SYS-limitiert ohne zusätzliche Konfiguration)
- Einzelthreadig per `GetContext()` – erfordert Runspace-Pools für parallele Requests

**Grundstruktur für SPA-Hosting:**

```powershell
function Start-LocalWebServer {
    param(
        [string]$RootDirectory = "C:\MyApp\dist",
        [int]$Port = 8080,
        [string]$Hostname = "localhost"
    )

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://${Hostname}:${Port}/")
    $listener.Start()

    while ($listener.IsListening) {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        # URL-Pfad bereinigen
        $urlPath = $request.Url.LocalPath.TrimStart('/')

        # SPA-Fallback: Unbekannte Routen -> index.html
        $filePath = Join-Path $RootDirectory $urlPath
        if (-not (Test-Path $filePath) -or (Get-Item $filePath).PSIsContainer) {
            $filePath = Join-Path $RootDirectory "index.html"
        }

        if (Test-Path $filePath) {
            $mimeType           = Get-MimeType -FilePath $filePath
            $fileBytes          = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType   = $mimeType
            $response.ContentLength64 = $fileBytes.Length
            $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
        } else {
            $response.StatusCode = 404
            $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
            $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
        }
        $response.OutputStream.Close()
    }
}
```

### Option B: `npx serve` oder `python -m http.server` via PowerShell

PowerShell kann externe Tools starten:

```powershell
# Python (falls installiert)
Start-Process python -ArgumentList "-m http.server 8080" -WorkingDirectory "C:\MyApp\dist"

# Node.js serve (falls npm installiert)
Start-Process npx -ArgumentList "serve -s C:\MyApp\dist -l 8080"
```

**Problem:** Diese Ansätze erzeugen externe Abhängigkeiten (Python, Node.js) und sind für eine portable, eigenständige Lösung ungeeignet.

### Option C: IIS Express via PowerShell

Microsoft stellt IIS Express als leichtgewichtige IIS-Variante bereit:

```powershell
$iisExpress = "C:\Program Files\IIS Express\iisexpress.exe"
Start-Process $iisExpress -ArgumentList "/path:C:\MyApp\dist /port:8080"
```

**Problem:** IIS Express muss separat installiert sein und ist nicht auf jedem System vorhanden.

### MIME-Type-Tabelle für SPAs

Eine vollständige MIME-Type-Funktion ist essenziell für korrekt funktionierende SPAs:

```powershell
function Get-MimeType {
    param([string]$FilePath)

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    $mimeTypes = @{
        # Web-Grundlagen
        ".html"  = "text/html; charset=utf-8"
        ".htm"   = "text/html; charset=utf-8"
        ".css"   = "text/css; charset=utf-8"
        ".js"    = "application/javascript; charset=utf-8"
        ".mjs"   = "application/javascript; charset=utf-8"
        ".json"  = "application/json; charset=utf-8"
        ".xml"   = "application/xml; charset=utf-8"
        ".txt"   = "text/plain; charset=utf-8"
        # Bilder
        ".png"   = "image/png"
        ".jpg"   = "image/jpeg"
        ".jpeg"  = "image/jpeg"
        ".gif"   = "image/gif"
        ".svg"   = "image/svg+xml"
        ".ico"   = "image/x-icon"
        ".webp"  = "image/webp"
        ".avif"  = "image/avif"
        # Fonts
        ".woff"  = "font/woff"
        ".woff2" = "font/woff2"
        ".ttf"   = "font/ttf"
        ".otf"   = "font/otf"
        ".eot"   = "application/vnd.ms-fontobject"
        # Medien
        ".mp4"   = "video/mp4"
        ".webm"  = "video/webm"
        ".mp3"   = "audio/mpeg"
        ".ogg"   = "audio/ogg"
        # Dokumente
        ".pdf"   = "application/pdf"
        ".zip"   = "application/zip"
        # PWA / Manifest
        ".webmanifest" = "application/manifest+json"
        ".map"   = "application/json"
        # WebAssembly
        ".wasm"  = "application/wasm"
    }

    if ($mimeTypes.ContainsKey($extension)) {
        return $mimeTypes[$extension]
    }
    return "application/octet-stream"
}
```

### SPA-Routing (Critical für Angular/React/Vue)

**Das wichtigste Konzept beim SPA-Hosting:** SPAs verwenden clientseitiges Routing. URLs wie `http://localhost:8080/dashboard` oder `/settings/profile` existieren **nicht als Dateipfade** auf dem Dateisystem. Der Server muss diese Anfragen erkennen und statt einer 404 die `index.html` zurückgeben – das SPA-Framework übernimmt dann das Routing im Browser.

```powershell
# SPA-Fallback-Logik
$absolutePath = Join-Path $RootDirectory $urlPath.Replace('/', [IO.Path]::DirectorySeparatorChar)

$isSpaRoute = (
    -not (Test-Path $absolutePath) -or       # Datei existiert nicht
    (Get-Item $absolutePath -ErrorAction SilentlyContinue)?.PSIsContainer  # Ist ein Verzeichnis
) -and ($urlPath -notlike "*/api/*")         # Kein API-Aufruf

if ($isSpaRoute) {
    $filePath = Join-Path $RootDirectory "index.html"
} else {
    $filePath = $absolutePath
}
```

---

## 4. Inter-Prozess-Kommunikation & Steuerung via API-Endpunkt

Dies ist einer der kreativsten Aspekte dieses Projekts: **Ja, es ist absolut technisch möglich**, einen laufenden Server über einen API-Endpunkt von außen zu steuern.

### Das Grundprinzip

Der Server selbst definiert einen oder mehrere **administrative API-Endpunkte** (z. B. `/admin/`), die von einem externen Skript aufgerufen werden können. Dabei spielt die Prozess-ID keine besondere Rolle – die Kommunikation läuft über **HTTP selbst**.

```
[Externes Skript]  --HTTP POST--> http://localhost:8080/admin/stop
                                  [Laufender Server-Prozess]
```

### Implementierung: Admin-Endpunkt im Server

```powershell
# Im Server-Hauptloop: Admin-Routen abfangen
if ($request.Url.LocalPath -like "/admin/*") {
    $adminToken = $request.Headers["X-Admin-Token"]

    # Einfache Token-Authentifizierung
    if ($adminToken -ne $script:AdminToken) {
        $response.StatusCode = 401
        Send-Response $response "Unauthorized"
        continue
    }

    switch ($request.Url.LocalPath) {
        "/admin/stop" {
            Send-Response $response '{"status":"stopping"}'
            $listener.Stop()
            break
        }
        "/admin/status" {
            $status = @{
                uptime    = (Get-Date) - $script:StartTime
                requests  = $script:RequestCount
                port      = $Port
                rootDir   = $RootDirectory
            } | ConvertTo-Json
            Send-Response $response $status "application/json"
        }
        "/admin/reload" {
            # Root-Verzeichnis neu einlesen, Cache leeren etc.
            $script:FileCache.Clear()
            Send-Response $response '{"status":"reloaded"}'
        }
    }
}
```

### Steuerung vom externen Skript aus

```powershell
# control-server.ps1 – Externes Steuerskript

$adminToken = "mein-geheimer-token-123"
$baseUrl    = "http://localhost:8080"

function Invoke-ServerCommand {
    param([string]$Command)

    $headers = @{ "X-Admin-Token" = $adminToken }

    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/admin/$Command" -Headers $headers -Method POST
        Write-Host "Server response: $($result | ConvertTo-Json)"
    } catch {
        Write-Error "Server nicht erreichbar oder Fehler: $_"
    }
}

# Verwendung:
Invoke-ServerCommand -Command "status"
Invoke-ServerCommand -Command "reload"
Invoke-ServerCommand -Command "stop"
```

### Alternative: Named Pipes für IPC

Für eine noch direktere Kommunikation (ohne HTTP-Overhead) können **Named Pipes** verwendet werden:

```powershell
# Server erstellt eine Named Pipe
$pipeName   = "LocalWebServer_Control"
$pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName)

# In einem separaten Runspace lauschen
# Externes Skript sendet Befehle über:
$pipeClient = [System.IO.Pipes.NamedPipeClientStream]::new(".", $pipeName)
$pipeClient.Connect(1000)   # 1 Sekunde Timeout
$writer = [System.IO.StreamWriter]::new($pipeClient)
$writer.WriteLine("stop")
$writer.Flush()
```

### Alternative: Mutex / Event-basiert

```powershell
# Server registriert einen globalen Event
$eventName = "LocalWebServer_StopEvent"
$stopEvent = [System.Threading.EventWaitHandle]::new($false,
    [System.Threading.EventResetMode]::ManualReset, $eventName)

# Externes Skript sendet Stop-Signal:
$existingEvent = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
$existingEvent.Set()   # Server erkennt dieses Signal und stoppt
```

### Empfehlung: HTTP Admin-API

Für dein Szenario ist der **HTTP Admin-Endpunkt mit Token-Auth** die beste Wahl:

- Einfach zu implementieren und zu testen (`Invoke-RestMethod` reicht aus)
- Funktioniert ohne zusätzliche IPC-Infrastruktur
- Gut dokumentierbar und erweiterbar
- Prozess-ID ist **nicht notwendig** – die URL reicht als Adresse

---

## 5. Eigene lokale Domain statt `localhost`

**Ja, es ist möglich**, den Server auf einem benutzerdefinierten Hostnamen wie `http://localweb/` oder `http://webengine/` lauschen zu lassen. Dazu sind zwei Schritte notwendig:

### Schritt 1: Windows Hosts-Datei anpassen

Die Datei `C:\Windows\System32\drivers\etc\hosts` mappt Hostnamen auf IP-Adressen – komplett ohne DNS-Server.

```powershell
function Add-LocalHostEntry {
    param(
        [string]$Hostname,   # z.B. "localweb"
        [string]$IP = "127.0.0.1"
    )

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $entry     = "$IP`t$Hostname"

    # Prüfen ob Eintrag bereits existiert
    $existing = Get-Content $hostsPath | Where-Object { $_ -match $Hostname }
    if (-not $existing) {
        # Administratorrechte erforderlich!
        Add-Content -Path $hostsPath -Value $entry
        Write-Host "Hosts-Eintrag hinzugefügt: $entry"
    } else {
        Write-Host "Eintrag bereits vorhanden."
    }
}

# Beispiel:
Add-LocalHostEntry -Hostname "localweb"
Add-LocalHostEntry -Hostname "webengine"
```

> **Wichtig:** Das Schreiben in die Hosts-Datei erfordert **Administratorrechte**.  
> Das Modul kann dies automatisch via `Start-Process powershell -Verb RunAs` eskalieren.

### Schritt 2: HttpListener auf den Hostnamen binden

```powershell
# Normaler localhost
$listener.Prefixes.Add("http://localhost:8080/")

# Eigener Hostname (nach Hosts-Eintrag)
$listener.Prefixes.Add("http://localweb/")       # Port 80 – Admin-Rechte nötig!
$listener.Prefixes.Add("http://webengine:8080/") # Port > 1024 – keine Admin-Rechte

# Alle Interfaces (alle lokalen IPs)
$listener.Prefixes.Add("http://+:8080/")
```

### Schritt 3: netsh URL-Reservierung (ohne Admin im Dauerbetrieb)

Damit der Server **ohne Administratorrechte** auf einem Hostnamen lauschen kann, muss einmalig (mit Admin-Rechten) eine URL-Reservierung angelegt werden:

```powershell
# Einmalig mit Admin-Rechten ausführen:
netsh http add urlacl url="http://localweb:8080/" user="$env:USERDOMAIN\$env:USERNAME"

# Zum Entfernen:
netsh http delete urlacl url="http://localweb:8080/"
```

### DNS-Flush nach Hosts-Änderung

```powershell
# Windows DNS-Cache leeren (damit die Änderung sofort wirkt)
Clear-DnsClientCache
ipconfig /flushdns
```

### Zusammenfassung: Hostnamen-Optionen

| Option | Port | Admin-Rechte | Hostnamen |
|---|---|---|---|
| `http://localhost:8080/` | >1024 | Nein | localhost only |
| `http://+:8080/` | >1024 | Nein | Alle lokalen IPs |
| `http://localweb/` | 80 | Ja (Port 80) | Custom (nach hosts) |
| `http://localweb:8080/` | >1024 | Nach netsh-Setup: Nein | Custom |

---

## 6. Einzelskript vs. PowerShell-Modul

### Direkter Vergleich

| Kriterium | Einzelskript (`.ps1`) | PowerShell-Modul (`.psm1`) |
|---|---|---|
| **Struktur** | Alles in einer Datei | Klare Dateistruktur mit Manifest |
| **Wiederverwendbarkeit** | Gering | Hoch – Funktionen importierbar |
| **Versionierung** | Manuell im Code | Im Manifest (`.psd1`) definiert |
| **Abhängigkeiten** | Manuell prüfen | `RequiredModules` im Manifest |
| **Systemprüfungen** | Manuell im Skript | `RootModule`-Loader automatisiert |
| **Distribution** | Einzeldatei | PowerShell Gallery / NuGet |
| **Autarker Betrieb** | Möglich aber unübersichtlich | Ideal durch Manifest |
| **Komplexität** | Gering | Mittel |

### Empfehlung: PowerShell-Modul

Für dein Szenario ist ein **eigenständiges PowerShell-Modul** der klar bessere Ansatz – besonders, weil:

1. **Systemprüfungen** (PowerShell-Version, .NET-Framework, Admin-Rechte, Port-Verfügbarkeit) elegant im Modul-Loader integriert werden können
2. **Exported Functions** eine saubere öffentliche API bieten (`Start-WebServer`, `Stop-WebServer`, `Get-WebServerStatus`)
3. Das Modul als **portable Einheit** mit der Web-App ausgeliefert werden kann
4. **Private Hilfsfunktionen** (MIME-Erkennung, Datei-Serving, Logging) sauber intern bleiben

### Vorgeschlagene Modulstruktur

```
LocalWebServer/
├── LocalWebServer.psd1          # Modul-Manifest
├── LocalWebServer.psm1          # Haupt-Modul (lädt alle privaten Dateien)
├── Private/
│   ├── Start-HttpListener.ps1   # Interner Listener-Start
│   ├── Invoke-RequestHandler.ps1 # Request-Verarbeitung
│   ├── Get-MimeType.ps1         # MIME-Type-Auflösung
│   ├── Send-HttpResponse.ps1    # Response-Helfer
│   ├── Write-ServerLog.ps1      # Logging
│   └── Test-Prerequisites.ps1  # Systemvoraussetzungen prüfen
└── Public/
    ├── Start-WebServer.ps1      # Öffentlich: Server starten
    ├── Stop-WebServer.ps1       # Öffentlich: Server stoppen
    ├── Restart-WebServer.ps1    # Öffentlich: Server neu starten
    ├── Get-WebServerStatus.ps1  # Öffentlich: Status abfragen
    └── Set-WebServerConfig.ps1  # Öffentlich: Konfiguration ändern
```

### Modul-Manifest (`LocalWebServer.psd1`)

```powershell
@{
    ModuleVersion       = '1.0.0'
    GUID                = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'   # New-Guid
    Author              = 'Dein Name'
    Description         = 'Lokaler PowerShell HTTP-Server für SPAs und Websites'
    PowerShellVersion   = '5.1'
    RequiredAssemblies  = @()
    FunctionsToExport   = @(
        'Start-WebServer',
        'Stop-WebServer',
        'Restart-WebServer',
        'Get-WebServerStatus',
        'Set-WebServerConfig'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('HTTP', 'WebServer', 'SPA', 'Localhost')
        }
    }
}
```

### Systemvoraussetzungen automatisch prüfen

```powershell
# Private/Test-Prerequisites.ps1
function Test-Prerequisites {
    $errors = @()

    # PowerShell-Version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $errors += "PowerShell 5.1 oder neuer erforderlich."
    }

    # .NET-Verfügbarkeit
    try {
        $null = [System.Net.HttpListener]
    } catch {
        $errors += ".NET HttpListener nicht verfügbar."
    }

    # Port-Verfügbarkeit prüfen
    $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($portInUse) {
        $errors += "Port $Port wird bereits verwendet."
    }

    # Root-Verzeichnis existiert?
    if (-not (Test-Path $RootDirectory)) {
        $errors += "Root-Verzeichnis '$RootDirectory' nicht gefunden."
    }

    if ($errors.Count -gt 0) {
        throw "Voraussetzungen nicht erfüllt:`n" + ($errors -join "`n")
    }
    return $true
}
```

---

## 7. Grundfunktionen & Entwicklungsaufwand

### Kern-Features (MVP – Minimum Viable Product)

Das folgende beschreibt den **minimalen Funktionsumfang**, damit der Server die gestellten Anforderungen erfüllt:

#### Feature-Liste

| Priorität | Feature | Beschreibung |
|---|---|---|
| **P0** | HTTP-Listener-Setup | Port binden, starten, stoppen |
| **P0** | Statisches File-Serving | Dateien aus Root-Verzeichnis lesen & senden |
| **P0** | MIME-Type-Erkennung | Korrekte Content-Type-Header |
| **P0** | SPA-Fallback-Routing | Unbekannte URLs → `index.html` |
| **P0** | Hintergrundbetrieb | Background-Runspace oder -Job |
| **P1** | Admin-API | `/admin/*`-Endpunkte (stop, status, reload) |
| **P1** | Logging | Requests mit Timestamp loggen |
| **P1** | Index-File-Serving | `index.html` bei Verzeichnisaufruf |
| **P1** | Error-Pages | Eigene 404/500-Seiten |
| **P2** | Datei-Caching | Häufig angefragte Dateien im RAM cachen |
| **P2** | Custom Hostnamen | Hosts-Datei-Verwaltung + netsh |
| **P2** | Konfigurations-Datei | JSON/XML-Konfiguration laden |
| **P3** | HTTPS-Support | Selbstsigniertes Zertifikat, netsh ssl |
| **P3** | Gzip-Komprimierung | Response-Komprimierung |
| **P3** | Multi-Site | Mehrere Root-Verzeichnisse auf verschiedenen Ports |

### Hintergrundbetrieb: Runspace vs. Background-Job

Für einen stabilen Hintergrundbetrieb sind **Runspaces** dem `Start-Job`-Ansatz überlegen:

| Kriterium | `Start-Job` | Runspace |
|---|---|---|
| Performance | Niedriger (eigener Prozess) | Höher (gleicher Prozess) |
| Typ-Fidelität | Verlust durch Serialisierung | Vollständige .NET-Typen |
| Kommunikation | Eingeschränkt | Direkt via Shared-Variablen |
| Kontrolle | `Stop-Job` etc. | Direkter Runspace-Stop |
| Empfehlung | Einfache Tasks | HTTP-Server |

```powershell
function Start-WebServerBackground {
    param([hashtable]$Config)

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "MTA"
    $runspace.ThreadOptions  = "ReuseThread"
    $runspace.Open()

    # Konfiguration in den Runspace übergeben
    $runspace.SessionStateProxy.SetVariable("Config", $Config)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        # Server-Hauptloop hier
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://$($Config.Hostname):$($Config.Port)/")
        $listener.Start()

        while ($listener.IsListening) {
            $context = $listener.GetContext()
            # ... Request-Handling ...
        }
    }) | Out-Null

    $handle = $ps.BeginInvoke()

    # Handle und Runspace für späteren Stop speichern
    $script:ServerRunspace  = $runspace
    $script:ServerPowerShell = $ps
    $script:ServerHandle    = $handle

    Write-Host "Server läuft im Hintergrund auf http://$($Config.Hostname):$($Config.Port)/"
}
```

### Schätzung: Entwicklungsaufwand

| Phase | Inhalt | Aufwand |
|---|---|---|
| **Phase 1: MVP** | Listener, File-Serving, MIME, SPA-Fallback | 4–8 Std. |
| **Phase 2: Hintergrund** | Runspace-Integration, Start/Stop-Funktionen | 3–6 Std. |
| **Phase 3: Admin-API** | HTTP-Admin-Endpunkte, Token-Auth | 2–4 Std. |
| **Phase 4: Modul** | Modulstruktur, Manifest, Systemprüfungen | 3–5 Std. |
| **Phase 5: Robustheit** | Fehlerbehandlung, Logging, Edge Cases | 4–8 Std. |
| **Phase 6: Custom DNS** | Hosts-Datei, netsh, HTTPS | 3–6 Std. |
| **Gesamt (MVP-Modul)** | Stabil, funktional, dokumentiert | **~20–37 Std.** |

> **Hinweis:** Diese Schätzung gilt für eine stabile, produktionsreife Implementierung. Ein funktionsfähiges Proof-of-Concept ist in 2–4 Stunden erreichbar.

---

## 8. Sicherheit

Da der Server lokal läuft, ist das Risiko geringer als bei einem öffentlich exponierten Server – aber **nicht null**. Andere Prozesse auf demselben Rechner (oder im selben Netzwerk) können theoretisch auf den Server zugreifen.

### 8.1 Bindung auf `localhost` beschränken

**Der wichtigste Schritt:** Den Server **ausschließlich** auf `127.0.0.1` (nicht auf `0.0.0.0` oder `+`) binden:

```powershell
# Sicher: Nur lokale Verbindungen
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Prefixes.Add("http://127.0.0.1:8080/")

# Unsicher: Alle Interfaces (auch Netzwerkinterfaces!)
$listener.Prefixes.Add("http://+:8080/")    # NICHT für lokale Server verwenden
$listener.Prefixes.Add("http://*:8080/")    # NICHT für lokale Server verwenden
```

### 8.2 Admin-Endpunkte mit Token absichern

```powershell
# Token bei Server-Start generieren (zufällig, nicht hardcoded!)
$script:AdminToken = [System.Convert]::ToBase64String(
    [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
)

# In jedem Request prüfen:
$token = $request.Headers["X-Admin-Token"]
if ($token -ne $script:AdminToken) {
    $response.StatusCode = 401
    # Response senden und continue
}
```

### 8.3 Path-Traversal-Angriffe verhindern

Ein kritischer Angriff: Ein Client sendet eine URL wie `/../../../Windows/System32/config/SAM`. Der Server muss sicherstellen, dass er niemals Dateien außerhalb des Root-Verzeichnisses ausliefert:

```powershell
function Resolve-SafePath {
    param(
        [string]$RootDirectory,
        [string]$RequestedPath
    )

    # Pfad normalisieren und absolut machen
    $fullPath = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($RootDirectory, $RequestedPath.TrimStart('/'))
    )

    # Sicherheitscheck: Liegt der Pfad wirklich im Root-Verzeichnis?
    if (-not $fullPath.StartsWith($RootDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path traversal attempt detected: $RequestedPath"
    }

    return $fullPath
}
```

### 8.4 Gefährliche Dateiendungen blocken

```powershell
$blockedExtensions = @(".ps1", ".psm1", ".psd1", ".bat", ".cmd", ".exe",
                       ".vbs", ".js_exe", ".config", ".env", ".key", ".pem")

$ext = [System.IO.Path]::GetExtension($filePath).ToLower()
if ($blockedExtensions -contains $ext) {
    $response.StatusCode = 403
    Send-Response $response "403 - Forbidden"
    continue
}
```

### 8.5 Rate Limiting (Basis)

```powershell
# Einfaches In-Memory Rate Limiting
$script:RequestCounts = @{}
$script:WindowStart   = Get-Date

function Test-RateLimit {
    param([string]$ClientIP, [int]$MaxRequests = 100, [int]$WindowSeconds = 60)

    $now = Get-Date
    # Fenster zurücksetzen wenn abgelaufen
    if (($now - $script:WindowStart).TotalSeconds -gt $WindowSeconds) {
        $script:RequestCounts.Clear()
        $script:WindowStart = $now
    }

    $script:RequestCounts[$ClientIP] = ($script:RequestCounts[$ClientIP] ?? 0) + 1

    return $script:RequestCounts[$ClientIP] -le $MaxRequests
}
```

### 8.6 Security-Header setzen

```powershell
function Add-SecurityHeaders {
    param([System.Net.HttpListenerResponse]$Response)

    $Response.Headers.Add("X-Content-Type-Options", "nosniff")
    $Response.Headers.Add("X-Frame-Options", "SAMEORIGIN")
    $Response.Headers.Add("X-XSS-Protection", "1; mode=block")
    $Response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin")
    $Response.Headers.Add("Cache-Control", "no-store")

    # Content Security Policy – anpassen je nach App
    $Response.Headers.Add("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'")
}
```

### 8.7 Sicherheits-Checkliste

| Maßnahme | Priorität | Status |
|---|---|---|
| Nur auf `localhost`/`127.0.0.1` binden | **Kritisch** | ☐ |
| Path-Traversal-Prüfung | **Kritisch** | ☐ |
| Gefährliche Dateiendungen blockieren | **Hoch** | ☐ |
| Admin-API mit zufälligem Token | **Hoch** | ☐ |
| Security-HTTP-Header setzen | **Mittel** | ☐ |
| Request-Logging für Audit | **Mittel** | ☐ |
| Rate Limiting | **Mittel** | ☐ |
| HTTPS (selbstsigniertes Zertifikat) | **Optional** | ☐ |
| Firewall-Regel für Port | **Optional** | ☐ |

---

## 9. Anhang: Vollständiges Grundgerüst (Modul-Skelett)

Das folgende Beispiel zeigt ein **minimales, lauffähiges Grundgerüst** eines PowerShell-Moduls für einen lokalen HTTP-Server. Es dient als Startpunkt – nicht als fertige Produktionslösung.

### `LocalWebServer.psm1`

```powershell
# LocalWebServer.psm1 – Haupt-Modul

# Private Funktionen laden
$privateFiles = Get-ChildItem "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) { . $file.FullName }

# Public Funktionen laden und exportieren
$publicFiles = Get-ChildItem "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    . $file.FullName
    Export-ModuleMember -Function $file.BaseName
}

# Modul-Zustand initialisieren
$script:ServerRunspace   = $null
$script:ServerPowerShell = $null
$script:AdminToken       = $null
$script:Config           = $null
```

### `Public/Start-WebServer.ps1`

```powershell
function Start-WebServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$RootDirectory,

        [int]$Port = 8080,
        [string]$Hostname = "localhost",
        [switch]$PassThru
    )

    # Voraussetzungen prüfen
    Test-Prerequisites -Port $Port -RootDirectory $RootDirectory

    # Admin-Token generieren
    $script:AdminToken = [System.Convert]::ToBase64String(
        [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    )

    $script:Config = @{
        RootDirectory = (Resolve-Path $RootDirectory).Path
        Port          = $Port
        Hostname      = $Hostname
        StartTime     = Get-Date
    }

    # Server im Hintergrund starten
    Start-WebServerBackground -Config $script:Config

    Write-Host "✓ LocalWebServer gestartet: http://${Hostname}:${Port}/" -ForegroundColor Green
    Write-Host "  Root: $RootDirectory"
    Write-Host "  Admin-Token: $script:AdminToken" -ForegroundColor Yellow

    if ($PassThru) {
        return @{
            Url        = "http://${Hostname}:${Port}/"
            AdminToken = $script:AdminToken
            Config     = $script:Config
        }
    }
}
```

### `Public/Stop-WebServer.ps1`

```powershell
function Stop-WebServer {
    [CmdletBinding()]
    param()

    if ($null -eq $script:ServerRunspace) {
        Write-Warning "Kein laufender Server gefunden."
        return
    }

    try {
        # Server über Admin-API stoppen (sendet Signal an Runspace)
        $headers = @{ "X-Admin-Token" = $script:AdminToken }
        Invoke-RestMethod -Uri "http://$($script:Config.Hostname):$($script:Config.Port)/admin/stop" `
            -Headers $headers -Method POST -TimeoutSec 3 -ErrorAction SilentlyContinue
    } catch { <# Ignorieren wenn Server bereits gestoppt #> }

    # Runspace aufräumen
    Start-Sleep -Milliseconds 500
    $script:ServerPowerShell?.Stop()
    $script:ServerPowerShell?.Dispose()
    $script:ServerRunspace?.Close()
    $script:ServerRunspace?.Dispose()

    $script:ServerRunspace   = $null
    $script:ServerPowerShell = $null

    Write-Host "✓ LocalWebServer gestoppt." -ForegroundColor Green
}
```

---

*Ende der Dokumentation – Version 1.0 | April 2026*