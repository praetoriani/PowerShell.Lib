<#
.SYNOPSIS
    ModernUI v1.00.02 - Modern UI Framework for PowerShell WPF

.DESCRIPTION
    A modern user interface for PowerShell built with WPF, following
    Microsoft Windows 11 Modern UI Design Principles. This version introduces:
    - External XAML file loading (./WPF/ directory structure)
    - Comprehensive logging system with config.json integration
    - Label-based UI elements with hover effects
    - Config-driven application behavior
    - Production-ready reliability

.AUTHOR
    Marc Sczepanski (praetoriani)

.VERSION
    1.00.02 (Enhancement Release)
    - External XAML file loading from ./WPF/ directory
    - Comprehensive logging system with WriteLogEntry function
    - Label-based close button with hover effects
    - Config-driven window initialization
    - Enhanced resource management
    - Complete English documentation
    - Frameless window design with PNG-based UI elements

.NOTES
    Requires: PowerShell 7.0+, .NET Framework 4.8+
    GitHub: https://github.com/praetoriani/PowerShell.Lib
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config.json"
)

# ============================================================================
# GLOBAL VARIABLES & CONSTANTS
# ============================================================================

$script:WindowReference = $null
$script:Config = $null
$script:LogFilePath = $null
$script:LogEnabled = $false
$script:ImageCache = @{}

# ============================================================================
# ASSEMBLY LOADING
# ============================================================================

try {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationCore")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("WindowsBase")
}
catch {
    Write-Error "[ERROR] Assembly loading failed: $_"
    exit 1
}

# ============================================================================
# LOGGING SYSTEM
# ============================================================================

function Initialize-Logging {
    param([pscustomobject]$Config)

    try {
        $script:LogEnabled = $false
        
        # Check if logging is enabled in config
        if ($null -ne $Config.debug -and $Config.debug.enabled -eq "true") {
            $logFileName = $Config.debug.file
            $script:LogFilePath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
            
            # Delete existing log file
            if (Test-Path -Path $script:LogFilePath) {
                Remove-Item -Path $script:LogFilePath -Force -ErrorAction SilentlyContinue
            }
            
            # Create new log file
            $null = New-Item -Path $script:LogFilePath -ItemType File -Force -ErrorAction SilentlyContinue
            $script:LogEnabled = $true
            
            Write-LogEntry -Severity "INFO" -Message "Logging initialized - $logFileName" -WriteConsole
        }
        else {
            Write-LogEntry -Severity "INFO" -Message "Logging disabled in config" -WriteConsole
        }
    }
    catch {
        Write-Error "[ERROR] Logging initialization failed: $_"
    }
}

