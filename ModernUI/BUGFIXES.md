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
| Event Handler Parameter Binding | ✅ FIXED | HIGH | v1.00.00 |
| Image Path Resolution | ✅ FIXED | HIGH | v1.00.00 |

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
    $script:CloseButtonNormal = (get image)
    $script:CloseButtonHover = (get image)
    
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
Multiple issues combined:
1. Image loading worked but wasn't assigned to Image element
2. Image element didn't have proper binding
3. Grid layering issue with background image

**Solution:**
Ensured proper XAML structure and image assignment:

```xaml
<Grid>
    <!-- Background image first (appears behind) -->
    <Image 
        x:Name="BackgroundImage" 
        Stretch="UniformToFill" 
        HorizontalAlignment="Stretch" 
        VerticalAlignment="Stretch" />
    
    <!-- Overlay grid on top -->
    <Grid>
        <!-- Title bar and content -->
    </Grid>
</Grid>
```

Then assign in PowerShell:
```powershell
$bgImage = $window.FindName("BackgroundImage")
if ($script:BackgroundImage) {
    $bgImage.Source = $script:BackgroundImage  # Direct assignment
}
```

**Key Learning:**
Layering matters - background image must be first child of Grid. Always verify image is assigned to control.

---

### 5. Event Handler Parameter Binding

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
})
```

**Key Learning:**
Always use `param($sender, $e)` in event handlers, even if you don't use the parameters.

---

### 6. Image Path Resolution

**Symptoms:**
- "Image file not found" errors
- Images specified in config.json not loading
- Different behavior when running from different directories

**Root Cause:**
Relative paths don't work consistently:
```powershell
# ❌ WRONG - Relative paths are unreliable
$iconPath = "./PNG/appicon.png"  # May not work
$bgPath = "PNG/ModernUI-WinBG.png"  # Depends on working directory
```

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
$testBitmap = Load-BitmapImage -ImagePath $bgPath -ImageName "TestBG"
if ($testBitmap -eq $null) {
    Write-Host "ERROR: Image failed to load"
} else {
    Write-Host "SUCCESS: Image loaded"
}
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
$button.Add_Click({ Write-Host $_ })  # $_  is not the button!

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
- [ ] Close button hover effect works
- [ ] No crash when hovering over close button
- [ ] Hover effect PNG swaps correctly
- [ ] Standard cursor displays (no hand cursor)
- [ ] OK button is clickable
- [ ] Application closes cleanly
- [ ] No console errors or warnings
- [ ] No memory leaks on repeated close/open

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
