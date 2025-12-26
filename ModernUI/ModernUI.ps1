<#
.SYNOPSIS
    ModernUI v1.00.00 - Modern UI Framework for PowerShell WPF

.DESCRIPTION
    Eine moderne Benutzeroberflaeche fuer PowerShell mit WPF, basierend auf 
    Microsoft Windows 11 Modern UI Design Principles.

.AUTHOR
    Marc Sczepanski (praetoriani)

.VERSION
    1.00.00 (Stable Release)
    - Fenster verschiebbar
    - Hover-Effekte fuer Close Button
    - Korrekte Titelleisten-Positionierung
    - Config-driven Image Loading
    - Rahmenloses Fenster Design

.NOTES
    Requires: PowerShell 7.0+, .NET Framework 4.8+
    GitHub: https://github.com/praetoriani/PowerShell.Lib
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config.json"
)

# ============================================================================
# ASSEMBLY LOADING (CRITICAL FOR WPF)
# ============================================================================

try {
    # Load required WPF and .NET assemblies
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("PresentationCore")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("WindowsBase")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Xaml")
}
catch {
    Write-Error "[ERROR] Fehler beim Laden der erforderlichen Assemblies: $_"
    exit 1
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

function Load-Configuration {
    <#
    .SYNOPSIS
        Laedt die Konfiguration aus config.json und expandiert Variablen
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Config nicht gefunden: $Path"
        return $null
    }

    try {
        # Lese config.json
        $configJson = Get-Content $Path -Raw
        
        # Expandiere $PSScriptRoot Variable in der Config
        $configJson = $configJson -replace '\$PSScriptRoot', $PSScriptRoot
        
        # Parse als JSON
        $config = $configJson | ConvertFrom-Json
        
        Write-Host "[OK] Config geladen" -ForegroundColor Green
        Write-Host "   - Pfad: $Path" -ForegroundColor Gray
        Write-Host "   - Icon: $($config.windowIcon)" -ForegroundColor Gray
        
        return $config
    }
    catch {
        Write-Error "[ERROR] Fehler beim Laden der Config: $_"
        return $null
    }
}

# ============================================================================
# IMAGE LOADING HELPER
# ============================================================================

function Load-BitmapImage {
    <#
    .SYNOPSIS
        Laedt ein Bild mit korrektem URI Format
    #>
    param(
        [string]$ImagePath,
        [string]$ImageName = "Unknown"
    )
    
    if ([string]::IsNullOrEmpty($ImagePath)) {
        Write-Warning "[WARN] Bildpfad ist leer fuer $ImageName"
        return $null
    }
    
    if (-not (Test-Path $ImagePath)) {
        Write-Warning "[WARN] Bilddatei nicht gefunden: $ImagePath"
        return $null
    }
    
    try {
        Write-Host "[INFO] Lade Bild: $ImageName von $ImagePath" -ForegroundColor Gray
        
        $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapImage.BeginInit()
        $bitmapImage.UriSource = New-Object System.Uri($ImagePath)
        $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmapImage.EndInit()
        $bitmapImage.Freeze()  # Freeze fuer Cross-Thread Zugriff
        
        Write-Host "[OK] Bild geladen: $ImageName" -ForegroundColor Green
        return $bitmapImage
    }
    catch {
        Write-Warning "[WARN] Fehler beim Laden des Bildes $ImageName : $_"
        return $null
    }
}

# ============================================================================
# XAML DEFINITION (FRAMELESS WINDOW)
# ============================================================================

$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="ModernUI v1.00.00"
    Height="600"
    Width="800"
    Background="#F5F5F5"
    WindowStartupLocation="CenterScreen"
    WindowStyle="None"
    AllowsTransparency="True"
    x:Name="MainWindow">

    <Grid Background="#FAFAFA">
        <Grid.RowDefinitions>
            <RowDefinition Height="40" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <!-- TITLE BAR -->
        <Border x:Name="TitleBar" Grid.Row="0" Background="#FFFFFF" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>

                <!-- Window Icon (Left) -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0,0,0">
                    <Image 
                        x:Name="WindowIcon" 
                        Width="24" 
                        Height="24" 
                        Margin="0,0,8,0"
                        VerticalAlignment="Center"
                        HorizontalAlignment="Left" />
                </StackPanel>

                <!-- Window Title (Next to Icon) -->
                <TextBlock 
                    x:Name="TitleText"
                    Text="ModernUI v1.00.00"
                    VerticalAlignment="Center"
                    HorizontalAlignment="Left"
                    Margin="40,0,0,0"
                    FontSize="14"
                    Foreground="#333333"
                    FontWeight="SemiBold" />

                <!-- Spacer -->
                <Border Grid.Column="1" />

                <!-- Window Controls (Right) -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,8,0">
                    <!-- Close Button -->
                    <Button 
                        x:Name="CloseButton" 
                        Width="32" 
                        Height="32" 
                        Background="Transparent" 
                        BorderThickness="0"
                        Cursor="Arrow"
                        HorizontalContentAlignment="Center" 
                        VerticalContentAlignment="Center">
                        <Image 
                            x:Name="CloseButtonImage" 
                            Width="16" 
                            Height="16" />
                    </Button>
                </StackPanel>
            </Grid>
        </Border>

        <!-- MAIN CONTENT AREA -->
        <Grid Grid.Row="1" Background="#FAFAFA">
            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                <TextBlock 
                    Text="ModernUI v1.00.00" 
                    FontSize="32" 
                    FontWeight="Bold" 
                    Foreground="#333333"
                    TextAlignment="Center"
                    Margin="0,0,0,16" />
                <TextBlock 
                    Text="Modern UI Framework fuer PowerShell WPF"
                    FontSize="16"
                    Foreground="#666666"
                    TextAlignment="Center"
                    Margin="0,0,0,32" />
                <Button 
                    x:Name="OKButton"
                    Content="OK"
                    Width="120"
                    Height="40"
                    Background="#007ACC"
                    Foreground="White"
                    FontSize="14"
                    HorizontalAlignment="Center" />
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

