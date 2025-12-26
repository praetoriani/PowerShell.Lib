# Bug Fixes and Known Issues

**ModernUI v1.00.00**

This document details all known issues, fixes implemented, and best practices for avoiding common problems.

---

## Status: All Critical Issues Fixed ✅

| Issue | Status | Severity | Fixed In |
|-------|--------|----------|----------|
| XAML Parser Error (x:Class) | ✅ FIXED | CRITICAL | v1.00.00 |
| Window Dragging Not Working | ✅ FIXED | CRITICAL | v1.00.00 |
| Close Button Hover Crash | ✅ FIXED | CRITICAL | v1.00.00 |
| Background Image Not Displaying | ✅ FIXED | CRITICAL | v1.00.00 |
| Transparent Titlebar Not Working | ✅ FIXED | CRITICAL | v1.00.00 |
| Hover Effect Not Working | ✅ FIXED | CRITICAL | v1.00.00 |
| Event Handler Parameter Binding | ✅ FIXED | HIGH | v1.00.00 |
| Image Path Resolution | ✅ FIXED | HIGH | v1.00.00 |
| White Titlebar Blocks Background | ✅ FIXED | CRITICAL | v1.00.00 |
| XAML Triggers Unreliable | ✅ FIXED | CRITICAL | v1.00.00 |

---

## Fixed Issues

### 1. XAML Parser Error (x:Class Directive)

**Error Message:**
```
Zeilennummer "1" und Zeilenposition "9" von "Der angegebene Klassenname 'ModernUI.MainWindow' 
entspricht nicht dem tatsaechlichen Stamminstanztyp 'System.Windows.Window'.
Entfernen Sie die Klassendirektive, oder geben Sie eine Instanz ueber XamlObjectWriterSettings.RootObjectInstance an."
```

**Root Cause:**
PowerShell's `System.Windows.Markup.XamlReader` cannot load code-behind classes. The XAML had:
```xaml
<Window x:Class="ModernUI.MainWindow" ...>
```

**Solution:**
Removed the `x:Class` directive entirely. Changed to:
```xaml
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ...>
```

**Key Learning:**
Never use `x:Class` in PowerShell-XAML. Use only `x:Name` attributes and bind events in PowerShell.

---

### 2. Window Dragging Not Working

**Symptoms:**
- Title bar clicks don't move the window
- No error messages in console
- DragMove() appears to execute but has no effect

**Root Cause:**
Variable scoping issue in event handlers. The code attempted:
```powershell
# ❌ WRONG - $Window is null in event handler
function Register-EventHandlers {
    param([System.Windows.Window]$Window)
    $titleBar.Add_MouseLeftButtonDown({
        param($sender, $e)
        $Window.DragMove()  # ERROR: $Window is $null here!
    })
}
```

**Why This Happens:**
Event handler scripts run in an **isolated scope**. Local function variables are NOT accessible to event handlers:
- ✅ `$Global:` variables ARE accessible
- ✅ `$script:` variables ARE accessible
- ❌ Local function variables are NOT accessible
- ❌ Function parameters are NOT accessible

**Solution:**
Store the window reference in **script scope**:

```powershell
# ✅ CORRECT - Use $script: scope
function Initialize-WPF {
    param([xml]$Xaml)
    
    $xmlReader = [System.Xml.XmlNodeReader]::new($Xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
    
    # Store in script scope (CRITICAL!)
    $script:WindowReference = $window
    
    $titleBar = $window.FindName("TitleBar")
    
    # Now event handler can access it
    $titleBar.Add_MouseLeftButtonDown({
        param($sender, $e)
        if ($script:WindowReference -ne $null) {
            $script:WindowReference.DragMove()  # Works!
        }
    })
}
```

**Key Learning:**
Always use `$script:` scope for variables needed in event handlers.

---

### 3. Close Button Hover Crash

**Symptoms:**
- Application closes immediately when hovering over close button
- Error message: "The property 'Source' was not found for this object"
- Full error in console:
  ```
  Show-ModernUI : [ERROR] Fehler beim Starten der ModernUI: Ausnahme beim Aufrufen von "ShowDialog" 
  mit 0 Argument(en): "Die Eigenschaft "Source" wurde fuer dieses Objekt nicht gefunden."
  ```

**Root Cause:**
Attempted to use `.FindName()` inside the event handler to get the image control:
```powershell
# ❌ WRONG - FindName doesn't work reliably in event handlers
$closeButton.Add_MouseEnter({
    param($sender, $e)
    # FindName fails here!
    $image = $window.FindName("CloseButtonImage")
    $image.Source = $hoverBitmap  # Crashes!
})
```

