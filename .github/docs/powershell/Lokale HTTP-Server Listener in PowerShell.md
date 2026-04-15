# Lokale HTTP-Server/Listener in PowerShell

## Executive Summary

Dieses Dokument beschreibt umfassend, wie mit PowerShell ein vollständig eigenständiger, lokaler HTTP-Server auf Basis von `System.Net.HttpListener` entwickelt werden kann. Es beantwortet die grundlegenden Fragen zu Technologie, Architektur, Sicherheit, MIME-Types, SPA-Support, Interprozesskommunikation und Modulstruktur – und bietet damit eine solide Grundlage für die Entwicklung eines produktionsreifen, lokal laufenden Webservers in PowerShell.

***

## 1. Szenario & Use Cases

### Wofür braucht man einen lokalen HTTP-Server in PowerShell?

Ein lokal laufender HTTP-Server in PowerShell löst ein häufiges Problem in der Softwareentwicklung und IT-Administration: Webanwendungen – insbesondere SPAs wie Angular-, React- oder Vue-Applikationen – können nicht einfach als Dateien aus dem Dateisystem geöffnet werden. Browser blockieren dabei Sicherheitsfeatures wie Fetch-API, lokales Routing oder den Service-Worker-Cache, da die `file://`-URL bestimmte Cross-Origin-Mechanismen unterbindet.

Ein dedizierter lokaler Server beseitigt diese Einschränkungen vollständig. Mit `http://localhost:8080` wird die WebApp über das echte HTTP-Protokoll ausgeliefert, wodurch:

- **Routing** (HTML5 History API, Hash-Routing) korrekt funktioniert[^1][^2]
- **CORS-Anfragen** zu lokalen APIs möglich werden
- **Service Worker** und PWA-Features genutzt werden können
- **MIME-Types** korrekt vom Server gesetzt werden[^3]
- **Development-Tools** (Browser DevTools, Lighthouse) vollständig nutzbar sind

### Konkrete Anwendungsfälle

| Use Case | Beschreibung |
|---|---|
| **SPA-Hosting** | Angular/React/Vue-Build lokal hosten, ohne Node.js oder IIS zu benötigen |
| **Offline-Dokumentation** | Technische Dokus als WebApp lokal bereitstellen |
| **Admin-Dashboard** | Lokales Web-UI zur Steuerung von PowerShell-Skripten und -Modulen |
| **Entwicklungsumgebung** | Schneller Ersatz für `npm run start` ohne npm-Installation |
| **Kiosk-Systeme** | Vollständige WebApp für Terminals, die keinen externen Server erreichen |
| **Netzwerkinternes Tool** | Leichtgewichtige interne Webanwendung für IT-Teams |

Der entscheidende Vorteil gegenüber klassischen Lösungen (IIS, Apache, XAMPP): Der Server benötigt **keine separate Installation**, keine Konfigurationsdateien und kann vollständig durch PowerShell verwaltet werden – inklusive Start, Stop und Neukonfiguration zur Laufzeit.

***

## 2. HTTP-Server vs. HTTP-Listener – Der Unterschied

### Was ist ein HTTP-Server?

Ein HTTP-Server ist eine vollständige, eigenständige Anwendung, die auf einem definierten Port auf eingehende TCP-Verbindungen wartet, HTTP-Anfragen parst, Ressourcen auflöst und vollständige HTTP-Antworten zurücksendet. Er implementiert den gesamten HTTP-Lebenszyklus: Verbindungsmanagement, Keep-Alive, Pipelining, Fehlerbehandlung, MIME-Erkennung und Logging. Beispiele sind Apache, nginx oder IIS.[^4]

### Was ist ein HTTP-Listener?

Ein HTTP-Listener ist eine **Kernbaukomponente**, die das Empfangen und Weiterleiten von HTTP-Verbindungen übernimmt, ohne selbst die vollständige Server-Logik zu implementieren. In .NET ist `System.Net.HttpListener` exakt das: eine Abstraktion über Windows' HTTP.sys-Kerneltreiber, die eingehende Anfragen entgegennimmt und dem Entwickler als Objekte (`HttpListenerContext`, `HttpListenerRequest`, `HttpListenerResponse`) übergibt. Der Entwickler ist dann selbst dafür verantwortlich, die Anfrage auszuwerten, den richtigen Inhalt zu laden und eine korrekte Antwort zu senden.[^5][^6]

### Gegenüberstellung

| Eigenschaft | HTTP-Server (z. B. Apache) | HTTP-Listener (`HttpListener`) |
|---|---|---|
| **Routing** | Eingebaut (mod_rewrite, VirtualHosts) | Manuell zu implementieren |
| **MIME-Types** | Vordefiniert, konfigurierbar | Manuell per Hashtable/Dictionary |
| **Static Files** | Automatisch ausgeliefert | Manuell aus Dateisystem lesen und senden |
| **SPA-Fallback** | Konfigurierbar (FallbackResource) | Manuell zu implementieren |
| **SSL/TLS** | Nativ und einfach konfigurierbar | Benötigt `netsh`-Bindung + Zertifikat |
| **Abhängigkeiten** | Externe Installation nötig | Eingebaut in .NET/Windows |
| **Flexibilität** | Durch Module erweiterbar | Vollständige Kontrolle über jeden Schritt |

**Fazit:** In PowerShell wird `System.Net.HttpListener` als Listener verwendet, um darauf aufbauend einen vollständigen HTTP-Server zu implementieren. Das bedeutet mehr Entwicklungsaufwand, aber auch maximale Kontrolle.[^5][^3]

***

## 3. Möglichkeiten zum Hosting lokaler SPAs via PowerShell

### Option A: Reines `HttpListener`-Skript (empfohlen)

Der direkteste Weg nutzt `[System.Net.HttpListener]` aus dem .NET-Namensraum, der in PowerShell ohne zusätzliche Installationen verfügbar ist. Dieses Vorgehen ermöglicht vollständige Kontrolle über den Serverbetrieb.[^6]

