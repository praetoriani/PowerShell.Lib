<#
.SYNOPSIS
    DAMSA - Download App for Microsoft Store Apps
.DESCRIPTION
    DAMSA allows downloading Microsoft Store Apps without using the Microsoft Store directly.
    The application provides a GUI to enter Microsoft Store URLs and download the corresponding
    APPX/MSIX files for offline installation.
.NOTES
    Creation Date:  03.10.2025
    Version:        1.00.00
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
#>

# Load necessary assemblies for WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Global application variables
$global:AppName = "DAMSA - Download App for Microsoft Store Apps"
$global:AppVers = "1.00.00"
$global:AppPath = $PSScriptRoot
$global:UIPath = Join-Path $AppPath "ui"
$global:ConfigPath = Join-Path $AppPath "config"
$global:Config = $null
$global:Language = $null
$global:LoadedFonts = @{}

# Font loader class for external font loading
$fontLoaderCode = @"
using System;
using System.Runtime.InteropServices;

public class FontLoader {
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

Add-Type -TypeDefinition $fontLoaderCode -Language CSharp

# Function to load configuration
function Load-Configuration {
    try {
        Write-Host ($global:Language.console.loadingConfig) -ForegroundColor Yellow
        $configFile = Join-Path $global:ConfigPath "config.json"
        
        if (Test-Path $configFile) {
            $global:Config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host ($global:Language.console.configLoaded) -ForegroundColor Green
            return $true
        } else {
            Write-Host ($global:Language.console.configError) -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host ($global:Language.console.configError + ": " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function to load language package
function Load-Language {
    param([string]$langCode = "de-de")
    
    try {
        Write-Host "Loading language package..." -ForegroundColor Yellow
        $langFile = Join-Path $global:ConfigPath "$langCode.json"
        
        if (Test-Path $langFile) {
            $global:Language = Get-Content $langFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "Language package loaded" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Error loading language package" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host ("Error loading language package: " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function to load fonts
function Load-Fonts {
    try {
        Write-Host ($global:Language.console.loadingFonts) -ForegroundColor Yellow
        
        $fontRegularPath = Join-Path $global:UIPath "Exo2-Regular.ttf"
        $fontBoldPath = Join-Path $global:UIPath "Exo2-SemiBold.ttf"
        
        # Check if font files exist
        if (-not (Test-Path $fontRegularPath)) {
            Write-Host ("Font file not found: Exo2-Regular.ttf") -ForegroundColor Red
            return $false
        }
        
        if (-not (Test-Path $fontBoldPath)) {
            Write-Host ("Font file not found: Exo2-SemiBold.ttf") -ForegroundColor Red
            return $false
        }
        
        # Load fonts into memory
        $global:LoadedFonts["Exo2-Regular"] = [FontLoader]::LoadFontFromFile($fontRegularPath)
        $global:LoadedFonts["Exo2-SemiBold"] = [FontLoader]::LoadFontFromFile($fontBoldPath)
        
        Write-Host ($global:Language.console.fontsLoaded) -ForegroundColor Green
        return $true
    } catch {
        Write-Host ($global:Language.console.fontsError + ": " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function to validate Microsoft Store URL
function Test-StoreUrl {
    param([string]$url)
    
    if ([string]::IsNullOrWhiteSpace($url)) {
        return $false
    }
    
    # Check if URL matches Microsoft Store pattern
    $storeUrlPattern = "https://apps\.microsoft\.com/detail/"
    return $url -match $storeUrlPattern
}

# Function to get system language
function Get-SystemLanguage {
    try {
        $culture = [System.Globalization.CultureInfo]::CurrentCulture
        $langCode = $culture.Name.ToLower()
        
        # Map system language to supported languages
        if ($langCode.StartsWith("de")) {
            return "de-DE"
        } elseif ($langCode.StartsWith("en")) {
            return "en-US"
        } else {
            return "en-US" # Default to English
        }
    } catch {
        return "en-US" # Fallback to English
    }
}

# Function to show URL error window
function Show-UrlErrorWindow {
    param([string]$errorType)
    
    try {
        # Load URL error window XAML
        $xamlPath = Join-Path $global:UIPath "url-error.xaml"
        [xml]$xaml = Get-Content $xamlPath -Encoding UTF8
        
        # Create window
        $reader = [System.Xml.XmlNodeReader]::new($xaml)
        $errorWindow = [System.Windows.Markup.XamlReader]::Load($reader)
        
        # Get UI elements
        $titleText = $errorWindow.FindName("TitleText")
        $errorText = $errorWindow.FindName("ErrorText")
        $okButton = $errorWindow.FindName("OkButton")
        
        # Set localized texts
        $titleText.Text = $global:Language.urlErrorWindow.title
        $okButton.Content = $global:Language.urlErrorWindow.okButton
        
        # Set error message based on type
        if ($errorType -eq "empty") {
            $errorText.Text = $global:Language.urlErrorWindow.emptyUrlError
        } else {
            $errorText.Text = $global:Language.urlErrorWindow.invalidUrlError
        }
        
        # Add OK button click event
        $okButton.Add_Click({
            $errorWindow.Close()
        })
        
        # Show window as dialog
        $errorWindow.ShowDialog() | Out-Null
        
    } catch {
        Write-Host ("Error showing URL error window: " + $_.Exception.Message) -ForegroundColor Red
    }
}

# Function to fetch download links from store.rg-adguard.net
function Get-StoreDownloadLinks {
    param([string]$storeUrl)
    
    try {
        # API endpoint
        $apiUrl = "https://store.rg-adguard.net/api/GetFiles"
        
        # Get system language for API call
        $systemLang = Get-SystemLanguage
        
        # Prepare request body
        $body = @{
            type = 'url'
            url = $storeUrl
            ring = 'Retail'
            lang = $systemLang
        }
        
        # Make API request
        $response = Invoke-RestMethod -Method Post -Uri $apiUrl -ContentType 'application/x-www-form-urlencoded' -Body $body
        
        # Extract download links from HTML response
        $pattern = '<tr style.*<a href="([^"]*)"\\s.*>([^<]*)</a>'
        $matches = [regex]::Matches($response, $pattern)
        
        $downloadLinks = @()
        foreach ($match in $matches) {
            $downloadUrl = $match.Groups[1].Value
            $fileName = $match.Groups[2].Value
            
            # Only include APPX/MSIX files
            if ($fileName -match "\\.(appx|appxbundle|msix|msixbundle)$") {
                $downloadLinks += @{
                    Url = $downloadUrl
                    FileName = $fileName
                }
            }
        }
        
        return $downloadLinks
        
    } catch {
        Write-Host ("Error fetching download links: " + $_.Exception.Message) -ForegroundColor Red
        return @()
    }
}

# Function to show linklist window
function Show-LinklistWindow {
    param([array]$downloadLinks)
    
    try {
        # Load linklist window XAML
        $xamlPath = Join-Path $global:UIPath "linklist-window.xaml"
        [xml]$xaml = Get-Content $xamlPath -Encoding UTF8
        
        # Create window
        $reader = [System.Xml.XmlNodeReader]::new($xaml)
        $linklistWindow = [System.Windows.Markup.XamlReader]::Load($reader)
        
        # Get UI elements
        $titleText = $linklistWindow.FindName("TitleText")
        $infoText = $linklistWindow.FindName("InfoText")
        $downloadLinksListBox = $linklistWindow.FindName("DownloadLinksListBox")
        $downloadButton = $linklistWindow.FindName("DownloadButton")
        $exitButton = $linklistWindow.FindName("ExitButton")
        
        # Set localized texts
        $titleText.Text = $global:Language.linklistWindow.title
        $infoText.Text = $global:Language.linklistWindow.infoText
        $downloadButton.Content = $global:Language.linklistWindow.downloadButton
        $exitButton.Content = $global:Language.linklistWindow.exitButton
        
        # Populate listbox with download links
        foreach ($link in $downloadLinks) {
            $downloadLinksListBox.Items.Add($link.FileName) | Out-Null
        }
        
        # Add exit button click event
        $exitButton.Add_Click({
            Write-Host ($global:Language.console.exit) -ForegroundColor Yellow
            $linklistWindow.Close()
            [System.Environment]::Exit(0)
        })
        
        # Add download button click event (placeholder for now)
        $downloadButton.Add_Click({
            # TODO: Implement download functionality
            Write-Host "Download functionality will be implemented in next phase" -ForegroundColor Yellow
        })
        
        # Show window
        $linklistWindow.ShowDialog() | Out-Null
        
    } catch {
        Write-Host ("Error showing linklist window: " + $_.Exception.Message) -ForegroundColor Red
    }
}

# Function to show main window
function Show-MainWindow {
    try {
        Write-Host ($global:Language.console.showingMainWindow) -ForegroundColor Yellow
        
        # Load main window XAML
        $xamlPath = Join-Path $global:UIPath "main-window.xaml"
        [xml]$xaml = Get-Content $xamlPath -Encoding UTF8
        
        # Create window
        $reader = [System.Xml.XmlNodeReader]::new($xaml)
        $mainWindow = [System.Windows.Markup.XamlReader]::Load($reader)
        
        # Get UI elements
        $titleText = $mainWindow.FindName("TitleText")
        $infoText = $mainWindow.FindName("InfoText")
        $urlLabel = $mainWindow.FindName("UrlLabel")
        $urlTextBox = $mainWindow.FindName("UrlTextBox")
        $downloadButton = $mainWindow.FindName("DownloadButton")
        $exitButton = $mainWindow.FindName("ExitButton")
        
        # Set localized texts
        $titleText.Text = $global:Language.mainWindow.title
        $infoText.Text = $global:Language.mainWindow.infoText
        $urlLabel.Text = $global:Language.mainWindow.urlLabel
        $urlTextBox.Text = $global:Language.mainWindow.urlPlaceholder
        $downloadButton.Content = $global:Language.mainWindow.downloadButton
        $exitButton.Content = $global:Language.mainWindow.exitButton
        
        # Add exit button click event
        $exitButton.Add_Click({
            Write-Host ($global:Language.console.exit) -ForegroundColor Yellow
            $mainWindow.Close()
            [System.Environment]::Exit(0)
        })
        
        # Add download button click event
        $downloadButton.Add_Click({
            $url = $urlTextBox.Text.Trim()
            
            # Validate URL
            if ([string]::IsNullOrWhiteSpace($url) -or $url -eq $global:Language.mainWindow.urlPlaceholder) {
                Show-UrlErrorWindow -errorType "empty"
                return
            }
            
            if (-not (Test-StoreUrl -url $url)) {
                Show-UrlErrorWindow -errorType "invalid"
                return
            }
            
            # Fetch download links
            Write-Host "Fetching download links..." -ForegroundColor Yellow
            $downloadLinks = Get-StoreDownloadLinks -storeUrl $url
            
            if ($downloadLinks.Count -gt 0) {
                # Close main window and show linklist window
                $mainWindow.Close()
                Show-LinklistWindow -downloadLinks $downloadLinks
            } else {
                Write-Host "No download links found" -ForegroundColor Red
            }
        })
        
        # Show window
        $mainWindow.ShowDialog() | Out-Null
        
    } catch {
        Write-Host ("Error showing main window: " + $_.Exception.Message) -ForegroundColor Red
    }
}

# Function to cleanup fonts on exit
function Remove-LoadedFonts {
    foreach ($fontKey in $global:LoadedFonts.Keys) {
        try {
            [FontLoader]::RemoveFont($global:LoadedFonts[$fontKey]) | Out-Null
            Write-Host ("Font '$fontKey' removed successfully") -ForegroundColor Green
        } catch {
            Write-Host ("Error removing font '$fontKey': " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

# Main application entry point
function Start-DAMSA {
    try {
        Write-Host "Starting DAMSA..." -ForegroundColor Green
        
        # Minimize console window
        Write-Host "Minimizing console..." -ForegroundColor Yellow
        $consoleWindow = [System.Console]::Title = $global:AppName
        Add-Type -Name "Win32ShowWindow" -Namespace Win32Functions -MemberDefinition '
            [DllImport("user32.dll")]
            public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            [DllImport("kernel32.dll")]
            public static extern IntPtr GetConsoleWindow();
        '
        $consoleHandle = [Win32Functions.Win32ShowWindow]::GetConsoleWindow()
        [Win32Functions.Win32ShowWindow]::ShowWindow($consoleHandle, 2) | Out-Null # 2 = SW_SHOWMINIMIZED
        
        # Load initial language (default)
        if (-not (Load-Language -langCode "de-de")) {
            Write-Host "Failed to load initial language package" -ForegroundColor Red
            return
        }
        
        # Load configuration
        if (-not (Load-Configuration)) {
            Write-Host "Failed to load configuration" -ForegroundColor Red
            return
        }
        
        # Load language based on config
        if ($global:Config.language -ne "de-de") {
            if (-not (Load-Language -langCode $global:Config.language)) {
                Write-Host "Failed to load configured language, using default" -ForegroundColor Yellow
            }
        }
        
        # Load fonts
        if (-not (Load-Fonts)) {
            Write-Host "Failed to load fonts, continuing without custom fonts" -ForegroundColor Yellow
        }
        
        # Show main window
        Show-MainWindow
        
    } catch {
        Write-Host ("Error starting DAMSA: " + $_.Exception.Message) -ForegroundColor Red
    } finally {
        # Cleanup fonts on exit
        Remove-LoadedFonts
    }
}

# Start the application
Start-DAMSA