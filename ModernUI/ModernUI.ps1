<#
.SYNOPSIS
    ModernUI v1.00.00 - Modern UI Framework for PowerShell WPF

.DESCRIPTION
    Eine moderne Benutzeroberfläche für PowerShell mit WPF, basierend auf 
    Microsoft Windows 11 Modern UI Design Principles.

.AUTHOR
    Marc Sczepanski (praetoriani)

.VERSION
    1.00.00 (Stable Release)
    - Fenster verschiebbar
    - Hover-Effekte für Close Button
    - Korrekte Titelleisten-Positionierung
    - Config-driven Image Loading

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
    Write-Error "❌ Fehler beim Laden der erforderlichen Assemblies: $_"
    exit 1
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

function Load-Configuration {
    <#
    .SYNOPSIS
        Lädt die Konfiguration aus config.json
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Config nicht gefunden: $Path"
        return $null
    }

    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        Write-Host "✅ Config geladen" -ForegroundColor Green
        return $config
    }
    catch {
        Write-Error "❌ Fehler beim Laden der Config: $_"
        return $null
    }
}

# ============================================================================
# IMAGE LOADING HELPER
# ============================================================================

function Load-BitmapImage {
    <#
    .SYNOPSIS
        Lädt ein Bild mit korrektem URI Format
    #>
    param(
        [string]$ImagePath
    )
    
    if ([string]::IsNullOrEmpty($ImagePath) -or -not (Test-Path $ImagePath)) {
        return $null
    }
    
    try {
        $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapImage.BeginInit()
        $bitmapImage.UriSource = New-Object System.Uri($ImagePath)
        $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmapImage.EndInit()
        $bitmapImage.Freeze()  # Freeze für Cross-Thread Zugriff
        return $bitmapImage
    }
    catch {
        Write-Warning "❌ Fehler beim Laden des Bildes '$ImagePath': $_"
        return $null
    }
}

# ============================================================================
# XAML DEFINITION (CLEAN & SIMPLE)
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
    ResizeMode="CanResizeWithGrip"
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
                    Text="Modern UI Framework für PowerShell WPF"
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
    <#
    .SYNOPSIS
        Initialisiert die WPF-UI und registriert Event Handler
    #>
    param(
        [xml]$Xaml,
        [pscustomobject]$Config
    )

    try {
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

        # ====================================================================
        # LOAD IMAGES FROM CONFIG
        # ====================================================================
        
        if ($Config.WindowIcon -and (Test-Path $Config.WindowIcon)) {
            $iconBitmap = Load-BitmapImage -ImagePath $Config.WindowIcon
            if ($iconBitmap) {
                $windowIcon.Source = $iconBitmap
            }
        }

        # Close Button - Normal State
        $script:NormalButtonImage = $null
        $script:HoverButtonImage = $null
        
        if ($Config.CloseButton.NormalPath -and (Test-Path $Config.CloseButton.NormalPath)) {
            $script:NormalButtonImage = Load-BitmapImage -ImagePath $Config.CloseButton.NormalPath
            if ($script:NormalButtonImage) {
                $closeButtonImage.Source = $script:NormalButtonImage
            }
        }

        # Close Button - Hover State
        if ($Config.CloseButton.HoverPath -and (Test-Path $Config.CloseButton.HoverPath)) {
            $script:HoverButtonImage = Load-BitmapImage -ImagePath $Config.CloseButton.HoverPath
        }

        # ====================================================================
        # HOVER EFFECT HANDLER
        # ====================================================================
        
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

        # ====================================================================
        # EVENT HANDLER REGISTRATION
        # ====================================================================

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
                    Write-Warning "Fehler beim Schließen des Fensters: $_"
                }
            }
        })

        # OK Button Click
        $okButton.Add_Click({
            Write-Host "✅ OK Button geklickt" -ForegroundColor Green
        })

        return $window
    }
    catch {
        Write-Error "❌ Fehler beim Initialisieren der WPF-UI: $_"
        Write-Error $_.ScriptStackTrace
        return $null
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Show-ModernUI {
    <#
    .SYNOPSIS
        Zeigt die ModernUI an
    #>
    try {
        Write-Host "⏳ Starte ModernUI v1.00.00..." -ForegroundColor Cyan
        
        # Load Config
        $config = Load-Configuration -Path $ConfigPath
        if ($null -eq $config) {
            Write-Error "❌ Konfiguration konnte nicht geladen werden"
            return
        }

        # Convert XAML String to XML
        $xamlXml = [xml]$xaml

        # Initialize WPF and show Window
        $window = Initialize-WPF -Xaml $xamlXml -Config $config
        
        if ($null -eq $window) {
            Write-Error "❌ Fenster konnte nicht erstellt werden"
            return
        }
        
        Write-Host "✅ ModernUI v1.00.00 erfolgreich gestartet" -ForegroundColor Green
        Write-Host "   ├─ Fenster verschiebbar (Titelleiste)" -ForegroundColor Green
        Write-Host "   ├─ Hover-Effekte aktiv (Close Button)" -ForegroundColor Green
        Write-Host "   └─ Config-driven Images" -ForegroundColor Green
        Write-Host ""
        
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Error "❌ Fehler beim Starten der ModernUI: $_"
        Write-Error $_.ScriptStackTrace
    }
}

# ============================================================================
# ENTRY POINT
# ============================================================================

Show-ModernUI
