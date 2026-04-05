# PowerShell: Bilder in WPF/XAML einbinden & DLL/COM-Objekte nutzen

## Übersicht

Dieses Dokument beantwortet zwei grundlegende Fragen rund um erweiterte PowerShell-Techniken: erstens die Einbettung von Bilddateien direkt in WPF/XAML-Anwendungen über Base64-Kodierung, und zweitens den Zugriff auf COM/OLE-Objekte sowie das Laden und Inspizieren von DLL-Dateien mitsamt ihrer Funktionen über .NET Reflection und P/Invoke.

***

## Teil 1: Bilddateien in WPF/XAML-Anwendungen einbinden

### Warum Base64 und nicht Dateipfade?

In PowerShell-WPF-Skripten ist es üblich, Bilder über relative Dateipfade zu referenzieren. Dies hat jedoch einen entscheidenden Nachteil: Sobald das Skript auf einem anderen System ausgeführt wird oder das Bild nicht am erwarteten Pfad liegt, schlägt die Anwendung fehl. Die elegante Lösung ist das **Konvertieren des Bildes in einen Base64-String**, der direkt im Skript eingebettet wird – das Ergebnis ist ein vollständig portables, einzel-datei-basiertes Skript ohne externe Abhängigkeiten.

Base64 ist ein Kodierungsverfahren, das beliebige Binärdaten (also auch Bilddaten wie JPG, PNG oder BMP) in eine ASCII-Zeichenkette umwandelt. Diese Zeichenkette kann problemlos in einer PowerShell-Variable gespeichert, in einem Skript verteilt oder sogar in eine XML/XAML-Datei eingebettet werden.

### Schritt 1: Bild in Base64-String umwandeln

Der erste Schritt ist das Lesen der Bilddatei als Byte-Array und anschließende Konvertierung in einen Base64-String. PowerShell stellt dafür die statischen .NET-Methoden `[System.IO.File]::ReadAllBytes()` und `[System.Convert]::ToBase64String()` bereit:

```powershell
# Beliebiges Bildformat: JPG, PNG, BMP, GIF etc.
$imagePath = "C:\Bilder\meinLogo.png"
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
$base64String = [System.Convert]::ToBase64String($imageBytes)

# Optional: In die Zwischenablage kopieren
$base64String | Set-Clipboard

# Optional: In eine Textdatei schreiben
$base64String | Out-File "C:\Bilder\meinLogo_base64.txt"
```

Der resultierende String beginnt typischerweise mit `iVBORw0KGgo...` (bei PNG) oder `/9j/4AAQSkZJRg...` (bei JPG) und kann je nach Bildgröße sehr lang werden – das ist vollkommen normal.

### Schritt 2: Base64-String als BitmapImage laden

Sobald der Base64-String vorliegt (entweder durch die obige Konvertierung oder als fest eingebetteter Wert im Skript), wird er über einen `MemoryStream` in ein `BitmapImage`-Objekt des WPF-Namespaces geladen:

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# Base64-String (hier gekürzt dargestellt)
$base64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAA..."

# Byte-Array aus Base64 erzeugen
$imageBytes = [System.Convert]::FromBase64String($base64)

# MemoryStream erstellen und BitmapImage laden
$bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.StreamSource = [System.IO.MemoryStream]$imageBytes
$bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$bitmap.EndInit()

