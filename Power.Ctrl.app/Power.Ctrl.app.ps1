<#
.SYNOPSIS
    Power.Ctrl.app - Simple System Control Application
.DESCRIPTION
    A simple application that provides buttons for common system actions: Lock, Logoff, Restart, and Shutdown.
    Features dark mode UI, multilingual support via JSON language files, icons from Shell32.dll, and optional logging.
.NOTES
    Creation Date: 28.09.2025
    Last Update: 28.09.2025
    Version: v1.00.10
    Author: Praetoriani
    Website: https://github.com/praetoriani
#>

#Requires -Version 5.0

# Load required assemblies for WPF
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

# ====================================
# GLOBAL APPLICATION VARIABLES
# ====================================
$global:globalAppName = "Power.Ctrl.app"
$global:globalAppVers = "v1.00.10"
$global:globalAppPath = $PSScriptRoot
$global:globalAppIcon = Join-Path $globalAppPath "appicon.ico"
$global:globalLanguage = "de-de" # Change this to "en-us" for English

# Window positioning: "center", "lowerleft", "lowerright"
$global:globalWindowPosition = "lowerleft"

# Show confirmation dialog: $true or $false
$global:globalShowConfirmationDialog = $true

# Create log file: $true or $false
$global:globalCreateLogFile = $false

# Language and UI variables
$global:languageData = $null
$global:mainWindow = $null
$global:popupWindow = $null
$global:pendingAction = ""
$global:consoleHandle = $null
$global:application = $null
$global:isShuttingDown = $false
$global:logFilePath = ""

# ====================================
# LOG FILE MANAGEMENT FUNCTIONS
# ====================================

