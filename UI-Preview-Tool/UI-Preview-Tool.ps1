# ---------------------------------------------------------------------------
# UI-Preview-Tool.ps1
# A WPF-based XAML/XML preview tool for PowerShell developers.
#
# Author:      praetoriani (https://github.com/praetoriani)
# Contributor: paladin-xerox (https://github.com/paladin-xerox)
# Version:     1.02.00
# License:     Apache License 2.0
# Requires:    Windows PowerShell 5.1 or PowerShell 7+ (Windows)
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    UI-Preview-Tool - A WPF-based XAML/XML preview tool for PowerShell developers.

.DESCRIPTION
    UI-Preview-Tool is a standalone WPF application that lets you quickly preview
    XAML/XML files without running the full application. It is designed for
    PowerShell GUI developers who want to iterate on UI layout (for example,
    checking whether a button looks better a few pixels further to the right)
    without launching the entire program.

    Key features:
      - Inline preview of XAML/XML files (Window/UserControl content is extracted)
      - Auto-reload when the file changes on disk (FileSystemWatcher + debounce)
      - Zoom controls (fit to window, zoom in/out, reset to 100%)
      - Drag & drop support
      - Recent files list (persisted to a JSON file)
      - "Show as Window" mode for Window-rooted XAML
      - Robust, layered XAML cleanup that handles event handlers, code-behind
        references, custom namespaces and unresolvable bindings.
#>

# ---------------------------------------------------------------------------
# Region: Assembly loading
# ---------------------------------------------------------------------------
# Load the WPF and XML assemblies required for XAML parsing and rendering.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Xml

# ---------------------------------------------------------------------------
# Region: Win32 console helpers
# ---------------------------------------------------------------------------
# These helpers hide the console window while the GUI is shown and restore it
# when the tool exits. They are optional and fail silently if no console exists
# (for example when running inside an IDE).
if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_HIDE = 0;
    public const int SW_RESTORE = 9;
}
"@
}

function Hide-ConsoleWindow {
    try {
        $ptr = [Win32]::GetConsoleWindow()
        if ($ptr -ne [IntPtr]::Zero) { [Win32]::ShowWindow($ptr, [Win32]::SW_HIDE) | Out-Null }
    } catch { }
}

function Show-ConsoleWindow {
    try {
        $ptr = [Win32]::GetConsoleWindow()
        if ($ptr -ne [IntPtr]::Zero) { [Win32]::ShowWindow($ptr, [Win32]::SW_RESTORE) | Out-Null }
    } catch { }
}

# ---------------------------------------------------------------------------
# Region: XAML cleanup
# ---------------------------------------------------------------------------
# Regular expression matching common event-handler attributes. These reference
# code-behind methods that do not exist in a standalone preview, so they must be
# removed before the XAML can be parsed by XamlReader.
$script:EventHandlerRegex = '\s(?:Click|Loaded|Unloaded|MouseDown|MouseUp|MouseMove|MouseEnter|MouseLeave|MouseLeftButtonDown|MouseLeftButtonUp|MouseRightButtonDown|MouseRightButtonUp|KeyDown|KeyUp|PreviewKeyDown|PreviewKeyUp|TextChanged|SelectionChanged|GotFocus|LostFocus|GotKeyboardFocus|LostKeyboardFocus|PreviewMouseDown|PreviewMouseUp|PreviewMouseMove|PreviewMouseLeftButtonDown|PreviewMouseLeftButtonUp|PreviewMouseRightButtonDown|PreviewMouseRightButtonUp|DragEnter|DragOver|DragLeave|Drop|Closing|Closed|Initialized|ContextMenuOpening|Checked|Unchecked|DropDownOpened|DropDownClosed|ScrollChanged|SizeChanged|IsVisibleChanged|LayoutUpdated|Rendered|SourceUpdated|TargetUpdated|DataContextChanged|PropertyChanged)="[^"]*"'