# WICHTIG: Freeze() verhindert Memory Leaks!
$bitmap.Freeze()
```

Der Aufruf von `$bitmap.Freeze()` ist kein optionaler Schritt, sondern eine Best Practice: Er macht das `BitmapImage`-Objekt unveränderlich und thread-sicher, was Memory Leaks verhindert, die sonst entstehen können, wenn das WPF-Fenster geschlossen wird.

### Schritt 3: Vollständiges WPF-Beispiel

Das folgende Beispiel zeigt eine komplette, sofort lauffähige WPF-Anwendung in PowerShell, die ein per Base64 eingebettetes Bild anzeigt:

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# XAML-Definition des WPF-Fensters
# Wichtig: x:Name="imgAnzeige" für spätere Referenzierung
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Bild-Demo" Height="350" Width="500">
    <Grid>
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
            <Image x:Name="imgAnzeige" Width="200" Height="200"
                   Stretch="Uniform" Margin="10"/>
            <TextBlock Text="PowerShell WPF mit eingebettetem Bild"
                       HorizontalAlignment="Center" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
'@

# WPF-Fenster aus XAML laden
$reader = New-Object System.Xml.XmlNodeReader $xaml
$form   = [Windows.Markup.XamlReader]::Load($reader)

# Alle benannten Controls als Variablen verfügbar machen
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $form.FindName($_.Name) -Scope Script
}

# Base64-String des Bildes (hier komplett eingebettet)
$base64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAA..."

# BitmapImage aus Base64 erstellen
$bmp = New-Object System.Windows.Media.Imaging.BitmapImage
$bmp.BeginInit()
$bmp.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
$bmp.CacheOption  = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$bmp.EndInit()
$bmp.Freeze()

# Bild dem Image-Control zuweisen
$imgAnzeige.Source = $bmp

# Fenster anzeigen
$form.ShowDialog() | Out-Null
```

### Bild als Fenster-Icon setzen

Das gleiche Prinzip funktioniert auch für das Taskleisten- und Titelleisten-Icon des WPF-Fensters. Statt `Source` wird die `Icon`-Eigenschaft des Fensters gesetzt:

```powershell
# Für das Fenster-Icon wird ein BitmapFrame benötigt
$iconBytes  = [System.Convert]::FromBase64String($base64Icon)
$iconStream = [System.IO.MemoryStream]$iconBytes
$form.Icon  = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconStream)
```

### Für LargeImageSource und SmallImageSource

In komplexeren WPF-Anwendungen (z.B. mit Ribbon-Controls oder CommandBar) können dieselben `BitmapImage`-Objekte auch direkt als `LargeImageSource` oder `SmallImageSource` zugewiesen werden:

```powershell
$buttonControl.LargeImageSource = $bitmap
$buttonControl.SmallImageSource = $bitmap
```

### Unterschied: Windows PowerShell 5.1 vs. PowerShell 7+

Bei der Base64-Kodierung gibt es einen bekannten Unterschied zwischen den PowerShell-Versionen: Windows PowerShell 5.1 verwendet standardmäßig UTF-16-LE (Unicode) für Textstrings, während PowerShell 7+ auf UTF-8 setzt. Für **Bilder** ist dies irrelevant, da Bilddaten binäre Bytes sind und nicht als Text kodiert werden – hier liefert `[System.IO.File]::ReadAllBytes()` in beiden Versionen identische Ergebnisse.

***

## Teil 2: OLE/COM-Objekte und DLL-Dateien in PowerShell

### Das Konzept: PowerShell als vollwertiger .NET-Host

PowerShell ist keine isolierte Skriptsprache, sondern ein vollwertiger .NET-Host. Das bedeutet: Alles, was in C# oder VB.NET möglich ist, ist auch in PowerShell möglich – einschließlich des Zugriffs auf COM-Objekte, des Ladens von .NET-Assemblies und des Aufrufs nativer Windows-DLLs über P/Invoke.

### 2.1 COM/OLE-Objekte – der direkte Weg

#### Grundprinzip: `New-Object -ComObject`

Das Pendant zu Perls `Win32::OLE->new(ProgID)` ist in PowerShell das Cmdlet `New-Object` mit dem Parameter `-ComObject`:

```powershell
# Excel-Instanz erstellen (entspricht Win32::OLE->new("Excel.Application"))
$excel = New-Object -ComObject Excel.Application

# Anwendung sichtbar machen
$excel.Visible = $true

# Neue Arbeitsmappe erstellen
$workbook  = $excel.Workbooks.Add()
$worksheet = $workbook.Worksheets.Item(1)

# Zellen beschreiben
$worksheet.Cells.Item(1,1).Value2 = "Stadt"
$worksheet.Cells.Item(1,2).Value2 = "Einwohnerzahl"
$worksheet.Cells.Item(2,1).Value2 = "München"
$worksheet.Cells.Item(2,2).Value2 = 1600000

# Speichern und schließen
$workbook.SaveAs("C:\Temp\StaedteDemo.xlsx")
$excel.Quit()

# Wichtig: COM-Objekte sauber freigeben!
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)  | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)     | Out-Null
[System.GC]::Collect()
```