```powershell
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request  = $context.Request
    $response = $context.Response

    $localPath = $request.Url.LocalPath.TrimStart('/')
    if ([string]::IsNullOrEmpty($localPath)) { $localPath = "index.html" }

    $filePath = Join-Path $RootDirectory $localPath

    if (Test-Path $filePath -PathType Leaf) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $response.ContentType = Get-MimeType $filePath
        $response.StatusCode = 200
    } else {
        # SPA-Fallback: alle unbekannten Routen → index.html
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $RootDirectory "index.html"))
        $response.ContentType = "text/html; charset=utf-8"
        $response.StatusCode = 200
    }

    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
}
```

Dieses Muster deckt bereits die grundlegende SPA-Funktionalität ab: Der Server liefert reale Dateien aus und fällt für unbekannte Pfade auf `index.html` zurück, damit das clientseitige Routing der SPA übernehmen kann.[^7][^8][^2]

### Option B: Polaris (PowerShell-Webframework)

Microsoft hat das experimentelle Modul **Polaris** entwickelt – ein minimalistisches Webframework für PowerShell, das `HttpListener` intern verwendet. Es bietet eine Express.js-ähnliche Routing-API:[^9][^10]

```powershell
Install-Module Polaris
New-PolarisGetRoute -Path "/api/status" -Scriptblock {
    $Response.Send('{"status": "ok"}')
}
Start-Polaris -Port 8080
```

**Wichtiger Hinweis:** Polaris ist als experimentell markiert und wird von Microsoft nicht aktiv als unterstütztes Produkt weiterentwickelt. Für ein produktiv genutztes Modul ist ein eigener Ansatz auf Basis von `HttpListener` empfehlenswert, um volle Kontrolle und Stabilität zu gewährleisten.[^9]

### Option C: Weitere Module aus der Community

- **SimplePowerShellHTTPServer (SPHS)**: Ein PowerShell-Implementierung des .NET-`HttpListener`-Objekts mit Dateiupload/-download-Unterstützung[^11]
- **PSWebServer**: Community-Modul mit Routing-Abstraktion für PowerShell[^12]

### SPA-Routing – Das Kernproblem und die Lösung

SPAs wie Angular oder React nutzen die **HTML5 History API** (`pushState`), um URLs wie `/dashboard` oder `/settings/profile` zu erzeugen, ohne echte Dateien unter diesen Pfaden zu haben. Wenn ein Benutzer die Seite an dieser URL neu lädt, versucht der Server, eine Datei unter `/dashboard` zu finden – die es nicht gibt. Ohne SPA-Fallback entsteht ein 404-Fehler.[^1]

Die Lösung: Der Server muss für jede Anfrage prüfen, ob die angeforderte Ressource eine echte Datei ist. Ist sie es nicht **und** hat der Pfad keine Dateiendung, wird stattdessen `index.html` zurückgegeben:[^8]

```powershell
$extension = [System.IO.Path]::GetExtension($localPath)
$isFilePath = $extension -ne ""

if (Test-Path $filePath -PathType Leaf) {
    # Echte Datei ausliefern
} elseif (-not $isFilePath) {
    # SPA-Route → index.html zurückgeben
    $response.StatusCode = 200
    # index.html laden und senden
} else {
    # Echte 404-Fehler für fehlende Dateien mit Endung
    $response.StatusCode = 404
}
```

### MIME-Types korrekt setzen

Damit Browser Assets korrekt interpretieren (JavaScript, CSS, Bilder, Webfonts, WebAssembly etc.), muss der Server für jede Datei den passenden Content-Type-Header setzen. Eine vollständige MIME-Tabelle als PowerShell-Hashtable:[^3]

```powershell
function Get-MimeType {
    param([string]$FilePath)
    $mimeTypes = @{
        ".html"  = "text/html; charset=utf-8"
        ".htm"   = "text/html; charset=utf-8"
        ".css"   = "text/css; charset=utf-8"
        ".js"    = "application/javascript; charset=utf-8"
        ".mjs"   = "application/javascript; charset=utf-8"
        ".json"  = "application/json; charset=utf-8"
        ".png"   = "image/png"
        ".jpg"   = "image/jpeg"
        ".jpeg"  = "image/jpeg"
        ".gif"   = "image/gif"
        ".svg"   = "image/svg+xml"
        ".ico"   = "image/x-icon"
        ".woff"  = "font/woff"
        ".woff2" = "font/woff2"
        ".ttf"   = "font/ttf"
        ".eot"   = "application/vnd.ms-fontobject"
        ".webp"  = "image/webp"
        ".avif"  = "image/avif"
        ".mp4"   = "video/mp4"
        ".webm"  = "video/webm"
        ".wasm"  = "application/wasm"
        ".pdf"   = "application/pdf"
        ".xml"   = "application/xml"
        ".txt"   = "text/plain; charset=utf-8"
        ".map"   = "application/json"
    }
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($mimeTypes.ContainsKey($ext)) {
        return $mimeTypes[$ext]
    }
    return "application/octet-stream"
}
```

***

## 4. Hintergrundprozess – Server versteckt laufen lassen

### Das Problem: PowerShell und das Konsolenfenster

`powershell.exe` ist eine Konsolenanwendung. Windows erstellt das Konsolenfenster automatisch beim Prozessstart, bevor PowerShell-Code ausgeführt wird. Der Parameter `-WindowStyle Hidden` kann daher ein kurzes Aufblitzen des Fensters nicht vollständig verhindern.[^13]

### Lösung 1: `Start-Process` mit `-WindowStyle Hidden`

Die einfachste Methode, ein PowerShell-Skript vollständig unsichtbar zu starten:

```powershell
Start-Process powershell.exe `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"C:\pfad\zum\server.ps1`"" `
    -WindowStyle Hidden
```

Damit wird der Serverprozess als separater, versteckter Prozess gestartet. Die Prozess-ID kann für spätere Steuerung gespeichert werden.[^14]

### Lösung 2: `Start-Job` im Hintergrund

Für eine Lösung innerhalb derselben PowerShell-Sitzung eignet sich `Start-Job`:[^15][^16]

```powershell
$serverJob = Start-Job -ScriptBlock {
    param($port, $rootDir)
    # Serverlogik hier
} -ArgumentList 8080, "C:\webroot"

