<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***

# PowerShell – Umfassende Technische Dokumentation

## 1. Externe Skripte einbinden – Dot-Sourcing

Das Einbinden externer PowerShell-Skripte als wiederverwendbare Code-Bibliotheken ist mit **Dot-Sourcing** möglich. Dabei wird dem Dateipfad ein Punkt gefolgt von einem Leerzeichen vorangestellt.

### Grundprinzip

Wenn du ein Skript normal ausführst (`& .\functions.ps1`), landen alle darin definierten Funktionen und Variablen im sogenannten **Script-Scope** – und werden nach Beendigung des Skripts verworfen. Dot-Sourcing hingegen lädt alles direkt in den **aktuellen Scope**, sodass Funktionen und Variablen anschließend vollständig verfügbar bleiben.

```powershell
# Normale Ausführung – Funktionen nicht verfügbar nach Abschluss
& .\helpers.ps1

# Dot-Sourcing – Funktionen bleiben im aktuellen Scope verfügbar
. .\helpers.ps1

# Mit absolutem Pfad
. "C:\Scripts\MyLibrary.ps1"

# Relativ zum Skriptverzeichnis (Best Practice!)
. "$PSScriptRoot\helpers.ps1"
```


### Praxisbeispiel

**helpers.ps1** (externe Datei):

```powershell
function Get-Greeting {
    param([string]$Name)
    return "Hallo, $Name!"
}

function Write-LogEntry {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message" -ForegroundColor Cyan
}

$global:AppVersion = "1.0.0"
```

**main.ps1** (Hauptskript):

```powershell
# Bibliothek einbinden
. "$PSScriptRoot\helpers.ps1"

# Jetzt sind alle Funktionen verfügbar
$msg = Get-Greeting -Name "Max"
Write-Host $msg

Write-LogEntry -Message "Skript gestartet" -Level "INFO"
Write-Host "Version: $AppVersion"
```


### Dot-Sourcing vs. Module vs. `Invoke-Expression`

| Methode | Scope-Verhalten | Geeignet für | Nachteile |
| :-- | :-- | :-- | :-- |
| **Dot-Sourcing** (`. .\file.ps1`) | Direkt in aktuellen Scope | Einfache Code-Bibliotheken, Rapid Dev | Kein Packaging, kein Versioning |
| **Module** (`Import-Module`) | Eigener Modul-Scope, expliziter Export | Wiederverwendbare Tools, Teams | Höherer Aufwand beim Erstellen |
| **`& .\file.ps1`** | Script-Scope, danach weg | Ausführen ohne Import-Bedarf | Kein Zugriff auf Funktionen danach |
| **`Invoke-Expression`** | Aktueller Scope | Dynamischer Code | Sicherheitsrisiko, kaum empfohlen |

`$PSScriptRoot` ist dabei immer der empfohlene Weg, da er immer auf das Verzeichnis der aktuell ausgeführten Skriptdatei zeigt – unabhängig davon, von wo du das Skript aufrufst.

### Fehlerbehandlung beim Dot-Sourcing

```powershell
$libPath = "$PSScriptRoot\helpers.ps1"

if (Test-Path $libPath) {
    . $libPath
} else {
    throw "Bibliotheksdatei nicht gefunden: $libPath"
}
```


***

## 2. PowerShell-Module nur für Variablen

Ja, das ist technisch vollständig möglich und hat durchaus sinnvolle Anwendungsfälle. Variablen werden in einem `.psm1`-Modul definiert und über `Export-ModuleMember -Variable` explizit exportiert.

### Wichtige Regel

Standardmäßig exportiert ein Modul **nur Funktionen und Aliases – niemals Variablen automatisch**. Damit Variablen aus einem Modul im aufrufenden Skript sichtbar werden, müssen sie explizit deklariert werden:

```powershell
# config.psm1 – Nur Konfigurationsvariablen
$AppName        = "MeinTool"
$AppVersion     = "2.1.0"
$AppLogPath     = "C:\Logs\MeinTool"
$MaxRetries     = 3
$DefaultTimeout = 30

$DBConfig = @{
    Server   = "localhost"
    Port     = 5432
    Database = "AppDB"
}

# Alle Variablen exportieren
Export-ModuleMember -Variable AppName, AppVersion, AppLogPath, MaxRetries, DefaultTimeout, DBConfig
```

