# Google Fonts WPF Demo - Roboto & Exo
# Vollständiges PowerShell-Skript

# 1. Required Assemblies laden
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# 2. Schriftarten-URLs definieren
$fontUrls = @{
    RobotoRegular  = "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf"
    RobotoBold     = "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Bold.ttf"
    ExoRegular     = "https://github.com/google/fonts/raw/main/ofl/exo/Exo-Regular.ttf"
    ExoItalic      = "https://github.com/google/fonts/raw/main/ofl/exo/Exo-Italic.ttf"
    ExoBold        = "https://github.com/google/fonts/raw/main/ofl/exo/Exo-Bold.ttf"
}

# 3. Schriftarten-Verzeichnis erstellen
$fontDir = Join-Path $PSScriptRoot "data\fonts"
if (-not (Test-Path $fontDir)) {
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
}

# 4. Schriftarten-Download Funktion
function Get-Font {
    param(
        [string]$Url,
        [string]$FileName
    )
    
    $outputPath = Join-Path $fontDir $FileName
    if (-not (Test-Path $outputPath)) {
        try {
            Write-Host "Lade $FileName herunter..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $Url -OutFile $outputPath -UseBasicParsing
        }
        catch {
            Write-Host "Fehler beim Download von $FileName : $_" -ForegroundColor Red
            exit 1
        }
    }
    return $outputPath
}

# 5. Alle Schriftarten herunterladen
$fonts = @{
    RobotoRegular = Get-Font -Url $fontUrls.RobotoRegular -FileName "Roboto-Regular.ttf"
    RobotoBold    = Get-Font -Url $fontUrls.RobotoBold    -FileName "Roboto-Bold.ttf"
    ExoRegular    = Get-Font -Url $fontUrls.ExoRegular    -FileName "Exo-Regular.ttf"
    ExoItalic     = Get-Font -Url $fontUrls.ExoItalic     -FileName "Exo-Italic.ttf"
    ExoBold       = Get-Font -Url $fontUrls.ExoBold       -FileName "Exo-Bold.ttf"
}

