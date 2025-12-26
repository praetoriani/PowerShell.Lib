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

## Batch 2: Functionality Issues (Window Dragging & Hover Effects)

### Fehler 1: Fenster kann nicht verschoben werden

**Symptome:**
- Klick und Drag auf TitleBar funktioniert nicht
- Fenster bewegt sich nicht
- DragMove() wird ausgefuehrt, hat aber keine Wirkung

**Ursache:**
Die Kombination von `WindowStyle="None"` + `AllowsTransparency="True"` braucht spezielles Handling.
Die DragMove()-Methode funktioniert nur wenn:
1. Sie innerhalb eines MouseLeftButtonDown-Events aufgerufen wird
2. Das Event von einem interaktiven Element stammt
3. Der Dragging-State korrekt verwaltet wird

**Loesung 1 - XAML Update:**
```xaml
<Border x:Name="TitleBar"
        DockPanel.Dock="Top" 
        Height="36" 
        Cursor="Hand">
```

Ergaenzungen:
- `x:Name="TitleBar"`: Fuer PowerShell Event-Binding
- `Cursor="Hand"`: User-Feedback beim Hover ueber TitleBar

**WICHTIG - Was man NICHT machen sollte:**
```xaml
<!-- FALSCH - Diese Event Handler muessen in PowerShell registriert werden! -->
<Border x:Name="TitleBar" MouseLeftButtonDown="TitleBar_MouseLeftButtonDown" ...>
<Window MouseMove="Window_MouseMove" ...>
```

**Loesung 2 - PowerShell Event Handler:**
```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    try {
        $Global:ModernUI_State.IsDragging = $true
        $Window.DragMove()  # Nur im MouseLeftButtonDown Event aufrufbar!
    }
    catch {
        Write-Verbose "[ModernUI] DragMove error: $_"
    }
    finally {
        $Global:ModernUI_State.IsDragging = $false
    }
})

$titleBar.Add_MouseLeftButtonUp({
    $Global:ModernUI_State.IsDragging = $false
})
```

**Wichtige Details:**
- Try-Catch-Finally fuer sichere State-Verwaltung
- IsDragging Flag verhindert gleichzeitige Drag-Events
- MouseLeftButtonUp Handler fuer sauberes Ende
- KEINE Event-Handler in der XAML definieren - nur Names (x:Name)

---

### Fehler 2: Close Button Hover zeigt blaues Quadrat

**Symptome:**
- Hover ueber Close Button zeigt hellblaues Farbquadrat
- PNG wird halb sichtbar dahinter
- Soll stattdessen PNG tauschen (normal <-> hover)

**Ursache:**
Der WPF Button hat einen Default-Hover-Style, der das PNG verdeckt:
```xaml
<!-- Standard Button Behavior -->
<Button>...
  <!-- Default: Blaer Hover-Hintergrund wird gezeichnet -->
```

**Loesung 1 - XAML Button Style:**
```xaml
<Style x:Key="CloseButtonStyle" TargetType="Button">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="Button">
                <Border Background="{TemplateBinding Background}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <!-- Remove default hover effect -->
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter Property="Background" Value="Transparent"/>
                    </Trigger>
                    <Trigger Property="IsPressed" Value="True">
                        <Setter Property="Background" Value="Transparent"/>
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
```

Anwendung:
```xaml
<Button x:Name="CloseButton" 
        Style="{StaticResource CloseButtonStyle}"
        ...
        Padding="6">
    <Image x:Name="CloseButtonImage" />
</Button>
```

**WICHTIG - Was man NICHT machen sollte:**
```xaml
<!-- FALSCH - Sollte in PowerShell registriert werden -->
<Button x:Name="CloseButton" Click="CloseButton_Click" ...>

<!-- FALSCH - Undefined Event Handler -->
<Window MouseMove="Window_MouseMove" ...>
```

**Loesung 2 - PowerShell Image Swap Logic:**

**Falscher Ansatz (wie zuvor):**
```powershell
# FALSCH - Fehler bei BitmapImage-Erstellung
$closeButtonImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([uri]$closePath)
```