function Initialize-LogFile {
    <#
    .SYNOPSIS
    Initializes the log file based on global settings
    #>
    try {
        $global:logFilePath = Join-Path $global:globalAppPath "Power.Ctrl.app.log"
        
        if ($global:globalCreateLogFile) {
            # Delete existing log file if it exists
            if (Test-Path $global:logFilePath) {
                Remove-Item $global:logFilePath -Force -ErrorAction SilentlyContinue
            }
            
            # Create new empty log file
            New-Item -Path $global:logFilePath -ItemType File -Force | Out-Null
            Write-LogMessage "Log file initialized: $global:logFilePath"
        }
        else {
            # Delete log file if it exists and logging is disabled
            if (Test-Path $global:logFilePath) {
                Remove-Item $global:logFilePath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        # If log initialization fails, continue without logging
        $global:globalCreateLogFile = $false
    }
}

function Write-LogMessage {
    <#
    .SYNOPSIS
    Writes a message to the log file with timestamp
    #>
    param(
        [string]$Message
    )
    
    if ($global:globalCreateLogFile -and $global:logFilePath -and (Test-Path $global:logFilePath)) {
        try {
            $timestamp = Get-Date -Format "dd.MM.yyyy ; HH:mm:ss"
            $logEntry = "[$timestamp] $Message"
            Add-Content -Path $global:logFilePath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # If logging fails, continue silently
        }
    }
}

# ====================================
# CONSOLE MANAGEMENT FUNCTIONS
# ====================================

function Initialize-ConsoleHandle {
    <#
    .SYNOPSIS
    Initializes console window handle for show/hide operations
    #>
    try {
        $script:showWindowAsync = Add-Type -MemberDefinition @"
            [DllImport("user32.dll")]
            public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
            [DllImport("kernel32.dll")]
            public static extern IntPtr GetConsoleWindow();
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
        
        $global:consoleHandle = $script:showWindowAsync::GetConsoleWindow()
        Write-ConsoleMessage "ConsoleHandleInitialized"
    }
    catch {
        Write-ConsoleMessage "ConsoleHandleError" $_.Exception.Message
    }
}

function Hide-ConsoleWindow {
    <#
    .SYNOPSIS
    Minimizes the console window
    #>
    try {
        if ($global:consoleHandle -and $script:showWindowAsync) {
            $script:showWindowAsync::ShowWindowAsync($global:consoleHandle, 2) | Out-Null # 2 = SW_MINIMIZE
            Write-ConsoleMessage "ConsoleMinimized"
        }
    }
    catch {
        Write-ConsoleMessage "ConsoleMinimizeError" $_.Exception.Message
    }
}

function Show-ConsoleWindow {
    <#
    .SYNOPSIS
    Restores the console window to normal state
    #>
    try {
        if ($global:consoleHandle -and $script:showWindowAsync) {
            $script:showWindowAsync::ShowWindowAsync($global:consoleHandle, 9) | Out-Null # 9 = SW_RESTORE
            Write-ConsoleMessage "ConsoleRestored"
        }
    }
    catch {
        Write-ConsoleMessage "ConsoleRestoreError" $_.Exception.Message
    }
}

# ====================================
# ICON EXTRACTION FUNCTIONS
# ====================================

# Win32 API definitions for icon extraction
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class IconExtractor {
    [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
    
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@

function Get-IconFromShell32 {
    <#
    .SYNOPSIS
    Extracts an icon from Shell32.dll and converts it to BitmapSource for WPF
    .PARAMETER IconIndex
    The index of the icon in Shell32.dll
    .PARAMETER Size
    The size of the icon (16, 32, 48, etc.)
    #>
    param(
        [int]$IconIndex,
        [int]$Size = 32
    )
    
    try {
        $shell32Path = Join-Path $env:SystemRoot "System32\shell32.dll"
        $largeIcon = [IntPtr]::Zero
        $smallIcon = [IntPtr]::Zero
        
        # Extract both large and small icons
        $result = [IconExtractor]::ExtractIconEx($shell32Path, $IconIndex, [ref]$largeIcon, [ref]$smallIcon, 1)
        
        if ($result -gt 0) {
            # Choose appropriate icon based on requested size
            $iconHandle = if ($Size -le 16) { $smallIcon } else { $largeIcon }
            
            if ($iconHandle -ne [IntPtr]::Zero) {
                # Convert to .NET Icon and then to BitmapSource
                $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
                $bitmap = $icon.ToBitmap()
                
                # Convert System.Drawing.Bitmap to WPF BitmapSource
                $memoryStream = New-Object System.IO.MemoryStream
                $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $memoryStream.Position = 0
                
                $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
                $bitmapImage.BeginInit()
                $bitmapImage.StreamSource = $memoryStream
                $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bitmapImage.EndInit()
                $bitmapImage.Freeze()
                
                # Cleanup
                $bitmap.Dispose()
                $icon.Dispose()
                $memoryStream.Dispose()
                
                return $bitmapImage
            }
        }
    }
    catch {
        Write-ConsoleMessage "IconExtractionFailed" $IconIndex
    }
    finally {
        # Always cleanup icon handles
        if ($largeIcon -ne [IntPtr]::Zero) {
            [IconExtractor]::DestroyIcon($largeIcon) | Out-Null
        }
        if ($smallIcon -ne [IntPtr]::Zero) {
            [IconExtractor]::DestroyIcon($smallIcon) | Out-Null
        }
    }
    
    return $null
}

# ====================================
# LANGUAGE LOADING FUNCTIONS
# ====================================

function Load-LanguageFile {
    <#
    .SYNOPSIS
    Loads the language file based on the global language setting
    #>
    param(
        [string]$Language = $global:globalLanguage
    )
    
    try {
        $languageFilePath = Join-Path $global:globalAppPath "$Language.json"
        
        if (Test-Path $languageFilePath) {
            $jsonContent = Get-Content $languageFilePath -Raw -Encoding UTF8
            $global:languageData = $jsonContent | ConvertFrom-Json
            Write-ConsoleMessage "LanguageFileLoaded" $languageFilePath
        }
        else {
            Write-ConsoleMessage "LanguageFileNotFound" $languageFilePath
            # Fallback to English if German file not found
            if ($Language -ne "en-us") {
                Load-LanguageFile -Language "en-us"
            }
            else {
                Write-ConsoleMessage "NoLanguageFilesFound"
                exit 1
            }
        }
    }
    catch {
        Write-ConsoleMessage "LanguageFileLoadError" $_.Exception.Message
        exit 1
    }
}

function Get-LocalizedText {
    <#
    .SYNOPSIS
    Gets localized text for a given key
    #>
    param(
        [string]$Key
    )
    
    if ($global:languageData -and $global:languageData.PSObject.Properties[$Key]) {
        return $global:languageData.$Key
    }
    else {
        Write-ConsoleMessage "LocalizedTextNotFound" $Key
        return $Key
    }
}

function Write-ConsoleMessage {
    <#
    .SYNOPSIS
    Writes localized console messages with fallback for early startup and logs to file
    #>
    param(
        [string]$MessageKey,
        [string]$Parameter = ""
    )
    
    $message = ""
    
    # Early startup fallback messages before language file is loaded
    if (-not $global:languageData) {
        $fallbackMessages = @{
            "ApplicationStarting" = if ($global:globalLanguage -eq "de-de") { "Power.Ctrl.app v1.00.10 wird gestartet" } else { "Starting Power.Ctrl.app v1.00.10" }
            "LogFileInitialized" = if ($global:globalLanguage -eq "de-de") { "Log-Datei initialisiert" } else { "Log file initialized" }
            "ApplicationInstanceCreating" = if ($global:globalLanguage -eq "de-de") { "Neue WPF Application-Instanz wird erstellt" } else { "Creating new WPF Application instance" }
            "ApplicationInstanceCreated" = if ($global:globalLanguage -eq "de-de") { "Neue WPF Application-Instanz erfolgreich erstellt" } else { "New WPF Application instance created successfully" }
            "ApplicationInstanceReused" = if ($global:globalLanguage -eq "de-de") { "Bestehende WPF Application-Instanz wiederverwendet" } else { "Reusing existing WPF Application instance" }
            "ConsoleHandleInitialized" = if ($global:globalLanguage -eq "de-de") { "Console-Fenster-Handle initialisiert" } else { "Console window handle initialized" }
            "ConsoleMinimized" = if ($global:globalLanguage -eq "de-de") { "Console-Fenster minimiert" } else { "Console window minimized" }
        }
        
        if ($fallbackMessages.ContainsKey($MessageKey)) {
            $message = $fallbackMessages[$MessageKey]
            if ($Parameter -ne "") {
                $message = $message -replace '\{0\}', $Parameter
            }
        }
    }
    
    # Normal localized message handling
    if (-not $message -and $global:languageData -and $global:languageData.Console -and $global:languageData.Console.PSObject.Properties[$MessageKey]) {
        $message = $global:languageData.Console.$MessageKey
        if ($Parameter -ne "") {
            $message = $message -replace '\{0\}', $Parameter
        }
    }
    
    # Final fallback
    if (-not $message) {
        $message = if ($Parameter -ne "") { "$MessageKey`: $Parameter" } else { $MessageKey }
    }
    
    # Output to console
    Write-Host $message
    
    # Log to file if enabled
    Write-LogMessage $message
}

# ====================================
# WINDOW POSITIONING FUNCTIONS
# ====================================

function Set-WindowPosition {
    <#
    .SYNOPSIS
    Sets window position based on global setting with precise positioning and taskbar awareness
    #>
    param(
        [System.Windows.Window]$Window
    )
    
    try {
        # Get working area (screen size minus taskbar and other system elements)
        $workingArea = [System.Windows.SystemParameters]::WorkArea
        $workingWidth = $workingArea.Width
        $workingHeight = $workingArea.Height
        $workingLeft = $workingArea.Left
        $workingTop = $workingArea.Top
        
        # Get full screen dimensions for reference
        $screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
        $screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
        
        # Calculate taskbar height for logging
        $taskbarHeight = $screenHeight - $workingHeight
        
        switch ($global:globalWindowPosition.ToLower()) {
            "center" {
                $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
            }
            "lowerleft" {
                $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
                # Position at left edge (optimized with tested offset)
                $Window.Left = -6
                # Position above taskbar (optimized with tested offset)
                $Window.Top = ($workingTop + $workingHeight - $Window.Height) + 6
            }
            "lowerright" {
                $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
                # Position at right edge (optimized with tested offset)
                $Window.Left = ($workingLeft + $workingWidth - $Window.Width) + 6
                # Position above taskbar (optimized with tested offset)
                $Window.Top = ($workingTop + $workingHeight - $Window.Height) + 6
            }
            default {
                $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
            }
        }
        
        Write-ConsoleMessage "WindowPositionSet" "$global:globalWindowPosition (Working Area: ${workingWidth}x${workingHeight}, Taskbar Height: ${taskbarHeight}px)"
    }
    catch {
        Write-ConsoleMessage "WindowPositionError" $_.Exception.Message
        $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    }
}

# ====================================
# SYSTEM ACTION FUNCTIONS
# ====================================

function Invoke-LockWorkstation {
    <#
    .SYNOPSIS
    Locks the current workstation
    #>
    try {
        # Using rundll32 to call LockWorkStation from user32.dll
        Start-Process "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation" -WindowStyle Hidden
        Write-ConsoleMessage "LockSuccess"
    }
    catch {
        Write-ConsoleMessage "LockError" $_.Exception.Message
    }
}

function Invoke-LogoffSession {
    <#
    .SYNOPSIS
    Logs off the current user session
    #>
    try {
        # Using shutdown command for logoff (immediate)
        Start-Process "shutdown.exe" -ArgumentList "/l" -WindowStyle Hidden
        Write-ConsoleMessage "LogoffSuccess"
    }
    catch {
        Write-ConsoleMessage "LogoffError" $_.Exception.Message
    }
}

function Invoke-RestartComputer {
    <#
    .SYNOPSIS
    Restarts the computer immediately
    #>
    try {
        # Using shutdown command for restart (immediate - /t 0)
        Start-Process "shutdown.exe" -ArgumentList "/r /t 0" -WindowStyle Hidden
        Write-ConsoleMessage "RestartSuccess"
    }
    catch {
        Write-ConsoleMessage "RestartError" $_.Exception.Message
    }
}

function Invoke-ShutdownComputer {
    <#
    .SYNOPSIS
    Shuts down the computer immediately
    #>
    try {
        # Using shutdown command for shutdown (immediate - /t 0)
        Start-Process "shutdown.exe" -ArgumentList "/s /t 0" -WindowStyle Hidden
        Write-ConsoleMessage "ShutdownSuccess"
    }
    catch {
        Write-ConsoleMessage "ShutdownError" $_.Exception.Message
    }
}

function Execute-PendingAction {
    <#
    .SYNOPSIS
    Executes the pending system action and exits application cleanly
    #>
    try {
        $global:isShuttingDown = $true
        
        switch ($global:pendingAction) {
            "lock" { Invoke-LockWorkstation }
            "logoff" { Invoke-LogoffSession }
            "restart" { Invoke-RestartComputer }
            "shutdown" { Invoke-ShutdownComputer }
        }
        
        Write-ConsoleMessage "ActionExecutedClosing"
        
        # Clean shutdown without console restoration (action was executed)
        Shutdown-Application $false
    }
    catch {
        Write-ConsoleMessage "ActionExecutionError" $_.Exception.Message
        Shutdown-Application $true
    }
}

function Shutdown-Application {
    <#
    .SYNOPSIS
    Shuts down the application properly with cleanup
    #>
    param(
        [bool]$RestoreConsole = $true
    )
    
    try {
        $global:isShuttingDown = $true
        
        if ($RestoreConsole) {
            Show-ConsoleWindow
            Write-ConsoleMessage "ApplicationClosedWithoutAction"
        }
        
        Write-ConsoleMessage "ApplicationClosed"
        
        # Use Dispatcher to shutdown gracefully and then exit process
        if ($global:application -and $global:application.Dispatcher) {
            $global:application.Dispatcher.BeginInvokeShutdown([System.Windows.Threading.DispatcherPriority]::Normal)
            
            # Give WPF time to shutdown properly, then force exit
            Start-Sleep -Milliseconds 500
        }
        
        # Force exit the process to ensure clean shutdown
        [System.Environment]::Exit(0)
    }
    catch {
        # Final fallback - force exit
        [System.Environment]::Exit(1)
    }
}

# ====================================
# UI LOADING AND EVENT HANDLING
# ====================================

function Load-MainWindow {
    <#
    .SYNOPSIS
    Loads the main XAML user interface
    #>
    try {
        $xamlPath = Join-Path $global:globalAppPath "app-ui-main.xaml"
        
        if (-not (Test-Path $xamlPath)) {
            Write-ConsoleMessage "XamlFileNotFound" $xamlPath
            exit 1
        }
        
        # Load XAML content and clean it for PowerShell usage
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        
        # Remove problematic attributes that cause issues when loading XAML in PowerShell
        $xamlToRemove = @(
            'x:Class=".*?"',
            'mc:Ignorable=".*?"',
            'xmlns:local=".*?"'
        )
        
        foreach ($xtr in $xamlToRemove) {
            $xamlContent = $xamlContent -replace $xtr, ''
        }
        
        # Convert cleaned XAML string to XML
        [xml]$xaml = $xamlContent
        
        # Parse XAML
        $xmlReader = [System.Xml.XmlNodeReader]::new($xaml)
        $global:mainWindow = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
        if (-not $global:mainWindow) {
            Write-ConsoleMessage "WindowCreationFailed"
            exit 1
        }
        
        Write-ConsoleMessage "MainWindowLoaded"
    }
    catch {
        Write-ConsoleMessage "UserInterfaceLoadError" $_.Exception.Message
        exit 1
    }
}

function Load-PopupWindow {
    <#
    .SYNOPSIS
    Loads the popup confirmation XAML user interface
    #>
    try {
        $xamlPath = Join-Path $global:globalAppPath "app-ui-popup.xaml"
        
        if (-not (Test-Path $xamlPath)) {
            Write-ConsoleMessage "XamlFileNotFound" $xamlPath
            return $false
        }
        
        # Load XAML content and clean it for PowerShell usage
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        
        # Remove problematic attributes that cause issues when loading XAML in PowerShell
        $xamlToRemove = @(
            'x:Class=".*?"',
            'mc:Ignorable=".*?"',
            'xmlns:local=".*?"'
        )
        
        foreach ($xtr in $xamlToRemove) {
            $xamlContent = $xamlContent -replace $xtr, ''
        }
        
        # Convert cleaned XAML string to XML
        [xml]$xaml = $xamlContent
        
        # Parse XAML
        $xmlReader = [System.Xml.XmlNodeReader]::new($xaml)
        $global:popupWindow = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
        if (-not $global:popupWindow) {
            Write-ConsoleMessage "PopupWindowCreationFailed"
            return $false
        }
        
        Write-ConsoleMessage "PopupWindowLoaded"
        return $true
    }
    catch {
        Write-ConsoleMessage "PopupWindowLoadError" $_.Exception.Message
        return $false
    }
}

function Initialize-MainWindowElements {
    <#
    .SYNOPSIS
    Initializes main window UI elements with localized text and icons
    #>
    try {
        # Set window title
        $global:mainWindow.Title = Get-LocalizedText "WindowTitle"
        
        # Initialize button texts
        $global:mainWindow.FindName("LockText").Text = Get-LocalizedText "LockText"
        $global:mainWindow.FindName("LogoffText").Text = Get-LocalizedText "LogoffText"
        $global:mainWindow.FindName("RestartText").Text = Get-LocalizedText "RestartText"
        $global:mainWindow.FindName("ShutdownText").Text = Get-LocalizedText "ShutdownText"
        
        # Initialize tooltips
        $global:mainWindow.FindName("LockButton").ToolTip = Get-LocalizedText "LockTooltip"
        $global:mainWindow.FindName("LogoffButton").ToolTip = Get-LocalizedText "LogoffTooltip"
        $global:mainWindow.FindName("RestartButton").ToolTip = Get-LocalizedText "RestartTooltip"
        $global:mainWindow.FindName("ShutdownButton").ToolTip = Get-LocalizedText "ShutdownTooltip"
        
        # Load and set icons
        $lockIcon = Get-IconFromShell32 -IconIndex 47 -Size 32
        $logoffIcon = Get-IconFromShell32 -IconIndex 25 -Size 32
        $restartIcon = Get-IconFromShell32 -IconIndex 238 -Size 32
        $shutdownIcon = Get-IconFromShell32 -IconIndex 112 -Size 32
        
        if ($lockIcon) { $global:mainWindow.FindName("LockIcon").Source = $lockIcon }
        if ($logoffIcon) { $global:mainWindow.FindName("LogoffIcon").Source = $logoffIcon }
        if ($restartIcon) { $global:mainWindow.FindName("RestartIcon").Source = $restartIcon }
        if ($shutdownIcon) { $global:mainWindow.FindName("ShutdownIcon").Source = $shutdownIcon }
        
        # Set window position
        Set-WindowPosition $global:mainWindow
        
        Write-ConsoleMessage "MainWindowElementsInitialized"
    }
    catch {
        Write-ConsoleMessage "UIElementsInitError" $_.Exception.Message
    }
}

function Initialize-PopupWindowElements {
    <#
    .SYNOPSIS
    Initializes popup window UI elements with localized text
    #>
    param(
        [string]$Action
    )
    
    try {
        # Set window title
        $global:popupWindow.Title = Get-LocalizedText "ConfirmationTitle"
        
        # Set confirmation message based on action
        $messageKey = switch ($Action) {
            "lock" { "ConfirmLockMessage" }
            "logoff" { "ConfirmLogoffMessage" }
            "restart" { "ConfirmRestartMessage" }
            "shutdown" { "ConfirmShutdownMessage" }
            default { "ConfirmActionMessage" }
        }
        
        $global:popupWindow.FindName("ConfirmationMessage").Text = Get-LocalizedText $messageKey
        
        # Set button texts
        $global:popupWindow.FindName("YesButton").Content = Get-LocalizedText "YesButtonText"
        $global:popupWindow.FindName("NoButton").Content = Get-LocalizedText "NoButtonText"
        
        # Set tooltips
        $global:popupWindow.FindName("YesButton").ToolTip = Get-LocalizedText "YesButtonTooltip"
        $global:popupWindow.FindName("NoButton").ToolTip = Get-LocalizedText "NoButtonTooltip"
        
        # Position popup at same location as main window using precise positioning
        Set-WindowPosition $global:popupWindow
        
        Write-ConsoleMessage "PopupWindowElementsInitialized"
    }
    catch {
        Write-ConsoleMessage "PopupUIElementsInitError" $_.Exception.Message
    }
}

function Register-MainWindowEventHandlers {
    <#
    .SYNOPSIS
    Registers event handlers for main window UI buttons
    #>
    try {
        # Lock button
        $lockButton = $global:mainWindow.FindName("LockButton")
        $lockButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Handle-ActionClick "lock"
            }
        })
        
        # Logoff button
        $logoffButton = $global:mainWindow.FindName("LogoffButton")
        $logoffButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Handle-ActionClick "logoff"
            }
        })
        
        # Restart button
        $restartButton = $global:mainWindow.FindName("RestartButton")
        $restartButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Handle-ActionClick "restart"
            }
        })
        
        # Shutdown button
        $shutdownButton = $global:mainWindow.FindName("ShutdownButton")
        $shutdownButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Handle-ActionClick "shutdown"
            }
        })
        
        # Main window closing event - shutdown application with console restoration
        $global:mainWindow.Add_Closing({
            param($sender, $e)
            if (-not $global:isShuttingDown) {
                Write-ConsoleMessage "MainWindowClosing"
                Shutdown-Application $true
            }
        })
        
        Write-ConsoleMessage "MainWindowEventHandlersRegistered"
    }
    catch {
        Write-ConsoleMessage "EventHandlersRegisterError" $_.Exception.Message
    }
}

