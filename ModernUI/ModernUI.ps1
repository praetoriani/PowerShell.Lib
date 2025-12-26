#region Header
<#
.SYNOPSIS
    ModernUI - Modern GUI Framework for PowerShell
    
.DESCRIPTION
    Frameless WPF-based GUI framework with PNG background overlay support.
    Provides a modern user interface experience with draggable windows and smooth controls.
    
.NOTES
    Author:     Praetoriani
    Version:    1.00.00
    Date:       2025-12-26
    Website:    https://github.com/praetoriani
    
.EXAMPLE
    .\ModernUI.ps1
#>
#endregion Header

#region Global Variables
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsBase') | Out-Null

# Global Configuration Variable
[hashtable]$Global:ModernUI_Config = @{}

# Global Application State
[hashtable]$Global:ModernUI_State = @{
    IsRunning = $false
    Window = $null
    LastMousePos = @{X = 0; Y = 0}
    IsDragging = $false
}

# Global XAML Variable
[string]$Global:ModernUI_XAML = $null

# Script Path for relative file references
[string]$Global:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

#endregion Global Variables

#region Environment Checks
function Test-ModernUIEnvironment {
    <#
    .SYNOPSIS
        Validates that all required directories and prerequisites exist.
        
    .DESCRIPTION
        Checks for required directories and verifies that essential files can be found.
    #>
    
    Write-Host "[ModernUI] Environment check in progress..." -ForegroundColor Cyan
    
    $pngPath = Join-Path $Global:ScriptPath "PNG"
    if (-not (Test-Path $pngPath -PathType Container)) {
        Write-Warning "[ModernUI] PNG directory not found: $pngPath"
        return $false
    }
    
    Write-Host "[ModernUI] OK - Environment is correct" -ForegroundColor Green
    return $true
}
#endregion Environment Checks

#region Configuration Loading
function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts a PSObject to a Hashtable recursively.
        
    .DESCRIPTION
        Recursively converts PSCustomObject to hashtable.
        Handles arrays and nested objects.
    #>
    
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    
    process {
        if ($null -eq $InputObject) {
            return $null
        }
        
        if ($InputObject -is [System.Collections.IDictionary]) {
            return $InputObject
        }
        
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @()
            foreach ($object in $InputObject) {
                $collection += ConvertTo-Hashtable -InputObject $object
            }
            return $collection
        }
        
        if ($InputObject -is [object] -and $InputObject.GetType().Name -eq 'PSCustomObject') {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            return $hash
        }
        
        return $InputObject
    }
}

function Load-ModernUIConfig {
    <#
    .SYNOPSIS
        Loads the config.json file into the global configuration variable.
        
    .DESCRIPTION
        Reads config.json and parses JSON content into hashtable.
        Sets Global:ModernUI_Config for application-wide access.
        
    .OUTPUTS
        Boolean. Returns true if successful, false otherwise.
    #>
    
    Write-Host "[ModernUI] Configuration is loading..." -ForegroundColor Cyan
    
    $configPath = Join-Path $Global:ScriptPath "config.json"
    
    if (-not (Test-Path $configPath -PathType Leaf)) {
        Write-Error "[ModernUI] config.json not found: $configPath"
        return $false
    }
    
    try {
        $jsonContent = Get-Content $configPath -Raw | ConvertFrom-Json
        $Global:ModernUI_Config = ConvertTo-Hashtable -InputObject $jsonContent
        
        Write-Host "[ModernUI] OK - Configuration loaded successfully" -ForegroundColor Green
        Write-Host "  - App Name: $($Global:ModernUI_Config['appname'])"
        Write-Host "  - Version: $($Global:ModernUI_Config['appver'])"
        Write-Host "  - Developer: $($Global:ModernUI_Config['devname'])"
        
        return $true
    }
    catch {
        Write-Error "[ModernUI] Error loading config.json: $_"
        return $false
    }
}
#endregion Configuration Loading

