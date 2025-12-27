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
$script:CloseButtonImageElement = $null

# ============================================================================
# ASSEMBLY LOADING
# ============================================================================

try {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationCore")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("WindowsBase")
}
catch {
    Write-Host "[ERROR] Assembly loading failed: $_" -ForegroundColor Red
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
            
            Write-LogEntry -Severity "INFO" -Message "Logging initialized - $logFileName"
        }
        else {
            Write-LogEntry -Severity "INFO" -Message "Logging disabled in config"
        }
    }
    catch {
        Write-Host "[ERROR] Logging initialization failed: $_" -ForegroundColor Red
    }
}

function Write-LogEntry {
    param(
        [string]$Severity = "INFO",
        [string]$Message = ""
    )

    try {
        if (-not $script:LogEnabled -or [string]::IsNullOrEmpty($script:LogFilePath)) {
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
                $severityIcon = "[$Severity] -> "
            }
        }
        else {
            $severityIcon = "[$Severity] -> "
        }

        # Format log entry
        $logEntry = "[$timestamp] $severityIcon $Message"

        # Write to log file
        $logEntry | Out-File -FilePath $script:LogFilePath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail - don't even write errors to console
    }
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

function Load-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "[ERROR] Configuration file not found: $Path" -ForegroundColor Red
        return $null
    }

    try {
        $configJson = Get-Content -Path $Path -Raw -Encoding UTF8
        $config = $configJson | ConvertFrom-Json -ErrorAction Stop
        return $config
    }
    catch {
        Write-Host "[ERROR] Configuration error: $($_.Exception.Message)" -ForegroundColor Red
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
            Write-LogEntry -Severity "ERROR" -Message "XAML file not found: $xamlPath"
            return $null
        }

        Write-LogEntry -Severity "INFO" -Message "Loading XAML file: $XamlFileName"
        
        $xamlContent = Get-Content -Path $xamlPath -Raw -Encoding UTF8
        
        Write-LogEntry -Severity "DEBUG" -Message "XAML file loaded: $XamlFileName"
        return $xamlContent
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "Error loading XAML file: $_"
        return $null
    }
}

# ============================================================================
# WINDOW RESOURCES INITIALIZATION
# ============================================================================

function Initialize-WindowResources {
    param([pscustomobject]$Config)

    try {
        Write-LogEntry -Severity "INFO" -Message "Initializing window resources..."
        
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
            Write-LogEntry -Severity "ERROR" -Message "Background image failed to load"
            return $false
        }
        
        if ($null -eq $script:CloseButtonNormalImage) {
            Write-LogEntry -Severity "ERROR" -Message "Close button normal image failed to load"
            return $false
        }

        if ($null -eq $script:CloseButtonHoverImage) {
            Write-LogEntry -Severity "ERROR" -Message "Close button hover image failed to load"
            return $false
        }
        
        Write-LogEntry -Severity "INFO" -Message "All resources loaded successfully"
        return $true
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "Resource initialization failed: $_"
        return $false
    }
}

# ============================================================================
# WPF UI INITIALIZATION
# ============================================================================