**Richtiger Ansatz:**
```powershell
$closeButton.Add_MouseEnter({
    param($sender, $e)
    try {
        if (Test-Path $sender.Tag.HoverPath -PathType Leaf) {
            # Proper BitmapImage initialization
            $hoverBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $hoverBitmap.BeginInit()               # Start initialization
            $hoverBitmap.UriSource = [uri]$sender.Tag.HoverPath
            $hoverBitmap.CacheOption = `
                [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad  # Load sofort
            $hoverBitmap.EndInit()                 # End initialization
            $hoverBitmap.Freeze()                  # Thread-safe
            
            # Swap image
            $sender.Tag.ImageControl.Source = $hoverBitmap
        }
    }
    catch {
        Write-Verbose "[ModernUI] Error setting hover image: $_"
    }
})
```

**Wichtige Details:**
- **BeginInit/EndInit**: XAML-Pattern fuer WPF Object-Initialisierung
- **CacheOption = OnLoad**: Bitmap sofort laden, nicht lazy
- **Freeze()**: Thread-Safety fuer Bitmap-Sharing
- **ImageControl.Source**: Direktes Swap des PNG
- **NO Event Handlers in XAML**: Nur x:Name verwenden!

---

## Zusammenfassung der Aenderungen

| Batch | Problem | Datei | Loesung |
|-------|---------|-------|----------|
| **1** | XAML Parser Error | ModernUI.xaml | Removed x:Class |
| **1** | Undefined Event Handlers | ModernUI.xaml | Remove handler attributes, use x:Name only |
| **1** | ConvertTo-Hashtable | ModernUI.ps1 | Fixed recursion |
| **1** | Event Parameter Binding | ModernUI.ps1 | Added param() |
| **1** | Relative Paths | ModernUI.ps1 | Use absolute paths |
| **2** | Window Drag nicht funktional | ModernUI.xaml + .ps1 | DragMove in Try-Finally |
| **2** | Close Button Hover Blau | ModernUI.xaml + .ps1 | Remove FocusVisualStyle, BeginInit/EndInit |

---

## KRITISCHE REGEL FÜR POWERSHELL-XAML

### ⚠️ NEVER USE EVENT HANDLERS IN XAML

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

Alle Event Handler muessen in PowerShell registriert werden:
```powershell
$window.Add_MouseMove({ ... })
$titleBar.Add_MouseLeftButtonDown({ ... })
$closeButton.Add_Click({ ... })
```

### Warum?
- PowerShell XamlReader kann keine Code-Behind Methoden aufrufen
- Undefined Event Handler verursachen Parser-Fehler
- Alle Logik sollte in PowerShell sein, nicht XAML

---

## Wichtige PowerShell-WPF Konzepte

### 1. Window.DragMove()
- Muss innerhalb eines **MouseLeftButtonDown** Event aufgerufen werden
- Braucht `WindowStyle="None"` fuer rahmenloses Fenster
- Try-Catch empfohlen da Exception bei bestimmten Window-States

### 2. BitmapImage Initialization
```powershell
# RICHTIG - 3-Schritt Prozess
$bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
$bitmap.BeginInit()
$bitmap.UriSource = [uri]"path\to\image.png"
$bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$bitmap.EndInit()
$bitmap.Freeze()

# FALSCH - One-liner schlaegt fehl
$bitmap = [System.Windows.Media.Imaging.BitmapImage]::new([uri]"path")
```

### 3. Button Styling in PowerShell-XAML
- FocusVisualStyle="{x:Null}" entfernt blaues Quad
- ControlTemplate.Triggers fuer IsMouseOver/IsPressed
- Content muss in ContentPresenter sein

### 4. Event Handler Scope
```powershell
# Global Access
$script:CloseButtonImage = $Window.FindName("CloseButtonImage")

# Im Handler
$closeButton.Add_MouseEnter({
    $script:CloseButtonImage.Source = ...  # Zugriff auf script-scoped Variable
})
```

### 5. XAML in PowerShell - Nur Names verwenden
```xaml
<!-- Alle diese sind OK - verwenden x:Name -->
<Window x:Name="MyWindow" ...>
<Border x:Name="TitleBar" ...
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
# Teste DragMove direkt
$titleBar.Add_MouseLeftButtonDown({
    Write-Host "MouseDown triggered"
    $Window.DragMove()
    Write-Host "DragMove executed"
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
    # ...image swap logic...
    Write-Host "Image swapped"
})

$closeButton.Add_MouseLeave({
    Write-Host "Hover ended"
    # ...restore logic...
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
- [x] **TitleBar drag functionality works** (via PowerShell event binding)
- [x] **Window moves smoothly when dragging TitleBar**
- [x] Close button click event fires
- [x] **Close button PNG swaps on hover** (BeginInit/EndInit/Freeze)
- [x] **No blue hover effect on close button**
- [x] Application exits cleanly
- [x] All images display correctly

---

**Version**: 1.00.00 Final  
**Status**: Production Ready (alle kritischen Fixes + Dokumentation)  
**Datum**: 2025-12-26  
**Critical Lesson**: NEVER put event handlers in PowerShell-XAML - only use x:Name and register handlers in PowerShell