Der Aufruf von `ReleaseComObject()` am Ende ist wichtig, um COM-Prozesse (z.B. laufende Excel-Prozesse) sauber zu beenden.

#### Outlook per COM steuern

```powershell
# Outlook-Instanz erstellen
$outlook   = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")

# Neue E-Mail erstellen und versenden
$mail             = $outlook.CreateItem(0) # 0 = MailItem
$mail.Recipients.Add("empfaenger@example.com")
$mail.Subject     = "PowerShell COM-Demo"
$mail.HTMLBody    = "<h1>Hallo!</h1><p>Diese Mail wurde per PowerShell und COM erstellt.</p>"
$mail.Send()
```

#### Auf bereits laufende COM-Instanzen zugreifen: `GetActiveObject`

Das Pendant zu Perls `Win32::OLE->GetActiveObject(ProgID)` ist in PowerShell die Methode `Marshal::GetActiveObject()`:

```powershell
# Verbindung zu einer bereits laufenden Excel-Instanz herstellen
$excel = [System.Runtime.InteropServices.Marshal]::GetActiveObject('Excel.Application')

# Ab PowerShell 7+ (da GetActiveObject in .NET 5+ nicht mehr direkt verfügbar):
# Alternativ über Add-Type mit COM-Interop
```

> **Hinweis für PowerShell 7+:** `Marshal::GetActiveObject` ist in .NET 5+ nicht mehr direkt im Standard-Namespace verfügbar. In diesem Fall muss eine alternative Strategie über COM-Interop oder die Verwendung von Windows PowerShell 5.1 gewählt werden.

#### Alle registrierten COM-Objekte auflisten

Eine vollständige Liste aller auf dem System registrierten COM-ProgIDs lässt sich direkt aus der Registry lesen:

```powershell
# Methode 1: Alle ProgIDs aus HKEY_CLASSES_ROOT
$alleComObjekte = Get-ChildItem "REGISTRY::HKEY_CLASSES_ROOT\CLSID" `
    -Include PROGID -Recurse | ForEach-Object { $_.GetValue("") }

# Nur Microsoft Office-bezogene anzeigen
$alleComObjekte | Where-Object { $_ -match "Excel|Word|Outlook|Access" } | Sort-Object

# Methode 2: Kompaktere Variante
$alleComObjekte = Get-ChildItem "registry::HKEY_CLASSES_ROOT\" `
    -Include PROGID -Recurse | ForEach-Object { $_.GetValue("") }
$alleComObjekte | Where-Object { $_ -match "Application" } | Sort-Object
```

Die ProgID (Programmatic Identifier) ist der String, den man an `-ComObject` übergibt – z.B. `Excel.Application`, `Outlook.Application`, `WScript.Shell` etc.

#### Methoden eines COM-Objekts ermitteln

Genau wie in Perl kann man auch in PowerShell die verfügbaren Methoden und Eigenschaften eines COM-Objekts einfach erkunden – mit `Get-Member`:

```powershell
$excel = New-Object -ComObject Excel.Application

# Alle Methoden und Eigenschaften anzeigen
$excel | Get-Member

# Nur Methoden anzeigen
$excel | Get-Member -MemberType Method

# Nur Eigenschaften anzeigen
$excel | Get-Member -MemberType Property

# Auf ein Unterobjekt anwenden
$workbook = $excel.Workbooks.Add()
$workbook | Get-Member
```

### 2.2 Managed .NET-DLLs laden und nutzen

#### Methode 1: `Add-Type -Path` (empfohlener Weg)

Für .NET-Assemblies (Managed DLLs, also solche die in C#, VB.NET o.Ä. geschrieben wurden) ist `Add-Type -Path` die bevorzugte Methode:

```powershell
# .NET-Assembly laden
Add-Type -Path "C:\MeineProjekte\MeineBibliothek.dll"

