# Changelog - ScanProfileSwitcher

## [1.1.3] - 2025-12-21 (FINAL - PRODUCTION READY)

### CRITICAL FIXES - Final Polish Round

#### Fix 1: Handle-Error() Exit Behavior
- **Problem**: Application hung after user confirmed error dialog in Save Button context
  - error.log was created ✓
  - Dialog was shown ✓
  - BUT: Programm did NOT exit ✗
  - User had to force-close the application

- **Root Cause**: 
  - `Handle-Error()` called `Show-ErrorDialog()` which internally calls `exit 1`
  - BUT: When called from Save Button handler inside MainWindow context
  - The `exit 1` inside `Show-ErrorDialog()` was blocked by WPF event loop
  - Application never actually exited

- **Solution**:
  - `Show-ErrorDialog()` properly calls `exit 1` AFTER `ShowDialog()` returns
  - Added explicit `OwnerWindow` parameter to `Handle-Error()`
  - Error dialog now properly positioned on main window
  - Exit 1 is called cleanly AFTER dialog closes

- **Result**:
  - All error scenarios now exit cleanly ✓
  - No more hanging applications ✓
  - Proper error dialog display ✓

#### Fix 2: Error Messages Accuracy
- **Problem**: Wrong error message for save operations
  - When config.json save failed, showed CONFIG_LOAD_ERROR context
  - When profile swap failed, logged wrong context
  - Confused user and made debugging harder

- **Root Cause**:
  - `Update-ProfileConfiguration()` called `Get-ConfigurationFile()` to LOAD config
  - Then tried to SAVE the config
  - If `Get-ConfigurationFile()` failed, logged "load" message but tried to SAVE
  - Mismatch between operation and error message

- **Solution**:
  - Split error logging in `Update-ProfileConfiguration()`: 
    - If Get fails: "Fehler: Konfigurationsdatei konnte nicht für Speichern gelesen werden"
    - If Set fails: "Fehler: Konfigurationsdatei konnte nicht geschrieben werden"
  - Added explicit context in Save Button handler:
    - `Handle-Error ... -ErrorMessage "Fehler beim Speichern: ..."` 
  - Clear distinction between load and save errors

- **Result**:
  - Accurate error messages in error.log ✓
  - Clear context for troubleshooting ✓
  - Proper error semantics ✓

#### Fix 3: Error Dialog Positioning
- **Problem**: popup-error.xaml appeared in different positions
  - No consistent window positioning
  - Made user experience unpredictable

- **Solution**:
  - Set `Topmost = true` on error dialog
  - Set `Owner = MainWindow` when called from main context
  - Consistent positioning through proper WPF hierarchy

- **Result**:
  - Error dialogs always visible ✓
  - Consistent positioning ✓
  - Professional appearance ✓

### Test Results - All Scenarios Passing

#### Normal Operation (No Errors)
- [x] Startup with all files present ✓
- [x] Make changes and save ✓
- [x] Close application normally ✓
- [x] error.log NOT created ✓

#### Startup Errors
- [x] Missing config.json
  - [x] error.log created ✓
  - [x] Dialog shown ✓
  - [x] Clean exit ✓
- [x] Missing TWAIN folder
  - [x] error.log created ✓
  - [x] Dialog shown ✓
  - [x] Clean exit ✓
- [x] Missing INI files
  - [x] error.log created ✓
  - [x] Dialog shown ✓
  - [x] Clean exit ✓

#### Save Errors - Config.json Deleted
- [x] error.log created ✓
- [x] CONFIG_SAVE_ERROR dialog shown ✓
- [x] Proper error message: "Fehler beim Speichern: Konfiguration konnte nicht geschrieben werden" ✓
- [x] Programm exits cleanly ✓ (FIXED - was hanging before)

#### Save Errors - TWAIN Folder Deleted
- [x] error.log created ✓
- [x] PROFILE_SWAP_ERROR dialog shown ✓
- [x] Proper error message: "Fehler beim Speichern: Scanner-Profil konnte nicht getauscht werden" ✓
- [x] Programm exits cleanly ✓ (FIXED - was hanging before)

### Code Quality
- Centralized error handling with `Handle-Error()` function
- Clear semantic distinction between load and save errors
- Proper error context in all logging messages
- Consistent exit behavior across all error paths
- Professional error dialog positioning and display

### Version Status
- **v1.1.3**: PRODUCTION READY - Ready for deployment
- **v1.1.4**: Planned - User's custom enhancement

---

## [1.1.2] - 2025-12-21

### Fixed
- Smart change detection for reverting to original profile
- Error dialog hanging and newline display issues

---

## [1.1.1] - 2025-12-21

### Fixed
- Exit Code 2 bug and dialog cascade prevention

---

## [1.1.0] - 2025-12-21

### Fixed
- Closing button scenarios

---

## [1.0.0] - 2025-12-18

### Added
- Initial release

---

**Status:** ✅ PRODUCTION READY - All critical bugs fixed, comprehensive testing complete, ready for v1.1.4
