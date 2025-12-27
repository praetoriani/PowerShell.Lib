# ModernUI - BUGFIXES (v1.00.02)

This document lists bugfixes that are part of **ModernUI v1.00.02 Final Release**.
Previous versions are not documented here.

---

## Fixed Issues

### 1. Close button hover effect not displaying properly

**Problem:**
- The close button's hover effect (image swap) was implemented but the hover image would not display correctly.
- When hovering over the button, the normal image would disappear but the hover image would not appear.
- The button would remain blank even after moving the cursor away.

**Root Cause Analysis:**
- Initially, events were attached to the parent `Label` element instead of the child `Image` element, causing WPF event routing interference.
- Images were frozen with `.Freeze()` to improve performance, but this prevented dynamic updates to the `Source` property.
- Closure variables in PowerShell event handlers were not properly capturing the Image element reference.
- Cached `BitmapImage` objects were being reused, but new instances were needed for proper WPF rendering state transitions.

**Fix (Final):**
- Removed `.Freeze()` call from `Load-BitmapImage` function to allow dynamic image updates.
- Attached `MouseEnter` and `MouseLeave` events directly to the `Image` element (not the parent `Label`).
- Used `$sender` parameter directly in event handlers to reference the correct element.
- Implemented `Get-FreshBitmapImage` function to create fresh `BitmapImage` instances on each hover event.
- Stored image file paths globally (`$script:CloseButtonHoverImagePath` and `$script:CloseButtonNormalImagePath`) for dynamic reloading.
- Events now reload the hover/normal images dynamically instead of reusing cached instances.

**Result:**
- Close button hover effect is now fully functional and reliable.
- Hover image displays correctly when cursor enters the button area.
- Normal image displays correctly when cursor leaves the button area.
- No visual glitches or blank states occur during transitions.

---

### 2. Close button reliability and click behavior

**Problem:**
- The previous implementation used a `Button` with an image as content.
- Hover effects were difficult to implement and not reliable due to the internal button template and visual state handling.
- Click detection could be affected by bubbling behaviour and default button logic.

**Fix:**
- Replaced the close button with a `Label` hosting an `Image` as its content.
- Implemented hover and click behaviour purely event-driven:
  - `MouseEnter` switches to the hover PNG.
  - `MouseLeave` switches back to the normal PNG.
  - `PreviewMouseLeftButtonDown` closes the window and marks the event as handled.

**Result:**
- Hover effects are stable and immediate.
- Click behaviour is predictable and reliable.
- Visual template complexity is removed.

---

### 3. Centralized image loading and caching

**Problem:**
- Images were loaded in a scattered way and without caching.
- Missing images were only partially reported.

**Fix:**
- Introduced `Resolve-ImagePath` and `Load-BitmapImage` as central helpers.
- Added a simple in-memory cache (`$script:ImageCache`) to reuse already loaded images.
- Added `Get-FreshBitmapImage` function for creating new image instances on demand.
- Logging integration for all image load operations.

**Result:**
- More robust error handling when images are missing.
- Improved performance due to selective reuse of already loaded images.
- Better traceability through log entries.

---

### 4. Missing separation between UI and configuration

**Problem:**
- Some UI-relevant values (titles, version texts) were hard-coded in the script or XAML.

**Fix:**
- Moved the main window XAML to `WPF/ModernUI.xaml`.
- Used `config.app.name` and `config.app.version` as the single source of truth for titles and version labels at runtime.

**Result:**
- Clear separation between layout (XAML) and behaviour (PowerShell).
- Easier future changes to application naming and versioning.

---

### 5. Lack of structured diagnostic output

**Problem:**
- Diagnostic messages were written directly to the console using `Write-Host` and `Write-Error`.
- There was no central, file-based log, making it harder to analyse issues after the fact.

**Fix:**
- Added a `Write-LogEntry` function that writes structured log entries to a file if `debug.enabled` is set to `"true"` in `config.json`.
- Log format is fully driven by `config.json`:
  - File name via `debug.file`.
  - Timestamp format via `debug.datetime`.
  - Severity labels/icons via `debug.severityLevel`.
- Debug log entries can be selectively disabled by commenting out `Write-LogEntry` calls without removing the code.

**Result:**
- Central, file-based logging for easier debugging and support.
- Console output can be kept minimal while still having a full trace in the log file.
- Clean production logging by disabling debug entries.

---

### 6. Obsolete documentation file

**Problem:**
- `FIXES.md` overlapped with other documentation and was not aligned with the new ModernUI structure.

**Fix:**
- Removed `FIXES.md` and consolidated bugfix information in this `BUGFIXES.md` and `CHANGELOG.md`.

**Result:**
- Cleaner documentation structure.
- All bug-related changes reside in one consistent place.

---

## Testing Notes

**v1.00.02 Final Release** has been thoroughly tested:
- ✅ Close button displays correct normal image on startup
- ✅ Hovering over close button displays correct hover image
- ✅ Moving cursor away from close button restores normal image
- ✅ Multiple hover transitions work reliably
- ✅ Clicking close button closes the application cleanly
- ✅ All logging entries are properly recorded when enabled
- ✅ Application initializes correctly with all resources loaded

---

## Version

**ModernUI v1.00.02 Final Release** (Build: 251227)
