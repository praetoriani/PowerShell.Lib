# Demo-WPF-Anwendung mit Ubuntu-Schriftart in PowerShell

# 1. Benötigte Assemblies laden
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# 2. Schriftart herunterladen (nur bei Erstausführung notwendig)
$fontUrl = "https://github.com/google/fonts/raw/main/ufl/ubuntu/Ubuntu-Regular.ttf"
$fontPath = Join-Path $PSScriptRoot "data\fonts\Ubuntu-Regular.ttf"

if (-not (Test-Path $fontPath)) {
    New-Item -ItemType Directory -Path (Split-Path $fontPath) -Force | Out-Null
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontPath
}

# 3. WPF-Fenster erstellen
$window = New-Object System.Windows.Window
$window.Title = "Ubuntu Schriftart Demo"
$window.Width = 600
$window.Height = 400
$window.WindowStartupLocation = "CenterScreen"

# 4. Container für das Layout
$grid = New-Object System.Windows.Controls.Grid
$window.Content = $grid

# 5. Schriftart als Ressource laden
$fontUri = New-Object System.Uri($fontPath, [System.UriKind]::Absolute)
$fontFamily = New-Object System.Windows.Media.FontFamily($fontUri.AbsoluteUri + "#Ubuntu")

# 6. UI-Elemente erstellen
$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.Margin = New-Object System.Windows.Thickness(20)

# Titel mit Ubuntu-Schriftart
$title = New-Object System.Windows.Controls.TextBlock
$title.Text = "PowerShell WPF mit Ubuntu-Schriftart"
$title.FontSize = 24
$title.FontFamily = $fontFamily
$title.Margin = New-Object System.Windows.Thickness(0,0,0,20)

# Standard-Schriftart zum Vergleich
$defaultText = New-Object System.Windows.Controls.TextBlock
$defaultText.Text = "Standard Windows Schriftart"
$defaultText.FontSize = 24
$defaultText.Margin = New-Object System.Windows.Thickness(0,0,0,40)

# Formatierter Textblock
$loremIpsum = New-Object System.Windows.Controls.TextBlock
$loremIpsum.Text = @"
Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
"@
$loremIpsum.TextWrapping = "Wrap"
$loremIpsum.FontSize = 16
$loremIpsum.FontFamily = $fontFamily

# 7. Elemente hinzufügen
$stackPanel.Children.Add($title) | Out-Null
$stackPanel.Children.Add($defaultText) | Out-Null
$stackPanel.Children.Add($loremIpsum) | Out-Null
$grid.Children.Add($stackPanel) | Out-Null

# 8. Fenster anzeigen
$window.ShowDialog() | Out-Null
