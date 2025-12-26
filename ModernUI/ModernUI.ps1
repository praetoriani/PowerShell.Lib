<#
.SYNOPSIS
    ModernUI v1.00.00 - Modern UI Framework for PowerShell WPF (FINAL STABLE)

.DESCRIPTION
    Eine moderne Benutzeroberflaeche fuer PowerShell mit WPF, basierend auf 
    Microsoft Windows 11 Modern UI Design Principles.

.AUTHOR
    Marc Sczepanski (praetoriani)

.VERSION
    1.00.00 (Stable Release - FINAL)
    - Fenster verschiebbar
    - PNG Close Button (STABIL - keine Hover-Effekte)
    - Korrekte Titelleisten-Positionierung
    - Config-driven Image Loading
    - Rahmenloses Fenster Design
    - **FINAL: PNG Close Button stabil ohne Hover**
    - **NO HOVER EFFECTS - CLEAN BUTTON**

.NOTES
    Requires: PowerShell 7.0+, .NET Framework 4.8+
    GitHub: https://github.com/praetoriani/PowerShell.Lib
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config.json"
)

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
# CONFIGURATION LOADING
# ============================================================================

function Load-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "[ERROR] Config nicht gefunden: $Path"
        return $null
    }

    try {
        Write-Host "[INFO] Lade Konfiguration von: $Path" -ForegroundColor Cyan
        $configJson = Get-Content -Path $Path -Raw -Encoding UTF8
        $config = $configJson | ConvertFrom-Json -ErrorAction Stop
        Write-Host "[OK] Config erfolgreich geladen" -ForegroundColor Green
        return $config
    }
    catch {
        Write-Error "[ERROR] Config error: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# IMAGE PATH RESOLUTION
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
    
    Write-Warning "[WARN] Bild nicht gefunden: $fullPath"
    return $null
}

# ============================================================================
# IMAGE LOADING
# ============================================================================

function Load-BitmapImage {
    param(
        [string]$ImagePath,
        [string]$ImageName = "Unknown"
    )
    
    if ([string]::IsNullOrEmpty($ImagePath) -or -not (Test-Path $ImagePath)) {
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
        $bitmapImage.Freeze()
        
        Write-Host "[OK] Bild geladen: $ImageName" -ForegroundColor Green
        return $bitmapImage
    }
    catch {
        Write-Warning "[WARN] Fehler beim Laden: $_"
        return $null
    }
}

# ============================================================================
# IMAGE BRUSH CREATION
# ============================================================================

function Create-ImageBrush {
    param([System.Windows.Media.Imaging.BitmapImage]$BitmapImage)
    
    if ($null -eq $BitmapImage) {
        return $null
    }
    
    try {
        $brush = New-Object System.Windows.Media.ImageBrush
        $brush.ImageSource = $BitmapImage
        $brush.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        $brush.AlignmentX = [System.Windows.Media.AlignmentX]::Center
        $brush.AlignmentY = [System.Windows.Media.AlignmentY]::Center
        return $brush
    }
    catch {
        Write-Warning "[WARN] ImageBrush error: $_"
        return $null
    }
}

# ============================================================================
# INITIALIZE WINDOW RESOURCES
# ============================================================================

function Initialize-WindowResources {
    param([pscustomobject]$Config)

    try {
        Write-Host "[INFO] Initialisiere Window-Ressourcen..." -ForegroundColor Cyan
        
        $iconPath = Resolve-ImagePath -ImageName $Config.paths.windowIcon
        $bgPath = Resolve-ImagePath -ImageName $Config.paths.backgroundImage
        $closeButtonPath = Resolve-ImagePath -ImageName $Config.paths.closeButtonNormalPath
        
        $script:WindowIcon = $null
        $script:BackgroundBrush = $null
        $script:CloseButtonImage = $null
        
        if ($iconPath) {
            $script:WindowIcon = Load-BitmapImage -ImagePath $iconPath -ImageName "Window Icon"
        }
        
        if ($bgPath) {
            $backgroundImage = Load-BitmapImage -ImagePath $bgPath -ImageName "Background Image"
            if ($backgroundImage) {
                $script:BackgroundBrush = Create-ImageBrush -BitmapImage $backgroundImage
            }
        }
        
        if ($closeButtonPath) {
            $script:CloseButtonImage = Load-BitmapImage -ImagePath $closeButtonPath -ImageName "Close Button"
        }
        
        if ($null -eq $script:BackgroundBrush) {
            Write-Error "[ERROR] Background Image failed"
            return $false
        }
        
        if ($null -eq $script:CloseButtonImage) {
            Write-Error "[ERROR] Close Button Image failed"
            return $false
        }
        
        Write-Host "[OK] Alle Ressourcen erfolgreich geladen" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "[ERROR] Resource initialization failed: $_"
        return $false
    }
}

