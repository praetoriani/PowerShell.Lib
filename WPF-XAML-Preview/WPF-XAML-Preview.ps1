<#
.SYNOPSIS
    WPF-XAML-Preview
.DESCRIPTION
    A PowerShell application to preview and test XAML files by loading them dynamically and displaying them as WPF windows
.NOTES
    Creation Date:  September 21, 2025
    Version:        1.02.00
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
#>

# Global application variables
$global:AppName = "WPF-XAML-Preview"
$global:AppVers = "1.02.00"
$global:AppPath = $PSScriptRoot
$global:AppIcon = Join-Path $AppPath "appicon.ico"

# Add required assemblies for WPF and Windows Forms (for file dialog)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Define Windows API constants and functions for console window manipulation
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    public const int SW_HIDE = 0;
    public const int SW_MINIMIZE = 6;
    public const int SW_RESTORE = 9;
    public const int SW_SHOW = 5;
    public const int SW_SHOWDEFAULT = 10;
}
"@

# Function to write colored output to console
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    switch ($Level.ToUpper()) {
        "INFO" { 
            Write-Host "[$timestamp] [INFO]  $Message" -ForegroundColor Green 
        }
        "WARN" { 
            Write-Host "[$timestamp] [WARN]  $Message" -ForegroundColor Yellow 
        }
        "ERROR" { 
            Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red 
        }
        "DEBUG" { 
            Write-Host "[$timestamp] [DEBUG] $Message" -ForegroundColor Cyan 
        }
    }
}

# Function to minimize the console window
function Hide-ConsoleWindow {
    Write-ColorOutput "Minimizing console window..." "DEBUG"
    $consolePtr = [Win32]::GetConsoleWindow()
    [Win32]::ShowWindow($consolePtr, [Win32]::SW_MINIMIZE) | Out-Null
}

# Function to restore and bring console window to front
function Show-ConsoleWindow {
    Write-ColorOutput "Restoring console window..." "DEBUG"
    $consolePtr = [Win32]::GetConsoleWindow()
    [Win32]::ShowWindow($consolePtr, [Win32]::SW_RESTORE) | Out-Null
    [Win32]::SetForegroundWindow($consolePtr) | Out-Null
    [Win32]::BringWindowToTop($consolePtr) | Out-Null
}

# Function to show file open dialog for XAML files with foreground focus
function Get-XamlFile {
    Write-ColorOutput "Opening file dialog for XAML selection..." "INFO"

    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = "Select XAML File for Preview"
    $fileDialog.Filter = "XAML Files (*.xaml)|*.xaml|All Files (*.*)|*.*"
    $fileDialog.FilterIndex = 1
    $fileDialog.InitialDirectory = $env:USERPROFILE
    $fileDialog.Multiselect = $false

    # Ensure dialog appears in foreground
    $fileDialog.ShowHelp = $false
    $fileDialog.RestoreDirectory = $true

    # Create a dummy form to ensure proper focus handling
    $dummyForm = New-Object System.Windows.Forms.Form
    $dummyForm.TopMost = $true
    $dummyForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    $dummyForm.ShowInTaskbar = $false

    try {
        $result = $fileDialog.ShowDialog($dummyForm)

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-ColorOutput "Selected XAML file: $($fileDialog.FileName)" "INFO"
            return $fileDialog.FileName
        }
        else {
            Write-ColorOutput "No XAML file selected" "WARN"
            return $null
        }
    }
    finally {
        $dummyForm.Dispose()
    }
}

