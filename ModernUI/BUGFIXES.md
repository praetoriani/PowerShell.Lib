# ModernUI v1.00.00 - Bugfixes und Loesungen

## Fehleranalyse und Behobene Probleme

---

## Batch 1: Initial Parser Errors

### Original Fehler

```
[ModernUI] Error loading ModernUI.xaml: Ausnahme beim Aufrufen von "Load" mit 1 Argument(en):
"Zeilennummer "1" und Zeilenposition "9" von "Der angegebene Klassenname "ModernUI.MainWindow" 
entspricht nicht dem tatsaechlichen Stamminstanztyp "System.Windows.Window". Entfernen Sie die 
Klassendirektive, oder geben Sie eine Instanz ueber XamlObjectWriterSettings.RootObjectInstance an."
```

### Identifizierte Probleme und Loesungen

#### Problem 1: XAML x:Class Direktive

**Ursache:**
```xaml
<Window x:Class="ModernUI.MainWindow" ...>
```
PowerShell's `System.Windows.Markup.XamlReader` kann keine Code-Behind-Klassen laden.

**Loesung:**
```xaml
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ...>
```

#### Problem 2: Undefined Event Handlers in XAML

**Ursache:**
```xaml
<Border MouseLeftButtonDown="TitleBar_MouseLeftButtonDown">
<Button Click="CloseButton_Click">
```

**Loesung:**
Event-Handler werden in PowerShell registriert:
```powershell
$titleBar.Add_MouseLeftButtonDown({ ... })
$closeButton.Add_Click({ ... })
```

#### Problem 3: ConvertTo-Hashtable Fehler

**Ursache:**
Funktion gab Hashtable-Type-Name statt Werte zurueck.

**Loesung:**
```powershell
function ConvertTo-Hashtable {
    process {
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

#### Problem 4: Event Handler Parameter Binding

**Ursache:**
Parameter nicht definiert in Event Handlern.

**Loesung:**
```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)  # Event-Handler Parameter
    $Window.DragMove()
})
```

#### Problem 5: Image Loading Path Resolution

**Ursache:**
Relative Pfade funktionieren nicht zuverlaessig.

**Loesung:**
```powershell
$windowPath = Join-Path $Global:ScriptPath $Global:ModernUI_Config.modernui.window
if (Test-Path $windowPath -PathType Leaf) {
    $bgImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$windowPath)
}
```

---

## Batch 2: Functionality Issues (Window Dragging & Hover Effects) - INITIAL ATTEMPT

### Fehler 1: Fenster kann nicht verschoben werden (First Attempt)

**Symptome:**
- Klick und Drag auf TitleBar funktioniert nicht
- Fenster bewegt sich nicht
- DragMove() wird ausgefuehrt, hat aber keine Wirkung

**Root Cause - Variable Scoping Problem:**
Das Hauptproblem war die Variable-Referenz in Event Handlern. Die `$Window` Variable war nicht korrekt in den Event Handler Scopes verfügbar:

```powershell
# FALSCH - $Window ist im Event Handler nicht verfügbar!
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    $Window.DragMove()  # ERROR: $Window is $null here!
})
```

**Ursache der Variable-Unverfügbarkeit:**
- Event Handler werden in einem neuen Script-Scope ausgeführt
- Lokale Funktionsvariablen sind nicht im Event-Handler-Scope verfügbar
- Nur `$Global:` und `$script:` Variablen sind zugänglich

**Loesung - Script-Scoped Variable:**
```powershell
# RICHTIG - $script:WindowReference ist im Event Handler verfügbar
function Register-EventHandlers {
    param([System.Windows.Window]$Window)
    
    # Store window reference in script scope
    $script:WindowReference = $Window
    
    $titleBar.Add_MouseLeftButtonDown({
        param($sender, $e)
        try {
            if ($script:WindowReference -ne $null) {
                $script:WindowReference.DragMove()
            }
        }
        catch {
            Write-Verbose "[ModernUI] DragMove error: $_"
        }
    })
}
```

**Key Points:**
- `$script:WindowReference` ist im Event Handler IMMER verfügbar
- Null-Check verhindert Fehler bei unerwarteten State-Änderungen
- Direkter Zugriff auf `DragMove()` Methode durch gespeicherte Referenz

---

### Fehler 2: Close Button Hover-Effekt funktioniert nicht

**Symptome:**
- Hover ueber Close Button zeigt kein visuelles Feedback
- PNG tauscht nicht zwischen normal und hover
- Soll: PNG-Swap (normal <-> hover)
- Ist: Keine Aenderung beim Hover

**Root Cause - Tag Property nicht korrekt verfügbar:**
Das Problem war ähnlich wie bei Window Dragging - der Zugriff auf `$sender.Tag` im Event Handler war nicht optimal implementiert:

**Loesung - Korrekter Tag-Zugriff:**
```powershell
# Korrekt - Tag Property vom Button wird genutzt
$closeButton.Add_MouseEnter({
    param($sender, $e)
    try {
        # $sender ist der Button - Tag wurde beim Laden gespeichert
        if ($sender.Tag.HoverPath -and (Test-Path $sender.Tag.HoverPath -PathType Leaf)) {
            $hoverBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $hoverBitmap.BeginInit()
            $hoverBitmap.UriSource = [uri]$sender.Tag.HoverPath
            $hoverBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $hoverBitmap.EndInit()
            $hoverBitmap.Freeze()
            $sender.Tag.ImageControl.Source = $hoverBitmap
        }
    }
    catch {
        Write-Verbose "[ModernUI] Error setting hover image: $_"
    }
})