# ============================================================================
# XAML DEFINITION (WITH NO HOVER STYLE)
# ============================================================================

$xamlString = @"
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
        <!-- NO HOVER CLOSE BUTTON STYLE -->
        <Style x:Key="NoHoverButtonStyle" TargetType="Button">
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border 
                            Background="{TemplateBinding Background}"
                            BorderThickness="0"
                            Padding="0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid x:Name="RootGrid" Background="Transparent">
        <Grid.RowDefinitions>
            <RowDefinition Height="40" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <!-- TITLE BAR -->
        <Border x:Name="TitleBar" Grid.Row="0" Background="Transparent">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>

                <Image x:Name="WindowIconImage" Grid.Column="0" Width="24" Height="24" Margin="8,0,0,0" VerticalAlignment="Center" />
                
                <TextBlock x:Name="TitleText" Grid.Column="1" Text="ModernUI v1.00.00" VerticalAlignment="Center" Margin="40,0,0,0" FontSize="14" Foreground="#FFFFFF" FontWeight="SemiBold" />
                
                <Button x:Name="CloseButton" Grid.Column="2" Style="{StaticResource NoHoverButtonStyle}" Width="40" Height="40" Cursor="Hand" Margin="0,0,8,0" VerticalAlignment="Center" />
            </Grid>
        </Border>

        <!-- MAIN CONTENT -->
        <Grid Grid.Row="1" Background="Transparent">
            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                <TextBlock Text="ModernUI v1.00.00" FontSize="32" FontWeight="Bold" Foreground="#FFFFFF" TextAlignment="Center" Margin="0,0,0,16" />
                <TextBlock Text="Modern UI Framework fuer PowerShell WPF" FontSize="16" Foreground="#E0E0E0" TextAlignment="Center" Margin="0,0,0,32" />
                <Button x:Name="OKButton" Content="OK" Width="120" Height="40" Background="#007ACC" Foreground="White" FontSize="14" HorizontalAlignment="Center" />
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

# ============================================================================
# WPF UI INITIALIZATION
# ============================================================================

