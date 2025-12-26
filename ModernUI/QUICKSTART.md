# ModernUI v1.00.00 - Quick Start Guide

## 🌠 5-Minuten Starteranleitung

### Schritt 1: Repository klonen

```powershell
git clone https://github.com/praetoriani/PowerShell.Lib.git
cd PowerShell.Lib\ModernUI
```

### Schritt 2: Starten

```powershell
.\ModernUI.ps1
```

### Schritt 3: Fenster testen

✅ **Fenster öffnet sich**
- Rahmenloses Design mit Hintergrundbild
- Titelleiste mit Icon
- Close Button auf der rechten Seite

✅ **Close Button testen**
- **Normal:** Grau angezeigt
- **Hover:** Rot angezeigt (bei Mauszeiger)
- **Click:** Fenster schliesst sich

✅ **Fenster verschieben**
- Klick auf Titelleiste halten
- Fenster folgt dem Mauszeiger
- Fenster bleibt im Bildschirmbereich

---

## 🛠️ Fehlerbehandlung

### Problem: Fenster startet nicht

**Lösung 1: PowerShell-Version prüfen**
```powershell
$PSVersionTable.PSVersion
# Muss mindestens 7.0 sein
```

**Lösung 2: config.json validieren**
```powershell
# Öffne PowerShell im ModernUI Verzeichnis
Get-Content .\config.json | ConvertFrom-Json | Format-List
```

Sollte folgende Ausgabe zeigen:
```
version                       : 1.00.00
application                   : @{name=ModernUI; description=Modern UI Framework for PowerShell WPF; author=Marc Sczepanski (praetoriani)}
window                        : @{title=ModernUI v1.00.00; width=800; height=600; startupLocation=CenterScreen}
paths                         : @{baseImagePath=./PNG; windowIcon=appicon.png; backgroundImage=ModernUI-WinBG.png; closeButtonNormalPath=axn-winclose-normal.png; closeButtonHoverPath=axn-winclose-hover.png}
```

**Lösung 3: Bilder prüfen**
```powershell
# Öberprüfe ob PNG Verzeichnis existiert
Get-ChildItem .\PNG
```

Sollte folgende Dateien zeigen:
```
    Directory: C:\Users\...\ModernUI\PNG

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           26.12.2025 19:30           5907 ModernUI-WinBG.png
-a---           26.12.2025 19:30           1907 appicon.png
-a---           26.12.2025 19:30           2042 axn-winclose-hover.png
-a---           26.12.2025 19:30           2079 axn-winclose-normal.png
```

**Lösung 4: Mit Verbose-Ausgabe starten**
```powershell
.\ModernUI.ps1 -Verbose
```

Dies zeigt detaillierte Lade-Informationen.

---

## 🔍 Debugging-Tipps

### Schritt 1: Pfade prüfen

```powershell
# In PowerShell im ModernUI Verzeichnis:
$PSScriptRoot
$PNG_Path = Join-Path $PSScriptRoot "PNG"
Test-Path $PNG_Path
```

### Schritt 2: Einzelne Bilder testen

```powershell
# Prüfe ob Bilder existieren
Test-Path (Join-Path $PNG_Path "appicon.png")
Test-Path (Join-Path $PNG_Path "ModernUI-WinBG.png")
Test-Path (Join-Path $PNG_Path "axn-winclose-normal.png")
Test-Path (Join-Path $PNG_Path "axn-winclose-hover.png")
```

Alle sollten `True` zurückgeben.

### Schritt 3: JSON validieren

```powershell
# Lese und parse config.json manuell
$config = Get-Content ".\config.json" -Raw | ConvertFrom-Json
$config.paths
```

Sollte folgendes anzeigen:
```powershell
baseImagePath         : ./PNG
windowIcon            : appicon.png
backgroundImage       : ModernUI-WinBG.png
closeButtonNormalPath : axn-winclose-normal.png
closeButtonHoverPath  : axn-winclose-hover.png
```

