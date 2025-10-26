# PowerShell Font Installer - System-Wide Font Installation Utility
# Installs 26 custom fonts from the "Fonts" subdirectory to the Windows system fonts folder
# Requires Administrator privileges for system-wide installation

# Check for Administrator privileges - required for system font installation
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required for system font installation." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "PowerShell Font Installer v1.0" -ForegroundColor Cyan
Write-Host "System-Wide Font Installation Utility" -ForegroundColor Gray
Write-Host "=" * 50

# Define C# class for system font installation
$fontInstallerCode = @"
using System;
using System.Runtime.InteropServices;
using System.IO;

public class FontInstaller {
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern int AddFontResource(string lpFilename);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    
    private const int HWND_BROADCAST = 0xFFFF;
    private const uint WM_FONTCHANGE = 0x001D;
    
    public static bool InstallFont(string fontPath, string fontName) {
        try {
            // Copy font to Windows Fonts directory
            string windowsFontsDir = Environment.GetFolderPath(Environment.SpecialFolder.Fonts);
            string destinationPath = Path.Combine(windowsFontsDir, Path.GetFileName(fontPath));
            
            // Remove existing font if present
            if (File.Exists(destinationPath)) {
                File.Delete(destinationPath);
            }
            
            // Copy new font file
            File.Copy(fontPath, destinationPath, true);
            
            // Add font resource to system
            int result = AddFontResource(destinationPath);
            
            if (result > 0) {
                // Notify all applications of font change
                SendNotifyMessage((IntPtr)HWND_BROADCAST, WM_FONTCHANGE, IntPtr.Zero, IntPtr.Zero);
                return true;
            }
            
            return false;
        } catch (Exception ex) {
            Console.WriteLine("Error installing font: " + ex.Message);
            return false;
        }
    }
}
"@

try {
    Add-Type -TypeDefinition $fontInstallerCode -Language CSharp
    Write-Host "Font installation system initialized successfully." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to initialize font installation system." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Define font directory and all 26 font files
$fontDir = Join-Path $PSScriptRoot "Fonts"
$fontFiles = @(
    "AveriaLibre-Bold.ttf",
    "AveriaLibre-Regular.ttf",
    "Coda-Regular.ttf",
    "CutiveMono-Regular.ttf",
    "Dosis-Bold.ttf",
    "Dosis-Regular.ttf",
    "Exo2-Regular.ttf",
    "Exo2-SemiBold.ttf",
    "Lato-Bold.ttf",
    "Lato-Regular.ttf",
    "Monda-Bold.ttf",
    "Monda-Regular.ttf",
    "Oxanium-Bold.ttf",
    "Oxanium-Regular.ttf",
    "Play-Bold.ttf",
    "Play-Regular.ttf",
    "PoiretOne-Regular.ttf",
    "Roboto-Bold.ttf",
    "Roboto-Medium.ttf",
    "Roboto-Regular.ttf",
    "SpaceMono-Regular.ttf",
    "Telex-Regular.ttf",
    "TitilliumWeb-Bold.ttf",
    "TitilliumWeb-Regular.ttf",
    "Ubuntu-Bold.ttf",
    "Ubuntu-Regular.ttf"
)

Write-Host ""
Write-Host "Checking font files in directory: $fontDir" -ForegroundColor Yellow

# Check if font directory exists
if (-not (Test-Path $fontDir)) {
    Write-Host "ERROR: Font directory not found: $fontDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if all font files exist
$missingFiles = @()
foreach ($fontFile in $fontFiles) {
    $fontPath = Join-Path $fontDir $fontFile
    if (-not (Test-Path $fontPath)) {
        $missingFiles += $fontFile
        Write-Host "  MISSING: $fontFile" -ForegroundColor Red
    } else {
        Write-Host "  FOUND:   $fontFile" -ForegroundColor Green
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: $($missingFiles.Count) font file(s) missing from $fontDir" -ForegroundColor Red
    Write-Host "Missing files:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "All $($fontFiles.Count) font files found successfully." -ForegroundColor Green
Write-Host ""

# Confirm installation
$response = Read-Host "Install all $($fontFiles.Count) fonts system-wide? (Y/N)"
if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "Font installation cancelled by user." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Installing fonts system-wide..." -ForegroundColor Cyan
Write-Host "=" * 50

# Install all fonts system-wide
$installedFonts = 0
$failedFonts = @()

foreach ($fontFile in $fontFiles) {
    $fontPath = Join-Path $fontDir $fontFile
    $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile)
    
    Write-Host "Installing: $fontFile" -NoNewline -ForegroundColor White
    
    try {
        $success = [FontInstaller]::InstallFont($fontPath, $fontName)
        if ($success) {
            Write-Host " [SUCCESS]" -ForegroundColor Green
            $installedFonts++
        } else {
            Write-Host " [FAILED]" -ForegroundColor Red
            $failedFonts += $fontFile
        }
    } catch {
        Write-Host " [ERROR: $_]" -ForegroundColor Red
        $failedFonts += $fontFile
    }
}

Write-Host ""
Write-Host "=" * 50
Write-Host "Font Installation Summary:" -ForegroundColor Cyan
Write-Host "  Total fonts:        $($fontFiles.Count)" -ForegroundColor White
Write-Host "  Successfully installed: $installedFonts" -ForegroundColor Green
Write-Host "  Failed installations:   $($failedFonts.Count)" -ForegroundColor Red

if ($failedFonts.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed font installations:" -ForegroundColor Red
    foreach ($file in $failedFonts) {
        Write-Host "  - $file" -ForegroundColor Red
    }
}

Write-Host ""
if ($installedFonts -eq $fontFiles.Count) {
    Write-Host "ALL FONTS INSTALLED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "All fonts are now available system-wide for all applications." -ForegroundColor White
} elseif ($installedFonts -gt 0) {
    Write-Host "PARTIAL SUCCESS: $installedFonts out of $($fontFiles.Count) fonts installed." -ForegroundColor Yellow
    Write-Host "Installed fonts are available system-wide." -ForegroundColor White
} else {
    Write-Host "INSTALLATION FAILED: No fonts were installed successfully." -ForegroundColor Red
}

Write-Host ""
Write-Host "Note: You may need to restart applications to see the new fonts." -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"