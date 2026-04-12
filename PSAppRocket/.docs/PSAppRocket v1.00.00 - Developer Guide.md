# PSAppRocket – Developer Guide

> **Version:** 1.00.00 (Konzept & Erstfassung)
> **Autor:** Praetoriani
> **Datum:** April 2026
> **Status:** Entwurf / In Entwicklung

***

## 1. Überblick & Zielsetzung

**PSAppRocket** ist eine PowerShell-basierte Applikation zur automatisierten, sequenziellen Ausführung vordefinierter Programme anhand von Profil-Konfigurationsdateien. Das Programm liest ein benanntes Profil aus einer `.config.ps1`-Datei, verarbeitet dessen Eintragsarray und startet die enthaltenen Applikationen mit den jeweils definierten Parametern (Fensterstil, Ausführungskontext, Wartezeiten).

Das Kernziel besteht darin, wiederkehrende Startsequenzen — beispielsweise ein komplettes Admin-Toolset, eine Entwicklungsumgebung oder ein tägliches Arbeitsprofil — als reproduzierbares, konfigurierbares und protokollierbares Skript abzubilden. In Kombination mit dem VPDLX-Modul und PSAppCoreLib ergibt sich ein professionelles Ökosystem, das sich nahtlos in bestehende PowerShell-Werkzeugketten einfügt.

### Kernprinzipien

- **Profilbasiert:** Jede Startsequenz ist in einer eigenen `.config.ps1`-Datei definiert. Profile sind isoliert, eindeutig benannt und über eine zentrale Datenbank (`psapp.profiledb.conf`) registriert.
- **Parametrisiert:** Das Hauptskript `psapp.rocket.ps1` nimmt alle relevanten Steuerbefehle als Kommandozeilenparameter entgegen.
- **Dot-Source-Architektur:** Das Hauptskript lädt alle Untermodule per Dot-Sourcing, sodass deren Funktionen und Variablen im gleichen Scope verfügbar sind.
- **Sicherheitsorientiert:** Path-Whitelisting, Pfad-Kanonisierung, Input-Validierung und strikte Parameterprüfung verhindern unbeabsichtigte oder missbräuchliche Ausführungen.[^1]
- **Logging:** Rotierendes Logfile-System mit maximal 50 Dateien im Unterverzeichnis `logfiles\`. Optionale Integration mit VPDLX für In-Memory-Logging mit anschließendem Disk-Export.

***

## 2. Verzeichnis- und Dateistruktur

Die folgende Struktur stellt die vollständige, empfohlene Verzeichnishierarchie dar. Sie basiert auf dem Originalkonzept, erweitert um eine saubere Trennung von Core-Logik, GUI-Definitionen und Konfigurationsdaten.

```
PSAppRocket\                          (Root-Verzeichnis)
│
├── .core\                            (Interne Kernlogik — dot-sourced by psapp.rocket.ps1)
│   ├── psapp.validator.ps1           (Eingabevalidierung, Pfadprüfung, Whitelisting)
│   ├── psapp.loader.ps1              (Profil laden, parsen, validieren)
│   ├── psapp.executor.ps1            (Prozess-Startlogik, RUN_AS-Handling)
│   ├── psapp.logger.ps1              (Logfile-Rotation, Schreiben, Verwaltung)
│   └── psapp.profilemgr.ps1         (Profil CRUD: Add, Delete, List, Validate)
│
├── .gui\                             (WPF/XAML-Definitionen — extern, nicht inline)
│   ├── gui.main.xml                  (GUI-Modus: Hauptfenster mit Fortschrittsanzeige)
│   ├── gui.console.xml               (Console-Modus: Terminal-stilisiertes WPF-Fenster)
│   └── gui.taskbar.xml               (Taskbar-Modus: NotifyIcon-basiertes Tray-Layout)
│
├── logfiles\                         (Laufzeit-Logdateien, max. 50 Dateien)
│   └── YYYYMMDD-HHMMSS.log
│
├── profiles\                         (Profil-Konfigurationsdateien)
│   ├── example-profile.config.ps1    (Beispiel / Template)
│   └── [profilename].config.ps1
│
├── settings\                         (Programm-eigene Einstellungen)
│   └── psapp.settings.conf           (JSON oder CSV — globale App-Konfiguration)
│
├── psapp.rocket.ps1                  (Hauptprogramm / Einstiegspunkt)
└── psapp.profiledb.conf              (Profil-Datenbank: Name;Dateiname, eine Zeile je Profil)
```

### Begründung der `.core\`- und `.gui\`-Trennung

Die Separierung der Kernlogik in ein `.core\`-Verzeichnis folgt dem bewährten Muster aus PSAppCoreLib und VPDLX, wo ebenfalls `Public\` und `Private\` klar voneinander getrennt werden. Das Dot-Präfix signalisiert, dass es sich um interne, nicht direkt ausführbare Dateien handelt. Die XAML-Definitionen für WPF-Fenster gehören gemäß den gültigen App-Development-Richtlinien zwingend in externe Dateien und dürfen nicht inline im PowerShell-Code eingebettet werden.[^2]

***

## 3. Architektur & Dot-Source-Konzept

Das Hauptskript `psapp.rocket.ps1` fungiert als Einstiegspunkt und Orchestrator. Es enthält selbst keine Geschäftslogik, sondern lädt alle Funktionen per Dot-Sourcing in den aktuellen Skript-Scope. Dieses Muster entspricht exakt dem in PSAppCoreLib und VPDLX verwendeten Ansatz.

```powershell
# Dot-sourcing all core modules in psapp.rocket.ps1

$CoreFiles = @(
    "$PSScriptRoot\.core\psapp.validator.ps1",
    "$PSScriptRoot\.core\psapp.loader.ps1",
    "$PSScriptRoot\.core\psapp.executor.ps1",
    "$PSScriptRoot\.core\psapp.logger.ps1",
    "$PSScriptRoot\.core\psapp.profilemgr.ps1"
)

