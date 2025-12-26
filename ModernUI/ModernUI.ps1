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
    .\ ModernUI.ps1
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
        Checks for required directories (ModernUI, ModernUI\PNG) and
        verifies that essential files can be found.
    #>
    
    Write-Host "[ModernUI] Umgebungsprüfung wird durchgeführt..." -ForegroundColor Cyan
    
    # Check for PNG directory
    $pngPath = Join-Path $Global:ScriptPath "PNG"
    if (-not (Test-Path $pngPath -PathType Container)) {
        Write-Warning "[ModernUI] PNG-Verzeichnis nicht gefunden: $pngPath"
        return $false
    }
    
    Write-Host "[ModernUI] ✓ Umgebung ist korrekt" -ForegroundColor Green
    return $true
}
#endregion Environment Checks

#region Configuration Loading
function Load-ModernUIConfig {
    <#
    .SYNOPSIS
        Loads the config.json file into the global configuration variable.
        
    .DESCRIPTION
        Reads config.json and parses JSON content into hashtable.
        Sets Global:ModernUI_Config for application-wide access.
        
    .OUTPUTS
        Boolean. Returns $true if successful, $false otherwise.
    #>
    
    Write-Host "[ModernUI] Konfiguration wird geladen..." -ForegroundColor Cyan
    
    $configPath = Join-Path $Global:ScriptPath "config.json"
    
    if (-not (Test-Path $configPath -PathType Leaf)) {
        Write-Error "[ModernUI] config.json nicht gefunden: $configPath"
        return $false
    }
    
    try {
        $jsonContent = Get-Content $configPath -Raw | ConvertFrom-Json
        
        # Convert PSObject to Hashtable for easier manipulation
        $Global:ModernUI_Config = ConvertTo-Hashtable $jsonContent
        
        Write-Host "[ModernUI] ✓ Konfiguration erfolgreich geladen" -ForegroundColor Green
        Write-Host "  - App Name: $($Global:ModernUI_Config['appname'])"
        Write-Host "  - Version: $($Global:ModernUI_Config['appver'])"
        Write-Host "  - Developer: $($Global:ModernUI_Config['devname'])"
        
        return $true
    } 
    catch {
        Write-Error "[ModernUI] Fehler beim Laden von config.json: $_"
        return $false
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts a PSObject to a Hashtable recursively.
    #>
    
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    
    if ($null -eq $InputObject) { return $null }
    
    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject
    }
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @()
        foreach ($object in $InputObject) {
            $collection += ConvertTo-Hashtable $object
        }
        return $collection
    }
    
    $hash = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        $hash[$property.Name] = ConvertTo-Hashtable $property.Value
    }
    
    return $hash
}
#endregion Configuration Loading

#region XAML Loading
function Load-ModernUIXAML {
    <#
    .SYNOPSIS
        Loads and processes the XAML file with configuration data.
        
    .DESCRIPTION
        Reads ModernUI.xaml and resolves image paths from config.
        Initializes the WPF window and sets up event handlers.
        
    .OUTPUTS
        System.Windows.Window. Returns the loaded window object.
    #>
    
    Write-Host "[ModernUI] XAML wird geladen..." -ForegroundColor Cyan
    
    $xamlPath = Join-Path $Global:ScriptPath "ModernUI.xaml"
    
    if (-not (Test-Path $xamlPath -PathType Leaf)) {
        Write-Error "[ModernUI] ModernUI.xaml nicht gefunden: $xamlPath"
        return $null
    }
    
    try {
        $xamlContent = Get-Content $xamlPath -Raw
        $Global:ModernUI_XAML = $xamlContent
        
        # Create XmlNamespaceManager for XAML parsing
        $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
        # Load images from config
        $windowPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.window
        $iconPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appicon
        $closeNormalPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appclose.normal
        $closeHoverPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.appclose.hover
        
        # Set Background Image
        if (Test-Path $windowPath) {
            $bgImage = $window.FindName("BackgroundImage")
            if ($null -ne $bgImage) {
                $bgImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$windowPath)
            }
        }
        
        # Set App Icon
        if (Test-Path $iconPath) {
            $appIcon = $window.FindName("AppIcon")
            if ($null -ne $appIcon) {
                $appIcon.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$iconPath)
            }
        }
        
        # Set Close Button Images
        if (Test-Path $closeNormalPath) {
            $closeButton = $window.FindName("CloseButton")
            $closeButtonImage = $window.FindName("CloseButtonImage")
            if ($null -ne $closeButtonImage) {
                $closeButtonImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$closeNormalPath)
                
                # Add Hover/Leave event handlers for close button
                $closeButton.Add_MouseEnter({
                    if (Test-Path $closeHoverPath) {
                        $_.Source.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$closeHoverPath)
                    }
                })
                
                $closeButton.Add_MouseLeave({
                    if (Test-Path $closeNormalPath) {
                        $_.Source.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$closeNormalPath)
                    }
                })
            }
        }
        
        Write-Host "[ModernUI] ✓ XAML erfolgreich geladen" -ForegroundColor Green
        
        return $window
    }
    catch {
        Write-Error "[ModernUI] Fehler beim Laden von ModernUI.xaml: $_"
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
        Sets up event handlers for:
        - Window dragging (MouseLeftButtonDown on TitleBar)
        - Close button functionality
        - Window lifecycle events
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )
    
    Write-Host "[ModernUI] Event-Handler werden registriert..." -ForegroundColor Cyan
    
    # Window Drag Handler
    $titleBar = $Window.FindName("TitleBar")
    if ($null -ne $titleBar) {
        $titleBar.Add_MouseLeftButtonDown({
            if ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                return
            }
            try {
                $Window.DragMove()
            }
            catch {
                Write-Verbose "[ModernUI] DragMove fehlgeschlagen: $_"
            }
        })
    }
    
    # Close Button Handler
    $closeButton = $Window.FindName("CloseButton")
    if ($null -ne $closeButton) {
        $closeButton.Add_Click({
            Invoke-AppExit
        })
    }
    
    # Window Closed Event
    $Window.Add_Closed({
        $Global:ModernUI_State.IsRunning = $false
        Write-Host "[ModernUI] Fenster wurde geschlossen" -ForegroundColor Yellow
    })
    
    Write-Host "[ModernUI] ✓ Event-Handler registriert" -ForegroundColor Green
}
#endregion Event Handlers