# 6. XAML Interface Definition
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PowerShell Font Demo" Width="850" Height="650"
    WindowStartupLocation="CenterScreen"
    Background="#FFFFFF">
    
    <Window.Resources>
        <!-- Roboto Schriftarten -->
        <FontFamily x:Key="RobotoRegular">pack://siteoforigin:,,,/fonts/Roboto-Regular.ttf#Roboto</FontFamily>
        <FontFamily x:Key="RobotoBold">pack://siteoforigin:,,,/fonts/Roboto-Bold.ttf#Roboto</FontFamily>
        
        <!-- Exo Schriftarten -->
        <FontFamily x:Key="ExoRegular">pack://siteoforigin:,,,/fonts/Exo-Regular.ttf#Exo</FontFamily>
        <FontFamily x:Key="ExoItalic">pack://siteoforigin:,,,/fonts/Exo-Italic.ttf#Exo</FontFamily>
        <FontFamily x:Key="ExoBold">pack://siteoforigin:,,,/fonts/Exo-Bold.ttf#Exo</FontFamily>
        
        <!-- Globale Stile -->
        <Style x:Key="HeaderStyle" TargetType="TextBlock">
            <Setter Property="FontSize" Value="22"/>
            <Setter Property="Margin" Value="0,15,0,10"/>
            <Setter Property="Foreground" Value="#333333"/>
        </Style>
        
        <Style x:Key="SampleTextStyle" TargetType="TextBlock">
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="Margin" Value="0,0,0,15"/>
            <Setter Property="LineHeight" Value="22"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="20">
                <!-- Hauptheader -->
                <TextBlock Text="PowerShell WPF Font Demo" 
                          FontFamily="{StaticResource RobotoBold}"
                          FontSize="28" 
                          Foreground="#2A5DB0"
                          TextAlignment="Center"
                          Margin="0,0,0,25"/>
                
                <!-- Roboto Abschnitt -->
                <Border Background="#F8F9FA" CornerRadius="8" Padding="15" Margin="0,0,0,20">
                    <StackPanel>
                        <TextBlock Text="Roboto Schriftfamilie" 
                                  Style="{StaticResource HeaderStyle}"
                                  FontFamily="{StaticResource RobotoBold}"/>
                        
                        <TextBlock Style="{StaticResource SampleTextStyle}"
                                  FontFamily="{StaticResource RobotoRegular}">
                            Roboto ist eine moderne Sans-Serif-Schriftart, die speziell für 
                            Benutzeroberflächen entwickelt wurde. Sie kombiniert geometrische 
                            Formen mit freundlichen Kurven für eine optimierte Lesbarkeit.
                        </TextBlock>
                        
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="5">
                                <TextBlock Text="Regular" FontFamily="{StaticResource RobotoRegular}" FontSize="16"/>
                                <TextBlock Text="The quick brown fox jumps over the lazy dog" 
                                          FontFamily="{StaticResource RobotoRegular}"
                                          Margin="0,5"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1" Margin="5">
                                <TextBlock Text="Italic" FontFamily="{StaticResource RobotoRegular}" FontSize="16"/>
                                <TextBlock Text="1234567890 !@#$%^&amp;*()" 
                                          FontFamily="{StaticResource RobotoRegular}"
                                          Margin="0,5"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="2" Margin="5">
                                <TextBlock Text="Bold" FontFamily="{StaticResource RobotoBold}" FontSize="16"/>
                                <TextBlock Text="ABCDEFGHIJKLMNOPQRSTUVWXYZ" 
                                          FontFamily="{StaticResource RobotoBold}"
                                          Margin="0,5"/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                </Border>
                
                <!-- Exo Abschnitt -->
                <Border Background="#F3F6FF" CornerRadius="8" Padding="15" Margin="0,0,0,20">
                    <StackPanel>
                        <TextBlock Text="Exo Schriftfamilie" 
                                  Style="{StaticResource HeaderStyle}"
                                  FontFamily="{StaticResource ExoBold}"/>
                        
                        <TextBlock Style="{StaticResource SampleTextStyle}"
                                  FontFamily="{StaticResource ExoRegular}">
                            Exo ist eine geometrische Schriftart mit technischem Einschlag, 
                            ideal für moderne Anwendungen und Webdesign. Die hohen x-Höhen 
                            und präzisen Formen verleihen ihr einen futuristischen Charakter.
                        </TextBlock>
                        
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="5">
                                <TextBlock Text="Regular" FontFamily="{StaticResource ExoRegular}" FontSize="16"/>
                                <TextBlock Text="Lorem ipsum dolor sit amet, consectetur adipiscing elit" 
                                          FontFamily="{StaticResource ExoRegular}"
                                          Margin="0,5"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1" Margin="5">
                                <TextBlock Text="Italic" FontFamily="{StaticResource ExoItalic}" FontSize="16"/>
                                <TextBlock Text="äöüß €§°¹²³¼½¬{[]}" 
                                          FontFamily="{StaticResource ExoItalic}"
                                          Margin="0,5"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="2" Margin="5">
                                <TextBlock Text="Bold" FontFamily="{StaticResource ExoBold}" FontSize="16"/>
                                <TextBlock Text="abcdefghijklmnopqrstuvwxyz" 
                                          FontFamily="{StaticResource ExoBold}"
                                          Margin="0,5"/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                </Border>
                
                <!-- Vergleichssektion -->
                <Border Background="#FFFFFF" BorderThickness="1" BorderBrush="#E0E0E0" CornerRadius="8" Padding="15">
                    <StackPanel>
                        <TextBlock Text="Direkter Vergleich" 
                                  Style="{StaticResource HeaderStyle}"
                                  FontFamily="{StaticResource RobotoBold}"/>
                        
                        <Grid Margin="0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <TextBlock Grid.Column="0" 
                                      Text="Roboto zeigt technische Präzision mit humanistischen Zügen."
                                      FontFamily="{StaticResource RobotoRegular}"
                                      TextWrapping="Wrap"
                                      FontSize="14"/>
                            
                            <TextBlock Grid.Column="1" 
                                      Text="VS" 
                                      Margin="20,0"
                                      FontSize="24"
                                      VerticalAlignment="Center"/>
                            
                            <TextBlock Grid.Column="2" 
                                      Text="Exo bietet futuristische Eleganz mit geometrischer Strenge."
                                      FontFamily="{StaticResource ExoRegular}"
                                      TextWrapping="Wrap"
                                      FontSize="14"/>
                        </Grid>
                    </StackPanel>
                </Border>
                
                <!-- Footer -->
                <TextBlock Margin="0,20,0,0" FontSize="12" Foreground="#666666">
                    <Run Text="Schriftarten bereitgestellt von Google Fonts | "/>
                    <Run Text="PowerShell $($PSVersionTable.PSVersion.ToString()) | "/>
                    <Run Text="WPF .NET $([Environment]::Version)"/>
                </TextBlock>
            </StackPanel>
        </ScrollViewer>
    </Grid>
</Window>
"@

# 7. XAML verarbeiten und Fenster erstellen
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# 8. Fenster anzeigen
$null = $window.ShowDialog()
