# Demo-WPF-Anwendung mit den externen Schriftarten Ubuntu-Regular und Ubuntu-Bold
# über AddFontMemResourceEx. Dabei werden beide Fonts aus dem Unterordner "data\fonts" geladen,
# der allokierte Speicher beim Beenden wieder freigegeben und formattierter Text (mit Unicode-Entitäten)
# angezeigt, sodass Umlaute wie ä, ö und ü korrekt dargestellt werden.

# 1. Notwendige .NET-Assemblies laden
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# 2. C#-Klasse definieren, die AddFontMemResourceEx und RemoveFontMemResourceEx kapselt
#    und den allokierten Speicher verwaltet.
$fontLoaderCode = @"
using System;
using System.Runtime.InteropServices;
public class FontLoader {
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern IntPtr AddFontMemResourceEx(IntPtr pbFont, uint cbFont, IntPtr pdv, [In] ref uint pcFonts);
    
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern bool RemoveFontMemResourceEx(IntPtr fh);

    // Hilfsklasse, um den Font-Handle sowie den allokierten Speicher-Pointer zu speichern.
    public class LoadedFont {
        public IntPtr Handle;
        public IntPtr FontPointer;
    }
    
    // Lädt die Schriftdatei in den Prozess (als privaten Font) und gibt ein LoadedFont-Objekt zurück,
    // das sowohl den Font-Handle als auch den zugehörigen Speicher-Pointer enthält.
    public static LoadedFont LoadFontFromFile(string path) {
        byte[] fontData = System.IO.File.ReadAllBytes(path);
        IntPtr fontPtr = Marshal.AllocCoTaskMem(fontData.Length);
        Marshal.Copy(fontData, 0, fontPtr, fontData.Length);
        uint dummy = 0;
        IntPtr handle = AddFontMemResourceEx(fontPtr, (uint)fontData.Length, IntPtr.Zero, ref dummy);
        if(handle == IntPtr.Zero)
           throw new Exception("AddFontMemResourceEx failed. Error: " + Marshal.GetLastWin32Error());
        LoadedFont lf = new LoadedFont();
        lf.Handle = handle;
        lf.FontPointer = fontPtr;
        return lf;
    }
    
    // Entfernt die geladene Schriftart aus dem privaten Font-Pool und gibt den allokierten Speicher frei.
    public static bool RemoveFont(LoadedFont lf) {
        bool result = RemoveFontMemResourceEx(lf.Handle);
        if (result) {
            Marshal.FreeCoTaskMem(lf.FontPointer);
        }
        return result;
    }
}
"@
Add-Type -TypeDefinition $fontLoaderCode -Language CSharp

# 3. Pfad zu den Schriftdateien definieren (beide liegen im Unterordner "data\fonts" des Skriptverzeichnisses)
$fontDir = Join-Path $PSScriptRoot "data\fonts"
$fontRegularPath = Join-Path $fontDir "Ubuntu-Regular.ttf"
$fontBoldPath    = Join-Path $fontDir "Ubuntu-Bold.ttf"

if (-not (Test-Path $fontRegularPath)) {
    Write-Host "Fehler: Datei 'Ubuntu-Regular.ttf' wurde nicht gefunden in $fontDir"
    exit
}
if (-not (Test-Path $fontBoldPath)) {
    Write-Host "Fehler: Datei 'Ubuntu-Bold.ttf' wurde nicht gefunden in $fontDir"
    exit
}

# 4. Schriftarten in den privaten Font-Pool laden und die geladenen Objekte speichern
try {
    $global:loadedFonts = @{}
    $global:loadedFonts["Ubuntu-Regular"] = [FontLoader]::LoadFontFromFile($fontRegularPath)
    $global:loadedFonts["Ubuntu-Bold"]    = [FontLoader]::LoadFontFromFile($fontBoldPath)
    Write-Host "Schriftarten wurden erfolgreich geladen."
} catch {
    Write-Host "Fehler beim Laden der Schriftarten:" $_
    exit
}

# 5. XAML-Definition des Fensters inkl. Ressourceneinträgen für die Schriftarten.
#    Die XML-Deklaration gibt an, dass die XAML als UTF-8 interpretiert werden soll.
#    Innerhalb des Textes werden Umlaute als Unicode-Entitäten eingebettet:
#      - ä als &#228;
#      - ö als &#246;
#      - ü als &#252;
[xml]$xaml = @"
<?xml version="1.0" encoding="utf-8" ?>
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Ubuntu Schriftarten Demo" 
    Width="600" Height="400"
    WindowStartupLocation="CenterScreen">
    
    <Window.Resources>
        <FontFamily x:Key="UbuntuRegular">Ubuntu</FontFamily>
        <FontFamily x:Key="UbuntuBold">Ubuntu Bold</FontFamily>
    </Window.Resources>
    
    <Grid Background="White">
        <StackPanel Margin="20">
            <!-- Überschrift in Bold -->
            <TextBlock 
                Text="Demo: Externe Ubuntu-Schriftarten" 
                FontSize="28"
                FontFamily="{StaticResource UbuntuBold}"
                Foreground="DarkBlue"
                Margin="0,0,0,20"/>
            
            <!-- Einfache Textzeile in Regular -->
            <TextBlock 
                Text="Dies ist ein Beispieltext in Ubuntu Regular."
                FontSize="20"
                FontFamily="{StaticResource UbuntuRegular}"
                Foreground="Black"
                Margin="0,0,0,10"/>
            
            <!-- TextBlock mit Inline-Formatierung (Mischung aus Regular und Bold) -->
            <TextBlock FontSize="16" Margin="0,0,0,10">
                <Run Text="Dieser Text enth&#228;lt " Foreground="Black"/>
                <Run Text="fett formatierten" FontFamily="{StaticResource UbuntuBold}" Foreground="Black"/>
                <Run Text=" Text inmitten von Regular Text." Foreground="Black"/>
            </TextBlock>
            
            <!-- Weiterer Absatz in Regular -->
            <TextBlock 
                Text="Ein weiterer Absatz in Ubuntu Regular mit Standard-Formatierung."
                FontSize="16"
                FontFamily="{StaticResource UbuntuRegular}"
                Foreground="DarkGreen"
                TextWrapping="Wrap"/>
        </StackPanel>
    </Grid>
</Window>
"@

# 6. XAML parsen und Fenster erstellen
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)
if (-not $window) {
    Write-Host "Fehler: Das Fenster konnte nicht erstellt werden."
    exit
}

# 7. Beim Schließen des Fensters: Die geladenen Schriftarten entfernen und den zugehörigen Speicher freigeben.
$window.Add_Closed({
    foreach ($fontKey in $global:loadedFonts.Keys) {
        try {
            [FontLoader]::RemoveFont($global:loadedFonts[$fontKey]) | Out-Null
            Write-Host "Schriftart '$fontKey' wurde erfolgreich entfernt."
        } catch {
            Write-Host "Fehler beim Entfernen von Schriftart '$fontKey': $_"
        }
    }
})

# 8. Fenster anzeigen
$window.ShowDialog() | Out-Null