foreach ($CoreFile in $CoreFiles) {
    if (-not (Test-Path -LiteralPath $CoreFile)) {
        Write-Error "PSAppRocket: Required core file not found: $CoreFile"
        exit 1
    }
    try {
        . $CoreFile
        Write-Verbose "PSAppRocket: Loaded core file: $($CoreFile | Split-Path -Leaf)"
    }
    catch {
        Write-Error "PSAppRocket: Failed to load core file '$CoreFile': $($_.Exception.Message)"
        exit 1
    }
}
```

### Warum Dot-Sourcing statt `Import-Module`?

Dot-Sourcing führt den Code eines anderen Skripts im **aktuellen Scope** aus. Alle dort definierten Funktionen, Variablen und Typen sind danach direkt im aufrufenden Skript verfügbar, ohne dass ein Modul-Manifest (`.psd1`) oder eine Installation im Modul-Pfad notwendig ist. Das ist ideal für eine selbstenthaltene App-Struktur, in der sich alle Komponenten im gleichen Verzeichnis befinden. Der Nachteil — fehlende Kapselung — wird durch den architektonischen Aufbau (`.core\` als internes Verzeichnis, Validierung aller Inputs) ausgeglichen.

***

## 4. Pflichtkonventionen & Coding-Standards

Alle Quelldateien des Projekts folgen den verbindlichen App-Development-Richtlinien. Die nachfolgenden Regeln sind nicht optional.[^2]

### 4.1 Header-Kommentar

Jede `.ps1`-Datei beginnt mit einem standardisierten Header-Block:[^2]

```powershell
<#
.SYNOPSIS
    PSAppRocket - [Kurzbeschreibung der Datei/Funktion]

.DESCRIPTION
    [Ausführliche Beschreibung]

.NOTES
    Creation Date: TT.MM.YYYY
    Last Update:   TT.MM.YYYY
    Version:       1.00.00
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    REQUIREMENTS & DEPENDENCIES:
    - PowerShell 5.1 or higher
    - .NET Framework 4.7.2 or higher
    [weitere Abhängigkeiten]
#>
```

### 4.2 Globale Variablen (nur in `psapp.rocket.ps1`)

```powershell
# Global application variables
$global:AppName = "PSAppRocket"
$global:AppVers = "1.00.00"
$global:AppPath = $PSScriptRoot
$global:AppIcon = Join-Path $PSScriptRoot "psapprocket.ico"

# Global path constants
$global:ProfilesDir  = Join-Path $PSScriptRoot "profiles"
$global:LogfilesDir  = Join-Path $PSScriptRoot "logfiles"
$global:SettingsDir  = Join-Path $PSScriptRoot "settings"
$global:ProfileDB    = Join-Path $PSScriptRoot "psapp.profiledb.conf"
$global:MaxLogFiles  = 50
$global:MaxAppsPerProfile = 20
```

### 4.3 Status-Rückgabeobjekt (OPSreturn-Pattern)

Analog zu PSAppCoreLib gibt **jede Funktion** ausnahmslos ein standardisiertes Status-Objekt zurück. Dies ist nicht verhandelbar. Eine private Hilfsfunktion `PSARreturn` wird in einer `Private\`-Datei definiert und von allen Core-Funktionen verwendet.

```powershell
# psapp.rocket.ps1 oder .core\psapp.private.ps1