function ConvertTo-PreviewXaml {
    <#
    .SYNOPSIS
        Reads a XAML file and applies progressively more aggressive cleanup.
    .PARAMETER FilePath
        Path to the XAML/XML file.
    .PARAMETER Level
        0 = minimal cleanup, 1 = also remove custom namespaces/elements,
        2 = also remove bindings and resource references.
    #>
    param([string]$FilePath, [int]$Level = 0)

    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "The file is empty or could not be read."
    }

    # Strip a UTF-8 byte order mark (BOM) if present. Many XAML files (e.g. from
    # Visual Studio) start with a BOM, and the XML parser would otherwise fail on
    # the leading U+FEFF character.
    if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) {
        $content = $content.Substring(1)
    }

    # --- Always applied (Level 0) ---
    # Remove the code-behind class reference (x:Class).
    $content = $content -replace 'x:Class="[^"]*"', ''
    # Remove the design-time "ignorable" marker.
    $content = $content -replace 'mc:Ignorable="[^"]*"', ''
    # Remove design-time (d:) attributes.
    $content = $content -replace '\sd:[A-Za-z]+="[^"]*"', ''
    # Remove event-handler attributes (code-behind methods do not exist here).
    $content = $content -replace $script:EventHandlerRegex, ''
    # Replace x:Name with Name (named elements are not needed in a preview).
    $content = $content -replace 'x:Name', 'Name'

    if ($Level -ge 1) {
        # Remove custom namespace declarations (e.g. xmlns:local="clr-namespace:...").
        $content = $content -replace 'xmlns:[A-Za-z0-9_]+="[^"]*"', ''
        # Remove custom element tags (e.g. <local:MyControl .../>).
        $content = $content -replace '</?[A-Za-z0-9_]+:[A-Za-z0-9_.]+[^>]*>', ''
    }

    if ($Level -ge 2) {
        # Remove bindings and resource references that cannot resolve without a
        # DataContext or a full resource dictionary.
        $content = $content -replace '\{Binding[^}]*\}', ''
        $content = $content -replace '\{TemplateBinding[^}]*\}', ''
        $content = $content -replace '\{StaticResource[^}]*\}', ''
        $content = $content -replace '\{DynamicResource[^}]*\}', ''
    }

    return $content
}

# ---------------------------------------------------------------------------
# Region: XAML loading
# ---------------------------------------------------------------------------
function Load-XamlObject {
    <#
    .SYNOPSIS
        Loads a XAML file into a WPF object, escalating cleanup levels on failure.
    .RETURNS
        The loaded WPF object.
    .THROWS
        If the file cannot be loaded even with the most aggressive cleanup.
    #>
    param([string]$FilePath)

    $lastError = $null
    for ($level = 0; $level -le 2; $level++) {
        try {
            $xaml = ConvertTo-PreviewXaml -FilePath $FilePath -Level $level
            # Validate that the cleaned content is well-formed XML first.
            $xmlDoc = New-Object System.Xml.XmlDocument
            $xmlDoc.LoadXml($xaml)
            $reader = New-Object System.Xml.XmlNodeReader $xmlDoc
            return [System.Windows.Markup.XamlReader]::Load($reader)
        }
        catch {
            $lastError = $_.Exception.Message
        }
    }
    throw "Could not load the XAML file. Last error: $lastError"
}

# ---------------------------------------------------------------------------
# Region: Status bar
# ---------------------------------------------------------------------------
function Set-Status {
    <#
    .SYNOPSIS
        Updates the status bar text and background color.
    .PARAMETER Message
        The text to display.
    .PARAMETER Type
        'info', 'warn' or 'error' - controls the background color.
    #>
    param([string]$Message, [string]$Type = 'info')
    # StatusText is a StatusBarItem (a ContentControl), so the message is set
    # via Content - it has no Text property.
    $script:StatusText.Content = $Message
    switch ($Type) {
        'error' { $script:StatusText.Background = [System.Windows.Media.Brushes]::DarkRed }
        'warn'  { $script:StatusText.Background = [System.Windows.Media.Brushes]::DarkOrange }
        default { $script:StatusText.Background = [System.Windows.Media.Brushes]::SteelBlue }
    }
}

