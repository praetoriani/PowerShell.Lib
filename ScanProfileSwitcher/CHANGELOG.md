# Changelog - ScanProfileSwitcher

## [1.0.6] - 2025-12-20

### Added
- ✅ UTF-8 with BOM encoding for ALL files (XAML, PowerShell, JSON, Markdown)
- ✅ UTF8-BOM-Patch.ps1 script for automatic encoding conversion
- ✅ Comprehensive encoding documentation

### Fixed
- ❌ Character display issues with German umlauts (ä, ö, ü, ß)
- ❌ Komisches Zeichen in Checkboxen
- ❌ Schriftgrößen und Abstands-Darstellungsfehler
- ❌ Button-Positionierung in Dialogen

### Changed
- Alle Dateien jetzt mit BOM-Marker (EF BB BF) versehen
- Verbessertes Encoding-Handling in PowerShell

---

## [1.0.5] - 2025-12-20

### Fixed
- ❌ CRITICAL: Fixed Setter.View error (should be Value) in main-app-win.xaml
- ❌ Fenster zu groß: 700x520 → 660x460
- ❌ Dialoge große optimiert: 540-570x280-310

### Changed
- Schriftgrößen angepasst (Titel 24pt → 22pt)
- Margins und Abstands-Werte optimiert

---

## [1.0.4] - 2025-12-20

### Added
- UTF-8 BOM Encoding in XAML-Dateien (erste Implementierung)
- Große UI-Redesign
- Größere Schriftarten
- Größere Icons

### Fixed
- Checkmark-Symbol (✓) wird jetzt korrekt angezeigt
- Button-Farben auf Grau eingestellt (#757575)
- Abstands-Probleme gelöst

### Changed
- Window-Größen erhöht
- Uniform Button-Design implementiert
- Verbesserte Spacing-Verhältnisse

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
- ❌ DropShadow Effect aus XAML entfernt
- Basis-Kompatibilitätsprobleme gelöst

---

## [1.0.1] - 2025-12-18

### Fixed
- ❌ Ungültige Hex-Farbwerte korrigiert
- Grund-Darstellungsfehler behoben

---

## [1.0.0] - 2025-12-18

### Added
- Initiale Veröffentlichung
- Basis-Scanner-Profile (Standard + Duplex)
- Grundlegende GUI-Funktionalität
- Fehlerlogging
- Konfigurationsverwaltung

---

## Encoding History

- **v1.0.6**: UTF-8 with BOM für ALLE Dateien (Final Solution)
- **v1.0.4-v1.0.5**: UTF-8 BOM nur in XAML-Dateien (Partial Solution)
- **v1.0.0-v1.0.3**: UTF-8 ohne BOM (Problematisch - Darstellungsfehler)

---

**Status:** Production Ready ✔️
