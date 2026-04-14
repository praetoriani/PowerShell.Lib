<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# WebView2 - User Data Folder

```text
ℹ️ Hinweis

Alle Informationen in diesem Dokument beziehen sich auf PowerEdge v1.00.00.
Es ist durchaus möglich, dass es bereits aktuellere Versionen von PowerEdge gibt.
```

Dieses Dokument behandelt, wie die WebView2-Engine in PowerEdge die Benutzerdaten (User Data) verwaltet, wo sie diese speichert und bespricht, wie es theoretisch möglich ist, mehrere Browser-Profile anzulege.

## Was ist `.wv2data`?

Der Ordner ist das sogenannte **User-Data-Verzeichnis** (User Data Folder) der embedded Chromium-Engine, die WebView2 intern verwendet. Microsoft Edge basiert auf Chromium — und WebView2 ist im Grunde dieselbe Engine, eingebettet in deine Anwendung. Jeder Chromium-basierte Browser (Chrome, Edge, Brave, Vivaldi) legt ein solches Profilverzeichnis an, um seinen Zustand persistent zu speichern.

Wenn du Edge öffnest, liegt dessen entsprechender Ordner unter:

```
%LOCALAPPDATA%\Microsoft\Edge\User Data\
```

Bei PowerEdge landet er durch den Fix eben in:

```
<PSScriptRoot>\.wv2data\
```


***

## Was ist `EBWebView`?

Das ist der Name des **Browser-Profils** innerhalb des User-Data-Verzeichnisses. Der Name `EBWebView` ist der Chromium-Standard-Profilname, den WebView2 verwendet, wenn kein eigener Profilname angegeben wird. In einem normalen Edge-Browser heißt das entsprechende Verzeichnis `Default`.

Die Struktur sieht immer so aus:

```
.wv2data\              ← User-Data-Verzeichnis (übergeben an CreateAsync)
  └── EBWebView\       ← Browser-Profil
        ├── Cache\
        ├── Network\
        ├── ...
```


***

## Welche Dateien werden dort erstellt?

Die über 150 Dateien verteilen sich auf mehrere Kategorien:

### Browser-Infrastruktur (immer vorhanden)

| Datei / Ordner | Inhalt |
| :-- | :-- |
| `Preferences` | JSON-Datei mit allen Browser-Einstellungen des Profils |
| `Secure Preferences` | Signierte, manipulationsgeschützte Version der Preferences |
| `Local State` | Globale Zustands-Daten des User-Data-Verzeichnisses |
| `Web Data` | SQLite-DB: Autofill-Daten, Formulardaten |
| `History` | SQLite-DB: Browserverlauf |
| `Cookies` | SQLite-DB: HTTP-Cookies der geöffneten Seiten |
| `Login Data` | SQLite-DB: Gespeicherte Zugangsdaten (bei WebView2 leer) |

### Netzwerk \& Cache

