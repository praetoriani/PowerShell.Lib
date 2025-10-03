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
│   ├── Exo2-Regular.ttf
│   ├── Exo2-SemiBold.ttf
│   ├── Coda-Regular.ttf
│   ├── Ubuntu-Regular.ttf
│   ├── SpaceMono-Regular.ttf
│   ├── TitilliumWeb-Regular.ttf
│   ├── Monda-Regular.ttf
│   ├── Monda-Bold.ttf
│   ├── Roboto-Regular.ttf
│   ├── Oxanium-Regular.ttf
│   ├── AveriaLibre-Regular.ttf
│   ├── CutiveMono-Regular.ttf
│   ├── Dosis-Regular.ttf
│   ├── Telex-Regular.ttf
│   └── Play-Regular.ttf
├── data/
│   └── ui/
│       └── PowerShell-XAML-Demo.xaml  # External XAML file
├── PowerShell-XAML-Demo.ps1           # ⭐ Recommended main demo
├── install-fonts.ps1                  # Font installation script
└── README.md                          # This file
```

## 🚀 Getting Started

### Prerequisites

- **PowerShell 5.1** or **PowerShell 7+**
- **Windows** with WPF support
- **Administrator privileges** (for font installation only)

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
- **15 different external fonts**
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

## 📚 Demo Scripts Overview

### PowerShell-XAML-Demo.ps1
**The premier font demonstration** - A professional-grade application showcasing all 15 fonts with:
- Modern dark theme UI
- External XAML file integration
- Multiple font sizes per typeface
- Comprehensive font descriptions
- Professional card-based layout

### install-fonts.ps1
Automated font installation script for system-wide font deployment.

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

The demo includes 15 carefully selected fonts showcasing different styles:

| Font Family | Style | Use Case |
|-------------|-------|----------|
| Exo2 | Regular, SemiBold | Modern digital applications |
| Coda | Regular | Geometric, attention-grabbing designs |
| Ubuntu | Regular | Warm, friendly Linux-style interface |
| Space Mono | Regular | Monospaced code display |
| Titillium Web | Regular | Web-optimized readability |
| Monda | Regular, Bold | Playful, creative projects |
| Roboto | Regular | Android-style modern interfaces |
| Oxanium | Regular | Futuristic, sci-fi applications |
| Averia Libre | Regular | Handwritten, personal touch |
| Cutive Mono | Regular | Vintage typewriter aesthetic |
| Dosis | Regular | Clean, minimalistic design |
| Telex | Regular | Classical proportions with modern details |
| Play | Regular | Clear, direct sans-serif |

## 🔧 Troubleshooting

### Common Issues

**"Unable to find the specified file" Error:**
- Ensure fonts are installed system-wide
- Run `install-fonts.ps1` as Administrator
- Verify XAML files are in correct locations

**Fonts Not Displaying:**
- Check if fonts are properly installed in Windows
- Verify font names match installed font families
- Restart PowerShell session after font installation

**Permission Errors:**
- Run PowerShell as Administrator for font installation
- Check Windows font directory permissions

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

**Note**: This demo collection represents advanced PowerShell WPF development techniques. The `PowerShell-XAML-Demo.ps1` script showcases enterprise-level font integration with modern UI design patterns.