Verwendung im Hauptskript:

```powershell
Import-Module "$PSScriptRoot\config.psm1"

Write-Host "Anwendung: $AppName v$AppVersion"
Write-Host "Log-Pfad: $AppLogPath"
Write-Host "DB-Server: $($DBConfig.Server)"
```


### Alternativ: `$global:` Scope Modifier

Eine einfachere Alternative, ohne Modul-Overhead, ist die explizite Verwendung des `$global:`-Präfixes direkt in einem Skript:

```powershell
# config.ps1 – als Dot-Source einbinden
$global:AppName     = "MeinTool"
$global:AppVersion  = "2.1.0"
$global:MaxRetries  = 3
$global:DBConfig    = @{ Server = "localhost"; Port = 5432 }
```

```powershell
# Hauptskript
. "$PSScriptRoot\config.ps1"
Write-Host $global:AppName  # "MeinTool"
```


### Typische Use Cases für Konfigurations-Module

- **Unternehmensweite Skript-Konstanten**: Servernamen, Pfade, Ports zentral definieren, sodass alle Skripte auf dieselbe Konfigurationsquelle zurückgreifen
- **Umgebungsspezifische Parameter**: Unterschiedliche Konfigurationsmodule für DEV/TEST/PROD laden
- **Mehrsprachige Ressourcen (Localization)**: Textstrings je nach Systemsprache aus einem Variablenmodul laden
- **Gemeinsame Enum-Werte**: Statuskonstanten (`$STATUS_OK = 0`, `$STATUS_ERROR = 1`) projektweit teilen

```powershell
# Umgebungsabhängige Konfiguration laden
$env = $env:DEPLOY_ENV ?? "dev"
Import-Module "$PSScriptRoot\config\config-$env.psm1"
```


***

## 3. Persistenter lokaler Datenspeicher in PowerShell

Einen Browser-ähnlichen LocalStorage gibt es nativ in PowerShell nicht. Es existieren jedoch mehrere robuste und praktikable Alternativen je nach Anforderung.

### Methode 1: JSON-Datei (einfachste Lösung)

JSON ist der de-facto Standard für leichtgewichtige persistente Speicherung in PowerShell-Skripten. Die Daten werden im `AppData`-Verzeichnis des Benutzers gespeichert.

```powershell
# LocalStorage-Klasse in PowerShell
class LocalStorage {
    [string]$StorePath

    LocalStorage([string]$AppName) {
        $dir = "$env:APPDATA\$AppName"
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $this.StorePath = "$dir\storage.json"
    }

    [void] Set([string]$Key, $Value) {
        $data = $this.GetAll()
        $data[$Key] = $Value
        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $this.StorePath -Encoding UTF8
    }

    [object] Get([string]$Key) {
        $data = $this.GetAll()
        return $data[$Key]
    }

    [hashtable] GetAll() {
        if (Test-Path $this.StorePath) {
            return Get-Content $this.StorePath -Raw | ConvertFrom-Json -AsHashtable
        }
        return @{}
    }

    [void] Remove([string]$Key) {
        $data = $this.GetAll()
        $data.Remove($Key)
        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $this.StorePath -Encoding UTF8
    }

    [void] Clear() {
        @{} | ConvertTo-Json | Set-Content -Path $this.StorePath -Encoding UTF8
    }
}

# Verwendung
$storage = [LocalStorage]::new("MeineApp")
$storage.Set("theme", "dark")
$storage.Set("lastUser", "max.mustermann")
$storage.Set("windowSize", @{ Width = 1280; Height = 720 })

$theme = $storage.Get("theme")
Write-Host "Theme: $theme"
```


### Methode 2: Windows Registry

Die Registry eignet sich für kleine Konfigurationswerte, die maschinenweit oder benutzerweit gelten sollen:

```powershell
function Set-RegistryValue {
    param([string]$AppName, [string]$Key, [string]$Value)
    $regPath = "HKCU:\Software\$AppName"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name $Key -Value $Value
}

function Get-RegistryValue {
    param([string]$AppName, [string]$Key)
    $regPath = "HKCU:\Software\$AppName"
    return (Get-ItemProperty -Path $regPath -Name $Key -ErrorAction SilentlyContinue).$Key
}

# Verwendung
Set-RegistryValue -AppName "MeineApp" -Key "Theme" -Value "dark"
$theme = Get-RegistryValue -AppName "MeineApp" -Key "Theme"
```