| Datei / Ordner | Inhalt |
| :-- | :-- |
| `Cache\` | HTTP-Disk-Cache — gecachte Ressourcen (JS, CSS, Bilder) der geladenen HTML-Seite |
| `Network\` | Netzwerk-Qualitätsdaten, HSTS-Preload-Liste (HTTP Strict Transport Security) |
| `Code Cache\` | Kompilierter JavaScript-Bytecode (V8 Cache) — beschleunigt das zweite Laden derselben JS-Dateien erheblich |
| `GPUCache\` | Shader-Cache der GPU: kompilierte WebGL/GPU-Programme |

### Sicherheit \& Verschlüsselung

| Datei / Ordner | Inhalt |
| :-- | :-- |
| `TransportSecurity` | HSTS- und PKP-Daten (HTTP Public Key Pinning) |
| `Trust Tokens` | Privacy-Mechanismus für Authentifizierung ohne Tracking |
| `Certificate Revocation Lists\` | Widerrufene TLS-Zertifikate |

### Chromium-interne Verwaltung

| Datei / Ordner | Inhalt |
| :-- | :-- |
| `IndexedDB\` | Web Storage API — Schlüssel-Wert-Datenbank für Webanwendungen |
| `Local Storage\` | `localStorage`-Daten der geöffneten HTML-Seite |
| `Session Storage\` | `sessionStorage`-Daten |
| `Service Worker\` | Registrierte Service Worker (falls deine WebApp PWA-Features nutzt) |
| `Extension State` | Zustand von Browser-Erweiterungen (bei WebView2 leer) |
| `Visited Links` | Welche Links der Nutzer bereits besucht hat (für CSS `:visited`) |


***

## Warum werden die Daten sofort neu erstellt?

Chromium initialisiert sein Profil **beim ersten Start vollständig neu**, weil alle diese Datenbanken und Konfigurationsdateien für den Betrieb der Engine **zwingend erforderlich** sind. Das ist kein optionales Caching, sondern die grundlegende Datenschicht, auf der die Browser-Engine arbeitet. Ohne `Preferences` weiß die Engine nicht, welche Einstellungen gelten. Ohne `Cookies`-Datenbank kann kein einziges Cookie gespeichert werden — selbst wenn deine WebApp keine Cookies verwendet, muss die Datei existieren.

Das ist konzeptionell identisch damit, dass du eine portable App aus einem ZIP entpackst — beim ersten Start werden immer alle notwendigen Konfigurationsdateien angelegt, auch wenn du sie zuvor gelöscht hast.

***

## Soll man `.wv2data` in `.gitignore` aufnehmen?

**Ja, unbedingt.** Der Ordner enthält ausschließlich Laufzeit-Daten, die auf jedem Rechner neu generiert werden und nicht ins Repository gehören. Füge in deine `.gitignore` folgendes ein:

```gitignore
# WebView2 user-data directory (runtime-generated, machine-specific)
.wv2data/
```

***

## Sollte man `.wv2data` nicht löschen?

Ja, im Klartext: **Wenn du PowerEdge regelmäßig nutzt, solltest du den Ordner in Ruhe lassen.** Beim Löschen gehen verloren:

- **HTTP-Cache** — alle gecachten Ressourcen deiner WebApp. Beim nächsten Start muss alles neu geladen und neu kompiliert werden → spürbar langsamerer erster Start
- **V8 Code Cache** — kompilierter JavaScript-Bytecode. Ohne ihn übersetzt die Engine beim nächsten Start jede JS-Datei erneut
- **GPU Shader Cache** — kompilierte WebGL-Shader. Betrifft dich nur wenn deine WebApp Canvas oder WebGL nutzt
- **localStorage / IndexedDB** — falls deine WebApp Daten clientseitig speichert (Einstellungen, Zustände, Offline-Daten), sind diese **dauerhaft weg**
- **Cookies \& Session-Daten** — Sitzungszustände, Login-Tokens einer eingebetteten WebApp gehen verloren
- **Preferences** — angepasste Browser-Einstellungen des WebView2-Profils

Der Ordner schadet nicht. Er wächst moderat (typisch 5–50 MB je nach WebApp) und sollte dauerhaft erhalten bleiben.

***

## Kann man den Ordner umbenennen oder verlagern?

**Ja, vollständig.** Der Pfad ist in PowerEdge bewusst als Variable ausgelagert (`$global:Wv2DataDir`) und wird an `CoreWebView2Environment.CreateAsync()` übergeben. Du kannst dort jeden beliebigen, schreibbaren Pfad angeben. Es sind nur **zwei Zeilen** im Skript zu ändern:

```powershell
# Aktuelle Zeile in PowerEdge.ps1:
$global:Wv2DataDir = Join-Path $PSScriptRoot ".wv2data"

# Beispiel 1: Umbenennen zu .\userdata
$global:Wv2DataDir = Join-Path $PSScriptRoot "userdata"

# Beispiel 2: Zentrales Verzeichnis im AppData-Ordner des Benutzers
$global:Wv2DataDir = Join-Path $env:LOCALAPPDATA "PowerEdge\userdata"

# Beispiel 3: Absoluter Pfad auf einem anderen Laufwerk
$global:Wv2DataDir = "D:\PowerEdge\userdata"
```

Es gibt dabei **keine Einschränkungen** — der Pfad darf Leerzeichen enthalten, auf einem Netzlaufwerk liegen oder ein beliebiger Unterordner sein. WebView2 legt ihn beim ersten Start automatisch an, falls er noch nicht existiert. Wichtig ist nur, dass der laufende Benutzer Schreibrecht auf diesen Pfad hat.

***

## Können mehrere Profile angelegt werden?

**Ja — und das ist sogar ein offiziell unterstütztes Feature von WebView2.** Die Architektur sieht so aus:

```
UserDataFolder (.wv2data)          ← ein CoreWebView2Environment
  ├── EBWebView\                   ← Standard-Profil (automatisch)
  ├── WorkProfile\                 ← eigenes Profil A
  └── PersonalProfile\             ← eigenes Profil B