# ---------------------------------------------------------------------------
# Region: Zoom handling
# ---------------------------------------------------------------------------
$script:ZoomScale = 1.0

function Set-Zoom {
    <#
    .SYNOPSIS
        Applies a scale transform to the preview content and updates the label.
    #>
    param([double]$Scale)
    $script:ZoomScale = [Math]::Round($Scale, 2)
    $script:ZoomScale = [Math]::Max(0.1, [Math]::Min(5.0, $script:ZoomScale))
    $transform = New-Object System.Windows.Media.ScaleTransform($script:ZoomScale, $script:ZoomScale)
    $script:PreviewHost.LayoutTransform = $transform
    $script:ZoomLabel.Text = "$([int]($script:ZoomScale * 100))%"
}

function Set-FitZoom {
    <#
    .SYNOPSIS
        Scales the preview so the whole content fits inside the viewport.
    #>
    # Measure the natural (unscaled) size of the content first.
    $script:PreviewHost.LayoutTransform = $null
    $script:PreviewHost.UpdateLayout()
    $contentW = $script:PreviewHost.ActualWidth
    $contentH = $script:PreviewHost.ActualHeight
    $viewW = $script:PreviewScroll.ViewportWidth
    $viewH = $script:PreviewScroll.ViewportHeight
    if ($contentW -le 0 -or $contentH -le 0 -or $viewW -le 0 -or $viewH -le 0) { return }
    $scale = [Math]::Min($viewW / $contentW, $viewH / $contentH)
    Set-Zoom -Scale $scale
}

# ---------------------------------------------------------------------------
# Region: Preview rendering
# ---------------------------------------------------------------------------
function Show-Preview {
    <#
    .SYNOPSIS
        Loads the given file and renders it inline in the preview area.
    #>
    param([string]$FilePath)

    try {
        if (-not (Test-Path -LiteralPath $FilePath)) {
            throw "File not found: $FilePath"
        }

        $loaded = Load-XamlObject -FilePath $FilePath
        $script:CurrentLoadedObject = $loaded

        # Extract the content for inline preview. A Window or UserControl cannot
        # be embedded inside another window, so we render its content instead.
        $content = $loaded
        if ($loaded -is [System.Windows.Window]) {
            $content = $loaded.Content
            # Preserve window-level resources so styles still apply to the content.
            if ($loaded.Resources -and $loaded.Resources.Count -gt 0) {
                foreach ($key in @($loaded.Resources.Keys)) {
                    $script:PreviewHost.Resources[$key] = $loaded.Resources[$key]
                }
            }
        }
        elseif ($loaded -is [System.Windows.Controls.UserControl]) {
            $content = $loaded.Content
        }

        if ($null -eq $content) {
            throw "The XAML root has no content to display."
        }

        $script:PreviewHost.Content = $content
        $script:CurrentFilePath = $FilePath

        # Update the window title and status bar.
        $script:MainWindow.Title = "UI Preview Tool - $(Split-Path $FilePath -Leaf)"
        Set-Status -Message "Loaded: $(Split-Path $FilePath -Leaf)" -Type 'info'

        # Show the preview at 100% zoom by default (the user can switch to Fit
        # or any other zoom level via the toolbar).
        Set-Zoom -Scale 1.0
    }
    catch {
        Set-Status -Message "Error: $($_.Exception.Message)" -Type 'error'
        $script:PreviewHost.Content = $null
    }
}