The `$image` object is null, so accessing `.Source` property fails.

**Solution:**
Store the image control reference in **script scope** during initialization:

```powershell
# During initialization
function Initialize-WPF {
    param([xml]$Xaml)
    
    $xmlReader = [System.Xml.XmlNodeReader]::new($Xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
    
    # Store references in script scope
    $script:WindowReference = $window
    $script:CloseButtonImageControl = $window.FindName("CloseButtonImage")
    $script:CloseButtonNormal = (LoadBitmapImage ...)
    $script:CloseButtonHover = (LoadBitmapImage ...)
    
    $closeButton = $window.FindName("CloseButton")
    
    # Now use script-scoped references in event handler
    $closeButton.Add_MouseEnter({
        param($sender, $e)
        if ($script:CloseButtonHover -ne $null -and $script:CloseButtonImageControl -ne $null) {
            $script:CloseButtonImageControl.Source = $script:CloseButtonHover  # Works!
        }
    })
}
```

**Key Difference:**
- ❌ WRONG: Use `.FindName()` inside event handler
- ✅ CORRECT: Store control reference in `$script:` scope, use it in event handler

**Key Learning:**
Never call `.FindName()` or access local variables inside event handlers. Store everything needed in `$script:` scope.

---

### 4. Background Image Not Displaying

**Symptoms:**
- Window appears with gray/blank background
- Console shows images loaded successfully
- No error messages
- Title bar displays but background is missing

**Root Cause:**
In rahmenlosen (`AllowsTransparency="True"`) WPF-Fenstern wird `Grid.Background` ignoriert. WPF rendert in diesem Modus mit Direct3D, und nur `Window.Background` wird korrekt verarbeitet.

**Technical Explanation:**
When `AllowsTransparency="True"` is set on a Window:
- WPF switches rendering from GDI to Direct3D
- Direct3D ignores `Grid.Background` and only renders `Window.Background`
- This is by design for transparency effects

**Solution:**
```powershell
# CRITICAL FIX: Set background on Window, NOT Grid!
if ($script:BackgroundBrush) {
    # Set the brush on Window, not Grid!
    $window.Background = $script:BackgroundBrush
    Write-Host "[OK] Hintergrundbild auf Window gesetzt" -ForegroundColor Green
}
```

**Never do this:**
```powershell
# ❌ WRONG - Won't display with AllowsTransparency=True
$rootGrid.Background = $script:BackgroundBrush  # IGNORED!
```

**Key Learning:**
Bei rahmenlosen Fenstern: **IMMER** `Window.Background` verwenden, `Grid.Background` wird ignoriert!

---

### 5. White Titlebar Blocks Background Image

**Symptoms:**
- White/colored bar at top of window
- Background image not visible under titlebar
- Titlebar appears as separate colored rectangle

**Root Cause:**
Titlebar had `Background="#FFFFFF"` (solid white), which completely blocked the background image from showing through:

```xaml
<!-- ❌ WRONG - Solid background blocks image -->
<Border x:Name="TitleBar" Grid.Row="0" Background="#FFFFFF" Height="40" ...>
    <!-- Title bar content -->
</Border>
```

**Solution:**
Changed titlebar background to `Transparent`:

```xaml
<!-- ✅ CORRECT - Transparent background lets image show through -->
<Border x:Name="TitleBar" Grid.Row="0" Background="Transparent" Height="40" ...>
    <!-- Title bar content -->
</Border>
```

**Key Learning:**
In frameless windows mit Background Image: All overlay containers sollten `Background="Transparent"` sein, damit das Background-Image durchscheint.

---

### 6. Hover Effect Not Working Correctly

**Symptoms:**
- Close button doesn't change image on hover
- Image swap doesn't happen reliably
- Or hover effect only works sometimes
- No visual feedback on hover

**Root Cause:**
XAML Triggers funktionieren nicht zuverlässig für `Image.Source` bei dynamisch geladenen Bildern aus PowerShell:

```xaml
<!-- ❌ WRONG - XAML Triggers unreliable for dynamic images -->
<Image x:Name="CloseButtonImage" Source="{Binding ...}">
    <Image.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter Property="Source" Value="{Binding HoverImage}" />
        </Trigger>
    </Image.Triggers>
</Image>
```

