# PowerShell-XAML-Demo.ps1
# Advanced font demonstration application with external fonts and dark theme

# 1. Load required .NET assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# 2. Define C# class for font loading
$fontLoaderCode = @"
using System;
using System.Runtime.InteropServices;
public class FontLoaderXAML {
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern IntPtr AddFontMemResourceEx(IntPtr pbFont, uint cbFont, IntPtr pdv, [In] ref uint pcFonts);
    
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern bool RemoveFontMemResourceEx(IntPtr fh);

    public class LoadedFont {
        public IntPtr Handle;
        public IntPtr FontPointer;
    }
    
    public static LoadedFont LoadFontFromFile(string path) {
        byte[] fontData = System.IO.File.ReadAllBytes(path);
        IntPtr fontPtr = Marshal.AllocCoTaskMem(fontData.Length);
        Marshal.Copy(fontData, 0, fontPtr, fontData.Length);
        uint dummy = 0;
        IntPtr handle = AddFontMemResourceEx(fontPtr, (uint)fontData.Length, IntPtr.Zero, ref dummy);
        if(handle == IntPtr.Zero)
           throw new Exception("AddFontMemResourceEx failed. Error: " + Marshal.GetLastWin32Error());
        LoadedFont lf = new LoadedFont();
        lf.Handle = handle;
        lf.FontPointer = fontPtr;
        return lf;
    }
    
    public static bool RemoveFont(LoadedFont lf) {
        bool result = RemoveFontMemResourceEx(lf.Handle);
        if (result) {
            Marshal.FreeCoTaskMem(lf.FontPointer);
        }
        return result;
    }
}
"@

# Check if class already exists
if (-not ([System.Management.Automation.PSTypeName]'FontLoaderXAML').Type) {
    Add-Type -TypeDefinition $fontLoaderCode -Language CSharp
}

# 3. Global variable for script directory
$global:ScriptDirectory = $PSScriptRoot
if ([string]::IsNullOrEmpty($global:ScriptDirectory)) {
    $global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrEmpty($global:ScriptDirectory)) {
    $global:ScriptDirectory = Get-Location
}

# Define paths
$fontDir = Join-Path $global:ScriptDirectory "Fonts"
$xamlPath = Join-Path $global:ScriptDirectory "data\ui\PowerShell-XAML-Demo.xaml"

# All font file paths
$fontExo2RegularPath = Join-Path $fontDir "Exo2-Regular.ttf"
$fontExo2SemiBoldPath = Join-Path $fontDir "Exo2-SemiBold.ttf"
$fontCodaRegularPath = Join-Path $fontDir "Coda-Regular.ttf"
$fontUbuntuRegularPath = Join-Path $fontDir "Ubuntu-Regular.ttf"
$fontSpaceMonoRegularPath = Join-Path $fontDir "SpaceMono-Regular.ttf"
$fontTitilliumWebRegularPath = Join-Path $fontDir "TitilliumWeb-Regular.ttf"
$fontMondaRegularPath = Join-Path $fontDir "Monda-Regular.ttf"
$fontMondaBoldPath = Join-Path $fontDir "Monda-Bold.ttf"
$fontRobotoRegularPath = Join-Path $fontDir "Roboto-Regular.ttf"
$fontOxaniumRegularPath = Join-Path $fontDir "Oxanium-Regular.ttf"
$fontAveriaLibreRegularPath = Join-Path $fontDir "AveriaLibre-Regular.ttf"
$fontCutiveMonoRegularPath = Join-Path $fontDir "CutiveMono-Regular.ttf"
$fontDosisRegularPath = Join-Path $fontDir "Dosis-Regular.ttf"
$fontTelexRegularPath = Join-Path $fontDir "Telex-Regular.ttf"
$fontPlayRegularPath = Join-Path $fontDir "Play-Regular.ttf"

# 4. Font file validation
if (-not (Test-Path $fontExo2RegularPath)) {
    Write-Host "Error: Font file 'Exo2-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontExo2SemiBoldPath)) {
    Write-Host "Error: Font file 'Exo2-SemiBold.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontCodaRegularPath)) {
    Write-Host "Error: Font file 'Coda-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontUbuntuRegularPath)) {
    Write-Host "Error: Font file 'Ubuntu-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontSpaceMonoRegularPath)) {
    Write-Host "Error: Font file 'SpaceMono-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontTitilliumWebRegularPath)) {
    Write-Host "Error: Font file 'TitilliumWeb-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontMondaRegularPath)) {
    Write-Host "Error: Font file 'Monda-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontMondaBoldPath)) {
    Write-Host "Error: Font file 'Monda-Bold.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontRobotoRegularPath)) {
    Write-Host "Error: Font file 'Roboto-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontOxaniumRegularPath)) {
    Write-Host "Error: Font file 'Oxanium-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontAveriaLibreRegularPath)) {
    Write-Host "Error: Font file 'AveriaLibre-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontCutiveMonoRegularPath)) {
    Write-Host "Error: Font file 'CutiveMono-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontDosisRegularPath)) {
    Write-Host "Error: Font file 'Dosis-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontTelexRegularPath)) {
    Write-Host "Error: Font file 'Telex-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $fontPlayRegularPath)) {
    Write-Host "Error: Font file 'Play-Regular.ttf' not found in $fontDir" -ForegroundColor Red
    exit
}
if (-not (Test-Path $xamlPath)) {
    Write-Host "Error: XAML file not found in data\ui\" -ForegroundColor Red
    exit
}