# Job später beenden:
Stop-Job $serverJob
Remove-Job $serverJob
```

`Start-Job` erzeugt einen neuen PowerShell-Prozess im Hintergrund, ohne Konsolenfenster.[^15]

### Lösung 3: Runspaces (empfohlen für Module)

Runspaces sind leichtgewichtiger als Jobs, da sie als Thread im bestehenden Prozess laufen und keine Serialisierung der Daten erfordern:[^17][^18]

```powershell
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$ps = [PowerShell]::Create()
$ps.Runspace = $runspace
$ps.AddScript({
    # Serverlogik
    param($port, $rootDir)
}) | Out-Null
$ps.AddArgument(8080) | Out-Null
$ps.AddArgument("C:\webroot") | Out-Null
$handle = $ps.BeginInvoke()
```

### Lösung 4: Windows Task Scheduler

Für einen Server, der beim Windows-Start automatisch und vollständig ohne Konsolenfenster startet, eignet sich der Aufgabenplaner:[^19]

```powershell
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\WebServer\Start-WebServer.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName "LocalWebServer" -Action $action -Trigger $trigger -RunLevel Highest
```

### Vergleich der Methoden

| Methode | Isolation | Sichtbarkeit | Persistenz | Steuerbarkeit |
|---|---|---|---|---|
| `Start-Process` | Eigener Prozess | Kein Fenster | Nur bis Abmeldung | Per PID |
| `Start-Job` | Eigener Prozess | Kein Fenster | Nur bis Sitzungsende | Per Job-Objekt |
| Runspace | Gleicher Prozess | N/A | Nur bis Skriptende | Per Handle |
| Task Scheduler | Eigener Prozess | Kein Fenster | Persistiert über Neustarts | Per Task-Name |

***

## 5. Interprozesskommunikation – Steuerung des Servers

### Frage: Kann ein zweites Skript den laufenden Server über die PID steuern?

Die Antwort ist **ja**, und PowerShell bietet dafür mehrere elegante Mechanismen.

### Methode 1: HTTP-Steuerungsendpoint (empfohlen)

Da der Server ohnehin ein HTTP-Listener ist, ist der einfachste Weg, ihm spezielle **Steuerungs-Routen** beizubringen. Ein zweites Skript sendet dann HTTP-Anfragen an diese Routen:[^20][^21]

```powershell
# Im Server: Steuerungsrouten definieren
if ($request.Url.LocalPath -eq "/control/stop") {
    $response.StatusCode = 200
    Send-Response $response "Server wird gestoppt..."
    $listener.Stop()
    break
}

if ($request.Url.LocalPath -eq "/control/status") {
    $json = '{"status":"running","port":8080,"uptime":"...'
    Send-JsonResponse $response $json
}
```

```powershell
# Zweites Skript: Server stoppen
Invoke-RestMethod -Uri "http://localhost:8080/control/stop" -Method GET
```

Dieser Ansatz ist besonders robust, da er unabhängig von der PID funktioniert und auch aus anderen Sprachen oder Tools aufgerufen werden kann.

### Methode 2: Named Pipes mit `Enter-PSHostProcess`

PowerShell bietet von Haus aus IPC über Named Pipes: Mit `Enter-PSHostProcess -Id <PID>` kann ein zweiter PowerShell-Prozess in den Runspace eines laufenden PowerShell-Prozesses eintreten und dessen Variablen und Funktionen direkt aufrufen:[^22][^23]

```powershell
# In Prozess 1: PID ermitteln
$PID  # z. B. 4820

# In Prozess 2: Verbindung aufbauen
Enter-PSHostProcess -Id 4820
# Jetzt können Variablen und Cmdlets des anderen Prozesses verwendet werden
```

Jeder PowerShell-Prozess erstellt automatisch einen Named-Pipe-Listener, dessen Name aus PID, Startzeit und Prozessname zusammengesetzt wird. Dies funktioniert ohne zusätzliche Konfiguration.[^22]

### Methode 3: Named Pipes (manuell)

Für eine vollständig eigene IPC-Lösung können Named Pipes in PowerShell über .NET implementiert werden:[^24]

```powershell
# Server-Seite (Pipe-Server)
$pipe = [System.IO.Pipes.NamedPipeServerStream]::new("WebServerControl")
$pipe.WaitForConnection()
$reader = [System.IO.StreamReader]::new($pipe)
$command = $reader.ReadLine()
switch ($command) {
    "STOP"    { $listener.Stop() }
    "RESTART" { Restart-Server }
    "STATUS"  { Send-Status $pipe }
}

# Client-Seite (zweites Skript)
$pipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", "WebServerControl", "Out")
$pipe.Connect()
$writer = [System.IO.StreamWriter]::new($pipe)
$writer.WriteLine("STOP")
$writer.Flush()
```

### Methode 4: Shared Files / Mutex

Eine einfachere, aber robuste Alternative: Der Server liest regelmäßig eine Steuerdatei (z. B. `server.control`) aus einem definierten Verzeichnis. Ein externes Skript schreibt Befehle in diese Datei:[^20]

```powershell
# Server: Polling-Loop
while ($listener.IsListening) {
    $ctrlFile = "C:\WebServer\server.control"
    if (Test-Path $ctrlFile) {
        $cmd = Get-Content $ctrlFile -Raw
        Remove-Item $ctrlFile
        if ($cmd.Trim() -eq "STOP") { $listener.Stop(); break }
    }
    # HTTP-Anfragen verarbeiten...
}
```

### Empfehlung

Für das beschriebene Szenario ist **Methode 1 (HTTP-Steuerungsendpoint)** die eleganteste Lösung, da sie keine zusätzliche IPC-Infrastruktur benötigt und die bestehende HTTP-Architektur nutzt. Die Steuerungsrouten sollten durch ein Token oder einen geheimen Schlüssel abgesichert sein.

***

## 6. Benutzerdefinierte Domain statt `localhost`

### Technische Voraussetzungen

Ja, es ist technisch möglich, den Server unter einer anderen Domain wie `http://localweb/` oder `http://webengine/` laufen zu lassen. Dafür sind zwei Schritte notwendig:[^25][^26]