Problems with this approach:
- Binding doesn't work with dynamically loaded images
- Trigger evaluation is unreliable
- No feedback if trigger fails

**Solution:**
Nutze PowerShell Event Handler statt XAML Triggers:

```powershell
# Store images in script scope
$script:CloseButtonImageControl = $window.FindName("CloseButtonImage")
$script:CloseButtonImageSource_Normal = (LoadedBitmapImage)  # Pre-loaded
$script:CloseButtonImageSource_Hover = (LoadedBitmapImage)   # Pre-loaded

$closeButton = $window.FindName("CloseButton")

# Use MouseEnter event for reliable hover in
$closeButton.Add_MouseEnter({
    param($sender, $e)
    if ($script:CloseButtonImageSource_Hover -ne $null) {
        $script:CloseButtonImageControl.Source = $script:CloseButtonImageSource_Hover
    }
})

# Use MouseLeave event for reliable hover out
$closeButton.Add_MouseLeave({
    param($sender, $e)
    if ($script:CloseButtonImageSource_Normal -ne $null) {
        $script:CloseButtonImageControl.Source = $script:CloseButtonImageSource_Normal
    }
})
```

**Why This Works Better:**
- ✅ Pre-load images during initialization (not during hover)
- ✅ XAML Triggers only work with static XAML resources
- ✅ PowerShell Events are reliable for dynamic images
- ✅ Event Handlers give full control over swap process
- ✅ Easy to debug if something goes wrong
- ✅ Guaranteed execution with error handling

**Why XAML Triggers Don't Work:**
- ❌ Triggers only bind to `StaticResource` or `DynamicResource`
- ❌ PowerShell doesn't register resources in XAML namespace
- ❌ No way for Trigger to know about PowerShell-loaded images
- ❌ Fallback to default binding doesn't happen

**Key Learning:**
Für komplexe Hover-Effekte: PowerShell Events verwenden, nie XAML Triggers!

---

### 7. Event Handler Parameter Binding

**Symptoms:**
- Event handlers execute but `$sender` is undefined
- Cannot access event information
- Errors when trying to use parameters

**Root Cause:**
Event handlers were registered without proper parameter declaration:
```powershell
# ❌ WRONG - No parameters declared
$titleBar.Add_MouseLeftButtonDown({
    # $sender is undefined
    # $e is undefined
    $_ is the error object (not what we want)
})
```

**Solution:**
Always declare parameters in event handlers:
```powershell
# ✅ CORRECT - Parameters declared
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)  # Declare parameters!
    # Now $sender and $e are available
    $sender.Opacity = 0.8  # Works!
    $e.Handled = $true
})
```

**Key Learning:**
Always use `param($sender, $e)` in event handlers, even if you don't use the parameters.

---

### 8. Image Path Resolution

**Symptoms:**
- "Image file not found" errors
- Images specified in config.json not loading
- Different behavior when running from different directories
- Works when running from script directory, fails from other locations

**Root Cause:**
Relative paths don't work consistently:
```powershell
# ❌ WRONG - Relative paths are unreliable
$iconPath = "./PNG/appicon.png"  # Depends on current directory
$bgPath = "PNG/ModernUI-WinBG.png"  # May not work
```

The current directory when PowerShell executes a script can vary:
- Running from different directories
- Called from another script
- Executed by a scheduler or automation tool

**Solution:**
Convert all paths to absolute paths using script root:
```powershell
# ✅ CORRECT - Absolute paths are reliable
function Resolve-ImagePath {
    param(
        [string]$ImageName,
        [string]$BasePath = "PNG"
    )
    
    # Use $PSScriptRoot (always the script directory)
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $BasePath | 
                Join-Path -ChildPath $ImageName
    
    if (Test-Path -Path $fullPath -PathType Leaf) {
        return (Resolve-Path -Path $fullPath).Path  # Return absolute path
    }
    
    return $null
}

# Usage in config loading
$bgImagePath = Resolve-ImagePath -ImageName $config.paths.backgroundImage
```

**Key Learning:**
Always use `$PSScriptRoot` for relative path resolution. Convert to absolute paths immediately.

---

## Troubleshooting Guide

### Scenario 1: Application Won't Start

**Check:**
1. PowerShell version (`$PSVersionTable.PSVersion`)
2. .NET Framework version (`[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()`)
3. Required assemblies load (`[System.Windows.Forms.Application]::EnableVisualStyles()` works)

