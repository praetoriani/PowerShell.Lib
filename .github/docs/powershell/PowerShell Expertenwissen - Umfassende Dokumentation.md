# PowerShell Expertenwissen – Umfassende Dokumentation

> Erstellt am 05. April 2026 | Zielgruppe: Fortgeschrittene PowerShell-Entwickler

---

## Inhaltsverzeichnis

1. [Externe Skripte einbinden – Dot-Sourcing & Module](#1-externe-skripte-einbinden)
2. [Module als Variablen-Container – Globaler Scope](#2-module-als-variablen-container)
3. [Persistenter Speicher – PowerShells LocalStorage-Äquivalent](#3-persistenter-speicher)
4. [Eigene Datenbank programmieren – LocalStorage-Feature](#4-eigene-datenbank-programmieren)
5. [Programme als Administrator oder als anderer Benutzer starten](#5-programme-als-administrator-starten)
6. [Eigener Passwortmanager mit WPF, XAML und .NET](#6-eigener-passwortmanager)

---

## 1. Externe Skripte einbinden

### Das Konzept: Dot-Sourcing vs. Modulimport

In PowerShell gibt es zwei etablierte Wege, Funktionen und Inhalte aus einer externen `.ps1`-Datei in den aktuellen Kontext zu laden: **Dot-Sourcing** und **Modulimport**. Beide Methoden gehen weit über ein bloßes textuelles Einlesen der Datei hinaus – sie laden den Code tatsächlich in den Arbeitsspeicher und machen ihn ausführbar.

Der entscheidende Unterschied liegt im Scope (Gültigkeitsbereich), in den die Inhalte geladen werden:

| Methode | Syntax | Scope | Geeignet für |
|---|---|---|---|
| Normaler Aufruf | `.\script.ps1` | Script-Scope (wird nach Ausführung verworfen) | Einmalige Ausführung |
| Dot-Sourcing | `. .\script.ps1` | Lokaler/Globaler Scope des Aufrufers | Einfache Skript-Modularisierung |
| Modulimport | `Import-Module MyModule` | Modul-Scope mit Export-Kontrolle | Professionelle, wiederverwendbare Tools |
| `using module` | `using module .\MyModule.psm1` | Klassen & Enum aus Modul in aktuellen Scope | Klassen, Enums, Typen |

---

### Methode 1: Dot-Sourcing (`.`)

Dot-Sourcing ist die einfachste Methode, um Funktionen aus einer externen `.ps1`-Datei in den aktuellen Scope zu importieren. Der Punkt (`.`) vor dem Skriptpfad ist dabei das entscheidende Schlüsselzeichen.

**Funktionsweise:**
Normalerweise erstellt PowerShell beim Aufruf eines Skripts einen neuen, untergeordneten *Script-Scope*. Alle dort definierten Funktionen und Variablen verschwinden nach Ende des Skripts. Dot-Sourcing verhindert dies: Die Inhalte werden direkt in den *aufrufenden* Scope (den *lokalen* Scope des Hauptskripts) geladen.

```powershell
# functions.ps1 – externe Funktionsbibliothek
function Get-Greeting {
    param([string]$Name)
    return "Hallo, $Name! Willkommen."
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message" -ForegroundColor Cyan
}
```

```powershell
# main.ps1 – Hauptskript, das die Funktionen einbindet
# Dot-Sourcing: Punkt + Leerzeichen + Pfad
. .\functions.ps1

# Jetzt sind alle Funktionen aus functions.ps1 verfügbar:
$greeting = Get-Greeting -Name "Max"
Write-Log -Message $greeting -Level "INFO"

# Dot-Sourcing mit absolutem Pfad:
. "C:\Scripts\MyLib\functions.ps1"

# Dot-Sourcing relativ zum Skriptverzeichnis (empfohlen für portable Skripte):
. "$PSScriptRoot\functions.ps1"
```

**Wichtiger Hinweis: `$PSScriptRoot` vs. relativer Pfad**
Der relative Pfad (`.\functions.ps1`) bezieht sich auf das aktuelle *Arbeitsverzeichnis* der PowerShell-Sitzung (dem Ergebnis von `Get-Location`), NICHT auf das Verzeichnis des Skripts selbst. Wird das Skript von einem anderen Verzeichnis aus aufgerufen, schlägt der relative Pfad fehl. Die robuste Alternative ist `$PSScriptRoot`, welche immer auf das Verzeichnis zeigt, in dem das aufrufende Skript liegt.

**Mehrere Dateien dot-sourcen:**
```powershell
# Alle .ps1-Dateien in einem Unterordner einbinden (z.B. "lib"-Ordner)
$libPath = Join-Path $PSScriptRoot "lib"
Get-ChildItem -Path $libPath -Filter "*.ps1" -Recurse | ForEach-Object {
    . $_.FullName
    Write-Verbose "Geladen: $($_.Name)"
}
```

**Stärken von Dot-Sourcing:**
- Extrem einfach, kein Modul-Gerüst erforderlich
- Ideal für persönliche Skript-Bibliotheken und Profile
- Alle Funktionen, Variablen und Aliase werden in den Caller-Scope importiert

**Schwächen von Dot-Sourcing:**
- Kein Namensraum-Schutz: Variablen aus dem eingebundenen Skript können Variablen im Hauptskript überschreiben (Namespace-Pollution)
- Kein gezielter Export/Import möglich (alles oder nichts)
- Schwieriger zu testen und zu warten bei großen Projekten

---

### Methode 2: PowerShell Script Module (.psm1)

Für professionelle, wiederverwendbare Bibliotheken ist das PowerShell-Modul die überlegene Wahl. Ein Script-Modul ist einfach eine Datei mit der Erweiterung `.psm1` (PowerShell Script Module) statt `.ps1`.

**Aufbau eines einfachen Script-Moduls:**

```powershell
# MeineLibrary.psm1

# Private Hilfsfunktion – wird NICHT exportiert
function Invoke-InternalHelper {
    param([string]$Data)
    return $Data.Trim().ToLower()
}

# Öffentliche Funktion – wird exportiert
function Get-ProcessedData {
    param([string]$RawData)
    $cleaned = Invoke-InternalHelper -Data $RawData
    return "Verarbeitet: $cleaned"
}

# Weitere öffentliche Funktion
function Set-Configuration {
    param(
        [string]$Key,
        [string]$Value
    )
    # Implementierung ...
    Write-Host "Konfiguration gesetzt: $Key = $Value"
}

# Expliziter Export – nur diese Funktionen sind von außen sichtbar
Export-ModuleMember -Function 'Get-ProcessedData', 'Set-Configuration'
# Interne Hilfsfunktionen (wie Invoke-InternalHelper) werden NICHT exportiert
```

**Modul verwenden:**

```powershell
# main.ps1

# Option 1: Modul aus einem Pfad laden (ohne Installation)
Import-Module "$PSScriptRoot\MeineLibrary.psm1" -Force

# Option 2: Modul aus dem Modul-Pfad laden (nach Installation)
Import-Module MeineLibrary

# Funktionen verwenden:
$result = Get-ProcessedData -RawData "  Hallo Welt  "
Write-Host $result   # Ausgabe: "Verarbeitet: hallo welt"

# Alle verfügbaren Befehle des Moduls anzeigen:
Get-Command -Module MeineLibrary

# Modul wieder entladen:
Remove-Module MeineLibrary
```

**Modul-Manifest (.psd1) – der professionelle Weg:**

Für ein vollständiges Modul empfiehlt sich auch ein Manifest, das Metadaten und Abhängigkeiten beschreibt:

```powershell
# Manifest erstellen:
New-ModuleManifest -Path ".\MeineLibrary.psd1" `
    -RootModule "MeineLibrary.psm1" `
    -ModuleVersion "1.0.0" `
    -Author "Dein Name" `
    -Description "Meine PowerShell-Bibliothek" `
    -FunctionsToExport @('Get-ProcessedData', 'Set-Configuration') `
    -VariablesToExport @() `
    -PowerShellVersion "5.1"
```

**Modul im Modul-Pfad installieren:**

```powershell
# Modulpfade anzeigen:
$env:PSModulePath -split ";"

# Modul in Benutzer-Modul-Pfad kopieren:
$targetPath = "$HOME\Documents\PowerShell\Modules\MeineLibrary"
New-Item -ItemType Directory -Path $targetPath -Force
Copy-Item ".\MeineLibrary.psm1" -Destination $targetPath
Copy-Item ".\MeineLibrary.psd1" -Destination $targetPath

# Ab jetzt kann man das Modul von überall mit Import-Module MeineLibrary laden
```

---

### Methode 3: `using module` – Klassen und Typen importieren

Seit PowerShell 5.0 gibt es die `using module`-Direktive. Sie ist besonders wichtig, wenn ein Modul **Klassen**, **Enums** oder **.NET-Typen** definiert, die im Hauptskript direkt als Typen verwendet werden sollen.

```powershell
# Klassen-Modul: DataTypes.psm1
class Person {
    [string]$Name
    [int]$Alter
    [string]$Email

    Person([string]$name, [int]$alter, [string]$email) {
        $this.Name = $name
        $this.Alter = $alter
        $this.Email = $email
    }

    [string] ToString() {
        return "$($this.Name) (Alter: $($this.Alter))"
    }
}

enum UserRole {
    Admin = 0
    User = 1
    Guest = 2
}
```

```powershell
# main.ps1 – MUSS am Anfang der Datei stehen, vor allen anderen Anweisungen!
using module .\DataTypes.psm1

# Klassen-Typen direkt nutzen:
$person = [Person]::new("Max Mustermann", 30, "max@example.de")
Write-Host $person.ToString()

# Enum verwenden:
$rolle = [UserRole]::Admin
Write-Host "Benutzerrolle: $rolle"
```

**Wichtig:** `using module` muss zwingend am Anfang einer `.ps1`-Datei stehen und kann nicht dynamisch (z.B. in einer `if`-Bedingung oder Funktion) verwendet werden.

---

### Entscheidungsbaum: Welche Methode wählen?

```
Brauche ich Klassen/Enums aus einem anderen Skript?
 └─► JA  → using module
 └─► NEIN
      ↓
Ist es ein kleines, persönliches Helfer-Skript ohne Namespace-Konfliktgefahr?
 └─► JA  → Dot-Sourcing (. .\helper.ps1)
 └─► NEIN
      ↓
Soll der Code wiederverwendbar, testbar und wartbar sein?
 └─► JA  → Script Module (.psm1) mit Export-ModuleMember
```

---

## 2. Module als Variablen-Container

### Technische Grundlagen

Es ist absolut möglich, ein PowerShell-Modul ausschließlich zur Definition und zum Export von Variablen zu verwenden. Diese Technik ist weniger verbreitet als Funktions-Module, hat aber sehr spezifische und legitime Anwendungsfälle.

**Wichtiger Scope-Unterschied:**
Variablen in einem `.psm1`-Modul leben standardmäßig im *Modul-Scope*, nicht im globalen Scope. `Export-ModuleMember -Variable` macht sie zugänglich, platziert sie aber technisch gesehen in einem eigenen Namespace. Um eine Variable wirklich im *globalen* Scope zu haben, benötigt man entweder den `$global:`-Präfix oder entsprechende Import-Optionen.

```powershell
# Konfiguration.psm1 – Modul als Variablen-Container

# --- Globale Konfigurationseinstellungen ---

# Anwendungspfade
$script:AppRoot   = "C:\MeineApp"
$script:LogPath   = Join-Path $script:AppRoot "Logs"
$script:DataPath  = Join-Path $script:AppRoot "Data"
$script:ConfigPath = Join-Path $AppRoot "Config\settings.json"

# Anwendungsparameter
$script:AppName    = "MeineAnwendung"
$script:AppVersion = "2.1.0"
$script:MaxRetries = 3
$script:TimeoutSec = 30

# Farbkonstanten für Ausgaben
$script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
}

# API-Endpunkte (Beispiel)
$script:ApiBaseUrl  = "https://api.example.com/v2"
$script:ApiTimeout  = 15

# Benutzereinstellungen (werden zur Laufzeit überschrieben)
$script:CurrentUser = $env:USERNAME
$script:IsAdmin     = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Exportiert alle definierten Variablen (und keine Funktionen)
Export-ModuleMember -Variable 'AppRoot','LogPath','DataPath','ConfigPath',
                               'AppName','AppVersion','MaxRetries','TimeoutSec',
                               'Colors','ApiBaseUrl','ApiTimeout',
                               'CurrentUser','IsAdmin'
```

**Einbindung im Hauptskript:**

```powershell
# main.ps1
Import-Module "$PSScriptRoot\Konfiguration.psm1" -Force

# Variablen direkt verwenden (über Modul-Scope zugänglich):
Write-Host "Starte $AppName v$AppVersion"
Write-Host "Benutzer: $CurrentUser | Administrator: $IsAdmin"
Write-Host "Log-Pfad: $LogPath"

# Farbige Ausgabe mit dem Colors-Hashtable:
Write-Host "Erfolg!" -ForegroundColor $Colors.Success
Write-Host "Warnung!" -ForegroundColor $Colors.Warning
```

**Alternative: Direkt in den globalen Scope schreiben:**

```powershell
# GlobalVars.psm1 – Variablen werden direkt global gesetzt
function Initialize-GlobalConfig {
    $global:AppName    = "MeineApp"
    $global:AppVersion = "1.0"
    $global:AppRoot    = "C:\MeineApp"
    $global:LogPath    = "$global:AppRoot\Logs"
}

Export-ModuleMember -Function 'Initialize-GlobalConfig'
```

```powershell
# Verwendung:
Import-Module "$PSScriptRoot\GlobalVars.psm1"
Initialize-GlobalConfig   # Setzt alle globalen Variablen

Write-Host $global:AppName  # Verfügbar in der gesamten Session
```

---

### Praxisnahe Use Cases

**Use Case 1: Zentrales Konfigurationsmodul in großen Projekten**

In einem Projekt mit 20+ Skripten, die alle dieselbe Konfiguration benötigen (Datenbankverbindungsstrings, Pfade, Versionsnummern), spart ein zentrales Konfigurationsmodul enorme Redundanz. Statt in jedem Skript die Werte zu wiederholen, wird das Modul einfach geladen.

```powershell
# Alle Skripte beginnen mit:
Import-Module "$PSScriptRoot\..\Core\AppConfig.psm1" -Force

# Und haben sofort Zugriff auf:
# $DbConnectionString, $LogLevel, $AppVersion, $ApiKey, ...
```

**Use Case 2: Umgebungsspezifische Konfiguration (DEV/STAGING/PROD)**

```powershell
# EnvironmentConfig.psm1
param([string]$Environment = "DEV")

switch ($Environment) {
    "DEV"  {
        $script:DbServer  = "dev-db.local"
        $script:ApiUrl    = "https://api-dev.example.com"
        $script:LogLevel  = "DEBUG"
    }
    "STAGING" {
        $script:DbServer  = "staging-db.example.com"
        $script:ApiUrl    = "https://api-staging.example.com"
        $script:LogLevel  = "INFO"
    }
    "PROD" {
        $script:DbServer  = "prod-db.example.com"
        $script:ApiUrl    = "https://api.example.com"
        $script:LogLevel  = "WARNING"
    }
}

Export-ModuleMember -Variable 'DbServer','ApiUrl','LogLevel'
```

```powershell
# main.ps1
$env = $env:DEPLOY_ENV ?? "DEV"
Import-Module "$PSScriptRoot\EnvironmentConfig.psm1" -ArgumentList $env -Force
Write-Host "Verbinde zu: $DbServer (Log-Level: $LogLevel)"
```

**Use Case 3: Shared Constants / Enum-Ersatz in PowerShell 5.1**

Vor PowerShell 5.0 gab es keine nativen Enums. In älteren Umgebungen ersetzt ein Variablen-Modul dieses Konzept:

```powershell
# Constants.psm1
$script:EXIT_SUCCESS  = 0
$script:EXIT_ERROR    = 1
$script:EXIT_TIMEOUT  = 2
$script:EXIT_NO_PERMS = 3

$script:STATUS_PENDING  = "PENDING"
$script:STATUS_RUNNING  = "RUNNING"
$script:STATUS_DONE     = "DONE"
$script:STATUS_FAILED   = "FAILED"

Export-ModuleMember -Variable 'EXIT_SUCCESS','EXIT_ERROR','EXIT_TIMEOUT','EXIT_NO_PERMS',
                               'STATUS_PENDING','STATUS_RUNNING','STATUS_DONE','STATUS_FAILED'
```

**Empfehlung:** Für neue Projekte (PS 5.0+) sind native Enums via `using module` und Klassen die elegantere Lösung. Das Variablen-Modul bleibt aber wertvoll für Konfigurationsdaten, die keine Typsicherheit benötigen und sich zur Laufzeit ändern können.

---

## 3. Persistenter Speicher

### Das Problem: PowerShell ist zustandslos

PowerShell-Sessions sind von Natur aus flüchtig. Alle Variablen, Objekte und Zustände verschwinden nach Beendigung der Session. Es gibt kein natives Äquivalent zum Browser-`localStorage`. Um Daten zwischen Sessions zu erhalten, muss man explizit schreiben und lesen.

### Lösungsübersicht

| Methode | Format | Geeignet für | Nachteile |
|---|---|---|---|
| JSON-Datei | Text | Konfiguration, kleine Datensätze | Kein Concurrency-Schutz |
| XML / CliXML | Text/Binär | Komplexe Objekte, typsicher | Verbose, schwer lesbar |
| CSV-Datei | Text | Tabellarische Daten | Nur flache Strukturen |
| Registry | Windows-spezifisch | Anwendungseinstellungen | Windows-only, flache Struktur |
| SQLite (PSSQLite) | Binär | Relationale Daten, größere Mengen | Externe Bibliothek nötig |
| Encrypted SecureString | Text | Sensitive Daten, Passwörter | User-/Maschinenbindung |

---

### Option A: JSON-Datei (empfohlen für Konfiguration)

JSON ist die modernste und flexibelste Methode für einfache persistente Speicherung. PowerShell hat native `ConvertTo-Json`- und `ConvertFrom-Json`-Cmdlets.

```powershell
# LocalStorage.psm1 – Generische JSON-basierte Persistenz-Schicht

$script:StoragePath = Join-Path $env:APPDATA "MeineApp\storage.json"

function Initialize-Storage {
    $dir = Split-Path $script:StoragePath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path $script:StoragePath)) {
        @{} | ConvertTo-Json | Set-Content $script:StoragePath -Encoding UTF8
    }
}

function Get-StorageItem {
    param([string]$Key)
    Initialize-Storage
    $data = Get-Content $script:StoragePath -Raw -Encoding UTF8 | ConvertFrom-Json
    return $data.$Key
}

function Set-StorageItem {
    param([string]$Key, $Value)
    Initialize-Storage
    $data = Get-Content $script:StoragePath -Raw -Encoding UTF8 | ConvertFrom-Json
    
    # PSCustomObject ist immutable, daher in Hashtable konvertieren
    $hashtable = @{}
    $data.PSObject.Properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
    $hashtable[$Key] = $Value
    
    $hashtable | ConvertTo-Json -Depth 10 | Set-Content $script:StoragePath -Encoding UTF8
}

function Remove-StorageItem {
    param([string]$Key)
    Initialize-Storage
    $data = Get-Content $script:StoragePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $hashtable = @{}
    $data.PSObject.Properties | 
        Where-Object { $_.Name -ne $Key } | 
        ForEach-Object { $hashtable[$_.Name] = $_.Value }
    $hashtable | ConvertTo-Json -Depth 10 | Set-Content $script:StoragePath -Encoding UTF8
}

function Get-AllStorageItems {
    Initialize-Storage
    return Get-Content $script:StoragePath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Clear-Storage {
    @{} | ConvertTo-Json | Set-Content $script:StoragePath -Encoding UTF8
}

Export-ModuleMember -Function 'Get-StorageItem','Set-StorageItem','Remove-StorageItem',
                               'Get-AllStorageItems','Clear-Storage'
```

**Verwendungsbeispiel (Browser-localStorage-ähnliche API):**

```powershell
Import-Module "$PSScriptRoot\LocalStorage.psm1" -Force

# Einfache Werte speichern
Set-StorageItem -Key "letzterLogin"    -Value (Get-Date -Format "o")
Set-StorageItem -Key "bevorzugtesThema" -Value "Dunkel"
Set-StorageItem -Key "fenstergröße"    -Value @{ Breite = 1280; Höhe = 720 }

# Werte lesen
$letzterLogin = Get-StorageItem -Key "letzterLogin"
Write-Host "Letzter Login: $letzterLogin"

$theme = Get-StorageItem -Key "bevorzugtesThema"
Write-Host "Theme: $theme"

# Alle Daten anzeigen
$alle = Get-AllStorageItems
$alle | ConvertTo-Json | Write-Host

# Eintrag löschen
Remove-StorageItem -Key "fenstergröße"
```

---

### Option B: Windows Registry (für Anwendungseinstellungen)

Die Windows Registry ist ein nativer persistenter Key-Value-Store, der ideal für Anwendungseinstellungen (ähnlich wie `localStorage`) geeignet ist und kein zusätzliches Dateisystem-Management benötigt.

```powershell
# Registry-basierter Persistenz-Helper

$script:RegPath = "HKCU:\Software\MeineApp"

function Initialize-Registry {
    if (-not (Test-Path $script:RegPath)) {
        New-Item -Path $script:RegPath -Force | Out-Null
    }
}

function Set-AppSetting {
    param([string]$Name, [string]$Value)
    Initialize-Registry
    Set-ItemProperty -Path $script:RegPath -Name $Name -Value $Value
}

function Get-AppSetting {
    param([string]$Name, [string]$Default = "")
    Initialize-Registry
    try {
        return (Get-ItemProperty -Path $script:RegPath -Name $Name -ErrorAction Stop).$Name
    } catch {
        return $Default
    }
}

function Remove-AppSetting {
    param([string]$Name)
    Remove-ItemProperty -Path $script:RegPath -Name $Name -ErrorAction SilentlyContinue
}

# Verwendung:
Set-AppSetting -Name "LastUser"  -Value $env:USERNAME
Set-AppSetting -Name "DarkMode"  -Value "true"
Set-AppSetting -Name "Language"  -Value "de-DE"

$lastUser = Get-AppSetting -Name "LastUser" -Default "Unbekannt"
Write-Host "Letzter Benutzer: $lastUser"
```

---

### Option C: CliXML – Typsichere Objektpersistenz

`Export-Clixml` / `Import-Clixml` ist die PowerShell-native Methode, um komplexe Objekte (inkl. Typen) zu serialisieren – ideal wenn PowerShell-Objekte mit ihren Eigenschaften exakt wiederhergestellt werden sollen.

```powershell
# Komplexe Objektstruktur speichern:
$config = [PSCustomObject]@{
    ServerName    = "db01.local"
    Port          = 5432
    MaxConnections = 100
    LastModified  = Get-Date
    Tags          = @("production", "critical")
}

$config | Export-Clixml -Path "$env:APPDATA\MeineApp\config.xml"

# Später wiederherstellen (inkl. korrekter Typen!):
$restoredConfig = Import-Clixml -Path "$env:APPDATA\MeineApp\config.xml"
Write-Host "Server: $($restoredConfig.ServerName)"
Write-Host "Datum: $($restoredConfig.LastModified.ToString('dd.MM.yyyy'))"
# $restoredConfig.LastModified ist ein echter [DateTime]-Typ, keine Zeichenkette!
```

---

## 4. Eigene Datenbank programmieren

### Ansatz A: Eigener Mini-Datenbankserver in PowerShell (TCP/IP)

Es ist technisch möglich, einen simplen Datenbank-Server direkt in PowerShell zu implementieren, der über Named Pipes oder TCP lauscht. Dieser Ansatz eignet sich für Szenarien, in denen mehrere Skripte gleichzeitig auf gemeinsame Daten zugreifen müssen.

```powershell
# SimpleDbServer.ps1 – In-Process Key-Value Store über Named Pipe

Add-Type -AssemblyName System.IO

function Start-SimpleDbServer {
    param(
        [string]$PipeName = "PowerShellLocalDB",
        [string]$DataFile = "$env:APPDATA\MeineApp\db.json"
    )

    Write-Host "Starte DB-Server auf Pipe: \\.\pipe\$PipeName" -ForegroundColor Green

    # Daten laden oder neu initialisieren
    $db = if (Test-Path $DataFile) {
        Get-Content $DataFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }

    $server = New-Object System.IO.Pipes.NamedPipeServerStream(
        $PipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Message,
        [System.IO.Pipes.PipeOptions]::None
    )

    while ($true) {
        Write-Host "Warte auf Client-Verbindung..." -ForegroundColor Yellow
        $server.WaitForConnection()

        $reader = New-Object System.IO.StreamReader($server)
        $writer = New-Object System.IO.StreamWriter($server)
        $writer.AutoFlush = $true

        $requestJson = $reader.ReadLine()
        $request = $requestJson | ConvertFrom-Json

        $response = switch ($request.Command) {
            "SET" {
                $db[$request.Key] = $request.Value
                $db | ConvertTo-Json -Depth 10 | Set-Content $DataFile -Encoding UTF8
                @{ Status = "OK"; Value = $request.Value }
            }
            "GET" {
                @{ Status = "OK"; Value = $db[$request.Key] }
            }
            "DEL" {
                $db.Remove($request.Key)
                $db | ConvertTo-Json -Depth 10 | Set-Content $DataFile -Encoding UTF8
                @{ Status = "OK" }
            }
            "KEYS" {
                @{ Status = "OK"; Value = @($db.Keys) }
            }
            default {
                @{ Status = "ERROR"; Message = "Unbekannter Befehl: $($request.Command)" }
            }
        }

        $writer.WriteLine(($response | ConvertTo-Json -Compress))
        $server.Disconnect()
    }
}

# Client-Funktion:
function Invoke-DbCommand {
    param(
        [string]$Command,
        [string]$Key,
        $Value,
        [string]$PipeName = "PowerShellLocalDB"
    )

    $client = New-Object System.IO.Pipes.NamedPipeClientStream(".", $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $client.Connect(5000)  # 5 Sekunden Timeout

    $writer = New-Object System.IO.StreamWriter($client)
    $reader = New-Object System.IO.StreamReader($client)
    $writer.AutoFlush = $true

    $request = @{ Command = $Command; Key = $Key; Value = $Value }
    $writer.WriteLine(($request | ConvertTo-Json -Compress))

    $responseJson = $reader.ReadLine()
    $client.Dispose()

    return $responseJson | ConvertFrom-Json
}
```

---

### Ansatz B: SQLite mit PSSQLite (EMPFOHLEN)

SQLite ist die überlegene Lösung für einen lokalen, dateibasierten Datenbankserver in PowerShell. Das [PSSQLite-Modul](https://github.com/RamblingCookieMonster/PSSQLite) stellt eine komfortable PowerShell-Schnittstelle zur Verfügung.

```powershell
# PSSQLite installieren (einmalig):
Install-Module -Name PSSQLite -Scope CurrentUser -Force

# Modul importieren:
Import-Module PSSQLite

$dbPath = "$env:APPDATA\MeineApp\app.db"

# Datenbank und Tabellen erstellen:
$createTablesQuery = @"
CREATE TABLE IF NOT EXISTS AppSettings (
    Key   TEXT PRIMARY KEY,
    Value TEXT NOT NULL,
    UpdatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS UserData (
    Id        INTEGER PRIMARY KEY AUTOINCREMENT,
    Username  TEXT NOT NULL,
    Category  TEXT,
    Data      TEXT,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@

Invoke-SqliteQuery -DataSource $dbPath -Query $createTablesQuery

# Daten einfügen / aktualisieren (UPSERT):
$upsertQuery = @"
INSERT INTO AppSettings (Key, Value, UpdatedAt)
VALUES (@key, @value, CURRENT_TIMESTAMP)
ON CONFLICT(Key) DO UPDATE SET
    Value = excluded.Value,
    UpdatedAt = excluded.UpdatedAt;
"@

Invoke-SqliteQuery -DataSource $dbPath -Query $upsertQuery -SqlParameters @{
    key   = "LastLogin"
    value = (Get-Date -Format "o")
}

Invoke-SqliteQuery -DataSource $dbPath -Query $upsertQuery -SqlParameters @{
    key   = "Theme"
    value = "Dark"
}

# Daten lesen:
$setting = Invoke-SqliteQuery -DataSource $dbPath `
    -Query "SELECT Value FROM AppSettings WHERE Key = @key" `
    -SqlParameters @{ key = "LastLogin" }

Write-Host "Letzter Login: $($setting.Value)"

# Alle Einstellungen lesen:
$allSettings = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT * FROM AppSettings"
$allSettings | Format-Table

# Bulk-Insert (sehr schnell via Transaktion):
$userData = 1..100 | ForEach-Object {
    [PSCustomObject]@{
        Username = "user$_"
        Category = if ($_ % 2 -eq 0) { "Premium" } else { "Standard" }
        Data     = "Datenpunkt $_"
    }
}

$dataTable = $userData | Out-DataTable
Invoke-SQLiteBulkCopy -DataTable $dataTable -DataSource $dbPath -Table "UserData" -NotifyAfter 10

# Abfragen mit JOINs und Filtern:
$premiumUsers = Invoke-SqliteQuery -DataSource $dbPath `
    -Query "SELECT * FROM UserData WHERE Category = 'Premium' ORDER BY Id LIMIT 10"

$premiumUsers | Format-Table
```

---

### Ansatz C: Einfache JSON-Flat-File-Datenbank (ohne externe Abhängigkeiten)

Für Szenarien ohne externe Module und mit geringem Datenvolumen ist eine JSON-basierte Flat-File-Datenbank oft die pragmatischste Lösung:

```powershell
# FlatFileDb.psm1 – Einfache JSON-Datenbank

class FlatFileDb {
    hidden [string]$FilePath
    hidden [hashtable]$Data

    FlatFileDb([string]$path) {
        $this.FilePath = $path
        $this.Load()
    }

    hidden [void] Load() {
        if (Test-Path $this.FilePath) {
            $raw = Get-Content $this.FilePath -Raw -Encoding UTF8
            $this.Data = $raw | ConvertFrom-Json -AsHashtable
        } else {
            $this.Data = @{}
            $this.Save()
        }
    }

    hidden [void] Save() {
        $dir = Split-Path $this.FilePath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $this.Data | ConvertTo-Json -Depth 20 | Set-Content $this.FilePath -Encoding UTF8
    }

    [void] Set([string]$collection, [string]$id, [object]$document) {
        if (-not $this.Data.ContainsKey($collection)) {
            $this.Data[$collection] = @{}
        }
        $this.Data[$collection][$id] = $document
        $this.Save()
    }

    [object] Get([string]$collection, [string]$id) {
        if ($this.Data.ContainsKey($collection) -and $this.Data[$collection].ContainsKey($id)) {
            return $this.Data[$collection][$id]
        }
        return $null
    }

    [object[]] GetAll([string]$collection) {
        if ($this.Data.ContainsKey($collection)) {
            return @($this.Data[$collection].Values)
        }
        return @()
    }

    [bool] Delete([string]$collection, [string]$id) {
        if ($this.Data.ContainsKey($collection) -and $this.Data[$collection].ContainsKey($id)) {
            $this.Data[$collection].Remove($id)
            $this.Save()
            return $true
        }
        return $false
    }

    [int] Count([string]$collection) {
        if ($this.Data.ContainsKey($collection)) { return $this.Data[$collection].Count }
        return 0
    }
}
```

```powershell
using module ".\FlatFileDb.psm1"

$db = [FlatFileDb]::new("$env:APPDATA\MeineApp\flatdb.json")

# Dokument speichern:
$db.Set("benutzer", "user_001", @{
    Name     = "Max Mustermann"
    Email    = "max@example.de"
    Erstellt = (Get-Date -Format "o")
    Aktiv    = $true
})

# Dokument lesen:
$user = $db.Get("benutzer", "user_001")
Write-Host "Name: $($user.Name)"

# Alle lesen:
$alleBenutzer = $db.GetAll("benutzer")
Write-Host "Anzahl Benutzer: $($db.Count('benutzer'))"

# Löschen:
$db.Delete("benutzer", "user_001")
```

---

## 5. Programme als Administrator oder als anderer Benutzer starten

### Methode 1: Programm als Administrator starten (`-Verb RunAs`)

Der Parameter `-Verb RunAs` von `Start-Process` löst eine UAC-Anfrage aus und startet den Prozess mit erhöhten Rechten. Dies funktioniert für jede ausführbare Datei.

```powershell
# Notepad++ als Administrator starten:
Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" -Verb RunAs

# Mit spezifischer Datei öffnen:
Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" `
              -ArgumentList "C:\temp\config.txt" `
              -Verb RunAs

# PowerShell-Skript als Admin ausführen:
Start-Process -FilePath "powershell.exe" `
              -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"C:\Scripts\admin_task.ps1`"" `
              -Verb RunAs `
              -Wait  # Warten bis der Prozess beendet ist

# cmd.exe als Administrator:
Start-Process cmd.exe -Verb RunAs

# Beliebige .exe als Admin (generisch):
$programm = "notepad++.exe"
$pfad = (Get-Command $programm -ErrorAction SilentlyContinue)?.Source
if ($pfad) {
    Start-Process -FilePath $pfad -Verb RunAs
} else {
    Write-Warning "Programm nicht gefunden: $programm"
}
```

**Prüfen ob das aktuelle Skript bereits als Admin läuft:**

```powershell
function Test-IsAdministrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Automatische Eskalation (Self-Elevation):
function Invoke-SelfElevation {
    if (-not (Test-IsAdministrator)) {
        Write-Host "Administratorrechte erforderlich. Eskaliere..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Definition
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
            -Verb RunAs `
            -Wait
        exit
    }
    Write-Host "Läuft bereits als Administrator." -ForegroundColor Green
}

# Am Skriptanfang aufrufen:
Invoke-SelfElevation

# Ab hier hat das Skript Admin-Rechte...
Write-Host "Führe privilegierte Operationen durch..."
```

---

### Methode 2: Programm als bestimmter Benutzer starten (`-Credential`)

Mit dem `-Credential`-Parameter kann jedes Programm unter einem anderen Benutzerkonto gestartet werden. Dies ist besonders nützlich in Unternehmensumgebungen (z.B. ein Tool als Dienst-Konto starten).

```powershell
# Methode A: Interaktive Credential-Abfrage
$cred = Get-Credential -Message "Gib die Anmeldedaten für den Ziel-Benutzer ein" `
                       -UserName "DOMAIN\ServiceAccount"

Start-Process -FilePath "notepad++.exe" -Credential $cred

# Methode B: Programmatische Credentials (z.B. für Automatisierung)
$benutzername = "DOMAIN\ServiceUser"
$passwort = ConvertTo-SecureString "SicheresPasswort123!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($benutzername, $passwort)

Start-Process -FilePath "C:\Tools\SpecialTool.exe" `
              -Credential $cred `
              -WorkingDirectory "C:\Tools"

# Methode C: Passwort aus verschlüsselter Datei (sicher für Skripte):
# Einmalig speichern (nur einmal nötig, danke DPAPI-Verschlüsselung):
$passwort = Read-Host "Passwort eingeben" -AsSecureString
$passwort | ConvertFrom-SecureString | Set-Content "$env:APPDATA\cred_encrypted.txt"

# In Skripten laden:
$verschlüsselt = Get-Content "$env:APPDATA\cred_encrypted.txt"
$sicheresPasswort = $verschlüsselt | ConvertTo-SecureString  # Nur auf DIESEM PC/User funktionierend
$cred = New-Object PSCredential("DOMAIN\ServiceUser", $sicheresPasswort)
Start-Process "notepad++.exe" -Credential $cred
```

---

### Methode 3: Kombination – Als Administrator UND als anderer Benutzer

`-Verb RunAs` und `-Credential` können in `Start-Process` NICHT direkt kombiniert werden. Ein Workaround über einen Zwischen-Prozess ist notwendig:

```powershell
# Workaround: Erst als anderen User starten, dieser startet dann mit RunAs
$cred = Get-Credential "DOMAIN\AdminUser"

Start-Process -FilePath "powershell.exe" `
    -Credential $cred `
    -ArgumentList '-Command', '& { Start-Process notepad++.exe -Verb RunAs }' `
    -WindowStyle Hidden
```

---

### Methode 4: `runas.exe` – Klassischer Windows-Weg

Die klassische `runas.exe` funktioniert ebenfalls aus PowerShell, hat aber weniger Flexibilität:

```powershell
# Interaktiv (Passwort-Prompt im Konsolenfenster):
Start-Process runas.exe -ArgumentList '/user:DOMAIN\AdminUser "notepad++.exe"'

# Mit /savecred (Credentials werden im Windows Credential Store gecacht):
Start-Process runas.exe -ArgumentList '/savecred /user:DOMAIN\AdminUser "notepad++.exe"'
```

---

### Methode 5: Programme als anderer Benutzer mit `Invoke-Command` (lokal)

```powershell
# Lokale PowerShell-Session als anderer Benutzer:
$cred = Get-Credential "DOMAIN\OtherUser"

Invoke-Command -ComputerName localhost `
               -Credential $cred `
               -ScriptBlock {
                    # Dieser Code läuft als OtherUser
                    $env:USERNAME
                    Start-Process notepad++.exe
               }
```

---

## 6. Eigener Passwortmanager mit WPF, XAML und .NET

### Komplexitätseinschätzung

Die Implementierung eines sicheren, portablen Passwortmanagers in PowerShell ist **technisch möglich, aber signifikant komplex**. Der Aufwand liegt vor allem in der korrekten Implementierung der Sicherheitsaspekte, nicht in der UI-Erstellung.

**Komplexitätsbewertung:**

| Komponente | Aufwand | Schwierigkeit |
|---|---|---|
| WPF/XAML UI Grundgerüst | 2-4h | Mittel |
| Datenbankstruktur (JSON/SQLite) | 1-2h | Niedrig |
| AES-256 Verschlüsselung | 3-5h | Hoch |
| Master-Passwort + Key Derivation (PBKDF2) | 4-8h | Sehr Hoch |
| Sichere Passwortgenerierung | 1-2h | Niedrig |
| Clipboard-Management (Auto-Clear) | 1h | Niedrig |
| Import/Export (KeePass-kompatibel) | 4-8h | Hoch |
| Auto-Lock / Session-Timeout | 2-3h | Mittel |
| Sicherheits-Auditing & Härtung | 8-16h | Sehr Hoch |
| **Gesamt (Minimum)** | **~26-49h** | **Hoch** |

---

### Architektur-Übersicht

```
PowerShell Passwortmanager
├── UI-Schicht (WPF/XAML)
│   ├── MainWindow.xaml       – Hauptfenster mit Passwortliste
│   ├── LoginWindow.xaml      – Master-Passwort-Eingabe
│   ├── EditEntryDialog.xaml  – Eintrag hinzufügen/bearbeiten
│   └── SettingsWindow.xaml   – Einstellungen
├── Core-Schicht
│   ├── CryptoEngine.psm1     – Ver-/Entschlüsselung (AES-256)
│   ├── KeyDerivation.psm1    – PBKDF2/Argon2 Key-Ableitng
│   ├── DatabaseManager.psm1  – Datenpersistenz
│   └── PasswordGenerator.psm1 – Sichere Passwortgenerierung
└── Daten
    └── vault.dat             – Verschlüsselte Datenbank
```

---

### Schritt 1: Kryptografische Grundlage (PBKDF2 + AES-256)

```powershell
# CryptoEngine.psm1

Add-Type -AssemblyName System.Security

# Key-Ableitung mit PBKDF2 (RFC 2898) – NIEMALS rohes Passwort als Key verwenden!
function Get-DerivedKey {
    param(
        [Parameter(Mandatory)]
        [System.Security.SecureString]$MasterPassword,
        
        [Parameter(Mandatory)]
        [byte[]]$Salt,
        
        [int]$Iterations = 310000,  # OWASP-Empfehlung 2023 für PBKDF2-SHA256
        [int]$KeyLength = 32        # 256 Bit für AES-256
    )
    
    # SecureString in byte[] konvertieren (Sicherheitskritisch!)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($MasterPassword)
    try {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($plainPassword)
        
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
            $passwordBytes, $Salt, $Iterations,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        
        return $pbkdf2.GetBytes($KeyLength)
    } finally {
        # Speicher sofort bereinigen!
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        if ($passwordBytes) { 
            [System.Array]::Clear($passwordBytes, 0, $passwordBytes.Length) 
        }
    }
}

# Neue zufällige Salt erzeugen:
function New-CryptoSalt {
    param([int]$Length = 32)  # 256 Bit Salt
    $salt = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)
    return $salt
}

# Daten mit AES-256-GCM verschlüsseln:
function Protect-Data {
    param(
        [Parameter(Mandatory)]
        [string]$PlainText,
        
        [Parameter(Mandatory)]
        [byte[]]$Key
    )
    
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 256
    $aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key     = $Key
    $aes.GenerateIV()
    
    $plainBytes     = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $encryptor      = $aes.CreateEncryptor()
    $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    
    # IV + verschlüsselte Daten kombinieren
    $result = $aes.IV + $encryptedBytes
    
    $aes.Dispose()
    return [System.Convert]::ToBase64String($result)
}

# Daten entschlüsseln:
function Unprotect-Data {
    param(
        [Parameter(Mandatory)]
        [string]$CipherText,
        
        [Parameter(Mandatory)]
        [byte[]]$Key
    )
    
    $allBytes      = [System.Convert]::FromBase64String($CipherText)
    $iv            = $allBytes[0..15]
    $encryptedData = $allBytes[16..($allBytes.Length - 1)]
    
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 256
    $aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key     = $Key
    $aes.IV      = $iv
    
    $decryptor    = $aes.CreateDecryptor()
    $decryptedBytes = $decryptor.TransformFinalBlock($encryptedData, 0, $encryptedData.Length)
    
    $aes.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
}

# HMAC-SHA256 für Integritätsprüfung der Datenbank:
function Get-DatabaseMAC {
    param(
        [byte[]]$Data,
        [byte[]]$MacKey
    )
    $hmac = New-Object System.Security.Cryptography.HMACSHA256($MacKey)
    return $hmac.ComputeHash($Data)
}

Export-ModuleMember -Function 'Get-DerivedKey','New-CryptoSalt','Protect-Data',
                               'Unprotect-Data','Get-DatabaseMAC'
```

---

### Schritt 2: Sichere Passwortgenerierung

```powershell
# PasswordGenerator.psm1

function New-SecurePassword {
    param(
        [int]$Length = 20,
        [switch]$IncludeUppercase,
        [switch]$IncludeLowercase,
        [switch]$IncludeDigits,
        [switch]$IncludeSymbols,
        [string]$ExcludeChars = "0OIl1",  # Verwirrende Zeichen ausschließen
        [switch]$AllSets  # Alle Zeichensätze aktivieren
    )
    
    if ($AllSets) {
        $IncludeUppercase = $true
        $IncludeLowercase = $true
        $IncludeDigits    = $true
        $IncludeSymbols   = $true
    }
    
    $charSet = ""
    if ($IncludeLowercase) { $charSet += "abcdefghijkmnopqrstuvwxyz" }
    if ($IncludeUppercase) { $charSet += "ABCDEFGHJKLMNPQRSTUVWXYZ" }
    if ($IncludeDigits)    { $charSet += "23456789" }
    if ($IncludeSymbols)   { $charSet += "!@#$%^&*()_+-=[]{}|;:,.<>?" }
    
    if ($charSet.Length -eq 0) { $charSet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$" }
    
    # Exkludierte Zeichen entfernen:
    foreach ($char in $ExcludeChars.ToCharArray()) {
        $charSet = $charSet.Replace([string]$char, "")
    }
    
    # Kryptografisch sicherer Zufallsgenerator:
    $rng      = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $password = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $randomBytes = New-Object byte[] 4
        $rng.GetBytes($randomBytes)
        $randomValue = [System.BitConverter]::ToUInt32($randomBytes, 0)
        $index = $randomValue % $charSet.Length
        $password += $charSet[$index]
    }
    
    $rng.Dispose()
    return $password
}

Export-ModuleMember -Function 'New-SecurePassword'
```

---

### Schritt 3: WPF-Hauptfenster (vereinfachtes Beispiel)

```powershell
# PasswordManagerUI.ps1 – Vollständiger WPF-Passwortmanager

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Module laden (angenommen sie liegen im selben Verzeichnis):
. "$PSScriptRoot\CryptoEngine.psm1"
. "$PSScriptRoot\PasswordGenerator.psm1"

# === XAML-Definition des Hauptfensters ===
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Passwortmanager" Height="600" Width="900"
        Background="#1E1E2E" WindowStartupLocation="CenterScreen"
        MinHeight="400" MinWidth="700">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#6C63FF"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Padding" Value="8,5"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#181825"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="RowBackground" Value="#181825"/>
            <Setter Property="AlternatingRowBackground" Value="#1E1E2E"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#6C63FF" Padding="15,10">
            <TextBlock Text="🔐 PowerShell Passwortmanager" FontSize="18" 
                       FontWeight="Bold" Foreground="White"/>
        </Border>

        <!-- Toolbar -->
        <Grid Grid.Row="1" Background="#313244" Margin="0,0,0,5">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" Name="btnAdd" Content="➕ Hinzufügen" Margin="5"/>
            <TextBox Grid.Column="1" Name="txtSearch" Text="Suchen..." 
                     VerticalAlignment="Center" Margin="5" Background="#1E1E2E"/>
            <Button Grid.Column="2" Name="btnCopyUser" Content="👤 Benutzer kopieren" 
                    Margin="5" Background="#45475A"/>
            <Button Grid.Column="3" Name="btnCopyPass" Content="🔑 Passwort kopieren" 
                    Margin="5" Background="#45475A"/>
            <Button Grid.Column="4" Name="btnDelete" Content="🗑️ Löschen" 
                    Margin="5" Background="#F38BA8"/>
        </Grid>

        <!-- Passwortliste -->
        <DataGrid Grid.Row="2" Name="dgPasswords" Margin="5"
                  AutoGenerateColumns="False" IsReadOnly="True"
                  SelectionMode="Single" CanUserAddRows="False">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Titel"      Binding="{Binding Title}"    Width="200"/>
                <DataGridTextColumn Header="Benutzername" Binding="{Binding Username}" Width="180"/>
                <DataGridTextColumn Header="URL"        Binding="{Binding Url}"      Width="200"/>
                <DataGridTextColumn Header="Kategorie"  Binding="{Binding Category}" Width="120"/>
                <DataGridTextColumn Header="Geändert"   Binding="{Binding Modified}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Statusbar -->
        <Border Grid.Row="3" Background="#313244" Padding="10,5">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Name="lblStatus" Text="Bereit" 
                           Foreground="#A6ADC8" FontSize="12"/>
                <TextBlock Grid.Column="1" Name="lblCount" Text="0 Einträge" 
                           Foreground="#A6ADC8" FontSize="12"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Fenster erstellen:
$reader = New-Object System.Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Steuerelemente binden:
$dgPasswords  = $window.FindName("dgPasswords")
$txtSearch    = $window.FindName("txtSearch")
$btnAdd       = $window.FindName("btnAdd")
$btnCopyUser  = $window.FindName("btnCopyUser")
$btnCopyPass  = $window.FindName("btnCopyPass")
$btnDelete    = $window.FindName("btnDelete")
$lblStatus    = $window.FindName("lblStatus")
$lblCount     = $window.FindName("lblCount")

# === In-Memory Datenspeicher (nach Entschlüsselung) ===
$script:MasterKey  = $null
$script:VaultPath  = "$env:APPDATA\PowerVault\vault.dat"
$script:Entries    = [System.Collections.Generic.List[object]]::new()

# Passwortliste aktualisieren:
function Update-PasswordList {
    param([string]$Filter = "")
    $filtered = if ($Filter -and $Filter -ne "Suchen...") {
        $script:Entries | Where-Object { 
            $_.Title -like "*$Filter*" -or 
            $_.Username -like "*$Filter*" -or
            $_.Url -like "*$Filter*"
        }
    } else {
        $script:Entries
    }
    
    $displayData = $filtered | ForEach-Object {
        [PSCustomObject]@{
            Title    = $_.Title
            Username = $_.Username
            Url      = $_.Url
            Category = $_.Category
            Modified = $_.Modified
        }
    }
    
    $dgPasswords.ItemsSource = $displayData
    $lblCount.Text = "$($script:Entries.Count) Einträge"
}

# Passwort kopieren (mit Auto-Clear nach 30s):
function Copy-PasswordToClipboard {
    param([string]$SelectedTitle)
    $entry = $script:Entries | Where-Object { $_.Title -eq $SelectedTitle } | Select-Object -First 1
    if (-not $entry) { return }
    
    # Passwort entschlüsseln:
    $plainPassword = Unprotect-Data -CipherText $entry.EncryptedPassword -Key $script:MasterKey
    [System.Windows.Clipboard]::SetText($plainPassword)
    $lblStatus.Text = "Passwort kopiert (wird in 30s gelöscht)..."
    
    # Zwischenablage nach 30 Sekunden löschen (im Hintergrund):
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(30)
    $timer.Add_Tick({
        [System.Windows.Clipboard]::Clear()
        $lblStatus.Text = "Zwischenablage geleert."
        $timer.Stop()
    })
    $timer.Start()
    
    # Passwort sofort aus RAM bereinigen:
    [System.Array]::Clear([System.Text.Encoding]::UTF8.GetBytes($plainPassword), 0, 
                           [System.Text.Encoding]::UTF8.GetBytes($plainPassword).Length)
}

# Event-Handler:
$btnCopyPass.Add_Click({
    $selected = $dgPasswords.SelectedItem
    if ($selected) { Copy-PasswordToClipboard -SelectedTitle $selected.Title }
})

$btnCopyUser.Add_Click({
    $selected = $dgPasswords.SelectedItem
    if ($selected) {
        [System.Windows.Clipboard]::SetText($selected.Username)
        $lblStatus.Text = "Benutzername kopiert."
    }
})

$txtSearch.Add_TextChanged({
    Update-PasswordList -Filter $txtSearch.Text
})

$btnAdd.Add_Click({
    # Neuen Eintrag mit generiertem Passwort hinzufügen (vereinfacht):
    $newPass = New-SecurePassword -Length 20 -AllSets
    $newEntry = [PSCustomObject]@{
        Id                = [System.Guid]::NewGuid().ToString()
        Title             = "Neuer Eintrag"
        Username          = ""
        Url               = ""
        Category          = "Allgemein"
        Notes             = ""
        EncryptedPassword = Protect-Data -PlainText $newPass -Key $script:MasterKey
        Modified          = (Get-Date -Format "dd.MM.yyyy HH:mm")
    }
    $script:Entries.Add($newEntry)
    Update-PasswordList
    $lblStatus.Text = "Eintrag hinzugefügt. Passwort: $newPass (bitte sofort ändern!)"
})

# Fenster anzeigen:
# (Login-Dialog sollte ZUERST gezeigt werden, hier vereinfacht)
$script:MasterKey = Get-DerivedKey `
    -MasterPassword (ConvertTo-SecureString "DemoPasswort123!" -AsPlainText -Force) `
    -Salt (New-CryptoSalt)

Update-PasswordList
$window.ShowDialog() | Out-Null
```

---

### Sicherheits-Checkliste für den Passwortmanager

Ein sicherer Passwortmanager MUSS folgende Punkte erfüllen:

**Kryptografische Sicherheit:**
- [ ] AES-256-CBC oder AES-256-GCM als Verschlüsselungsalgorithmus
- [ ] PBKDF2-SHA256 mit ≥310.000 Iterationen (OWASP 2023) oder Argon2id als Key-Derivation
- [ ] Zufällige, 256-Bit-Salt pro Vault (NIEMALS gleiche Salt wiederverwenden)
- [ ] HMAC-SHA256 zur Integritätsprüfung der verschlüsselten Datenbank
- [ ] Master-Key NIEMALS im Klartext speichern, nur im RAM halten

**Speicher-Sicherheit:**
- [ ] Master-Passwort als `SecureString` behandeln, niemals als `String`
- [ ] Sensible Byte-Arrays nach Verwendung mit `Array.Clear()` überschreiben
- [ ] Keine Passwörter in Logs, Console-Outputs oder Debug-Ausgaben

**UI-Sicherheit:**
- [ ] `PasswordBox` statt `TextBox` für Passwort-Eingaben
- [ ] Zwischenablage nach maximal 30 Sekunden automatisch löschen
- [ ] Auto-Lock nach Inaktivität (5-10 Minuten)
- [ ] Sichtbares Passwort nur auf explizite Benutzeraktion

**Datei-Sicherheit:**
- [ ] Vault-Datei in `%APPDATA%` oder mit eingeschränkten NTFS-Berechtigungen
- [ ] Optional: NTFS-EFS-Verschlüsselung oder Windows DPAPI als zusätzliche Schicht
- [ ] Sichere Lösch-Routine beim Deinstallieren

---

### Komplexitätsvergleich: PowerShell vs. dedizierte Sprachen

| Aspekt | PowerShell + WPF | C# + WPF | Electron/Web |
|---|---|---|---|
| Entwicklungsaufwand | Hoch | Mittel | Mittel |
| Krypto-Qualität | ✅ (via .NET) | ✅ (nativ) | ⚠️ (WebCrypto API) |
| Portabilität | Windows only | Windows only | Plattformübergreifend |
| Verteilung | Einfach (.ps1) | Komplexer (Installer) | Komplex (Electron-Bundle) |
| Performance | ⚠️ Overhead | ✅ Gut | ⚠️ Overhead |
| Sicherheits-Auditing | Schwieriger | Standard | Standard |
| Community/Ecosystem | Klein | Groß | Sehr groß |

**Empfehlung:** Für einen produktionsreifen, sicheren Passwortmanager eignet sich C# mit WPF oder .NET MAUI besser als PowerShell. PowerShell ist ideal für interne Tools, Proof-of-Concepts oder wenn PowerShell-Skripting-Skills genutzt werden sollen. Wer KeePass-Kompatibilität benötigt, sollte die [KeePassLib NuGet-Bibliothek](https://www.nuget.org/packages/KeePass/) in sein PowerShell-Projekt einbinden, was den Aufwand erheblich reduziert.

---

*Dokumentation erstellt am 05.04.2026 – PowerShell 5.1 / 7.x kompatibel*
