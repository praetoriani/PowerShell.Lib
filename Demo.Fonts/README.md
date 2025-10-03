# Demo.Fonts - PowerShell Font Integration Examples

A comprehensive collection of PowerShell scripts demonstrating how to integrate external fonts in WPF/XAML applications using various techniques and approaches.

## 📦 Quick Download

**[Download Demo.Fonts-2025-10-03.zip](https://github.com/praetoriani/PowerShell.Lib/raw/refs/heads/main/Demo.Fonts/Demo.Fonts-2025-10-03.zip)** - Complete package containing all demo files, fonts, and scripts.

## 🎯 Overview

This directory contains multiple demonstrations of external font loading and integration in PowerShell WPF applications. The examples range from basic font loading to advanced professional UI implementations with modern dark themes.

## 📁 Directory Structure

```
Demo.Fonts/
├── Fonts/                          # Font files (.ttf)
│   ├── AveriaLibre-Bold.ttf
│   ├── AveriaLibre-Regular.ttf
│   ├── Coda-Regular.ttf
│   ├── CutiveMono-Regular.ttf
│   ├── Dosis-Bold.ttf
│   ├── Dosis-Regular.ttf
│   ├── Exo2-Regular.ttf
│   ├── Exo2-SemiBold.ttf
│   ├── Lato-Bold.ttf
│   ├── Lato-Regular.ttf
│   ├── Monda-Bold.ttf
│   ├── Monda-Regular.ttf
│   ├── Oxanium-Bold.ttf
│   ├── Oxanium-Regular.ttf
│   ├── Play-Bold.ttf
│   ├── Play-Regular.ttf
│   ├── PoiretOne-Regular.ttf
│   ├── Roboto-Bold.ttf
│   ├── Roboto-Medium.ttf
│   ├── Roboto-Regular.ttf
│   ├── SpaceMono-Regular.ttf
│   ├── Telex-Regular.ttf
│   ├── TitilliumWeb-Bold.ttf
│   ├── TitilliumWeb-Regular.ttf
│   ├── Ubuntu-Bold.ttf
│   └── Ubuntu-Regular.ttf
├── data/
│   └── ui/
│       └── PowerShell-XAML-Demo.xaml  # External XAML file
├── PowerShell-XAML-Demo.ps1           # ⭐ Recommended main demo
├── install-fonts.ps1                  # Font installation script
├── debug-system-fonts.ps1             # 🔧 Font analysis & WPF compatibility checker
└── README.md                          # This file
```

## 🚀 Getting Started

### Prerequisites

- **PowerShell 5.1** or **PowerShell 7+**
- **Windows** with WPF support
- **Administrator privileges** (for font installation and analysis)

### ⚠️ Important: Font Installation Required

**Before running any demos, fonts must be installed system-wide.** Choose one of these methods:

#### Method 1: Automated Installation (Recommended)
```powershell
# Run as Administrator
.\install-fonts.ps1
```

> **⚠️ ADMINISTRATOR PRIVILEGES REQUIRED**: The `install-fonts.ps1` script must be executed with administrator privileges to install fonts system-wide.

#### Method 2: Manual Installation
1. Navigate to the `Fonts/` directory
2. Select all `.ttf` files
3. Right-click and select "Install" or "Install for all users"
4. Fonts will be installed to `C:\Windows\Fonts\`

### Running the Demos

#### 🌟 Recommended Demo: PowerShell-XAML-Demo.ps1

This is the **flagship demonstration** featuring:
- **26 different external fonts** (Regular and Bold variants)
- **Professional dark theme UI**
- **Multiple font sizes** (24pt, 18pt, 14pt) per font
- **Modern card-based layout**
- **External XAML integration**

```powershell
.\PowerShell-XAML-Demo.ps1
```

**Features:**
- ✅ Professional dark gradient background
- ✅ Card-based font demonstrations
- ✅ Three font sizes per typeface
- ✅ Detailed font descriptions
- ✅ Modern WPF design patterns
- ✅ Proper resource management

#### 🔧 Font Analysis Tool: debug-system-fonts.ps1

Advanced diagnostic script for analyzing installed fonts and WPF compatibility:

```powershell
# Run as Administrator
.\debug-system-fonts.ps1
```

> **⚠️ ADMINISTRATOR PRIVILEGES REQUIRED**: This script requires administrator privileges to perform comprehensive font system analysis.

**Features:**
- ✅ Analyzes all installed system fonts
- ✅ Tests WPF compatibility for each font
- ✅ Generates detailed log files with results
- ✅ Identifies problematic or incompatible fonts
- ✅ Provides font loading diagnostics

## 📚 Demo Scripts Overview

### PowerShell-XAML-Demo.ps1
**The premier font demonstration** - A professional-grade application showcasing all available fonts with:
- Modern dark theme UI
- External XAML file integration
- Multiple font sizes per typeface
- Comprehensive font descriptions
- Professional card-based layout

### install-fonts.ps1
Automated font installation script for system-wide font deployment from the `Fonts/` directory.

### debug-system-fonts.ps1
**Advanced font analysis tool** - Comprehensive diagnostic script that:
- Scans all installed system fonts
- Tests WPF compatibility and loading capabilities
- Creates detailed log files with analysis results
- Identifies font loading issues and conflicts
- Provides troubleshooting information for font problems

## 🛠️ Technical Implementation

### Font Loading Architecture

All demos use the Windows GDI32 API for runtime font integration:

```csharp
[DllImport("gdi32.dll", SetLastError = true)]
public static extern IntPtr AddFontMemResourceEx(IntPtr pbFont, uint cbFont, IntPtr pdv, [In] ref uint pcFonts);

[DllImport("gdi32.dll", SetLastError = true)]
public static extern bool RemoveFontMemResourceEx(IntPtr fh);
```

### Key Features

- **Memory Management**: Proper allocation and cleanup of font resources
- **Error Handling**: Comprehensive error checking and user feedback
- **Cross-Platform Fonts**: Support for various font formats and styles
- **Resource Cleanup**: Automatic font removal on application exit
- **XAML Integration**: External XAML file support for UI separation

## 🎨 Included Fonts

The demo includes 26 carefully selected fonts showcasing different styles:

| Font Family | Available Styles | Use Case |
|-------------|------------------|----------|
| AveriaLibre | Regular, Bold | Handwritten, personal touch |
| Coda | Regular | Geometric, attention-grabbing designs |
| CutiveMono | Regular | Vintage typewriter aesthetic |
| Dosis | Regular, Bold | Clean, minimalistic design |
| Exo2 | Regular, SemiBold | Modern digital applications |
| Lato | Regular, Bold | Professional web typography |
| Monda | Regular, Bold | Playful, creative projects |
| Oxanium | Regular, Bold | Futuristic, sci-fi applications |
| Play | Regular, Bold | Clear, direct sans-serif |
| PoiretOne | Regular | Elegant, decorative headings |
| Roboto | Regular, Medium, Bold | Android-style modern interfaces |
| SpaceMono | Regular | Monospaced code display |
| Telex | Regular | Classical proportions with modern details |
| TitilliumWeb | Regular, Bold | Web-optimized readability |
| Ubuntu | Regular, Bold | Warm, friendly Linux-style interface |

## 🔧 Troubleshooting

### Common Issues

**"Unable to find the specified file" Error:**
- Ensure fonts are installed system-wide
- Run `install-fonts.ps1` as Administrator
- Verify XAML files are in correct locations
- Use `debug-system-fonts.ps1` to analyze font compatibility

**Fonts Not Displaying:**
- Check if fonts are properly installed in Windows
- Verify font names match installed font families
- Restart PowerShell session after font installation
- Run font analysis tool for detailed diagnostics

**Permission Errors:**
- Run PowerShell as Administrator for font installation
- Check Windows font directory permissions
- Ensure proper execution policy settings

### Diagnostic Tools

Use the included `debug-system-fonts.ps1` script to:
- Identify font loading issues
- Check WPF compatibility
- Generate detailed system font reports
- Troubleshoot specific font problems

## 📄 License

This demonstration package is provided for educational and development purposes. Font licenses may vary - please check individual font licensing terms.

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Additional font examples
- New UI themes
- Enhanced error handling
- Cross-platform compatibility
- Performance optimizations

## 📞 Support

For issues, questions, or contributions, please refer to the main PowerShell.Lib repository documentation.

---

**Note**: This demo collection represents advanced PowerShell WPF development techniques. The `PowerShell-XAML-Demo.ps1` script showcases enterprise-level font integration with modern UI design patterns, while `debug-system-fonts.ps1` provides professional-grade font analysis capabilities.