### Methode 3: XML (für komplexe strukturierte Daten)

```powershell
$settingsPath = "$env:APPDATA\MeineApp\settings.xml"

# Speichern
$settings = [PSCustomObject]@{
    Theme      = "dark"
    Language   = "de-DE"
    LastLogin  = (Get-Date).ToString("o")
}
$settings | Export-Clixml -Path $settingsPath

# Laden
$loaded = Import-Clixml -Path $settingsPath
Write-Host $loaded.Theme
```


### Methode 4: SQLite (für strukturierte Daten mit Abfragen)

Für größere Datenmengen mit Abfrageanforderungen bietet sich SQLite über das NuGet-Paket `System.Data.SQLite` an:

```powershell
# NuGet-Paket laden (einmalig)
# Install-Package System.Data.SQLite -Destination "$env:APPDATA\PSLibs"

Add-Type -Path "$env:APPDATA\PSLibs\System.Data.SQLite.1.0.118.0\lib\net46\System.Data.SQLite.dll"

$dbPath = "$env:APPDATA\MeineApp\app.db"
$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
$conn.Open()

# Tabelle anlegen
$cmd = $conn.CreateCommand()
$cmd.CommandText = "CREATE TABLE IF NOT EXISTS KeyValue (Key TEXT PRIMARY KEY, Value TEXT, UpdatedAt TEXT)"
$cmd.ExecuteNonQuery()

# Wert speichern
$cmd.CommandText = "INSERT OR REPLACE INTO KeyValue VALUES (@k, @v, @t)"
$cmd.Parameters.AddWithValue("@k", "theme")
$cmd.Parameters.AddWithValue("@v", "dark")
$cmd.Parameters.AddWithValue("@t", (Get-Date).ToString("o"))
$cmd.ExecuteNonQuery()

$conn.Close()
```


***

## 4. Eigene Datenbank / Mini-Datenbankserver

### Eigene In-Process-Datenbank in PowerShell

Eine vollständige, eigene Datenbank lässt sich in PowerShell als Klasse realisieren. Dies eignet sich für Szenarien, wo keine externe Abhängigkeit erwünscht ist:

```powershell
class SimpleDB {
    hidden [hashtable]$_tables  = @{}
    hidden [string]$_dbFile

    SimpleDB([string]$FilePath) {
        $this._dbFile = $FilePath
        if (Test-Path $FilePath) { $this._load() }
    }

    [void] CreateTable([string]$Name) {
        if (-not $this._tables.ContainsKey($Name)) {
            $this._tables[$Name] = [System.Collections.Generic.List[hashtable]]::new()
            $this._save()
        }
    }

    [void] Insert([string]$Table, [hashtable]$Record) {
        if (-not $Record.ContainsKey("_id")) {
            $Record["_id"] = [guid]::NewGuid().ToString()
        }
        $Record["_createdAt"] = (Get-Date).ToString("o")
        $this._tables[$Table].Add($Record)
        $this._save()
    }

    [object[]] Select([string]$Table, [scriptblock]$Filter = { $true }) {
        return $this._tables[$Table] | Where-Object $Filter
    }

    [void] Update([string]$Table, [string]$Id, [hashtable]$Updates) {
        $record = $this._tables[$Table] | Where-Object { $_["_id"] -eq $Id } | Select-Object -First 1
        if ($record) {
            foreach ($key in $Updates.Keys) { $record[$key] = $Updates[$key] }
            $record["_updatedAt"] = (Get-Date).ToString("o")
            $this._save()
        }
    }

    [void] Delete([string]$Table, [string]$Id) {
        $item = $this._tables[$Table] | Where-Object { $_["_id"] -eq $Id }
        if ($item) { $this._tables[$Table].Remove($item) | Out-Null; $this._save() }
    }

    hidden [void] _save() {
        $this._tables | ConvertTo-Json -Depth 20 | 
            Set-Content -Path $this._dbFile -Encoding UTF8
    }

    hidden [void] _load() {
        $raw = Get-Content $this._dbFile -Raw | ConvertFrom-Json -AsHashtable
        foreach ($table in $raw.Keys) {
            $this._tables[$table] = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($row in $raw[$table]) { $this._tables[$table].Add($row) }
        }
    }
}

# Verwendung
$db = [SimpleDB]::new("$env:APPDATA\MeineApp\data.db")
$db.CreateTable("users")
$db.Insert("users", @{ Name = "Max Mustermann"; Email = "max@example.com"; Role = "admin" })

$admins = $db.Select("users", { $_["Role"] -eq "admin" })
Write-Host "Admins gefunden: $($admins.Count)"
```


