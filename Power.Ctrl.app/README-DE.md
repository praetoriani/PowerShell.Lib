# Power.Ctrl.app - Installationsanleitung (Deutsch)

## Übersicht
Power.Ctrl.app ist eine erweiterte Systemsteuerungs-Anwendung, die es ermöglicht, häufige Systemaktionen wie Sperren, Abmelden, Neustart und Herunterfahren über eine benutzerfreundliche grafische Oberfläche durchzuführen. Mit Version 1.00.04 wurden wichtige Fehlerbehebungen und Verbesserungen implementiert.

## Benötigte Dateien
1. **Power.Ctrl.app.ps1** - Hauptskript der Anwendung
2. **app-ui-main.xaml** - XAML-Datei für das Hauptfenster
3. **app-ui-popup.xaml** - XAML-Datei für Bestätigungsdialoge
4. **de-de.json** - Deutsche Sprachdatei
5. **en-us.json** - Englische Sprachdatei

## Installation

### Schritt 1: Dateien vorbereiten
1. Erstellen Sie einen neuen Ordner für Power.Ctrl.app (z.B. `C:\Tools\Power.Ctrl.app\`)
2. Speichern Sie alle fünf generierten Dateien in diesem Ordner
3. Stellen Sie sicher, dass alle Dateien im gleichen Verzeichnis liegen

### Schritt 2: PowerShell Ausführungsrichtlinie
Öffnen Sie PowerShell als Administrator und führen Sie aus:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Schritt 3: Anwendung starten
Navigieren Sie zum Power.Ctrl.app-Ordner und führen Sie aus:
```powershell
.\Power.Ctrl.app.ps1
```

## Konfiguration

### Globale Variablen
Bearbeiten Sie diese Variablen am Anfang der Power.Ctrl.app.ps1-Datei:

#### Sprache ändern
```powershell
$global:globalLanguage = "de-de"  # Für Deutsch
$global:globalLanguage = "en-us"  # Für Englisch
```

#### Fensterposition festlegen
```powershell
$global:globalWindowPosition = "center"     # Bildschirmmitte
$global:globalWindowPosition = "lowerleft"  # Unten links (0px Abstand)
$global:globalWindowPosition = "lowerright" # Unten rechts (0px Abstand)
```

#### Bestätigungsdialog aktivieren/deaktivieren
```powershell
$global:globalShowConfirmationDialog = $true   # Bestätigung anzeigen
$global:globalShowConfirmationDialog = $false  # Direkte Ausführung
```

### Weitere Sprachen hinzufügen
1. Erstellen Sie eine neue JSON-Datei nach dem Muster `[sprache]-[region].json`
2. Kopieren Sie die Struktur von `de-de.json` oder `en-us.json`
3. Übersetzen Sie alle Texte (UI-Elemente, ToolTips, Console-Nachrichten, Popup-Texte)
4. Ändern Sie die `$global:globalLanguage` Variable entsprechend

## Funktionen

### Verfügbare Aktionen
- **Sperren**: Sperrt die aktuelle Arbeitssitzung (sofort)
- **Abmelden**: Meldet den aktuellen Benutzer ab (sofort)
- **Neustart**: Startet den Computer neu (sofort, keine Verzögerung)
- **Ausschalten**: Fährt den Computer herunter (sofort, keine Verzögerung)

### Features in Version 1.00.04
- ✅ **Einheitliche Fenstergrößen**: Beide Fenster 520x200 Pixel für nahtloses Switching
- ✅ **Präzise Positionierung**: 0px Abstand zu Bildschirmrändern und Taskleiste
- ✅ **Verbesserte Popup-Buttons**: Höhere Ja/Nein-Buttons für bessere Bedienbarkeit
- ✅ **Korrigierter Popup-Workflow**: Nein-Button kehrt zu Hauptfenster zurück (beendet nicht)
- ✅ **Intelligente X-Button-Behandlung**: Popup-X kehrt zu Main zurück, Main-X beendet Programm
- ✅ **Console-Management**: Automatische Console-Wiederherstellung bei Programmende ohne Aktion
- ✅ **Vollständig lokalisierte ToolTips**: Alle Hilfetexte sprachabhängig
- ✅ **Dark Mode Benutzeroberfläche**: Einheitliches dunkles Design
- ✅ **Größere Schaltflächen**: 48x48 Pixel für bessere Bedienbarkeit
- ✅ **Icons aus Windows Shell32.dll**: Systemkonforme Darstellung
- ✅ **Mehrsprachige Unterstützung**: 100% lokalisiert (UI + Console + ToolTips)
- ✅ **Immer im Vordergrund**: Beide Fenster bleiben sichtbar

## Änderungen in Version 1.00.04

### Fehlerbehebungen
1. **Identische Fenstergrößen**: Beide XAML-Dateien verwenden jetzt 520x200 Pixel
2. **Präzise Eckenpositionierung**:
   - `lowerleft`: Left = 0, Top = ScreenHeight - WindowHeight
   - `lowerright`: Left = ScreenWidth - WindowWidth, Top = ScreenHeight - WindowHeight
3. **Höhere Popup-Buttons**: MinHeight = 35px für bessere Klickbarkeit
4. **Korrigierter Nein-Button**: Kehrt zu Hauptfenster zurück statt Programm zu beenden
5. **X-Button-Logik**: Popup-X Button kehrt zu Main zurück, nur Main-X beendet Programm
6. **Console-Wiederherstellung**: Bei Programmende ohne Aktion wird Console wieder sichtbar

### Verbesserte Funktionalität
- **Return-ToMainWindow-Funktion**: Sauberer Wechsel von Popup zurück zu Main
- **Close-Application-Funktion**: Kontrolliertes Beenden mit optionaler Console-Wiederherstellung
- **Console-Management**: Separate Funktionen für Hide/Show Console
- **Event-Handler**: Popup-Closing-Event verhindert echtes Schließen und kehrt zu Main zurück

### Erweiterte JSON-Nachrichten
Neue Console-Nachrichten hinzugefügt:
- `ApplicationClosedWithoutAction`: Bei Programmende ohne Systemaktion
- `MainWindowClosing`: Bei Main-Fenster X-Button-Klick
- `PopupWindowClosing`: Bei Popup-Fenster X-Button-Klick
- `ReturnedToMainWindow`: Bei erfolgreicher Rückkehr zu Main
- `ActionExecutedClosing`: Bei Aktionsausführung vor Programmende
- Console-Handle-Management: Nachrichten für Console-Operationen

## Workflow der Anwendung

### Mit Bestätigungsdialog ($globalShowConfirmationDialog = $true)
1. **Hauptfenster** wird angezeigt an gewählter Position (520x200)
2. **User klickt Action** → Hauptfenster wird ausgeblendet
3. **Popup-Dialog** erscheint an identischer Position (520x200) mit spezifischer Bestätigung
4. **User klickt "Ja"** → Aktion wird ausgeführt, Programm beendet (ohne Console-Wiederherstellung)
5. **User klickt "Nein"** oder **X-Button** → Popup schließt, Hauptfenster wieder sichtbar
6. **User klickt Main-X** → Programm beendet mit Console-Wiederherstellung

### Ohne Bestätigungsdialog ($globalShowConfirmationDialog = $false)
1. **Hauptfenster** wird angezeigt
2. **User klickt Action** → Aktion wird sofort ausgeführt, Programm beendet
3. **User klickt Main-X** → Programm beendet mit Console-Wiederherstellung

## Fensterpositionierung

### Center (Standard)
- Position: Bildschirmmitte
- Implementierung: `WindowStartupLocation = CenterScreen`

### LowerLeft
- Position: Linke untere Ecke
- Koordinaten: `Left = 0, Top = ScreenHeight - WindowHeight`
- **0px Abstand** zu linkem Rand und Taskleiste

### LowerRight  
- Position: Rechte untere Ecke
- Koordinaten: `Left = ScreenWidth - WindowWidth, Top = ScreenHeight - WindowHeight`
- **0px Abstand** zu rechtem Rand und Taskleiste

## Fehlerbehebung

### PowerShell Ausführungsrichtlinie
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### XAML-Dateien nicht gefunden
Stellen Sie sicher, dass beide XAML-Dateien vorhanden sind:
- `app-ui-main.xaml` (Hauptfenster - 520x200)
- `app-ui-popup.xaml` (Bestätigungsdialog - 520x200)

### Fensterpositionierung funktioniert nicht
Überprüfen Sie die Variable `$global:globalWindowPosition`:
- Gültige Werte: `"center"`, `"lowerleft"`, `"lowerright"`
- Bei ungültigem Wert wird automatisch `"center"` verwendet

### Popup kehrt nicht zu Main zurück
- Überprüfen Sie dass beide XAML-Dateien die gleiche Größe haben
- Stellen Sie sicher, dass Event-Handler korrekt registriert sind
- `Return-ToMainWindow` Funktion behandelt den Wechsel

### Console wird nicht wiederhergestellt
- Console-Handle wird beim Programmstart initialisiert
- Bei normalem X-Button-Klick auf Main wird `Close-Application $true` aufgerufen
- Bei Aktionsausführung wird `Close-Application $false` aufgerufen (keine Console-Wiederherstellung)

## Anpassungen

### Fenstergrößen ändern
**WICHTIG**: Beide XAML-Dateien müssen identische Größe haben!

**Hauptfenster UND Popup** (beide Dateien ändern):
```xml
Width="520" Height="200"
```

### Button-Höhen anpassen
**Popup-Buttons** (app-ui-popup.xaml):
```xml
<Setter Property="MinHeight" Value="35"/>
```

### Positionierungs-Modi erweitern
Erweitern Sie die `Set-WindowPosition` Funktion:
```powershell
"topleft" {
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $Window.Left = 0
    $Window.Top = 0
}
"topright" {
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $Window.Left = $screenWidth - $Window.Width
    $Window.Top = 0
}
```

### Console-Verhalten anpassen
```powershell
# Console beim Start nicht minimieren
# Kommentieren Sie diese Zeile aus:
# Hide-ConsoleWindow

# Console niemals wiederherstellen
# Ändern Sie Close-Application Aufrufe zu:
Close-Application $false
```

## Technische Details

### Systemanforderungen
- Windows 7 oder höher
- PowerShell 5.0 oder höher
- .NET Framework 4.5 oder höher
- Minimum 1024x768 Bildschirmauflösung

### Verwendete Technologien
- **PowerShell mit WPF** (Windows Presentation Foundation)
- **XAML** für Benutzeroberflächen (2 identische Fenstergrößen)
- **JSON** für vollständige Lokalisierung
- **Win32 API** für Icon-Extraktion und Console-Management

### Sicherheitshinweise
- Verwendet Windows-Standardbefehle (shutdown.exe, rundll32.exe)
- **Sofortige Ausführung** ohne Wartezeit bei Restart/Shutdown
- **Bestätigungsdialog** optional aktivierbar für zusätzliche Sicherheit
- **Intelligente Programmbeendigung**: Nur bei Aktionen oder Main-X
- Keine erhöhten Berechtigungen erforderlich

### Fenster-Spezifikationen
```
Hauptfenster (app-ui-main.xaml):
- Größe: 520x200 Pixel (identisch mit Popup)
- 4 Action-Buttons (48x48 Pixel)
- Icons: 32x32 Pixel
- Position: Konfigurierbar

Popup-Fenster (app-ui-popup.xaml):
- Größe: 520x200 Pixel (identisch mit Main)
- 2 Buttons (Ja/Nein, MinHeight: 35px)
- Position: Synchronisiert mit Hauptfenster
- Modal: Blockiert Interaktion mit Hauptfenster
```

### Console-Management
```
Beim Start:     Console minimieren
Bei Main-X:     Console wiederherstellen + Programm beenden
Bei Popup-X:    Nur zu Main zurückkehren
Bei Nein:       Nur zu Main zurückkehren
Bei Ja:         Aktion ausführen + Programm beenden (ohne Console)
```

### Event-Handler-Logic
```
Main-Window:
- Action-Buttons → Handle-ActionClick
- X-Button → Close-Application $true

Popup-Window:
- Ja-Button → Execute-PendingAction
- Nein-Button → Return-ToMainWindow  
- X-Button → Return-ToMainWindow (Cancel = true)
```

Power.Ctrl.app v1.00.04 bietet nun eine perfekt abgestimmte, fehlerfreie Benutzererfahrung mit nahtlosem Fenster-Switching, präziser Positionierung und intelligentem Console-Management für maximale Benutzerfreundlichkeit.