**Schritt 1: Windows Hosts-Datei anpassen**

Die Datei `C:\Windows\System32\drivers\etc\hosts` muss (als Administrator) um einen Eintrag erweitert werden:[^25]

```
127.0.0.1    localweb
127.0.0.1    webengine
```

Nach dem Speichern löst Windows den Hostnamen `localweb` auf `127.0.0.1` auf. Kein DNS-Server wird dafür benötigt.

**Schritt 2: HttpListener-Prefix anpassen**

Der Listener muss auf den neuen Hostnamen hören:

```powershell
$listener.Prefixes.Add("http://localweb:8080/")
$listener.Start()
```

**Alternativ** kann der Wildcard-Prefix `http://+:8080/` verwendet werden, der alle Hostnamen auf dem entsprechenden Port akzeptiert – dann ist keine Hostnamen-spezifische Konfiguration im Listener nötig.[^5]

### Wichtig: `netsh`-Reservierung

`HttpListener` in .NET nutzt intern Windows' **HTTP.sys**-Kerneltreiber. Um als Nicht-Administrator auf einem Port lauschen zu dürfen, muss eine URL-ACL registriert werden:[^27][^28]

```powershell
# Einmalig als Administrator ausführen:
netsh http add urlacl url="http://localweb:8080/" user="DOMÄNE\Benutzername"
# oder für alle Benutzer:
netsh http add urlacl url="http://localweb:8080/" user="Everyone"
```

Ohne diese Registrierung ist für das Öffnen von Ports < 1024 oder für Non-localhost-Prefixe Administratorrecht erforderlich. Für `localhost` auf Ports > 1024 ist in neueren Windows-Versionen dagegen oft kein Admin-Recht nötig.[^29][^28]

### Automatisierung der Hosts-Datei

Das Modul kann die Hosts-Datei automatisch eintragen – erfordert aber ebenfalls Administratorrechte:

```powershell
function Add-HostsEntry {
    param([string]$Hostname)
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    $entry = "127.0.0.1`t$Hostname"
    if (-not (Select-String -Path $hostsFile -Pattern $Hostname -Quiet)) {
        Add-Content -Path $hostsFile -Value $entry
    }
}
```

***

## 7. Architektur: Einzelskript vs. PowerShell-Modul

### Einzelskript – Wann sinnvoll?

Ein einzelnes `.ps1`-Skript ist ausreichend, wenn:
- Der Server als einmaliges Tool für ein spezifisches Projekt verwendet wird
- Keine Wiederverwendung über verschiedene Szenarien geplant ist
- Die Komplexität überschaubar bleibt (< 300 Zeilen)
- Kein Packaging oder Versionierung benötigt wird[^30]

### PowerShell-Modul – Warum es die bessere Wahl ist

Für das beschriebene Szenario (eigenständige Anwendung, Systemvoraussetzungsprüfung, Start/Stop-Steuerung, Wiederverwendbarkeit) ist ein **PowerShell-Modul** klar die überlegene Architektur:[^31][^32]

**Vorteile eines Moduls:**
- **`#Requires`-Statement** zur automatischen Prüfung von PowerShell-Version und Abhängigkeiten
- **`New-ModuleManifest`** (`.psd1`) für Versionierung, Autoren-Metadaten und Abhängigkeitsdeklaration
- **Export-Kontrolle**: Öffentliche Funktionen per `Export-ModuleMember` gezielt freigeben, private Hilfsfunktionen intern halten[^31]
- **Selbstverwaltung**: Das Modul kann eigene Prozesse starten, stoppen und überwachen
- **PowerShell Gallery**: Veröffentlichung und Verteilung über `Publish-Module`

### Empfohlene Modulstruktur

```
LocalWebServer\
├── LocalWebServer.psd1          # Modul-Manifest
├── LocalWebServer.psm1          # Haupt-Modul (lädt alle privaten Funktionen)
├── Public\
│   ├── Start-LocalWebServer.ps1
│   ├── Stop-LocalWebServer.ps1
│   ├── Restart-LocalWebServer.ps1
│   ├── Get-LocalWebServerStatus.ps1
│   └── Set-LocalWebServerConfig.ps1
├── Private\
│   ├── Invoke-HttpListener.ps1  # Kernlogik des Listeners
│   ├── Get-MimeType.ps1
│   ├── Invoke-SpaFallback.ps1
│   ├── Send-HttpResponse.ps1
│   ├── Test-SystemRequirements.ps1
│   └── Register-UrlAcl.ps1
├── Config\
│   └── default.config.json
└── Resources\
    └── error-pages\
        ├── 404.html
        └── 500.html
```

### Selbststart-Logik im Modul

Das Modul kann beim Import (`Import-Module`) automatisch Voraussetzungen prüfen:

```powershell
# In LocalWebServer.psm1
#Requires -Version 5.1

# Private Funktionen laden
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1"
$privateFunctions | ForEach-Object { . $_.FullName }

# Öffentliche Funktionen laden
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"
$publicFunctions | ForEach-Object { . $_.FullName }

# Systemvoraussetzungen beim Modulimport prüfen
Test-SystemRequirements

Export-ModuleMember -Function 'Start-LocalWebServer', 'Stop-LocalWebServer',
                               'Restart-LocalWebServer', 'Get-LocalWebServerStatus',
                               'Set-LocalWebServerConfig'
```

Die Funktion `Test-SystemRequirements` kann prüfen, ob:
- Die benötigte PowerShell-Version vorhanden ist
- Das Root-Verzeichnis existiert
- Der gewünschte Port frei ist (`Test-NetConnection` oder `[System.Net.Sockets.TcpClient]`)
- Administratorrechte vorhanden sind (falls benötigt)
- Die URL-ACL bereits registriert ist

***

## 8. Grundfunktionen und Entwicklungsaufwand

### Mindestanforderungen für einen funktionsfähigen SPA-Server

