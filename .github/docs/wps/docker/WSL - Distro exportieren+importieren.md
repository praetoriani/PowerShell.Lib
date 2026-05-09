<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>


## Distro exportieren (Backup erstellen)

Bevor du exportierst, empfiehlt es sich, WSL zuerst zu beenden, damit das Dateisystem konsistent ist:

```powershell
wsl --shutdown
```

Dann listest du deine installierten Distros auf, um den genauen Namen zu ermitteln:[^1_4]

```powershell
wsl --list --verbose
```

Anschließend exportierst du mit einem dieser beiden Formate:

**Als TAR-Archiv (universell, plattformübergreifend nutzbar):**

```powershell
wsl --export Ubuntu C:\Backups\WSL\Ubuntu_Backup.tar
```

**Als VHD-Datei (schneller, direkter Import möglich):**

```powershell
wsl --export --vhd Ubuntu C:\Backups\WSL\Ubuntu_Backup.vhdx
```

Das TAR-Format erzeugt ein vollständiges Abbild des Root-Dateisystems der Distribution. Das VHD-Format ist praktischer, wenn du die Distro 1:1 auf einen anderen PC verschieben möchtest.[^1_4]

## Distro wiederherstellen (Import)

**Aus TAR importieren** (erzeugt eine neue, benannte Instanz):

```powershell
wsl --import Ubuntu-Restored D:\WSL\Ubuntu C:\Backups\WSL\Ubuntu_Backup.tar
```

**Aus VHD importieren** (direkter In-Place-Import):

```powershell
wsl --import --vhd Ubuntu-Restored D:\WSL\Ubuntu C:\Backups\WSL\Ubuntu_Backup.vhdx
```

Der erste Parameter ist der neue Distro-Name, der zweite der Ordner, in dem die VHDX-Datei gespeichert wird (bei TAR), und der dritte die Backup-Datei. Nach dem Import kannst du mit `wsl --list` prüfen, ob alles erfolgreich war.[^1_4]

## Automatisiertes Backup per PowerShell

Für regelmäßige Backups kannst du ein einfaches PowerShell-Skript mit dem Windows Task Scheduler kombinieren:

```powershell
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupDir = "D:\Backups\WSL"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
wsl --shutdown
wsl --export Ubuntu "$backupDir\Ubuntu_$timestamp.tar"
```


## Typische Anwendungsfälle

| Szenario | Empfohlene Methode |
| :-- | :-- |
| Einfaches Backup auf externem Laufwerk | `--export` als `.tar` |
| Umzug auf neuen PC | `--export --vhd` + `--import --vhd` |
| Distro auf anderes Laufwerk verschieben | Export → `--unregister` → `--import` am neuen Pfad |
| Distro klonen/duplizieren | Export → `--import` mit neuem Namen |

Der gesamte Prozess funktioniert über PowerShell oder CMD direkt unter Windows, ohne dass du in die WSL-Shell selbst wechseln musst.
