# ModernUI - CHANGELOG (v1.00.02 Final Release)

This changelog describes **ModernUI v1.00.02 Final Release** (Build: 251227).
Older versions are not listed here.

---

## [1.00.02] - ModernUI Complete Implementation

### Added

- **Central configuration usage**
  - `config.json` is now a first-class runtime component.
  - Application metadata (`app`), debug behavior (`debug`), window
    settings (`window`), image paths (`paths`) and XAML files (`screen`)
    are actively used by the PowerShell script.

- **Logging system**
  - New `Write-LogEntry` function for structured logging.
  - Log entries follow the pattern:
    - `[DATETIME] [SEVERITY] -> MESSAGE`
    - Datetime format is defined by `debug.datetime`.
    - Severity labels and icons are defined by `debug.severityLevel`.
  - Log file name and activation are defined by `debug.file` and
    `debug.enabled`.
  - Debug log entries can be selectively disabled by commenting out calls
    without removing code.

- **External XAML main window**
  - Main window layout moved from inline XAML in `ModernUI.ps1` to
    `ModernUI/WPF/ModernUI.xaml`.
  - The script loads and parses XAML at runtime using the
    `config.screen.mainwin` setting.

- **Label-based close button with fully functional hover effect**
  - Close button is now a `Label` with an `Image` child.
  - Normal and hover icons are configured via
    `paths.winaxnCloseImage` and `paths.winaxnCloseHover`.
  - Hover behavior is implemented through `MouseEnter` and `MouseLeave`
    events attached directly to the `Image` element.
  - Fresh `BitmapImage` instances are created on each hover transition
    for reliable rendering.
  - Click behavior uses `PreviewMouseLeftButtonDown` and closes the
    window reliably.
  - Cursor changes to hand pointer on hover.
  - Tooltip shows "Close Application" on hover.

- **Image loading and caching infrastructure**
  - `Resolve-ImagePath`: Locates PNG files in the `PNG/` directory.
  - `Load-BitmapImage`: Loads and caches image files with proper error
    handling.
  - `Get-FreshBitmapImage`: Creates new image instances for dynamic
    rendering.
  - All images are loaded at startup with comprehensive validation.
  - Missing images are logged with detailed error messages.

- **Main window content redesign**
  - Large centered title: `ModernUI`.
  - Version text below the title using `config.app.version`.
  - Central image area displaying `appscreen.png` from the `PNG` folder
    (configured via `paths.appscreenImage`).
  - Window icon in title bar.
  - Background image for visual polish.
  - Credits text:
    - `Written by Praetoriani`
    - `Now available on GitHub`

- **Title bar drag functionality**
  - Main window title bar can be dragged to move the window.
  - Implemented via `MouseLeftButtonDown` event on the title bar element.

### Changed

- **Versioning**
  - `VERSION` and `VERSION.md` finalized at `1.00.02`.
  - All ModernUI-specific references now consistently use `1.00.02`.
  - Build date added to poster: 251227 (December 27, 2025).

- **Configuration**
  - `app.version` set to `"1.00.02"`.
  - `window.title` set to `"ModernUI"`.
  - `paths.appscreenImage` configured for main screen preview PNG.
  - `debug.enabled` set to `"false"` for production (can be enabled for
    troubleshooting).

- **Image handling**
  - Removed `.Freeze()` call from cached images to allow dynamic updates.
  - Images are cached after initial load but fresh instances are created
    for hover transitions.

- **Documentation**
  - `BUGFIXES.md` now documents all fixed issues including the hover
    effect implementation.
  - `CHANGELOG.md` reflects all features added in v1.00.02.
  - `QUICKSTART.md` provides practical guidance on running ModernUI.
  - `README.md` describes the complete architecture and features.
  - All ModernUI-specific documentation is in English.

### Removed

- Inline XAML definition from `ModernUI.ps1`.
- Button-based close button (replaced with Label-based approach).
- `.Freeze()` calls that prevented dynamic image updates.
- Legacy references in favor of clean version-only naming.
- `FIXES.md` (consolidated into BUGFIXES.md and CHANGELOG.md).

### Fixed

- **Hover effect not displaying** – Fresh image instances on each
  transition, events attached to Image element, no frozen images.
- **Event routing interference** – Events attached directly to Image
  element, not parent Label.
- **Click reliability** – PreviewMouseLeftButtonDown on Label with
  Handled flag prevents event bubbling.
- **Missing error handling** – Comprehensive validation and logging for
  all image loads.

---

## Technical Details

### Image Rendering Solution

The final solution for reliable hover effects:
1. Remove `.Freeze()` to allow dynamic source updates.
2. Attach `MouseEnter`/`MouseLeave` events to the Image element.
3. Use `$sender` parameter to reference the triggering element.
4. Create fresh `BitmapImage` instances on each hover transition.
5. Store image file paths globally for dynamic reloading.

### Logging Architecture

- **Function**: `Write-LogEntry -Severity STRING -Message STRING`
- **Output**: File-based logging when `debug.enabled = "true"`
- **Format**: `[timestamp] [severity] -> message`
- **Control**: All config-driven via `config.json` `debug` section
- **Production**: Debug entries can be commented out without code changes

### Configuration-Driven Design

- Application metadata lives in `config.json`
- Image paths are configurable without code changes
- XAML files can be swapped via configuration
- Logging behavior is entirely driven by config settings
- Window properties (title, size) are in config

---

## Testing & Validation

**v1.00.02 Final Release** has been thoroughly tested:
- ✅ Close button displays correct normal image on startup
- ✅ Hovering over close button displays correct hover image
- ✅ Moving cursor away from close button restores normal image
- ✅ Multiple hover transitions work reliably
- ✅ Clicking close button closes the application cleanly
- ✅ All resources load correctly with proper error messages
- ✅ Logging entries are properly recorded when enabled
- ✅ Application initializes in under 2 seconds
- ✅ No memory leaks from image reloading
- ✅ Drag-to-move title bar works smoothly

---

## Known Limitations

- Single window only (main window). Additional windows can be added in
  future versions.
- PNG-only for UI graphics (WAY -> XAML vector graphics could be added
  later).
- No theme switching (can be implemented in v1.00.03 or later).

---

## Future Development

With v1.00.02 as a stable foundation, the following enhancements are
potential candidates for future releases:

- Additional window support (dialogs, settings, etc.)
- Theme switching (light/dark modes)
- Animation framework for transitions
- Custom control library
- Advanced configuration options
- Multi-language support

---

## Version Summary

**ModernUI v1.00.02 Final Release** (Build: 251227)
- **Release Date**: December 27, 2025
- **Status**: Stable, production-ready
- **Code Quality**: Fully tested, documented, clean
- **Breaking Changes**: None from v1.00.01 (first public release)