# ---------------------------------------------------------------------------
# Region: File watcher (auto-reload)
# ---------------------------------------------------------------------------
function Set-FileWatcher {
    <#
    .SYNOPSIS
        Watches the directory of the given file and triggers a debounced reload
        whenever the file changes on disk.
    #>
    param([string]$FilePath)

    # Dispose any previous watcher.
    if ($script:Watcher) {
        $script:Watcher.EnableRaisingEvents = $false
        $script:Watcher.Dispose()
        $script:Watcher = $null
    }

    $dir = [System.IO.Path]::GetDirectoryName($FilePath)
    $name = [System.IO.Path]::GetFileName($FilePath)
    if ([string]::IsNullOrWhiteSpace($dir)) { return }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $dir
    $watcher.Filter = $name
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size
    $watcher.EnableRaisingEvents = $true

    # FileSystemWatcher raises events on a background thread, so marshal the
    # debounce timer reset onto the UI dispatcher.
    $watcher.Add_Changed({
        $script:Dispatcher.BeginInvoke([Action]{
            $script:ReloadTimer.Stop()
            $script:ReloadTimer.Start()
        }) | Out-Null
    })

    $script:Watcher = $watcher
}

# ---------------------------------------------------------------------------
# Region: Recent files
# ---------------------------------------------------------------------------
$script:RecentFileStore = Join-Path $PSScriptRoot "ui-preview-recent.json"
$script:RecentFiles = @()

function Load-RecentFiles {
    <#
    .SYNOPSIS
        Loads the recent files list from disk and refreshes the UI.
    #>
    if (Test-Path -LiteralPath $script:RecentFileStore) {
        try {
            $data = Get-Content -LiteralPath $script:RecentFileStore -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:RecentFiles = @($data | Where-Object { Test-Path -LiteralPath $_ })
        }
        catch { $script:RecentFiles = @() }
    }
    Refresh-FileList
}

function Save-RecentFiles {
    <#
    .SYNOPSIS
        Persists the recent files list to disk.
    #>
    try {
        $script:RecentFiles | Select-Object -First 15 | ConvertTo-Json |
            Set-Content -LiteralPath $script:RecentFileStore -Encoding UTF8
    }
    catch { }
}

function Add-RecentFile {
    <#
    .SYNOPSIS
        Adds a file to the top of the recent files list and refreshes the UI.
    #>
    param([string]$FilePath)
    $script:RecentFiles = @($FilePath) + @($script:RecentFiles | Where-Object { $_ -ne $FilePath })
    $script:RecentFiles = @($script:RecentFiles | Select-Object -First 15)
    Save-RecentFiles
    Refresh-FileList
}

function Refresh-FileList {
    <#
    .SYNOPSIS
        Rebuilds the recent files list box from the in-memory list.
    #>
    $script:FileList.Items.Clear()
    foreach ($f in $script:RecentFiles) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = [System.IO.Path]::GetFileName($f)
        $item.ToolTip = $f
        $item.Tag = $f
        $script:FileList.Items.Add($item) | Out-Null
    }
}

function Clear-RecentFiles {
    <#
    .SYNOPSIS
        Clears the recent files list and refreshes the UI.
    #>
    $script:RecentFiles = @()
    Save-RecentFiles
    Refresh-FileList
    Set-Status -Message "Recent files history cleared." -Type 'info'
}

# ---------------------------------------------------------------------------
# Region: File opening
# ---------------------------------------------------------------------------
function Open-File {
    <#
    .SYNOPSIS
        Opens a file: adds it to recent files, sets up the watcher and renders it.
    #>
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Set-Status -Message "File not found: $FilePath" -Type 'error'
        return
    }
    $script:CurrentFilePath = $FilePath
    Add-RecentFile -FilePath $FilePath
    Set-FileWatcher -FilePath $FilePath
    Show-Preview -FilePath $FilePath
}

function Open-FileDialog {
    <#
    .SYNOPSIS
        Shows the open file dialog and opens the selected file.
    #>
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title = "Open XAML/XML file for preview"
    $dlg.Filter = "XAML/XML Files (*.xaml;*.xml)|*.xaml;*.xml|XAML Files (*.xaml)|*.xaml|XML Files (*.xml)|*.xml|All Files (*.*)|*.*"
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog($script:MainWindow) -eq $true) {
        Open-File -FilePath $dlg.FileName
    }
}