| Funktion | Beschreibung | Priorität |
|---|---|---|
| **HttpListener initialisieren** | Port/Host konfigurieren, URL-Prefix setzen | Kritisch |
| **Request-Loop** | Synchrone oder asynchrone Request-Verarbeitung | Kritisch |
| **Static File Serving** | Dateien aus Root-Verzeichnis lesen und senden | Kritisch |
| **MIME-Type-Erkennung** | Korrekte Content-Type-Header setzen | Kritisch |
| **SPA-Fallback** | 404-Routen auf `index.html` umleiten | Kritisch |
| **Hintergrundausführung** | Start als Job/Runspace/Task | Wichtig |
| **Start/Stop/Status** | Steuerungsbefehle implementieren | Wichtig |
| **Error Handling** | HTTP 404, 500 mit sinnvollen Fehlerseiten | Wichtig |
| **Logging** | Zugriffsprotokollierung (optional aber empfohlen) | Optional |
| **Path-Traversal-Schutz** | Absichern gegen `../../`-Angriffe | Sicherheitskritisch |
| **Steuerungsendpoint** | `/control`-Route für IPC | Empfohlen |
| **Konfigurationsdatei** | Port, Root-Dir etc. aus JSON/YAML laden | Empfohlen |
| **HTTPS-Support** | Self-Signed-Cert + netsh SSL-Bindung | Erweitert |

### Realistischer Entwicklungsaufwand

| Phase | Beschreibung | Aufwand |
|---|---|---|
| **Phase 1** | Basis-Listener mit Static File Serving und MIME-Types | 2–4 Stunden |
| **Phase 2** | SPA-Fallback, Fehlerseiten, Path-Traversal-Schutz | 3–5 Stunden |
| **Phase 3** | Hintergrundstart (Job/Runspace), Start/Stop-Befehle | 3–6 Stunden |
| **Phase 4** | Modul-Struktur, Manifest, Systemvoraussetzungsprüfung | 4–8 Stunden |
| **Phase 5** | IPC-Steuerungsendpoint, Logging, Konfigurationsdatei | 4–8 Stunden |
| **Phase 6** | Asynchrone Anfrageverarbeitung, Performanceoptimierung | 6–10 Stunden |
| **Phase 7** | HTTPS-Support, Tests, Dokumentation | 6–12 Stunden |

**Gesamtaufwand für einen stabilen, produktionsreifen Server: ca. 28–53 Stunden** – abhängig von Erfahrungsstand und gewünschtem Funktionsumfang. Ein funktionsfähiger MVP (Phasen 1–4) ist realistisch in einem Wochenende entwickelbar.

### Asynchrone vs. synchrone Anfrageverarbeitung

Die einfache, synchrone Implementierung mit `$listener.GetContext()` blockiert den Thread, bis eine Anfrage eingeht. Das bedeutet: Solange eine Anfrage verarbeitet wird, können keine weiteren entgegengenommen werden. Für einen einzelnen Nutzer auf `localhost` ist das ausreichend.[^6]

Für konkurrierende Anfragen (z. B. wenn eine SPA mehrere Assets gleichzeitig lädt) ist asynchrone Verarbeitung nötig:[^33]

```powershell
# Asynchrones Pattern mit BeginGetContext
$callback = {
    param($result)
    $listener = $result.AsyncState
    $context = $listener.EndGetContext($result)
    # Anfrage verarbeiten
    # Nächste Anfrage registrieren
    $listener.BeginGetContext($callback, $listener) | Out-Null
}
$listener.BeginGetContext($callback, $listener) | Out-Null
```

***

## 9. Sicherheit des lokalen Servers

### Grundprinzip: Lokal ≠ sicher

Ein lokal laufender HTTP-Server ist nicht automatisch sicher. Auch wenn er nur auf `localhost` lauscht, können lokale Anwendungen, Browser-Erweiterungen, Skripte und (bei Wildcard-Binding) andere Netzwerkteilnehmer Anfragen senden. Das Risiko ist lokal begrenzt, aber nicht null.

### 9.1 Path Traversal verhindern (Sicherheitskritisch)

Path-Traversal-Angriffe versuchen, durch `../`-Sequenzen in der URL auf Dateien außerhalb des Root-Verzeichnisses zuzugreifen. Beispiel: `http://localhost:8080/../../Windows/System32/cmd.exe`.[^34][^35]

**Schutz durch Pfad-Normalisierung:**

```powershell
function Get-SafeFilePath {
    param([string]$RootDir, [string]$RequestedPath)

    # Pfad normalisieren und kombinieren
    $combined = [System.IO.Path]::Combine($RootDir, $RequestedPath.TrimStart('/').Replace('/', '\'))
    $fullPath  = [System.IO.Path]::GetFullPath($combined)

    # Sicherstellen, dass der Pfad innerhalb des Root-Verzeichnisses liegt
    if (-not $fullPath.StartsWith([System.IO.Path]::GetFullPath($RootDir))) {
        return $null  # Zugriff verweigert
    }
    return $fullPath
}
```

Wenn die Funktion `$null` zurückgibt, wird mit HTTP 403 geantwortet.[^34]

### 9.2 Binding auf localhost beschränken

Der Listener sollte ausschließlich auf `localhost` (127.0.0.1) binden, nicht auf `0.0.0.0` oder `+`, um zu verhindern, dass andere Netzwerkteilnehmer auf den Server zugreifen:[^5]

```powershell
# Sicher: Nur Loopback
$listener.Prefixes.Add("http://localhost:8080/")

# Weniger sicher: Alle Interfaces
# $listener.Prefixes.Add("http://+:8080/")  # Nur wenn bewusst gewünscht
```

### 9.3 Steuerungsendpoints absichern

Steuerungsrouten wie `/control/stop` müssen durch ein Token abgesichert sein, da sonst jedes lokale Programm den Server stoppen könnte:

```powershell
$controlToken = [System.Guid]::NewGuid().ToString()
# Token in Datei speichern, damit externe Skripte es lesen können

if ($request.Url.LocalPath -like "/control/*") {
    $providedToken = $request.Headers["X-Control-Token"]
    if ($providedToken -ne $controlToken) {
        $response.StatusCode = 403
        Send-Response $response "Forbidden"
        continue
    }
}
```

### 9.4 HTTP-Methoden einschränken