### Einfachere Alternative: `ConvertTo-Json`/`Import-Clixml` mit Index-Datei

Für die meisten Anwendungsfälle ist eine JSON-basierte Flat-File-Datenbank mit einer Index-Hashtable die pragmatischste Lösung:

```powershell
# Einfaches Key-Value Store Modul
$script:_store = @{}
$script:_storePath = "$env:APPDATA\MeineApp\kvstore.json"

function Initialize-Store {
    if (Test-Path $script:_storePath) {
        $script:_store = Get-Content $script:_storePath -Raw | 
            ConvertFrom-Json -AsHashtable
    }
}

function Set-StoreValue([string]$Key, $Value) {
    $script:_store[$Key] = $Value
    $script:_store | ConvertTo-Json -Depth 10 | 
        Set-Content $script:_storePath -Encoding UTF8
}

function Get-StoreValue([string]$Key) { return $script:_store[$Key] }
```


***

## 5. Externe Programme als Administrator oder anderer Benutzer starten

### Als Administrator ausführen (`-Verb RunAs`)

`Start-Process` mit dem Parameter `-Verb RunAs` löst den UAC-Dialog aus und startet das Programm mit erhöhten Rechten:

```powershell
# Notepad++ als Administrator starten
Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" -Verb RunAs

# Mit bestimmter Datei öffnen
Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" `
              -ArgumentList "C:\wichtige-datei.txt" `
              -Verb RunAs

# PowerShell-Instanz selbst erhöhen
Start-Process powershell.exe -Verb RunAs -WorkingDirectory (Get-Location)

# Warten bis das Programm beendet ist
Start-Process -FilePath "notepad.exe" -Verb RunAs -Wait
```


### Prüfen ob das aktuelle Skript bereits als Admin läuft

```powershell
function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Auto-Elevation: Skript startet sich selbst als Admin neu
if (-not (Test-IsAdmin)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $args -Verb RunAs
    exit
}
Write-Host "Läuft als Administrator!" -ForegroundColor Green
```


### Als bestimmter Benutzer starten (`-Credential`)

Mit dem `-Credential`-Parameter kann ein beliebiger Benutzer angegeben werden:

```powershell
# Interaktive Eingabe der Credentials (öffnet Dialog)
$cred = Get-Credential -Message "Bitte Administratorkonto eingeben"

# Notepad++ als anderen Benutzer starten
Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" `
              -Credential $cred

# Powershell-Skript als anderer Benutzer ausführen
Start-Process powershell.exe `
    -ArgumentList "-NoProfile -File C:\Scripts\admin-task.ps1" `
    -Credential $cred `
    -NoNewWindow

# Credentials ohne Dialog (für Automatisierung, z.B. in CI/CD)
$password  = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
$cred      = New-Object System.Management.Automation.PSCredential("DOMAIN\adminuser", $password)
Start-Process "notepad.exe" -Credential $cred
```


### Als Admin UND als anderer Benutzer (kombiniert)

Um ein Programm als bestimmter Benutzer **und** mit erhöhten Rechten zu starten, muss eine doppelte `Start-Process`-Schachtelung verwendet werden:

```powershell
$cred = Get-Credential -Message "Admin-Konto eingeben"

Start-Process powershell.exe `
    -Credential $cred `
    -NoNewWindow `
    -ArgumentList "Start-Process 'C:\Program Files\Notepad++\notepad++.exe' -Verb RunAs"
```


### Externes Programm mit `runas.exe` (klassisch)

```powershell
# Klassische CMD-Alternative
runas.exe /user:DOMAIN\Administrator "notepad++.exe"