#region XAML Loading
function Load-ModernUIXAML {
    <#
    .SYNOPSIS
        Loads and processes the XAML file with configuration data.
        
    .DESCRIPTION
        Reads ModernUI.xaml and resolves image paths from config.
        Initializes the WPF window and sets up image sources.
        
    .OUTPUTS
        System.Windows.Window. Returns the loaded window object.
    #>
    
    Write-Host "[ModernUI] XAML is loading..." -ForegroundColor Cyan
    
    $xamlPath = Join-Path $Global:ScriptPath "ModernUI.xaml"
    
    if (-not (Test-Path $xamlPath -PathType Leaf)) {
        Write-Error "[ModernUI] ModernUI.xaml not found: $xamlPath"
        return $null
    }
    
    try {
        $xamlContent = Get-Content $xamlPath -Raw
        $Global:ModernUI_XAML = $xamlContent
        
        $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
        if ($null -eq $window) {
            Write-Error "[ModernUI] Failed to load XAML - window is null"
            return $null
        }
        
        # Load images from config - resolve absolute paths
        $windowBg = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.window
        $appIcon = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appicon
        $closeNormal = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appclose.normal
        $closeHover = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appclose.hover
        
        # Set Background Image
        if (Test-Path $windowBg -PathType Leaf) {
            $bgImage = $window.FindName("BackgroundImage")
            if ($null -ne $bgImage) {
                $bgImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$windowBg)
            }
        } else {
            Write-Warning "[ModernUI] Background image not found: $windowBg"
        }
        
        # Set App Icon
        if (Test-Path $appIcon -PathType Leaf) {
            $appIconControl = $window.FindName("AppIcon")
            if ($null -ne $appIconControl) {
                $appIconControl.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$appIcon)
            }
        } else {
            Write-Warning "[ModernUI] App icon not found: $appIcon"
        }
        
        # Set Close Button Image
        if (Test-Path $closeNormal -PathType Leaf) {
            $closeButton = $window.FindName("CloseButton")
            $closeButtonImage = $window.FindName("CloseButtonImage")
            if ($null -ne $closeButtonImage -and $null -ne $closeButton) {
                $closeButtonImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$closeNormal)
                
                # Store paths in button tag for later hover effects
                $closeButton.Tag = @{
                    NormalPath = $closeNormal
                    HoverPath = $closeHover
                    ImageControl = $closeButtonImage
                }
            }
        } else {
            Write-Warning "[ModernUI] Close button normal image not found: $closeNormal"
        }
        
        Write-Host "[ModernUI] OK - XAML loaded successfully" -ForegroundColor Green
        
        return $window
    }
    catch {
        Write-Error "[ModernUI] Error loading ModernUI.xaml: $_"
        return $null
    }
}
#endregion XAML Loading

#region Event Handlers
function Register-EventHandlers {
    <#
    .SYNOPSIS
        Registers all event handlers for the application window.
        
    .DESCRIPTION
        Sets up event handlers for window dragging, close button, and lifecycle events.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )
    
    Write-Host "[ModernUI] Event handlers are being registered..." -ForegroundColor Cyan
    
    try {
        # Store window reference in script scope for use in event handlers
        $script:WindowReference = $Window
        
        # Store close button references for hover effects
        $script:CloseButtonImage = $Window.FindName("CloseButtonImage")
        $script:CloseButtonControl = $Window.FindName("CloseButton")
        
        # Window Drag Handler - find TitleBar border element
        $titleBar = $Window.FindName("TitleBar")
        if ($null -ne $titleBar) {
            $titleBar.Add_MouseLeftButtonDown({
                param($sender, $e)
                try {
                    if ($script:WindowReference -ne $null) {
                        $script:WindowReference.DragMove()
                    }
                }
                catch {
                    Write-Verbose "[ModernUI] DragMove error: $_"
                }
            })
            
            Write-Host "  - TitleBar drag enabled" -ForegroundColor Green
        } else {
            Write-Warning "[ModernUI] TitleBar element not found in XAML"
        }
        
        # Close Button Handler
        $closeButton = $Window.FindName("CloseButton")
        if ($null -ne $closeButton) {
            $closeButton.Add_Click({
                param($sender, $e)
                Invoke-AppExit
            })
            Write-Host "  - Close button click handler enabled" -ForegroundColor Green
            
            # Hover effects for close button image - using direct image swap
            if ($null -ne $script:CloseButtonImage -and $closeButton.Tag) {
                # Mouse Enter - swap to hover image
                $closeButton.Add_MouseEnter({
                    param($sender, $e)
                    try {
                        if ($sender.Tag.HoverPath -and (Test-Path $sender.Tag.HoverPath -PathType Leaf)) {
                            $hoverBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
                            $hoverBitmap.BeginInit()
                            $hoverBitmap.UriSource = [uri]$sender.Tag.HoverPath
                            $hoverBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                            $hoverBitmap.EndInit()
                            $hoverBitmap.Freeze()
                            $sender.Tag.ImageControl.Source = $hoverBitmap
                        }
                    }
                    catch {
                        Write-Verbose "[ModernUI] Error setting hover image: $_"
                    }
                })
                
                # Mouse Leave - swap back to normal image
                $closeButton.Add_MouseLeave({
                    param($sender, $e)
                    try {
                        if ($sender.Tag.NormalPath -and (Test-Path $sender.Tag.NormalPath -PathType Leaf)) {
                            $normalBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
                            $normalBitmap.BeginInit()
                            $normalBitmap.UriSource = [uri]$sender.Tag.NormalPath
                            $normalBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                            $normalBitmap.EndInit()
                            $normalBitmap.Freeze()
                            $sender.Tag.ImageControl.Source = $normalBitmap
                        }
                    }
                    catch {
                        Write-Verbose "[ModernUI] Error setting normal image: $_"
                    }
                })
                Write-Host "  - Close button hover effects enabled" -ForegroundColor Green
            }
        } else {
            Write-Warning "[ModernUI] CloseButton element not found in XAML"
        }
        
        # Window Closed Event
        $Window.Add_Closed({
            $Global:ModernUI_State.IsRunning = $false
            Write-Host "[ModernUI] Window closed" -ForegroundColor Yellow
        })
        
        Write-Host "[ModernUI] OK - Event handlers registered" -ForegroundColor Green
    }
    catch {
        Write-Error "[ModernUI] Error registering event handlers: $_"
    }
}
#endregion Event Handlers