# Instanz einer Klasse aus der DLL erstellen
$objekt = New-Object "MeinNamespace.MeineKlasse"

# Methode aufrufen
$ergebnis = $objekt.MeineMethode("Parameter1", 42)
Write-Output $ergebnis

# Statische Methode direkt aufrufen
[MeinNamespace.MeineHilfsklasse]::StatischeMethode()
```

#### Methode 2: `[Reflection.Assembly]::LoadFile()` / `::LoadFrom()`

Die zweite Möglichkeit ist das direkte Laden über die .NET Reflection API:

```powershell
# Assembly per Reflection laden
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")

# Oder: LoadFrom() für Assemblies mit Abhängigkeiten im gleichen Verzeichnis
$assembly = [System.Reflection.Assembly]::LoadFrom("C:\Pfad\zur\Datei.dll")

# Klasse instanziieren
$typ     = $assembly.GetType("MeinNamespace.MeineKlasse")
$objekt  = [Activator]::CreateInstance($typ)

# Methode aufrufen
$methode = $typ.GetMethod("MeineMethode")
$methode.Invoke($objekt, @("Parameter1", 42))
```

Der Unterschied: `LoadFile()` lädt die Assembly aus einem absoluten Pfad ohne den Suchkontext, während `LoadFrom()` auch Abhängigkeiten aus dem gleichen Verzeichnis automatisch auflöst.

### 2.3 Funktionen einer DLL ermitteln (Reflection)

Dies ist der direkte Ersatz für das, was in Perl über AUTOLOAD oder die Analyse der Exporttabelle einer DLL möglich war. In PowerShell steht dafür die vollständige .NET Reflection API zur Verfügung.

#### Alle öffentlichen Typen einer Assembly anzeigen

```powershell
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")

# Alle öffentlich sichtbaren Typen (Klassen, Interfaces, Enums)
$assembly.GetExportedTypes() | Select-Object FullName, IsClass, IsInterface, IsEnum

# Alle Typen inkl. interne (non-public)
$assembly.GetTypes() | Select-Object FullName, IsPublic
```

#### Alle Methoden einer Klasse auflisten

```powershell
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")
$typ      = $assembly.GetType("MeinNamespace.MeineKlasse")