# ============================================================================
# WPF UI INITIALIZATION
# ============================================================================

function Initialize-WPF {
    param(
        [xml]$Xaml,
        [pscustomobject]$Config
    )

    try {
        Write-Host "[INFO] Initialisiere WPF-UI..." -ForegroundColor Cyan
        
        # Create XamlReader
        $xmlReader = [System.Xml.XmlNodeReader]::new($Xaml)
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

        # Store window reference globally for event handlers
        $script:WindowReference = $window
        $script:Config = $Config

        # Get UI Elements
        $titleBar = $window.FindName("TitleBar")
        $closeButton = $window.FindName("CloseButton")
        $closeButtonImage = $window.FindName("CloseButtonImage")
        $windowIcon = $window.FindName("WindowIcon")
        $okButton = $window.FindName("OKButton")

        # Load Window Icon
        Write-Host "[INFO] Lade Fenster-Icon..." -ForegroundColor Cyan
        if ($Config.windowIcon) {
            $iconBitmap = Load-BitmapImage -ImagePath $Config.windowIcon -ImageName "Window Icon"
            if ($iconBitmap) {
                $windowIcon.Source = $iconBitmap
            }
        }

        # Load Close Button Images
        Write-Host "[INFO] Lade Close Button Grafiken..." -ForegroundColor Cyan
        $script:NormalButtonImage = $null
        $script:HoverButtonImage = $null
        
        if ($Config.closeButton.normalPath) {
            $script:NormalButtonImage = Load-BitmapImage -ImagePath $Config.closeButton.normalPath -ImageName "Close Button Normal"
            if ($script:NormalButtonImage) {
                $closeButtonImage.Source = $script:NormalButtonImage
            }
        }

        if ($Config.closeButton.hoverPath) {
            $script:HoverButtonImage = Load-BitmapImage -ImagePath $Config.closeButton.hoverPath -ImageName "Close Button Hover"
        }

        # Hover Effect Handler
        Write-Host "[INFO] Registriere Hover-Events..." -ForegroundColor Cyan
        $closeButton.Add_MouseEnter({
            param($sender, $e)
            if ($script:HoverButtonImage -ne $null) {
                $closeButtonImage.Source = $script:HoverButtonImage
            }
        })

        $closeButton.Add_MouseLeave({
            param($sender, $e)
            if ($script:NormalButtonImage -ne $null) {
                $closeButtonImage.Source = $script:NormalButtonImage
            }
        })

        # Window Dragging (Title Bar)
        $titleBar.Add_MouseLeftButtonDown({
            param($sender, $e)
            if ($script:WindowReference -ne $null) {
                try {
                    $script:WindowReference.DragMove()
                }
                catch {
                    Write-Warning "Fehler beim Verschieben des Fensters: $_"
                }
            }
        })

        # Close Button Click
        $closeButton.Add_Click({
            param($sender, $e)
            if ($script:WindowReference -ne $null) {
                try {
                    $script:WindowReference.Close()
                }
                catch {
                    Write-Warning "Fehler beim Schliessen des Fensters: $_"
                }
            }
        })

        # OK Button Click
        $okButton.Add_Click({
            Write-Host "[OK] OK Button geklickt" -ForegroundColor Green
        })

        Write-Host "[OK] WPF-UI erfolgreich initialisiert" -ForegroundColor Green
        return $window
    }
    catch {
        Write-Error "[ERROR] Fehler beim Initialisieren der WPF-UI: $_"
        Write-Error $_.ScriptStackTrace
        return $null
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Show-ModernUI {
    try {
        Write-Host ""
        Write-Host "=================================================" -ForegroundColor Cyan
        Write-Host "[INFO] Starte ModernUI v1.00.00..." -ForegroundColor Cyan
        Write-Host "=================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Load Config
        $config = Load-Configuration -Path $ConfigPath
        if ($null -eq $config) {
            Write-Error "[ERROR] Konfiguration konnte nicht geladen werden"
            return
        }

        Write-Host ""
        
        # Convert XAML String to XML
        $xamlXml = [xml]$xaml

        # Initialize WPF and show Window
        $window = Initialize-WPF -Xaml $xamlXml -Config $config
        
        if ($null -eq $window) {
            Write-Error "[ERROR] Fenster konnte nicht erstellt werden"
            return
        }
        
        Write-Host ""
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "[OK] ModernUI v1.00.00 erfolgreich gestartet" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "   * Fenster verschiebbar (Titelleiste)" -ForegroundColor Green
        Write-Host "   * Hover-Effekte aktiv (Close Button)" -ForegroundColor Green
        Write-Host "   * Config-driven Images" -ForegroundColor Green
        Write-Host "   * Rahmenloses Fenster Design" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host ""
        
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Error "[ERROR] Fehler beim Starten der ModernUI: $_"
        Write-Error $_.ScriptStackTrace
    }
}

# ============================================================================
# ENTRY POINT
# ============================================================================

Show-ModernUI