---

## 🔨 Customization

### Fenster-Große ändern

**In config.json:**
```json
"window": {
  "title": "Meine App",
  "width": 1200,      // Neue Breite
  "height": 800      // Neue Höhe
}
```

### Titeltext ändern

**In config.json:**
```json
"window": {
  "title": "Meine Custom App v1.0"
}
```

### Eigene Bilder verwenden

1. **Kopiere deine PNG-Dateien ins PNG Verzeichnis:**
   ```
   ModernUI/PNG/
   ├── my-icon.png
   ├── my-background.png
   ├── my-close-normal.png
   └── my-close-hover.png
   ```

2. **Aktualisiere config.json:**
   ```json
   "paths": {
     "baseImagePath": "./PNG",
     "windowIcon": "my-icon.png",
     "backgroundImage": "my-background.png",
     "closeButtonNormalPath": "my-close-normal.png",
     "closeButtonHoverPath": "my-close-hover.png"
   }
   ```

3. **Starte ModernUI:**
   ```powershell
   .\ModernUI.ps1
   ```

---

## 📍 Systemanforderungen

- **Windows 10/11**
- **PowerShell 7.0+** (oder Windows PowerShell 5.1 mit .NET 4.8)
- **.NET Framework 4.8+**
- **PNG-Dateien** im PNG Verzeichnis

### Version prüfen

```powershell
# PowerShell Version
$PSVersionTable.PSVersion

# .NET Version
[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
```

---

## 💁 FAQ

### F: Kann ich das Fenster resizen?
**A:** Nein, das ist beabsichtigt. Das Fenster hat eine feste Größe von 800x600 (oder wie konfiguriert).

### F: Kann ich weitere Buttons hinzufügen?
**A:** Ja! Bearbeite `ModernUI.xaml` und füge weitere Button-Elemente hinzu. Dann kannst du in `ModernUI.ps1` Click-Handler registrieren.

### F: Wie kann ich das Hintergrundbild ändern?
**A:** 
1. Ersetze `ModernUI/PNG/ModernUI-WinBG.png` mit deinem PNG
2. Stelle sicher dass der Dateiname gleich bleibt
3. Oder: ändere den Namen in `config.json` im `backgroundImage` Feld

### F: Warum erscheint das Close-Button Image nicht?
**A:** Prüfe ob die Dateien existieren:
```powershell
Test-Path ".\PNG\axn-winclose-normal.png"
Test-Path ".\PNG\axn-winclose-hover.png"
```

Beide sollten `True` sein.

### F: Kann ich das Fenster minimieren?
**A:** Nein, das rahmenloses Fenster hat keine Standard-Buttons. Du kannst jedoch weitere Buttons in der Titelleiste hinzufügen.

### F: Funktioniert das auch mit Windows PowerShell?
**A:** Ja, aber nur mit PowerShell 5.1 + .NET Framework 4.8 oder höher. PowerShell 7+ wird empfohlen.

---

## 🔗 Weitere Ressourcen

- **GitHub:** https://github.com/praetoriani/PowerShell.Lib
- **Release Notes:** [RELEASE_NOTES_v1.00.00_FINAL.md](./RELEASE_NOTES_v1.00.00_FINAL.md)
- **Behebungen:** [FIXES_v1.00.00.md](./FIXES_v1.00.00.md)
- **README:** [README.md](./README.md)

---

## 📄 Support

Bei Problemen:

1. **Prüfe die FAQ** oben
2. **Führe Debugging-Tipps** durch
3. **Schau in die Release Notes** für bekannte Probleme
4. **Erstelle ein Issue** auf GitHub mit:
   - PowerShell Version (`$PSVersionTable.PSVersion`)
   - .NET Version
   - Fehlermeldung (vollständig)
   - Schritte zum Reproduzieren

---

**Version:** 1.00.00 FINAL
**Status:** ✅ Produktionsreif
**Last Updated:** 26. Dezember 2025
