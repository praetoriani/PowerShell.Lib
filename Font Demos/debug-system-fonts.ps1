# PowerShell System Font Debugger v2.1
# Analyzes system-installed fonts to find correct FontFamily names for WPF
# Creates detailed log file "system-font-analysis.log" in script directory
# Requires Administrator privileges for complete font analysis

# Check for Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "PowerShell System Font Debugger v2.1" -ForegroundColor Cyan
Write-Host "Analyzing system fonts..." -ForegroundColor Gray

# Initialize log file (ensure complete overwrite)
$logFile = Join-Path $PSScriptRoot "system-font-analysis.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Remove existing log file if present to ensure complete overwrite
if (Test-Path $logFile) {
    try {
        Remove-Item $logFile -Force
        Write-Host "Previous log file removed." -ForegroundColor Gray
    } catch {
        Write-Host "WARNING: Could not remove existing log file: $_" -ForegroundColor Yellow
    }
}

# Create new log file
try {
    New-Item -Path $logFile -ItemType File -Force | Out-Null
    Write-Host "Log file initialized: system-font-analysis.log" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not create log file: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

function Write-LogOnly {
    param([string]$Message)
    Add-Content -Path $logFile -Value $Message -Encoding UTF8
}

# Initialize detailed logging
Write-LogOnly "================================================================================"
Write-LogOnly "PowerShell System Font Debugger v2.1"
Write-LogOnly "System Font Analysis for WPF Compatibility"
Write-LogOnly "================================================================================"
Write-LogOnly "Analysis Date: $timestamp"
Write-LogOnly "Administrator Mode: $isAdmin"
Write-LogOnly "Log File: $logFile"
Write-LogOnly "================================================================================"
Write-LogOnly ""

# Load necessary .NET assemblies
Write-Host "Loading WPF assemblies..." -ForegroundColor Gray
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Write-LogOnly "[SUCCESS] .NET WPF assemblies loaded successfully"
} catch {
    Write-Host "ERROR: Failed to load .NET WPF assemblies." -ForegroundColor Red
    Write-LogOnly "[ERROR] Failed to load .NET WPF assemblies: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

# Get all system font families
Write-Host "Enumerating system fonts..." -ForegroundColor Gray
try {
    $systemFonts = [System.Windows.Media.Fonts]::SystemFontFamilies | Sort-Object Source
    Write-Host "Found $($systemFonts.Count) system fonts." -ForegroundColor Green
    Write-LogOnly "[SUCCESS] Found $($systemFonts.Count) total system font families"
} catch {
    Write-Host "ERROR: Failed to enumerate system fonts." -ForegroundColor Red
    Write-LogOnly "[ERROR] Failed to enumerate system fonts: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

# Target fonts for analysis
$targetFonts = @(
    "Exo 2", "Lato", "Ubuntu", "Oxanium", "Titillium Web", "Averia Libre",
    "Coda", "Cutive Mono", "Monda", "Space Mono", "Telex", "Dosis",
    "Play", "PoiretOne", "Roboto"
)

Write-Host "Analyzing target fonts..." -ForegroundColor Gray

Write-LogOnly ""
Write-LogOnly "SYSTEM FONTS ANALYSIS - TARGET FONTS"
Write-LogOnly "================================================================================"
Write-LogOnly "Target Font Families: $($targetFonts.Count)"
Write-LogOnly "Searching for: $($targetFonts -join ', ')"
Write-LogOnly ""

$foundFonts = @{}
$totalFoundVariants = 0

foreach ($font in $systemFonts) {
    $fontName = $font.Source
    
    # Check if this font matches any of our target fonts
    foreach ($target in $targetFonts) {
        if ($fontName -like "*$target*" -or $fontName -eq $target) {
            if (-not $foundFonts.ContainsKey($target)) {
                $foundFonts[$target] = @()
            }
            $foundFonts[$target] += $fontName
            Write-LogOnly "[FOUND] [$target] -> '$fontName'"
            $totalFoundVariants++
        }
    }
}

Write-LogOnly ""
Write-LogOnly "DETAILED WPF COMPATIBILITY ANALYSIS"
Write-LogOnly "================================================================================"

$xmlFragments = @()
$validFonts = 0

foreach ($targetFont in $targetFonts) {
    Write-LogOnly ""
    Write-LogOnly "$targetFont Family Analysis:"
    Write-LogOnly "----------------------------------------"
    
    if ($foundFonts.ContainsKey($targetFont)) {
        foreach ($variant in $foundFonts[$targetFont]) {
            Write-LogOnly "  FontFamily Name: '$variant'"
            
            # Test WPF compatibility
            try {
                $testFamily = New-Object System.Windows.Media.FontFamily($variant)
                $testTypeface = New-Object System.Windows.Media.Typeface($testFamily, [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::Normal, [System.Windows.FontStretches]::Normal)
                Write-LogOnly "    WPF Status: ✓ COMPATIBLE"
                
                # Generate XAML fragment
                $safeKey = $variant -replace " ", "" -replace "[^a-zA-Z0-9]", ""
                $xmlFragment = "    <FontFamily x:Key=`"$safeKey`">$variant</FontFamily>"
                $xmlFragments += $xmlFragment
                Write-LogOnly "    XAML Key: $safeKey"
                Write-LogOnly "    XAML Fragment: $xmlFragment"
                $validFonts++
                
            } catch {
                Write-LogOnly "    WPF Status: ✗ ERROR - $_"
            }
        }
    } else {
        Write-LogOnly "  Status: NOT FOUND in system fonts"
        Write-LogOnly "  Action: Verify font installation"
    }
}

Write-Host "Generating XAML resources..." -ForegroundColor Gray

Write-LogOnly ""
Write-LogOnly "GENERATED XAML FONT RESOURCES"
Write-LogOnly "================================================================================"
Write-LogOnly "Copy the following XAML fragments into your Window.Resources section:"
Write-LogOnly ""
Write-LogOnly "<Window.Resources>"

foreach ($fragment in $xmlFragments) {
    Write-LogOnly $fragment
}

Write-LogOnly "</Window.Resources>"
Write-LogOnly ""

Write-LogOnly "COMPLETE SYSTEM FONT INVENTORY"
Write-LogOnly "================================================================================"
Write-LogOnly "All $($systemFonts.Count) installed system fonts:"
Write-LogOnly ""

foreach ($font in $systemFonts) {
    Write-LogOnly "  $($font.Source)"
}

Write-LogOnly ""
Write-LogOnly "ANALYSIS SUMMARY"
Write-LogOnly "================================================================================"
Write-LogOnly "Total System Fonts: $($systemFonts.Count)"
Write-LogOnly "Target Font Families: $($targetFonts.Count)"
Write-LogOnly "Found Target Variants: $totalFoundVariants"
Write-LogOnly "WPF Compatible Fonts: $validFonts"
Write-LogOnly "XAML Resources Generated: $($xmlFragments.Count)"
Write-LogOnly "Analysis Completed: $timestamp"
Write-LogOnly "================================================================================"

# Final console summary
Write-Host ""
Write-Host "Analysis completed successfully!" -ForegroundColor Green
Write-Host "Target fonts found: $totalFoundVariants/$($targetFonts.Count) families" -ForegroundColor White
Write-Host "WPF compatible: $validFonts fonts" -ForegroundColor White
Write-Host "XAML resources: $($xmlFragments.Count) generated" -ForegroundColor White
Write-Host ""
Write-Host "Detailed results saved to: system-font-analysis.log" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"