function Write-LogEntry {
    param(
        [string]$Severity = "INFO",
        [string]$Message = "",
        [switch]$WriteConsole = $false
    )

    try {
        if (-not $script:LogEnabled -or [string]::IsNullOrEmpty($script:LogFilePath)) {
            if ($WriteConsole) {
                $consoleColor = switch ($Severity) {
                    "INFO" { "Cyan" }
                    "WARN" { "Yellow" }
                    "ERROR" { "Red" }
                    "DEBUG" { "Gray" }
                    default { "White" }
                }
                Write-Host "[$Severity] $Message" -ForegroundColor $consoleColor
            }
            return
        }

        # Get timestamp format from config
        $dateTimeFormat = if ($script:Config.debug.datetime) { $script:Config.debug.datetime } else { "yyyy.MM.dd ; HH:mm:ss" }
        $timestamp = Get-Date -Format $dateTimeFormat

        # Get severity icon from config - use safe defaults if not available
        $severityIcon = "[INFO] -> "
        
        if ($script:Config.debug.severityLevel -and $script:Config.debug.severityLevel.$Severity) {
            try {
                $severityIcon = $script:Config.debug.severityLevel.$Severity
            }
            catch {
                # Fallback to plain text if emoji causes issues
                $severityIcon = "[$Severity] -> "
            }
        }
        else {
            # Fallback: use severity name as text
            $severityIcon = "[$Severity] -> "
        }

        # Format log entry
        $logEntry = "[$timestamp] $severityIcon $Message"

        # Write to log file
        $logEntry | Out-File -FilePath $script:LogFilePath -Append -Encoding UTF8 -ErrorAction SilentlyContinue

        # Also write to console if requested
        if ($WriteConsole) {
            $consoleColor = switch ($Severity) {
                "INFO" { "Cyan" }
                "WARN" { "Yellow" }
                "ERROR" { "Red" }
                "DEBUG" { "Gray" }
                default { "White" }
            }
            Write-Host $logEntry -ForegroundColor $consoleColor
        }
    }
    catch {
        Write-Host "[ERROR] Failed to write log entry: $_" -ForegroundColor Red
    }
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

function Load-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "[ERROR] Configuration file not found: $Path"
        return $null
    }

    try {
        Write-Host "[INFO] Loading configuration from: $Path" -ForegroundColor Cyan
        $configJson = Get-Content -Path $Path -Raw -Encoding UTF8
        $config = $configJson | ConvertFrom-Json -ErrorAction Stop
        Write-Host "[OK] Configuration loaded successfully" -ForegroundColor Green
        return $config
    }
    catch {
        Write-Error "[ERROR] Configuration error: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# IMAGE PATH RESOLUTION & LOADING
# ============================================================================

function Resolve-ImagePath {
    param(
        [string]$ImageName,
        [string]$BasePath = "PNG"
    )
    
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $BasePath | Join-Path -ChildPath $ImageName
    
    if (Test-Path -Path $fullPath -PathType Leaf) {
        return (Resolve-Path -Path $fullPath).Path
    }
    
    Write-LogEntry -Severity "WARN" -Message "Image not found: $fullPath"
    return $null
}

function Load-BitmapImage {
    param(
        [string]$ImagePath,
        [string]$ImageName = "Unknown"
    )
    
    if ([string]::IsNullOrEmpty($ImagePath) -or -not (Test-Path $ImagePath)) {
        Write-LogEntry -Severity "WARN" -Message "Image file not found: $ImagePath"
        return $null
    }

    # Check cache first
    if ($script:ImageCache.ContainsKey($ImagePath)) {
        Write-LogEntry -Severity "DEBUG" -Message "Using cached image: $ImageName"
        return $script:ImageCache[$ImagePath]
    }
    
    try {
        Write-LogEntry -Severity "DEBUG" -Message "Loading image: $ImageName"
        
        $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapImage.BeginInit()
        $bitmapImage.UriSource = New-Object System.Uri($ImagePath, [System.UriKind]::Absolute)
        $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmapImage.EndInit()
        $bitmapImage.Freeze()
        
        # Cache the image
        $script:ImageCache[$ImagePath] = $bitmapImage
        
        Write-LogEntry -Severity "INFO" -Message "Image loaded successfully: $ImageName"
        return $bitmapImage
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "Error loading image: $_"
        return $null
    }
}

# ============================================================================
# XAML LOADING
# ============================================================================

function Load-XamlFile {
    param([string]$XamlFileName)

    try {
        $xamlPath = Join-Path -Path $PSScriptRoot -ChildPath "WPF" | Join-Path -ChildPath $XamlFileName
        
        if (-not (Test-Path $xamlPath)) {
            Write-LogEntry -Severity "ERROR" -Message "XAML file not found: $xamlPath" -WriteConsole
            return $null
        }

        Write-LogEntry -Severity "INFO" -Message "Loading XAML file: $XamlFileName" -WriteConsole
        
        $xamlContent = Get-Content -Path $xamlPath -Raw -Encoding UTF8
        
        Write-LogEntry -Severity "DEBUG" -Message "XAML file loaded: $XamlFileName"
        return $xamlContent
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "Error loading XAML file: $_" -WriteConsole
        return $null
    }
}

# ============================================================================
# WINDOW RESOURCES INITIALIZATION
# ============================================================================

function Initialize-WindowResources {
    param([pscustomobject]$Config)

    try {
        Write-LogEntry -Severity "INFO" -Message "Initializing window resources..." -WriteConsole
        
        # Resolve image paths
        $iconPath = Resolve-ImagePath -ImageName $Config.paths.windowIcon
        $bgPath = Resolve-ImagePath -ImageName $Config.paths.backgroundImage
        $closeButtonNormalPath = Resolve-ImagePath -ImageName $Config.paths.winaxnCloseImage
        $closeButtonHoverPath = Resolve-ImagePath -ImageName $Config.paths.winaxnCloseHover
        $appScreenPath = Resolve-ImagePath -ImageName $Config.paths.appscreenImage
        
        # Load images
        if ($iconPath) {
            $script:WindowIcon = Load-BitmapImage -ImagePath $iconPath -ImageName "Window Icon"
        }
        
        if ($bgPath) {
            $script:BackgroundImage = Load-BitmapImage -ImagePath $bgPath -ImageName "Background Image"
        }
        
        if ($closeButtonNormalPath) {
            $script:CloseButtonNormalImage = Load-BitmapImage -ImagePath $closeButtonNormalPath -ImageName "Close Button (Normal)"
        }
        
        if ($closeButtonHoverPath) {
            $script:CloseButtonHoverImage = Load-BitmapImage -ImagePath $closeButtonHoverPath -ImageName "Close Button (Hover)"
        }

        if ($appScreenPath) {
            $script:AppScreenImage = Load-BitmapImage -ImagePath $appScreenPath -ImageName "Application Screen"
        }
        
        # Validate critical resources
        if ($null -eq $script:BackgroundImage) {
            Write-LogEntry -Severity "ERROR" -Message "Background image failed to load" -WriteConsole
            return $false
        }
        
        if ($null -eq $script:CloseButtonNormalImage) {
            Write-LogEntry -Severity "ERROR" -Message "Close button normal image failed to load" -WriteConsole
            return $false
        }

        if ($null -eq $script:CloseButtonHoverImage) {
            Write-LogEntry -Severity "ERROR" -Message "Close button hover image failed to load" -WriteConsole
            return $false
        }
        
        Write-LogEntry -Severity "INFO" -Message "All resources loaded successfully" -WriteConsole
        return $true
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "Resource initialization failed: $_" -WriteConsole
        return $false
    }
}

# ============================================================================
# WPF UI INITIALIZATION
# ============================================================================

function Initialize-WPF {
    param([pscustomobject]$Config)

    try {
        Write-LogEntry -Severity "INFO" -Message "Initializing WPF UI..." -WriteConsole
        
        # Load XAML from external file
        $xamlString = Load-XamlFile -XamlFileName $Config.screen.mainwin
        
        if ([string]::IsNullOrEmpty($xamlString)) {
            Write-LogEntry -Severity "ERROR" -Message "Failed to load XAML content" -WriteConsole
            return $null
        }

        # Parse XAML
        $xamlXml = [xml]$xamlString
        $xmlReader = [System.Xml.XmlNodeReader]::new($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

        if ($null -eq $window) {
            Write-LogEntry -Severity "ERROR" -Message "XAML parsing returned null" -WriteConsole
            return $null
        }

        $script:WindowReference = $window
        Write-LogEntry -Severity "DEBUG" -Message "Window object created"

        # =====================================================================
        # GET UI ELEMENTS
        # =====================================================================
        
        $titleBar = $window.FindName("TitleBar")
        $closeButtonLabel = $window.FindName("CloseButton")
        $windowIconImg = $window.FindName("WindowIcon")
        $titleText = $window.FindName("TitleText")
        $versionText = $window.FindName("VersionText")
        $mainVersionText = $window.FindName("MainVersionText")
        $appScreenImg = $window.FindName("AppScreenImage")
        $bgImage = $window.FindName("BackgroundImage")

        Write-LogEntry -Severity "DEBUG" -Message "UI elements resolved from XAML"

        # =====================================================================
        # SET BACKGROUND
        # =====================================================================
        
        if ($bgImage -and $script:BackgroundImage) {
            $bgImage.Source = $script:BackgroundImage
            Write-LogEntry -Severity "INFO" -Message "Background image set"
        }

        # =====================================================================
        # SET WINDOW ICON
        # =====================================================================
        
        if ($windowIconImg -and $script:WindowIcon) {
            $windowIconImg.Source = $script:WindowIcon
            Write-LogEntry -Severity "INFO" -Message "Window icon set"
        }

        # =====================================================================
        # SET WINDOW TITLE & VERSION
        # =====================================================================
        
        if ($titleText) {
            $titleText.Text = $Config.app.name
            Write-LogEntry -Severity "DEBUG" -Message "Window title set: $($Config.app.name)"
        }

        if ($versionText) {
            $versionText.Text = "v$($Config.app.version)"
            Write-LogEntry -Severity "DEBUG" -Message "Version text set: v$($Config.app.version)"
        }

        if ($mainVersionText) {
            $mainVersionText.Text = "v$($Config.app.version)"
            Write-LogEntry -Severity "DEBUG" -Message "Main version text set: v$($Config.app.version)"
        }

        # =====================================================================
        # SET APP SCREEN IMAGE
        # =====================================================================
        
        if ($appScreenImg -and $script:AppScreenImage) {
            $appScreenImg.Source = $script:AppScreenImage
            Write-LogEntry -Severity "INFO" -Message "Application screen image set"
        }

        # =====================================================================
        # SETUP CLOSE BUTTON WITH HOVER EFFECT
        # =====================================================================
        
        if ($null -ne $closeButtonLabel) {
            try {
                # Get the image element inside the label
                $closeButtonImg = $closeButtonLabel.Content -as [System.Windows.Controls.Image]
                
                if ($null -ne $closeButtonImg) {
                    # Set initial image
                    $closeButtonImg.Source = $script:CloseButtonNormalImage
                    $closeButtonLabel.Cursor = [System.Windows.Input.Cursors]::Hand
                    
                    Write-LogEntry -Severity "DEBUG" -Message "Close button image set (normal)"
                    
                    # MouseEnter - Show hover image
                    $closeButtonLabel.Add_MouseEnter({
                        try {
                            $closeButtonImg.Source = $script:CloseButtonHoverImage
                            Write-LogEntry -Severity "DEBUG" -Message "Close button hover state activated"
                        }
                        catch {
                            Write-LogEntry -Severity "WARN" -Message "Error on mouse enter: $_"
                        }
                    })
                    
                    # MouseLeave - Show normal image
                    $closeButtonLabel.Add_MouseLeave({
                        try {
                            $closeButtonImg.Source = $script:CloseButtonNormalImage
                            Write-LogEntry -Severity "DEBUG" -Message "Close button hover state deactivated"
                        }
                        catch {
                            Write-LogEntry -Severity "WARN" -Message "Error on mouse leave: $_"
                        }
                    })
                    
                    # PreviewMouseLeftButtonDown - Close window
                    $closeButtonLabel.Add_PreviewMouseLeftButtonDown({
                        param($sender, $e)
                        try {
                            Write-LogEntry -Severity "INFO" -Message "Close button clicked - closing application" -WriteConsole
                            if ($script:WindowReference -ne $null) {
                                $script:WindowReference.Close()
                            }
                        }
                        catch {
                            Write-LogEntry -Severity "ERROR" -Message "Error closing window: $_"
                        }
                        $e.Handled = $true
                    })
                    
                    # Add tooltip
                    try {
                        $tooltip = New-Object System.Windows.Controls.ToolTip
                        $tooltip.Content = "Close Application"
                        $tooltip.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(64, 64, 64))
                        $tooltip.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
                        $tooltip.FontSize = 12
                        $tooltip.Padding = New-Object System.Windows.Thickness(8)
                        $closeButtonLabel.ToolTip = $tooltip
                        Write-LogEntry -Severity "DEBUG" -Message "Tooltip added to close button"
                    }
                    catch {
                        Write-LogEntry -Severity "WARN" -Message "Tooltip error: $_"
                    }
                    
                    Write-LogEntry -Severity "INFO" -Message "Close button with hover effect fully configured"
                }
                else {
                    Write-LogEntry -Severity "ERROR" -Message "Close button image element not found" -WriteConsole
                }
            }
            catch {
                Write-LogEntry -Severity "ERROR" -Message "Close button setup failed: $_" -WriteConsole
                return $null
            }
        }

        # =====================================================================
        # TITLE BAR DRAG FUNCTIONALITY
        # =====================================================================
        
        if ($null -ne $titleBar) {
            $titleBar.Add_MouseLeftButtonDown({
                if ($script:WindowReference -ne $null) {
                    try {
                        $script:WindowReference.DragMove()
                    }
                    catch {
                        Write-LogEntry -Severity "DEBUG" -Message "Drag operation triggered"
                    }
                }
            })
            Write-LogEntry -Severity "DEBUG" -Message "Title bar drag functionality enabled"
        }

        Write-LogEntry -Severity "INFO" -Message "WPF UI initialized successfully" -WriteConsole
        return $window
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "WPF initialization failed: $_" -WriteConsole
        Write-Error $_.ScriptStackTrace
        return $null
    }
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

try {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "[INFO] Starting ModernUI v1.00.02..." -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    $script:Config = Load-Configuration -Path $ConfigPath
    if ($null -eq $script:Config) {
        Write-Error "[ERROR] Configuration loading failed"
        exit 1
    }

    # Initialize logging
    Initialize-Logging -Config $script:Config

    Write-LogEntry -Severity "INFO" -Message "ModernUI v1.00.02 startup initiated" -WriteConsole
    Write-LogEntry -Severity "INFO" -Message "Application: $($script:Config.app.name) v$($script:Config.app.version)" -WriteConsole
    
    # Initialize window resources
    if (-not (Initialize-WindowResources -Config $script:Config)) {
        Write-LogEntry -Severity "ERROR" -Message "Resource initialization failed" -WriteConsole
        exit 1
    }

    Write-Host ""
    
    # Initialize WPF UI
    $window = Initialize-WPF -Config $script:Config
    
    if ($null -eq $window) {
        Write-LogEntry -Severity "ERROR" -Message "Window creation failed" -WriteConsole
        exit 1
    }
    
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "[OK] ModernUI v1.00.02 started successfully" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "   [OK] Window initialized" -ForegroundColor Green
    Write-Host "   [OK] Configuration loaded from config.json" -ForegroundColor Green
    Write-Host "   [OK] XAML loaded from external file" -ForegroundColor Green
    Write-Host "   [OK] All resources loaded" -ForegroundColor Green
    Write-Host "   [OK] Logging system active" -ForegroundColor Green
    Write-Host "   [OK] Close button with hover effect" -ForegroundColor Green
    Write-Host "   [OK] Frameless window design" -ForegroundColor Green
    Write-Host "   [OK] Production-ready version" -ForegroundColor Green
    if ($script:LogEnabled) {
        Write-Host "   [OK] Log file: $($script:LogFilePath)" -ForegroundColor Green
    }
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    
    Write-LogEntry -Severity "INFO" -Message "Window displayed - waiting for user interaction" -WriteConsole
    $window.ShowDialog() | Out-Null
    
    Write-LogEntry -Severity "INFO" -Message "Application closed successfully" -WriteConsole
    Write-Host "[OK] Application closed" -ForegroundColor Green
}
catch {
    Write-LogEntry -Severity "ERROR" -Message "Fatal error: $_" -WriteConsole
    Write-Error $_.ScriptStackTrace
    exit 1
}
