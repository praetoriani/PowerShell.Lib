# Contributing to ScanProfileSwitcher

## Overview

This document outlines guidelines for contributing to the ScanProfileSwitcher project.

## Development Environment Setup

### Requirements
- Windows 10 or Windows 11
- PowerShell 5.0 or higher
- Visual Studio Code (recommended) or PowerShell ISE
- TWAIN scanner driver (for testing)

### Repository Structure

```
ScanProfileSwitcher/
├── ScanProfileSwitcher.ps1    # Main application entry point
├── config.json                 # Application configuration
├── GUI/                       # XAML UI definitions
│   ├── main-app-win.xaml     # Main application window
│   ├── popup-close.xaml      # Close confirmation dialog
│   ├── popup-save.xaml       # Save success confirmation
│   ├── popup-warn.xaml       # Unsaved changes warning
│   └── popup-error.xaml      # Error display dialog
├── README.md                   # User documentation
├── INSTALL.md                  # Administrator guide
├── QUICKSTART.md              # Quick reference
├── CHANGELOG.md               # Version history
├── LICENSE                     # License terms
└── .gitignore                  # Git ignore rules
```

## Code Style Guidelines

### PowerShell
- Use PascalCase for function names
- Use camelCase for variable names (except global variables which use UPPERCASE with dollar prefix)
- Add comprehensive comment blocks for all functions
- Use Try-Catch for error handling
- Include error logging for debugging

### XAML
- Use consistent indentation (2 spaces)
- Define styles in Window.Resources
- Use descriptive x:Name attributes
- Include meaningful comments for complex UI sections

### Configuration (JSON)
- Use consistent formatting with 2-space indentation
- Include comments describing each section
- Keep configuration values in logical groupings

## Development Workflow

### 1. Setting Up for Development

```powershell
# Clone the repository
git clone https://github.com/praetoriani/PowerShell.Lib.git
cd PowerShell.Lib/ScanProfileSwitcher

# Review the current structure
ls -Recurse
```

### 2. Testing Changes

```powershell
# Run the application in development
powershell -NoProfile -ExecutionPolicy Bypass -File ScanProfileSwitcher.ps1
```

### 3. Testing the GUI

- Verify all dialogs appear correctly
- Test checkbox mutually exclusive behavior
- Confirm error messages display properly
- Verify profile switching logic

### 4. Committing Changes

```powershell
# Stage your changes
git add .

# Create descriptive commit message
git commit -m "feat: add new feature description"

# Push to your branch
git push origin your-feature-branch
```

## Issue Reporting

When reporting issues, please include:
- Windows version (10 or 11)
- PowerShell version (run `$PSVersionTable.PSVersion`)
- Exact error message
- Steps to reproduce
- Expected vs actual behavior

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with clear commit messages
4. Test thoroughly
5. Push to your branch
6. Create a Pull Request with:
   - Clear description of changes
   - Reference to any related issues
   - List of changes made

## Release Process

1. Update version numbers in all files
2. Update CHANGELOG.md with new changes
3. Create a git tag with version number
4. Push tag to repository
5. GitHub Actions workflow automatically creates release

## Questions?

If you have questions about contributing, please reach out to the project maintainers.

