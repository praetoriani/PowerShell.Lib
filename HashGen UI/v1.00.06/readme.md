# HashGen UI v1.00.00

## Overview

**HashGen UI** is a powerful PowerShell-based tool that generates cryptographic hash values for files using SHA algorithms. It provides a complete graphical user interface built with WPF/XAML and supports SHA256, SHA384, and SHA512 algorithms.

## Features

- **Modern GUI**: Clean, intuitive WPF-based interface
- **Multiple Hash Algorithms**: Support for SHA256, SHA384, and SHA512
- **Flexible Output**: Display hash values in-app or save to file
- **Batch Processing**: Process multiple files using a file list
- **Multi-language Support**: English and German language packs included
- **Comprehensive Logging**: Optional debug logging for troubleshooting
- **Security Features**: Built-in protection against path traversal and injection attacks

## System Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- .NET Framework 4.5 or higher
- Windows Presentation Framework (WPF)

## Installation

1. Download and extract the HashGen UI package
2. Ensure the folder structure is intact (see below)
3. Run `hashgen-ui.ps1` with PowerShell

## Folder Structure

```
HashGen-UI/
├── data/
│   ├── lang/
│   │   ├── en-us.json
│   │   └── de-de.json
│   ├── ui/
│   │   ├── hashgen-ui.main.xaml
│   │   ├── hashgen-ui.output.xaml
│   │   ├── hashgen-ui.info.xaml
│   │   ├── hashgen-ui.warn.xaml
│   │   └── hashgen-ui.error.xaml
│   └── config.json
├── output/
│   └── (generated files)
├── hashgen-ui.ps1
├── readme.md
├── changelog.md
├── hashgen-ui.log (generated)
└── app.error.log (generated if errors occur)
```

## Configuration

Edit `data/config.json` to customize the application:

```json
{
  "langpack": "en-us.json",
  "hashfile": "hash-output.txt",
  "debugger": {
    "usagemode": "enabled",
    "debugfile": "hashgen-ui.log"
  }
}
```

### Configuration Options

- **langpack**: Language pack to use (`en-us.json` or `de-de.json`)
- **hashfile**: Output filename for hash values (set to empty to disable file output)
- **debugger.usagemode**: Enable or disable debug logging (`enabled` or `disabled`)
- **debugger.debugfile**: Name of the debug log file

## Usage

### Single File Hashing

1. Launch `hashgen-ui.ps1`
2. Click **Browse** to select a file
3. Choose a hash algorithm from the dropdown (SHA256, SHA384, or SHA512)
4. Click **Generate Hash**
5. View the hash in the output window or check the output file

### Batch File Hashing

1. Create a `filelist.txt` file with one file path per line:
   ```
   C:\Path\To\File1.txt
   C:\Path\To\File2.pdf
   C:\Path\To\File3.jpg
   ```
2. Select `filelist.txt` through the Browse dialog
3. Click **Generate Hash**
4. Results are saved to `output/hash-filelist.json`

### Output Format

When saving to a file, the output format is:

```
File: example.zip
Path: C:\Users\Username\Downloads\example.zip
Algorithm: SHA512
Hash: E339E138DFF5B6937AA0A803EE4EABB4F4510D6BDFB218F3C72A0D47439...
Created on: 2025-10-17 18:30:45
```

For batch processing, the JSON output format is:

```json
{
  "File1.txt": {
    "path": "C:\\Path\\To\\File1.txt",
    "algo": "SHA512",
    "hash": "a1b2c3d4e5f6..."
  },
  "File2.pdf": {
    "path": "C:\\Path\\To\\File2.pdf",
    "algo": "SHA512",
    "hash": "x1y2z3..."
  }
}
```

## Security Features

HashGen UI includes several security measures:

- **Path Validation**: Prevents directory traversal attacks
- **Path Canonicalization**: Ensures paths are properly resolved
- **Input Sanitization**: Validates all file paths and configuration values
- **XML Validation**: XAML files are validated before loading
- **JSON Validation**: Configuration and language files are validated

## Troubleshooting

### Application Won't Start

- Check that all required files are present in the correct folders
- Review `app.error.log` for critical error messages
- Ensure PowerShell execution policy allows script execution

### Hash Generation Fails

- Verify the file exists and is accessible
- Check file permissions
- Review `hashgen-ui.log` for detailed error information

### GUI Not Displaying

- Ensure .NET Framework 4.5 or higher is installed
- Check that WPF assemblies are available
- Try running PowerShell as Administrator

## Language Support

HashGen UI supports multiple languages through JSON language packs located in `data/lang/`:

- `en-us.json`: English (United States)
- `de-de.json`: German (Germany)

To add a new language, create a new JSON file following the same structure and reference it in `config.json`.

## Development

### Adding New Features

All functions follow a standard return pattern:

```powershell
$status = [PSCustomObject]@{
    code = 0    # 0 = success, -1 = error
    msg  = ""   # Empty on success, error message on failure
}
```

### Debug Logging

Enable debug logging in `config.json` to track application behavior:

```json
"debugger": {
  "usagemode": "enabled",
  "debugfile": "hashgen-ui.log"
}
```

## License

This project is developed by Praetoriani.

GitHub: https://github.com/praetoriani

## Version History

See `changelog.md` for detailed version history.

## Support

For issues, questions, or feature requests, please visit the GitHub repository.

---

**HashGen UI v1.00.00** - Created on October 17, 2025