#region Application Control
function Invoke-AppExit {
    <#
    .SYNOPSIS
        Cleanly exits the application.
        
    .DESCRIPTION
        Centralised exit function ensuring proper cleanup and resource disposal.
        Called by Close button or application termination.
    #>
    
    Write-Host "[ModernUI] Anwendung wird beendet..." -ForegroundColor Yellow
    
    if ($null -ne $Global:ModernUI_State.Window) {
        try {
            $Global:ModernUI_State.Window.Close()
        }
        catch {
            Write-Warning "[ModernUI] Fehler beim Schließen des Fensters: $_"
        }
    }
    
    $Global:ModernUI_State.IsRunning = $false
    
    # Cleanup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "[ModernUI] ✓ Anwendung beendet" -ForegroundColor Green
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
    
    Write-Host ""`n[ModernUI] Framework wird initialisiert...`n" -ForegroundColor Magenta
    
    # Load Configuration
    if (-not (Load-ModernUIConfig)) {
        Write-Error "[ModernUI] Konfiguration konnte nicht geladen werden"
        return $false
    }
    
    # Load XAML
    $window = Load-ModernUIXAML
    if ($null -eq $window) {
        Write-Error "[ModernUI] XAML konnte nicht geladen werden"
        return $false
    }
    
    $Global:ModernUI_State.Window = $window
    
    # Register Event Handlers
    Register-EventHandlers -Window $window
    
    Write-Host "[ModernUI] ✓ Framework initialisiert`n" -ForegroundColor Green
    
    return $true
}
#endregion Application Control

#region Main Orchestration
function Invoke-RunMainApp {
    <#
    .SYNOPSIS
        Main application orchestration function.
        
    .DESCRIPTION
        Central entry point that coordinates all application initialization
        and execution.
    #>
    
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host "ModernUI Framework - Frameless WPF Application" -ForegroundColor Cyan
    Write-Host ("="*60) + "`n" -ForegroundColor Cyan
    
    # Environment Check
    if (-not (Test-ModernUIEnvironment)) {
        Write-Error "[ModernUI] Umgebungsprüfung fehlgeschlagen"
        return
    }
    
    # Initialize Framework
    if (-not (Initialize-ModernUI)) {
        Write-Error "[ModernUI] Initialisierung fehlgeschlagen"
        return
    }
    
    # Show Window
    $Global:ModernUI_State.IsRunning = $true
    Write-Host "[ModernUI] Fenster wird angezeigt...\n" -ForegroundColor Cyan
    
    try {
        $null = $Global:ModernUI_State.Window.ShowDialog()
    }
    catch {
        Write-Error "[ModernUI] Fehler beim Anzeigen des Fensters: $_"
    }
    finally {
        Invoke-AppExit
    }
}
#endregion Main Orchestration

#region Script Execution
if (-not (Test-ModernUIEnvironment)) {
    Write-Error "[ModernUI] Umgebungsprüfung fehlgeschlagen. Beende..."
    exit 1
}

Invoke-RunMainApp
#endregion Script Execution
