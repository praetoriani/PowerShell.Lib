# Changelog - ScanProfileSwitcher

## [1.1.2] - 2025-12-21 (FINAL UPDATE)

### CRITICAL FIXES
- CRITICAL: Fixed startup crash (Exit Code 2)
  - Changed $ErrorActionPreference from 'Stop' to 'Continue'
  - Explicit error checking instead of exception-based handling
  - Graceful error accumulation in error.log

- CRITICAL: Fixed dialog cascade bug (NEW FIX)
  - Exit Button (Beenden-Button) was triggering BOTH popup-warn.xaml AND popup-close.xaml in sequence
  - This caused hanging when user selected "Ja" on second dialog
  - Fixed: Exit button now ONLY shows popup-warn.xaml, NEVER popup-close.xaml
  - Fixed: Title bar close (X) now ONLY shows popup-close.xaml, NEVER popup-warn.xaml

- CRITICAL: Restored proper event handler separation
  - Re-introduced IsExiting flag to prevent event recursion
  - Re-introduced IsClosingFromButton flag to distinguish close sources
  - These flags are NECESSARY for proper dialog flow and prevent cascades

### Bug Scenarios (All Fixed)

#### Scenario 1: No Changes
- Exit Button → Closes immediately ✅
- Title Bar (X) → Closes immediately ✅

#### Scenario 2: Changes Made
- Exit Button → Shows popup-warn.xaml ONLY ✅
  - User says "Ja" → Program exits cleanly ✅
  - User says "Nein" → Window stays open ✅
  - NO popup-close.xaml cascade ✅

- Title Bar (X) → Shows popup-close.xaml ONLY ✅
  - User says "Ja" → Program exits cleanly ✅
  - User says "Nein" → Window stays open ✅
  - NO popup-warn.xaml cascade ✅

### Improved
- Explicit error checking throughout startup sequence
- Clear error logging for troubleshooting
- Proper separation of Exit Button vs Title Bar handlers
- Independent dialog flows - no cascades or interference

### Changed
- Restored IsExiting flag for proper event management
- Restored IsClosingFromButton flag to distinguish close sources
- Simplified but correct event handler logic
- Version remains 1.1.2

### Technical Details
- Exit Button checks IsClosingFromButton to avoid triggering Closing event handler
- Closing event checks IsExiting to allow final close without re-triggering
- Each dialog path is independent and never cascades to another

---

## [1.1.1] - 2025-12-21

### Fixed
- Exit Code 2 bug with IsExiting flag mechanism
- Closing behavior consistent between buttons

### Changed
- Version: 1.1.0 => 1.1.1

---

## [1.1.0] - 2025-12-21

### Fixed
- Closing-Button (Titelleiste) behavior for both scenarios
- Exit-Button (Hauptfenster) behavior for both scenarios

### Changed
- Version: 1.0.9 => 1.1.0

---

## [1.0.6] - 2025-12-20

### Added
- UTF-8 with BOM encoding for ALL files
- XAML Layout Optimizations (final version)

### Fixed
- Character display issues with German umlauts

---

## [1.0.0] - 2025-12-18

### Added
- Initial release with basic scanner profile switching

---

**Status:** Production Ready - Dialog cascades fixed, All scenarios working