```

Ein `CoreWebView2Environment` entspricht immer einem User-Data-Verzeichnis. Innerhalb dieses Verzeichnisses können **mehrere benannte Profile** existieren — jedes mit eigenem Cache, eigenen Cookies, eigenem localStorage und eigenen Einstellungen. Profile werden über `CoreWebView2Environment.CreateCoreWebView2ControllerWithOptionsAsync()` in Kombination mit `CoreWebView2ControllerOptions` angelegt.

### Wie das in PowerEdge aussehen würde

```powershell
# Profil-Optionen erstellen
$profileOptions = $wv2Env.CreateCoreWebView2ControllerOptions()
$profileOptions.ProfileName = "WorkProfile"    # Name des Profils
$profileOptions.IsInPrivateModeEnabled = $false

# WebView2-Controller mit diesem Profil initialisieren
# (vereinfachte Darstellung des Prinzips)
$wv2Env.CreateCoreWebView2ControllerWithOptionsAsync(
    $hwnd,
    $profileOptions
)
```


### Praktisches Szenario für PowerEdge

Du könntest PowerEdge einen optionalen Parameter `-Profile` geben:

```powershell
param(
    [string]$WebAppPath  = "",
    [string]$WindowTitle = "PowerEdge",
    [string]$Profile     = "Default"       # ← neu
)
```

Dann würde jedes Profil in `$global:Wv2DataDir` einen eigenen Unterordner bekommen:


| Aufruf | Profil-Verzeichnis |
| :-- | :-- |
| `.\PowerEdge.ps1` | `.wv2data\Default\` |
| `.\PowerEdge.ps1 -Profile Work` | `.wv2data\Work\` |
| `.\PowerEdge.ps1 -Profile Private` | `.wv2data\Private\` |

Jedes Profil hat komplett isolierte Cookies, Cache, localStorage und Einstellungen. Das ist nützlich, wenn du mit PowerEdge verschiedene WebApps betreibst, die sich nicht gegenseitig beeinflussen sollen — z. B. eine interne Firmeanwendung und ein persönliches Dashboard.

### In-Private-Modus als Sonderfall

WebView2 unterstützt auch einen **In-Private-Profil-Modus** (`IsInPrivateModeEnabled = $true`). In diesem Modus werden **keine Daten auf die Festplatte geschrieben** — alles läuft ausschließlich im RAM. Nach dem Schließen des Fensters sind alle Cookies, Cache und Storage-Daten rückstandslos weg. Das wäre das PowerEdge-Äquivalent zum Inkognito-Fenster in Edge:

```powershell
.\PowerEdge.ps1 -Profile InPrivate   # kein persistenter Zustand
```


***

## Zusammenfassung der Möglichkeiten

| Was | Wie | Aufwand |
| :-- | :-- | :-- |
| Ordner umbenennen (z. B. `userdata`) | Eine Zeile in `$global:Wv2DataDir` ändern | Minimal |
| Ordner woanders ablegen (z. B. `%LOCALAPPDATA%`) | Pfad in `$global:Wv2DataDir` ändern | Minimal |
| Mehrere Profile unterstützen | Parameter `-Profile` + `CreateCoreWebView2ControllerWithOptionsAsync` | Mittlerer Aufwand |
| In-Private-Modus | `IsInPrivateModeEnabled = $true` im Profil | Gering |

Alle drei Erweiterungen bauen direkt auf der bestehenden Architektur von PowerEdge auf — die Variable `$global:Wv2DataDir` und die explizite Environment-Erstellung, die in v1.00.02 eingeführt wurde, sind genau dafür die notwendige Grundlage.

---
<!--
<i>Bitte erstelle mir eine umfassende, ausführliche und detaillierte Dokumentation mit dem Titel "PowerEdge WebView2 - Handbook". Deine Dokumentation sollte auf folgende Fragen eingehen (immer unter Berücksichtigung dass wir hier explizit über WebView2 im PowerEdge kontext reden):

- Wo speichert PowerEdge Laufzeitdaten/Browserdaten?
- Welche Daten werden in so einem Browserprofil gespeichert?
- Kann PowerEdge mehrere Broser-Profile anlegen/verwalten?
- Welche UseCases gibt es für unterschiedliche Browser-Profile?
- Kann PowerEdge auch einen In-Private Modus?
- Welche Auswirkungen hätte ein In-Private Modus für den Betrieb von PowerEdge?

Es wäre toll, wenn Du diese Fragen so ausführlich wie möglich beantworten könntest und die Dokumentation als Markdown Datei erstellen könntest. Solltest Du noch Themen haben, die zu meinen Fragen passen würden, dann kannst Du diese sehr gerne zusätzlich in die Dokumentation mit aufnehmen.

Vielen lieben Dank für deine großartige Hilfe und tolle Unterstützung bei diesem Projekt

<b>Answer skipped.</b>

</i>
-->
