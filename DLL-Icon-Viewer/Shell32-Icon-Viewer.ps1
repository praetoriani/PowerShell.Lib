# PowerShell WPF Demo-Anwendung: Shell32.dll Icon Viewer (UTF-8 BOM Version)
# Zeigt ALLE Icons aus der Windows shell32.dll in einem Grid-Layout an

# UTF-8 Encoding für die Konsole setzen (für korrekte Umlaute)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
chcp 65001 | Out-Null

# Erforderliche Assemblies laden
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore

# Win32-API-Definitionen (mit korrekten using-Direktiven)
if (-not ('Win32.IconExtractor' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

namespace Win32 {
    public class IconExtractor {
        [DllImport("Shell32.dll", CharSet = CharSet.Auto)]
        public static extern uint ExtractIconEx(
            string szFileName,
            int nIconIndex,
            IntPtr[] phiconLarge,
            IntPtr[] phiconSmall,
            uint nIcons
        );
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr hIcon);
        
        public static Icon ExtractIcon(string file, int index, bool largeIcon = true) {
            IntPtr[] large = new IntPtr[1] { IntPtr.Zero };
            IntPtr[] small = new IntPtr[1] { IntPtr.Zero };
            
            uint count = ExtractIconEx(file, index, large, small, 1);
            
            if (count > 0) {
                IntPtr iconPtr = largeIcon ? large[0] : small[0];
                if (iconPtr != IntPtr.Zero) {
                    Icon icon = Icon.FromHandle(iconPtr);
                    Icon clonedIcon = (Icon)icon.Clone();
                    DestroyIcon(iconPtr);
                    return clonedIcon;
                }
            }
            
            return null;
        }
        
        // Funktion zur Ermittlung der Gesamtanzahl Icons in einer DLL
        public static uint GetIconCount(string file) {
            return ExtractIconEx(file, -1, null, null, 0);
        }
    }
}
"@ -ReferencedAssemblies @('System.Drawing', 'System.Windows.Forms')
}

# XAML-Definition für die GUI mit korrekter Button-Template-Struktur
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Shell32.dll Icon Viewer - Alle Icons anzeigen"
        WindowStartupLocation="CenterScreen"
        Width="950"
        Height="750"
        MinWidth="700"
        MinHeight="500"
        Background="White">
    
    <Window.Resources>
        <!-- Style fuer Load Button mit Hover-Effekt -->
        <Style x:Key="LoadButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#E3F2FD"/>
            <Setter Property="BorderBrush" Value="#2196F3"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="Foreground" Value="#1976D2"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="Center" 
                                            VerticalAlignment="Center"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#BBDEFB"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#1976D2"/>
                                <Setter Property="Foreground" Value="#0D47A1"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#90CAF9"/>
                                <Setter Property="Foreground" Value="#0D47A1"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#FFCCCCCC"/>
                                <Setter Property="Foreground" Value="#FF666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Style fuer Exit Button mit rotem Hover-Effekt und ControlTemplate -->
        <Style x:Key="ExitButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#FFEBEE"/>
            <Setter Property="BorderBrush" Value="#E57373"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="Foreground" Value="#D32F2F"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="Center" 
                                            VerticalAlignment="Center"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#FFC0392B"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FF8B0000"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#FFA93226"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#FFCCCCCC"/>
                                <Setter Property="Foreground" Value="#FF666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <StackPanel Grid.Row="0" Orientation="Vertical" Margin="0,0,0,15">
            <TextBlock Text="Shell32.dll Icon Viewer - Vollständige Sammlung" 
                      FontSize="28" 
                      FontWeight="Bold" 
                      HorizontalAlignment="Center"
                      Foreground="DarkBlue"/>
            <TextBlock Text="Diese Demo-Anwendung zeigt ALLE verfügbaren Icons aus der Windows shell32.dll" 
                      FontSize="13" 
                      HorizontalAlignment="Center"
                      Margin="0,8,0,0"
                      TextWrapping="Wrap"
                      Foreground="Gray"/>
        </StackPanel>
        
        <!-- Icon-Anzeige-Bereich mit ScrollViewer und UniformGrid -->
        <Border Grid.Row="1" 
               BorderBrush="LightGray" 
               BorderThickness="2" 
               Margin="0,0,0,15"
               Background="#FAFAFA">
            <ScrollViewer VerticalScrollBarVisibility="Auto" 
                         HorizontalScrollBarVisibility="Auto"
                         Padding="15">
                <UniformGrid x:Name="IconGrid" 
                           Columns="12"
                           HorizontalAlignment="Center"
                           VerticalAlignment="Top"/>
            </ScrollViewer>
        </Border>
        
        <!-- Status und Steuerung -->
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                <TextBlock x:Name="StatusText" 
                          Text="Bereit - Klicke 'Alle Icons laden' um alle shell32.dll Icons anzuzeigen" 
                          FontSize="12"
                          Margin="0,0,10,2"/>
                <StackPanel Orientation="Horizontal">
                    <TextBlock x:Name="CountText"
                              Text=""
                              FontSize="11"
                              FontWeight="Bold"
                              Foreground="DarkBlue"
                              Margin="0,0,10,0"/>
                    <TextBlock x:Name="TotalText"
                              Text=""
                              FontSize="11"
                              FontWeight="Normal"
                              Foreground="DarkGreen"/>
                </StackPanel>
            </StackPanel>
            
            <Button x:Name="LoadButton" 
                   Grid.Column="1" 
                   Content="Alle Icons laden" 
                   Width="130" 
                   Height="40" 
                   Margin="10,0,10,0"
                   FontSize="12"
                   Style="{StaticResource LoadButtonStyle}"/>
            
            <Button x:Name="ExitButton" 
                   Grid.Column="2" 
                   Content="Beenden" 
                   Width="100" 
                   Height="40"
                   FontSize="12"
                   Style="{StaticResource ExitButtonStyle}"/>
        </Grid>
    </Grid>
