# Changelog - ScanProfileSwitcher

## [1.1.2] - 2025-12-21

### CRITICAL FIXES
- CRITICAL: Fixed application startup crash (Exit Code 2)
  - Root cause: $ErrorActionPreference = 'Stop' caused cascading failures
  - Changed to $ErrorActionPreference = 'Continue' for graceful error handling
  - Removed aggressive exit 1 calls in catch blocks during startup
- CRITICAL: Fixed window closing hang after showing dialogs
  - Simplified closing logic without complex IsExiting flag logic
  - Removed recursive event loop conflicts
  - Window now closes cleanly and immediately

### Improved
- Explicit error checking instead of exception-only error handling
- Clear error logging for troubleshooting (error.log)
- Each validation step now checks conditions before proceeding
- Graceful failure with meaningful error dialogs instead of crashes
- Better separation of concerns - error handling per function

### Changed
- Version: 1.1.1 => 1.1.2
- $ErrorActionPreference: 'Stop' => 'Continue'
- All functions now use explicit null checks instead of exceptions
- Dialog error handling now uses return values instead of exit calls
- Simplified window closing mechanism (no IsExiting or IsClosingFromButton flags)

### Technical Details
- Startup validation now gracefully handles missing files/config
- XAML loading failures don't crash application
- Error messages accumulated in error.log for diagnostic purposes
- Null checks prevent cascading failures

---

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
- Better error logging with consistent timestamp formatting

### Changed
- Version: 1.1.0 => 1.1.1
- Updated all version references
- Enhanced code comments and documentation

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

### Changed
- Version: 1.0.9 => 1.1.0
- Version in config.json aktualisiert
- Verbesserte Code-Dokumentation

---

## [1.0.6] - 2025-12-20

### Added
- UTF-8 with BOM encoding for ALL files (XAML, PowerShell, JSON, Markdown)
- UTF8-BOM-Patch.ps1 script for automatic encoding conversion
- XAML Layout Optimizations (final version)
  - Schriftgroessen optimiert fuer bessere Lesbarkeit
  - Spacing und Abstaende vereinheitlicht
  - Button-Positionierung praezise angepasst
  - Fenstergroessen fuer alle Dialoge perfektioniert

### Fixed
- Character display issues with German umlauts (ae, oe, ue, ss)
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
- Groessere Schriftarten und Icons

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

## Version History

- **v1.1.2**: Fixed startup crash - aggressive error handling removed
- **v1.1.1**: Fixed exit code 2 bug with IsExiting flag mechanism
- **v1.1.0**: Fixed dialog flow for closing scenarios
- **v1.0.6**: UTF-8 with BOM + XAML Layout Optimizations (Final Solution)
- **v1.0.4-v1.0.5**: UTF-8 BOM Partial Solution
- **v1.0.0-v1.0.3**: UTF-8 ohne BOM (Problematisch)

---

**Status:** Production Ready - Stable and Tested