function Register-PopupWindowEventHandlers {
    <#
    .SYNOPSIS
    Registers event handlers for popup window buttons
    #>
    try {
        # Yes button - execute action and shutdown application
        $yesButton = $global:popupWindow.FindName("YesButton")
        $yesButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Write-ConsoleMessage "ConfirmationYes"
                if ($global:popupWindow) { $global:popupWindow.Hide() }
                Execute-PendingAction
            }
        })
        
        # No button - return to main window (do not shutdown application)
        $noButton = $global:popupWindow.FindName("NoButton")
        $noButton.Add_Click({
            if (-not $global:isShuttingDown) {
                Write-ConsoleMessage "ConfirmationNo"
                Return-ToMainWindow
            }
        })
        
        # Popup window closing event (X button) - return to main window
        $global:popupWindow.Add_Closing({
            param($sender, $e)
            if (-not $global:isShuttingDown) {
                $e.Cancel = $true  # Prevent actual closing
                Write-ConsoleMessage "PopupWindowClosing"
                Return-ToMainWindow
            }
        })
        
        Write-ConsoleMessage "PopupWindowEventHandlersRegistered"
    }
    catch {
        Write-ConsoleMessage "PopupEventHandlersRegisterError" $_.Exception.Message
    }
}

function Return-ToMainWindow {
    <#
    .SYNOPSIS
    Hides popup and shows main window again with proper focus
    #>
    try {
        if (-not $global:isShuttingDown) {
            if ($global:popupWindow) {
                $global:popupWindow.Hide()
            }
            
            if ($global:mainWindow) {
                $global:mainWindow.Show()
                $global:mainWindow.Activate()
                $global:mainWindow.Focus()
            }
            
            $global:pendingAction = ""
            Write-ConsoleMessage "ReturnedToMainWindow"
        }
    }
    catch {
        if (-not $global:isShuttingDown) {
            Write-ConsoleMessage "ReturnToMainWindowError" $_.Exception.Message
        }
    }
}