$closeButton.Add_MouseLeave({
    param($sender, $e)
    try {
        if ($sender.Tag.NormalPath -and (Test-Path $sender.Tag.NormalPath -PathType Leaf)) {
            $normalBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $normalBitmap.BeginInit()
            $normalBitmap.UriSource = [uri]$sender.Tag.NormalPath
            $normalBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $normalBitmap.EndInit()
            $normalBitmap.Freeze()
            $sender.Tag.ImageControl.Source = $normalBitmap
        }
    }
    catch {
        Write-Verbose "[ModernUI] Error setting normal image: $_"
    }
})
```

**What we store in Button.Tag during XAML load:**
```powershell
# In Load-ModernUIXAML function:
$closeButton.Tag = @{
    NormalPath = $closeNormal
    HoverPath = $closeHover
    ImageControl = $closeButtonImage
}
```

**Key Points:**
- `$sender` Parameter ist IMMER der Button der den Event getriggert hat
- `$sender.Tag` enthält die gespeicherten Pfade und Image-Referenzen
- Image Control Referenz ist auch im Tag gespeichert
- BeginInit/EndInit/Freeze Pattern für sichere BitmapImage-Erstellung

---

## Batch 3: Cursor Styling (v1.00.00 Final)

### Fehler 3: Falsche Cursor-Anzeige

**Symptome:**
- Hand-Cursor wird angezeigt statt Standard-Cursor
- Nicht konsistent mit Windows 11 Verhalten
- Unerwünschte visuelle Feedback

**Ursache:**
In der XAML wurden `Cursor="Hand"` Attribute gesetzt:
```xaml
<Border Cursor="Hand" ...>      <!-- FALSCH -->
<Button Cursor="Hand" ...>      <!-- FALSCH -->
```

**Loesung:**
```xaml
<!-- Alle Cursor Attribute entfernen -->
<Border x:Name="TitleBar" ...>  <!-- Standard Cursor -->
<Button x:Name="CloseButton" ...> <!-- Standard Cursor -->
```

**Ergebnis:**
- Standard-Cursor wird überall angezeigt
- Konsistent mit Windows 11 UI-Verhalten
- Kein Cursor-Flicker oder visuelles Chaos

---

## Zusammenfassung aller Aenderungen v1.00.00

| Batch | Problem | Datei | Loesung |
|-------|---------|-------|----------|
| **1** | XAML Parser Error | ModernUI.xaml | Removed x:Class |
| **1** | Undefined Event Handlers | ModernUI.xaml | Remove handler attributes, use x:Name only |
| **1** | ConvertTo-Hashtable | ModernUI.ps1 | Fixed recursion |
| **1** | Event Parameter Binding | ModernUI.ps1 | Added param() |
| **1** | Relative Paths | ModernUI.ps1 | Use absolute paths |
| **2a** | Window Drag nicht funktional | ModernUI.ps1 | **script:WindowReference Variable** |
| **2b** | Close Button Hover nicht funktional | ModernUI.ps1 | **Tag Property richtig nutzen** |
| **3** | Falscher Cursor | ModernUI.xaml | Remove Cursor attributes |

---

## KRITISCHE REGELN FÜR POWERSHELL-XAML UND WPF

### 1. ⚠️ NEVER USE EVENT HANDLERS IN XAML

```xaml
<!-- FALSCH -->
<Window MouseMove="Window_MouseMove" ...>
<Border MouseLeftButtonDown="TitleBar_MouseLeftButtonDown" ...>
<Button Click="CloseButton_Click" ...>