# ---------------------------------------------------------------------------
# Region: Code view
# ---------------------------------------------------------------------------
function Show-CodeView {
    <#
    .SYNOPSIS
        Opens a read-only window showing the raw code of the current file.
    #>
    if (-not $script:CurrentFilePath) {
        Set-Status -Message "No file loaded." -Type 'warn'
        return
    }

    $codeXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Code View" Height="600" Width="800"
        WindowStartupLocation="CenterOwner" Background="#FF1E1E1E">
    <DockPanel>
        <TextBlock DockPanel.Dock="Top" x:Name="CodeTitle" Foreground="White"
                   FontWeight="Bold" Margin="10,8" Text="Code"/>
        <TextBox x:Name="CodeBox" IsReadOnly="True" FontFamily="Consolas"
                 FontSize="12" Foreground="#FFDCDCDC" Background="#FF1E1E1E"
                 BorderThickness="0" Padding="8"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                 TextWrapping="NoWrap"/>
    </DockPanel>
</Window>
'@

    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($codeXaml)
        $reader = New-Object System.Xml.XmlNodeReader $xmlDoc
        $codeWindow = [System.Windows.Markup.XamlReader]::Load($reader)
        $codeBox = $codeWindow.FindName('CodeBox')
        $codeTitle = $codeWindow.FindName('CodeTitle')

        $codeTitle.Text = "Code - $(Split-Path $script:CurrentFilePath -Leaf)"
        $codeBox.Text = Get-Content -LiteralPath $script:CurrentFilePath -Raw -Encoding UTF8
        $codeWindow.ShowDialog() | Out-Null
    }
    catch {
        Set-Status -Message "Error opening code view: $($_.Exception.Message)" -Type 'error'
    }
}

# ---------------------------------------------------------------------------
# Region: Main window definition
# ---------------------------------------------------------------------------
$mainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="UI Preview Tool" Height="720" Width="1100"
        WindowStartupLocation="CenterScreen" Background="#FF1E1E1E">
    <DockPanel>
        <!-- Toolbar -->
        <ToolBarTray DockPanel.Dock="Top" Background="#FF2D2D30">
            <ToolBar>
                <Button x:Name="OpenButton" Content="Open..." ToolTip="Open a XAML/XML file (Ctrl+O)"/>
                <Button x:Name="ReloadButton" Content="Reload" ToolTip="Reload the current file (Ctrl+R / F5)"/>
                <CheckBox x:Name="AutoReloadCheck" Content="Auto-reload" IsChecked="True" ToolTip="Automatically reload the preview when the file changes"/>
                <Separator/>
                <Button x:Name="ZoomOutButton" Content="-" ToolTip="Zoom out"/>
                <Button x:Name="ZoomInButton" Content="+" ToolTip="Zoom in"/>
                <Button x:Name="FitButton" Content="Fit" ToolTip="Fit the preview to the window"/>
                <Button x:Name="ResetZoomButton" Content="100%" ToolTip="Reset zoom to 100%"/>
                <TextBlock x:Name="ZoomLabel" Text="100%" VerticalAlignment="Center" Margin="6,0,0,0" Foreground="White"/>
                <Separator/>
                <Button x:Name="ShowWindowButton" Content="Show as Window" ToolTip="Open the loaded XAML as a separate window"/>
                <Button x:Name="ViewCodeButton" Content="View Code" ToolTip="View the raw code of the current file"/>
            </ToolBar>
        </ToolBarTray>

        <!-- Status bar -->
        <StatusBar DockPanel.Dock="Bottom" Background="#FF007ACC">
            <StatusBarItem x:Name="StatusText" Foreground="White" Content="Ready"/>
        </StatusBar>

        <!-- Main content -->
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="240" MinWidth="160"/>
                <ColumnDefinition Width="5"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left panel: recent files -->
            <DockPanel Grid.Column="0" Background="#FF252526">
                <TextBlock DockPanel.Dock="Top" Text="Recent Files" Foreground="White" FontWeight="Bold" Margin="10,8"/>
                <Button x:Name="ClearHistoryButton" DockPanel.Dock="Bottom" Content="Clear History"
                        Margin="8" Padding="4,3" ToolTip="Clear the recent files list"/>
                <ListBox x:Name="FileList" Background="#FF252526" Foreground="White" BorderThickness="0"/>
            </DockPanel>

            <!-- Splitter -->
            <GridSplitter Grid.Column="1" HorizontalAlignment="Stretch" Background="#FF3F3F46"/>

            <!-- Preview area -->
            <Border Grid.Column="2" Background="#FFF0F0F0">
                <ScrollViewer x:Name="PreviewScroll" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#FFF0F0F0">
                    <!-- The wrapping Grid is kept at least as large as the viewport
                         (via MinWidth/MinHeight bound to the ScrollViewer size) so
                         the preview content is centered when it is smaller than the
                         viewport, but still scrolls when it is larger. -->
                    <Grid x:Name="PreviewCenter" HorizontalAlignment="Left" VerticalAlignment="Top"
                          MinWidth="{Binding ActualWidth, ElementName=PreviewScroll}"
                          MinHeight="{Binding ActualHeight, ElementName=PreviewScroll}">
                        <ContentControl x:Name="PreviewHost" HorizontalAlignment="Center" VerticalAlignment="Center" Background="White"/>
                    </Grid>
                </ScrollViewer>
            </Border>
        </Grid>
    </DockPanel>