Ein Static-File-Server muss nur `GET` und `HEAD`-Anfragen beantworten. Alle anderen Methoden (POST, PUT, DELETE, PATCH) sollten mit HTTP 405 (`Method Not Allowed`) abgelehnt werden, sofern keine API-Endpunkte implementiert sind:

```powershell
if ($request.HttpMethod -notin @("GET", "HEAD")) {
    $response.StatusCode = 405
    $response.Headers.Add("Allow", "GET, HEAD")
    Send-Response $response "Method Not Allowed"
    continue
}
```

### 9.5 Response-Header absichern

Moderne Sicherheits-Header schützen vor Browser-seitigen Angriffen:[^36]

```powershell
$response.Headers.Add("X-Content-Type-Options", "nosniff")
$response.Headers.Add("X-Frame-Options", "SAMEORIGIN")
$response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin")
# Für SPAs ohne externe Ressourcen:
$response.Headers.Add("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'")
```

### 9.6 Eingabevalidierung für API-Endpunkte

Falls der Server zusätzlich als API-Backend fungiert, müssen alle eingehenden Daten (Query-Parameter, Request-Body) vollständig validiert werden, bevor sie weiterverarbeitet werden. Niemals eingehende Daten unvalidiert an `Invoke-Expression` oder andere Ausführungsbefehle übergeben.

### 9.7 HTTPS mit Self-Signed-Zertifikat

Für sensible Daten empfiehlt sich HTTPS, auch lokal. Die Einrichtung erfordert ein Zertifikat und eine `netsh`-SSL-Bindung:[^37][^38][^39]

```powershell
# Schritt 1: Self-Signed-Zertifikat erstellen
$cert = New-SelfSignedCertificate `
    -DnsName "localhost" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(5)

# Schritt 2: SSL-Bindung über netsh registrieren (als Admin)
$thumbprint = $cert.Thumbprint
$appId = [Guid]::NewGuid().ToString("B")
netsh http add sslcert ipport=0.0.0.0:8443 certhash=$thumbprint appid=$appId

# Schritt 3: HTTPS-Listener konfigurieren
$listener.Prefixes.Add("https://localhost:8443/")
```

### Sicherheitscheckliste

| Maßnahme | Priorität | Beschreibung |
|---|---|---|
| Path-Traversal-Schutz | **Kritisch** | `GetFullPath` + Root-Verzeichnis-Check |
| Nur-Localhost-Binding | **Hoch** | `http://localhost:PORT/` statt `http://+:PORT/` |
| Steuerungs-Token | **Hoch** | Zufälliges GUID pro Serverstart |
| HTTP-Methoden einschränken | **Mittel** | Nur GET/HEAD für Static Files |
| Security-Header | **Mittel** | X-Content-Type-Options, X-Frame-Options, CSP |
| Eingabevalidierung | **Mittel** | Alle externen Daten validieren |
| Logging | **Empfohlen** | Zugriffsprotokoll für Forensik |
| HTTPS | **Optional** | Für sensitive Daten empfohlen |
| Rate Limiting | **Optional** | Schutz vor exzessiven Anfragen |

***

## 10. Vollständiges Beispiel: Minimaler SPA-Server

Das folgende Beispiel zeigt einen vollständigen, funktionsfähigen SPA-Server als PowerShell-Funktion, der die wichtigsten beschriebenen Konzepte vereint:[^40][^41][^3]

```powershell
function Start-SpaServer {
    [CmdletBinding()]
    param(
        [string]$RootDirectory = (Get-Location).Path,
        [int]$Port = 8080,
        [switch]$Background
    )

    $serverBlock = {
        param($RootDir, $Port)

        #region MIME-Types
        $mimeTypes = @{
            ".html" = "text/html; charset=utf-8"; ".htm"  = "text/html; charset=utf-8"
            ".css"  = "text/css; charset=utf-8";  ".js"   = "application/javascript"
            ".json" = "application/json";          ".png"  = "image/png"
            ".jpg"  = "image/jpeg";               ".jpeg" = "image/jpeg"
            ".gif"  = "image/gif";                ".svg"  = "image/svg+xml"
            ".ico"  = "image/x-icon";             ".woff" = "font/woff"
            ".woff2"= "font/woff2";               ".webp" = "image/webp"
            ".wasm" = "application/wasm";          ".map"  = "application/json"
        }
        #endregion

        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://localhost:$Port/")
        $listener.Start()

        while ($listener.IsListening) {
            try {
                $ctx      = $listener.GetContext()
                $req      = $ctx.Request
                $res      = $ctx.Response

                # Path-Traversal-Schutz
                $rawPath  = $req.Url.LocalPath.TrimStart('/')
                if ([string]::IsNullOrEmpty($rawPath)) { $rawPath = "index.html" }
                $combined = [IO.Path]::GetFullPath([IO.Path]::Combine($RootDir, $rawPath))

                if (-not $combined.StartsWith([IO.Path]::GetFullPath($RootDir))) {
                    $res.StatusCode = 403
                    $bytes = [Text.Encoding]::UTF8.GetBytes("403 Forbidden")
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.Close(); continue
                }

                # Steuerungsendpoint
                if ($req.Url.LocalPath -eq "/control/stop") {
                    $res.StatusCode = 200
                    $bytes = [Text.Encoding]::UTF8.GetBytes("Server stopping...")
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.Close()
                    $listener.Stop(); break
                }

                # Datei auflösen: echte Datei oder SPA-Fallback
                $ext = [IO.Path]::GetExtension($rawPath)
                if (Test-Path $combined -PathType Leaf) {
                    $filePath = $combined
                    $mime     = if ($mimeTypes[$ext]) { $mimeTypes[$ext] } else { "application/octet-stream" }
                } elseif ($ext -eq "") {
                    # SPA-Route: Fallback auf index.html
                    $filePath = [IO.Path]::Combine($RootDir, "index.html")
                    $mime     = "text/html; charset=utf-8"
                } else {
                    $res.StatusCode = 404
                    $bytes = [Text.Encoding]::UTF8.GetBytes("<h1>404 - Not Found</h1>")
                    $res.ContentType = "text/html; charset=utf-8"
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.Close(); continue
                }

                # Security-Header
                $res.Headers.Add("X-Content-Type-Options", "nosniff")
                $res.Headers.Add("X-Frame-Options", "SAMEORIGIN")

                # Datei senden
                $bytes = [IO.File]::ReadAllBytes($filePath)
                $res.ContentType     = $mime
                $res.StatusCode      = 200
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()

            } catch { Write-Warning "Fehler: $_" }
        }
        $listener.Dispose()
    }

    if ($Background) {
        $job = Start-Job -ScriptBlock $serverBlock -ArgumentList $RootDirectory, $Port
        Write-Host "Server gestartet (Job-ID: $($job.Id)) auf http://localhost:$Port/"
        return $job
    } else {
        & $serverBlock -RootDir $RootDirectory -Port $Port
    }
}
```