<!-- RICHTIG -->
<Window x:Name="ModernUIWindow" ...>
<Border x:Name="TitleBar" ...>
<Button x:Name="CloseButton" ...>
```

### 2. ⚠️ VARIABLE SCOPING IN EVENT HANDLERS

Event Handler Scopes sind ISOLIERT - normale Funktionsvariablen sind NOT verfügbar:

```powershell
# FALSCH - $Window ist im Handler nicht verfügbar
function Register-Events {
    param($Window)
    $titleBar.Add_MouseLeftButtonDown({
        $Window.DragMove()  # ERROR: $Window is $null
    })
}

# RICHTIG - script:WindowReference IST im Handler verfügbar
function Register-Events {
    param($Window)
    $script:WindowReference = $Window
    $titleBar.Add_MouseLeftButtonDown({
        $script:WindowReference.DragMove()  # OK: $script: scope is accessible
    })
}
```

**Available Scopes in Event Handlers:**
- ✅ `$Global:` - Global scope (always accessible)
- ✅ `$script:` - Script scope (accessible within same script)
- ✅ `param($sender, $e)` - Event parameters
- ❌ Function local variables - NOT accessible
- ❌ Parent function scope - NOT accessible

### 3. ⚠️ SENDER PARAMETER IS YOUR FRIEND

Der `$sender` Parameter ist IMMER das Control das den Event getriggert hat:

```powershell
# $sender ist der Button
$closeButton.Add_Click({
    param($sender, $e)
    # $sender = $closeButton
})

# $sender ist der Border/TitleBar
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    # $sender = $titleBar
})
```

### 4. ⚠️ STORE DATA IN CONTROL.TAG FOR EVENT ACCESS

Wenn ihr Daten in Event Handlern braucht, speichert sie in `.Tag`:

```powershell
# Im Initialisierungscode
$button.Tag = @{
    NormalPath = "path\to\normal.png"
    HoverPath = "path\to\hover.png"
    ImageControl = $imageObject
}

# Im Event Handler
$closeButton.Add_MouseEnter({
    param($sender, $e)
    # Zugriff auf Data via $sender.Tag
    $hoverPath = $sender.Tag.HoverPath
    $imageControl = $sender.Tag.ImageControl
})
```

---

## Wichtige PowerShell-WPF Konzepte

### 1. Window.DragMove()
- Muss innerhalb eines **MouseLeftButtonDown** Event aufgerufen werden
- Braucht `WindowStyle="None"` fuer rahmenloses Fenster
- Try-Catch empfohlen da Exception bei bestimmten Window-States
- **KRITISCH**: Fenster-Referenz muss verfügbar sein (script-scoped)

### 2. BitmapImage Initialization
```powershell
# RICHTIG - 5-Schritt Prozess
$bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
$bitmap.BeginInit()                                           # Step 1
$bitmap.UriSource = [uri]"path\to\image.png"                # Step 2
$bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad  # Step 3
$bitmap.EndInit()                                             # Step 4
$bitmap.Freeze()                                              # Step 5

