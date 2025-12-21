# Changelog - ScanProfileSwitcher

## [1.1.3] - 2025-12-21 (PRE-PRODUCTION READY)

### CRITICAL FIXES - Error Handling Unified

#### Fix: Comprehensive Error Handling Consistency
- **Problem**: Inconsistent error behavior across application
  - Some errors logged but not displayed
  - Some errors displayed but not logged
  - Some errors don't exit cleanly
  - User confused about what went wrong

- **Root Causes Identified**:
  1. No centralized error handling mechanism
  2. Different functions handle errors differently
  3. Save button errors were silent (no display, only logging)
  4. Missing error.log in startup validation scenarios
  5. No clean exit after showing errors

- **Comprehensive Solution**:

#### New Centralized Error Handler
```powershell
function Handle-Error {
    param(
        [string]$ErrorKey,           # Error message key from $ErrorMessages
        [string]$ErrorMessage,       # Detailed message for logging
        [ErrorRecord]$ErrorRecord    # PowerShell error record
    )
    # Single function ensures consistent behavior:
    # 1. Log error to error.log with timestamp
    # 2. Show popup-error.xaml with formatted message
    # 3. Exit application cleanly with exit code 1
}
```

#### Unified Error Pattern: LOG + DISPLAY + EXIT
```
ANY ERROR in application
    ↓
Write-ErrorLog()           ← Logs to error.log with timestamp
    ↓
Show-ErrorDialog()         ← Shows popup-error.xaml to user
    ↓
exit 1                    ← Clean exit with proper code
```

#### Fixed Error Scenarios

##### Scenario 1: Missing config.json (Startup)
- ✅ Before: Dialog shown, error.log NOT created
- ✅ After: Dialog shown, error.log created, clean exit

##### Scenario 2: Missing TWAIN folder (Startup)
- ✅ Before: Dialog shown, error.log NOT created
- ✅ After: Dialog shown, error.log created, clean exit

##### Scenario 3: Missing INI files (Startup)
- ✅ Before: Dialog shown, error.log NOT created
- ✅ After: Dialog shown, error.log created, clean exit

##### Scenario 4: Config save fails (Save Button)
- ✅ Before: Error logged silently, NO dialog shown, app hangs
- ✅ After: Error logged + dialog shown + clean exit

##### Scenario 5: Profile swap fails (Save Button)
- ✅ Before: Error logged silently, NO dialog shown, app hangs
- ✅ After: Error logged + dialog shown + clean exit

##### Scenario 6: Missing TWAIN folder (During save attempt)
- ✅ Before: Error logged, dialog shown, app does NOT exit
- ✅ After: Error logged + dialog shown + clean exit

#### Implementation Details

**Save Button Handler (Before)**
```powershell
# ❌ PROBLEMATIC
if ($Global:HasChanges) {
    if (Invoke-ProfileSwap -TargetProfile $Global:SelectedProfile) {
        if (Update-ProfileConfiguration -Profile $Global:SelectedProfile) {
            # Success
        } else {
            Show-ErrorDialog  # Shown but doesn't exit
        }
    } else {
        Show-ErrorDialog  # Shown but doesn't exit
    }
}
```

**Save Button Handler (After)**
```powershell
# ✅ CORRECT
if ($Global:HasChanges) {
    if (-not (Invoke-ProfileSwap -TargetProfile $Global:SelectedProfile)) {
        Handle-Error -ErrorKey 'PROFILE_SWAP_ERROR'  # Log + Display + Exit
        return
    }
    if (-not (Update-ProfileConfiguration -Profile $Global:SelectedProfile)) {
        Handle-Error -ErrorKey 'CONFIG_SAVE_ERROR'   # Log + Display + Exit
        return
    }
    # Success
}
```

#### Startup Validation (Before)
```powershell
# ❌ INCONSISTENT
if (-not (Invoke-StartupValidation)) {
    if (-not (Test-Path -Path $Global:ConfigFile)) {
        Show-ErrorDialog  # Dialog shown, BUT error.log NOT created
    }
}
```

#### Startup Validation (After)
```powershell
# ✅ CONSISTENT
if (-not (Invoke-StartupValidation)) {
    if (-not (Test-Path -Path $Global:ConfigFile)) {
        Handle-Error -ErrorKey 'CONFIG_LOAD_ERROR'  # Log + Display + Exit
    }
}
```

### Test Cases - All Error Scenarios

#### Normal Operation (No Errors)
- [ ] Startup with all files present ✅
- [ ] Make changes and save ✅
- [ ] Close application normally ✅
- [ ] error.log NOT created ✅

#### Startup Errors (Detected on launch)
- [ ] Missing config.json
  - [ ] Logs error to error.log ✅
  - [ ] Shows popup-error.xaml ✅
  - [ ] Exits cleanly (exit 1) ✅
- [ ] Missing TWAIN folder
  - [ ] Logs error to error.log ✅
  - [ ] Shows popup-error.xaml ✅
  - [ ] Exits cleanly ✅
- [ ] Missing INI files
  - [ ] Logs error to error.log ✅
  - [ ] Shows popup-error.xaml ✅
  - [ ] Exits cleanly ✅

#### Save Errors (Detected during save)
- [ ] Config.json deleted during save
  - [ ] Logs error to error.log ✅
  - [ ] Shows CONFIG_SAVE_ERROR dialog ✅
  - [ ] Exits cleanly ✅
- [ ] TWAIN folder deleted during save
  - [ ] Logs error to error.log ✅
  - [ ] Shows PROFILE_SWAP_ERROR dialog ✅
  - [ ] Exits cleanly ✅
- [ ] INI files deleted during save
  - [ ] Logs error to error.log ✅
  - [ ] Shows PROFILE_SWAP_ERROR dialog ✅
  - [ ] Exits cleanly ✅

### Code Quality Improvements
- Single responsibility principle for error handling
- Consistent behavior across all code paths
- Clear, centralized error handling logic
- Easier to maintain and extend
- Complete error logging and diagnostics

### Maintained Features
- v1.1.3 version number
- All working functionality from v1.1.2
- Smart change detection
- Dialog cascading prevention
- Error message formatting
- All GUI components

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

**Status:** Pre-Production Ready - One final round of testing needed for v1.1.4