# 5. Load fonts into private font pool
try {
    $global:loadedFonts = @{}
    $global:loadedFonts["Exo2-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontExo2RegularPath)
    $global:loadedFonts["Exo2-SemiBold"] = [FontLoaderXAML]::LoadFontFromFile($fontExo2SemiBoldPath)
    $global:loadedFonts["Coda-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontCodaRegularPath)
    $global:loadedFonts["Ubuntu-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontUbuntuRegularPath)
    $global:loadedFonts["SpaceMono-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontSpaceMonoRegularPath)
    $global:loadedFonts["TitilliumWeb-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontTitilliumWebRegularPath)
    $global:loadedFonts["Monda-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontMondaRegularPath)
    $global:loadedFonts["Monda-Bold"] = [FontLoaderXAML]::LoadFontFromFile($fontMondaBoldPath)
    $global:loadedFonts["Roboto-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontRobotoRegularPath)
    $global:loadedFonts["Oxanium-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontOxaniumRegularPath)
    $global:loadedFonts["AveriaLibre-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontAveriaLibreRegularPath)
    $global:loadedFonts["CutiveMono-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontCutiveMonoRegularPath)
    $global:loadedFonts["Dosis-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontDosisRegularPath)
    $global:loadedFonts["Telex-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontTelexRegularPath)
    $global:loadedFonts["Play-Regular"] = [FontLoaderXAML]::LoadFontFromFile($fontPlayRegularPath)
    Write-Host "Fonts loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error loading fonts: $_" -ForegroundColor Red
    exit
}

# 6. Load XAML file
try {
    [xml]$xaml = Get-Content $xamlPath -Raw -Encoding UTF8
    Write-Host "XAML file loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error loading XAML file: $_" -ForegroundColor Red
    exit
}

# 7. Parse XAML and create window
try {
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    if (-not $window) {
        Write-Host "Error: Could not create window." -ForegroundColor Red
        exit
    }
    Write-Host "Window created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating window: $_" -ForegroundColor Red
    exit
}

# 8. Set font families after XAML loading
$window.FindName("txtExo2Large").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2")
$window.FindName("txtExo2Medium").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2")
$window.FindName("txtExo2Small").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2")

$window.FindName("txtExo2SemiBoldLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2 SemiBold")
$window.FindName("txtExo2SemiBoldMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2 SemiBold")
$window.FindName("txtExo2SemiBoldSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Exo 2 SemiBold")

$window.FindName("txtCodaLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Coda")
$window.FindName("txtCodaMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Coda")
$window.FindName("txtCodaSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Coda")

$window.FindName("txtUbuntuLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Ubuntu")
$window.FindName("txtUbuntuMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Ubuntu")
$window.FindName("txtUbuntuSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Ubuntu")

$window.FindName("txtSpaceMonoLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Space Mono")
$window.FindName("txtSpaceMonoMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Space Mono")
$window.FindName("txtSpaceMonoSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Space Mono")

$window.FindName("txtTitilliumWebLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Titillium Web")
$window.FindName("txtTitilliumWebMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Titillium Web")
$window.FindName("txtTitilliumWebSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Titillium Web")

$window.FindName("txtMondaRegularLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Monda")
$window.FindName("txtMondaRegularMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Monda")
$window.FindName("txtMondaRegularSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Monda")

$window.FindName("txtMondaBoldLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Monda Bold")
$window.FindName("txtMondaBoldMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Monda Bold")
$window.FindName("txtMondaBoldSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Monda Bold")

$window.FindName("txtRobotoLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Roboto")
$window.FindName("txtRobotoMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Roboto")
$window.FindName("txtRobotoSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Roboto")

$window.FindName("txtOxaniumLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Oxanium")
$window.FindName("txtOxaniumMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Oxanium")
$window.FindName("txtOxaniumSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Oxanium")

$window.FindName("txtAveriaLibreLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Averia Libre")
$window.FindName("txtAveriaLibreMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Averia Libre")
$window.FindName("txtAveriaLibreSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Averia Libre")

$window.FindName("txtCutiveMonoLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Cutive Mono")
$window.FindName("txtCutiveMonoMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Cutive Mono")
$window.FindName("txtCutiveMonoSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Cutive Mono")

$window.FindName("txtDosisLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Dosis")
$window.FindName("txtDosisMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Dosis")
$window.FindName("txtDosisSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Dosis")

$window.FindName("txtTelexLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Telex")
$window.FindName("txtTelexMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Telex")
$window.FindName("txtTelexSmall").FontFamily = New-Object System.Windows.Media.FontFamily("Telex")

$window.FindName("txtPlayLarge").FontFamily = New-Object System.Windows.Media.FontFamily("Play")
$window.FindName("txtPlayMedium").FontFamily = New-Object System.Windows.Media.FontFamily("Play")
$window.FindName("txtPlaySmall").FontFamily = New-Object System.Windows.Media.FontFamily("Play")

# 9. Window close event handler
$window.Add_Closed({
    Write-Host "Closing application and releasing resources..." -ForegroundColor Yellow
    foreach ($fontKey in $global:loadedFonts.Keys) {
        try {
            [FontLoaderXAML]::RemoveFont($global:loadedFonts[$fontKey]) | Out-Null
            Write-Host "Font '$fontKey' removed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Error removing font '$fontKey': $_" -ForegroundColor Red
        }
    }
    Write-Host "Application closed." -ForegroundColor Cyan
})

# 10. Show window
Write-Host "Displaying PowerShell XAML Font Demo window..." -ForegroundColor Cyan
$window.ShowDialog() | Out-Null