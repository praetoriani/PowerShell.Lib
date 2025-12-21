# Changelog - ScanProfileSwitcher

## [1.1.3] - 2025-12-21 (✅ FINAL - PRODUCTION READY)

### CRITICAL FIXES - Guaranteed Clean Exit in ALL Scenarios

#### Problem Analysis
- **Report Date**: 2025-12-21 16:38-17:10 CET
- **Production Impact**: CRITICAL
- **Deployment Context**: `conhost.exe --headless powershell.exe ...` (NO Console)
- **Risk**: Application hangs in background, user must use Task Manager

#### Issues Identified
1. **Startup Error Dialog Positioning**: Random placement on screen
2. **Save Error Dialog Exit Failure**: Dialog shown but application hung
3. **Event Loop Blocking**: `exit 1` not working from event handler context

#### Root Cause Analysis
- **Startup Phase**: Dialog shown but no centered positioning
- **Runtime Phase (Save Button)**:
  - `exit 1` blocked by WPF event loop
  - Dialog closes but application continues running
  - No process termination mechanism
  - Accumulated WPF resources not cleaned up

### Solution: Two-Dialog Strategy

#### 1. Startup Error Dialog (`Show-ErrorDialog-Startup`)
```powershell
# For: Missing config.json, TWAIN folder, INI files (startup validation)
# Strategy:
#   - Centered on screen (WindowStartupLocation = CenterScreen)
#   - No owner window (prevents blocking)
#   - Topmost = true (always visible)
#   - Simple exit 1 (no event loop blocking at startup)
#
# Flow:
#   Show Dialog
#   Wait for user OK
#   exit 1 (clean shutdown)
```

#### 2. Runtime Error Dialog (`Show-ErrorDialog-Runtime`)
```powershell
# For: Profile swap error, config save error (from Save Button)
# Strategy:
#   - Positioned relative to MainWindow (owner window)
#   - Uses Application.Current.Shutdown(1) instead of exit 1
#   - Proper WPF cleanup before process termination
#   - Works even from event handler context
#
# Flow:
#   Show Dialog (with owner)
#   Wait for user OK
#   Application.Current.Shutdown(1) (guaranteed WPF cleanup + exit)
```

### Key Technical Details

#### Why Two Different Approaches?

**Startup Phase (Simple)**:
- No WPF MainWindow yet
- Dialog is first GUI
- Simple `exit 1` works fine
- No event loop blocking risk

**Runtime Phase (Complex)**:
- WPF MainWindow already running
- ShowDialog() called from event handler
- WPF event loop is active
- Plain `exit 1` gets blocked
- **Solution**: `Application.Current.Shutdown(1)` properly signals WPF to close

#### Application.Current.Shutdown(1) vs exit 1

| Aspect | exit 1 | Application.Shutdown(1) |
|--------|--------|------------------------|
| **From Startup** | ✅ Works | ✅ Works |
| **From Event Handler** | ❌ Blocked | ✅ Works |
| **WPF Cleanup** | ⚠️ Partial | ✅ Complete |
| **Resource Release** | ⚠️ Incomplete | ✅ Proper |
| **Process Exit** | ✅ Yes | ✅ Yes |
| **Headless Context** | ⚠️ Risky | ✅ Safe |

### Test Cases - All Passing ✅

#### Normal Operation
- [x] Startup with all files present
- [x] Make changes and save successfully
- [x] Close application normally
- [x] No error.log created

#### Startup Errors (Centered Dialog)
- [x] Missing config.json
  - [x] Dialog centered on screen ✅ (NEW FIX)
  - [x] error.log created
  - [x] Topmost = true (always visible)
  - [x] Clean exit
- [x] Missing TWAIN folder
  - [x] Dialog centered on screen ✅ (NEW FIX)
  - [x] error.log created
  - [x] Clean exit
- [x] Missing INI files
  - [x] Dialog centered on screen ✅ (NEW FIX)
  - [x] error.log created
  - [x] Clean exit

#### Save Errors (Guaranteed Exit)
- [x] Config.json deleted during runtime
  - [x] error.log created
  - [x] CONFIG_SAVE_ERROR dialog shown
  - [x] Dialog shows with owner window (relative positioning)
  - [x] **Programm exits cleanly ✅ (FIXED - was hanging before)**
- [x] TWAIN folder deleted during runtime
  - [x] error.log created
  - [x] PROFILE_SWAP_ERROR dialog shown
  - [x] **Programm exits cleanly ✅ (FIXED - was hanging before)**

### Production Readiness Checklist

#### Execution Context: conhost.exe --headless
```powershell
C:\Windows\System32\conhost.exe --headless powershell.exe `
  -WindowStyle Hidden `
  -ExecutionPolicy Bypass `
  -NoProfile `
  -NonInteractive `
  -File "C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1"
```

- [x] No console window visible
- [x] Only GUI visible
- [x] All error dialogs centered on screen
- [x] ALL error paths guarantee process termination
- [x] **No hanging applications**
- [x] **No Task Manager needed**
- [x] **User can't get stuck**
- [x] **Proper cleanup of WPF resources**

#### Code Quality
- [x] Separated concerns (startup vs runtime dialogs)
- [x] Clear responsibility assignment
- [x] Comprehensive error logging
- [x] Proper resource management
- [x] No memory leaks
- [x] Professional error handling

### Migration from v1.1.2
- ✅ All existing functionality preserved
- ✅ Only error handling improved
- ✅ Backward compatible
- ✅ No breaking changes

### Version Status
**✅ v1.1.3 - PRODUCTION READY**
- Comprehensive testing completed
- All edge cases handled
- Guaranteed clean exit in ALL scenarios
- Ready for deployment
- Ready for v1.1.4 enhancements

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

**🎉 ScanProfileSwitcher v1.1.3 is now ready for production deployment!**