***

## Fazit und Empfehlungen

Für die Entwicklung eines vollständigen, eigenständigen lokalen HTTP-Servers in PowerShell bietet `System.Net.HttpListener` die optimale Grundlage. Die Technologie ist tief in Windows integriert, benötigt keine externen Abhängigkeiten und gibt dem Entwickler vollständige Kontrolle über den gesamten Request-Response-Zyklus.[^3][^5]

**Die wichtigsten Empfehlungen auf einen Blick:**

1. **Architektur**: PowerShell-Modul mit `.psm1` + `.psd1`, Public/Private-Trennung, selbstständiger Systemvoraussetzungsprüfung[^31]
2. **Hintergrundstart**: `Start-Job` für einfache Szenarien, Runspaces für Performancekritisches, Task Scheduler für Autostart[^16][^15]
3. **SPA-Support**: Fallback auf `index.html` für alle Pfade ohne Dateiendung, die keine echte Datei sind[^2][^8]
4. **IPC**: HTTP-Steuerungsendpoint mit Token-Absicherung als einfachste und robusteste Lösung[^20]
5. **Custom Domain**: Hosts-Datei + `netsh urlacl` für eigene lokale Domains[^27][^25]
6. **Sicherheit**: Path-Traversal-Schutz ist nicht optional – er ist die Mindestanforderung jedes dateiausliefernden HTTP-Servers[^35][^34]

---

## References