</Window>
"@

# Funktion zum Erstellen der WPF-Window aus XAML
function Convert-XAMLtoWindow {
    param([string]$XAML)
    
    try {
        $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
        $result = [Windows.Markup.XAMLReader]::Load($reader)
        $reader.Close()
        
        # Alle benannten Elemente als Properties hinzufügen
        $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
        while ($reader.Read()) {
            $name = $reader.GetAttribute('Name')
            if (!$name) { $name = $reader.GetAttribute('x:Name') }
            if ($name) {
                $result | Add-Member NoteProperty -Name $name -Value $result.FindName($name) -Force
            }
        }
        $reader.Close()
        
        return $result
    }
    catch {
        Write-Error "Fehler beim Laden der XAML: $_"
        return $null
    }
}

# Funktion zum Extrahieren eines Icons aus shell32.dll
function Get-Shell32Icon {
    param(
        [int]$IconIndex
    )
    
    try {
        $shell32Path = "$env:SystemRoot\System32\shell32.dll"
        
        # Versuche mit Win32-API
        $icon = [Win32.IconExtractor]::ExtractIcon($shell32Path, $IconIndex, $true)
        
        if ($icon -eq $null -and $IconIndex -eq 0) {
            # Fallback für Index 0 mit ExtractAssociatedIcon
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($shell32Path)
        }
        
        return $icon
    }
    catch {
        return $null
    }
}

# Funktion zum Ermitteln der Gesamtanzahl Icons in shell32.dll
function Get-Shell32IconCount {
    try {
        $shell32Path = "$env:SystemRoot\System32\shell32.dll"
        $totalCount = [Win32.IconExtractor]::GetIconCount($shell32Path)
        return [int]$totalCount
    }
    catch {
        # Fallback: Bekannte Anzahl für Windows 10/11 (ca. 300-350 Icons)
        return 350
    }
}

# Funktion zum Konvertieren eines Icons zu BitmapSource für WPF
function ConvertTo-WpfBitmapSource {
    param([System.Drawing.Icon]$Icon)
    
    if ($Icon -eq $null) { return $null }
    
    try {
        $bitmapSource = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $Icon.Handle,
            [System.Windows.Int32Rect]::Empty,
            [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
        )
        
        return $bitmapSource
    }
    catch {
        return $null
    }
}

