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
    - Hover-Effekte fuer Close Button via WPF IsMouseOver Trigger + ImageBrush Background
    - Korrekte Titelleisten-Positionierung
    - Config-driven Image Loading
    - Rahmenloses Fenster Design mit transparenter Titelleiste
    - **FIX: Proper ControlTemplate with IsMouseOver Trigger + ImageBrush Background**
    - **FIX: Background als ImageBrush (nicht Image-Control!)**
    - **FIX: TemplateBinding Background in Border + explizite Width/Height**

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
        Laedt die Konfiguration aus config.json und expandiert Pfade korrekt
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "[ERROR] Config nicht gefunden: $Path"
        return $null
    }

    try {
        Write-Host "[INFO] Lade Konfiguration von: $Path" -ForegroundColor Cyan
        
        # Lese config.json mit UTF8 Encoding
        $configJson = Get-Content -Path $Path -Raw -Encoding UTF8
        
        # Parse als JSON
        $config = $configJson | ConvertFrom-Json -ErrorAction Stop
        
        Write-Host "[OK] Config erfolgreich geladen" -ForegroundColor Green
        
        return $config
    }
    catch {
        Write-Error "[ERROR] Fehler beim Laden der Config: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# IMAGE PATH RESOLUTION
# ============================================================================

function Resolve-ImagePath {
    <#
    .SYNOPSIS
        Resolved einen Bildpfad korrekt relativ zum Skript
    #>
    param(
        [string]$ImageName,
        [string]$BasePath = "PNG"
    )
    
    # Baue den Pfad zusammen
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $BasePath | Join-Path -ChildPath $ImageName
    
    if (Test-Path -Path $fullPath -PathType Leaf) {
        return (Resolve-Path -Path $fullPath).Path
    }
    
    Write-Warning "[WARN] Bild nicht gefunden: $fullPath"
    return $null
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
        Write-Host "[INFO] Lade Bild: $ImageName" -ForegroundColor Gray
        
        $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapImage.BeginInit()
        $bitmapImage.UriSource = New-Object System.Uri($ImagePath, [System.UriKind]::Absolute)
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
# IMAGE BRUSH HELPER (fuer Frameless Windows)
# ============================================================================

function Create-ImageBrush {
    <#
    .SYNOPSIS
        Erstellt einen ImageBrush aus einem BitmapImage
        WICHTIG: Fuer rahmenloses WPF muss der Brush speziell konfiguriert werden
    #>
    param(
        [System.Windows.Media.Imaging.BitmapImage]$BitmapImage,
        [System.Windows.Media.Stretch]$Stretch = [System.Windows.Media.Stretch]::UniformToFill,
        [System.Windows.Media.AlignmentX]$AlignmentX = [System.Windows.Media.AlignmentX]::Center,
        [System.Windows.Media.AlignmentY]$AlignmentY = [System.Windows.Media.AlignmentY]::Center
    )
    
    if ($null -eq $BitmapImage) {
        return $null
    }
    
    try {
        $brush = New-Object System.Windows.Media.ImageBrush
        $brush.ImageSource = $BitmapImage
        $brush.Stretch = $Stretch
        $brush.AlignmentX = $AlignmentX
        $brush.AlignmentY = $AlignmentY
        $brush.Opacity = 1.0  # Volle Deckkraft
        return $brush
    }
    catch {
        Write-Warning "[WARN] Fehler beim Erstellen des ImageBrush: $_"
        return $null
    }
}

# ============================================================================
# INITIALIZE WINDOW RESOURCES
# ============================================================================

function Initialize-WindowResources {
    <#
    .SYNOPSIS
        Initialisiert alle Window-Ressourcen aus der Konfiguration
    #>
    param(
        [pscustomobject]$Config
    )

    try {
        Write-Host "[INFO] Initialisiere Window-Ressourcen..." -ForegroundColor Cyan
        
        # Resolve image paths
        $iconPath = Resolve-ImagePath -ImageName $Config.paths.windowIcon
        $bgPath = Resolve-ImagePath -ImageName $Config.paths.backgroundImage
        $closeNormalPath = Resolve-ImagePath -ImageName $Config.paths.closeButtonNormalPath
        $closeHoverPath = Resolve-ImagePath -ImageName $Config.paths.closeButtonHoverPath
        
        # Load images
        $script:WindowIcon = $null
        $script:BackgroundImage = $null
        $script:BackgroundBrush = $null
        $script:CloseButtonNormalBrush = $null
        $script:CloseButtonHoverBrush = $null
        
        if ($iconPath) {
            $script:WindowIcon = Load-BitmapImage -ImagePath $iconPath -ImageName "Window Icon"
        }
        
        # CRITICAL: Load background image AND create brush
        if ($bgPath) {
            $script:BackgroundImage = Load-BitmapImage -ImagePath $bgPath -ImageName "Background Image"
            if ($script:BackgroundImage) {
                $script:BackgroundBrush = Create-ImageBrush -BitmapImage $script:BackgroundImage
            }
        }
        
        # CRITICAL: Load close button images AND create brushes for triggers
        if ($closeNormalPath) {
            $normalImage = Load-BitmapImage -ImagePath $closeNormalPath -ImageName "Close Button Normal"
            if ($normalImage) {
                $script:CloseButtonNormalBrush = Create-ImageBrush -BitmapImage $normalImage -Stretch Uniform
            }
        }
        
        if ($closeHoverPath) {
            $hoverImage = Load-BitmapImage -ImagePath $closeHoverPath -ImageName "Close Button Hover"
            if ($hoverImage) {
                $script:CloseButtonHoverBrush = Create-ImageBrush -BitmapImage $hoverImage -Stretch Uniform
            }
        }
        
        # Validiere kritische Ressourcen
        if ($null -eq $script:BackgroundBrush) {
            Write-Error "[ERROR] Hintergrundbild konnte nicht geladen werden: $bgPath"
            return $false
        }
        
        if ($null -eq $script:CloseButtonNormalBrush) {
            Write-Error "[ERROR] Close Button Normal Brush konnte nicht erstellt werden: $closeNormalPath"
            return $false
        }
        
        if ($null -eq $script:CloseButtonHoverBrush) {
            Write-Error "[ERROR] Close Button Hover Brush konnte nicht erstellt werden: $closeHoverPath"
            return $false
        }
        
        Write-Host "[OK] Alle Ressourcen erfolgreich geladen" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "[ERROR] Fehler bei der Ressourcen-Initialisierung: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# XAML DEFINITION (WITH PROPER CONTROL TEMPLATE + ISMOUSEOVER TRIGGER)
# ============================================================================
# CRITICAL:
# Der Close Button bekommt ein Style mit Custom ControlTemplate, das:
# 1. Border mit TemplateBinding Background (CRUCIAL!)
# 2. IsMouseOver Trigger in ControlTemplate.Triggers
# 3. Background als ImageBrush (nicht Image-Control!)
# 4. **CRITICAL: Explizite Width/Height auf Border (NICHT nur am Button!)**

$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="ModernUI v1.00.00"
    Height="600"
    Width="800"
    WindowStartupLocation="CenterScreen"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="Transparent"
    x:Name="MainWindow">

    <Window.Resources>
        <!-- CRITICAL: Style for Close Button with IsMouseOver Trigger + ImageBrush Background -->
        <Style x:Key="CloseButtonStyle" TargetType="Button">
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="Background" Value="{DynamicResource CloseButtonNormalBrush}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <!-- CRITICAL: Border with EXPLICIT Width/Height (THIS IS THE FIX!) -->
                        <Border 
                            Name="ButtonBorder"
                            Width="24"
                            Height="24"
                            BorderThickness="0"
                            Background="{TemplateBinding Background}">
                            <!-- No Content needed - Background is the Image! -->
                        </Border>
                        
                        <!-- CRITICAL: IsMouseOver Trigger - Changes Background to Hover Brush -->
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{DynamicResource CloseButtonHoverBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid x:Name="RootGrid" Background="Transparent">
        <!-- OVERLAY GRID (auf dem Hintergrundbild) -->
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="40" />
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <!-- TITLE BAR (TRANSPARENT damit Bild durchscheint) -->
            <Border x:Name="TitleBar" Grid.Row="0" Background="Transparent" Opacity="1.0">
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

                    <!-- Window Title -->
                    <TextBlock 
                        x:Name="TitleText"
                        Text="ModernUI v1.00.00"
                        VerticalAlignment="Center"
                        HorizontalAlignment="Left"
                        Margin="40,0,0,0"
                        FontSize="14"
                        Foreground="#FFFFFF"
                        FontWeight="SemiBold" />

                    <!-- Spacer -->
                    <Border Grid.Column="1" />

                    <!-- Window Controls (Right) -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,8,0">
                        <!-- Close Button WITH STYLE -->
                        <Button 
                            x:Name="CloseButton" 
                            Width="32" 
                            Height="32" 
                            Style="{StaticResource CloseButtonStyle}"
                            Cursor="Arrow" />
                    </StackPanel>
                </Grid>
            </Border>

            <!-- MAIN CONTENT AREA -->
            <Grid Grid.Row="1" Background="Transparent">
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock 
                        Text="ModernUI v1.00.00" 
                        FontSize="32" 
                        FontWeight="Bold" 
                        Foreground="#FFFFFF"
                        TextAlignment="Center"
                        Margin="0,0,0,16" />
                    <TextBlock 
                        Text="Modern UI Framework fuer PowerShell WPF"
                        FontSize="16"
                        Foreground="#E0E0E0"
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
                        HorizontalAlignment="Center"
                        FocusVisualStyle="{x:Null}" />
                </StackPanel>
            </Grid>
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

        # Store window reference in script scope (CRITICAL for event handlers)
        $script:WindowReference = $window
        $script:Config = $Config

        # Get UI Elements
        $rootGrid = $window.FindName("RootGrid")
        $titleBar = $window.FindName("TitleBar")
        $closeButton = $window.FindName("CloseButton")
        $windowIcon = $window.FindName("WindowIcon")
        $okButton = $window.FindName("OKButton")

        # =====================================================================
        # REGISTER DYNAMIC RESOURCES FOR TRIGGERS
        # =====================================================================
        # Diese Brushes werden von den XAML Triggers verwendet!
        $window.Resources.Add("CloseButtonNormalBrush", $script:CloseButtonNormalBrush)
        $window.Resources.Add("CloseButtonHoverBrush", $script:CloseButtonHoverBrush)
        Write-Host "[OK] Dynamic Resources registriert" -ForegroundColor Green

        # =====================================================================
        # CRITICAL FIX: SET BACKGROUND ON WINDOW
        # =====================================================================
        if ($script:BackgroundBrush) {
            $window.Background = $script:BackgroundBrush
            Write-Host "[OK] Hintergrundbild auf Window gesetzt" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Hintergrundbild konnte nicht gesetzt werden" -ForegroundColor Yellow
            $window.Background = [System.Windows.Media.Brushes]::DarkGray
        }

        # =====================================================================
        # SET WINDOW ICON
        # =====================================================================
        if ($script:WindowIcon) {
            $windowIcon.Source = $script:WindowIcon
            Write-Host "[OK] Window-Icon gesetzt" -ForegroundColor Green
        }

        # =====================================================================
        # SET CLOSE BUTTON INITIAL BACKGROUND (via Style)
        # =====================================================================
        if ($script:CloseButtonNormalBrush) {
            $closeButton.Background = $script:CloseButtonNormalBrush
            Write-Host "[OK] Close Button Background (Normal) gesetzt" -ForegroundColor Green
        }

        # =====================================================================
        # TITLE BAR DRAG HANDLER
        # =====================================================================
        $titleBar.Add_MouseLeftButtonDown({
            param($sender, $e)
            if ($script:WindowReference -ne $null) {
                try {
                    $script:WindowReference.DragMove()
                }
                catch {
                    Write-Warning "[WARN] Fehler beim Verschieben des Fensters: $_"
                }
            }
        })

        # =====================================================================
        # CLOSE BUTTON CLICK HANDLER
        # =====================================================================
        $closeButton.Add_Click({
            param($sender, $e)
            if ($script:WindowReference -ne $null) {
                try {
                    Write-Host "[OK] Close Button geklickt" -ForegroundColor Green
                    $script:WindowReference.Close()
                }
                catch {
                    Write-Warning "[WARN] Fehler beim Schliessen des Fensters: $_"
                }
            }
        })

        # =====================================================================
        # OK BUTTON CLICK HANDLER
        # =====================================================================
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
        
        # Initialize Resources
        if (-not (Initialize-WindowResources -Config $config)) {
            Write-Error "[ERROR] Ressourcen-Initialisierung fehlgeschlagen"
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
        Write-Host "   * Hover-Effekte aktiv (Close Button - IsMouseOver Trigger)" -ForegroundColor Green
        Write-Host "   * Hintergrundbild angezeigt" -ForegroundColor Green
        Write-Host "   * Config-driven Images" -ForegroundColor Green
        Write-Host "   * Rahmenloses Fenster Design" -ForegroundColor Green
        Write-Host "   * Transparente Titelleiste" -ForegroundColor Green
        Write-Host "   * XAML IsMouseOver Trigger (zuverlässig!)" -ForegroundColor Green
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
