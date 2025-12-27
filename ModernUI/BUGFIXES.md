# ModernUI - BUGFIXES (v1.00.02)

This document lists bugfixes that are part of **ModernUI v1.00.02**.
Previous versions are not documented here.

---

## Fixed Issues

### 1. Close button reliability and hover behavior

**Problem:**
- The previous implementation used a `Button` with an image as content.
- Hover effects were difficult to implement and not reliable due to the
  internal button template and visual state handling.
- Click detection could be affected by bubbling behaviour and default
  button logic.

**Fix:**
- Replaced the close button with a `Label` hosting an `Image` as its
  content.
- Implemented hover and click behaviour purely event-driven:
  - `MouseEnter` switches to the hover PNG.
  - `MouseLeave` switches back to the normal PNG.
  - `PreviewMouseLeftButtonDown` closes the window and marks the event
    as handled.

**Result:**
- Hover effects are stable and immediate.
- Click behaviour is predictable and reliable.
- Visual template complexity is removed.

---

### 2. Centralized image loading and caching

**Problem:**
- Images were loaded in a scattered way and without caching.
- Missing images were only partially reported.

**Fix:**
- Introduced `Resolve-ImagePath` and `Load-BitmapImage` as central
  helpers.
- Added a simple in-memory cache (`$script:ImageCache`) to reuse already
  loaded images.
- Logging integration for all image load operations.

**Result:**
- More robust error handling when images are missing.
- Slightly improved performance due to reuse of already loaded images.
- Better traceability through log entries.

---

### 3. Missing separation between UI and configuration

**Problem:**
- Some UI-relevant values (titles, version texts) were hard-coded in the
  script or XAML.

**Fix:**
- Moved the main window XAML to `WPF/ModernUI.xaml`.
- Used `config.app.name` and `config.app.version` as the single source of
  truth for titles and version labels at runtime.

**Result:**
- Clear separation between layout (XAML) and behaviour (PowerShell).
- Easier future changes to application naming and versioning.

---

### 4. Lack of structured diagnostic output

**Problem:**
- Diagnostic messages were written directly to the console using
  `Write-Host` and `Write-Error`.
- There was no central, file-based log, making it harder to analyse
  issues after the fact.

**Fix:**
- Added a `Write-LogEntry` function that writes structured log entries to
  a file if `debug.enabled` is set to `"true"` in `config.json`.
- Log format is fully driven by `config.json`:
  - File name via `debug.file`.
  - Timestamp format via `debug.datetime`.
  - Severity labels/icons via `debug.severityLevel`.

**Result:**
- Central, file-based logging for easier debugging and support.
- Console output can be kept minimal while still having a full trace in
  the log file.

---

### 5. Obsolete documentation file

**Problem:**
- `FIXES.md` overlapped with other documentation and was not aligned
  with the new ModernUI structure.

**Fix:**
- Removed `FIXES.md` and consolidated bugfix information in this
  `BUGFIXES.md` and `CHANGELOG.md`.

**Result:**
- Cleaner documentation structure.
- All bug-related changes reside in one consistent place.
