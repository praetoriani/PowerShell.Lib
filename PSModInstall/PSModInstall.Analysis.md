<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***

# PSModInstall – Developer Task Liste \& Analyse

## Präambel

Diese Analyse basiert auf einer vollständigen Code-Durchsicht des aktuellen `PSModInstall.ps1`-Skripts und kategorisiert alle identifizierten Punkte in drei Prioritätsstufen: **Sicherheit**, **Optimierung** und **neue Features**.

***

## 🔴 Kategorie 1 — Sicherheitsrelevante Tasks (Höchste Priorität)


***

### SEC-01 · Ziel-Pfad-Containment-Check fehlt

**Problem:** Der aktuelle Code löst den *Quell*-Pfad via `Resolve-Path` auf und prüft, ob er absolute Form hat — aber das **Zielpfad-Konstrukt** wird niemals gegen ein Basis-Verzeichnis validiert. Ein manipulierter `-ModuleName`-Parameter wie `"../../Windows/System32/fake"` würde den `Join-Path`-Aufruf in ein vollkommen unerwünschtes Verzeichnis außerhalb von `WindowsPowerShell\Modules` leiten.

**Lösungsansatz:**

```powershell
# Nach dem Aufbau von $targetPath:
$allowedBasePath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
$resolvedTarget  = [System.IO.Path]::GetFullPath($targetPath)

if (-not $resolvedTarget.StartsWith($allowedBasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "  [ERROR] Target path escapes the allowed module base directory!" -ForegroundColor Red
    exit 1
}
```


***

### SEC-02 · ModuleName-Whitelist-Validierung fehlt (Injection-Gefahr)

