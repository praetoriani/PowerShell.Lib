# ModernUI - CHANGELOG (v1.00.02)

This changelog describes **ModernUI v1.00.02**. Older versions are not
listed here.

---

## [1.00.02] - ModernUI Core Enhancements

### Added

- **Central configuration usage**
  - `config.json` is now a first-class runtime component.
  - Application metadata (`app`), debug behavior (`debug`), window
    settings (`window`), image paths (`paths`) and XAML files (`screen`)
    are actively used by the PowerShell script.

- **Logging system**
  - New `Write-LogEntry` function for structured logging.
  - Log entries follow the pattern:
    - `DATETIME - SEVERITY - MESSAGE`
    - Datetime format is defined by `debug.datetime`.
    - Severity labels and icons are defined by `debug.severityLevel`.
  - Log file name and activation are defined by `debug.file` and
    `debug.enabled`.

- **External XAML main window**
  - Main window layout moved from inline XAML in `ModernUI.ps1` to
    `ModernUI/WPF/ModernUI.xaml`.
  - The script loads and parses XAML at runtime using the
    `config.screen.mainwin` setting.

- **Label-based close button with hover effect**
  - Close button is now a `Label` with an `Image` child.
  - Normal and hover icons are configured via
    `paths.winaxnCloseImage` and `paths.winaxnCloseHover`.
  - Hover behavior is implemented through `MouseEnter` and
    `MouseLeave` events.
  - Click behavior uses `PreviewMouseLeftButtonDown` and closes the
    window reliably.

- **Main window content redesign**
  - Large centered title: `ModernUI`.
  - Version text below the title using `config.app.version`.
  - Central image area displaying `appscreen.png` from the `PNG` folder
    (configured via `paths.appscreenImage`).
  - Credits text:
    - `Written by Praetoriani`
    - `Now available on GitHub`

### Changed

- **Versioning**
  - `VERSION` and `VERSION.md` updated to `1.00.02`.
  - All ModernUI-specific references now consistently use `1.00.02`.

- **Configuration**
  - `app.version` set to `"1.00.02"`.
  - `window.title` simplified to `"ModernUI"`.
  - Added `paths.appscreenImage` for the main screen preview PNG.

- **Documentation**
  - `BUGFIXES.md`, `CHANGELOG.md`, `QUICKSTART.md` and `README.md` have
    been rewritten in English for the ModernUI scope.
  - `FIXES.md` has been removed to avoid duplication.

### Removed

- Inline XAML definition from `ModernUI.ps1`.
- Legacy references to final or stable branding in favour of a clean
  version-only naming.

---

## Notes

- This version is intended as a solid baseline for further feature
  extensions. All structural changes are focused on maintainability and
  clarity rather than visual experimentation.
