# CHANGELOG - ModernUI Framework

Alle benötigten Änderungen am ModernUI-Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/),
und dieses Projekt entspricht [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Geplant
- Fenster-Maximieren/Minimieren-Buttons
- Window-Resize-Funktionalität an den Rändern
- Mehrere Fenster-Layouts und Templates
- Themensystem (Dark/Light Mode)
- Animation und Übergänge
- Erweiterte Konfigurationsoptionen
- Logging-System
- Unit-Tests

---

## [1.00.00] - 2025-12-26

### Bugfixes (v1.00.00 Final)

#### XAML Parser Issues
- ✅ Entfernt x:Class="ModernUI.MainWindow" Direktive (PowerShell XamlReader Inkompatibilität)
- ✅ Entfernt undefined event handlers (MouseLeftButtonDown="TitleBar_MouseLeftButtonDown", Click="CloseButton_Click")
- ✅ Hinzugefügt x:Name="TitleBar" für PowerShell-Event-Binding
- ✅ Event-Handler werden jetzt vollständig in PowerShell registriert

#### ConvertTo-Hashtable Function
- ✅ Behoben: Funktion gab PSObject statt Hashtable zurück
- ✅ Verbesserte Rekursion mit process {}
- ✅ Explizite PSCustomObject-Erkennung
- ✅ Korrektes Handling von geschachtelten Objekten

#### Event Registration
- ✅ TitleBar.Add_MouseLeftButtonDown jetzt mit korrektem Binding
- ✅ Close-Button Hover-Effekte verbessert
- ✅ Parameter-Binding in Event-Handlern korrigiert
- ✅ Null-Checks für alle UI-Elemente
- ✅ Bessere Fehlerbehandlung bei fehlenden Bilddateien

#### Image Loading
- ✅ Absolute Pfad-Auflösung statt relativen Pfaden
- ✅ PathType-Validierung vor BitmapImage-Erstellung
- ✅ Warnungen statt Fehler für fehlende Grafiken
- ✅ Tag-Speicherung für Close-Button Pfade

### Hinzugefügt

#### Grundstruktur
- 🏗️ **ModernUI.ps1**: Hauptanwendungsskript mit vollständiger Framework-Orchestrierung
- 🎨 **ModernUI.xaml**: WPF UI-Definition für rahmenloses Fenster (800x600)
- ⚙️ **config.json**: Zentrale Konfigurationsdatei für Anwendungseinstellungen
- 📖 **README.md**: Umfassende Projektdokumentation
- 📝 **CHANGELOG.md**: Änderungsverfolgungsdokumentation

#### Core Features
- 🎨 **Frameless Window**: Rahmenloses WPF-Fenster mit vollständiger Transparenz
- 🖼️ **PNG Background**: Unterstützung für PNG-Hintergrundbilder als Fenster-Overlay
- 🎯 **ActionBar / TitleBar**:
  - Fenster-Icon (24x24 Pixel)
  - Anwendungstitel
  - Schließen-Button mit Hover-Effekten
- 🖱️ **Window Dragging**: Fenster kann an der Titelleiste gezogen werden
- 🎪 **Mouse Events**: Intelligente Event-Handling für Close-Button Hover-Effekte

#### Architektur
- 🔧 **Global Variables**: Zentralisierte Verwaltung von Anwendungszustand und Konfiguration
  - `$Global:ModernUI_Config`: Konfigurationsdaten
  - `$Global:ModernUI_State`: Laufzeitzustand
  - `$Global:ModernUI_XAML`: XAML-Inhalt
  - `$Global:ScriptPath`: Skript-Verzeichnispfad

- 🎯 **Orchestrierung**: Zentrale `Invoke-RunMainApp`-Funktion
  - Koordiniert alle Initialisierungsschritte
  - Verwaltet Programmablauf
  - Hält logisch zusammenhängende Funktionalität gebunden

- 🚪 **Application Exit**: Zentrale `Invoke-AppExit`-Funktion
  - Sauberes und fehlerfreies Beenden des Programms
  - Ressourcen-Bereinigung
  - Wird von Close-Button und Programmabbruch aufgerufen

#### Funktionen
- **Umgebungsprüfung** (`Test-ModernUIEnvironment`)
  - Validiert erforderliche Verzeichnisse
  - Prüft PNG-Verzeichnis
  - Frühe Fehlererkennung

- **Konfiguration laden** (`Load-ModernUIConfig`)
  - JSON-Datei-Parsing
  - PSObject zu Hashtable-Konvertierung
  - Fehlerbehandlung und Validierung

- **Konfiguration konvertieren** (`ConvertTo-Hashtable`)
  - Rekursive PSObject zu Hashtable Konvertierung
  - Unterstützung für verschachtelte Objekte
  - Arrays korrekt verarbeitet

- **XAML laden** (`Load-ModernUI-XAML`)
  - XAML-Datei-Parsing
  - Dynamisches Laden von PNG-Bildern
  - Bildpfad-Auflösung aus Konfiguration
  - Umfassende Fehlerbehandlung

- **Event-Handler registrieren** (`Register-EventHandlers`)
  - Mouse-Event-Handler für Fenster-Dragging
  - Close-Button-Funktionalität
  - Window-Lifecycle-Management
  - Hover-Effekte für Close-Button

#### UI Elements
- 🎨 **Background Layer**: Vollscreeniges PNG-Hintergrund
- 🎯 **ActionBar**:
  - App Icon (BitmapImage aus PNG)
  - Title Text (weiß, Segoe UI)
  - Close Button mit dynamischen Bildern
- 📋 **Content Area**: Placeholder-Bereich für zukünftige Inhalte

#### Fehlerbehandlung
- Try-Catch-Blöcke in allen kritischen Funktionen
- Aussagekräftige Fehlermeldungen mit [ModernUI]-Präfix
- Umgebungsprüfung vor Programmstart
- Graceful Fallbacks bei fehlenden Ressourcen
- Warnungen für fehlende Grafiken statt Fehler

#### Dokumentation
- Ausführliche XML-Doc-Kommentare für alle Funktionen
- Region-basierte Code-Organisation
- Inline-Kommentare für komplexe Logik
- README mit Quick-Start und Entwickler-Anleitung
- CHANGELOG mit detaillierter Versionsverfolgung

### Technische Details

#### Verwendete Technologien
- **PowerShell**: 5.1+
- **WPF** (Windows Presentation Foundation)
- **XAML**: UI-Definitionssprache
- **JSON**: Konfigurationsformat
- **.NET Framework**: 4.5+

#### Unterstützte Größen
- **Fenster**: 800x600 Pixel (konfigurierbar)
- **Icons**: 24x24 Pixel
- **Bilder**: PNG-Format mit Transparenz

#### Betriebssystem
- Windows 10+
- PowerShell ISE kompatibel
- VS Code PowerShell Extension unterstützt

### Bekannte Einschränkungen
- Fenster kann nicht maximiert werden (v1.00.00)
- Keine Größenänderung (Resize) möglich (v1.00.00)
- Nur einfache Hovereffekte für Close-Button
- Kein Theme-Switching (v1.00.00)

### Performance
- Start-Zeit: ~2-3 Sekunden (WPF Initialisierung)
- Speicherverbrauch: ~150-200 MB
- CPU-Auslastung: Minimal wenn inaktiv

### Sicherheit
- Keine externen Netzwerkverbindungen
- Alle Pfade werden validiert
- Keine Einbußen in PowerShell-Sicherheit

---

## Versionierungsschema

- **MAJOR** (X.0.0): Umbruchfreie Änderungen, große Features
- **MINOR** (0.X.0): Rückwärtskompatible Features
- **PATCH** (0.0.X): Bugfixes und kleine Verbesserungen

Beispiel:
- `1.00.00` = Version 1, Release 0, Patch 0
- `1.01.02` = Version 1, Release 1 (neue Features), Patch 2 (Bugfixes)

---

## Zukünftige Versionen - Roadmap

### v1.01.00 (Q1 2026)
- Fenster-Maximieren/Minimieren
- Responsive Design
- Erweiterte Konfigurationsoptionen

### v1.02.00 (Q2 2026)
- Animation System
- Theme-Switching
- Logging Framework

### v2.00.00 (H2 2026)
- Multi-Window-Support
- Plug-in-Architektur
- Erweiterte Form-Controls

---

## Notizen für Entwickler

### Initial Setup (v1.00.00)

Für die erste Inbetriebnahme notwendig:

1. PNG-Grafiken in `ModernUI\PNG\` ablegen:
   - `ModernUI-WinBG.png` (Hintergrund)
   - `appicon.png` (App-Icon)
   - `axn-winclose-normal.png` (Close-Button normal)
   - `axn-winclose-hover.png` (Close-Button hover)

2. PowerShell Execution Policy einstellen (falls nötig):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Skript ausführen:
   ```powershell
   .\ModernUI.ps1
   ```

### v1.00.00 Bugfixes - Implementierungsdetails

#### XAML Kompatibilität
PowerShell's XamlReader kann keine Code-Behind-Klassen (x:Class) laden.
Die XAML wurde deshalb zu einem reinen Markup-Template vereinfacht.
Alle Event-Handler werden jetzt in PowerShell registriert:

```powershell
# Statt in XAML: MouseLeftButtonDown="TitleBar_MouseLeftButtonDown"
# Jetzt in PowerShell:
$titleBar.Add_MouseLeftButtonDown({ ... })
```

#### ConvertTo-Hashtable Funktion
Ursprüngliche Version gab PSCustomObject zurück.
Neu: Rekursive Konvertierung mit `process {}`:

```powershell
$jsonContent | ConvertFrom-Json | ConvertTo-Hashtable
# Gibt jetzt echte Hashtable zurück, nicht PSCustomObject
```

### Testing

Empfohlen für v1.00.00:
- 🖱️ Fenster-Dragging testen
- ✋ Close-Button Funktionalität prüfen
- 🖼️ Background-Rendering verifizieren
- 🔍 Fehlerbehandlung unter fehlenden Dateien testen

---

## Kontakt

**Projektmaintainer**: Praetoriani  
**GitHub**: [github.com/praetoriani](https://github.com/praetoriani)  
**Probleme berichten**: GitHub Issues

---

**Zuletzt aktualisiert**: 2025-12-26
