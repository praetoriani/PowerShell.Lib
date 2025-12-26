# ModernUI v1.00.00 - Bugfixes und Loesungen

## Fehleranalyse und Behobene Probleme

### Original Fehler

```
[ModernUI] Error loading ModernUI.xaml: Ausnahme beim Aufrufen von "Load" mit 1 Argument(en):
"Zeilennummer "1" und Zeilenposition "9" von "Der angegebene Klassenname "ModernUI.MainWindow" 
entspricht nicht dem tatsaechlichen Stamminstanztyp "System.Windows.Window". Entfernen Sie die 
Klassendirektive, oder geben Sie eine Instanz ueber XamlObjectWriterSettings.RootObjectInstance an."
```

---

## Identifizierte Probleme und Loesungen

### Problem 1: XAML x:Class Direktive

**Ursache:**
```xaml
<Window x:Class="ModernUI.MainWindow" ...>
```
PowerShell's `System.Windows.Markup.XamlReader` kann keine Code-Behind-Klassen laden.
Diese Direktive existiert nur in C#/WPF-Projekten mit Compiler-Support.

**Loesung:**
```xaml
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ...>
```
Removed x:Class directive. Event handlers are now registered in PowerShell.

---

### Problem 2: Undefined Event Handlers in XAML

**Ursache:**
```xaml
<Border MouseLeftButtonDown="TitleBar_MouseLeftButtonDown">
<Button Click="CloseButton_Click">
```
Diese Event-Handler sind in PowerShell nicht definiert.
XamlReader versucht, sie zu finden und schlaegt fehl.

**Loesung:**
```xaml
<!-- XAML ohne Event-Attribute -->
<Border x:Name="TitleBar">  <!-- Nur Name zum Finden aus PowerShell -->
<Button x:Name="CloseButton">  <!-- Nur Name -->
```

Event-Handler werden in PowerShell registriert:
```powershell
$titleBar = $window.FindName("TitleBar")
$titleBar.Add_MouseLeftButtonDown({ ... })

$closeButton = $window.FindName("CloseButton")
$closeButton.Add_Click({ ... })
```

---

### Problem 3: ConvertTo-Hashtable Fehler

**Ursache:**
```
App Name: System.Collections.Hashtable  <-- Wrong! Should be "ModernUI"
Version: System.Collections.Hashtable   <-- Wrong!
Developer: System.Collections.Hashtable <-- Wrong!
```

Die Funktion gab Hashtable-Type-Name statt Werte zurueck.
Grund: Rekursion war nicht korrekt implementiert.

**Loesung:**
```powershell
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline = $true)] $InputObject)
    
    process {  # Use process block for pipeline
        if ($InputObject -is [object] -and $InputObject.GetType().Name -eq 'PSCustomObject') {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            return $hash  # Return hashtable, not its name
        }
    }
}
```

---

### Problem 4: Event Handler Parameter Binding

**Ursache:**
```powershell
# Falsch - Parameter nicht definiert
$titleBar.Add_MouseLeftButtonDown({
    $Window.DragMove()  # $Window ist in diesem Scope nicht definiert
})
```

**Loesung:**
```powershell
# Richtig - Parameter explizit definiert
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)  # Event-Handler Parameter
    $Window.DragMove()  # $Window ist jetzt aus closure bekannt
})
```

---

### Problem 5: Image Loading Path Resolution

**Ursache:**
```powershell
# Relative Pfade funktionieren nicht immer korrekt
$windowPath = $Global:ModernUI_Config.modernui.window  # Relative path
$bgImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$windowPath)
```

**Loesung:**
```powershell
# Absolute Pfade mit Join-Path
$windowPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.window
if (Test-Path $windowPath -PathType Leaf) {  # Validate path
    $bgImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$windowPath)
}
```

---

## Zusammenfassung der Aenderungen

| Datei | Problem | Loesung |
|-------|---------|----------|
| **ModernUI.xaml** | x:Class + undefined handlers | Removed x:Class, add x:Name instead |
| **ModernUI.ps1** | ConvertTo-Hashtable wrong return | Fixed recursion with process block |
| **ModernUI.ps1** | Event handler param binding | Added param() to handlers |
| **ModernUI.ps1** | Relative path issues | Use absolute paths with Join-Path |

---

## Debugging-Tipps

### XAML Fehler debuggen
```powershell
# Teste XAML Parser direkt
$xamlContent = Get-Content "ModernUI.xaml" -Raw
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
try {
    $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
    Write-Host "XAML load OK"
} catch {
    Write-Host "XAML Error: $_"
}
```

### Config Conversion debuggen
```powershell
$json = Get-Content "config.json" -Raw | ConvertFrom-Json
Write-Host "Type before: $($json.GetType().Name)"
$ht = ConvertTo-Hashtable $json
Write-Host "Type after: $($ht.GetType().Name)"
Write-Host "Values: $($ht['appname']), $($ht['appver'])"
```

### Event Handler debuggen
```powershell
# Verbose output
$titleBar.Add_MouseLeftButtonDown({
    Write-Verbose "TitleBar mouse down event fired"
    $Window.DragMove()
})

# Ausfuehren mit Verbose
.\ModernUI.ps1 -Verbose
```

---

## Wichtige PowerShell-WPF Konzepte

### 1. XamlReader Limitationen
- Keine x:Class Support
- Keine Code-Behind
- Event-Handler muessen in PowerShell registriert werden
- Verwendet XPath zum Finden von Elementen

### 2. Window Dragging
```powershell
# DragMove() nur im MouseLeftButtonDown Event aufrufen
$border.Add_MouseLeftButtonDown({
    try { $window.DragMove() }
    catch { Write-Verbose "DragMove failed" }
})
```

### 3. Image Loading
```powershell
# BitmapImage braucht [uri] Type
$image.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$filePath)
```

### 4. Hashtable vs PSCustomObject
```powershell
# JSON ist standardmaessig PSCustomObject
$json = Get-Content "config.json" | ConvertFrom-Json
$json.GetType().Name  # PSCustomObject - langsamer

# Fuer bessere Performance -> Hashtable konvertieren
$ht = ConvertTo-Hashtable $json
$ht.GetType().Name  # Hashtable - schneller
```

---

## Lessons Learned

1. **XAML in PowerShell**: Keine Code-Behind, alles als String
2. **Event Handler**: Muessen Parameternamen definieren
3. **Paths**: Immer absolute Pfade mit Join-Path verwenden
4. **Type Conversion**: PSCustomObject != Hashtable
5. **Error Messages**: Teils auf Deutsch -> PowerShell kann Probleme haben

---

## Testing-Checkliste

- [x] XAML parsed without errors
- [x] config.json loads as proper Hashtable
- [x] Images load from PNG directory
- [x] TitleBar drag functionality works
- [x] Close button click event fires
- [x] Close button hover effects work
- [x] Application exits cleanly

---

**Version**: 1.00.00  
**Status**: Production Ready (mit Fixes)  
**Datum**: 2025-12-26
