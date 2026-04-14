<#
.SYNOPSIS
    ShowSplashScreen - Displays a WPF splash screen window in a separate process
.DESCRIPTION
    This function launches the PowerEdge startup/splash screen (startup.window.xml)
    in an independent PowerShell process. This allows the splash screen to remain
    visible even while the main PowerEdge window is hidden during startup.
    The splash screen process will automatically terminate after the specified timeout.
.PARAMETER Timeout
    Duration in milliseconds that the splash screen should be displayed.
.PARAMETER AppIcon
    Path to the application icon (.ico file) to be shown in the splash screen.
.PARAMETER UiPath
    Path to the directory containing the startup.window.xml file.
.EXAMPLE
    ShowSplashScreen -Timeout 6000 -AppIcon "C:\App\app.ico" -UiPath "C:\App\data\ui"
.NOTES
    Author: Praetoriani
    Version: 1.00.02
    Date: 14.04.2026
#>
function ShowSplashScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Timeout,
        
        [Parameter(Mandatory = $true)]
        [string]$AppIcon,
        
        [Parameter(Mandatory = $true)]
        [string]$UiPath
    )
    
    $splashXamlPath = Join-Path $UiPath "startup.window.xml"
    
    if (-not (Test-Path -LiteralPath $splashXamlPath -PathType Leaf)) {
        Write-Warning "ShowSplashScreen: startup.window.xml not found at: $splashXamlPath"
        return
    }
    
    # Build the PowerShell script that will run in the separate process
    $splashScript = @"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

`$splashXamlPath = '$splashXamlPath'
`$appIconPath = '$AppIcon'
`$timeout = $Timeout

try {
    [xml]`$xamlDoc = Get-Content -LiteralPath `$splashXamlPath -Raw -ErrorAction Stop
    `$reader = [System.Xml.XmlNodeReader]::new(`$xamlDoc)
    `$splashWindow = [System.Windows.Markup.XamlReader]::Load(`$reader)
    
    if (`$null -eq `$splashWindow) {
        exit 1
    }
    
    # Set the app icon if it exists
    `$logoImage = `$splashWindow.FindName('SplashLogo')
    if (`$null -ne `$logoImage -and (Test-Path -LiteralPath `$appIconPath -ErrorAction SilentlyContinue)) {
        `$logoImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new(`$appIconPath))
    }
    
    # Create a timer to auto-close the splash screen
    `$timer = New-Object System.Windows.Threading.DispatcherTimer
    `$timer.Interval = [TimeSpan]::FromMilliseconds(`$timeout)
    `$timer.Add_Tick({
        `$splashWindow.Close()
        `$timer.Stop()
    })
    `$timer.Start()
    
    # Show the splash screen (blocking call)
    `$splashWindow.ShowDialog() | Out-Null
}
catch {
    # Silent fail — splash screen is non-critical
}
exit 0
"@
    
    # Start the splash screen in a hidden PowerShell process
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -WindowStyle Hidden -Command `"$splashScript`""
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    
    try {
        $process = [System.Diagnostics.Process]::Start($psi)
        Write-Verbose "ShowSplashScreen: Started splash screen process (PID: $($process.Id))"
    }
    catch {
        Write-Warning "ShowSplashScreen: Failed to start splash screen process: $($_.Exception.Message)"
    }
}
