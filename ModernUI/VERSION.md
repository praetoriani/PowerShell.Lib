# ModernUI Version 1.00.02

This file describes **ModernUI v1.00.02** in the context of the
`PowerShell.Lib` repository. Previous versions are not referenced here.

---

## Summary

- **Name:** ModernUI
- **Version:** 1.00.02
- **Type:** Feature & structure update
- **Technology:** PowerShell 7+, WPF (.NET Framework 4.8)

This version focuses on external XAML loading, a central logging system,
stronger configuration usage and a modernized main window with
label-based controls.

---

## Key Changes

1. **External XAML file for the main window**
   - Main window layout moved to `./ModernUI/WPF/ModernUI.xaml`.
   - The PowerShell script loads this file at runtime using `config.screen`.

2. **Config-driven behavior**
   - `config.json` is now a central runtime component.
   - It defines app metadata, logging behavior, image paths and XAML file
     names.

3. **Logging system**
   - New `Write-LogEntry` function logs important events to a file when
     enabled via `config.json`.
   - Log entries include timestamp, severity and message.

4. **Label-based close button with hover effect**
   - Close button is now implemented as a label hosting an image.
   - Normal and hover images are defined in `config.paths`.

5. **English-only ModernUI scope**
   - All UI labels and ModernUI-specific documentation for v1.00.02 are in
     English.

---

## Files updated for v1.00.02

- `ModernUI.ps1`
- `config.json`
- `WPF/ModernUI.xaml`
- `BUGFIXES.md`
- `CHANGELOG.md`
- `QUICKSTART.md`
- `README.md`
- `VERSION`
- `VERSION.md`

`FIXES.md` has been removed as it is no longer part of the ModernUI
documentation structure.

---

## Notes

- The version string `1.00.02` is used consistently across script, config,
  XAML and documentation.
- All references to older terms such as "Final Release" or previous version
  numbers have been removed from the ModernUI documentation for this version.

After testing this version in your environment, you can decide whether further
minor or major versions should be created and documented.