**Solution:**
Update PowerShell to 7.0+ and .NET Framework to 4.8+

---

### Scenario 2: "Property 'Source' not found" Error

**This is CRITICAL - follows this exact pattern:**

1. **Hover over close button**
2. **Application crashes**
3. **Console shows: "The property 'Source' was not found for this object"**

**Diagnosis:**
You're using `.FindName()` in an event handler or the image control reference is null.

**Fix:**
```powershell
# Store image control in script scope
$script:CloseButtonImageControl = $window.FindName("CloseButtonImage")

# Use in event handler
$closeButton.Add_MouseEnter({
    param($sender, $e)
    $script:CloseButtonImageControl.Source = $script:CloseButtonHover
})
```

---

### Scenario 3: Window Cannot Be Dragged

**Check:**
1. `WindowStyle="None"` in XAML
2. `AllowsTransparency="True"` in XAML
3. `$script:WindowReference` is set correctly

**Debug Code:**
```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    Write-Host "MouseDown triggered"
    if ($script:WindowReference -ne $null) {
        Write-Host "WindowReference found"
        try {
            $script:WindowReference.DragMove()
            Write-Host "DragMove executed"
        }
        catch {
            Write-Host "ERROR: $_"
        }
    } else {
        Write-Host "ERROR: WindowReference is null!"
    }
})
```

---

### Scenario 4: Images Not Displaying

**Check:**
1. PNG files exist in correct directory
2. File paths in config.json are correct
3. Images are valid PNG format
4. Image elements have `x:Name` attributes

**Debug Code:**
```powershell
# Test path resolution
$bgPath = Resolve-ImagePath -ImageName "ModernUI-WinBG.png"
Write-Host "Background path: $bgPath"
Test-Path $bgPath -PathType Leaf | Write-Host  # Should be True

# Test image loading
$testBitmap = Load-BitmapImage -ImagePath $bgPath
if ($testBitmap -eq $null) {
    Write-Host "ERROR: Image failed to load"
} else {
    Write-Host "SUCCESS: Image loaded"
}
```

---

### Scenario 5: Titlebar Blocks Background Image

**Check:**
1. TitleBar `Background` is set to `Transparent` (not a color)
2. All child containers of TitleBar have `Background="Transparent"`
3. Window.Background is set to the ImageBrush

**Debug Code:**
```powershell
$titleBar = $window.FindName("TitleBar")
Write-Host "TitleBar Background: $($titleBar.Background)"  # Should show Transparent
Write-Host "Window Background: $($window.Background)"  # Should show ImageBrush
```

**Fix:**
Verify XAML has transparent backgrounds:
```xaml
<!-- Check XAML TitleBar -->
<Border x:Name="TitleBar" Background="Transparent" ...>
    <!-- Should NOT have: Background="#FFFFFF" or any color -->
</Border>
```

---

### Scenario 6: Hover Effect Not Working

**Check:**
1. Images are pre-loaded in script scope
2. `script:CloseButtonImageControl` is set correctly
3. MouseEnter and MouseLeave events are registered
4. Image sources are not null

**Debug Code:**
```powershell
$closeButton.Add_MouseEnter({
    param($sender, $e)
    Write-Host "MouseEnter triggered"
    Write-Host "Normal image: $($script:CloseButtonImageSource_Normal -eq $null)"
    Write-Host "Hover image: $($script:CloseButtonImageSource_Hover -eq $null)"
    Write-Host "Image control: $($script:CloseButtonImageControl -eq $null)"
    if ($script:CloseButtonImageSource_Hover -ne $null) {
        $script:CloseButtonImageControl.Source = $script:CloseButtonImageSource_Hover
        Write-Host "Source updated successfully"
    }
})
```

---

## Critical Rules for PowerShell-WPF

### Rule 1: Never Use Event Handlers in XAML

```xaml
<!-- ❌ WRONG -->
<Window MouseMove="Window_MouseMove" />
<Button Click="Button_Click" />

<!-- ✅ CORRECT -->
<Window x:Name="MyWindow" />
<Button x:Name="MyButton" />
```

Bind events in PowerShell instead.

### Rule 2: Use script: Scope for Event Variables

```powershell
# ❌ WRONG
function Initialize {
    param($window)
    $button.Add_Click({ $window.Close() })  # Fails!
}

# ✅ CORRECT
function Initialize {
    param($window)
    $script:WindowRef = $window
    $button.Add_Click({ $script:WindowRef.Close() })  # Works!
}
```