function Handle-ActionClick {
    <#
    .SYNOPSIS
    Handles action button clicks
    #>
    param(
        [string]$Action
    )
    
    if ($global:isShuttingDown) { return }
    
    $global:pendingAction = $Action
    Write-ConsoleMessage "ActionRequested" $Action
    
    if ($global:globalShowConfirmationDialog) {
        # Show confirmation dialog
        if (Load-PopupWindow) {
            Initialize-PopupWindowElements $Action
            Register-PopupWindowEventHandlers
            $global:mainWindow.Hide()
            
            # Use ShowDialog() for popup to maintain message loop
            $global:popupWindow.ShowDialog() | Out-Null
        }
        else {
            # Fallback to direct execution if popup fails to load
            Execute-PendingAction
        }
    }
    else {
        # Direct execution without confirmation
        Execute-PendingAction
    }
}

# ====================================
# APPLICATION INSTANCE MANAGEMENT
# ====================================

function Get-WPFApplication {
    <#
    .SYNOPSIS
    Gets or creates a WPF Application instance safely
    #>
    try {
        # Check if there's already a current Application instance
        $currentApp = [System.Windows.Application]::Current
        
        if ($currentApp) {
            Write-ConsoleMessage "ApplicationInstanceReused"
            return $currentApp
        }
        else {
            Write-ConsoleMessage "ApplicationInstanceCreating"
            $newApp = New-Object System.Windows.Application
            Write-ConsoleMessage "ApplicationInstanceCreated"
            return $newApp
        }
    }
    catch {
        Write-ConsoleMessage "ApplicationInstanceError" $_.Exception.Message
        # If we can't create a new instance, try to work without it
        return $null
    }
}