# Function to load and display XAML file as preview with foreground focus
function Show-XamlPreview {
    param(
        [string]$XamlFilePath
    )

    try {
        Write-ColorOutput "Loading XAML file: $XamlFilePath" "INFO"

        # Read XAML content from file
        if (-not (Test-Path $XamlFilePath)) {
            throw "XAML file not found: $XamlFilePath"
        }

        $xamlContent = Get-Content $XamlFilePath -Raw -ErrorAction Stop
        Write-ColorOutput "XAML content loaded successfully" "INFO"

        # Clean up XAML content for PowerShell compatibility
        $xamlContent = $xamlContent -replace 'mc:Ignorable="d"', ''
        $xamlContent = $xamlContent -replace "x:Name", 'Name'
        $xamlContent = $xamlContent -replace "x:Class=`"[^`"]*`"", ''

        # Remove event handlers that might cause issues
        $xamlContent = $xamlContent -replace 'Click="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'Loaded="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'MouseDown="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'KeyDown="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'TextChanged="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'SelectionChanged="[^"]*"', ''

        # Load XAML using XamlReader
        [xml]$xaml = $xamlContent
        $reader = New-Object System.Xml.XmlNodeReader $xaml

        Write-ColorOutput "Creating WPF window from XAML..." "INFO"
        $window = [Windows.Markup.XamlReader]::Load($reader)

        # Set window properties for preview with foreground focus
        $window.Title = "XAML Preview - $(Split-Path $XamlFilePath -Leaf)"
        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

        # Set window state and focus properties
        $window.Topmost = $true
        $window.WindowState = [System.Windows.WindowState]::Normal

        # Add window event handlers
        $window.Add_Loaded({
            Write-ColorOutput "XAML preview window loaded successfully" "INFO"
            # Remove topmost after window is loaded and focused
            $this.Topmost = $false
            $this.Activate()
            $this.Focus()
        })

        # Simplified closing event - no confirmation dialog, direct close
        $window.Add_Closing({
            param($sender, $e)
            Write-ColorOutput "XAML preview window is closing..." "INFO"
        })

        $window.Add_Closed({
            param($sender, $e)
            Write-ColorOutput "XAML preview window closed. Restoring console..." "INFO"
            # Show console window when preview closes
            Show-ConsoleWindow
        })

        # CRITICAL FIX: Use ONLY ShowDialog(), not Show() + ShowDialog()
        # This was causing the "ShowDialog can only be called for hidden windows" error
        Write-ColorOutput "Displaying XAML preview window..." "INFO"
        $result = $window.ShowDialog()

        Write-ColorOutput "Preview window closed with result: $result" "INFO"
        return $true

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-ColorOutput "Error loading XAML preview: $errorMessage" "ERROR"

        # Show error dialog to user
        [System.Windows.MessageBox]::Show(
            "Failed to load XAML preview.`n`nError: $errorMessage`n`nPlease check if the XAML file is valid and contains proper WPF markup.",
            "XAML Preview Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null

        return $false
    }
}

# Function to prompt user for next action
function Get-UserAction {
    Write-ColorOutput "`n========================================" "INFO"
    Write-ColorOutput "Choose your next action:" "INFO"
    Write-ColorOutput "[O] - Open another XAML preview" "INFO"
    Write-ColorOutput "[Q] - Quit application" "INFO"
    Write-ColorOutput "========================================`n" "INFO"

    do {
        Write-Host "Enter your choice (O/Q): " -ForegroundColor White -NoNewline
        $choice = Read-Host
        $choice = $choice.ToUpper().Trim()

        if ($choice -eq "O") {
            Write-ColorOutput "User selected: Open another preview" "INFO"
            return "OPEN"
        }
        elseif ($choice -eq "Q") {
            Write-ColorOutput "User selected: Quit application" "INFO"
            return "QUIT"
        }
        else {
            Write-ColorOutput "Invalid choice. Please enter O or Q." "WARN"
        }
    } while ($true)
}

# Main application logic
function Main {
    Write-ColorOutput "Starting $global:AppName v$global:AppVers" "INFO"
    Write-ColorOutput "Application path: $global:AppPath" "DEBUG"

    # Main application loop
    do {
        # Hide console window before showing file dialog
        Hide-ConsoleWindow

        # Small delay to ensure console is minimized before dialog appears
        Start-Sleep -Milliseconds 200

        # Get XAML file from user
        $xamlFile = Get-XamlFile

        # Check if user cancelled file selection
        if ([string]::IsNullOrEmpty($xamlFile)) {
            Write-ColorOutput "No file selected. Exiting application." "INFO"
            Show-ConsoleWindow
            break
        }

        # Show XAML preview (console will be restored when preview closes)
        $previewResult = Show-XamlPreview -XamlFilePath $xamlFile

        # Console window is automatically restored by the preview window closed event

        if ($previewResult) {
            # Ask user what to do next
            $userAction = Get-UserAction

            if ($userAction -eq "QUIT") {
                Write-ColorOutput "Application terminated by user." "INFO"
                break
            }
            # If "OPEN", continue the loop
        }
        else {
            # Error occurred, ask if user wants to try again
            Write-ColorOutput "`nAn error occurred while loading the XAML preview." "ERROR"
            $userAction = Get-UserAction

            if ($userAction -eq "QUIT") {
                Write-ColorOutput "Application terminated after error." "INFO"
                break
            }
            # If "OPEN", continue the loop
        }

    } while ($true)

    Write-ColorOutput "Thank you for using $global:AppName!" "INFO"
    Write-ColorOutput "Press any key to exit..." "INFO"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Start the application
try {
    Main
}
catch {
    Write-ColorOutput "Unexpected error in main application: $($_.Exception.Message)" "ERROR"
    Show-ConsoleWindow
    Write-ColorOutput "Press any key to exit..." "INFO"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Ensure console window is visible at the end
Show-ConsoleWindow