### Rule 3: Always Use param() in Event Handlers

```powershell
# ❌ WRONG
$button.Add_Click({ Write-Host $_ })  # $_ is not the button!

# ✅ CORRECT
$button.Add_Click({ param($sender, $e) 
    Write-Host $sender  # $sender is the button
})
```

### Rule 4: Never Call .FindName() in Event Handlers

```powershell
# ❌ WRONG - Unreliable
$button.Add_MouseEnter({
    param($sender, $e)
    $image = $window.FindName("MyImage")  # May be null!
    $image.Source = ...  # Crashes!
})

# ✅ CORRECT - Reliable
$script:ImageControl = $window.FindName("MyImage")
$button.Add_MouseEnter({
    param($sender, $e)
    $script:ImageControl.Source = ...  # Always works!
})
```

### Rule 5: Always Use Absolute Paths

```powershell
# ❌ WRONG - Relative paths are unreliable
$path = "./PNG/image.png"

# ✅ CORRECT - Absolute paths are reliable
$path = Join-Path $PSScriptRoot "PNG" | Join-Path -ChildPath "image.png"
```

### Rule 6: Set Window Background, Not Grid Background

```powershell
# ❌ WRONG - Won't display with AllowsTransparency=True
$rootGrid.Background = $imageBrush

# ✅ CORRECT - Always displays
$window.Background = $imageBrush
```

### Rule 7: Use Transparent Backgrounds in Frameless Windows

```xaml
<!-- ❌ WRONG - Blocks background image -->
<Border Background="#FFFFFF" />

<!-- ✅ CORRECT - Lets background image show through -->
<Border Background="Transparent" />
```

### Rule 8: Pre-Load Images, Don't Load in Event Handlers

```powershell
# ❌ WRONG - Slow and unpredictable
$button.Add_MouseEnter({
    $image = Load-BitmapImage ...  # Slow!
    $control.Source = $image
})

# ✅ CORRECT - Fast and reliable
$script:HoverImage = Load-BitmapImage ...  # Load once
$button.Add_MouseEnter({
    $script:ImageControl.Source = $script:HoverImage  # Fast!
})
```

---

## Performance Tips

### 1. Cache BitmapImages

```powershell
# Load once during initialization
$script:CloseButtonNormal = Load-BitmapImage ...
$script:CloseButtonHover = Load-BitmapImage ...

# Reuse in event handlers
$closeButton.Add_MouseEnter({
    $script:CloseButtonImageControl.Source = $script:CloseButtonHover
})
```

### 2. Use Freeze() for Thread Safety

```powershell
# Always freeze images before cross-thread access
$bitmap.Freeze()  # Make immutable
# Now safe to use in event handlers
```

### 3. Minimize Try-Catch Overhead

```powershell
# Validate BEFORE event handler, not inside
if ($script:ImageControl -eq $null) {
    Write-Error "Image control not initialized"
    return
}

# Event handler is clean and fast
$button.Add_Click({ 
    $script:ImageControl.Source = ...  # No extra checks needed
})
```

---

## Testing Checklist

Before releasing any changes, verify:

- [ ] Application starts without errors
- [ ] Configuration loads correctly
- [ ] All images display properly
- [ ] Title bar is draggable
- [ ] Window moves smoothly
- [ ] Close button click works
- [ ] Close button hover effect works (image changes)
- [ ] No crash when hovering over close button
- [ ] Hover effect PNG swaps correctly (gray → red)
- [ ] Standard cursor displays (no hand cursor on button)
- [ ] OK button is clickable
- [ ] Application closes cleanly
- [ ] No console errors or warnings
- [ ] No memory leaks on repeated close/open
- [ ] Titlebar is transparent (background image shows through)
- [ ] All UI elements visible over background image
- [ ] Window can still be dragged after hover
- [ ] Hover effect works consistently

---

## Contact & Support

**Found a bug?**
1. Verify it's not listed in this document
2. Check error messages carefully
3. Review troubleshooting scenarios
4. Create GitHub issue with:
   - Error message (exact text)
   - Steps to reproduce
   - Your system info (OS, PowerShell version, .NET version)
   - Screenshot if applicable

**Questions?**
- GitHub: [@praetoriani](https://github.com/praetoriani)
- Email: marc.sczepanski@gmail.com
- Location: Freising, Bavaria, Germany

---

**Last Updated:** December 26, 2025  
**Version:** 1.00.00  
**Status:** All Critical Issues Fixed ✅