</Window>
'@

# Load the main window XAML and grab references to the named elements.
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($mainXaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$script:MainWindow = [System.Windows.Markup.XamlReader]::Load($reader)

$script:OpenButton       = $script:MainWindow.FindName('OpenButton')
$script:ReloadButton     = $script:MainWindow.FindName('ReloadButton')
$script:AutoReloadCheck  = $script:MainWindow.FindName('AutoReloadCheck')
$script:ZoomOutButton    = $script:MainWindow.FindName('ZoomOutButton')
$script:ZoomInButton     = $script:MainWindow.FindName('ZoomInButton')
$script:FitButton        = $script:MainWindow.FindName('FitButton')
$script:ResetZoomButton  = $script:MainWindow.FindName('ResetZoomButton')
$script:ZoomLabel        = $script:MainWindow.FindName('ZoomLabel')
$script:ShowWindowButton = $script:MainWindow.FindName('ShowWindowButton')
$script:ViewCodeButton    = $script:MainWindow.FindName('ViewCodeButton')
$script:ClearHistoryButton = $script:MainWindow.FindName('ClearHistoryButton')
$script:StatusText       = $script:MainWindow.FindName('StatusText')
$script:FileList         = $script:MainWindow.FindName('FileList')
$script:PreviewScroll    = $script:MainWindow.FindName('PreviewScroll')
$script:PreviewCenter    = $script:MainWindow.FindName('PreviewCenter')
$script:PreviewHost      = $script:MainWindow.FindName('PreviewHost')

# ---------------------------------------------------------------------------
# Region: Event wiring
# ---------------------------------------------------------------------------
# Toolbar buttons.
$script:OpenButton.Add_Click({ Open-FileDialog })
$script:ReloadButton.Add_Click({
    if ($script:CurrentFilePath) { Show-Preview -FilePath $script:CurrentFilePath }
})
$script:ZoomInButton.Add_Click({ Set-Zoom -Scale ($script:ZoomScale * 1.25) })
$script:ZoomOutButton.Add_Click({ Set-Zoom -Scale ($script:ZoomScale / 1.25) })
$script:ResetZoomButton.Add_Click({ Set-Zoom -Scale 1.0 })
$script:FitButton.Add_Click({ Set-FitZoom })

# "Show as Window" - reload the file fresh and display it as a real window.
$script:ShowWindowButton.Add_Click({
    if (-not $script:CurrentFilePath) {
        Set-Status -Message "No file loaded." -Type 'warn'
        return
    }
    try {
        $w = Load-XamlObject -FilePath $script:CurrentFilePath
        if ($w -is [System.Windows.Window]) {
            $w.Title = "Preview - $(Split-Path $script:CurrentFilePath -Leaf)"
            $w.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
            $w.ShowDialog() | Out-Null
        }
        else {
            Set-Status -Message "The XAML root is not a Window; it is shown inline." -Type 'warn'
        }
    }
    catch {
        Set-Status -Message "Error: $($_.Exception.Message)" -Type 'error'
    }
})

# "View Code" - show the raw code of the current file in a read-only window.
$script:ViewCodeButton.Add_Click({ Show-CodeView })

# "Clear History" - clear the recent files list.
$script:ClearHistoryButton.Add_Click({ Clear-RecentFiles })

# Recent files list.
$script:FileList.Add_SelectionChanged({
    param($sender, $e)
    $item = $script:FileList.SelectedItem
    if ($item -and $item.Tag) {
        Open-File -FilePath $item.Tag
    }
})

# Drag & drop support.
$script:MainWindow.AllowDrop = $true
$script:MainWindow.Add_DragOver({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    }
    else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})