#region Application Control
function Invoke-AppExit {
    <#
    .SYNOPSIS
        Cleanly exits the application.
        
    .DESCRIPTION
        Centralized exit function ensuring proper cleanup and resource disposal.
        Called by Close button or application termination.
    #>
    
    Write-Host "[ModernUI] Application is shutting down..." -ForegroundColor Yellow
    
    if ($null -ne $Global:ModernUI_State.Window) {
        try {
            $Global:ModernUI_State.Window.Close()
        }
        catch {
            Write-Warning "[ModernUI] Error closing window: $_"
        }
    }
    
    $Global:ModernUI_State.IsRunning = $false
    
    # Cleanup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "[ModernUI] OK - Application terminated" -ForegroundColor Green
    exit 0
}

function Initialize-ModernUI {
    <#
    .SYNOPSIS
        Initializes the ModernUI framework.
        
    .DESCRIPTION
        Sets up configuration, XAML, and event handlers.
        Prepares application for execution.
    #>
    
    Write-Host "`n[ModernUI] Framework initialization...`n" -ForegroundColor Magenta
    
    # Load Configuration
    if (-not (Load-ModernUIConfig)) {
        Write-Error "[ModernUI] Configuration could not be loaded"
        return $false
    }
    
    # Load XAML
    $window = Load-ModernUIXAML
    if ($null -eq $window) {
        Write-Error "[ModernUI] XAML could not be loaded"
        return $false
    }
    
    $Global:ModernUI_State.Window = $window
    
    # Register Event Handlers
    Register-EventHandlers -Window $window
    
    Write-Host "[ModernUI] OK - Framework initialized`n" -ForegroundColor Green
    
    return $true
}
#endregion Application Control

#region Main Orchestration
function Invoke-RunMainApp {
    <#
    .SYNOPSIS
        Main application orchestration function.
        
    .DESCRIPTION
        Central entry point that coordinates all application initialization and execution.
    #>
    
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host "ModernUI Framework - Frameless WPF Application" -ForegroundColor Cyan
    Write-Host ("="*60) + "`n" -ForegroundColor Cyan
    
    # Environment Check
    if (-not (Test-ModernUIEnvironment)) {
        Write-Error "[ModernUI] Environment check failed"
        return
    }
    
    # Initialize Framework
    if (-not (Initialize-ModernUI)) {
        Write-Error "[ModernUI] Initialization failed"
        return
    }
    
    # Show Window
    $Global:ModernUI_State.IsRunning = $true
    Write-Host "[ModernUI] Window is being displayed...`n" -ForegroundColor Cyan
    
    try {
        $null = $Global:ModernUI_State.Window.ShowDialog()
    }
    catch {
        Write-Error "[ModernUI] Error displaying window: $_"
    }
    finally {
        Invoke-AppExit
    }
}
#endregion Main Orchestration

#region Script Execution
if (-not (Test-ModernUIEnvironment)) {
    Write-Error "[ModernUI] Environment check failed. Exiting..."
    exit 1
}

Invoke-RunMainApp
#endregion Script Execution
