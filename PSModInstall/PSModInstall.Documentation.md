<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***

## Dokumentation: PSModInstall.ps1

### Übersicht

`PSModInstall.ps1` ist ein PowerShell-Installationsskript, das ein lokales PowerShell-Modul global auf dem System bereitstellt, indem es dieses in den systemweiten Modulpfad `$env:ProgramFiles\WindowsPowerShell\Modules\<ModulName>` kopiert. Das Skript validiert die Quelle, prüft Administrator-Rechte, und verwendet Robocopy als zuverlässigen Kopiermechanismus.

***

### Parameter-Referenz

| Parameter | Typ | Pflicht | Beschreibung |
| :-- | :-- | :-- | :-- |
| `-ModuleName` | `string` | ✅ Ja | Name des Moduls; wird als Zielordnername verwendet |
| `-Source` | `string` | ✅ Ja | Pfad zum Quellverzeichnis des Moduls |
| `-Force` | `switch` | ❌ Nein | Löscht das Zielverzeichnis vor der Installation vollständig |
| `-WriteLog` | `switch` | ❌ Nein | Schreibt einen Robocopy-Log nach `PSModInstall.log` im aktuellen Verzeichnis |


***

### Voraussetzungen

Folgende Bedingungen müssen erfüllt sein, damit das Skript korrekt funktioniert:

- **PowerShell 5.1** (Windows PowerShell) oder **PowerShell 7+**
- **Administrator-Rechte** sind zwingend erforderlich, da in `$env:ProgramFiles` geschrieben wird
- **Robocopy** muss verfügbar sein (ab Windows Vista/Server 2008 standardmäßig enthalten)
- Das Quellverzeichnis muss mindestens eine `.psd1`- oder `.psm1`-Datei enthalten

***

### Modul-Validierung im Detail

Das Skript führt eine mehrstufige Validierung durch, bevor irgendetwas kopiert wird:

1. **Existenzprüfung** — Ist der angegebene `-Source`-Pfad vorhanden und ein Verzeichnis?
2. **Pfad-Kanonisierung** — `Resolve-Path` löst relative Pfade auf und verhindert Directory-Traversal-Angriffe
3. **Modul-Erkennung** — Mindestens eine `.psd1`- oder `.psm1`-Datei muss im Verzeichnis liegen
4. **Manifest-Validierung** — Ist eine `.psd1` vorhanden, wird sie mit `Import-PowerShellDataFile` geparst und auf das Pflichtfeld `ModuleVersion` geprüft

Schlägt eine dieser Prüfungen fehl, bricht das Skript mit einer aussagekräftigen Fehlermeldung ab, ohne das Zielverzeichnis zu verändern.

***

### Robocopy Exit-Code-Logik

Robocopy verwendet Exit-Codes, die sich von Standard-Codes unterscheiden:


| Exit-Code | Bedeutung | Behandlung |
| :-- | :-- | :-- |
| `0` | Keine Dateien kopiert (Quelle = Ziel) | ✅ Erfolg |
| `1` | Dateien erfolgreich kopiert | ✅ Erfolg |
| `2` | Extra-Dateien im Ziel gefunden | ✅ Erfolg |
| `3` | Kombination aus 1 und 2 | ✅ Erfolg |
| `4` | Abweichende Dateien gefunden | ✅ Erfolg |
| `≥ 8` | Echter Fehler aufgetreten | ❌ Abbruch |

Das Skript wertet den Exit-Code korrekt aus — Exit-Codes unter 8 gelten als Erfolg.

***

### Verwendungsbeispiele

**Einfache Installation:**

```powershell
.\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib"
```

**Installation mit vollständiger Bereinigung des Zielverzeichnisses:**

```powershell
.\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib" -Force
```

**Installation mit Log-Datei:**

```powershell
.\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib" -WriteLog
```

**Vollständige Installation mit Bereinigung und Log:**

```powershell
.\PSModInstall.ps1 -ModuleName "WinISO.ScriptFXLib" -Source ".\PowerShell.Mods\WinISO.ScriptFXLib" -Force -WriteLog
```

**Als Administrator starten (direkt aus PowerShell heraus):**

```powershell
Start-Process powershell -ArgumentList "-File .\PSModInstall.ps1 -ModuleName WinISO.ScriptFXLib -Source .\PowerShell.Mods\WinISO.ScriptFXLib -Force" -Verb RunAs
```


***

### Ablauf des Skripts (Schritt für Schritt)

Das Skript durchläuft bei jedem Aufruf exakt sechs definierte Schritte:

1. **Admin-Check** — Bricht sofort ab, wenn keine Administratorrechte vorhanden sind
2. **Quell-Validierung** — Mehrstufige Prüfung der Quelle (Existenz, Kanonisierung, Modulerkennung, Manifest-Prüfung)
3. **Zielpfad-Aufbau** — Berechnet `$env:ProgramFiles\WindowsPowerShell\Modules\<ModuleName>`
4. **Force-Bereinigung** — Wenn `-Force` gesetzt: Zielverzeichnis rekursiv löschen
5. **Robocopy-Installation** — Stilles Kopieren mit `/E /NFL /NDL /NJH /NJS /NP`; bei `-WriteLog` zusätzlich `/LOG:PSModInstall.log`
6. **Verifikation** — Prüft, ob das Zielverzeichnis nach der Installation tatsächlich existiert

***

### Wichtige Hinweise

- Das Skript **muss als Administrator** ausgeführt werden, da `$env:ProgramFiles` erhöhte Rechte erfordert. Ohne Adminrechte bricht es in Schritt 1 ab.
- Der **`-Force`-Parameter ist empfohlen** bei Updates, da er sicherstellt, dass veraltete Dateien im Zielverzeichnis vollständig entfernt werden, bevor die neuen eingespielt werden.
- Die **Log-Datei** `PSModInstall.log` wird im **aktuellen Arbeitsverzeichnis** (`Get-Location`) angelegt, nicht im Skriptverzeichnis — das ist bewusst so, damit man den Log-Pfad durch `Set-Location` vor dem Skriptaufruf steuern kann.
- Das Skript folgt vollständig den definierten App Development Instructions: Standardisierter Header, globale Variablen, `$status`-Objekte als Rückgabewerte aller Funktionen, englische Code-Kommentare und Pfad-Validierung/Kanonisierung.

