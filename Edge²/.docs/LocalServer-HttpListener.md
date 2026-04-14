<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***
<!--
_Aus gegebenem Anlass interessiere ich mich sehr für die Möglichkeit, wie ich in PowerShell einen eigenen, leichten Server/HTTPlListener programmieren kann, der in der Lage ist, lokal gespeicherte SPAs zu hosten sodass man diese via entsprechender URL im Browser aufrufen und verwenden kann._

***

Nachfolgend eine vollständige Erklärung aller Konzepte und Designentscheidungen.

***
-->

## Architektur \& Kernkonzepte

Das Skript besteht aus drei Schichten, die voneinander unabhängig und erweiterbar sind:

**1. MIME-Type-Dictionary (`$Script:MimeTypes`)**
Ein skriptweit verfügbares Dictionary, das Dateiendungen auf ihre Content-Type-Strings mappt. Es deckt über 40 Typen ab — Web-Kern, Bilder, Fonts, Medien, Archive und PWA-Manifeste. Erweiterbar durch einfaches Hinzufügen eines weiteren Eintrags.

**2. Die `[LocalServer]`-Klasse**
Der Kern des Skripts. Kapselt den kompletten Lebenszyklus des Servers — Initialisierung, Hintergrundausführung und sauberes Herunterfahren — in einer einzigen, wiederverwendbaren Klasse.

**3. Die `New-LocalServer`-Hilfsfunktion**
Eine Factory-Funktion für bequeme One-Liner-Nutzung nach dem Dot-Sourcing.

***

## Wie der Hintergrundserver funktioniert

Der kritischste technische Aspekt: Der Server **blockiert den aufrufenden Thread nicht**. Das wird durch eine Kombination aus zwei .NET-Mechanismen erreicht:

- **`System.Net.HttpListener`** — Die .NET-Klasse, die den eigentlichen TCP-Socket öffnet und HTTP-Anfragen annimmt. Sie ist seit .NET 2.0 verfügbar und funktioniert in PowerShell 5.1 und 7+ gleichermaßen.
- **PowerShell Runspace** — Anstatt `Start-Job` (das einen separaten PowerShell-Prozess startet), wird ein leichtgewichtiger `Runspace` erzeugt — ein eigener Thread *im selben Prozess*. Das ermöglicht es, den `$_listener` direkt als Referenz zu übergeben, ohne Serialisierung.

Der Runspace führt die `$requestLoop`-ScriptBlock im Hintergrund aus, während `$server.Start()` sofort zurückkehrt und die PowerShell-Session interaktiv bleibt.

***

## Der Request-Loop im Detail

Statt des naiven `$listener.GetContext()` (blockiert den Thread für immer) verwendet der Loop `BeginGetContext` / `EndGetContext` mit einem **500ms WaitHandle-Timeout**:

```powershell
$asyncResult = $Listener.BeginGetContext($null, $null)
$signaled    = $asyncResult.AsyncWaitHandle.WaitOne(500)
```

Das bedeutet: Alle 500ms prüft der Loop ob `$Cts.IsCancellationRequested` gesetzt wurde — so ist ein sauberes Stoppen jederzeit möglich, ohne dass der Thread ewig auf eine Anfrage warten muss.

***

## SPA-Fallback-Routing

Für React, Angular, Vue \& Co. ist das der wichtigste Mechanismus. Wenn eine URL wie `/dashboard/settings` aufgerufen wird, existiert diese Datei natürlich nicht im Dateisystem. Ohne Fallback käme ein 404. Mit `$SpaFallback = $true` liefert der Server stattdessen `index.html` — und der clientseitige Router (React Router, Angular Router etc.) übernimmt die Auflösung der Route im Browser.

***

## Sicherheit: Path-Traversal-Guard

Die Funktion `Resolve-SafePath` verhindert Directory-Traversal-Angriffe (`/../../../etc/passwd`):

```powershell
if (-not $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
    return $null  # → 403 Forbidden
}
```

Jeder aufgelöste Pfad wird gegen das Root-Verzeichnis geprüft. Versuche, aus dem Web-Root auszubrechen, werden mit einem `403` abgefangen.

***

## Verwendung nach dem Dot-Sourcing

```powershell
# Klasse und Funktion in die aktuelle Session laden
. .\localserver.ps1

# --- Option A: Komfortfunktion (empfohlen) ---
$server = New-LocalServer -RootPath "C:\MeineApp\dist" -Port 3000
# Startet sofort und öffnet den Browser

# --- Option B: Direkter Klassenzugriff (für mehr Kontrolle) ---
$server = [LocalServer]::new("C:\MeineApp\dist", "http://localhost:8080/")
$server.SpaFallback            = $true
$server.EnableDirectoryListing = $false
$server.CustomHeaders["Cache-Control"] = "no-cache"
$server.Start()

# Status abfragen
$server.IsRunning()       # True / False
$server.ToString()        # Statuszeile mit allen Infos
$server.OpenInBrowser()   # Browser öffnen

# Server stoppen (ressourcenschonend)
$server.Stop()
```


***

## Aus einem anderen Skript per Dot-Sourcing einbinden

```powershell
# deploy.ps1 — Beispiel: SPA builden und direkt hosten
$distPath = ".\my-angular-app\dist\my-angular-app"

# localserver.ps1 laden
. "$PSScriptRoot\localserver.ps1"

# Server starten
$global:DevServer = New-LocalServer -RootPath $distPath -Port 4200 -OpenBrowser $true

Write-Host "Dev server running. Press any key to stop..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
$global:DevServer.Stop()
```


***

## Erweiterungsideen für spätere Iterationen

| Feature | Umsetzungsansatz |
| :-- | :-- |
| **CORS-Header** | `$server.CustomHeaders["Access-Control-Allow-Origin"] = "*"` — bereits heute möglich |
| **HTTPS / TLS** | `$listener.Prefixes.Add("https://localhost:443/")` + Zertifikat via `netsh` binden |
| **Live-Reload** | SSE-Endpoint (`/sse`) + FileSystemWatcher zum Pushen von Reload-Signalen |
| **Caching (ETag/Last-Modified)** | Im Request-Loop: Datei-Hash als ETag, `If-None-Match` prüfen → 304 |
| **Logging in Datei** | `StreamWriter` im Runspace öffnen, jede Anfrage mit Timestamp schreiben |
| **Multi-Site-Routing** | Dictionary `[string → string]` von Hostname/Pfad-Präfix auf Root-Verzeichnis |
| **API-Mock-Endpoints** | Vor dem Datei-Routing: URL-Pattern prüfen und JSON-Response zurückgeben |