function Initialize-WPF {
    param([pscustomobject]$Config)

    try {
        Write-Host "[INFO] Initialisiere WPF-UI..." -ForegroundColor Cyan
        
        # Parse XAML
        $xamlXml = [xml]$xamlString
        $xmlReader = [System.Xml.XmlNodeReader]::new($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

        if ($null -eq $window) {
            Write-Error "[ERROR] XAML parsing returned null"
            return $null
        }

        $script:WindowReference = $window

        # =====================================================================
        # GET UI ELEMENTS
        # =====================================================================
        
        $titleBar = $window.FindName("TitleBar")
        $closeButton = $window.FindName("CloseButton")
        $windowIconImg = $window.FindName("WindowIconImage")
        $okButton = $window.FindName("OKButton")

        if ($null -eq $closeButton) {
            Write-Error "[ERROR] CloseButton element not found in XAML"
            return $null
        }

        if ($null -eq $titleBar) {
            Write-Error "[ERROR] TitleBar element not found in XAML"
            return $null
        }

        # =====================================================================
        # SET BACKGROUND
        # =====================================================================
        if ($script:BackgroundBrush) {
            $window.Background = $script:BackgroundBrush
            Write-Host "[OK] Hintergrundbild auf Window gesetzt" -ForegroundColor Green
        }

        # =====================================================================
        # SET WINDOW ICON
        # =====================================================================
        if ($script:WindowIcon -and $windowIconImg) {
            $windowIconImg.Source = $script:WindowIcon
            Write-Host "[OK] Window-Icon gesetzt" -ForegroundColor Green
        }

        # =====================================================================
        # SET CLOSE BUTTON IMAGE - AS BACKGROUND
        # =====================================================================
        if ($script:CloseButtonImage) {
            try {
                # Create Image control
                $buttonImage = New-Object System.Windows.Controls.Image
                $buttonImage.Source = $script:CloseButtonImage
                $buttonImage.Stretch = [System.Windows.Media.Stretch]::Uniform
                $buttonImage.Width = 32
                $buttonImage.Height = 32
                $buttonImage.RenderOptions.SetBitmapScalingMode($buttonImage, [System.Windows.Media.BitmapScalingMode]::HighQuality)
                
                $closeButton.Content = $buttonImage
                $closeButton.Background = [System.Windows.Media.Brushes]::Transparent
                $closeButton.Padding = New-Object System.Windows.Thickness(4)
                
                Write-Host "[OK] Close Button Image gesetzt (PNG)" -ForegroundColor Green
            }
            catch {
                Write-Warning "[WARN] Close button image error: $_"
            }
        }

        # =====================================================================
        # ADD TOOLTIP
        # =====================================================================
        try {
            $tooltip = New-Object System.Windows.Controls.ToolTip
            $tooltip.Content = "Programm beenden"
            $tooltip.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(64, 64, 64))
            $tooltip.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
            $tooltip.FontSize = 12
            $tooltip.Padding = New-Object System.Windows.Thickness(8)
            $closeButton.ToolTip = $tooltip
            Write-Host "[OK] Tooltip fuer Close Button hinzugefuegt" -ForegroundColor Green
        }
        catch {
            Write-Warning "[WARN] Tooltip error: $_"
        }

        Write-Host "[OK] Close Button - NO HOVER EFFECTS (stabil)" -ForegroundColor Green

        # =====================================================================
        # TITLE BAR DRAG
        # =====================================================================
        $titleBar.Add_MouseLeftButtonDown({
            if ($script:WindowReference -ne $null) {
                try { $script:WindowReference.DragMove() } catch { }
            }
        })

        # =====================================================================
        # CLOSE BUTTON CLICK
        # =====================================================================
        $closeButton.Add_Click({
            if ($script:WindowReference -ne $null) {
                try {
                    Write-Host "[OK] Close Button geklickt - Fenster wird geschlossen" -ForegroundColor Green
                    $script:WindowReference.Close()
                }
                catch {
                    Write-Warning "[WARN] Close error: $_"
                }
            }
        })

        # =====================================================================
        # OK BUTTON CLICK
        # =====================================================================
        $okButton.Add_Click({
            Write-Host "[OK] OK Button geklickt" -ForegroundColor Green
        })

        Write-Host "[OK] WPF-UI erfolgreich initialisiert" -ForegroundColor Green
        return $window
    }
    catch {
        Write-Error "[ERROR] WPF initialization failed: $_"
        Write-Error $_.ScriptStackTrace
        return $null
    }
}

# ============================================================================
# MAIN
# ============================================================================

try {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "[INFO] Starte ModernUI v1.00.00 (FINAL STABLE)..." -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $config = Load-Configuration -Path $ConfigPath
    if ($null -eq $config) {
        Write-Error "[ERROR] Config loading failed"
        exit 1
    }

    Write-Host ""
    
    if (-not (Initialize-WindowResources -Config $config)) {
        Write-Error "[ERROR] Resource initialization failed"
        exit 1
    }

    Write-Host ""
    
    $window = Initialize-WPF -Config $config
    
    if ($null -eq $window) {
        Write-Error "[ERROR] Window creation failed"
        exit 1
    }
    
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "[OK] ModernUI v1.00.00 erfolgreich gestartet" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "   [OK] Fenster verschiebbar (Titelleiste)" -ForegroundColor Green
    Write-Host "   [OK] Hintergrundbild angezeigt" -ForegroundColor Green
    Write-Host "   [OK] PNG Close Button (OHNE HOVER-EFFEKTE)" -ForegroundColor Green
    Write-Host "   [OK] Tooltip 'Programm beenden'" -ForegroundColor Green
    Write-Host "   [OK] Hand-Cursor" -ForegroundColor Green
    Write-Host "   [OK] Config-driven Image Loading" -ForegroundColor Green
    Write-Host "   [OK] Rahmenloses Fenster Design" -ForegroundColor Green
    Write-Host "   [OK] FINAL STABLE RELIABLE VERSION" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    
    $window.ShowDialog() | Out-Null
}
catch {
    Write-Error "[ERROR] Fatal error: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
