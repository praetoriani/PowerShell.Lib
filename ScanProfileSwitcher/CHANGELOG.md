# Changelog - ScanProfileSwitcher

## [1.1.1] - 2025-12-21

### Fixed
- CRITICAL: Fixed Exit Code 2 (0x00000002) bug
  - Resolved recursive loop in Closing event handler
  - Added Global:IsExiting flag to prevent unwanted Closing event re-triggers
  - Closing button now properly closes application without hanging
  - Process exits cleanly with exit code 0
- Closing behavior now consistent with Exit button behavior

### Improved
- Comprehensive PowerShell Execution Preferences documentation
  - Detailed explanation of ErrorActionPreference, InformationPreference, etc.
  - User control and development guidance added
  - Impact and use cases documented for each preference
- Better error logging with consistent timestamp formatting
  - Log entries now use [timestamp] format for clarity

### Changed
- Version: 1.1.0 => 1.1.1
- Updated all version references in config.json and ScanProfileSwitcher.ps1
- Enhanced code comments and documentation

### Technical Details
- Added Global:IsExiting boolean flag to manage window closing state
- Modified Add_Closing event handler to check IsExiting flag
- Explicit exit 0 after ShowDialog() for clean process termination
- Prevents multiple Closing event invocations and process hanging

---

## [1.1.0] - 2025-12-21

### Fixed
- CRITICAL: Fixed Closing-Button (Titelleiste) behavior
  - Scenario 1: No changes => Close without confirmation
  - Scenario 2: Changes made => Show popup-close.xaml
- CRITICAL: Fixed Exit-Button (Hauptfenster) behavior
  - Scenario 1: No changes => Close without confirmation
  - Scenario 2: Changes made => Show popup-warn.xaml

### Improved
- Korrekter Programmablauf fuer beide Closing-Szenarien
- Explizite Unterscheidung zwischen Titelleiste-Schliessen und Exit-Button
- Global:IsClosingFromButton Flag fuer korrekte Handling-Logik

### Changed
- Versionsnummer erhoet: 1.0.9 => 1.1.0
- Version in config.json aktualisiert
- Verbesserte Code-Dokumentation

---

## [1.0.6] - 2025-12-20

### Added
- UTF-8 with BOM encoding for ALL files (XAML, PowerShell, JSON, Markdown)
- UTF8-BOM-Patch.ps1 script for automatic encoding conversion
- Comprehensive encoding documentation
- XAML Layout Optimizations (final version)
  - Schriftgroessen optimiert fuer bessere Lesbarkeit
  - Spacing und Abstaende vereinheitlicht
  - Button-Positionierung praezise angepasst
  - Fenstergroessen fuer alle Dialoge perfektioniert

### Fixed
- Character display issues with German umlauts (ae, oe, ue, ss)
- Komisches Zeichen in Checkboxen
- Schriftgroessen und Abstands-Darstellungsfehler
- Button-Positionierung in Dialogen

### Changed
- Alle Dateien jetzt mit BOM-Marker (EF BB BF) versehen
- Verbessertes Encoding-Handling in PowerShell

---

## [1.0.5] - 2025-12-20

### Fixed
- CRITICAL: Fixed Setter.View error (should be Value) in main-app-win.xaml
- Fenster zu gross: 700x520 => 660x460
- Dialoge groesse optimiert: 540-570x280-310

### Changed
- Schriftgroessen angepasst (Titel 24pt => 22pt)
- Margins und Abstands-Werte optimiert

---

## [1.0.4] - 2025-12-20

### Added
- UTF-8 BOM Encoding in XAML-Dateien (erste Implementierung)
- Grosse UI-Redesign
- Groessere Schriftarten
- Groessere Icons

### Fixed
- Checkmark-Symbol wird jetzt korrekt angezeigt
- Button-Farben auf Grau eingestellt (#757575)
- Abstands-Probleme geloest

### Changed
- Window-Groessen erhoet
- Uniform Button-Design implementiert
- Verbesserte Spacing-Verhaeltnisse

---

## [1.0.3] - 2025-12-19

### Added
- Grundlegende UI-Verbesserungen
- Fenstergruppierungen

### Fixed
- Elementare Positionierungsfehler

---

## [1.0.2] - 2025-12-19

### Fixed
- DropShadow Effect aus XAML entfernt
- Basis-Kompatibilitaetsprobleme geloest

---

## [1.0.1] - 2025-12-18

### Fixed
- Ungueltige Hex-Farbwerte korrigiert
- Grund-Darstellungsfehler behoben

---

## [1.0.0] - 2025-12-18

### Added
- Initiale Veroeffentlichung
- Basis-Scanner-Profile (Standard + Duplex)
- Grundlegende GUI-Funktionalitaet
- Fehlerlogging
- Konfigurationsverwaltung

---

## Encoding History

- **v1.1.1**: Fixed exit code 2 bug with IsExiting flag mechanism
- **v1.1.0**: Fixed dialog flow for closing scenarios
- **v1.0.6**: UTF-8 with BOM fuer ALLE Dateien + XAML Layout Optimizations (Final Solution)
- **v1.0.4-v1.0.5**: UTF-8 BOM nur in XAML-Dateien (Partial Solution)
- **v1.0.0-v1.0.3**: UTF-8 ohne BOM (Problematisch - Darstellungsfehler)

---

**Status:** Production Ready