**Problem:** Der `-ModuleName`-Parameter wird direkt in Dateisystem-Operationen und Robocopy-Argumente eingebettet, ohne jemals auf unerlaubte Sonderzeichen geprüft zu werden. Zeichen wie `&`, `;`, `|`, `"`, `````, Leerzeichen oder Unicode-Homoglyphen können in bestimmten Kontexten zu Argument-Injection führen.

**Lösungsansatz:**

```powershell
# Strict whitelist: nur alphanumerische Zeichen, Punkte, Bindestriche und Unterstriche
if ($ModuleName -notmatch '^[a-zA-Z0-9_.\-]{1,128}$') {
    Write-Host "  [ERROR] ModuleName contains invalid characters." -ForegroundColor Red
    Write-Host "          Allowed: A-Z, a-z, 0-9, underscore, hyphen, dot (max. 128 chars)" -ForegroundColor Red
    exit 1
}
```


***

### SEC-03 · Robocopy-Argumente werden unsicher konstruiert

**Problem:** Die Robocopy-Argumente werden als Array aus direkt interpolierten Strings zusammengebaut. Obwohl `Start-Process` mit `-ArgumentList` sicherer als ein direkter `Invoke-Expression`-Aufruf ist, können gequotete Pfade mit eingebetteten Sonderzeichen (z. B. Anführungszeichen im Pfad-String) das Argument-Parsing von `robocopy.exe` korrumpieren.

**Lösungsansatz:** Robocopy-Argumente per `[System.Diagnostics.ProcessStartInfo]` mit expliziter `ArgumentList`-Property übergeben, die keine Shell-Interpretation durchläuft. Alternativ: Pfade vorab mit `[System.IO.Path]::GetFullPath()` normalisieren und anschließend auf verbotene Zeichen prüfen, bevor sie in den Argument-String einfließen.

***

### SEC-04 · Kein Hash-Integrity-Check nach dem Kopiervorgang

**Problem:** Nach dem Robocopy-Durchlauf gibt es keinerlei Überprüfung, ob die kopierten Dateien integer sind. Ein Man-in-the-Middle beim Schreiben auf das Dateisystem (z. B. durch ein paralleles Process, das Dateien manipuliert) oder ein stiller I/O-Fehler bleibt vollständig unentdeckt.

**Lösungsansatz:** Vor dem Kopiervorgang SHA256-Hashes aller Quelldateien erfassen (`Get-FileHash`), nach dem Kopiervorgang die Zieldateien hashen und beide Listen vergleichen. Bei Abweichung: Rollback durch erneutes `Remove-Item` auf das Zielverzeichnis und Fehlerabbruch.

```powershell
function Compare-ModuleHashes {
    param([string]$SourcePath, [string]$TargetPath)

    $sourceHashes = Get-ChildItem -Recurse -File $SourcePath |
        ForEach-Object { Get-FileHash $_.FullName -Algorithm SHA256 }

    foreach ($h in $sourceHashes) {
        $relativePath  = $h.Path.Substring($SourcePath.Length).TrimStart('\')
        $targetFile    = Join-Path $TargetPath $relativePath
        $targetHash    = (Get-FileHash $targetFile -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
        if ($h.Hash -ne $targetHash) { return $false }
    }
    return $true
}
```


***

### SEC-05 · Temp-Dateien in `$env:TEMP` sind angreifbar (TOCTOU)

**Problem:** Das Skript leitet Robocopy stdout/stderr in `$env:TEMP\robocopy_stdout.tmp` und `robocopy_stderr.tmp` um. Da `$env:TEMP` ein systemweites, für alle Benutzer (oder zumindest alle Prozesse des aktuellen Nutzers) schreibbares Verzeichnis ist, besteht ein **Time-of-check-to-time-of-use (TOCTOU)**-Risiko: Ein paralleler Prozess könnte die Temp-Datei überschreiben oder auslesen.

**Lösungsansatz:** Statt fixer Dateinamen einen temporären Pfad mit garantiert einmaligem Namen verwenden:

```powershell
$tempStdout = [System.IO.Path]::GetTempFileName()
$tempStderr = [System.IO.Path]::GetTempFileName()
```

`GetTempFileName()` erstellt atomisch eine leere Datei mit einer GUID-basierten Bezeichnung und gibt den Pfad zurück — keine Race Condition möglich.

***

### SEC-06 · Kein Schutz gegen Symlink-Angriffe im Zielverzeichnis

**Problem:** Wenn ein Angreifer vor der Ausführung des Skripts an der Stelle des Zielverzeichnisses einen **symbolischen Link** auf ein kritisches Systemverzeichnis platziert (z. B. `$env:ProgramFiles\WindowsPowerShell\Modules\WinISO.ScriptFXLib` → `C:\Windows\System32`), wird `Remove-Item -Recurse -Force` bei aktiviertem `-Force` den Inhalt des Symlink-Ziels löschen, nicht nur den Link selbst.

**Lösungsansatz:** Vor `Remove-Item` prüfen, ob das Zielverzeichnis ein Symlink/Junction ist:

```powershell
$dirInfo = Get-Item -Path $TargetPath -ErrorAction SilentlyContinue
if ($dirInfo.LinkType -in @('SymbolicLink','Junction','HardLink')) {
    # Nur den Link selbst entfernen, NICHT den Inhalt
    [System.IO.Directory]::Delete($TargetPath, $false)
}
```


***

## 🟡 Kategorie 2 — Optimierung \& Verbesserung bestehenden Codes


***

### OPT-01 · Robocopy läuft ohne Timeout / Hänger-Schutz

**Problem:** `Start-Process -Wait` blockiert das Skript unbegrenzt. Hängt Robocopy (z. B. aufgrund eines gesperrten Netzlaufwerks oder eines Dateisystem-Deadlocks), terminiert das Skript nie.

**Lösungsansatz:**

```powershell
$process = Start-Process robocopy.exe -ArgumentList $roboArgs -PassThru -WindowStyle Hidden ...
if (-not $process.WaitForExit(60000)) {  # 60 Sekunden Timeout
    $process.Kill()
    $status.code = -1
    $status.msg  = "Robocopy timed out after 60 seconds and was terminated."
}
```


***

### OPT-02 · `Validate-ModuleSource` gibt den aufgelösten Pfad als `$status.msg` zurück

**Problem:** Das aktuelle Design missbraucht `$status.msg` als Rückgabekanal für den kanonischen Quellpfad (`$validationResult.msg` enthält dann den Pfad statt einer Fehlermeldung). Das verletzt das Prinzip des `$status`-Objekts, bricht die Konsistenz und macht den Code schwer wartbar.

**Lösungsansatz:** Das Status-Objekt um ein drittes Feld `data` erweitern:

```powershell
$status = [PSCustomObject]@{
    code = -1
    msg  = ""
    data = $null   # generisches Nutzlast-Feld für Rückgabewerte
}
# In Validate-ModuleSource:
$status.code = 0
$status.data = $resolvedPath  # Kanonischer Pfad hier
$status.msg  = ""
```


***

### OPT-03 · Fehlende `$ErrorActionPreference`-Initialisierung

**Problem:** Das Skript setzt `$ErrorActionPreference` nirgendwo explizit. Standardmäßig ist dieser Wert in PowerShell `Continue`, was bedeutet, dass nicht-terminierende Fehler (z. B. bei `Get-ChildItem`) ohne Abbruch still weiterlaufen.

**Lösungsansatz:** Direkt nach den globalen Variablen setzen:

```powershell
$ErrorActionPreference = 'Stop'
```

Damit werden alle Fehler als terminierende Fehler behandelt und landen im jeweiligen `try/catch`-Block — kein Fehler kann mehr unbemerkt durchrutschen.

***

### OPT-04 · `Remove-ExistingModule` verwendet keine atomare Operation

**Problem:** Zwischen dem `Test-Path`-Check und dem `Remove-Item`-Aufruf in `Remove-ExistingModule` gibt es eine Race Condition. Verschwindet das Verzeichnis in diesem kurzen Zeitfenster (z. B. durch ein paralleles Skript), wirft `Remove-Item` trotz `ErrorAction Stop` keinen Fehler, der Zustand ist aber dennoch unbekannt.

**Lösungsansatz:** `Test-Path` entfernen und `Remove-Item` direkt mit `ErrorAction SilentlyContinue` aufrufen, dann den Exit-Code/Exception auswerten. Ein nicht-existentes Verzeichnis ist kein Fehler:

```powershell
try {
    Remove-Item -Path $TargetPath -Recurse -Force -ErrorAction Stop
} catch [System.IO.DirectoryNotFoundException] {
    # Not an error — directory didn't exist
} catch {
    $status.code = -1
    $status.msg  = "Failed to remove: $($_.Exception.Message)"
}
```


***

### OPT-05 · Robocopy-Logging-Pfad ignoriert `$PSScriptRoot`-Konvention

**Problem:** Die Log-Datei wird in `(Get-Location).Path` angelegt, also im aktuellen Arbeitsverzeichnis zur Laufzeit. Wird das Skript aus einem anderen Verzeichnis aufgerufen (was in Automatisierungsszenarien Standard ist), landet das Log an einem unerwarteten Ort.

**Lösungsansatz:** Log-Pfad auf `$global:AppPath` (`$PSScriptRoot`) basieren, aber per Parameter überschreibbar machen:

```powershell
$logFilePath = Join-Path -Path $global:AppPath -ChildPath "PSModInstall.log"
```


***

### OPT-06 · Kein Rollback bei fehlgeschlagener Installation

**Problem:** Schlägt Robocopy mit einem Exit-Code ≥ 8 fehl, bleibt das Zielverzeichnis möglicherweise in einem **halb-kopierten, inkonsistenten Zustand** zurück — besonders, wenn `-Force` zuvor das alte Modul gelöscht hat.

**Lösungsansatz:** Vor dem Robocopy-Aufruf den ursprünglichen Zustand des Zielverzeichnisses in einem Temp-Pfad sichern. Bei Fehlschlag: Backup zurückkopieren. Bei Erfolg: Backup löschen.

```powershell
$backupPath = "$targetPath._backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
if (Test-Path $targetPath) {
    Copy-Item $targetPath $backupPath -Recurse -Force
}
# ... Robocopy ...
if ($installResult.code -ne 0) {
    Remove-Item $targetPath -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $backupPath) { Move-Item $backupPath $targetPath }
}
```


***

### OPT-07 · Konsolen-Ausgabe nicht konsistent formatierbar

**Problem:** Alle `Write-Host`-Aufrufe sind direkt im Hauptprogramm und in den Funktionen fest verdrahtet. Das Skript bietet kein `-Silent`- oder `-Quiet`-Flag, um die Ausgabe zu unterdrücken — wichtig für den Einsatz in CI/CD-Pipelines oder `Start-Job`-Szenarien.

**Lösungsansatz:** Ausgabe-Logik in eine zentrale Funktion `Write-StatusLine` auslagern, die über eine globale Variable `$global:SilentMode` steuerbar ist:

```powershell
function Write-StatusLine {
    param([string]$Message, [string]$Color = "White")
    if (-not $global:SilentMode) { Write-Host $Message -ForegroundColor $Color }
    # Hier kann später auch Write-Verbose/Write-Information eingehängt werden
}
```


***

### OPT-08 · Manifest-Validierung prüft nur `ModuleVersion`

**Problem:** `Import-PowerShellDataFile` wird genutzt, um das `.psd1`-Manifest zu lesen, aber es wird nur das Feld `ModuleVersion` geprüft. Ein Manifest mit fehlerhaftem `RootModule`-Verweis (Datei zeigt auf eine nicht existente `.psm1`) würde als gültig durchkommen.

**Lösungsansatz:** Nach der `ModuleVersion`-Prüfung zusätzlich validieren, ob das deklarierte `RootModule` oder `ModuleToProcess` tatsächlich im Quellverzeichnis existiert:

```powershell
if ($manifestData.RootModule) {
    $rootModulePath = Join-Path $resolvedPath $manifestData.RootModule
    if (-not (Test-Path $rootModulePath)) {
        $status.code = -1
        $status.msg  = "RootModule '$($manifestData.RootModule)' declared in manifest not found in source."
        return $status
    }
}
```


***

## 🟢 Kategorie 3 — Neue Features


***

### FEAT-01 · Side-by-Side Versionsinstallation (SxS)

**Beschreibung:** PowerShell unterstützt das Side-by-Side-Installationsmodell, bei dem mehrere Versionen eines Moduls gleichzeitig installiert sind — in Unterordnern benannt nach der Versionsnummer (`Modules\WinISO.ScriptFXLib\1.0.0\`). Das aktuelle Skript ignoriert dieses Modell vollständig und installiert immer in den Root-Ordner.

```
**Lösungsansatz:** Neuen Parameter `-SxS [switch]` hinzufügen. Wenn gesetzt, wird die `ModuleVersion` aus dem `.psd1`-Manifest ausgelesen und das Modul nach `Modules\<ModuleName>\<Version>\` installiert:
```

```powershell
if ($SxS.IsPresent -and $manifestData.ModuleVersion) {
    $targetPath = Join-Path $targetBasePath "$ModuleName\$($manifestData.ModuleVersion)"
}
```


***

### FEAT-02 · Pre/Post-Installation Hooks

**Beschreibung:** Für komplexe Module ist es oft notwendig, vor oder nach der Installation Aktionen auszuführen: Registry-Einträge setzen, Dienste neu starten, Abhängigkeiten installieren, etc.

**Lösungsansatz:** Das Skript prüft, ob im Quellverzeichnis eine optionale Datei `PSModInstall.hooks.ps1` existiert. Diese Datei kann zwei Funktionen definieren: `Invoke-PreInstall` und `Invoke-PostInstall`, die automatisch aufgerufen werden:

```powershell
$hooksFile = Join-Path $canonicalSource "PSModInstall.hooks.ps1"
if (Test-Path $hooksFile) {
    . $hooksFile  # Dot-source the hooks file
    if (Get-Command 'Invoke-PreInstall' -ErrorAction SilentlyContinue) {
        Invoke-PreInstall
    }
}
```


***

### FEAT-03 · Automatisches Backup vor Installation

**Beschreibung:** Anstatt (oder zusätzlich zu) `-Force` könnte ein Parameter `-Backup [switch]` das bestehende Modul vor der Überschreibung in ein konfigurierbares Backup-Verzeichnis archivieren — entweder als ZIP oder als Ordnerkopie mit Timestamp.

**Lösungsansatz:**

```powershell
if ($Backup.IsPresent -and (Test-Path $targetPath)) {
    $backupDir  = Join-Path $global:AppPath "backups"
    $backupName = "$ModuleName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $backupDest = Join-Path $backupDir $backupName
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item $targetPath $backupDest -Recurse -Force
    Compress-Archive -Path $backupDest -DestinationPath "$backupDest.zip" -Force
    Remove-Item $backupDest -Recurse -Force
}
```


***

### FEAT-04 · WhatIf-Unterstützung (`-WhatIf`)

**Beschreibung:** PowerShell-Skripte, die Systemzustand ändern, sollten den `ShouldProcess`-Mechanismus unterstützen. Mit `-WhatIf` könnten Administratoren die geplanten Aktionen simulieren, ohne tatsächlich etwas zu verändern — ideal für Pre-Deployment-Reviews.

**Lösungsansatz:** `[CmdletBinding(SupportsShouldProcess)]` aktivieren und alle destruktiven Operationen mit `$PSCmdlet.ShouldProcess()` wrappen:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]