# Funktion zum Erstellen eines Icon-Panels
function New-IconPanel {
    param(
        [int]$IconIndex,
        [System.Windows.Media.ImageSource]$ImageSource
    )
    
    # Border für das Icon-Panel erstellen
    $border = New-Object System.Windows.Controls.Border
    $border.BorderBrush = [System.Windows.Media.Brushes]::LightGray
    $border.BorderThickness = 1.5
    $border.Margin = 3
    $border.Padding = 8
    $border.Background = [System.Windows.Media.Brushes]::White
    
    # StackPanel für Icon und Text
    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $stackPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
    $stackPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    
    # Image-Control für das Icon
    $image = New-Object System.Windows.Controls.Image
    $image.Source = $ImageSource
    $image.Width = 36
    $image.Height = 36
    $image.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    
    # TextBlock für den Index
    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.Text = "Index $IconIndex"
    $textBlock.FontSize = 9
    $textBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
    $textBlock.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $textBlock.Margin = "0,4,0,0"
    $textBlock.Foreground = [System.Windows.Media.Brushes]::DarkSlateGray
    
    # Elemente zum StackPanel hinzufügen
    $stackPanel.Children.Add($image) | Out-Null
    $stackPanel.Children.Add($textBlock) | Out-Null
    
    # StackPanel zur Border hinzufügen
    $border.Child = $stackPanel
    
    # Tooltip hinzufügen
    $tooltip = New-Object System.Windows.Controls.ToolTip
    $tooltip.Content = "Shell32.dll Icon Index: $IconIndex`n`nPfad: %SystemRoot%\System32\shell32.dll`nVerwendung: shell32.dll,$IconIndex`n`nKlicken für weitere Details..."
    $border.ToolTip = $tooltip
    
    # Click-Event für Detailinformationen
    $border.add_MouseLeftButtonUp({
        param($sender, $e)
        try {
            $messageText = @"
Icon-Details

Datei: shell32.dll
Pfad: $env:SystemRoot\System32\shell32.dll
Index: $IconIndex
Größe: 36x36 Pixel

Verwendung in anderen Anwendungen:
   shell32.dll,$IconIndex

Registry-Syntax:
   %SystemRoot%\system32\shell32.dll,$IconIndex

Desktop.ini-Syntax:
   IconResource=%SystemRoot%\system32\shell32.dll,$IconIndex

Dieses Icon ist Teil der Windows-Systemicons.
"@
            [System.Windows.MessageBox]::Show(
                $messageText,
                "Icon-Information - Index $IconIndex",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
        catch {
            Write-Warning "Fehler beim Anzeigen der Icon-Details: $_"
        }
    })
    
    # Cursor ändern bei Hover
    $border.Cursor = [System.Windows.Input.Cursors]::Hand
    
    return $border
}

# Funktion zum Laden ALLER Icons aus shell32.dll
function Load-AllIcons {
    param($Window)
    
    try {
        $Window.StatusText.Text = "Ermittle Gesamtanzahl der Icons in shell32.dll..."
        $Window.CountText.Text = ""
        $Window.TotalText.Text = ""
        $Window.LoadButton.IsEnabled = $false
        $Window.IconGrid.Children.Clear()
        
        # Update GUI
        [System.Windows.Forms.Application]::DoEvents()
        
        # Ermittle die Gesamtanzahl der Icons in shell32.dll
        $totalIconCount = Get-Shell32IconCount
        Write-Host "Gefundene Gesamtanzahl Icons in shell32.dll: $totalIconCount" -ForegroundColor Green
        
        $Window.TotalText.Text = "Insgesamt $totalIconCount Icons in shell32.dll gefunden"
        
        # Erstelle Array mit allen Icon-Indizes von 0 bis Gesamtanzahl-1
        $iconIndizes = 0..($totalIconCount - 1)
        
        $Window.StatusText.Text = "Lade alle $totalIconCount Icons aus shell32.dll..."
        
        # Update GUI
        [System.Windows.Forms.Application]::DoEvents()
        
        $loadedCount = 0
        $skippedCount = 0
        
        Write-Host "Starte das Laden von $totalIconCount Icons..." -ForegroundColor Green
        
        foreach ($iconIndex in $iconIndizes) {
            try {
                # Status aktualisieren alle 10 Icons für bessere Performance
                if ($iconIndex % 10 -eq 0) {
                    $progress = [math]::Round(($iconIndex / $totalIconCount) * 100)
                    $Window.StatusText.Text = "Lade Icon $iconIndex... ($progress%)"
                    $Window.CountText.Text = "Geladen: $loadedCount, Übersprungen: $skippedCount"
                    
                    # GUI aktualisieren
                    [System.Windows.Forms.Application]::DoEvents()
                }
                
                $icon = Get-Shell32Icon -IconIndex $iconIndex
                if ($icon -ne $null) {
                    $bitmapSource = ConvertTo-WpfBitmapSource -Icon $icon
                    if ($bitmapSource -ne $null) {
                        $iconPanel = New-IconPanel -IconIndex $iconIndex -ImageSource $bitmapSource
                        $Window.IconGrid.Children.Add($iconPanel) | Out-Null
                        $loadedCount++
                    } else {
                        $skippedCount++
                    }
                    # Icon nach Verwendung freigeben
                    $icon.Dispose()
                } else {
                    $skippedCount++
                }
            }
            catch {
                $skippedCount++
                if ($iconIndex % 50 -eq 0) {
                    Write-Warning "Fehler beim Laden von Icon $iconIndex : $_"
                }
            }
            
            # Micro-Pause für bessere GUI-Responsivität (nur alle 20 Icons)
            if ($iconIndex % 20 -eq 0) {
                Start-Sleep -Milliseconds 10
            }
        }
        
        $Window.StatusText.Text = "Vollständig abgeschlossen! Alle verfügbaren Icons geladen."
        $Window.CountText.Text = "Erfolgreich geladen: $loadedCount Icons"
        $Window.TotalText.Text = "Übersprungen: $skippedCount Icons"
        $Window.LoadButton.IsEnabled = $true
        $Window.LoadButton.Content = "Neu laden"
        
        Write-Host "Icon-Ladevorgang abgeschlossen:" -ForegroundColor Green
        Write-Host "- $loadedCount Icons erfolgreich geladen" -ForegroundColor Green
        Write-Host "- $skippedCount Icons übersprungen (nicht verfügbar)" -ForegroundColor Yellow
        Write-Host "- Gesamtanzahl verarbeitet: $totalIconCount" -ForegroundColor Cyan
        
    }
    catch {
        Write-Error "Fehler beim Laden der Icons: $_"
        $Window.StatusText.Text = "Fehler beim Laden der Icons"
        $Window.LoadButton.IsEnabled = $true
    }
}

# Hauptprogramm
try {
    Write-Host "🚀 Starte Shell32.dll Icon Viewer Demo (UTF-8 BOM Version)..." -ForegroundColor Cyan
    Write-Host "📋 Diese Version lädt ALLE verfügbaren Icons aus shell32.dll!" -ForegroundColor Yellow
    Write-Host "🔤 UTF-8 Encoding aktiviert für korrekte Umlaut-Darstellung (ä,ö,ü)" -ForegroundColor Green
    
    # WPF-Window erstellen
    $window = Convert-XAMLtoWindow -XAML $xaml
    
    if ($window -eq $null) {
        Write-Error "❌ Konnte WPF-Window nicht erstellen"
        return
    }
    
    Write-Host "✅ GUI erfolgreich erstellt mit korrekten Button-Templates" -ForegroundColor Green
    
    # Event-Handler für Buttons
    $window.LoadButton.add_Click({
        param($sender, $e)
        try {
            Load-AllIcons -Window $window
        }
        catch {
            Write-Error "Fehler beim Laden der Icons: $_"
        }
    })
    
    $window.ExitButton.add_Click({
        param($sender, $e)
        try {
            Write-Host "👋 Anwendung wird beendet..." -ForegroundColor Yellow
            $window.Close()
        }
        catch {
            Write-Error "Fehler beim Schließen: $_"
        }
    })
    
    # Fenster-Icon setzen
    try {
        $windowIcon = Get-Shell32Icon -IconIndex 3  # Ordner-Icon
        if ($windowIcon -ne $null) {
            $windowIconSource = ConvertTo-WpfBitmapSource -Icon $windowIcon
            if ($windowIconSource -ne $null) {
                $window.Icon = $windowIconSource
            }
            $windowIcon.Dispose()
        }
    }
    catch {
        Write-Warning "⚠️ Konnte Fenster-Icon nicht setzen: $_"
    }
    
    Write-Host "🎯 Demo-Anwendung gestartet!" -ForegroundColor Green
    Write-Host "💡 Klicke auf 'Alle Icons laden' um ALLE Icons aus shell32.dll anzuzeigen" -ForegroundColor Yellow
    Write-Host "⏰ ACHTUNG: Das Laden aller Icons kann 1-2 Minuten dauern!" -ForegroundColor Red
    Write-Host "🖱️ Klicke auf Icons für Detailinformationen" -ForegroundColor Yellow
    Write-Host "🎨 Teste die neuen Button-Hover-Effekte!" -ForegroundColor Magenta
    
    # Fenster anzeigen
    $result = $window.ShowDialog()
    
    Write-Host "✅ Fenster erfolgreich geschlossen" -ForegroundColor Green
}
catch {
    Write-Error "❌ Kritischer Fehler beim Ausführen der Anwendung: $_"
    Write-Error $_.Exception.ToString()
}
finally {
    # Cleanup
    Write-Host "🏁 Demo-Anwendung sauber beendet" -ForegroundColor Cyan
}