$script:MainWindow.Add_Drop({
    param($sender, $e)
    $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
    if ($files -and $files.Count -gt 0) {
        Open-File -FilePath $files[0]
    }
    $e.Handled = $true
})

# Keyboard shortcuts: Ctrl+O (open), Ctrl+R / F5 (reload).
$script:MainWindow.Add_KeyDown({
    param($sender, $e)
    $ctrl = $e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control
    if ($e.Key -eq [System.Windows.Input.Key]::O -and $ctrl) {
        Open-FileDialog
        $e.Handled = $true
    }
    elseif ($e.Key -eq [System.Windows.Input.Key]::R -and $ctrl) {
        if ($script:CurrentFilePath) { Show-Preview -FilePath $script:CurrentFilePath }
        $e.Handled = $true
    }
    elseif ($e.Key -eq [System.Windows.Input.Key]::F5) {
        if ($script:CurrentFilePath) { Show-Preview -FilePath $script:CurrentFilePath }
        $e.Handled = $true
    }
})

# Clean up the file watcher when the tool closes.
$script:MainWindow.Add_Closed({
    if ($script:Watcher) {
        $script:Watcher.EnableRaisingEvents = $false
        $script:Watcher.Dispose()
    }
})

# ---------------------------------------------------------------------------
# Region: Main entry point
# ---------------------------------------------------------------------------
# Create the WPF application object if one does not already exist.
$app = [System.Windows.Application]::Current
if ($null -eq $app) { $app = New-Object System.Windows.Application }

# Capture the UI dispatcher for cross-thread marshaling (file watcher events).
$script:Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher

# Create the debounce timer used for auto-reload. It is created on the UI thread
# and reset on every file change; it only fires once changes stop for 400 ms.
$script:ReloadTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ReloadTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:ReloadTimer.Add_Tick({
    $script:ReloadTimer.Stop()
    if ($script:AutoReloadCheck.IsChecked -and $script:CurrentFilePath) {
        Show-Preview -FilePath $script:CurrentFilePath
    }
})

# Show a placeholder in the preview area until a file is opened.
$script:PreviewHost.Content = New-Object System.Windows.Controls.TextBlock -Property @{
    Text       = "Open a XAML/XML file to preview it here, or drag & drop a file."
    Foreground = [System.Windows.Media.Brushes]::Gray
    FontSize   = 16
    Margin     = New-Object System.Windows.Thickness(20)
}

# Load the recent files list.
Load-RecentFiles

# Hide the console while the GUI is shown.
Hide-ConsoleWindow

try {
    $script:MainWindow.ShowDialog() | Out-Null
}
finally {
    Show-ConsoleWindow
}
