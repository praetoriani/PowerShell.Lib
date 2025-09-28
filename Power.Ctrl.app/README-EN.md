# Power.Ctrl.app - Installation Guide (English)

## Overview
Power.Ctrl.app is an advanced system control application that enables common system actions such as Lock, Logoff, Restart, and Shutdown through a user-friendly graphical interface. Version 1.00.04 implements important bug fixes and improvements.

## Required Files
1. **Power.Ctrl.app.ps1** - Main application script
2. **app-ui-main.xaml** - XAML file for the main window
3. **app-ui-popup.xaml** - XAML file for confirmation dialogs
4. **de-de.json** - German language file
5. **en-us.json** - English language file

## Installation

### Step 1: Prepare Files
1. Create a new folder for Power.Ctrl.app (e.g., `C:\Tools\Power.Ctrl.app\`)
2. Save all five generated files in this folder
3. Ensure all files are in the same directory

### Step 2: PowerShell Execution Policy
Open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3: Start Application
Navigate to the Power.Ctrl.app folder and run:
```powershell
.\Power.Ctrl.app.ps1
```

## Configuration

### Global Variables
Edit these variables at the beginning of the Power.Ctrl.app.ps1 file:

#### Change Language
```powershell
$global:globalLanguage = "de-de"  # For German
$global:globalLanguage = "en-us"  # For English
```

#### Set Window Position
```powershell
$global:globalWindowPosition = "center"     # Screen center
$global:globalWindowPosition = "lowerleft"  # Bottom left (0px distance)
$global:globalWindowPosition = "lowerright" # Bottom right (0px distance)
```

#### Enable/Disable Confirmation Dialog
```powershell
$global:globalShowConfirmationDialog = $true   # Show confirmation
$global:globalShowConfirmationDialog = $false  # Direct execution
```

### Add Additional Languages
1. Create a new JSON file following the pattern `[language]-[region].json`
2. Copy the structure from `de-de.json` or `en-us.json`
3. Translate all texts (UI elements, ToolTips, Console messages, Popup texts)
4. Change the `$global:globalLanguage` variable accordingly

## Functions

### Available Actions
- **Lock**: Locks the current workstation (immediate)
- **Logoff**: Logs off the current user (immediate)
- **Restart**: Restarts the computer (immediate, no delay)
- **Shutdown**: Shuts down the computer (immediate, no delay)

### Features in Version 1.00.04
- ✅ **Uniform Window Sizes**: Both windows 520x200 pixels for seamless switching
- ✅ **Precise Positioning**: 0px distance to screen edges and taskbar
- ✅ **Improved Popup Buttons**: Taller Yes/No buttons for better usability
- ✅ **Corrected Popup Workflow**: No button returns to main window (doesn't exit)
- ✅ **Intelligent X-Button Handling**: Popup-X returns to Main, Main-X exits program
- ✅ **Console Management**: Automatic console restoration on program exit without action
- ✅ **Fully Localized ToolTips**: All help texts language-dependent
- ✅ **Dark Mode User Interface**: Consistent dark design
- ✅ **Larger Buttons**: 48x48 pixels for better usability
- ✅ **Icons from Windows Shell32.dll**: System-compliant display
- ✅ **Multilingual Support**: 100% localized (UI + Console + ToolTips)
- ✅ **Always On Top**: Both windows remain visible

## Changes in Version 1.00.04

### Bug Fixes
1. **Identical Window Sizes**: Both XAML files now use 520x200 pixels
2. **Precise Corner Positioning**:
   - `lowerleft`: Left = 0, Top = ScreenHeight - WindowHeight
   - `lowerright`: Left = ScreenWidth - WindowWidth, Top = ScreenHeight - WindowHeight
3. **Taller Popup Buttons**: MinHeight = 35px for better clickability
4. **Corrected No Button**: Returns to main window instead of exiting program
5. **X-Button Logic**: Popup-X returns to Main, only Main-X exits program
6. **Console Restoration**: Console becomes visible again on program exit without action

### Improved Functionality
- **Return-ToMainWindow Function**: Clean transition from Popup back to Main
- **Close-Application Function**: Controlled exit with optional console restoration
- **Console Management**: Separate functions for Hide/Show Console
- **Event Handlers**: Popup-Closing-Event prevents actual closing and returns to Main

### Extended JSON Messages
New console messages added:
- `ApplicationClosedWithoutAction`: On program exit without system action
- `MainWindowClosing`: On Main window X-button click
- `PopupWindowClosing`: On Popup window X-button click
- `ReturnedToMainWindow`: On successful return to Main
- `ActionExecutedClosing`: On action execution before program exit
- Console-Handle-Management: Messages for console operations

## Application Workflow

### With Confirmation Dialog ($globalShowConfirmationDialog = $true)
1. **Main Window** is displayed at chosen position (520x200)
2. **User clicks Action** → Main window is hidden
3. **Popup Dialog** appears at identical position (520x200) with specific confirmation
4. **User clicks "Yes"** → Action is executed, program exits (without console restoration)
5. **User clicks "No"** or **X-Button** → Popup closes, main window visible again
6. **User clicks Main-X** → Program exits with console restoration

### Without Confirmation Dialog ($globalShowConfirmationDialog = $false)
1. **Main Window** is displayed
2. **User clicks Action** → Action is executed immediately, program exits
3. **User clicks Main-X** → Program exits with console restoration

## Window Positioning

### Center (Default)
- Position: Screen center
- Implementation: `WindowStartupLocation = CenterScreen`

### LowerLeft
- Position: Lower left corner
- Coordinates: `Left = 0, Top = ScreenHeight - WindowHeight`
- **0px distance** to left edge and taskbar

### LowerRight  
- Position: Lower right corner
- Coordinates: `Left = ScreenWidth - WindowWidth, Top = ScreenHeight - WindowHeight`
- **0px distance** to right edge and taskbar

## Troubleshooting

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### XAML Files Not Found
Ensure both XAML files are present:
- `app-ui-main.xaml` (Main window - 520x200)
- `app-ui-popup.xaml` (Confirmation dialog - 520x200)

### Window Positioning Not Working
Check the `$global:globalWindowPosition` variable:
- Valid values: `"center"`, `"lowerleft"`, `"lowerright"`
- Invalid values automatically fall back to `"center"`

### Popup Doesn't Return to Main
- Verify both XAML files have the same size
- Ensure event handlers are correctly registered
- `Return-ToMainWindow` function handles the transition

### Console Not Restored
- Console handle is initialized at program start
- Normal X-button click on Main calls `Close-Application $true`
- Action execution calls `Close-Application $false` (no console restoration)

## Customizations

### Change Window Sizes
**IMPORTANT**: Both XAML files must have identical sizes!

**Main Window AND Popup** (change both files):
```xml
Width="520" Height="200"
```

### Adjust Button Heights
**Popup Buttons** (app-ui-popup.xaml):
```xml
<Setter Property="MinHeight" Value="35"/>
```

### Extend Positioning Modes
Extend the `Set-WindowPosition` function:
```powershell
"topleft" {
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $Window.Left = 0
    $Window.Top = 0
}
"topright" {
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $Window.Left = $screenWidth - $Window.Width
    $Window.Top = 0
}
```

### Customize Console Behavior
```powershell
# Don't minimize console at startup
# Comment out this line:
# Hide-ConsoleWindow

# Never restore console
# Change Close-Application calls to:
Close-Application $false
```

## Technical Details

### System Requirements
- Windows 7 or higher
- PowerShell 5.0 or higher
- .NET Framework 4.5 or higher
- Minimum 1024x768 screen resolution

### Technologies Used
- **PowerShell with WPF** (Windows Presentation Foundation)
- **XAML** for user interfaces (2 identical window sizes)
- **JSON** for complete localization
- **Win32 API** for icon extraction and console management

### Security Notes
- Uses Windows standard commands (shutdown.exe, rundll32.exe)
- **Immediate execution** without delay for Restart/Shutdown
- **Confirmation dialog** optionally activatable for additional security
- **Intelligent program termination**: Only on actions or Main-X
- No elevated privileges required

### Window Specifications
```
Main Window (app-ui-main.xaml):
- Size: 520x200 pixels (identical to Popup)
- 4 Action buttons (48x48 pixels)
- Icons: 32x32 pixels
- Position: Configurable

Popup Window (app-ui-popup.xaml):
- Size: 520x200 pixels (identical to Main)
- 2 Buttons (Yes/No, MinHeight: 35px)
- Position: Synchronized with main window
- Modal: Blocks interaction with main window
```

### Console Management
```
At startup:     Minimize console
On Main-X:      Restore console + exit program
On Popup-X:     Only return to Main
On No:          Only return to Main
On Yes:         Execute action + exit program (without console)
```

### Event Handler Logic
```
Main-Window:
- Action buttons → Handle-ActionClick
- X-Button → Close-Application $true

Popup-Window:
- Yes button → Execute-PendingAction
- No button → Return-ToMainWindow  
- X-Button → Return-ToMainWindow (Cancel = true)
```

Power.Ctrl.app v1.00.04 now provides a perfectly tuned, error-free user experience with seamless window switching, precise positioning, and intelligent console management for maximum usability.