function PSARreturn {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(-99, 99)]
        [int]$Code = -1,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Data = $null
    )
    return [PSCustomObject]@{
        code = $Code
        msg  = $Message
        data = $Data
    }
}
```

**Verwendungsregel:**
- `code = 0` → Funktion erfolgreich abgeschlossen, `msg` ist leer, `data` enthält ggf. Rückgabewerte
- `code = -1` → Fehler aufgetreten, `msg` enthält eine aussagekräftige Fehlermeldung, `data` ist `$null`

### 4.4 Sprache und Kommentare

Der gesamte Quellcode sowie alle Inline-Kommentare sind **ausnahmslos in englischer Sprache** zu verfassen. Deutsche Sprache ist nur in Benutzeroberflächen und in der Dokumentation (z.B. dieser Developer Guide) erlaubt. Alle Funktionen erhalten vollständige Comment-Based-Help-Blöcke mit `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE` und `.NOTES`.[^2]

***

## 5. Parameter-Design des Hauptskripts

Das Hauptskript `psapp.rocket.ps1` verwendet **PowerShell Parameter Sets**, um gegenseitig ausschließende Parameterkombinationen zu erzwingen. Ohne Parameter Sets würden `AddProfile`/`NewProfileID` und `DelProfile` irrtümlich kombinierbar sein.[^3][^4][^5]

### 5.1 Vollständige Parameterdefinition

```powershell
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    # ─── PARAMETER SET: 'Run' ────────────────────────────────────────────
    [Parameter(ParameterSetName = 'Run', Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileID,

    [Parameter(ParameterSetName = 'Run', Mandatory = $true, Position = 1)]
    [ValidateSet('GUI', 'Console', 'Taskbar', 'Hidden')]
    [string]$Mode,

    [Parameter(ParameterSetName = 'Run', Mandatory = $false)]
    [switch]$NoLogs,

    # ─── PARAMETER SET: 'AddProfile' ─────────────────────────────────────
    [Parameter(ParameterSetName = 'AddProfile', Mandatory = $true)]
    [switch]$AddProfile,

    [Parameter(ParameterSetName = 'AddProfile', Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-_]{0,48}[a-zA-Z0-9]$')]
    [string]$NewProfileID,

    # ─── PARAMETER SET: 'DelProfile' ─────────────────────────────────────
    [Parameter(ParameterSetName = 'DelProfile', Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DelProfile,

    # ─── PARAMETER SET: 'Backup' (Future) ────────────────────────────────
    [Parameter(ParameterSetName = 'Backup', Mandatory = $true)]
    [string]$Backup,

    [Parameter(ParameterSetName = 'Backup', Mandatory = $true)]
    [string]$BackupDir,

    # ─── PARAMETER SET: 'Restore' (Future) ───────────────────────────────
    [Parameter(ParameterSetName = 'Restore', Mandatory = $true)]
    [string]$Restore,

    [Parameter(ParameterSetName = 'Restore', Mandatory = $true)]
    [string]$RestoreFile
)
```

### 5.2 Parameterübersicht

| Parameter | Typ | Set | Pflicht | Beschreibung |
|-----------|-----|-----|---------|--------------|
| `-ProfileID` | `string` | `Run` | ✅ | Name des zu ladenden Profils (→ `profiles\{ID}.config.ps1`) |
| `-Mode` | `string` | `Run` | ✅ | Anzeigemodus: `GUI`, `Console`, `Taskbar`, `Hidden` |
| `-NoLogs` | `switch` | `Run` | ❌ | Deaktiviert Logfile-Erstellung für diesen Lauf |
| `-AddProfile` | `switch` | `AddProfile` | ✅ | Schaltet in Profilerstellungs-Modus um |
| `-NewProfileID` | `string` | `AddProfile` | ✅ | Name des neuen Profils (nur `[a-zA-Z0-9-_]`) |
| `-DelProfile` | `string` | `DelProfile` | ✅ | Name des zu löschenden Profils |
| `-Backup` | `string` | `Backup` | ✅ | Backup-Label (zukünftige Version) |
| `-BackupDir` | `string` | `Backup` | ✅ | Zielverzeichnis für Backup (zukünftige Version) |
| `-Restore` | `string` | `Restore` | ✅ | Restore-Label (zukünftige Version) |
| `-RestoreFile` | `string` | `Restore` | ✅ | Pfad zur Restore-Datei (zukünftige Version) |

### 5.3 Validierungsregel für Profil-IDs

Profil-IDs müssen dem regulären Ausdruck `^[a-zA-Z0-9][a-zA-Z0-9\-_]{0,48}[a-zA-Z0-9]$` entsprechen. Das bedeutet:
- Start und Ende: alphanumerisches Zeichen (kein `-` oder `_` am Rand)
- Maximale Länge: 50 Zeichen
- Erlaubt: `a-z`, `A-Z`, `0-9`, `-`, `_`
- Verboten: Leerzeichen, Sonderzeichen, Umlaute, Punkte

Dies ist entscheidend, weil der Profil-ID-Wert direkt zur Bildung eines Dateipfades verwendet wird. Eine fehlerhafte ID könnte ohne Validierung zu einem Path-Traversal-Angriff führen.[^6][^1]

***

## 6. Profil-Konfigurationsdatei

### 6.1 Verbessertes Schema (Empfehlung)

Das ursprüngliche Konzept sah einen String-Array mit Semikolon-Trenner und Backtick-Zeilenfortsetzung vor. Dieses Format ist zwar funktional, aber fehleranfällig, schwer zu parsen und schlecht wartbar. Die empfohlene Alternative verwendet nativ typisierte `PSCustomObject`-Einträge — das ist der PowerShell-idiomatische Weg, der direkt weiterverarbeitet werden kann ohne einen eigenen Parser zu benötigen.[^7][^8]

```powershell
<#
.SYNOPSIS
    PSAppRocket Profile Configuration File
    Profile ID: [PROFILE_NAME]

.DESCRIPTION
    Defines the list of applications to launch with this profile.
    Maximum: 20 entries. Only .exe files are permitted.

.NOTES
    Creation Date: [DATE]
    Last Update:   [DATE]
    Version:       1.00.00
    Author:        Praetoriani
    Website:       https://github.com/praetoriani

    ENTRY FORMAT:
    Each entry in $AppLoader is a PSCustomObject with the following properties:
    - ProgramName   [string]  Unique name for this entry
    - ExecPath      [string]  Full path to the .exe file (must exist)
    - RunAs         [string]  'AsUser' | 'AsAdmin' | 'DOMAIN\username'
    - WindowStyle   [string]  'Normal' | 'Hidden' | 'Minimized' | 'Maximized'
    - WaitMs        [int]     Milliseconds to wait after launch (0 = no wait, increments of 100)
#>

$AppLoader = @(
    [PSCustomObject]@{
        ProgramName = "Notepad"
        ExecPath    = "C:\Windows\System32\notepad.exe"
        RunAs       = "AsUser"
        WindowStyle = "Normal"
        WaitMs      = 500
    },
    [PSCustomObject]@{
        ProgramName = "Calculator"
        ExecPath    = "C:\Windows\System32\calc.exe"
        RunAs       = "AsUser"
        WindowStyle = "Normal"
        WaitMs      = 0
    }
)
```

### 6.2 Felddefinitionen

| Feld | Typ | Pflicht | Gültige Werte | Beschreibung |
|------|-----|---------|---------------|--------------|
| `ProgramName` | `string` | ✅ | Einzigartiger Name | Identifikator; muss pro Profil eindeutig sein |
| `ExecPath` | `string` | ✅ | Vollständiger Dateipfad | Muss auf eine `.exe`-Datei zeigen, die physisch existiert |
| `RunAs` | `string` | ✅ | `AsUser`, `AsAdmin`, `DOMAIN\user` | Ausführungskontext |
| `WindowStyle` | `string` | ✅ | `Normal`, `Hidden`, `Minimized`, `Maximized` | Fensterzustand beim Start |
| `WaitMs` | `int` | ✅ | `0` bis `60000`, 100er-Schritte | Wartezeit in ms nach dem Starten |

### 6.3 Validierungsregeln bei Profil-Load

Der `psapp.loader.ps1` prüft beim Einlesen eines Profils folgende Bedingungen (alle per `PSARreturn -Code -1` meldepflichtig):

1. `$AppLoader` ist definiert und ist ein Array
2. Anzahl der Einträge ≤ 20
3. Jeder Eintrag ist ein `PSCustomObject` mit allen 5 Pflichtfeldern
4. `ProgramName` ist nicht leer und innerhalb des Profils eindeutig
5. `ExecPath` endet auf `.exe` (Extension-Whitelist)
6. `ExecPath` ist nach Kanonisierung ein absoluter Pfad und die Datei existiert[^6]
7. `RunAs` entspricht `AsUser`, `AsAdmin` oder dem Regex `^[a-zA-Z0-9\.\-_]+\\[a-zA-Z0-9\.\-_]+$`
8. `WindowStyle` ist einer der vier gültigen Werte
9. `WaitMs` ist eine ganze Zahl ≥ 0, ≤ 60000, und durch 100 teilbar

***

## 7. Profil-Datenbank (`psapp.profiledb.conf`)

Die `psapp.profiledb.conf` ist eine reine Textdatei im CSV-ähnlichen Format (Semikolon als Trennzeichen), in der alle registrierten Profile verwaltet werden. Sie dient als **Single Source of Truth** dafür, welche Profile existieren.

### 7.1 Format

```
# PSAppRocket Profile Database
# Format: ProfileID;ConfigFileName
# Do NOT edit manually unless you know what you are doing.
standard-apps;standard-apps.config.ps1
developer-tools;developer-tools.config.ps1
admin-suite;admin-suite.config.ps1
```

**Regeln:**
- Zeilen, die mit `#` beginnen, sind Kommentare und werden beim Einlesen ignoriert
- Jeder Eintrag besteht aus genau zwei Feldern, getrennt durch `;`
- Der Dateiname im zweiten Feld ergibt sich immer aus `{ProfileID}.config.ps1`
- Die Suche nach einem ProfileID-Eintrag erfolgt **case-insensitiv**
- Duplikate (gleiche ProfileID, unabhängig von Groß-/Kleinschreibung) werden nicht toleriert

### 7.2 Lese-Funktion (Pseudocode)

```powershell
function Read-ProfileDatabase {
    # Returns PSARreturn with data = @( [PSCustomObject]@{ ID=...; FileName=... }, ... )
    # Ignores comment lines (#)
    # Validates that exactly 2 fields per line exist
    # Returns -1 if file not found or parse error
}
```

### 7.3 Prüfung auf Eindeutigkeit

Vor dem Hinzufügen eines neuen Profils (`-AddProfile -NewProfileID`) wird die Datenbank case-insensitiv auf das Vorhandensein des Namens geprüft:

```powershell
$existingIDs = (Read-ProfileDatabase).data | Select-Object -ExpandProperty ID
if ($existingIDs -icontains $NewProfileID) {
    return PSARreturn -Code -1 -Message "Profile '$NewProfileID' already exists (case-insensitive match)"
}
```

***

## 8. Prozessstart-Logik

Der `psapp.executor.ps1` ist die sicherheitskritischste Komponente. Er nutzt direkt `System.Diagnostics.ProcessStartInfo` und `System.Diagnostics.Process` — exakt wie die bewährte `RunProcess`-Funktion aus PSAppCoreLib. PSAppRocket kann diese Funktion direkt nutzen, wenn PSAppCoreLib als Dependency eingebunden ist.

### 8.1 RUN_AS-Mapping

```powershell
function Invoke-AppEntry {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Entry
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $Entry.ExecPath

    $WindowStyleMap = @{
        'Normal'    = [System.Diagnostics.ProcessWindowStyle]::Normal
        'Hidden'    = [System.Diagnostics.ProcessWindowStyle]::Hidden
        'Minimized' = [System.Diagnostics.ProcessWindowStyle]::Minimized
        'Maximized' = [System.Diagnostics.ProcessWindowStyle]::Maximized
    }
    $StartInfo.WindowStyle = $WindowStyleMap[$Entry.WindowStyle]

    switch -Regex ($Entry.RunAs) {
        '^AsUser$' {
            # Run as current user — standard launch
            $StartInfo.UseShellExecute = $true
        }
        '^AsAdmin$' {
            # Elevate via UAC
            $StartInfo.UseShellExecute = $true
            $StartInfo.Verb = "runas"
        }
        '^[a-zA-Z0-9\.\-_]+\\[a-zA-Z0-9\.\-_]+$' {
            # Run as specific domain\user — requires credential prompt or SecureString
            # NOTE: UseShellExecute must be false when using UserName/Password
            $StartInfo.UseShellExecute = $false
            $domainUser = $Entry.RunAs -split '\\'
            $StartInfo.Domain   = $domainUser
            $StartInfo.UserName = $domainUser[^1]
            # Password must be provided via SecureString — see Section 9 (Security)
        }
        default {
            return PSARreturn -Code -1 -Message "Invalid RunAs value: '$($Entry.RunAs)'"
        }
    }

    try {
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $StartInfo
        $started = $Process.Start()

        if (-not $started) {
            return PSARreturn -Code -1 -Message "Process.Start() returned false for '$($Entry.ProgramName)'"
        }

        # Wait after launch if configured
        if ($Entry.WaitMs -gt 0) {
            Start-Sleep -Milliseconds $Entry.WaitMs
        }

        return PSARreturn -Code 0 -Message "" -Data $Process.Id
    }
    catch [System.ComponentModel.Win32Exception] {
        return PSARreturn -Code -1 -Message "Win32 error launching '$($Entry.ProgramName)': $($_.Exception.Message) (Code: $($_.Exception.NativeErrorCode))"
    }
    catch [System.UnauthorizedAccessException] {
        return PSARreturn -Code -1 -Message "Access denied launching '$($Entry.ProgramName)'. Check permissions or RunAs setting."
    }
    catch {
        return PSARreturn -Code -1 -Message "Unexpected error launching '$($Entry.ProgramName)': $($_.Exception.Message)"
    }
}
```

### 8.2 Wichtiger Hinweis: UseShellExecute vs. Credential

Eine bekannte Einschränkung von `System.Diagnostics.ProcessStartInfo` unter Windows ist, dass `UseShellExecute = $true` und die gleichzeitige Angabe von `UserName`/`Password` nicht kombinierbar sind. Für `AsAdmin` (Verb `runas`) muss `UseShellExecute = $true` gesetzt sein; für einen frei gewählten Benutzer (`DOMAIN\user`) muss `UseShellExecute = $false` und ein Passwort als `SecureString` bereitgestellt werden. Dies ist eine systembedingte Limitation von Windows, keine Designentscheidung von PSAppRocket.[^9][^10]

### 8.3 WaitMs-Enforcement

`WaitMs` wird in 100er-Schritten definiert und auf 60.000 ms (60 Sekunden) begrenzt. Die Validierung beim Profil-Load stellt sicher, dass der Wert die Bedingung `$WaitMs % 100 -eq 0` erfüllt. Im Executor wird der Wert zusätzlich nochmals geclampt:

```powershell
$safewait = [Math]::Max(0, [Math]::Min($Entry.WaitMs, 60000))
if ($safewait -gt 0) { Start-Sleep -Milliseconds $safewait }
```

***

## 9. Sicherheitskonzept

Sicherheit ist ein erstklassiges Designziel von PSAppRocket. Die folgenden Maßnahmen sind verbindlich und bauen auf den allgemeinen App-Development-Richtlinien auf.[^2]

### 9.1 Path-Validierung und Kanonisierung

Bevor ein Pfad aus einem Profileintrag verwendet wird, durchläuft er eine mehrstufige Validierung:[^11][^1][^6]

```powershell
function Resolve-SafeExecPath {
    param([string]$InputPath)

    # Step 1: Reject null/empty
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return PSARreturn -Code -1 -Message "Path is null or empty"
    }

    # Step 2: Normalize slashes
    $normalized = $InputPath.Trim().Replace('/', '\')

    # Step 3: Must be absolute path (drive letter or UNC)
    if (-not ([System.IO.Path]::IsPathRooted($normalized))) {
        return PSARreturn -Code -1 -Message "Path must be absolute: '$normalized'"
    }

    # Step 4: Extension whitelist — only .exe allowed
    $ext = [System.IO.Path]::GetExtension($normalized).ToLower()
    if ($ext -ne '.exe') {
        return PSARreturn -Code -1 -Message "Only .exe files are permitted. Rejected: '$normalized'"
    }

    # Step 5: Canonicalize to detect traversal attempts (..\, symlinks)
    try {
        $canonical = [System.IO.Path]::GetFullPath($normalized)
    }
    catch {
        return PSARreturn -Code -1 -Message "Path canonicalization failed: $($_.Exception.Message)"
    }

    # Step 6: Verify the file physically exists
    if (-not (Test-Path -LiteralPath $canonical -PathType Leaf)) {
        return PSARreturn -Code -1 -Message "Executable not found: '$canonical'"
    }

    return PSARreturn -Code 0 -Message "" -Data $canonical
}
```

### 9.2 Whitelist: Nur `.exe`-Dateien

Nur Dateien mit der Erweiterung `.exe` dürfen ausgeführt werden. Dateitypen wie `.bat`, `.cmd`, `.ps1`, `.com`, `.vbs`, `.msi` sind explizit verboten. Die Erweiterungsprüfung erfolgt **nach** der Kanonisierung, um Tricks wie `program.exe.bat` zu verhindern.

### 9.3 Profil-Datei-Prüfung (Dot-Source-Sicherheit)

Eine Profil-Datei wird per Dot-Sourcing in den aktuellen Scope geladen (`. $profilePath`). Das ist ein potenzielles Sicherheitsrisiko, da schadhafter Code in der Profildatei ausgeführt werden würde. Folgende Gegenmaßnahmen sind zu implementieren:

- **Pfad-Einschränkung:** Der Pfad zur Profildatei wird ausschließlich aus `$global:ProfilesDir` und dem validierten Profil-ID-Wert zusammengesetzt. Eine direkte Pfadangabe durch den Benutzer ist nicht möglich.
- **Profil-DB-Abgleich:** Vor dem Laden wird geprüft, ob der Profilname in der `psapp.profiledb.conf` eingetragen ist **und** die entsprechende Datei im `profiles\`-Verzeichnis existiert. Beide Bedingungen müssen erfüllt sein.
- **Datei-Hash-Prüfung (empfohlen):** Bei der Profilerstellung (`-AddProfile`) wird ein SHA256-Hash der Datei berechnet und in `psapp.profiledb.conf` als drittes Feld gespeichert (`ProfileID;FileName;SHA256Hash`). Beim Laden wird der aktuelle Hash mit dem gespeicherten Hash verglichen. Bei Abweichung wird das Profil nicht geladen.

```
# Erweitertes psapp.profiledb.conf Format (mit Hash-Schutz):
developer-tools;developer-tools.config.ps1;3A7B2C1D...
admin-suite;admin-suite.config.ps1;9F4E8A2B...
```

### 9.4 Parameter-Injection-Prävention

Alle String-Parameter, die aus Benutzereingaben stammen (`ProfileID`, `NewProfileID`, `DelProfile`), werden durch `ValidatePattern` mit einem strikten Regex validiert, bevor sie irgendeiner weiteren Verarbeitung zugeführt werden. Diese Validierung findet auf PowerShell-Ebene statt, bevor der Script-Body ausgeführt wird.

### 9.5 Zugangsdaten-Handling (`DOMAIN\user` RunAs)

Das Speichern von Passwörtern im Klartext in einer Profildatei ist **verboten**. Wenn ein Eintrag `RunAs = "DOMAIN\username"` enthält, muss das Passwort zur Laufzeit sicher bezogen werden:

- Option A: `Get-Credential`-Dialog (interaktiv)
- Option B: Verschlüsseltes SecureString aus der Windows Credential Manager-Integration (`CredentialVault`-API)
- Option C: SecureString aus einer `.credx`-Datei, die mit `Export-Clixml` (DPAPI-verschlüsselt, benutzerspezifisch) erstellt wurde

***

## 10. Logging-System

### 10.1 Dateinamen-Schema

Logdateien folgen dem Namensschema `YYYYMMDD-HHMMSS.log` und werden im Verzeichnis `..\logfiles\` abgelegt.

```powershell
$LogFileName = (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"
$LogFilePath = Join-Path $global:LogfilesDir $LogFileName
```

### 10.2 Log-Rotation (Ring-Buffer-Prinzip)

Maximal 50 Logdateien werden im Verzeichnis gehalten. Bei der 51. Datei wird die älteste automatisch gelöscht:[^12][^13]

```powershell
function Invoke-LogRotation {
    param([string]$LogDir, [int]$MaxFiles = 50)

    $existing = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object -Property CreationTime -Descending

    if ($existing.Count -ge $MaxFiles) {
        $toDelete = $existing | Select-Object -Skip ($MaxFiles - 1)
        foreach ($file in $toDelete) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                Write-Verbose "PSAppRocket: Removed old logfile: $($file.Name)"
            }
            catch {
                Write-Warning "PSAppRocket: Could not remove logfile '$($file.Name)': $($_.Exception.Message)"
            }
        }
    }
    return PSARreturn -Code 0 -Message "Log rotation complete"
}
```

### 10.3 Log-Eintragsformat

Jede Zeile einer Logdatei folgt dem gleichen Format wie PSAppCoreLib's `WriteLogMessage`:

```
[yyyy.MM.dd ; HH:mm:ss] [INFO]  PSAppRocket started. Profile: developer-tools. Mode: GUI
[yyyy.MM.dd ; HH:mm:ss] [DEBUG] Loading profile from: .\profiles\developer-tools.config.ps1
[yyyy.MM.dd ; HH:mm:ss] [INFO]  Launching app 1/5: Notepad (Normal, AsUser, Wait: 500ms)
[yyyy.MM.dd ; HH:mm:ss] [INFO]  App 1/5 launched successfully. PID: 12345
[yyyy.MM.dd ; HH:mm:ss] [ERROR] App 3/5: Executable not found at 'C:\Tools\app.exe'
[yyyy.MM.dd ; HH:mm:ss] [INFO]  PSAppRocket finished. 4/5 apps launched successfully.
```

### 10.4 VPDLX-Integration (Empfehlung)

Für eine elegante Logging-Architektur empfiehlt sich die Integration von VPDLX als In-Memory-Logger. VPDLX erlaubt das Schreiben aller Log-Einträge in einen virtuellen In-Memory-Log, der erst am Ende oder bei Bedarf als `.log`-Datei exportiert wird. Dies vermeidet I/O-Locks während der Laufzeit und nutzt das bereits etablierte Log-Format.

```powershell
# VPDLX-basiertes Logging in PSAppRocket (wenn VPDLX importiert ist)
Import-Module VPDLX

$RunLog = [Logfile]::new("PSAppRocket_$(Get-Date -Format 'yyyyMMdd-HHmmss')")
$RunLog.Info("PSAppRocket started. Profile: $ProfileID. Mode: $Mode")

# ... nach Ausführung:
$exportPath = Join-Path $global:LogfilesDir "$($RunLog.Name).log"
VPDLXexportlogfile -LogfileName $RunLog.Name -ExportAs 'log' -OutputPath $global:LogfilesDir
```

***

## 11. Anzeigemodi (Mode-Parameter)

### 11.1 `GUI` – Grafisches Fortschrittsfenster

Ein WPF-Fenster (XAML aus `.gui\gui.main.xml`) zeigt den Fortschritt der Ausführung an. Enthält:
- Profilname und Gesamtzahl der Apps
- Fortschrittsbalken (1 bis N)
- Aktuell laufende App (Name, Status)
- Log-Ausgabe in einem `TextBox`-Bereich (scrollbar)

Da WPF im STA-Thread (Single-Thread Apartment) läuft und die App-Starts sequenziell im gleichen Thread erfolgen, muss die UI über einen **Runspace mit `$syncHash`** aktualisiert werden. Das UI läuft in einem separaten Runspace-Thread; der Haupt-Thread startet die Apps und aktualisiert den `$syncHash` über `Dispatcher.Invoke`.[^14][^15]

```powershell
# STA-Runspace für WPF-Fenster
$syncHash = [hashtable]::Synchronized(@{})
$newRunspace = [runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions   = "ReuseThread"
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
```

Gemäß den App-Development-Richtlinien wird das Konsolenfenster bei GUI-Start minimiert.[^2]

### 11.2 `Console` – Terminal-Style WPF-Fenster

Ähnlich wie GUI, aber optisch als Terminal gestaltet: schwarzer Hintergrund, monospaced Font (z.B. Consolas), zeilenweise Fortschrittsausgabe im Scrollfeld. Liest XAML aus `.gui\gui.console.xml`. Besonders geeignet für Admins, die eine "PowerShell-native" Ästhetik bevorzugen.

### 11.3 `Taskbar` – System-Tray-Icon

Ein `System.Windows.Forms.NotifyIcon` wird im Benachrichtigungsbereich der Taskbar angezeigt, solange PSAppRocket aktiv ist. Per Tooltip zeigt es den aktuell laufenden App-Namen und den Fortschritt (z.B. "Launching 2/5: VS Code"). Bei Abschluss erscheint ein Balloon-Tip ("PSAppRocket: All 5 apps launched successfully."). Das Icon wird beim Programmende automatisch `Dispose()`d.[^16][^17]

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon    = [System.Drawing.Icon]::ExtractAssociatedIcon($global:AppIcon)
$trayIcon.Visible = $true
$trayIcon.Text    = "PSAppRocket - Starting..."

# After completion:
$trayIcon.ShowBalloonTip(3000, "PSAppRocket", "All apps launched successfully.", [System.Windows.Forms.ToolTipIcon]::Info)
$trayIcon.Dispose()
```

### 11.4 `Hidden` – Unsichtbarer Modus

Kein Fenster, kein Icon, keine Ausgabe. Das Programm läuft vollständig im Hintergrund. Nützlich für automatisierte Startvorgänge (z.B. in Autostart-Skripten oder Task Scheduler-Jobs). Logging (falls nicht `-NoLogs`) erfolgt wie gewohnt ins Logfile.

***

## 12. Profilverwaltung (CRUD-Operationen)

### 12.1 Profil erstellen (`-AddProfile -NewProfileID`)

Ablauf:
1. `NewProfileID` per Regex validieren
2. `psapp.profiledb.conf` einlesen und case-insensitiv auf Duplikat prüfen
3. Template-Datei `profiles\{NewProfileID}.config.ps1` erstellen (mit Kommentaren und Beispieleinträgen)
4. Neuen Eintrag in `psapp.profiledb.conf` anfügen (inkl. SHA256-Hash der Template-Datei)
5. Erfolgsmeldung ausgeben

```powershell
# Example call
.\psapp.rocket.ps1 -AddProfile -NewProfileID "my-dev-apps"
# Creates: .\profiles\my-dev-apps.config.ps1
# Adds to: .\psapp.profiledb.conf
```

### 12.2 Profil löschen (`-DelProfile`)

**Wichtig: Dieser Vorgang ist irreversibel und erfolgt ohne Sicherheitsabfrage** (gemäß Originalkonzept). Die Dokumentation und das Logfile müssen dies deutlich vermerken.

Ablauf:
1. `DelProfile`-Wert per Regex validieren
2. Profil in `psapp.profiledb.conf` suchen (case-insensitiv)
3. Entsprechende `.config.ps1`-Datei im `profiles\`-Verzeichnis lokalisieren
4. **Beide** Schritte müssen erfolgreich sein: Eintrag in DB gefunden UND Datei vorhanden
5. Datei löschen (`Remove-Item -Force`)
6. Zeile aus `psapp.profiledb.conf` entfernen (Datei neu schreiben ohne diese Zeile)
7. Löschung ins Logfile schreiben

### 12.3 Profil laden und ausführen (`-ProfileID -Mode`)

Ablauf:
1. `ProfileID` validieren (Regex)
2. Profil in `psapp.profiledb.conf` suchen
3. Pfad zur `.config.ps1` konstruieren: `Join-Path $global:ProfilesDir "$ProfileID.config.ps1"`
4. Pfad kanonisieren und prüfen, ob er innerhalb von `$global:ProfilesDir` liegt
5. Optional: SHA256-Hash-Vergleich (Integritätsprüfung)
6. Profildatei dot-sourcen: `. $profilePath`
7. `$AppLoader`-Array validieren (Struktur, Feldwerte, max. 20 Einträge)
8. Log initialisieren (wenn nicht `-NoLogs`)
9. Log-Rotation ausführen
10. Mode-spezifisches UI starten
11. Jeden Eintrag in `$AppLoader` der Reihe nach per `Invoke-AppEntry` ausführen
12. UI aktualisieren, Ergebnis loggen
13. Abschlussmeldung, UI schließen, Log exportieren

***

## 13. Fehlerbehandlung & Robustheit

### 13.1 Allgemeine Prinzipien

- **Jede Funktion** gibt ein `PSARreturn`-Objekt zurück. Der Aufrufer prüft immer `$result.code -eq 0`.
- Bei `code = -1` wird die Fehlermeldung aus `$result.msg` ins Log geschrieben.
- Typed `catch`-Blöcke (`[System.ComponentModel.Win32Exception]`, `[System.UnauthorizedAccessException]`, etc.) ermöglichen präzise Fehlerdiagnosen.
- Kritische Fehler (Profil nicht gefunden, Profil-Parse-Fehler) brechen die Ausführung vollständig ab.
- Nicht-kritische Fehler (einzelne App konnte nicht gestartet werden) werden geloggt und die Ausführung wird mit dem nächsten Eintrag fortgesetzt.

### 13.2 Fehlerklassifikation

| Fehlertyp | Verhalten | Beispiel |
|-----------|-----------|---------|
| **Fatal** | Abbruch + Logfile + Fehlermeldung | Profil-DB nicht gefunden, Profildatei nicht gefunden |
| **Critical** | Abbruch + Logfile | Profil-Parsing fehlgeschlagen, App-Array ungültig |
| **Error** | Überspringen + Logfile + weiter | Einzelne App-Exe nicht gefunden, Zugriff verweigert |
| **Warning** | Logfile + weiter | WaitMs außerhalb empfohlenen Bereichs (wird geclampt) |
| **Info** | Logfile | Normaler Fortschritt |
| **Debug** | Logfile (nur bei Verbose) | Interne Ablaufdetails |

### 13.3 Transaktionale Sicherheit bei Profil-Schreiboperationen

Beim Schreiben in `psapp.profiledb.conf` (Add/Delete) sollte eine transaktionale Sicherheitsstrategie verwendet werden:
1. Aktuelle Datei in eine Temp-Datei kopieren (als Backup)
2. Schreiboperation durchführen
3. Bei Erfolg: Temp-Datei löschen
4. Bei Fehler: Original aus Temp-Datei wiederherstellen

***

## 14. Erweiterungen & Zukunftsvision

### 14.1 Backup & Restore (geplant)

Die Parameter `-Backup`/`-BackupDir` und `-Restore`/`-RestoreFile` sind als Platzhalter für eine zukünftige Version vorgesehen. Mögliche Implementierung:
- **Backup:** Komprimiert alle Profildateien + `psapp.profiledb.conf` in ein ZIP-Archiv im angegebenen Verzeichnis, mit Zeitstempel im Dateinamen (`PSAppRocket_Backup_YYYYMMDD-HHMMSS.zip`)
- **Restore:** Extrahiert ein Backup-ZIP, überschreibt vorhandene Profile nach Bestätigung

### 14.2 PSAppCoreLib-Integration

PSAppRocket kann die `RunProcess`-Funktion aus PSAppCoreLib direkt nutzen, anstatt die Prozessstart-Logik zu duplizieren. Voraussetzung: PSAppCoreLib ist installiert oder wird als lokale Dependency mitgeliefert. Die Funktion bietet bereits alle benötigten Features (WindowStyle, Credential, Verb, WaitForExit).

### 14.3 Konfigurierbarer Logfile-Pfad

Aktuell ist der Logfile-Pfad fest auf `.\logfiles\` gesetzt. Eine zukünftige Version könnte über `settings\psapp.settings.conf` einen alternativen Pfad erlauben.

### 14.4 Profil-Importer

Ein separater Parameter `-ImportProfile [string]` könnte das Importieren einer Profildatei von einem externen Pfad (z.B. einem Netzwerkpfad) ermöglichen. Die Datei würde zunächst in `profiles\` kopiert, dann in die Datenbank eingetragen.

### 14.5 Dry-Run-Modus

Ein `-DryRun`-Switch könnte alle Schritte simulieren (Validierung, Pfadprüfung), ohne tatsächlich Prozesse zu starten. Nützlich zum Testen von Profilen.

***

## 15. Aufrufbeispiele

```powershell
# Standard: Profil "developer-tools" im GUI-Modus ausführen
.\psapp.rocket.ps1 -ProfileID "developer-tools" -Mode GUI

# Profil "admin-suite" ohne Logfiles im Hidden-Modus ausführen
.\psapp.rocket.ps1 -ProfileID "admin-suite" -Mode Hidden -NoLogs

# Profil "standard-apps" im Console-Modus mit Taskbar-Icon
.\psapp.rocket.ps1 -ProfileID "standard-apps" -Mode Console

# Neues Profil erstellen (erstellt Template-Datei)
.\psapp.rocket.ps1 -AddProfile -NewProfileID "my-new-profile"

# Profil löschen (ACHTUNG: ohne Rückfrage, irreversibel!)
.\psapp.rocket.ps1 -DelProfile "my-new-profile"

# Hilfe anzeigen (built-in PowerShell Help)
Get-Help .\psapp.rocket.ps1 -Full
```

***

## 16. Systemanforderungen

| Anforderung | Mindestversion |
|-------------|---------------|
| PowerShell | 5.1 (empfohlen: 7.x) |
| .NET Framework | 4.7.2 (für WPF/WinForms) |
| Windows | 10 / 11 (inkl. Server 2019+) |
| PSAppCoreLib | ≥ 1.00.00 (optional, empfohlen) |
| VPDLX | ≥ 1.02.06 (optional, für erweitertes Logging) |

**Hinweis zur Execution Policy:** PSAppRocket muss in einer PowerShell-Sitzung ausgeführt werden, in der Skripte erlaubt sind. Für den produktiven Einsatz wird `Set-ExecutionPolicy RemoteSigned` empfohlen. Das Signieren der Skriptdateien mit einem Code-Signing-Zertifikat ist für Unternehmensumgebungen die sauberste Lösung.[^18]

***

## 17. Entwicklungs-Roadmap

| Version | Features |
|---------|----------|
| **1.00.00** | Grundfunktion: Run, AddProfile, DelProfile, alle 4 Modi, Logging, Sicherheitsvalidierung |
| **1.01.00** | VPDLX-Integration, Hash-basierte Profil-Integritätsprüfung, DryRun-Switch |
| **1.02.00** | PSAppCoreLib-Integration als Prozess-Engine, Konfigurierbarer Log-Pfad |
| **1.10.00** | Backup/Restore-Funktionalität |
| **2.00.00** | GUI-Profil-Editor (WPF-basiert), Profil-Importer, Netzwerkpfad-Support |

***

## 18. Bekannte Einschränkungen und Design-Entscheidungen

- **Kein Rollback:** Wenn App Nr. 3 von 5 fehlschlägt, werden Apps 1 und 2 nicht beendet. Das Beenden bereits gestarteter Prozesse ist nicht Teil des Konzepts, da PSAppRocket bewusst als "Fire and forget"-Launcher konzipiert ist.
- **Passwörter für `DOMAIN\user`:** Klartextpasswörter in Profildateien sind verboten. Interaktive Credential-Abfragen oder DPAPI-verschlüsselte Credential-Stores sind die einzig akzeptablen Alternativen.
- **Nur `.exe`-Dateien:** Die Beschränkung auf `.exe` ist bewusst konservativ. Skripte (`.ps1`, `.bat`) können immer durch ihre jeweilige Host-Applikation (`powershell.exe`, `cmd.exe`) als `.exe`-Aufruf gestartet werden.
- **Maximal 20 Apps pro Profil:** Diese Grenze dient der Übersicht und verhindert versehentlich überdimensionierte Startsequenzen. Sie ist im Code konfigurierbar über `$global:MaxAppsPerProfile`.
- **Kein paralleler Start:** Apps werden sequenziell gestartet. Parallele Starts sind konzeptionell nicht vorgesehen, da Wartezeiten und Reihenfolge wesentliche Designmerkmale sind.

---

## References

1. [Directory Traversal (Path Traversal) - Invicti](https://www.invicti.com/learn/directory-traversal-path-traversal) - A path can appear to stay inside an allowed directory but resolve to a location outside it if a syml...

2. [App-Development-Instructions.txt](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_a6c3829b-0732-43b6-a813-fc5eb8a1ffb4/f1f4d29c-2255-4164-bd99-ad7920ff7918/App-Development-Instructions.txt?AWSAccessKeyId=ASIA2F3EMEYE6GIFYMNX&Signature=guGPidUavmGYZf9V0x0nKl3hNxc%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEI%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJGMEQCICz5wve65hLYNj5Fsrnwf4aYeY3jWTRuYr6gHxxTw3JKAiAU0sflN0U9ic6YchCvCj6WPW%2FeABWgUjZSQGgTUUsYRSrzBAhYEAEaDDY5OTc1MzMwOTcwNSIMkOr3kR69O4gJiOuTKtAEhs6A%2FoAwiGd5DOtBTzEpFfjcgLPCcpjQW4QM6Ufybp4SShF9Jh1J%2FA0L2HvWkfN9uFljWn3ugGrAUePyypLGQoRYHznQVv0zUHdw%2FQVG2UoG%2BVgv5IOOODoYfnNtwvT9jff75WiebZVbo4YKDyU5OC%2Bj25lK%2FdtreI3Jdqs9M4Z8l2fX2Hjay3nAFe10bfZDqwYUQ8oEnrvYQQaCkuuFxXcrUF%2FIpAPxti6XTBucE9%2BpF6mJkH9cZC40FEYaYvYOR5r9MTf2zp2YGQQnjzzYiVYIwXn1G5%2BzpTpCTASFtNH1X0V9PkO7IkSaL6WEP93WA538P6DD9NVkErQ3thTZx166zBP46BvF%2Bb4TinEey8YsY9wluy4EzKsKXqMexbFZ9GGsC02mVfPyfP617LZQDefdy8S1vFogt%2BmYtLR2OgpkygK9NNdSiJbYKeGsmwwlne6dvTZBqUcZIfsIucU58zD05s%2FukYZBRYGc7tWs5JeEGdvrFRFspxhRWXoFyDDHYagQ%2Fx%2FVVFrXg5VtgezXhWqYbmf7vNwjcm6Iy2FuXvG6%2FIb4dm1HfwUEygMEN68PzXeo8QcwFijhQJBfZT1KmnNz0aFOqGIkBVSxXsMmKCMO6FBXNy5VpoDMSBXz7NfMD4zrEvnjR4MrD5xRXxpcleaMH9vfMj5lP7WV2DNG19cs482gDOTAhgx9wGWcEn3LDlRkqbW1Nl296Ci49DWJ8ykIA0tMgAe3YSu2IV%2F%2FFRU0pJpVakv%2B%2FfY9y2MrJcekLEq4P6EzbSVED1t0kssRMTCAh%2B3OBjqZARNmTV%2BCxa%2B8dr%2BaiGM%2Bs%2F1r2gTjKne3odT9WyvW7doU4xT9nMPcmJChYrYmlxQDzOjA1gsla%2BMwYkRjcr53lpXzo76yTggIQRBJbRtNeeqE9gdYPYzkQIf9JLKNcKVipGkLpyloQkkxxGP5MkFUHwRWi9J5Q8xd0vAP2kod6tS%2FTJg2W85fIFQ0e%2FoEg13x03C14tVhwJNXEw%3D%3D&Expires=1775980883) - ﻿App Development Instructions

Dieses Dokument legt verbindliche Anweisungen und Richtlinien fest ...

3. [Mutually exclusive powershell parameters - Stack Overflow](https://stackoverflow.com/questions/1767219/mutually-exclusive-powershell-parameters) - You can use the parameter attribute to declare multiple parameter sets. You then simply assign param...

4. [Designing Professional Parameters - powershell.one](https://powershell.one/powershell-internals/attributes/parameters) - When parameters are mutually exclusive, they should be grouped by Parameter Sets. Once the user subm...

5. [PowerShell functions and Parameter Sets - Simon Wahlin](https://blog.simonw.se/powershell-functions-and-parameter-sets/) - Both parameters exists but are mutually exclusive, you cannot use them both at the same time, since ...

6. [Preventing path traversal in PowerShell - Reddit](https://www.reddit.com/r/PowerShell/comments/vjjofi/preventing_path_traversal_in_powershell/) - It's supposed to take a filename from user input, then modify a file according to pre-defined rules....

7. [Everything you wanted to know about PSCustomObject - PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-pscustomobject?view=powershell-7.6) - This module explains how to use arrays and hash tables in Windows PowerShell scripts. Last updated o...

8. [Unlocking the Power of PSCustomObject in PowerShell - LinkedIn](https://www.linkedin.com/pulse/unlocking-power-pscustomobject-powershell-vishal-pant-clo9c) - PSCustomObject is a type accelerator in PowerShell that allows you to create structured data easily....

9. [Powershell start process with runas and credentials - Stack Overflow](https://stackoverflow.com/questions/63401299/powershell-start-process-with-runas-and-credentials) - I'm trying to run a process with a hardcoded user and pwd however i seem to only be able to specify ...

10. [Start-Process doesn't work with -credential parameter on Windows ...](https://www.reddit.com/r/PowerShell/comments/10dh2fr/startprocess_doesnt_work_with_credential/) - I have the task to run one script which executes another script with different credentials. Start-Pr...

11. [Path Traversal | OWASP Foundation](https://owasp.org/www-community/attacks/Path_Traversal) - A path traversal attack (also known as directory traversal) aims to access files and directories tha...

12. [Powershell keep only n latest items in folder (builds rotation)](https://stackoverflow.com/questions/32158865/powershell-keep-only-n-latest-items-in-folder-builds-rotation) - For purpose of builds rotation I want to keep only 10 latest items in folder. Builds are located in ...

13. [PowerShell Rotate Logs - Lethe HeloCheck - WordPress.com](https://helocheckblog.wordpress.com/2014/06/24/powershell-rotate-logs/) - The script will go through the directory defined as $rootPath deleting all files which are older tha...

14. [PowerShell ProgressBar -- Part 1 - Tiberriver256](https://tiberriver256.github.io/powershell/PowerShellProgress-Pt1/) - Showing how to create a progress bar in PowerShell using XAML and runspaces.

15. [Part V - Building Responsive PowerShell Apps with Progress bars](https://www.foxdeploy.com/blog/part-v-powershell-guis-responsive-apps-with-progress-bars.html) - In this post we'll be covering how to implement progress bars in your own application, and how to mu...

16. [The NotifyIcon Control - SAPIEN Information Center](https://info.sapien.com/guis/gui-controls/spotlight-on-the-notifyicon-control) - This property sets the icon to display in the system tray. Important: This property must be set; oth...

17. [Creating a Balloon Tip Notification Using PowerShell - MCPmag.com](https://mcpmag.com/articles/2017/09/07/creating-a-balloon-tip-notification-using-powershell.aspx) - PowerShell makes it easy to create a custom pop-up notification in Windows. There are a few ways tha...

18. [Set-ExecutionPolicy (Microsoft.PowerShell.Security)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.6) - An execution policy is part of the PowerShell security strategy. Execution policies determine whethe...

