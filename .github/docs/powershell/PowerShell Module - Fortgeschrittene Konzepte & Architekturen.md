# PowerShell Module – Fortgeschrittene Konzepte & Architekturen

> Eine umfassende Dokumentation zu Modulstruktur, Ladeverhalten, Runspaces, IPC und erweiterten Konfigurationsmustern.

***

## Inhaltsübersicht

1. [Modulstruktur: psm1, Public- und Private-Ordner](#1-modulstruktur-psm1-public--und-private-ordner)
2. [ScriptsToProcess: Ausführungsreihenfolge, Fehlerverhalten und Ladeabbruch](#2-scriptstoprocess-ausführungsreihenfolge-fehlerverhalten-und-ladeabbruch)
3. [Konfiguration beim Modulstart: Interaktiv und grafisch per WPF](#3-konfiguration-beim-modulstart-interaktiv-und-grafisch-per-wpf)
4. [Parameter in PowerShell Modulen](#4-parameter-in-powershell-modulen)
5. [Runspaces in PowerShell Modulen](#5-runspaces-in-powershell-modulen)
6. [Named Pipes in PowerShell Modulen](#6-named-pipes-in-powershell-modulen)
7. [Externes Prozess-Management: Modul in separatem Prozess & IPC via Named Pipes](#7-externes-prozess-management-modul-in-separatem-prozess--ipc-via-named-pipes)

***

## 1. Modulstruktur: psm1, Public- und Private-Ordner

### 1.1 Was ist eigentlich der Unterschied zwischen psm1 und separaten ps1-Dateien?

Ein PowerShell-Skriptmodul besteht im Kern aus **drei möglichen Schichten**:

| Datei / Ort | Rolle | Sichtbarkeit |
|---|---|---|
| `MeinModul.psm1` | Root Module – Einstiegspunkt des Moduls | Modulscope |
| `Public/*.ps1` | Exportierte Funktionen (via dot-sourcing) | Für Aufrufer sichtbar |
| `Private/*.ps1` | Interne Hilfsfunktionen | Nur im Modulscope sichtbar |

Das eigentliche Modul-Verhalten – sprich: isolierter Scope, Kontrolle über exportierte Befehle, Scoping-Regeln – wird **ausschließlich** durch die `.psm1`-Datei definiert. Eine `.ps1`-Datei, die irgendwo auf der Festplatte liegt, ist technisch gesehen nur ein Skript. Sie bekommt keine der Modul-spezifischen Eigenschaften (kein eigener isolierter Namespace, keine automatische Export-Kontrolle), solange sie nicht **vom Modul aus dot-sourced** wird.[^1][^2]

### 1.2 Wie funktioniert das Laden von Public/Private-Ordnern?

Die `psm1`-Datei ist der **Dirigent**: Sie ist für das Dot-Sourcing aller PS1-Dateien aus den Unterordnern verantwortlich. Für sich allein hat eine PS1-Datei im `Public`-Ordner keinerlei Wirkung – sie wird nicht automatisch geladen.

Das typische Muster in der `psm1`-Datei sieht so aus:

```powershell
# Alle Private-Funktionen laden (nur im Modul sichtbar)
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 -Recurse
foreach ($func in $PrivateFunctions) {
    . $func.FullName
}

# Alle Public-Funktionen laden und exportieren
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 -Recurse
foreach ($func in $PublicFunctions) {
    . $func.FullName
}

# Nur Public-Funktionen nach außen exportieren
Export-ModuleMember -Function ($PublicFunctions.BaseName)
```

Der Schlüssel liegt beim Dot-Sourcing (`. $func.FullName`): Alles, was innerhalb der `psm1` dot-sourced wird, landet im **Modulscope**. Funktionen aus dem `Private`-Ordner werden zwar geladen und sind innerhalb des Moduls nutzbar, aber da sie nicht in `Export-ModuleMember` oder `FunctionsToExport` im Manifest aufgeführt sind, bleiben sie für den Aufrufer unsichtbar.[^3][^4][^5]

### 1.3 Kann die psm1 bereits auf Public- und Private-Funktionen zugreifen?

**Ja, unbedingt.** Das ist sogar das Kernprinzip. Sobald eine Funktion in der `psm1` dot-sourced wurde (egal ob sie aus `Public/` oder `Private/` kommt), existiert sie im Modulscope und ist für alle nachfolgenden Codezeilen in der `psm1` sowie für alle anderen Modulfunktionen verfügbar.

Die Reihenfolge beim Laden spielt dabei eine Rolle. Es ist Best Practice, zuerst die `Private`-Funktionen zu laden, dann die `Public`-Funktionen. Wenn eine `Public`-Funktion eine `Private`-Funktion aufruft, muss die Private-Funktion zum Zeitpunkt des Aufrufs bereits im Scope existieren. Beim Laden reicht es, wenn sie beim ersten tatsächlichen **Aufruf** verfügbar ist (nicht schon beim Dot-Sourcing der Public-Funktion), aber die sauberere Praxis ist die sequenzielle Reihenfolge.[^6]

```powershell
# psm1 – Korrekte Ladereihenfolge
. "$PSScriptRoot\Private\ConvertTo-InternalFormat.ps1"   # Private zuerst
. "$PSScriptRoot\Public\Get-MeinErgebnis.ps1"            # Public danach

# Get-MeinErgebnis.ps1 kann intern ConvertTo-InternalFormat aufrufen ✓
```

### 1.4 Unterschied: Funktion direkt in psm1 vs. Funktion in separater ps1-Datei

Technisch ist es **dasselbe**. Eine Funktion, die direkt in der `psm1` steht, verhält sich identisch zu einer Funktion, die dot-sourced wurde – beide landen im Modulscope. Der Unterschied liegt rein in Wartbarkeit und Projektstruktur:[^2]

| Aspekt | Funktion direkt in psm1 | Funktion in separater ps1 |
|---|---|---|
| Scope | Modulscope | Modulscope (nach Dot-Sourcing) |
| Exportierbar | Ja (via Export-ModuleMember) | Ja (via Export-ModuleMember) |
| Wartbarkeit | Schlecht bei vielen Funktionen | Sehr gut – eine Funktion pro Datei |
| Git-Diff | Unübersichtlich | Klare Commits pro Funktion |
| Build-Prozess | Kein Build nötig | Kann zu einer einzelnen psm1 kompiliert werden |
| IDE-Support | Alle Funktionen in einer Datei | Bessere Navigation, Intellisense |

Projekte wie Plaster, PSFramework oder viele Open-Source-Module nutzen konsequent das Multi-File-Modell und kombinieren es mit einem Build-Schritt (z.B. via `Invoke-Build` oder `psake`), der alle PS1-Dateien zu einer einzigen großen `psm1` zusammenfasst. Das ermöglicht sowohl saubere Entwicklung als auch optimale Deploymentperformance.[^7][^6]

***

## 2. ScriptsToProcess: Ausführungsreihenfolge, Fehlerverhalten und Ladeabbruch

### 2.1 Was sind ScriptsToProcess?

`ScriptsToProcess` ist ein Schlüssel im Modulmanifest (`.psd1`). Dort angegebene `.ps1`-Skripte werden **vor** dem eigentlichen Modul-Ladevorgang ausgeführt – also bevor die `psm1` geladen wird. Sie laufen nicht im Modulscope, sondern im **Caller's Session State**, d.h. im Scope des Aufrufers, der `Import-Module` ausgeführt hat.[^8][^9]

```powershell
# In MeinModul.psd1:
ScriptsToProcess = @(
    'Scripts\Check-Prerequisites.ps1',
    'Scripts\Initialize-Environment.ps1'
)
```

**Typische Verwendungszwecke:**
- Prüfen von Voraussetzungen (z.B. .NET-Version, Betriebssystemversion, Administratorrechte)
- Setzen von Umgebungsvariablen im Aufrufer-Scope
- Installieren fehlender Abhängigkeiten
- Registrieren von Typen-Accelerators oder benutzerdefinierten Formatierungsdaten

### 2.2 Werden ScriptsToProcess sequenziell oder parallel ausgeführt?

**Immer sequenziell** – und das ist auch der einzig mögliche Modus. PowerShell verarbeitet das Manifest von oben nach unten: Die Skripte werden in der Reihenfolge ausgeführt, in der sie im Array stehen. Es gibt keinen parallelen Lademechanismus für `ScriptsToProcess`.[^10]

Das hat praktische Konsequenzen: Wenn `Initialize-Environment.ps1` auf Variablen oder Ergebnissen aus `Check-Prerequisites.ps1` aufbaut, ist das absolut sicher, weil das erste Skript garantiert fertig ist, bevor das zweite startet.[^10]

```powershell
# Reihenfolge im Array = Ausführungsreihenfolge
ScriptsToProcess = @(
    'Scripts\01-CheckPrerequisites.ps1',  # Wird zuerst ausgeführt
    'Scripts\02-LoadDependencies.ps1',    # Wird danach ausgeführt
    'Scripts\03-InitializeConfig.ps1'     # Wird zuletzt ausgeführt
)
```

### 2.3 Was passiert wenn ein ScriptsToProcess-Skript mit `exit 1` abbricht?

Hier liegt ein **kritischer Unterschied** zwischen `exit` und `throw` vor:

#### Verhalten von `exit <n>`

`exit` in einem `ScriptsToProcess`-Skript terminiert den **gesamten PowerShell-Prozess** – nicht nur das Skript selbst. Das ist kein modulspezifisches Verhalten, sondern eine grundlegende PowerShell-Eigenschaft: `exit` beendet die Host-Anwendung, nicht nur den aktuellen Scriptblock.[^11]

> ⚠️ **Achtung:** Ein `exit 1` in einem `ScriptsToProcess`-Skript schließt die gesamte PowerShell-Konsole bzw. den Prozess! Das ist in den meisten Fällen **nicht** das gewünschte Verhalten.

#### Verhalten von `throw`

`throw` erzeugt einen terminierenden Fehler, der den üblichen PowerShell-Fehlerbehandlungsmechanismen unterliegt. Das verhält sich anders: Der Fehler wird weitergegeben, aber der PowerShell-Prozess läuft weiter.[^12]

#### Wichtige Einschränkung: Modul wird trotzdem geladen

Nach aktuellem Stand (PowerShell 5.1 und 7.x) gilt folgendes dokumentiertes Verhalten: **Selbst wenn ein `ScriptsToProcess`-Skript einen Fehler wirft (throw), wird das Modul in den meisten Fällen trotzdem geladen**. Das ist ein bekanntes Design-Merkmal, das von manchen als Bug betrachtet wird.[^13]

```powershell
# So sieht ein ScriptsToProcess-Skript aus, das korrekt Fehler signalisiert:
# Check-Prerequisites.ps1

$requiredVersion = [Version]"5.1"
if ($PSVersionTable.PSVersion -lt $requiredVersion) {
    # NICHT: exit 1  (beendet den ganzen Prozess!)
    # NICHT: return  (hat keine Wirkung auf den Ladevorgang)
    throw "Dieses Modul erfordert PowerShell $requiredVersion oder höher."
    # Das Modul könnte trotzdem geladen werden – siehe Abschnitt 2.4
}
```

### 2.4 Kann ich das Laden des Moduls aus ScriptsToProcess heraus abbrechen?

Das ist eine der meistdiskutierten Fragen im PowerShell-Moduldesign. Die Antwort ist: **Nur bedingt, und mit Workarounds.**

#### Option 1: Fehler in der RootModule/psm1 erzwingen

Der zuverlässigste Weg ist, den Abbruch in der `psm1` selbst zu implementieren. Die `ScriptsToProcess`-Skripte können eine Variable oder einen Flag im Caller-Scope setzen, und die `psm1` prüft diesen beim Start:[^13]

```powershell
# In Check-Prerequisites.ps1 (ScriptsToProcess):
if (-not (Test-ModulePrerequisites)) {
    $global:__MeinModul_LoadAborted = $true
}

# In MeinModul.psm1 (RootModule):
if ($global:__MeinModul_LoadAborted) {
    Remove-Variable -Name '__MeinModul_LoadAborted' -Scope Global -ErrorAction SilentlyContinue
    throw "Modul-Voraussetzungen nicht erfüllt. Laden wird abgebrochen."
    # Jetzt schlägt das Laden der psm1 fehl!
}
```

#### Option 2: $ErrorActionPreference = 'Stop' + throw

Mit gesetzter `$ErrorActionPreference = 'Stop'` im Caller-Scope propagiert ein `throw` in der `psm1` korrekt als Ladefehler:

```powershell
# In MeinModul.psm1:
#Requires -Version 5.1
if ($PSVersionTable.PSVersion -lt [Version]"5.1") {
    throw [System.InvalidOperationException]::new("Inkompatible PowerShell-Version.")
}
```

Wenn die `psm1` einen terminierenden Fehler produziert, schlägt `Import-Module` fehl. Das ist der sauberere Ansatz.[^14]

#### Option 3: `#Requires`-Statement verwenden

Für häufige Prüfungen gibt es die eleganteste Lösung: das `#Requires`-Statement direkt in der `psm1` oder am Anfang der `ScriptsToProcess`-Skripte:

```powershell
#Requires -Version 7.0
#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator
```

`#Requires`-Verletzungen erzeugen automatisch terminierende Fehler, die den Ladevorgang zuverlässig abbrechen.

***

## 3. Konfiguration beim Modulstart: Interaktiv und grafisch per WPF

### 3.1 Konsolen-Konfiguration via Read-Host beim Laden

Es ist vollständig möglich, beim Laden eines Moduls Benutzereingaben abzufragen. Der richtige Ort dafür ist entweder ein `ScriptsToProcess`-Skript oder der Beginn der `psm1`-Datei selbst.

```powershell
# In MeinModul.psm1 oder einem ScriptsToProcess-Skript:

$configPath = "$env:APPDATA\MeinModul\config.json"

if (-not (Test-Path $configPath)) {
    Write-Host "=== Erstkonfiguration von MeinModul ===" -ForegroundColor Cyan
    
    $serverName = Read-Host -Prompt "Bitte Servername eingeben"
    $apiKey     = Read-Host -Prompt "API-Key eingeben" -AsSecureString
    $logLevel   = Read-Host -Prompt "Log-Level (Info/Warning/Error) [Info]"
    
    if ([string]::IsNullOrEmpty($logLevel)) { $logLevel = "Info" }
    
    $config = @{
        ServerName = $serverName
        LogLevel   = $logLevel
        ApiKey     = ($apiKey | ConvertFrom-SecureString)
        CreatedAt  = (Get-Date -Format "o")
    }
    
    $config | ConvertTo-Json | Set-Content -Path $configPath -Force
    Write-Host "Konfiguration gespeichert unter: $configPath" -ForegroundColor Green
}

# Konfiguration laden und als Modul-Variable verfügbar machen
$script:ModuleConfig = Get-Content $configPath | ConvertFrom-Json
```

> ℹ️ **Hinweis:** Da `ScriptsToProcess`-Skripte im Caller-Scope laufen, sind dort gesetzte Variablen im globalen Scope des Aufrufers verfügbar. In der `psm1` (Modul-Scope) sollte die Konfiguration dann erneut geladen werden, um sie sauber im Modul-Namespace zu halten.

### 3.2 Grafische WPF-Konfiguration beim Modulstart

Ja, das ist möglich – PowerShell kann WPF-Fenster direkt öffnen. Allerdings gibt es dabei wichtige Besonderheiten und Einschränkungen zu beachten.[^15][^16]

#### Grundvoraussetzungen

- WPF ist **nur unter Windows** verfügbar (nicht auf Linux/macOS mit pwsh)[^15]
- In **PowerShell 7+** muss die Assembly explizit geladen werden
- Der Code muss **im STA-Thread (Single-Threaded Apartment)** laufen – das ist in `powershell.exe` (Windows PowerShell) der Standard, in `pwsh.exe` (PowerShell 7) muss es ggf. erzwungen werden

```powershell
# In MeinModul.psm1 oder ScriptsToProcess:

# Assemblies für WPF laden
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Show-ModuleConfigDialog {
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MeinModul – Konfiguration"
        Height="250" Width="400"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <Label Grid.Row="0" Content="Servername:" FontWeight="Bold"/>
        <TextBox Grid.Row="1" Name="txtServer" Margin="0,0,0,10" Padding="5"/>
        
        <Label Grid.Row="2" Content="Log-Level:" FontWeight="Bold"/>
        <ComboBox Grid.Row="3" Name="cmbLogLevel" Margin="0,0,0,10" Padding="5" VerticalAlignment="Top">
            <ComboBoxItem Content="Info" IsSelected="True"/>
            <ComboBoxItem Content="Warning"/>
            <ComboBoxItem Content="Error"/>
        </ComboBox>
        
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="btnOK"     Content="OK"         Width="80" Margin="0,0,10,0" IsDefault="True"/>
            <Button Name="btnCancel" Content="Abbrechen"  Width="80"                   IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    $txtServer    = $window.FindName("txtServer")
    $cmbLogLevel  = $window.FindName("cmbLogLevel")
    $btnOK        = $window.FindName("btnOK")
    $btnCancel    = $window.FindName("btnCancel")
    
    $result = $null
    
    $btnOK.Add_Click({
        $result = @{
            ServerName = $txtServer.Text
            LogLevel   = $cmbLogLevel.SelectedItem.Content
        }
        $window.DialogResult = $true
        $window.Close()
    })
    
    $btnCancel.Add_Click({
        $window.DialogResult = $false
        $window.Close()
    })
    
    $dialogResult = $window.ShowDialog()
    
    if ($dialogResult -eq $true) {
        return $result
    } else {
        return $null
    }
}
```

#### WPF-Dialog beim Modul-Laden einbinden

```powershell
# In MeinModul.psm1:

$configPath = "$env:APPDATA\MeinModul\config.json"

if (-not (Test-Path $configPath)) {
    $config = Show-ModuleConfigDialog
    
    if ($null -eq $config) {
        throw "Modul-Konfiguration wurde abgebrochen. Das Modul wird nicht geladen."
    }
    
    # Konfiguration speichern
    New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
    $config | ConvertTo-Json | Set-Content -Path $configPath -Force
}

$script:Config = Get-Content $configPath | ConvertFrom-Json
```

#### STA-Thread-Problem in PowerShell 7 lösen

In PowerShell 7 läuft der Hauptthread nicht automatisch als STA. Wenn ein WPF-Fenster auf einem MTA-Thread geöffnet wird, kommt es zu Ausnahmen. Die Lösung ist ein Runspace mit explizitem STA-Threading:

```powershell
function Show-ModuleConfigDialogSafe {
    $result = $null
    
    # Runspace mit STA-Threading erstellen
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $runspace.Open()
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    [void]$ps.AddScript({
        Add-Type -AssemblyName PresentationFramework
        # ... WPF-Code hier ...
        return $config
    })
    
    $result = $ps.Invoke()
    $runspace.Close()
    
    return $result
}
```

***

## 4. Parameter in PowerShell Modulen

### 4.1 Kann ein PowerShell-Modul Parameter empfangen?

**Ja.** Es gibt zwei grundlegend verschiedene Mechanismen:

#### Methode 1: Import-Module mit -ArgumentList

Der bekannteste Weg, einem Modul beim Laden Werte zu übergeben, ist der `-ArgumentList`-Parameter von `Import-Module`. Diese Werte werden innerhalb der `psm1` über die automatische Variable `$args` oder einen `param()`-Block am Anfang der `psm1` empfangen.

```powershell
# Modul laden mit Parametern
Import-Module MeinModul -ArgumentList "https://api.example.com", "mein-api-key", $true
```

```powershell
# In MeinModul.psm1:
param(
    [string]$ApiBaseUrl,
    [string]$ApiKey,
    [bool]$VerboseLogging = $false
)

# Die Parameter sind jetzt im Modul-Scope als $script:-Variablen verwendbar
$script:ApiBaseUrl     = $ApiBaseUrl
$script:ApiKey         = $ApiKey
$script:VerboseLogging = $VerboseLogging
```

#### Methode 2: PrivateData im Manifest

Für **statische Konfigurationswerte**, die sich selten ändern, eignet sich das `PrivateData`-Feld im Modulmanifest. Auf diese Daten kann innerhalb des Moduls über `$MyInvocation.MyCommand.Module.PrivateData` zugegriffen werden:[^17][^18]

```powershell
# In MeinModul.psd1:
PrivateData = @{
    PSData = @{
        # PSGallery-Metadaten
    }
    
    # Eigene Konfigurationsdefaults
    DefaultLogPath    = "C:\Logs\MeinModul"
    MaxRetryCount     = 3
    SupportedApiVersions = @("v1", "v2", "v3")
}
```

```powershell
# In MeinModul.psm1 oder beliebigen Modulfunktionen:
$moduleData = $MyInvocation.MyCommand.Module.PrivateData
$defaultLogPath = $moduleData.DefaultLogPath
```

#### Methode 3: DefaultCommandPrefix im Manifest

Ein häufig übersehener "Parameter" ist `DefaultCommandPrefix` in der `.psd1`. Damit kann dem Modul ein Namens-Präfix für alle exportierten Befehle gegeben werden, was Namenskonflikte mit anderen Modulen verhindert:[^19]

```powershell
# In MeinModul.psd1:
DefaultCommandPrefix = 'Mein'

# Die Funktion Get-Status wird dann als Get-MeinStatus exportiert
```

Beim Laden kann das Präfix auch überschrieben werden:
```powershell
Import-Module MeinModul -Prefix "XYZ"
# Exportiert Get-XYZStatus statt Get-MeinStatus
```

### 4.2 Sinnvolle Use Cases für Modul-Parameter

| Parameter-Typ | Übergabe via | Typischer Use Case |
|---|---|---|
| API-Credentials | `-ArgumentList` | Module für externe APIs (REST, GraphQL) |
| Verbosity/Debug-Mode | `-ArgumentList` | Entwickler-Modi mit detaillogging |
| Umgebung (Dev/Prod) | `-ArgumentList` | Deployment-Module mit verschiedenen Endpunkten |
| Statische Defaults | `PrivateData` | Versionsnummern, unterstützte Protokolle |
| Namens-Präfix | `DefaultCommandPrefix` | Verhinderung von Namens-Kollisionen |
| Spracheinstellungen | `-ArgumentList` | Lokalisierte Module |

```powershell
# Praxisbeispiel: Deployment-Modul mit Umgebungs-Parameter
Import-Module DeploymentTools -ArgumentList @{
    Environment     = "Production"
    DeployServer    = "deploy01.intern.example.com"
    NotifyOnFailure = $true
    LogLevel        = "Verbose"
}
```

```powershell
# In DeploymentTools.psm1:
param([hashtable]$Config)

$script:Environment     = $Config.Environment     ?? "Development"
$script:DeployServer    = $Config.DeployServer    ?? "localhost"
$script:NotifyOnFailure = $Config.NotifyOnFailure ?? $false
$script:LogLevel        = $Config.LogLevel        ?? "Info"
```

***

## 5. Runspaces in PowerShell Modulen

### 5.1 Wie funktionieren Runspaces in PowerShell?

Ein **Runspace** ist die grundlegende Ausführungsumgebung (Execution Environment) von PowerShell. Wenn man eine normale PowerShell-Konsole öffnet, läuft alles in einem einzigen Standard-Runspace. Runspaces ermöglichen **echtes Multithreading** in PowerShell, weil sie auf separaten Threads des gleichen Prozesses laufen.[^20][^21]

Ein Runspace enthält:
- Eine eigene **Session State** (Variablen, Funktionen, Aliases, Module)
- Einen eigenen **Execution Stack**
- Eigene **Streams** (Output, Error, Warning, Verbose, Debug, Information)

Das Wichtigste: **Jeder Runspace hat seinen eigenen isolierten Scope.** Variablen, Funktionen und geladene Module des Parent-Runspace sind im neuen Runspace **nicht** automatisch verfügbar.[^22]

### 5.2 Runspace-Typen im Überblick

| Typ | Erstellung | Isolation | Kommunikation |
|---|---|---|---|
| Standard-Runspace | Automatisch | Vollständig | Direkte Variablen |
| `[runspacefactory]::CreateRunspace()` | Manuell | Vollständig | Shared Variables, PSDataCollection |
| RunspacePool | `CreateRunspacePool()` | Vollständig | Shared Variables |
| ThreadJob | `Start-ThreadJob` | Teilweise | Job-Output |
| BackgroundJob | `Start-Job` | Vollständig (eigener Prozess) | Job-Output |

### 5.3 Runspaces innerhalb eines PowerShell-Moduls verwenden

#### Schritt 1: InitialSessionState konfigurieren

Da ein neuer Runspace einen leeren Session State hat, muss man ihm alle benötigten Funktionen und Module explizit mitgeben. Dafür verwendet man ein `InitialSessionState`-Objekt:[^23][^24]

```powershell
function Start-BackgroundTask {
    param([string]$DataToProcess)
    
    # InitialSessionState erstellen
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    
    # Eigene Modul-Funktionen in den neuen Runspace injizieren
    # Variante A: Über den Modul-Pfad (empfohlen für komplette Module)
    $iss.ImportPSModule($PSScriptRoot)
    
    # Variante B: Einzelne Funktionen über SessionStateFunctionEntry injizieren
    $funcDef = Get-Item function:ConvertTo-InternalFormat
    $ssfe = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
        'ConvertTo-InternalFormat',
        $funcDef.ScriptBlock
    )
    $iss.Commands.Add($ssfe)
    
    # Runspace erstellen und öffnen
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $runspace.Open()
    
    # PowerShell-Instanz erstellen
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    # Script hinzufügen
    [void]$ps.AddScript({
        param($data)
        # Hier können Modul-Funktionen genutzt werden (wenn injiziert)
        $result = ConvertTo-InternalFormat -InputData $data
        return $result
    }).AddArgument($DataToProcess)
    
    # Asynchron starten
    $asyncResult = $ps.BeginInvoke()
    
    # Aufräumen und Ergebnis zurückgeben
    $output = $ps.EndInvoke($asyncResult)
    $runspace.Close()
    $ps.Dispose()
    
    return $output
}
```

#### Schritt 2: RunspacePool für parallele Verarbeitung

Für Szenarien, in denen viele Aufgaben parallel verarbeitet werden sollen, eignet sich ein **RunspacePool**:[^25][^26]

```powershell
function Invoke-ParallelProcessing {
    param(
        [string[]]$Items,
        [int]$MaxParallel = 5
    )
    
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ImportPSModule($PSScriptRoot)
    
    # Pool mit min. 1 und max. $MaxParallel gleichzeitigen Runspaces
    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $MaxParallel, $iss, $Host)
    $pool.Open()
    
    $jobs = [System.Collections.Generic.List[hashtable]]::new()
    
    foreach ($item in $Items) {
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.RunspacePool = $pool
        
        [void]$ps.AddScript({
            param($inputItem)
            # Verarbeitung hier
            [PSCustomObject]@{
                Item   = $inputItem
                Result = "Verarbeitet: $inputItem"
            }
        }).AddArgument($item)
        
        $jobs.Add(@{
            PS     = $ps
            Handle = $ps.BeginInvoke()
        })
    }
    
    # Ergebnisse einsammeln
    $results = foreach ($job in $jobs) {
        $job.PS.EndInvoke($job.Handle)
        $job.PS.Dispose()
    }
    
    $pool.Close()
    $pool.Dispose()
    
    return $results
}
```

#### Schritt 3: Synchronisierte Shared State zwischen Runspaces

Wenn Runspaces auf gemeinsame Daten zugreifen müssen, kann man **synchronisierte Hashtables** verwenden:

```powershell
# Geteilter, thread-sicherer Speicher
$script:SharedState = [hashtable]::Synchronized(@{
    CompletedCount = 0
    Errors         = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
    Results        = [System.Collections.Concurrent.ConcurrentQueue[PSObject]]::new()
})
```

Diese synchronisierten Collections können über die `$iss.Variables.Add()`-Methode an neue Runspaces übergeben werden:

```powershell
$varEntry = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
    'SharedState',
    $script:SharedState,
    'Geteilter Zustand'
)
$iss.Variables.Add($varEntry)
```

***

## 6. Named Pipes in PowerShell Modulen

### 6.1 Grundlagen: Was sind Named Pipes?

Named Pipes sind ein Mechanismus für **Inter-Process Communication (IPC)** – die Kommunikation zwischen verschiedenen Prozessen. Im Gegensatz zu Anonymous Pipes können Named Pipes:[^27]
- Von beliebigen Prozessen über ihren Namen gefunden werden
- Bidirektionale Kommunikation ermöglichen
- Über Netzwerkgrenzen hinweg funktionieren (mit `\\server\pipe\name`)
- Mehrere gleichzeitige Verbindungen unterstützen

PowerShell verwendet Named Pipes intern schon intensiv: Jede `pwsh.exe`-Instanz erstellt automatisch beim Start einen eigenen Named-Pipe-Listener für IPC-Kommunikation.[^28][^29]

```powershell
# Das macht PowerShell intern für jeden Prozess:
# PSHost.{Startzeit}.{PID}.DefaultAppDomain.pwsh
# Dieser Pipe ermöglicht z.B. Enter-PSHostProcess

$PID  # Aktuellen Prozess sehen
# PSHost-Pipe-Namen generieren (Hilfsfunktion):
function Get-PSHostNamedPipeName {
    param([int]$ProcessId)
    $process   = Get-Process -Id $ProcessId
    $startTime = $process.StartTime.ToFileTime().ToString([System.Globalization.CultureInfo]::InvariantCulture)
    return "PSHost.$startTime.$ProcessId.DefaultAppDomain.$($process.ProcessName)"
}
```

### 6.2 Einen Named-Pipe-Server im Modul einrichten

Ja, ein PowerShell-Modul kann vollständig einen Named-Pipe-Server einrichten. Dafür wird die .NET-Klasse `System.IO.Pipes.NamedPipeServerStream` verwendet.[^30][^31][^27]

#### Synchroner Pipe-Server (einfaches Beispiel)

```powershell
function Start-ModulePipeServer {
    param(
        [string]$PipeName  = "MeinModulPipe",
        [int]$MaxInstances = 1
    )
    
    $pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new(
        $PipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        $MaxInstances,
        [System.IO.Pipes.PipeTransmissionMode]::Message,
        [System.IO.Pipes.PipeOptions]::None
    )
    
    Write-Host "Warte auf Verbindung auf Pipe: \\.\pipe\$PipeName"
    $pipeServer.WaitForConnection()
    Write-Host "Client verbunden!"
    
    $reader = [System.IO.StreamReader]::new($pipeServer)
    $writer = [System.IO.StreamWriter]::new($pipeServer)
    $writer.AutoFlush = $true
    
    try {
        while ($pipeServer.IsConnected) {
            $message = $reader.ReadLine()
            if ($null -eq $message) { break }
            
            Write-Host "Empfangen: $message"
            
            # Antwort senden
            $response = "ACK: $message"
            $writer.WriteLine($response)
        }
    }
    finally {
        $pipeServer.Disconnect()
        $pipeServer.Dispose()
    }
}
```

#### Asynchroner Pipe-Server im Runspace (empfohlen für Module)

Ein blockierender Pipe-Server würde die gesamte Konsole blockieren. Die richtige Lösung ist ein **asynchroner Server in einem Hintergrund-Runspace**:[^32]

```powershell
# Modul-interne Variable für den Server-Runspace
$script:PipeServerRunspace = $null
$script:PipeServerPS       = $null
$script:SharedPipeQueue    = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

function Start-ModulePipeServerAsync {
    param([string]$PipeName = "MeinModulPipe")
    
    if ($null -ne $script:PipeServerRunspace) {
        Write-Warning "Pipe-Server läuft bereits."
        return
    }
    
    $queue = $script:SharedPipeQueue
    
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    
    # Geteilte Queue in den Runspace injizieren
    $varEntry = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
        'SharedQueue', $queue, 'Shared message queue'
    )
    $iss.Variables.Add($varEntry)
    
    $script:PipeServerRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $script:PipeServerRunspace.Open()
    
    $script:PipeServerPS = [System.Management.Automation.PowerShell]::Create()
    $script:PipeServerPS.Runspace = $script:PipeServerRunspace
    
    [void]$script:PipeServerPS.AddScript({
        param([string]$name)
        
        while ($true) {
            $server = [System.IO.Pipes.NamedPipeServerStream]::new(
                $name,
                [System.IO.Pipes.PipeDirection]::InOut,
                [System.IO.Pipes.NamedPipeServerStream]::MaxAllowedServerInstances
            )
            
            $server.WaitForConnection()
            
            $reader = [System.IO.StreamReader]::new($server)
            $writer = [System.IO.StreamWriter]::new($server)
            $writer.AutoFlush = $true
            
            try {
                $msg = $reader.ReadLine()
                if ($msg) {
                    $SharedQueue.Enqueue($msg)  # In geteilte Queue schreiben
                    $writer.WriteLine("OK")
                }
            }
            finally {
                $server.Disconnect()
                $server.Dispose()
            }
        }
    }).AddArgument($PipeName)
    
    # Asynchron starten (nicht warten)
    [void]$script:PipeServerPS.BeginInvoke()
    
    Write-Host "Pipe-Server gestartet auf: \\.\pipe\$PipeName"
}

function Stop-ModulePipeServerAsync {
    if ($script:PipeServerPS) {
        $script:PipeServerPS.Stop()
        $script:PipeServerPS.Dispose()
        $script:PipeServerPS = $null
    }
    if ($script:PipeServerRunspace) {
        $script:PipeServerRunspace.Close()
        $script:PipeServerRunspace.Dispose()
        $script:PipeServerRunspace = $null
    }
    Write-Host "Pipe-Server gestoppt."
}

function Get-ModulePipeMessages {
    $messages = @()
    $msg = $null
    while ($script:SharedPipeQueue.TryDequeue([ref]$msg)) {
        $messages += $msg
    }
    return $messages
}
```

#### Client-seitige Kommunikation (von außen)

```powershell
# Von außen oder aus einem anderen Skript/Prozess:
function Send-PipeMessage {
    param(
        [string]$PipeName = "MeinModulPipe",
        [string]$Message
    )
    
    $client = [System.IO.Pipes.NamedPipeClientStream]::new(
        ".",           # Lokaler Server
        $PipeName,
        [System.IO.Pipes.PipeDirection]::InOut
    )
    
    try {
        $client.Connect(3000)  # Timeout: 3 Sekunden
        
        $writer = [System.IO.StreamWriter]::new($client)
        $reader = [System.IO.StreamReader]::new($client)
        $writer.AutoFlush = $true
        
        $writer.WriteLine($Message)
        $response = $reader.ReadLine()
        
        Write-Host "Server-Antwort: $response"
    }
    finally {
        $client.Dispose()
    }
}
```

***

## 7. Externes Prozess-Management: Modul in separatem Prozess & IPC via Named Pipes

### 7.1 Kann ein Modul ein anderes Modul in einem separaten Prozess starten?

**Ja, das ist vollständig möglich und ein bewährtes Architekturmuster.** Man verwendet dabei `Start-Process` oder direkt die .NET-Klasse `System.Diagnostics.Process`.[^33]

#### Methode A: Start-Job (empfohlen für einfache Szenarien)

`Start-Job` startet einen vollständig separaten PowerShell-Prozess. Der Vorteil ist, dass PowerShell die gesamte Prozess- und Kommunikationsverwaltung übernimmt. Der Nachteil ist, dass die Kommunikation ausschließlich über den Job-Output-Stream läuft:[^34]

```powershell
function Start-ModuleWorkerProcess {
    param([hashtable]$WorkerConfig)
    
    $job = Start-Job -ScriptBlock {
        param($config)
        
        # Modul im Hintergrund-Prozess laden
        Import-Module MeinArbeitsModul -ArgumentList $config
        
        # Laufendes Processing (mit Named Pipe Server)
        Start-MeinArbeitsModulPipeServer -PipeName $config.PipeName
        
    } -ArgumentList $WorkerConfig
    
    return $job
}
```

#### Methode B: Start-Process mit Named Pipes (für fortgeschrittene IPC)

Für komplexere bidirektionale Kommunikation ist das Muster mit `Start-Process` und Named Pipes wesentlich flexibler:[^35][^33]

```powershell
# WorkerScript.ps1 (wird als separater Prozess gestartet)
param([string]$PipeName, [string]$ConfigJson)

$config = $ConfigJson | ConvertFrom-Json
Import-Module MeinArbeitsModul -ArgumentList $config

# Named Pipe Server starten (blockierend)
$server = [System.IO.Pipes.NamedPipeServerStream]::new(
    $PipeName,
    [System.IO.Pipes.PipeDirection]::InOut,
    10  # Max 10 gleichzeitige Verbindungen
)

Write-Host "Worker bereit. Warte auf Kommandos..."
$server.WaitForConnection()

$reader = [System.IO.StreamReader]::new($server)
$writer = [System.IO.StreamWriter]::new($server)
$writer.AutoFlush = $true

while ($true) {
    $command = $reader.ReadLine()
    if ($command -eq "EXIT") { break }
    
    # Kommando verarbeiten und Ergebnis zurücksenden
    $result = Invoke-Expression $command | ConvertTo-Json -Compress
    $writer.WriteLine($result)
}

$server.Disconnect()
$server.Dispose()
```

```powershell
# In MeinHauptModul.psm1 – Worker-Prozess starten und verwalten

$script:WorkerProcess   = $null
$script:WorkerPipeClient = $null
$script:WorkerPipeName  = "MeinHauptModul_Worker_$(Get-Random)"

function Start-WorkerProcess {
    $pipeName   = $script:WorkerPipeName
    $scriptPath = Join-Path $PSScriptRoot "WorkerScript.ps1"
    
    $pwshExe = (Get-Process -Id $PID).Path  # Aktuellen PS-Pfad bestimmen
    
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($pwshExe)
    $startInfo.Arguments       = "-NonInteractive -File `"$scriptPath`" -PipeName `"$pipeName`" -ConfigJson `'{}`'"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow  = $true
    
    $script:WorkerProcess = [System.Diagnostics.Process]::Start($startInfo)
    
    # Kurz warten, bis der Worker-Prozess bereit ist
    Start-Sleep -Milliseconds 500
    
    # Client-seitige Pipe-Verbindung aufbauen
    $script:WorkerPipeClient = [System.IO.Pipes.NamedPipeClientStream]::new(
        ".", $pipeName,
        [System.IO.Pipes.PipeDirection]::InOut
    )
    $script:WorkerPipeClient.Connect(10000)  # Timeout: 10 Sekunden
    
    Write-Host "Worker-Prozess gestartet (PID: $($script:WorkerProcess.Id))"
}

function Invoke-WorkerCommand {
    param([string]$Command)
    
    if ($null -eq $script:WorkerPipeClient -or -not $script:WorkerPipeClient.IsConnected) {
        throw "Worker-Prozess ist nicht verbunden. Start-WorkerProcess aufrufen."
    }
    
    $writer = [System.IO.StreamWriter]::new($script:WorkerPipeClient)
    $reader = [System.IO.StreamReader]::new($script:WorkerPipeClient)
    $writer.AutoFlush = $true
    
    $writer.WriteLine($Command)
    $responseJson = $reader.ReadLine()
    
    return $responseJson | ConvertFrom-Json
}

function Stop-WorkerProcess {
    if ($script:WorkerPipeClient -and $script:WorkerPipeClient.IsConnected) {
        $writer = [System.IO.StreamWriter]::new($script:WorkerPipeClient)
        $writer.AutoFlush = $true
        $writer.WriteLine("EXIT")
        $script:WorkerPipeClient.Dispose()
        $script:WorkerPipeClient = $null
    }
    
    if ($script:WorkerProcess -and -not $script:WorkerProcess.HasExited) {
        $script:WorkerProcess.WaitForExit(5000)
        if (-not $script:WorkerProcess.HasExited) {
            $script:WorkerProcess.Kill()
        }
    }
    
    Write-Host "Worker-Prozess beendet."
}
```

### 7.2 Wann welches Muster verwenden?

| Szenario | Empfohlenes Muster | Begründung |
|---|---|---|
| Kurze parallele Aufgaben | RunspacePool | Niedrig Overhead, gleicher Prozess |
| Langläufige Hintergrundverarbeitung | `Start-Job` | Prozess-Isolation, einfache Verwaltung |
| Bidirektionale Echtzeit-IPC | Named Pipes + separater Prozess | Maximale Flexibilität |
| Crash-Isolation (Worker darf abstürzen) | Separater Prozess | Isoliert Fehler vom Hauptprozess |
| GUI + Backend trennen | Separater Prozess + Named Pipes | STA/MTA-Probleme umgehen |
| Privilegien-Trennung | Separater Prozess (runas) | Worker läuft als anderer Benutzer |

### 7.3 PowerShells eingebauter IPC-Mechanismus: NamedPipeConnectionInfo

PowerShell 7 bietet mit `NamedPipeConnectionInfo` einen nativen Weg, Runspaces zwischen Prozessen zu verbinden:[^36][^28]

```powershell
# In Prozess A: Worker mit Custom Pipe Name starten
# pwsh.exe -CustomPipeName "MeinModulWorker"

# In Prozess B: Verbindung herstellen
$connInfo   = [System.Management.Automation.Runspaces.NamedPipeConnectionInfo]::new("MeinModulWorker")
$remRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($connInfo)
$remRunspace.Open()

$ps = [System.Management.Automation.PowerShell]::Create()
$ps.Runspace = $remRunspace

[void]$ps.AddCommand("Get-Process")
$result = $ps.Invoke()

$remRunspace.Close()
```

Das ist derselbe Mechanismus, den `Enter-PSHostProcess` intern nutzt – damit kann man sich per Named Pipe in einen anderen PowerShell-Prozess "einwählen" und Befehle dort ausführen.[^28]

***

## Anhang: Empfohlene Modulstruktur

```
MeinModul/
│
├── MeinModul.psd1              # Modulmanifest
├── MeinModul.psm1              # Root Module (Dot-Sourcing-Zentrale)
│
├── Public/                     # Exportierte Funktionen (eine Funktion pro Datei)
│   ├── Get-MeinStatus.ps1
│   ├── Set-MeinKonfiguration.ps1
│   └── Invoke-MeinBefehl.ps1
│
├── Private/                    # Interne Hilfsfunktionen (nicht exportiert)
│   ├── ConvertTo-InternalFormat.ps1
│   ├── Test-Prerequisites.ps1
│   └── Write-ModuleLog.ps1
│
├── Scripts/                    # ScriptsToProcess-Skripte
│   ├── 01-CheckPrerequisites.ps1
│   └── 02-InitializeEnvironment.ps1
│
├── Workers/                    # Skripte für separate Prozesse
│   └── BackgroundWorker.ps1
│
├── Resources/                  # WPF-XAML-Dateien, Konfigurationsvorlagen
│   ├── ConfigDialog.xaml
│   └── DefaultConfig.json
│
└── Tests/                      # Pester-Tests
    ├── Get-MeinStatus.Tests.ps1
    └── MeinModul.Tests.ps1
```

### psm1 – Minimale Best-Practice-Vorlage

```powershell
# MeinModul.psm1

#Requires -Version 5.1

# Modul-Konfiguration initialisieren
$script:ModuleConfig = $null
$script:ModuleRoot   = $PSScriptRoot

# Private Funktionen laden
Get-ChildItem -Path "$PSScriptRoot\Private" -Filter "*.ps1" -Recurse |
    ForEach-Object { . $_.FullName }

# Public Funktionen laden
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter "*.ps1" -Recurse
$publicFunctions | ForEach-Object { . $_.FullName }

# Konfiguration laden (oder initialisieren)
$configPath = "$env:APPDATA\MeinModul\config.json"
if (Test-Path $configPath) {
    $script:ModuleConfig = Get-Content $configPath -Raw | ConvertFrom-Json
}

# Cleanup beim Entladen registrieren
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Stop-WorkerProcess -ErrorAction SilentlyContinue
    Write-Verbose "MeinModul wurde entladen."
}

# Nur Public-Funktionen exportieren
Export-ModuleMember -Function $publicFunctions.BaseName
```

---

## References

1. [Ps1 and PSM1 - PowerShell Forums](https://forums.powershell.org/t/ps1-and-psm1/3856) - PS1 files are scripts, PSM1 files are script modules. You load up a module with the Import-Module co...

2. [What is the purpose of the *.psm1 files in a Powershell module?](https://stackoverflow.com/questions/55876838/what-is-the-purpose-of-the-psm1-files-in-a-powershell-module) - It is only *.psm1 files that provide the module-specific behaviors distinct from regular *.ps1 scrip...

3. [Script modules - PowerShell | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/10-script-modules?view=powershell-7.6) - You don't need to use both Export-ModuleMember in the .psm1 file and the FunctionsToExport section i...

4. [How to export PowerShell module functions - 4sysops](https://4sysops.com/archives/how-to-export-powershell-module-functions/) - To separate the functions, we'll have to figure out how to dot-source these PS1 files into the sessi...

5. [Is there a proper way to define a private function in a module while ...](https://www.reddit.com/r/PowerShell/comments/1ab55dn/is_there_a_proper_way_to_define_a_private/) - In my .psd1 I populate the FunctionsToExport variable with all my public functions. Is there a place...

6. [Creating Module of Departmental Scripts/Functions : r/PowerShell](https://www.reddit.com/r/PowerShell/comments/15vwfso/creating_module_of_departmental_scriptsfunctions/) - The .psm1 file processes the functions folder (among others), which contains 2 sub-folders: private ...

7. [PowerShell - Single PSM1 file versus multi-file modules - Evotec](https://evotec.xyz/powershell-single-psm1-file-versus-multi-file-modules/) - A module is stored in multiple folders Private, Public, Bin, Lib and so on and having YourModule.psm...

8. [powershell - Module ScriptToProcess: Is it possible to load functions ...](https://stackoverflow.com/questions/70793555/module-scripttoprocess-is-it-possible-to-load-functions-into-module-scope-preem) - ScriptsToProcess scripts are dot-sourced in the importer's scope, and unless that scope happens to b...

9. [about_Module_Manifests - PowerShell - Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests?view=powershell-7.6) - Test-ModuleManifest returns an error if the manifest is invalid or the module can't be imported into...

10. [The ScriptsToProcess and RequiredModules Order](https://tommymaynard.com/the-scriptstoprocess-and-requiredmodules-order-2018/) - A PowerShell module's ScriptsToProcess should run before RequiredModules is verified, allowing one t...

11. [How to stop functions from module manifest closing automatically](https://www.reddit.com/r/PowerShell/comments/tmv510/how_to_stop_functions_from_module_manifest/) - Go find every "exit", "break", and 'continue" in your scripts. You should rework every exit statemen...

12. [Practical PowerShell: Error Handling | Practical365](https://practical365.com/practical-powershell-error-handling/) - Throw is a keyword that you use to generate terminating errors. It will stop the code execution from...

13. [Powershell Module Manifest "ScriptsToProcess" - Stack Overflow](https://stackoverflow.com/questions/24644804/powershell-module-manifest-scriptstoprocess) - So if your intent is to prevent loading of the module I would put the warnings/throws in the startup...

14. [RFC Proposal: Make terminating errors terminate the right way in ...](https://github.com/PowerShell/PowerShell-RFC/issues/199) - With this definition, if the script module generates a terminating error, the module will properly f...

15. [Windows Forms / WPF XAML gui for powershell scripts - Reddit](https://www.reddit.com/r/PowerShell/comments/2f1fra/windows_forms_wpf_xaml_gui_for_powershell_scripts/) - A template for use while developing XAML based GUIs for powershell scripts. Save XAML code to anothe...

16. [Modern dialog with PowerShell and WPF - Syst & Deploy](https://www.systanddeploy.com/2019/08/modern-dialog-with-powershell-and-wpf.html) - In this post I will show you the new version of the CustomDialogs library, that allows you to displa...

17. [Accessing PrivateData during Import-Module - Stack Overflow](https://stackoverflow.com/questions/22269275/accessing-privatedata-during-import-module) - I want to load the contents of a config.xml file and store it in $PrivateData when my module loads. ...

18. [Manifest.psm1 0.4 - PowerShell Gallery](https://www.powershellgallery.com/packages/Configuration/0.4/Content/Manifest.psm1) - # By default Update-Manifest increments the ModuleVersion, but it can set any key in the Module Mani...

19. [PowerShellEditorServices.Commands.psd1 - GitHub](https://github.com/PowerShell/PowerShellEditorServices/blob/master/module/PowerShellEditorServices/Commands/PowerShellEditorServices.Commands.psd1) - # Default prefix for commands exported from this module. Override the default prefix using Import-Mo...

20. [Beginning Use of PowerShell Runspaces: Part 1](https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-1/) - Runspaces create a new thread on the existing process, and you can simply add what you need to it an...

21. [PowerShell Runspaces Deep Dive - Jordan Borean, Justin Grote](https://www.youtube.com/watch?v=U1eihsrazAA) - ... use Github Codespaces to enable you to try out these advanced parallelism ... Summary (autogen):...

22. [Invoke-Parallel need help to clone the current Runspace](https://forums.powershell.org/t/invoke-parallel-need-help-to-clone-the-current-runspace/2605) - I dont think the PowerShell Team offers a InitialSessionState.Variables.Add() Method to us, if there...

23. [Is it possible to share module between runspaces or assign a ...](https://stackoverflow.com/questions/67390868/is-it-possible-to-share-module-between-runspaces-or-assign-a-module-to-a-runspac) - So the answer is yes, I found out that you can use a property from initialsessionstate called Import...

24. [Using custom Functions and Types in PowerShell Runspaces](https://communary.net/2016/10/01/using-custom-functions-and-types-in-powershell-runspaces/) - The first thing we need to do is to create an InitialSessionState (ISS) object. This object is used ...

25. [Beginning Use of PowerShell Runspaces: Part 3](https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-3/) - We are taking the next step in our journey by looking at runspace pools to do some multithreading wi...

26. [More on PowerShell multithreading via runspace pools](https://davewyatt.wordpress.com/2014/04/12/more-on-powershell-multithreading-via-runspace-pools/) - First, I just added Import-Module calls to each background job to make sure they could access the Lo...

27. [Windows PowerShell and Named Pipes | Keith Hill's Blog](https://rkeithhill.wordpress.com/2014/11/01/windows-powershell-and-named-pipes/) - Named pipes provide one-way or duplex pipes for communication between a pipe server and one or more ...

28. [PowerShell Host IPC for any .NET application - AwakeCoding ☀️](https://awakecoding.com/posts/powershell-host-ipc-for-any-dotnet-application/) - Every PowerShell process has a default named pipe listener with a name that can be reconstructed usi...

29. [RemoteSessionNamedPipe.cs - GitHub](https://github.com/PowerShell/PowerShell/blob/master/src/System.Management.Automation/engine/remoting/common/RemoteSessionNamedPipe.cs) - // Unless opt-out, all PowerShell instances will start with the named-pipe listener created and runn...

30. [PSPipe.psm1 1.0.0.0 - PowerShell Gallery](https://www.powershellgallery.com/packages/PSPipe/1.0.0.0/Content/PSPipe.psm1) - Creates a named pipe and waits for a client to connect. .PARAMETER Name Name to give to pipe. .OUTPU...

31. [Tadas/PSNamedPipes: Asynchronous named pipe module ... - GitHub](https://github.com/Tadas/PSNamedPipes) - Asynchronous named pipe module for PowerShell. Contribute to Tadas ... NamedPipeServerStream] that i...

32. [Asynchronous named pipes in powershell using callbacks](https://stackoverflow.com/questions/31338421/asynchronous-named-pipes-in-powershell-using-callbacks) - I'm attempting to use a named pipe using a .net NamedPipeServerStream asynchronously using callbacks...

33. [Run command script as separate process powershell.exe and pwsh ...](https://stackoverflow.com/questions/71468290/run-command-script-as-separate-process-powershell-exe-and-pwsh-exe-compatible) - Is there any easy way to invoke a powershell script in separate process while being cross-platform (...

34. [PowerShell background jobs unlock scripting performance](https://www.techtarget.com/searchwindowsserver/tutorial/Try-these-PowerShell-Start-Job-examples-for-more-efficiency) - PowerShell background jobs can boost the speed of your scripts, but this tutorial explains some of t...

35. [How to: Use Named Pipes for Network Interprocess Communication](https://learn.microsoft.com/en-us/dotnet/standard/io/how-to-use-named-pipes-for-network-interprocess-communication) - Named pipes provide interprocess communication between a pipe server and one or more pipe clients. T...

36. [NamedPipeConnectionInfo Class (System.Management.Automation ...](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.namedpipeconnectioninfo?view=powershellsdk-7.4.0) - Class used to create an Out-Of-Process Runspace/RunspacePool between two local processes using a nam...