# Vor Remove-Item:
if ($PSCmdlet.ShouldProcess($targetPath, "Remove existing module directory")) {
    Remove-Item -Path $targetPath -Recurse -Force
}
```


***

### FEAT-05 · Mehrere Ziel-Scopes (User vs. System)

**Beschreibung:** Aktuell installiert das Skript immer in `$env:ProgramFiles` (systemweit). Es wäre sinnvoll, auch eine benutzerspezifische Installation in `$env:USERPROFILE\Documents\WindowsPowerShell\Modules` zu unterstützen, die keine Administratorrechte erfordert.

**Lösungsansatz:** Neuer Parameter `-Scope [ValidateSet('AllUsers','CurrentUser')]`:

```powershell
param (
    [ValidateSet('AllUsers', 'CurrentUser')]
    [string]$Scope = 'AllUsers'
)

$targetBasePath = switch ($Scope) {
    'AllUsers'    { Join-Path $env:ProgramFiles "WindowsPowerShell\Modules" }
    'CurrentUser' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules" }
}
```

Beim Scope `AllUsers` bleibt der Admin-Check aktiv, beim Scope `CurrentUser` entfällt er.

***

### FEAT-06 · Dependency-Check vor der Installation

**Beschreibung:** Das `.psd1`-Manifest kann im Feld `RequiredModules` Abhängigkeiten zu anderen Modulen deklarieren. Das Skript prüft diese derzeit nicht. Wird ein Modul installiert, dessen Abhängigkeiten fehlen, führt `Import-Module` später zu kryptischen Fehlern.

**Lösungsansatz:**

```powershell
if ($manifestData.RequiredModules) {
    foreach ($dep in $manifestData.RequiredModules) {
        $depName = if ($dep -is [hashtable]) { $dep.ModuleName } else { $dep }
        $existing = Get-Module -ListAvailable -Name $depName
        if (-not $existing) {
            Write-Host "  [WARNING] Required dependency '$depName' is not installed." -ForegroundColor DarkYellow
        }
    }
}
```


***

### FEAT-07 · Uninstall-Modus (`-Uninstall [switch]`)

**Beschreibung:** Ein vollständiges Installations-Framework sollte auch das Deinstallieren eines Moduls unterstützen. Durch einen `-Uninstall`-Switch könnte das Skript das Modul aus dem Zielverzeichnis entfernen — mit optionalem Backup-Schritt davor.

***

### FEAT-08 · Digitale Signatur-Verifizierung der Quelldateien

**Beschreibung:** Für Unternehmensumgebungen sollte sichergestellt sein, dass die zu installierenden `.psm1`- und `.ps1`-Dateien digital signiert und die Signatur von einer vertrauenswürdigen Stelle stammt.

**Lösungsansatz:**

```powershell
# Neuer Parameter: -RequireSigning [switch]
if ($RequireSigning.IsPresent) {
    $unsignedFiles = Get-ChildItem -Recurse -Path $canonicalSource -Include "*.ps1","*.psm1" |
        Where-Object { (Get-AuthenticodeSignature $_.FullName).Status -ne 'Valid' }

    if ($unsignedFiles.Count -gt 0) {
        Write-Host "  [ERROR] The following files have no valid digital signature:" -ForegroundColor Red
        $unsignedFiles | ForEach-Object { Write-Host "          $($_.FullName)" -ForegroundColor Red }
        exit 1
    }
}
```


***

## Prioritäts-Übersicht

| ID | Kategorie | Titel | Priorität |
| :-- | :-- | :-- | :-- |
| SEC-01 | 🔴 Security | Ziel-Pfad-Containment-Check | **Kritisch** |
| SEC-02 | 🔴 Security | ModuleName-Whitelist | **Kritisch** |
| SEC-03 | 🔴 Security | Robocopy-Argument-Injection | **Hoch** |
| SEC-04 | 🔴 Security | Hash-Integrity nach Kopiervorgang | **Hoch** |
| SEC-05 | 🔴 Security | TOCTOU bei Temp-Dateien | **Mittel** |
| SEC-06 | 🔴 Security | Symlink-Angriff bei `-Force` | **Mittel** |
| OPT-01 | 🟡 Optimierung | Robocopy Timeout-Schutz | **Hoch** |
| OPT-02 | 🟡 Optimierung | `$status.msg` als Rückgabekanal | **Hoch** |
| OPT-03 | 🟡 Optimierung | `$ErrorActionPreference = Stop` | **Hoch** |
| OPT-04 | 🟡 Optimierung | Race Condition in Remove-Funktion | **Mittel** |
| OPT-05 | 🟡 Optimierung | Log-Pfad auf `$PSScriptRoot` basieren | **Mittel** |
| OPT-06 | 🟡 Optimierung | Rollback bei fehlgeschlagener Installation | **Mittel** |
| OPT-07 | 🟡 Optimierung | Silent-Mode für CI/CD | **Niedrig** |
| OPT-08 | 🟡 Optimierung | Erweiterte Manifest-Validierung | **Niedrig** |
| FEAT-01 | 🟢 Feature | Side-by-Side Versionsinstallation | **Hoch** |
| FEAT-02 | 🟢 Feature | Pre/Post-Install Hooks | **Mittel** |
| FEAT-03 | 🟢 Feature | Automatisches Backup | **Mittel** |
| FEAT-04 | 🟢 Feature | `-WhatIf`-Unterstützung | **Mittel** |
| FEAT-05 | 🟢 Feature | Scope (AllUsers / CurrentUser) | **Hoch** |
| FEAT-06 | 🟢 Feature | Dependency-Check | **Mittel** |
| FEAT-07 | 🟢 Feature | Uninstall-Modus | **Niedrig** |
| FEAT-08 | 🟢 Feature | Digitale Signatur-Verifizierung | **Hoch (Enterprise)** |


***

## Empfohlene Implementierungs-Reihenfolge

Die empfohlene Reihenfolge folgt dem Prinzip **Security first, dann Stabilität, dann Komfort**:

1. **Sprint 1 (Sofort):** SEC-01, SEC-02, SEC-03, OPT-02, OPT-03 — diese Punkte beheben fundamentale Sicherheits- und Designlücken ohne großen Umbau
2. **Sprint 2 (Kurzfristig):** SEC-04, SEC-05, SEC-06, OPT-01, OPT-04, OPT-06 — Robustheit und Resilienz gegen Fehler und Angriffe
3. **Sprint 3 (Mittelfristig):** OPT-05, OPT-07, OPT-08, FEAT-01, FEAT-05 — Optimierungen und die zwei wichtigsten Features
4. **Sprint 4 (Langfristig):** FEAT-02, FEAT-03, FEAT-04, FEAT-06, FEAT-07, FEAT-08 — vollständiges Feature-Set für Enterprise-Einsatz