function Initialize-WPF {
    param([pscustomobject]$Config)

    try {
        Write-LogEntry -Severity "INFO" -Message "Initializing WPF UI..."
        
        # Load XAML from external file
        $xamlString = Load-XamlFile -XamlFileName $Config.screen.mainwin
        
        if ([string]::IsNullOrEmpty($xamlString)) {
            Write-LogEntry -Severity "ERROR" -Message "Failed to load XAML content"
            return $null
        }

        # Parse XAML
        $xamlXml = [xml]$xamlString
        $xmlReader = [System.Xml.XmlNodeReader]::new($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

        if ($null -eq $window) {
            Write-LogEntry -Severity "ERROR" -Message "XAML parsing returned null"
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
        $closeButtonImg = $window.FindName("CloseButtonImage")

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
        
        if ($null -ne $closeButtonLabel -and $null -ne $closeButtonImg) {
            try {
                # Store reference to image element for use in event handlers
                $script:CloseButtonImageElement = $closeButtonImg
                
                # Set initial image
                $closeButtonImg.Source = $script:CloseButtonNormalImage
                $closeButtonLabel.Cursor = [System.Windows.Input.Cursors]::Hand
                
                Write-LogEntry -Severity "DEBUG" -Message "Close button image set (normal)"
                
                # MouseEnter - Show hover image
                $closeButtonLabel.Add_MouseEnter({
                    try {
                        if ($null -ne $script:CloseButtonImageElement) {
                            $script:CloseButtonImageElement.Source = $script:CloseButtonHoverImage
                            Write-LogEntry -Severity "DEBUG" -Message "Close button hover state activated"
                        }
                    }
                    catch {
                        Write-LogEntry -Severity "WARN" -Message "Error on mouse enter: $_"
                    }
                })
                
                # MouseLeave - Show normal image
                $closeButtonLabel.Add_MouseLeave({
                    try {
                        if ($null -ne $script:CloseButtonImageElement) {
                            $script:CloseButtonImageElement.Source = $script:CloseButtonNormalImage
                            Write-LogEntry -Severity "DEBUG" -Message "Close button hover state deactivated"
                        }
                    }
                    catch {
                        Write-LogEntry -Severity "WARN" -Message "Error on mouse leave: $_"
                    }
                })
                
                # PreviewMouseLeftButtonDown - Close window
                $closeButtonLabel.Add_PreviewMouseLeftButtonDown({
                    param($sender, $e)
                    try {
                        Write-LogEntry -Severity "INFO" -Message "Close button clicked - closing application"
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
            catch {
                Write-LogEntry -Severity "ERROR" -Message "Close button setup failed: $_"
                return $null
            }
        }
        else {
            if ($null -eq $closeButtonLabel) {
                Write-LogEntry -Severity "ERROR" -Message "Close button Label element not found in XAML"
            }
            if ($null -eq $closeButtonImg) {
                Write-LogEntry -Severity "ERROR" -Message "Close button Image element not found in XAML"
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

        Write-LogEntry -Severity "INFO" -Message "WPF UI initialized successfully"
        return $window
    }
    catch {
        Write-LogEntry -Severity "ERROR" -Message "WPF initialization failed: $_"
        Write-Host "[ERROR] WPF initialization failed: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

try {
    # Load configuration (early to set up logging)
    $script:Config = Load-Configuration -Path $ConfigPath
    if ($null -eq $script:Config) {
        Write-Host "[FATAL] Configuration loading failed" -ForegroundColor Red
        exit 1
    }

    # Initialize logging
    Initialize-Logging -Config $script:Config

    # Start logging the application startup
    Write-LogEntry -Severity "INFO" -Message "ModernUI v1.00.02 startup initiated"
    Write-LogEntry -Severity "INFO" -Message "Application: $($script:Config.app.name) v$($script:Config.app.version)"
    
    # Initialize window resources
    if (-not (Initialize-WindowResources -Config $script:Config)) {
        Write-LogEntry -Severity "ERROR" -Message "Resource initialization failed"
        Write-Host "[FATAL] Resource initialization failed" -ForegroundColor Red
        exit 1
    }
    
    # Initialize WPF UI
    $window = Initialize-WPF -Config $script:Config
    
    if ($null -eq $window) {
        Write-LogEntry -Severity "ERROR" -Message "Window creation failed"
        Write-Host "[FATAL] Window creation failed" -ForegroundColor Red
        exit 1
    }
    
    # Log that window is displayed
    Write-LogEntry -Severity "INFO" -Message "Window displayed - waiting for user interaction"
    
    # Show the window (blocking call until closed)
    $window.ShowDialog() | Out-Null
    
    # Log application closure
    Write-LogEntry -Severity "INFO" -Message "Application closed successfully"
}
catch {
    Write-LogEntry -Severity "ERROR" -Message "Fatal error: $_"
    Write-Host "[FATAL ERROR] $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