# Mit gespeicherten Credentials (/savecred - Vorsicht: Sicherheitsrisiko!)
runas.exe /user:Administrator /savecred "notepad++.exe"
```


***

## 6. Eigener Passwortmanager mit PowerShell, WPF und .NET

### Komplexitätsbewertung

Einen **funktionalen und sicheren** Passwortmanager wie KeePass in PowerShell + WPF/XAML zu bauen ist **ambitioniert, aber durchaus machbar**. Die Komplexität liegt weniger im UI (WPF ist gut aus PowerShell nutzbar), sondern in der kryptografischen Korrektheit. Folgende Bereiche müssen abgedeckt werden:

**Aufwandsabschätzung:**


| Bereich | Aufwand | Technologie |
| :-- | :-- | :-- |
| WPF/XAML UI | Mittel | XAML, WPF Controls |
| AES-256 Verschlüsselung | Mittel | .NET `System.Security.Cryptography` |
| Master-Passwort / Key Derivation | Mittel-Hoch | PBKDF2 / `Rfc2898DeriveBytes` |
| Datenbankformat (verschlüsselte JSON/XML) | Mittel | `ConvertTo-Json` + AES |
| Clipboard-Handling (Auto-Clear) | Gering | `[Windows.Forms.Clipboard]` |
| Passwortgenerator | Gering | `[System.Web.Security.Membership]` |
| Auto-Lock / Session Timeout | Mittel | `DispatcherTimer` |
| DPAPI-Schutz (optional) | Gering | `[Security.Cryptography.ProtectedData]` |
| Portabilität (USB-Stick) | Gering | Relative Pfade |

### Kryptografische Kernarchitektur

Das Master-Passwort darf **niemals im Klartext** gespeichert werden. Der korrekte Weg ist:

1. **PBKDF2** (Password-Based Key Derivation Function 2) mit Rfc2898DeriveBytes, um aus dem Master-Passwort einen 256-Bit AES-Schlüssel abzuleiten
2. Alle Einträge werden **AES-256-CBC** verschlüsselt in einer JSON-Datei gespeichert
3. Beim Öffnen: Master-Passwort eingeben → Schlüssel ableiten → Datei entschlüsseln
```powershell
Add-Type -AssemblyName System.Security

# ── Schlüssel aus Master-Passwort ableiten (PBKDF2) ──────────────────────
function Derive-Key {
    param(
        [SecureString]$MasterPassword,
        [byte[]]$Salt,
        [int]$Iterations = 200000  # Mindestens 100.000 für Sicherheit
    )
    $bstr  = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($MasterPassword)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    $derive = New-Object Security.Cryptography.Rfc2898DeriveBytes(
        $plain,
        $Salt,
        $Iterations,
        [Security.Cryptography.HashAlgorithmName]::SHA256
    )
    $plain = $null  # Klartext sofort löschen!
    return $derive.GetBytes(32)  # 256-Bit Schlüssel
}

# ── Vault verschlüsseln ───────────────────────────────────────────────────
function Protect-Vault {
    param([hashtable]$Data, [byte[]]$Key)
    
    $json  = $Data | ConvertTo-Json -Depth 10
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)

    $aes = [Security.Cryptography.Aes]::Create()
    $aes.KeySize   = 256
    $aes.BlockSize = 128
    $aes.Mode      = [Security.Cryptography.CipherMode]::CBC
    $aes.Padding   = [Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key       = $Key
    $aes.GenerateIV()
    $iv = $aes.IV

    $enc    = $aes.CreateEncryptor()
    $stream = New-Object IO.MemoryStream
    $crypto = New-Object Security.Cryptography.CryptoStream($stream, $enc, [Security.Cryptography.CryptoStreamMode]::Write)
    $crypto.Write($bytes, 0, $bytes.Length)
    $crypto.FlushFinalBlock()
    $encrypted = $stream.ToArray()
    
    $aes.Dispose(); $stream.Dispose(); $crypto.Dispose()
    
    # IV + verschlüsselte Daten kombinieren und Base64-codieren
    $combined = $iv + $encrypted
    return [Convert]::ToBase64String($combined)
}

