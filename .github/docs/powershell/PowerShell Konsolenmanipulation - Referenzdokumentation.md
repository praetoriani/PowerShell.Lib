# PowerShell Konsolenmanipulation – Vollständige Referenzdokumentation

**Erstellt:** April 2026  
**Zielgruppe:** Entwickler von PowerShell Mini-Programmen & Skripten  
**Umgebung:** Windows 10/11, PowerShell 5.1 & PowerShell 7.x, Windows Terminal

---

## Inhaltsverzeichnis

1. [Fenstergröße, Titel & Anwendungsicon](#1-fenstergröße-titel--anwendungsicon)
2. [Erweiterte Farben – ANSI / VT100 / RGB True Color](#2-erweiterte-farben--ansi--vt100--rgb-true-color)
3. [Scrollbalken ausblenden](#3-scrollbalken-ausblenden)
4. [Erweiterte Schriftzeichen & Symbole (Unicode / Nerd Fonts)](#4-erweiterte-schriftzeichen--symbole-unicode--nerd-fonts)
5. [PowerShell-Konsole in WPF/XAML einbetten](#5-powershell-konsole-in-wpfxaml-einbetten)
6. [Konsolenfenster ausblenden & einblenden](#6-konsolenfenster-ausblenden--einblenden)
7. [Grafiken & Icons in der Konsole darstellen](#7-grafiken--icons-in-der-konsole-darstellen)
8. [Eigene Schriftarten in der Konsole verwenden](#8-eigene-schriftarten-in-der-konsole-verwenden)
9. [Animationen in der Konsole – Ladebalken & Fortschrittsanzeigen](#9-animationen-in-der-konsole--ladebalken--fortschrittsanzeigen)
10. [Kompatibilitätsmatrix & Best Practices](#10-kompatibilitätsmatrix--best-practices)

---

## 1. Fenstergröße, Titel & Anwendungsicon

### 1.1 Fenstergröße anpassen

Die Konsolenfenstergröße lässt sich über das `$Host.UI.RawUI`-Objekt steuern. Dieses Objekt stellt direkte Zugriffsmöglichkeiten auf die Puffer- und Fenstergröße der Konsole bereit.

**Wichtige Begriffe:**

| Begriff | Beschreibung |
|---------|-------------|
| `BufferSize` | Größe des gesamten Textpuffers (Scrollbereich, in Zeichen) |
| `WindowSize` | Sichtbarer Bereich des Konsolenfensters (in Zeichen) |
| `WindowPosition` | Position des sichtbaren Bereiches innerhalb des Puffers |

> **Wichtig:** `WindowSize` darf niemals größer als `BufferSize` sein – sonst wirft PowerShell eine Ausnahme. Puffergröße immer zuerst setzen!

```powershell
# ── Fenstergröße & Puffergröße anpassen ──────────────────────────────────────

function Set-ConsoleSize {
    param(
        [int]$Width  = 120,
        [int]$Height = 40,
        [int]$BufferHeight = 3000
    )

    $rawUI = $Host.UI.RawUI

    # Puffer zuerst setzen (muss >= Fenstergröße sein)
    $bufferSize = New-Object System.Management.Automation.Host.Size($Width, $BufferHeight)
    $rawUI.BufferSize = $bufferSize

    # Dann Fenstergröße setzen
    $windowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
    $rawUI.WindowSize = $windowSize
}

Set-ConsoleSize -Width 130 -Height 45 -BufferHeight 5000
```

**Fenstergröße in Pixel via Win32 API** (präzise Kontrolle):

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$hwnd = [ConsoleWindow]::GetConsoleWindow()

# Fenster auf 1000x600 Pixel setzen, Position (100, 100)
[ConsoleWindow]::MoveWindow($hwnd, 100, 100, 1000, 600, $true) | Out-Null
```

### 1.2 Konsolentitel ändern

Der Konsolentitel ist eine der einfachsten Anpassungen in PowerShell:

```powershell
# Methode 1: Über $Host-Objekt (universell, empfohlen)
$Host.UI.RawUI.WindowTitle = "Mein PowerShell Tool v1.0"

# Methode 2: Über .NET Console-Klasse
[Console]::Title = "CSV → XLSX Konverter"

# Methode 3: Über VT/ANSI Escape Sequence (nur Windows Terminal / VT-fähige Terminals)
# ESC]0;<string>ST  →  Setzt Titel (OSC 0) oder nur den Tab-Titel (OSC 2)
$ESC = [char]27
Write-Host "${ESC}]0;Mein Tool`a" -NoNewline

# Dynamischer Titel mit Fortschritt
function Update-ConsoleTitle {
    param([string]$Operation, [int]$Progress = -1)
    if ($Progress -ge 0) {
        $Host.UI.RawUI.WindowTitle = "$Operation [$Progress%]"
    } else {
        $Host.UI.RawUI.WindowTitle = $Operation
    }
}
```

### 1.3 Anwendungsicon des Konsolenfensters

Das Icon des nativen `conhost.exe`-Fensters lässt sich **nicht direkt über PowerShell-Bordmittel** ändern – das Fenster gehört dem Host-Prozess (`conhost.exe` oder `WindowsTerminal.exe`). Es gibt jedoch zwei Wege:

**Weg A: Eigene `.exe`-Wrapper-Datei mit Icon**

Das PowerShell-Skript wird über eine kompilierte `.exe` gestartet, die ein benutzerdefiniertes Icon trägt:

```powershell
# Skript als .exe kompilieren mit PS2EXE (Modul installieren: Install-Module ps2exe)
# Dann:
ps2exe -inputFile "MeinSkript.ps1" `
       -outputFile "MeinTool.exe" `
       -iconFile "MeinIcon.ico" `
       -title "Mein Tool" `
       -version "1.0.0.0"
```

**Weg B: WPF-Fenster als Host verwenden (empfohlen für professionelle Tools)**

Sobald das Skript eine WPF-Oberfläche startet (siehe Abschnitt 5), lässt sich das Icon trivial setzen:

```powershell
Add-Type -AssemblyName PresentationFramework
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Mein Tool"
        Icon="C:\Icons\mytool.ico"
        Width="800" Height="600">
    <Grid/>
</Window>
"@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.ShowDialog() | Out-Null
```

**Weg C: Icon via Win32 API direkt setzen**

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IconChanger {
    public const int GCL_HICON   = -14;
    public const int GCL_HICONSM = -34;
    public const int ICON_SMALL  = 0;
    public const int ICON_BIG    = 1;
    public const int WM_SETICON  = 0x80;

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern IntPtr LoadImage(IntPtr hInstance, string lpszName, uint uType,
                                           int cxDesired, int cyDesired, uint fuLoad);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

$hwnd = [IconChanger]::GetConsoleWindow()
# Lade Icon aus Datei (IMAGE_ICON = 1, LR_LOADFROMFILE = 0x10)
$hIcon = [IconChanger]::LoadImage([IntPtr]::Zero, "C:\Icons\mytool.ico", 1, 0, 0, 0x10)
[IconChanger]::SendMessage($hwnd, [IconChanger]::WM_SETICON, [IconChanger]::ICON_BIG,    $hIcon) | Out-Null
[IconChanger]::SendMessage($hwnd, [IconChanger]::WM_SETICON, [IconChanger]::ICON_SMALL,  $hIcon) | Out-Null
```

---

## 2. Erweiterte Farben – ANSI / VT100 / RGB True Color

### 2.1 Grundlagen: VT/ANSI Escape Sequenzen

Moderne Windows-Terminals (Windows 10 v1607+, Windows 11, Windows Terminal) unterstützen ANSI/VT100 Escape-Sequenzen. Im nativen `conhost.exe` muss dieser Modus aktiviert werden, in **Windows Terminal** und **PowerShell 7** ist er standardmäßig aktiv.

**VT-Modus für conhost.exe aktivieren:**

```powershell
# VT-Verarbeitung für den aktuellen Konsolenpuffer aktivieren
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class VTConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    
    public const int  STD_OUTPUT_HANDLE             = -11;
    public const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
}
"@

$stdOut = [VTConsole]::GetStdHandle([VTConsole]::STD_OUTPUT_HANDLE)
$mode   = 0
[VTConsole]::GetConsoleMode($stdOut, [ref]$mode) | Out-Null
[VTConsole]::SetConsoleMode($stdOut, $mode -bor [VTConsole]::ENABLE_VIRTUAL_TERMINAL_PROCESSING) | Out-Null
```

### 2.2 ANSI Standard-Farben (16 Farben)

```powershell
$ESC = [char]27

# Vordergrundfarben (30–37 Standard, 90–97 Bright/Hell)
# Hintergrundfarben (40–47 Standard, 100–107 Bright/Hell)

Write-Host "${ESC}[31mRoter Text${ESC}[0m"           # Rot
Write-Host "${ESC}[92mHelles Grün${ESC}[0m"          # Bright Green
Write-Host "${ESC}[41mRoter Hintergrund${ESC}[0m"    # Roter BG
Write-Host "${ESC}[1;33mFett + Gelb${ESC}[0m"        # Bold + Gelb

# Textformatierung
Write-Host "${ESC}[1mFett${ESC}[0m"
Write-Host "${ESC}[4mUnterstrichen${ESC}[0m"
Write-Host "${ESC}[7mInvertiert${ESC}[0m"
Write-Host "${ESC}[9mDurchgestrichen${ESC}[0m"
Write-Host "${ESC}[3mKursiv${ESC}[0m"                # Nur in manchen Terminals
```

### 2.3 256-Farb-Palette

```powershell
# Syntax: ESC[38;5;<n>m  → Vordergrund (n = 0-255)
#         ESC[48;5;<n>m  → Hintergrund (n = 0-255)

function Write-Color256 {
    param([string]$Text, [int]$FgColor, [int]$BgColor = -1)
    $ESC = [char]27
    $fg  = "${ESC}[38;5;${FgColor}m"
    $bg  = if ($BgColor -ge 0) { "${ESC}[48;5;${BgColor}m" } else { "" }
    Write-Host "${fg}${bg}${Text}${ESC}[0m" -NoNewline
}

Write-Color256 -Text " Erfolg! " -FgColor 46  -BgColor 22   # Grün auf dunkelgrün
Write-Color256 -Text " Warnung " -FgColor 214 -BgColor 52   # Orange auf dunkelrot
Write-Color256 -Text " Fehler  " -FgColor 196 -BgColor 88   # Hellrot auf dunkelrot

# 256-Farbpalette ausgeben (Übersicht)
for ($i = 0; $i -lt 256; $i++) {
    $ESC = [char]27
    Write-Host "${ESC}[48;5;${i}m  ${i.ToString().PadLeft(3)}  ${ESC}[0m" -NoNewline
    if (($i + 1) % 16 -eq 0) { Write-Host "" }
}
```

**Farbgruppen der 256-Farb-Palette:**

| Bereich | Farben | Beschreibung |
|---------|--------|-------------|
| 0–7 | Standard | 8 Basis-Farben (System-abhängig) |
| 8–15 | Bright | 8 helle Varianten |
| 16–231 | 6×6×6 Würfel | RGB-Farbraum, 216 Farben |
| 232–255 | Graustufen | 24-Stufen Grau von Schwarz zu Weiß |

### 2.4 True Color (24-Bit RGB)

```powershell
# Syntax: ESC[38;2;<r>;<g>;<b>m  → Vordergrund
#         ESC[48;2;<r>;<g>;<b>m  → Hintergrund
# Benötigt: Windows Terminal, PowerShell 7 oder conhost.exe mit ENABLE_VIRTUAL_TERMINAL_PROCESSING

function Write-RGBText {
    param(
        [string]$Text,
        [int]$FR = 255, [int]$FG = 255, [int]$FB = 255,   # Vordergrund RGB
        [int]$BR = -1,  [int]$BG = -1,  [int]$BB = -1     # Hintergrund RGB (-1 = kein)
    )
    $ESC  = [char]27
    $fg   = "${ESC}[38;2;${FR};${FG};${FB}m"
    $bg   = if ($BR -ge 0) { "${ESC}[48;2;${BR};${BG};${BB}m" } else { "" }
    Write-Host "${fg}${bg}${Text}${ESC}[0m" -NoNewline
}

Write-RGBText -Text "Perfektes Türkis" -FR 0 -FG 180 -FB 170
Write-RGBText -Text " " -NoNewline   # Neue Zeile
Write-Host ""

# Regenbogen-Gradient Effekt
function Write-Rainbow {
    param([string]$Text)
    $ESC  = [char]27
    $len  = $Text.Length
    for ($i = 0; $i -lt $len; $i++) {
        $hue = ($i / $len) * 360
        # HSV zu RGB (vereinfacht)
        $r = [Math]::Round(127.5 + 127.5 * [Math]::Cos([Math]::PI * $hue / 180))
        $g = [Math]::Round(127.5 + 127.5 * [Math]::Cos([Math]::PI * ($hue - 120) / 180))
        $b = [Math]::Round(127.5 + 127.5 * [Math]::Cos([Math]::PI * ($hue - 240) / 180))
        Write-Host "${ESC}[38;2;${r};${g};${b}m$($Text[$i])${ESC}[0m" -NoNewline
    }
    Write-Host ""
}

Write-Rainbow "PowerShell True Color Rainbow Text!"
```

---

## 3. Scrollbalken ausblenden

Das vollständige Ausblenden von Scrollbalken in einer nativen Konsole ist **technisch möglich, aber komplex**, da es direkt ins Win32-Fenstersystem eingreift.

### 3.1 Scrollbalken via Win32 API ausblenden

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ScrollBarHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowScrollBar(IntPtr hWnd, int wBar, bool bShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    // wBar Konstanten
    public const int SB_HORZ = 0;   // Horizontaler Scrollbalken
    public const int SB_VERT = 1;   // Vertikaler Scrollbalken  
    public const int SB_BOTH = 3;   // Beide Scrollbalken
}
"@

function Hide-ConsoleScrollBars {
    $hwnd = [ScrollBarHelper]::GetConsoleWindow()
    [ScrollBarHelper]::ShowScrollBar($hwnd, [ScrollBarHelper]::SB_BOTH, $false) | Out-Null
    Write-Host "Scrollbalken ausgeblendet."
}

function Show-ConsoleScrollBars {
    $hwnd = [ScrollBarHelper]::GetConsoleWindow()
    [ScrollBarHelper]::ShowScrollBar($hwnd, [ScrollBarHelper]::SB_BOTH, $true) | Out-Null
    Write-Host "Scrollbalken eingeblendet."
}

Hide-ConsoleScrollBars
```

> **Hinweis:** Diese Methode funktioniert nur bei klassischem `conhost.exe`. In **Windows Terminal** werden Scrollbalken durch den Terminal-Stil kontrolliert und können nur über die Terminaleinstellungen (`settings.json`) beeinflusst werden. In Windows Terminal kann `"scrollbarState": "hidden"` in der Profilkonfiguration gesetzt werden.

### 3.2 Scrollbalken-Verhalten über Puffergröße kontrollieren

Ein indirekter Weg: Wenn die `BufferSize.Height` gleich der `WindowSize.Height` gesetzt wird, verschwindet der vertikale Scrollbalken – da kein überlaufender Inhalt existiert:

```powershell
function Disable-VerticalScrollBuffer {
    $rawUI      = $Host.UI.RawUI
    $winHeight  = $rawUI.WindowSize.Height
    $winWidth   = $rawUI.WindowSize.Width
    # Pufferhöhe = Fensterhöhe → kein Scroll möglich → Scrollbalken verschwindet
    $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($winWidth, $winHeight)
}
```

---

## 4. Erweiterte Schriftzeichen & Symbole (Unicode / Nerd Fonts)

### 4.1 Unicode-Zeichen ausgeben

PowerShell unterstützt Unicode nativ. Wichtig ist, dass die richtige Codepage und eine kompatible Schriftart gesetzt sind:

```powershell
# Encoding auf UTF-8 setzen
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# Unicode-Zeichen via Escape (PowerShell 6+)
Write-Host "`u{2714}"   # ✔  Häkchen
Write-Host "`u{2718}"   # ✘  X-Zeichen
Write-Host "`u{2192}"   # →  Pfeil rechts
Write-Host "`u{2665}"   # ♥  Herz
Write-Host "`u{26A0}"   # ⚠  Warnung
Write-Host "`u{2139}"   # ℹ  Info
Write-Host "`u{1F4C1}"  # 📁 Ordner
Write-Host "`u{1F680}"  # 🚀 Rakete

# In PowerShell 5.1 (ältere Syntax)
[char]0x2714   # ✔
[char]0x2718   # ✘
```

### 4.2 Box-Drawing Zeichen für Rahmen & Layout

```powershell
# Box-Drawing Zeichen (Unicode Block: 2500–257F)
function Draw-Box {
    param(
        [string]$Title   = "Mein Tool",
        [int]   $Width   = 50,
        [string]$BgColor = "48;2;30;30;50",   # Optional: RGB Hintergrund
        [string]$FgColor = "38;2;100;200;255"  # Optional: RGB Vordergrund
    )
    $ESC  = [char]27
    $col  = "${ESC}[${FgColor}m"
    $rst  = "${ESC}[0m"
    $line = "─" * ($Width - 2)

    $titlePad   = $Title.PadRight($Width - 4).Substring(0, [Math]::Min($Title.Length, $Width - 4))
    $emptyLine  = " " * ($Width - 2)

    Write-Host "${col}┌${line}┐${rst}"
    Write-Host "${col}│ ${titlePad.PadRight($Width - 4)} │${rst}"
    Write-Host "${col}├${line}┤${rst}"
    Write-Host "${col}│ ${emptyLine} │${rst}"
    Write-Host "${col}└${line}┘${rst}"
}

Draw-Box -Title "CSV → XLSX Konverter" -Width 52

# Weitere Box-Varianten (Doppellinien)
# ╔═══╗  ╚═══╝  ║   ║  ╠═══╣  ╦  ╩  ╬
# Einfache Linien: ┌┐└┘│─├┤┬┴┼
```

### 4.3 Nerd Fonts – Icon-Symbole für die Konsole

Nerd Fonts sind reguläre Schriftarten, die mit tausenden Icons aus Iconfont-Sets wie FontAwesome, Material Design Icons, Devicons etc. erweitert wurden. Sie werden über private Unicode-Bereiche (PUA) eingebettet.

**Installation:**

1. Von [nerdfonts.com](https://www.nerdfonts.com/font-downloads) herunterladen (empfohlen: `CaskaydiaCove Nerd Font`, `JetBrainsMono Nerd Font`, `Hack Nerd Font`)
2. Font installieren (Rechtsklick → "Für alle Benutzer installieren")
3. In der Konsole als Schriftart auswählen (Abschnitt 8)

```powershell
# Beispiele für Nerd Font Zeichen (erfordern installierte Nerd Font)
# PowerShell Icon
Write-Host "`u{E0A0} "       # Branch-Symbol (Git)
Write-Host "`u{F015} Home"   # FontAwesome Haus
Write-Host "`u{F07B} Folder" # FontAwesome Ordner
Write-Host "`u{F00C} OK"     # FontAwesome Checkmark
Write-Host "`u{F00D} Error"  # FontAwesome X
Write-Host "`u{E0B0}"        # Powerline Pfeil-rechts

# Prüfen ob Nerd Font aktiv ist
function Test-NerdFont {
    $testChar = "`u{E0B0}"
    Write-Host "Test: ${testChar}" -NoNewline
    Write-Host " (Wenn ein Dreieck erscheint, ist Nerd Font aktiv)"
}
```

### 4.4 Braille-Zeichen für Textkonsolen-Grafiken

```powershell
# Braille-Zeichen können für einfache ASCII-Art-ähnliche Grafiken verwendet werden
# Unicode: 2800-28FF (256 Kombinationen)

# Balkendiagramm mit Braille
function Write-BrailleBar {
    param([int]$Percent, [int]$Width = 20)
    $filled = [Math]::Round($Percent / 100 * $Width)
    $bar    = ("⣿" * $filled).PadRight($Width)
    Write-Host "[$bar] $Percent%"
}

Write-BrailleBar -Percent 75
```

---

## 5. PowerShell-Konsole in WPF/XAML einbetten

### 5.1 Konzept: Hybride PowerShell/WPF-Anwendung

Es gibt zwei grundlegend verschiedene Ansätze, eine WPF-Oberfläche in Verbindung mit PowerShell-Konsolenoutput zu kombinieren:

**Ansatz A: WPF-Fenster mit `TextBox`/`RichTextBox` als Konsolenerssatz** (empfohlen)  
**Ansatz B: Natives Konsolenfenster via Win32 API in ein WPF-Fenster einbetten** (technisch anspruchsvoll)

### 5.2 Ansatz A: WPF-RichTextBox als Konsolenausgabe (Empfohlen)

Dieser Ansatz ersetzt die Konsolenausgabe durch eine farbfähige WPF-`RichTextBox`. Er ist professionell, stabil und vollständig anpassbar:

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Tool" Width="900" Height="600"
        Background="#1E1E2E" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Margin" Value="4"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Toolbar -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Background="#181825" Margin="0">
            <Button Name="btnRun"   Content="▶ Ausführen"/>
            <Button Name="btnClear" Content="✖ Löschen"/>
            <Button Name="btnExport" Content="💾 Export"/>
        </StackPanel>

        <!-- Konsolenausgabe (RichTextBox) -->
        <RichTextBox Name="rtbConsole" Grid.Row="1"
                     Background="#11111B" Foreground="#CDD6F4"
                     FontFamily="Cascadia Code, Consolas, Courier New"
                     FontSize="13" IsReadOnly="True"
                     BorderThickness="0" Margin="8"
                     VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto"/>

        <!-- Statusleiste -->
        <StatusBar Grid.Row="2" Background="#181825">
            <TextBlock Name="tbStatus" Text="Bereit" Foreground="#A6E3A1" Margin="8,0"/>
        </StatusBar>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$rtbConsole = $window.FindName("rtbConsole")
$tbStatus   = $window.FindName("tbStatus")
$btnRun     = $window.FindName("btnRun")
$btnClear   = $window.FindName("btnClear")

# Funktion: Text farbig in RichTextBox schreiben
function Write-RTB {
    param(
        [string]$Text,
        [string]$Color     = "#CDD6F4",   # Standard: helles Blau (Catppuccin)
        [string]$BgColor   = "",
        [switch]$Bold,
        [switch]$NewLine
    )
    $para      = New-Object System.Windows.Documents.Paragraph
    $run       = New-Object System.Windows.Documents.Run($Text)
    $run.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
    if ($Bold)    { $run.FontWeight = [System.Windows.FontWeights]::Bold }
    $para.Inlines.Add($run)
    $para.Margin = New-Object System.Windows.Thickness(0)
    $rtbConsole.Document.Blocks.Add($para)
    # Auto-Scroll ans Ende
    $rtbConsole.ScrollToEnd()
}

# Button-Events
$btnRun.Add_Click({
    Write-RTB "▶ Starte Operation..." -Color "#89B4FA" -Bold
    Write-RTB "  [OK] Schritt 1 abgeschlossen" -Color "#A6E3A1"
    Write-RTB "  [OK] Schritt 2 abgeschlossen" -Color "#A6E3A1"
    Write-RTB "  [⚠] Schritt 3: Warnung erkannt" -Color "#F9E2AF"
    Write-RTB "✔ Fertig!" -Color "#A6E3A1" -Bold
    $tbStatus.Text = "Abgeschlossen"
})

$btnClear.Add_Click({
    $rtbConsole.Document.Blocks.Clear()
    $tbStatus.Text = "Bereit"
})

# Initiale Ausgabe
Write-RTB "PowerShell Tool gestartet." -Color "#89DCEB"
Write-RTB "Klicke 'Ausführen' um zu starten." -Color "#6C7086"

$window.ShowDialog() | Out-Null
```

### 5.3 Ansatz B: Natives Konsolenfenster in WPF einbetten (Win32 API)

Dieser Ansatz ist technisch anspruchsvoll und embettet ein echtes Konsolenfenster via `SetParent` in ein WPF-HwndHost-Panel:

```powershell
# Konzept (vereinfacht – vollständige Implementierung erfordert C#-Klasse):
# 1. WPF-Fenster erstellen
# 2. HwndHost-Klasse implementieren (erfordert C#-Kompilierung in PowerShell)
# 3. CreateConPTY oder AllocConsole aufrufen
# 4. Konsolenfenster via SetParent() in WPF einbetten
# 5. Größenanpassung via MoveWindow() bei WPF-Resize-Events

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

public class ConsoleEmbedder : HwndHost {
    [DllImport("kernel32.dll")]
    public static extern bool AllocConsole();
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    
    [DllImport("user32.dll")]
    public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    
    public const int GWL_STYLE   = -16;
    public const int WS_CHILD    = 0x40000000;
    public const int WS_BORDER   = 0x00800000;
    
    private IntPtr _consoleHwnd;
    
    protected override HandleRef BuildWindowCore(HandleRef hwndParent) {
        AllocConsole();
        _consoleHwnd = GetConsoleWindow();
        SetParent(_consoleHwnd, hwndParent.Handle);
        SetWindowLong(_consoleHwnd, GWL_STYLE, WS_CHILD | WS_BORDER);
        return new HandleRef(this, _consoleHwnd);
    }
    
    protected override void DestroyWindowCore(HandleRef hwnd) { }
}
"@ -ReferencedAssemblies "PresentationFramework", "PresentationCore", "WindowsBase"

# Hinweis: Diese Methode hat Einschränkungen – das eingebettete Fenster
# reagiert möglicherweise nicht korrekt auf alle WPF-Layout-Änderungen.
# Für produktive Anwendungen ist Ansatz A (RichTextBox) deutlich stabiler.
```

---

## 6. Konsolenfenster ausblenden & einblenden

### 6.1 ShowWindow API – Vollständige Implementierung

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WindowVisibility {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    // ShowWindow Konstanten
    public const int SW_HIDE             = 0;   // Vollständig unsichtbar
    public const int SW_SHOWNORMAL       = 1;   // Normal anzeigen
    public const int SW_SHOWMINIMIZED    = 2;   // Minimiert
    public const int SW_SHOWMAXIMIZED    = 3;   // Maximiert
    public const int SW_SHOWNOACTIVATE   = 4;   // Anzeigen ohne Fokus
    public const int SW_SHOW             = 5;   // Anzeigen (aktiv)
    public const int SW_MINIMIZE         = 6;   // Minimieren
    public const int SW_SHOWMINNOACTIVE  = 7;   // Minimiert ohne Fokus
    public const int SW_SHOWNA           = 8;   // Anzeigen ohne Änderung
    public const int SW_RESTORE          = 9;   // Wiederherstellen
}
"@

function Hide-ConsoleWindow {
    <#
    .SYNOPSIS
        Blendet das PowerShell-Konsolenfenster vollständig aus (unsichtbar).
    .DESCRIPTION
        Nutzt die Win32 ShowWindow API mit SW_HIDE (0) um das Fenster zu verbergen.
        Das Skript läuft im Hintergrund weiter – das Fenster ist nur nicht mehr sichtbar.
    #>
    $hwnd = [WindowVisibility]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        [WindowVisibility]::ShowWindow($hwnd, [WindowVisibility]::SW_HIDE) | Out-Null
        Write-Verbose "Konsolenfenster ausgeblendet (HWND: $hwnd)"
    }
}

function Show-ConsoleWindow {
    <#
    .SYNOPSIS
        Blendet das PowerShell-Konsolenfenster wieder ein (sichtbar).
    .DESCRIPTION
        Nutzt die Win32 ShowWindow API mit SW_SHOW (5) um das Fenster wieder anzuzeigen.
    .PARAMETER State
        Anzeigemodus: Normal, Maximized, Minimized
    #>
    param(
        [ValidateSet("Normal", "Maximized", "Minimized")]
        [string]$State = "Normal"
    )
    $hwnd = [WindowVisibility]::GetConsoleWindow()
    $cmd  = switch ($State) {
        "Normal"    { [WindowVisibility]::SW_SHOWNORMAL }
        "Maximized" { [WindowVisibility]::SW_SHOWMAXIMIZED }
        "Minimized" { [WindowVisibility]::SW_SHOWMINIMIZED }
    }
    if ($hwnd -ne [IntPtr]::Zero) {
        [WindowVisibility]::ShowWindow($hwnd, $cmd) | Out-Null
    }
}

# ── Verwendungsbeispiel ───────────────────────────────────────────────────────
# Typischer Anwendungsfall: Skript läuft im Hintergrund, 
# nur eine WPF-GUI ist sichtbar

Add-Type -AssemblyName PresentationFramework

# Konsole sofort ausblenden
Hide-ConsoleWindow

# WPF-Fenster starten
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Mein Tool" Width="600" Height="400"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Button Name="btnShowConsole" Content="Konsole anzeigen"
                HorizontalAlignment="Center" VerticalAlignment="Center"
                Padding="20,10"/>
    </Grid>
</Window>
"@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$btnShowConsole = $window.FindName("btnShowConsole")
$btnShowConsole.Add_Click({
    Show-ConsoleWindow -State Normal
})

# Wenn WPF-Fenster geschlossen wird → Konsole wieder anzeigen (optional)
$window.Add_Closed({
    Show-ConsoleWindow -State Normal
})

$window.ShowDialog() | Out-Null
```

### 6.2 Anwendungsfall: Skript ohne Konsolenfenster starten

Um ein PowerShell-Skript von Anfang an ohne Konsolenfenster zu starten:

```powershell
# Aus CMD oder Taskplaner starten (kein Konsolenfenster):
# powershell.exe -WindowStyle Hidden -File "C:\Scripts\MeinTool.ps1"

# Oder als .bat-Starter:
# @echo off
# powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "%~dp0MeinTool.ps1"
```

---

## 7. Grafiken & Icons in der Konsole darstellen

### 7.1 Technische Einschränkungen

Die Windows-Konsole ist ein **Zeichengitter** – sie stellt grundsätzlich nur Textzeichen dar. Echte pixelbasierte Grafiken sind nicht nativ möglich. Es gibt jedoch mehrere Techniken, die sich diesem Ziel annähern:

| Technik | Qualität | Terminal-Anforderung | Kompatibilität |
|---------|----------|---------------------|----------------|
| ASCII/Unicode Art | Sehr niedrig | Alle | Universell |
| Block Elements (▀▄█) | Niedrig | Unicode-fähig | Gut |
| Halbblockelemente + RGB | Mittel | VT + True Color | Windows Terminal, iTerm2 |
| Sixel-Grafiken | Hoch | Sixel-Unterstützung | Sehr eingeschränkt (nicht Windows Terminal standard) |
| Kitty Graphics Protocol | Sehr hoch | Kitty Terminal | Linux/Mac, nicht Windows |

### 7.2 Blockelement-Grafiken (Halbblock-Methode)

Mit den Unicode-Blockelementen `▀` (obere Hälfte) und `▄` (untere Hälfte) kombiniert mit True-Color-Hintergrundfarben lassen sich Bilder mit halber vertikaler Auflösung darstellen:

```powershell
# Prinzip: Jedes "Pixel" im Ausgabebild entspricht einem halben Zeichen
# ▀ mit FG=Pixel oben, BG=Pixel unten → 2 Pixel pro Zeile

function ConvertTo-ConsoleImage {
    param(
        [string]$ImagePath,
        [int]   $MaxWidth = 60   # In Zeichen (= 2x Breite in Pixeln)
    )

    Add-Type -AssemblyName System.Drawing
    $ESC = [char]27

    $img    = [System.Drawing.Bitmap]::new($ImagePath)
    $ratio  = $img.Height / $img.Width
    $width  = $MaxWidth
    $height = [Math]::Round($width * $ratio * 0.5)   # 0.5 wegen doppelter Pixeldichte

    $resized = New-Object System.Drawing.Bitmap($width, $height * 2)
    $g       = [System.Drawing.Graphics]::FromImage($resized)
    $g.DrawImage($img, 0, 0, $width, $height * 2)
    $g.Dispose()

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $topPixel    = $resized.GetPixel($x, $y * 2)
            $bottomPixel = $resized.GetPixel($x, $y * 2 + 1)

            $fg = "${ESC}[38;2;$($topPixel.R);$($topPixel.G);$($topPixel.B)m"
            $bg = "${ESC}[48;2;$($bottomPixel.R);$($bottomPixel.G);$($bottomPixel.B)m"
            Write-Host "${fg}${bg}▀${ESC}[0m" -NoNewline
        }
        Write-Host ""
    }

    $resized.Dispose()
    $img.Dispose()
}

# Verwendung:
# ConvertTo-ConsoleImage -ImagePath "C:\Images\logo.png" -MaxWidth 80
```

### 7.3 Farbige Icons via Unicode + Farbe

```powershell
function Write-StatusIcon {
    param(
        [ValidateSet("Success", "Warning", "Error", "Info", "Running")]
        [string]$Type,
        [string]$Message
    )
    $ESC = [char]27
    $icon, $color = switch ($Type) {
        "Success" { "`u{2714}", "${ESC}[38;2;166;227;161m" }  # ✔ Grün
        "Warning" { "`u{26A0}", "${ESC}[38;2;249;226;175m" }  # ⚠ Gelb
        "Error"   { "`u{2718}", "${ESC}[38;2;243;139;168m" }  # ✘ Rot
        "Info"    { "`u{2139}", "${ESC}[38;2;137;180;250m" }  # ℹ Blau
        "Running" { "`u{25B6}", "${ESC}[38;2;203;166;247m" }  # ▶ Lila
    }
    Write-Host " ${color}${icon}${ESC}[0m $Message"
}

Write-StatusIcon -Type Success -Message "Datei erfolgreich konvertiert"
Write-StatusIcon -Type Warning -Message "Encoding-Problem erkannt"
Write-StatusIcon -Type Error   -Message "Datei nicht gefunden"
Write-StatusIcon -Type Info    -Message "Verarbeite 42 Dateien..."
Write-StatusIcon -Type Running -Message "Exportiere XLSX..."
```

---

## 8. Eigene Schriftarten in der Konsole verwenden

### 8.1 Einschränkungen & Anforderungen

Die Windows-Konsole (`conhost.exe`) akzeptiert **nur TrueType/OpenType-Schriftarten**, die als "Konsolen-kompatibel" registriert sind. Die Schriftart muss zusätzlich im Registry-Schlüssel `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont` eingetragen sein.

**Windows Terminal** hingegen akzeptiert jede auf dem System installierte Schriftart direkt über `settings.json`.

### 8.2 Schriftart für conhost.exe via Registry registrieren

```powershell
function Register-ConsoleFontForConhost {
    param(
        [string]$FontName   # Muss exakt dem Schriftnamen entsprechen
    )
    # Freie Zahlen im Registry-Schlüssel finden und neuen Eintrag hinzufügen
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    $existing = Get-ItemProperty -Path $regPath
    
    # Nächste freie Nummer nach 0 finden (0, 00, 000, ...)
    $i = 0
    do { $i++; $key = "0" * $i } while ($existing.PSObject.Properties.Name -contains $key)
    
    Set-ItemProperty -Path $regPath -Name $key -Value $FontName
    Write-Host "Schriftart '$FontName' unter Schlüssel '$key' registriert." -ForegroundColor Green
    Write-Host "Neustart des Konsolenfensters erforderlich."
}

# Beispiel: JetBrains Mono registrieren (muss installiert sein!)
# Register-ConsoleFontForConhost -FontName "JetBrainsMono Nerd Font"
```

### 8.3 Konsolenschriftart via Win32 API direkt setzen

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ConsoleFont {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFOEX {
        public uint   cbSize;
        public uint   nFont;
        public COORD  dwFontSize;
        public int    FontFamily;
        public int    FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct COORD {
        public short X;
        public short Y;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(
        IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    public const int STD_OUTPUT_HANDLE = -11;
}
"@

function Set-ConsoleFont {
    param(
        [string]$FontName   = "Cascadia Code",
        [int]   $FontSize   = 14,
        [int]   $FontWeight = 400  # 400 = Normal, 700 = Bold
    )

    $hOut = [ConsoleFont]::GetStdHandle([ConsoleFont]::STD_OUTPUT_HANDLE)
    
    $font                = New-Object ConsoleFont+CONSOLE_FONT_INFOEX
    $font.cbSize         = [System.Runtime.InteropServices.Marshal]::SizeOf($font)
    $font.nFont          = 0
    $font.dwFontSize     = New-Object ConsoleFont+COORD
    $font.dwFontSize.X   = 0
    $font.dwFontSize.Y   = $FontSize
    $font.FontFamily     = 54   # TMPF_TRUETYPE (0x04) | FF_MODERN (0x30)
    $font.FontWeight     = $FontWeight
    $font.FaceName       = $FontName

    $result = [ConsoleFont]::SetCurrentConsoleFontEx($hOut, $false, [ref]$font)
    if ($result) {
        Write-Host "Schriftart auf '$FontName' ($FontSize pt) gesetzt." -ForegroundColor Green
    } else {
        Write-Warning "Schriftart konnte nicht gesetzt werden. Prüfe ob die Schriftart installiert und im Registry registriert ist."
    }
}

Set-ConsoleFont -FontName "Cascadia Code" -FontSize 14
# Set-ConsoleFont -FontName "JetBrainsMono Nerd Font" -FontSize 13
```

### 8.4 Schriftart für Windows Terminal

In Windows Terminal wird die Schriftart direkt in der `settings.json` gesetzt – keine Registry-Einträge notwendig:

```json
{
    "profiles": {
        "defaults": {
            "font": {
                "face": "JetBrainsMono Nerd Font",
                "size": 13,
                "weight": "normal"
            }
        }
    }
}
```

Per PowerShell modifizierbar:

```powershell
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings.profiles.defaults | Add-Member -Force -NotePropertyName "font" -NotePropertyValue @{
        face   = "JetBrainsMono Nerd Font"
        size   = 13
        weight = "normal"
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Host "Windows Terminal Schriftart aktualisiert." -ForegroundColor Green
}
```

---

## 9. Animationen in der Konsole – Ladebalken & Fortschrittsanzeigen

### 9.1 Native PowerShell Write-Progress

```powershell
# Eingebauter Write-Progress – nutzt die native Fortschrittsleiste des Hosts
for ($i = 0; $i -le 100; $i += 2) {
    Write-Progress -Activity "Konvertiere CSV-Dateien" `
                   -Status "$i% abgeschlossen" `
                   -PercentComplete $i `
                   -CurrentOperation "Verarbeite Zeile $($i * 10)"
    Start-Sleep -Milliseconds 50
}
Write-Progress -Activity "Fertig" -Completed
```

### 9.2 Benutzerdefinierter RGB-Ladebalken

```powershell
function Show-ProgressBar {
    param(
        [string]$Label          = "Fortschritt",
        [int]   $Percent        = 0,
        [int]   $Width          = 40,
        [string]$FillColor      = "38;2;166;227;161",  # Grün (Catppuccin)
        [string]$EmptyColor     = "38;2;49;50;68",      # Dunkel
        [string]$TextColor      = "38;2;205;214;244",   # Hell
        [switch]$NoNewLine
    )
    $ESC      = [char]27
    $filled   = [Math]::Round($Percent / 100 * $Width)
    $empty    = $Width - $filled

    $bar  = "${ESC}[${FillColor}m" + ("█" * $filled)
    $bar += "${ESC}[${EmptyColor}m" + ("░" * $empty)
    $bar += "${ESC}[0m"

    $pct = "$Percent%".PadLeft(4)
    $lbl = $Label.PadRight(20)
    $line = " ${ESC}[${TextColor}m${lbl}${ESC}[0m [${bar}] ${ESC}[${TextColor}m${pct}${ESC}[0m"

    # Cursor an Zeilenanfang → Zeile überschreiben (in-place Update)
    Write-Host "`r${line}" -NoNewline
    if (-not $NoNewLine) { Write-Host "" }
}

# Fortschritt simulieren
Write-Host ""
for ($i = 0; $i -le 100; $i++) {
    Show-ProgressBar -Label "CSV einlesen" -Percent $i -NoNewLine
    Start-Sleep -Milliseconds 30
}
Write-Host ""
```

### 9.3 Spinner-Animation (Lade-Indikator)

```powershell
function Invoke-WithSpinner {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message = "Bitte warten..."
    )

    $ESC      = [char]27
    $spinners = @("⣾","⣽","⣻","⢿","⡿","⣟","⣯","⣷")
    # Alternative Spinner-Stile:
    # Klassisch:  @("|", "/", "-", "\")
    # Punkte:     @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    # Pfeile:     @("←","↖","↑","↗","→","↘","↓","↙")
    # Bouncing:   @("▁","▂","▃","▄","▅","▆","▇","█","▇","▆","▅","▄","▃","▂")
    
    $job     = Start-Job -ScriptBlock $ScriptBlock
    $i       = 0
    $color   = "${ESC}[38;2;137;180;250m"  # Blau

    [Console]::CursorVisible = $false
    try {
        while ($job.State -eq "Running") {
            $spin = $spinners[$i % $spinners.Count]
            Write-Host "`r ${color}${spin}${ESC}[0m $Message" -NoNewline
            Start-Sleep -Milliseconds 80
            $i++
        }
    } finally {
        [Console]::CursorVisible = $true
        Write-Host "`r${' ' * ($Message.Length + 5)}`r" -NoNewline  # Zeile löschen
    }

    $result = Receive-Job $job
    Remove-Job $job
    return $result
}

# Verwendung:
$ergebnis = Invoke-WithSpinner -Message "Verarbeite Daten..." -ScriptBlock {
    Start-Sleep -Seconds 3
    "Fertig!"
}
Write-Host "Ergebnis: $ergebnis"
```

### 9.4 Mehrstufige Fortschrittsanzeige mit Cursor-Positionierung

```powershell
function Show-MultiProgressBar {
    param(
        [hashtable[]]$Tasks  # Array von @{Name="..."; Percent=0}
    )
    $ESC = [char]27

    # Cursor-Steuerung
    # ESC[<n>A = Cursor n Zeilen hoch
    # ESC[<n>B = Cursor n Zeilen runter
    # ESC[2K   = Aktuelle Zeile löschen
    # ESC[?25l = Cursor ausblenden
    # ESC[?25h = Cursor einblenden

    Write-Host "${ESC}[?25l" -NoNewline   # Cursor ausblenden

    # Initial alle Balken ausgeben
    foreach ($task in $Tasks) {
        $pct    = $task.Percent
        $filled = [Math]::Round($pct / 100 * 30)
        $bar    = "${ESC}[38;2;166;227;161m" + ("█" * $filled) +
                  "${ESC}[38;2;49;50;68m" + ("░" * (30 - $filled)) + "${ESC}[0m"
        Write-Host " $($task.Name.PadRight(18)) [$bar] $($pct.ToString().PadLeft(3))%"
    }

    # Update-Schleife
    for ($step = 0; $step -le 100; $step += 5) {
        Start-Sleep -Milliseconds 100

        # Cursor zurück (Anzahl Tasks Zeilen hoch)
        Write-Host "${ESC}[$($Tasks.Count)A" -NoNewline

        foreach ($task in $Tasks) {
            $pct    = [Math]::Min(100, $step + (Get-Random -Min 0 -Max 10))
            $filled = [Math]::Round($pct / 100 * 30)
            $bar    = "${ESC}[38;2;166;227;161m" + ("█" * $filled) +
                      "${ESC}[38;2;49;50;68m" + ("░" * (30 - $filled)) + "${ESC}[0m"
            Write-Host "${ESC}[2K $($task.Name.PadRight(18)) [$bar] $($pct.ToString().PadLeft(3))%"
        }
    }

    Write-Host "${ESC}[?25h" -NoNewline   # Cursor einblenden
}

Show-MultiProgressBar -Tasks @(
    @{ Name = "CSV einlesen";      Percent = 0 },
    @{ Name = "Daten validieren";  Percent = 0 },
    @{ Name = "XLSX exportieren";  Percent = 0 }
)
```

### 9.5 Cursor-Kontrolle & Konsolenausgabe

```powershell
$ESC = [char]27

# ── Cursor-Positionierung ───────────────────────────────────────────────────
# Cursor an absolute Position setzen (Zeile, Spalte) – 1-basiert
Write-Host "${ESC}[5;10H" -NoNewline        # Zeile 5, Spalte 10

# Cursor speichern und wiederherstellen
Write-Host "${ESC}[s" -NoNewline            # Position speichern
Write-Host "Temporärer Text" -NoNewline
Write-Host "${ESC}[u" -NoNewline            # Position wiederherstellen

# Bildschirm löschen
Write-Host "${ESC}[2J${ESC}[H" -NoNewline   # Ganzen Bildschirm leeren + Cursor oben links
Write-Host "${ESC}[3J" -NoNewline           # Auch Scrollback-Puffer leeren

# Zeile löschen
Write-Host "${ESC}[2K" -NoNewline           # Aktuelle Zeile löschen
Write-Host "${ESC}[1K" -NoNewline           # Zeile bis Cursor löschen
Write-Host "${ESC}[0K" -NoNewline           # Zeile ab Cursor löschen

# Cursor ausblenden/einblenden
[Console]::CursorVisible = $false
[Console]::CursorVisible = $true
```

---

## 10. Kompatibilitätsmatrix & Best Practices

### 10.1 Kompatibilitätsmatrix

| Feature | conhost.exe (legacy) | Windows Terminal | PowerShell 7 | PowerShell 5.1 |
|---------|---------------------|-----------------|-------------|---------------|
| 16 ANSI-Farben | ✔ (ab Win 10 v1607) | ✔ | ✔ | ✔ (nach VT-Aktivierung) |
| 256-Farben | ✔ (nach VT-Aktivierung) | ✔ | ✔ | ✔ (nach VT-Aktivierung) |
| True Color (24-bit) | ✔ (nach VT-Aktivierung) | ✔ | ✔ | ✔ (nach VT-Aktivierung) |
| Unicode Basic | ✔ | ✔ | ✔ | ✔ |
| Emoji / Extended Unicode | ⚠ (Schriftartabhängig) | ✔ | ✔ | ⚠ |
| Nerd Font Icons | ⚠ (Font-Eintrag nötig) | ✔ | ✔ | ⚠ |
| Cursor-Positionierung | ✔ (nach VT-Aktivierung) | ✔ | ✔ | ✔ (nach VT-Aktivierung) |
| Scrollbalken ausblenden | ✔ (Win32 API) | ⚠ (settings.json) | N/A | ✔ (Win32 API) |
| Fenster ausblenden | ✔ (Win32 API) | ✔ (Win32 API) | ✔ | ✔ |
| Schriftart ändern | ✔ (Registry + API) | ✔ (settings.json) | ✔ | ✔ |
| `Write-Progress` | ✔ | ✔ | ✔ | ✔ |
| Blockelement-Grafiken | ✔ (mit Font) | ✔ | ✔ | ✔ |
| Pixelgrafiken | ✘ | ✘ | ✘ | ✘ |

### 10.2 Empfohlene Hilfsbibliotheken & Module

```powershell
# ── Nützliche PowerShell-Module ──────────────────────────────────────────────

# PSStyle (PowerShell 7.2+) – Nativ, kein Install nötig
# Bietet $PSStyle.Foreground/Background mit RGB-Unterstützung
$PSStyle.Foreground.FromRgb(166, 227, 161)   # Gibt ANSI-Escape zurück
Write-Host "$($PSStyle.Foreground.Green)Grüner Text$($PSStyle.Reset)"

# Terminal-Icons – Icons für Get-ChildItem etc.
Install-Module -Name Terminal-Icons -Scope CurrentUser

# Pansies – Erweiterte Farb-/Textformatierung
Install-Module -Name Pansies -Scope CurrentUser
Write-Host "<cyan>Hallo</cyan> <bg:darkblue><white>Welt</white></bg:darkblue>"

# ps2exe – Skript als .exe mit Icon kompilieren
Install-Module -Name ps2exe -Scope CurrentUser

# Oh-My-Posh – Prompt-Gestaltung mit Nerd Font Icons
Install-Module -Name oh-my-posh -Scope CurrentUser
```

### 10.3 Best Practices

**Encoding immer setzen:**
```powershell
# Am Anfang jedes Skripts mit Unicode-Ausgabe
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null   # Code Page 65001 = UTF-8 (optional, für externe Tools)
```

**VT-Unterstützung erkennen:**
```powershell
function Test-VTSupport {
    # PowerShell 7.2+ hat $PSStyle.OutputRendering
    if ($PSVersionTable.PSVersion.Major -ge 7) { return $true }
    
    # Windows Terminal erkennen
    if ($env:WT_SESSION) { return $true }
    
    # VT-Modus prüfen (Windows 10+)
    try {
        Add-Type @"
        using System; using System.Runtime.InteropServices;
        public class CVT {
            [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
            [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
        }
"@
        $h = [CVT]::GetStdHandle(-11)
        $m = 0
        [CVT]::GetConsoleMode($h, [ref]$m) | Out-Null
        return ($m -band 0x0004) -ne 0
    } catch { return $false }
}

if (Test-VTSupport) {
    Write-Host "VT/ANSI wird unterstützt – erweiterte Farben verfügbar." -ForegroundColor Green
} else {
    Write-Host "Kein VT-Support – nur Standard-Farben." -ForegroundColor Yellow
}
```

**Cleanup nach Skriptende:**
```powershell
# Sicherheits-Trap – stellt Cursor und Farbe wieder her, auch bei Fehler
trap {
    [Console]::CursorVisible = $true
    $ESC = [char]27
    Write-Host "${ESC}[0m" -NoNewline   # Alle Formatierungen zurücksetzen
    Write-Error $_.Exception.Message
}
```

---

*Dokumentation erstellt für PowerShell Development Space – April 2026*