# Alle öffentlichen Methoden
$typ.GetMethods() | Select-Object Name, ReturnType, @{
    Name = "Parameter"
    Expression = { ($_.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", " }
} | Format-Table -AutoSize

# Auch private und interne Methoden sehen (mit BindingFlags)
$flags = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Static
$typ.GetMethods($flags) | Select-Object Name, IsPublic, IsStatic | Format-Table -AutoSize
```

#### Einen kompletten Assembly-Report generieren

```powershell
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")

foreach ($typ in $assembly.GetExportedTypes()) {
    Write-Host "`n=== Typ: $($typ.FullName) ===" -ForegroundColor Cyan

    # Eigenschaften
    $typ.GetProperties() | ForEach-Object {
        Write-Host "  [Property] $($_.PropertyType.Name) $($_.Name)" -ForegroundColor Yellow
    }

    # Methoden (ohne geerbte Object-Methoden)
    $typ.GetMethods() | Where-Object { $_.DeclaringType -eq $typ } | ForEach-Object {
        $params = ($_.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", "
        Write-Host "  [Method]   $($_.ReturnType.Name) $($_.Name)($params)" -ForegroundColor Green
    }
}
```

#### Out-GridView für interaktive Exploration

Für eine besonders komfortable Exploration einer unbekannten DLL eignet sich `Out-GridView` in Kombination mit Reflection:

```powershell
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")
$results  = @()

$assembly.GetTypes() | ForEach-Object {
    $typ = $_
    $_.GetMembers() | ForEach-Object {
        $results += [PSCustomObject]@{
            Klasse     = $typ.FullName
            Typ        = $_.MemberType
            Name       = $_.Name
            Öffentlich = $_.IsPublic
            Definition = $_.ToString()
        }
    }
}

$results | Sort-Object Klasse, Typ, Name | Out-GridView -Title "DLL-Analyse"
```

#### Private Methoden aufrufen (Non-Public Reflection)

Ein besonderer Vorteil gegenüber normaler Programmierung: Mit Reflection kann man auch `private` und `internal` Methoden aufrufen – solange der ausführende Code volle Vertrauenswürdigkeit hat:

```powershell
$assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")
$typ      = $assembly.GetType("MeinNamespace.MeineKlasse")
$instanz  = [Activator]::CreateInstance($typ)

# Private Instanzmethode aufrufen
$bindingFlags = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance
$privateMethod = $typ.GetMethod("PrivateMethode", $bindingFlags)
$ergebnis = $privateMethod.Invoke($instanz, @("Argument1"))

# Private statische Methode aufrufen
$bindingFlags2 = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Static
$privateStatic = $typ.GetMethod("PrivateStatischeMethode", $bindingFlags2)
$ergebnis2 = $privateStatic.Invoke($null, @())
```

### 2.4 Native (unmanaged) DLLs mit P/Invoke aufrufen

Für native Windows-DLLs (z.B. `user32.dll`, `kernel32.dll` oder eigene C/C++-DLLs ohne .NET-Basis) gibt es P/Invoke (Platform Invoke). Dies ist das PowerShell-Äquivalent zum Laden einer DLL in Perl mit `use Win32::API` oder ähnlichen Modulen.

Der Mechanismus: `Add-Type` kompiliert C#-Code direkt in der PowerShell-Session. Dieser C#-Code enthält die `[DllImport]`-Attribute, die .NET mitteilen, welche Funktion aus welcher nativen DLL geladen werden soll:

```powershell
# Beispiel 1: Einfache MessageBox aus user32.dll
$signatur = @"
using System;
using System.Runtime.InteropServices;

public class User32Wrapper {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);
}
"@

Add-Type -TypeDefinition $signatur

# Funktion aufrufen
[User32Wrapper]::MessageBox(0, "Hallo aus PowerShell!", "P/Invoke Demo", 0)
```

```powershell
# Beispiel 2: Mehrere Win32-Funktionen aus verschiedenen DLLs
$signatur = @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    // user32.dll
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    // kernel32.dll
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

Add-Type -TypeDefinition $signatur

# Console-Fenster minimieren (nCmdShow = 2)
$hwnd = [WinAPI]::GetConsoleWindow()
[WinAPI]::ShowWindow($hwnd, 2)
```

```powershell
# Beispiel 3: Eigene native C/C++-DLL aufrufen
# (DLL muss exportierte C-Funktionen haben, kein C++-Name-Mangling)
$signatur = @"
using System;
using System.Runtime.InteropServices;

public class MeineNativeDll {
    [DllImport("C:\\Pfad\\zur\\meineDLL.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int BerechneSumme(int a, int b);

    [DllImport("C:\\Pfad\\zur\\meineDLL.dll", CharSet = CharSet.Ansi)]
    public static extern string GetVersionString();
}
"@

Add-Type -TypeDefinition $signatur

$summe   = [MeineNativeDll]::BerechneSumme(10, 32)
$version = [MeineNativeDll]::GetVersionString()
Write-Host "Summe: $summe, Version: $version"
```

#### Exportierte Funktionen einer nativen DLL ermitteln

Da native DLLs nicht über .NET Reflection inspizierbar sind, braucht man andere Werkzeuge, um die Export-Tabelle zu lesen. Dies kann direkt aus PowerShell heraus mit einem kleinen Trick über das Tool `dumpbin.exe` (Visual Studio) oder über die PE-Dateistruktur erfolgen:

```powershell
# Mit dumpbin.exe (Visual Studio muss installiert sein)
& "C:\Program Files\Microsoft Visual Studio\2022\...\dumpbin.exe" /exports "C:\Windows\System32\user32.dll"

# Alternative: Windows-eigenes Get-Command nach geladenen Modulen
# oder direkt über das PE-Format parsen (fortgeschritten)

# Für .NET-DLLs: ILSpy oder dotPeek sind GUI-Tools zur Dekompilierung
# In PowerShell: Über Reflection wie oben beschrieben
```

Ein sehr praktischer Online-Ressourcen ist [pinvoke.net](https://www.pinvoke.net), das für nahezu alle Standard-Windows-API-Funktionen bereits fertige C#/P/Invoke-Signaturen bereithält.

### 2.5 Gegenüberstellung: Perl vs. PowerShell

| Aufgabe | Perl (Win32::OLE) | PowerShell |
|---|---|---|
| COM-Objekt erstellen | `Win32::OLE->new("Excel.Application")` | `New-Object -ComObject Excel.Application` |
| Aktive Instanz holen | `Win32::OLE->GetActiveObject("Excel.Application")` | `[Marshal]::GetActiveObject('Excel.Application')` |
| Methoden erkunden | AUTOLOAD / Dokumentation | `$obj \| Get-Member` |
| .NET-DLL laden | `use Win32::API` oder extern | `Add-Type -Path "datei.dll"` oder `[Reflection.Assembly]::LoadFile()` |
| DLL-Funktionen ermitteln | Externe Tools / PDB | `.GetExportedTypes()`, `.GetMethods()` |
| Native DLL aufrufen | `use Win32::API` | `Add-Type` mit `[DllImport]`-Attribut (P/Invoke) |
| Private Methoden aufrufen | Nicht vorgesehen | `.GetMethod()` + `BindingFlags::NonPublic` + `.Invoke()` |

### 2.6 Assembly Load Contexts (PowerShell 7+)

Ab PowerShell 7 gibt es ein wichtiges Konzept zu beachten: **Assembly Load Contexts (ALCs)**. Da PowerShell 7 auf .NET 5+ aufbaut, kann jede benannte Assembly nur einmal in den Standard-Load-Context geladen werden. Wenn zwei Module unterschiedliche Versionen der gleichen DLL benötigen, entsteht ein Konflikt.

Die Lösung ist ein eigener ALC-Resolver, der Abhängigkeiten in einen separaten Kontext lädt. Für einfache Skripte ist dies in der Regel kein Problem – relevant wird es erst bei komplexen Modulentwicklungen.

***

## Wichtige Hinweise und Best Practices

### Memory Management

- Bei `BitmapImage` immer `.Freeze()` aufrufen, um Memory Leaks zu vermeiden
- Bei COM-Objekten `[System.Runtime.InteropServices.Marshal]::ReleaseComObject()` verwenden und anschließend `[System.GC]::Collect()` aufrufen
- `MemoryStream`-Objekte sollten mit `using`-Blöcken oder explizitem `.Dispose()` freigegeben werden

### Fehlerbehandlung bei DLL-Operationen

```powershell
try {
    $assembly = [System.Reflection.Assembly]::LoadFile("C:\Pfad\zur\Datei.dll")
    $typ = $assembly.GetType("MeinNamespace.MeineKlasse")
    if ($null -eq $typ) {
        Write-Warning "Typ nicht gefunden! Verfügbare Typen:"
        $assembly.GetExportedTypes() | ForEach-Object { Write-Host "  - $($_.FullName)" }
    }
} catch [System.BadImageFormatException] {
    Write-Error "DLL ist keine gültige .NET-Assembly (evtl. native C/C++-DLL)."
    Write-Host "Für native DLLs: Add-Type mit [DllImport]-Attribut verwenden."
} catch [System.IO.FileNotFoundException] {
    Write-Error "DLL-Datei nicht gefunden: $($_.Exception.Message)"
}
```

### Vorsichtsmaßnahmen bei P/Invoke

P/Invoke umgeht die normale .NET-Sicherheitsabstraktion. Fehler in der Signatur (falsche Typen, falsches CallingConvention) können zu Stack Corruption oder Anwendungsabstürzen führen. Daher empfiehlt sich:
- Signaturen immer aus vertrauenswürdigen Quellen wie [pinvoke.net](https://www.pinvoke.net) übernehmen
- `SetLastError = true` angeben, wenn Win32-Fehlercodes gebraucht werden
- `CallingConvention` korrekt setzen (Standard: `StdCall` für Windows-API; `Cdecl` für viele C-Bibliotheken)
- 32-Bit vs. 64-Bit beachten – `IntPtr` passt sich automatisch an, integer-Typen aber nicht immer

---