# ── Vault entschlüsseln ───────────────────────────────────────────────────
function Unprotect-Vault {
    param([string]$EncryptedData, [byte[]]$Key)
    
    $combined  = [Convert]::FromBase64String($EncryptedData)
    $iv        = $combined[0..15]
    $encrypted = $combined[16..($combined.Length - 1)]

    $aes = [Security.Cryptography.Aes]::Create()
    $aes.KeySize   = 256
    $aes.Mode      = [Security.Cryptography.CipherMode]::CBC
    $aes.Padding   = [Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key       = $Key
    $aes.IV        = $iv

    $dec    = $aes.CreateDecryptor()
    $stream = New-Object IO.MemoryStream(,$encrypted)
    $crypto = New-Object Security.Cryptography.CryptoStream($stream, $dec, [Security.Cryptography.CryptoStreamMode]::Read)
    $reader = New-Object IO.StreamReader($crypto)
    $json   = $reader.ReadToEnd()
    
    $aes.Dispose(); $stream.Dispose()
    return $json | ConvertFrom-Json -AsHashtable
}
```


### Datenbankstruktur (vault.dat)

```json
{
  "version": "1.0",
  "salt": "BASE64_ENCODED_SALT_32_BYTES",
  "iterations": 200000,
  "hmac": "BASE64_HMAC_SHA256_ZUR_INTEGRITÄTSPRÜFUNG",
  "entries": "AES256_CBC_ENCRYPTED_BASE64_BLOB"
}
```

Innerhalb des entschlüsselten Blobs:

```json
[
  {
    "id": "uuid-v4",
    "title": "GitHub",
    "username": "max.mustermann",
    "password": "SuperSecretP@ss!",
    "url": "https://github.com",
    "notes": "2FA aktiv!",
    "tags": ["dev", "git"],
    "createdAt": "2026-04-01T12:00:00",
    "modifiedAt": "2026-04-05T08:30:00"
  }
]
```


### WPF/XAML UI-Grundstruktur

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerVault – Passwortmanager"
        Width="900" Height="600"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2E">

    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Padding" Value="5"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- Sidebar mit Einträgen -->
        <StackPanel Grid.Column="0" Background="#181825" Margin="0">
            <TextBlock Text="🔐 PowerVault" FontSize="18" FontWeight="Bold"
                       Foreground="#CBA6F7" Margin="15,15,15,10"/>
            <TextBox x:Name="SearchBox" Text="" Margin="10,5"
                     Background="#313244" Foreground="#CDD6F4"
                     BorderBrush="#45475A" Padding="8"
                     Tag="Suchen..."/>
            <Button Content="+ Neuer Eintrag" x:Name="BtnNewEntry"
                    Margin="10,5" Background="#A6E3A1" Foreground="#1E1E2E"/>
            <ListBox x:Name="EntryList" Background="Transparent"
                     BorderThickness="0" Margin="5"
                     Foreground="#CDD6F4" Height="400"/>
        </StackPanel>

        <!-- Detailbereich -->
        <Grid Grid.Column="1" Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Text="Titel:" Foreground="#A6ADC8" Margin="0,5"/>
            <TextBox   Grid.Row="1" x:Name="TxtTitle" Margin="0,0,0,10"/>
            
            <TextBlock Grid.Row="2" Text="Benutzername:" Foreground="#A6ADC8" Margin="0,5"/>
            <TextBox   Grid.Row="3" x:Name="TxtUsername" Margin="0,0,0,10"/>

            <!-- Passwortfeld mit Sichtbarkeits-Toggle -->
            <StackPanel Grid.Row="4" Orientation="Horizontal">
                <PasswordBox x:Name="PwdBox" Width="300" Background="#313244"
                             Foreground="#CDD6F4" BorderBrush="#45475A" Padding="5"/>
                <Button Content="👁" x:Name="BtnTogglePwd" Width="35" Margin="5,0"/>
                <Button Content="🔄" x:Name="BtnGenPwd" Width="35" Margin="5,0"
                        ToolTip="Sicheres Passwort generieren"/>
                <Button Content="📋" x:Name="BtnCopyPwd" Width="35" Margin="5,0"
                        ToolTip="In Zwischenablage kopieren (30s)"/>
            </StackPanel>

            <StackPanel Grid.Row="5" Orientation="Horizontal" 
                        HorizontalAlignment="Right" Margin="0,20,0,0">
                <Button Content="💾 Speichern" x:Name="BtnSave" 
                        Background="#A6E3A1" Foreground="#1E1E2E" Margin="5"/>
                <Button Content="🗑 Löschen" x:Name="BtnDelete"
                        Background="#F38BA8" Foreground="#1E1E2E" Margin="5"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

$reader  = [Xml.XmlNodeReader]::new($xaml)
$window  = [Windows.Markup.XamlReader]::Load($reader)
```


### Passwortgenerator

```powershell
function New-SecurePassword {
    param(
        [int]$Length       = 20,
        [bool]$Uppercase   = $true,
        [bool]$Digits      = $true,
        [bool]$Symbols     = $true
    )
    $chars  = [char[]]('abcdefghijklmnopqrstuvwxyz')
    if ($Uppercase) { $chars += [char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ') }
    if ($Digits)    { $chars += [char[]]('0123456789') }
    if ($Symbols)   { $chars += [char[]]('!@#$%^&*()_+-=[]{}|;:,.<>?') }
    
    $rng      = [Security.Cryptography.RandomNumberGenerator]::Create()
    $password = [char[]]::new($Length)
    $buffer   = [byte[]]::new(1)
    
    for ($i = 0; $i -lt $Length; $i++) {
        do {
            $rng.GetBytes($buffer)
            $idx = $buffer[^1_0]
        } while ($idx -ge (256 - (256 % $chars.Length)))  # Uniform Distribution!
        $password[$i] = $chars[$idx % $chars.Length]
    }
    return [string]::new($password)
}
```


### Clipboard Auto-Clear

```powershell
# Passwort in Zwischenablage – automatisch nach 30 Sekunden löschen
$BtnCopyPwd.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.Clipboard]::SetText($PwdBox.Password)
    
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(30)
    $timer.Add_Tick({
        [Windows.Forms.Clipboard]::Clear()
        $timer.Stop()
        [System.Windows.MessageBox]::Show("Zwischenablage wurde geleert.", "Sicherheitshinweis")
    })
    $timer.Start()
})
```


### Sicherheitsempfehlungen für den Passwortmanager

- **PBKDF2 mit SHA-256, mindestens 200.000 Iterationen** oder besser Argon2 (via externer Library)
- **HMAC-SHA256** zur Integritätsprüfung der verschlüsselten Datei (verhindert Tampering)
- **Kein SecureString** für neue Entwicklungen empfohlen – stattdessen `char[]` mit explizitem Zero-Fill nach Verwendung
- **Auto-Lock** nach Inaktivität (5–10 Minuten) via `DispatcherTimer`
- **Kein Logging** von Passwörtern oder Master-Passwort-Derivaten
- **Salt**: 32 zufällige Bytes, generiert via `RandomNumberGenerator`, nie hardcodiert
- **Memory-Protection**: Sensible Daten nach Verwendung mit `Array.Clear()` aus dem Heap überschreiben


### Gesamtarchitektur des Projekts

```
PowerVault/
├── PowerVault.ps1          # Einstiegspunkt, WPF-Fenster laden
├── modules/
│   ├── Crypto.psm1         # AES-256, PBKDF2, HMAC
│   ├── VaultDB.psm1        # Datenbankoperationen (CRUD)
│   ├── UI.psm1             # WPF Event-Handler
│   └── PasswordGen.psm1    # Passwortgenerator
├── resources/
│   ├── MainWindow.xaml     # UI-Layout ausgelagert
│   └── Styles.xaml         # WPF-Styles / Themes
└── data/
    └── vault.dat           # Verschlüsselte Datenbank
```


### Realisierbarkeit im Vergleich zu KeePass

KeePass und Bitwarden sind über viele Jahre gewachsene, auditierte Produkte. Für den **privaten Gebrauch** oder als **Lernprojekt** ist ein PowerShell-basierter Passwortmanager mit AES-256 und PBKDF2 absolut realisierbar und kann einen respektablen Sicherheitsstandard erreichen. Für den **professionellen Unternehmenseinsatz** sollte die kryptografische Implementierung durch einen externen Audit überprüft werden – keine selbstentwickelte Krypto-Lösung sollte blindlings als produktionsreif betrachtet werden, ohne unabhängige Überprüfung.

***

