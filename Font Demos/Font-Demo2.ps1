# Demo-WPF-Anwendung mit Ubuntu-Schriftart und XAML-Markup

# 1. Benötigte Assemblies laden
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# 2. Schriftart herunterladen (nur bei Erstausführung)
$fontUrl = "https://github.com/google/fonts/raw/main/ufl/ubuntu/Ubuntu-Regular.ttf"
$fontDir = Join-Path $PSScriptRoot "data\fonts"
$fontPath = Join-Path $fontDir "Ubuntu-Regular.ttf"

if (-not (Test-Path $fontPath)) {
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontPath
}

# 3. XAML-Definition mit Schriftart-Ressource
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Ubuntu Schriftart Demo" 
    Width="600" 
    Height="400"
    WindowStartupLocation="CenterScreen">
    
    <Window.Resources>
        <FontFamily x:Key="UbuntuFont">pack://siteoforigin:,,,/Fonts/Ubuntu-Regular.ttf#Ubuntu</FontFamily>
    </Window.Resources>
    
    <Grid>
        <StackPanel Margin="20">
            <!-- Titel mit Ubuntu-Schrift -->
            <TextBlock 
                Text="PowerShell WPF mit Ubuntu-Schriftart" 
                FontSize="24"
                FontFamily="{StaticResource UbuntuFont}"
                Margin="0,0,0,20"/>
            
            <!-- Standard-Schriftart zum Vergleich -->
            <TextBlock 
                Text="Standard Windows Schriftart"
                FontSize="24"
                Margin="0,0,0,40"/>
            
            <!-- Formatierter Textblock -->
            <TextBlock 
                Text="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                TextWrapping="Wrap"
                FontSize="16"
                FontFamily="{StaticResource UbuntuFont}"/>
        </StackPanel>
    </Grid>
</Window>
"@

# 4. XAML-Verarbeitung und Fenster erstellen
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# 5. Schriftart dynamisch laden (falls benötigt)
$window.Add_Loaded({
    $ubuntuFont = New-Object System.Windows.Media.FontFamily(
        "pack://siteoforigin:,,,/Fonts/Ubuntu-Regular.ttf#Ubuntu"
    )
})

# 6. Fenster anzeigen
$window.ShowDialog() | Out-Null