# FALSCH - One-liner schlaegt fehl
$bitmap = [System.Windows.Media.Imaging.BitmapImage]::new([uri]"path")
```

### 3. Button Styling in PowerShell-XAML
- FocusVisualStyle="{x:Null}" entfernt blaues Quad
- ControlTemplate.Triggers fuer IsMouseOver/IsPressed
- Content muss in ContentPresenter sein

### 4. Event Handler Scope
```powershell
# RICHTIG - Lokale Variablen in script: scope speichern
$script:ImageControl = $Window.FindName("CloseButtonImage")
$script:WindowRef = $Window

# Im Handler
$button.Add_Click({
    $script:ImageControl.Source = ...  # OK
    $script:WindowRef.DragMove()        # OK
})
```

### 5. XAML in PowerShell - Nur Names verwenden
```xaml
<!-- Alle diese sind OK - verwenden x:Name -->
<Window x:Name="MyWindow" ...>
<Border x:Name="TitleBar" ...>
<Button x:Name="MyButton" ...>
<Image x:Name="MyImage" ...>

<!-- KEINE dieser Event-Attribute in PowerShell-XAML -->
<Window MouseMove="...">
<Border Click="...">
<Button DoubleClick="...">
```

---

## Debugging-Tipps

### DragMove Probleme
```powershell
# Teste DragMove direkter
$script:WindowRef = $window
$titleBar.Add_MouseLeftButtonDown({
    Write-Host "MouseDown triggered"
    if ($script:WindowRef -ne $null) {
        $script:WindowRef.DragMove()
        Write-Host "DragMove executed"
    } else {
        Write-Host "ERROR: WindowRef is null!"
    }
})
```

### BitmapImage Fehler
```powershell
# Teste Image-Erstellung
try {
    $testBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
    $testBitmap.BeginInit()
    $testBitmap.UriSource = [uri]"path\to\image.png"
    $testBitmap.CacheOption = `
        [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $testBitmap.EndInit()
    $testBitmap.Freeze()
    Write-Host "Bitmap created successfully"
}
catch {
    Write-Host "Error: $_"
}
```

### Hover Event Debugging
```powershell
$closeButton.Add_MouseEnter({
    Write-Host "Hover started"
    Write-Host "sender.Tag = $($args[0].Tag | ConvertTo-Json)"
})

$closeButton.Add_MouseLeave({
    Write-Host "Hover ended"
})
```

### XAML Parser Fehler
```powershell
# Bei Error wie "Fehler beim Erstellen von XYZ aus dem Text..."
# Prüfe ob in XAML nicht-definierte Event Handler stehen:
# <Window MouseMove="..." />  <-- FALSCH
# <Border Click="..." />      <-- FALSCH
# <Button DoubleClick="..." /> <-- FALSCH

# Sollte sein:
# <Window x:Name="ModernUIWindow" />
# <Border x:Name="TitleBar" />
# <Button x:Name="CloseButton" />
```

---

## Testing-Checkliste

- [x] XAML parses without errors (NO event handlers in XAML!)
- [x] Config loads as proper Hashtable
- [x] Images load from PNG directory
- [x] **TitleBar drag functionality works** (via PowerShell event binding with script:WindowReference)
- [x] **Window moves smoothly when dragging TitleBar**
- [x] Close button click event fires
- [x] **Close button PNG swaps on hover** (using $sender.Tag property)
- [x] **No blue hover effect on close button**
- [x] **Standard cursor shown** (no Hand cursor)
- [x] Application exits cleanly
- [x] All images display correctly

---

**Version**: 1.00.00 Final  
**Status**: Production Ready (alle kritischen Fixes + Dokumentation)  
**Datum**: 2025-12-26  
**Critical Lessons**: 
1. NEVER put event handlers in PowerShell-XAML
2. Use `$script:` scope for variables needed in event handlers
3. Use `$sender` and `.Tag` property for accessing handler data
4. Test variable availability in isolated event handler scopes