1. [Configure Azure Static Web Apps - Microsoft Learn](https://learn.microsoft.com/en-us/azure/static-web-apps/configuration) - The fallback page is often designated as index.html for your client-side app. Note. Route rules aren...

2. [Avoiding 404 errors with Single-Page Apps | oliverjam.com](https://oliverjam.es/articles/avoid-spa-404) - The solution is to tell your server to respond with the index.html for any route. Since that page co...

3. [Building a web server with PowerShell - 4sysops](https://4sysops.com/archives/building-a-web-server-with-powershell/) - I am going to show you how to make a simple web server in PowerShell that serves the contents of the...

4. [Creating A Model HTTP Server Program Using java](https://arxiv.org/ftp/arxiv/papers/1003/1003.1497.pdf) - ...information that is suitable for the World
Wide Web and can be accessed through a web browser and...

5. [PowerShell als HTTPServer - MSXFAQ](https://www.msxfaq.de/powershell/pshttpserver.htm) - Die einfachste Form eines HTTP-Servers mit PowerShell besteht aus ganz wenigen Zeilen. Ein HTTP-List...

6. [Running Simple HTTP Web Server Using PowerShell](https://woshub.com/simple-http-webserver-powershell/) - You can run a simple HTTP web server directly from your PowerShell console. You can run such a web s...

7. [Apache settings for SPA using HTML5 History routing - Stack Overflow](https://stackoverflow.com/questions/54897317/apache-settings-for-spa-using-html5-history-routing) - How could I configure Apache to only fall back to the index.html page for directories that don't exi...

8. [Handling SPA Fallback Paths in a Generic ASP.NET Core Server](https://weblog.west-wind.com/posts/2020/Jul/12/Handling-SPA-Fallback-Paths-in-a-Generic-ASPNET-Core-Server) - In this post I'll describe a simple middleware handler that generically and application specifically...

9. [PowerShell/Polaris: A cross-platform, minimalist web ... - GitHub](https://github.com/powershell/polaris) - Polaris is currently an unsupported, experimental, proof-of-concept. There is no current plan to tur...

10. [Polaris - simple Microservices using only PowerShell](https://devblogs.microsoft.com/powershell/polaris-simple-microservices-using-only-powershell/) - Polaris is a cross-platform, minimalist web framework for PowerShell Core 6. With 6 lines of code, y...

11. [A simple HTTP server module for PowerShell · GitHub](https://github.com/lpowell/SimplePowerShellHTTPServer) - SPHS is a PowerShell implementation of the .Net HttpListener class. SPHS includes a simple file uplo...

12. [Any interest in a Webserver Module (PSWebServer)? : r/PowerShell](https://www.reddit.com/r/PowerShell/comments/o9ay6y/any_interest_in_a_webserver_module_pswebserver/) - Hi! I've been playing around with creating a Powershell script (written all in Powershell) Webserver...

13. [best way to run powershell scripts in the background as scheduled ...](https://www.reddit.com/r/PowerShell/comments/crwfij/best_way_to_run_powershell_scripts_in_the/) - The console window is automatically created by the OS when the process starts. The powershell.exe co...

14. [How can I launch this PowerShell script in a new hidden window](https://stackoverflow.com/questions/52211463/how-can-i-launch-this-powershell-script-in-a-new-hidden-window) - Use Start-Process 's own -WindowStyle Hidden parameter to launch your script hidden and asynchronous...

15. [Powershell HTTP server in background thread (could be easily killed)](https://gist.github.com/mark05e/089b6668895345dd274fe5076f8e1271) - Powershell HTTP server in background thread (could be easily killed). Raw ... $serverJob = Start-Job...

16. [Script to start a background job in PowerShell on Windows - Hexnode](https://www.hexnode.com/mobile-device-management/help/script-to-start-a-background-job-in-powershell-on-windows/) - Learn how to start a background job in PowerShell on Windows devices using a script, allowing you to...

17. [Using Background Runspaces Instead of PSJobs For Better ...](https://learn-powershell.net/2012/05/13/using-background-runspaces-instead-of-psjobs-for-better-performance/) - I find myself using background runspaces more lately because you do not have to worry about another ...

18. [Beginning Use of PowerShell Runspaces: Part 1](https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-1/) - Runspaces create a new thread on the existing process, and you can simply add what you need to it an...

19. [Start a detached background process in PowerShell - Stack Overflow](https://stackoverflow.com/questions/25023458/start-a-detached-background-process-in-powershell) - I have a Java program which I would like to launch as a background process from a PowerShell script,...

20. [Making a RESTful API endpoint in powershell (kinda like python flask)](https://tech.zsoldier.com/2018/08/powershell-making-restful-api-endpoint.html) - Basically, you can have this script run on OS startup (pre-populated with your endpoint configs/scri...

21. [Getting data out of Powershell Jobs/Runspaces in realtime](https://royashbrook.com/2021/04/19/getting-data-out-of-powershell-jobs-runspaces-in-realtime/) - Run a web server that receives body data and echoes it to the screen; Have async processes make call...

22. [PowerShell Host IPC for any .NET application - AwakeCoding ☀️](https://awakecoding.com/posts/powershell-host-ipc-for-any-dotnet-application/) - Explore how PowerShell enables interprocess communication (IPC) using named pipes in .NET applicatio...

23. [Getting Enter-PSHostProcess behavior via PSSessionConfiguration ...](https://stackoverflow.com/questions/39376165/getting-enter-pshostprocess-behavior-via-pssessionconfiguration-file) - Enter-PSHostProcess communicates via named pipes, while Enter-PSSession uses WinRM (which is effecti...

24. [Local Machine Interprocess Communication with .NET](https://weblogs.asp.net/ricardoperes/local-machine-interprocess-communication-with-net) - This is generally called Interprocess Communication, or IPC. In this post, I am going to cover sever...

25. [Serve localhost with custom domain - DEV Community](https://dev.to/hidaytrahman/serve-localhost-with-custom-domain-3c3d) - Open the hosts file at C:\Windows\System32\Drivers\etc\hosts; Make the necessary changes to the file...

26. [How to set a custom domain name on a localhost (Windows 10)](https://ecompile.io/blog/localhost-custom-domain-name) - Step 1. Open the directory below in file explorer: C:\Windows\System32\drivers\etc Step 2. There you...

27. [netsh http | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-http) - ... http add urlacl, Allows non-administrator users and accounts to register the URL. The access per...

28. [Unable to run as a non-admin · Issue #204 · PowerShell/Polaris](https://github.com/PowerShell/Polaris/issues/204) - Unable to run Polaris as a non-admin due to httplistener use of http.sys and that needs admin rights...

29. [httpListener in local network without admin rights - Stack Overflow](https://stackoverflow.com/questions/47711660/httplistener-in-local-network-without-admin-rights) - I have the task to create a listener to a local computer inside a network. This computer takes POST ...

30. [When to choose development of a PowerShell Module over ...](https://stackoverflow.com/questions/5103211/when-to-choose-development-of-a-powershell-module-over-powershell-script) - In a nutshell, Windows PowerShell modules allow you to partition, organize, and abstract your Window...

31. [How to Write Better PowerShell Scripts: Architecture and Best ...](https://dev.to/playfulprogramming/how-to-write-better-powershell-scripts-architecture-and-best-practices-emh) - A script module can contain any PowerShell code, such as variables, functions, classes, commands, ex...

32. [Mastering PowerShell Script Modules: A Comprehensive Guide for ...](https://www.linkedin.com/pulse/mastering-powershell-script-modules-comprehensive-guide-vishal-pant-jz0zc) - 8. Best Practices for Module Development · Use Clear Naming Conventions: Follow a consistent naming ...

33. [c# - Httplistener asynchronous handling with Powershell (New ...](https://stackoverflow.com/questions/56058924/httplistener-asynchronous-handling-with-powershell-new-scriptblockcallback-s) - The code below should handle requests asynchronously, however when calling /timeout (that gives 10se...

34. [Preventing path traversal in PowerShell - Reddit](https://www.reddit.com/r/PowerShell/comments/vjjofi/preventing_path_traversal_in_powershell/) - It's supposed to take a filename from user input, then modify a file according to pre-defined rules....

35. [Testing Directory Traversal File Include - OWASP Foundation](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/05-Authorization_Testing/01-Testing_Directory_Traversal_File_Include) - Using input validation methods that have not been well designed or deployed, an aggressor could expl...

36. [PowerShell Security Best Practices for Windows Server - WafaiCloud](https://wafaicloud.com/blog/powershell-security-best-practices-for-windows-server/) - PowerShell Security Best Practices for Windows Server · 1. Restrict Execution Policies · 2. Limit Po...

37. [Using HTTPListener with HTTPS for local IP Address (Windows)](https://gist.github.com/unitycoder/ec217d20eecc2dfaf8d316acd8c3c5c5) - Using HTTPListener with HTTPS · CommandPrompt (as administrator): netsh http add sslcert ipport=0.0....

38. [Configure HTTPS with HTTP.sys for self hosted web servers](http://blog.boxofbolts.com/ssl/windows/owin/guide/2015/06/29/https-self-hosted-windows/) - A quick run down of the things you need to do to setup HTTPS for a self hosted web server. Assumptio...

39. [How Do I create secure https://127.0.0.1:8080 instead of http://127.0 ...](https://www.reddit.com/r/PowerShell/comments/12jm61w/how_do_i_create_secure_https1270018080_instead_of/) - To create a secure https://127.0.0.1:8080 using PowerShell, you need to do the following steps: - Ge...

40. [powershell HttpListener http file server - Stack Overflow](https://stackoverflow.com/questions/43103472/powershell-httplistener-http-file-server) - I'm trying to create a basic Powershell script to share files through http, I've copied the code fro...

41. [A simple PowerShell HTTP server script that supports static file ...](https://gist.github.com/barbarbar338/1ded84c76d7039845f474fb31a88dc01) - A simple PowerShell HTTP server script that supports static file hosting, server-side executions and...