# ====================================
# MAIN APPLICATION LOGIC
# ====================================

function Start-PowerCtrlApplication {
    <#
    .SYNOPSIS
    Main application entry point
    #>
    try {
        # Initial application starting message with fallback
        Write-ConsoleMessage "ApplicationStarting"
        
        # Initialize log file system
        Initialize-LogFile
        
        # Get or create WPF Application instance
        $global:application = Get-WPFApplication
        
        # Initialize console management
        [Console]::Title = "$global:globalAppName $global:globalAppVers - Console"
        Initialize-ConsoleHandle
        Hide-ConsoleWindow
        
        # Load language file
        Load-LanguageFile
        
        # Load and initialize main window
        Load-MainWindow
        Initialize-MainWindowElements
        Register-MainWindowEventHandlers
        
        # Show main window and start message loop
        if ($global:application) {
            $global:mainWindow.Show()
            $global:application.Run($global:mainWindow) | Out-Null
        }
        else {
            # Fallback: use ShowDialog if no Application instance available
            $global:mainWindow.ShowDialog() | Out-Null
        }
        
        Write-ConsoleMessage "ApplicationClosed"
    }
    catch {
        Write-ConsoleMessage "ApplicationError" $_.Exception.Message
        Show-ConsoleWindow
        [System.Environment]::Exit(1)
    }
}

# ====================================
# APPLICATION STARTUP
# ====================================

# Start the application
Start-PowerCtrlApplication