#Requires -Version 7.0
<#
.SYNOPSIS
    ModernMDV v1.00.00 - Modern Markdown Viewer

.DESCRIPTION
    A WPF/XAML-based Markdown viewer for PowerShell following the ModernUI
    design philosophy. Features:
    - Frameless custom-title-bar window (800x600, centred)
    - Two-pane layout: 30% Sitemap (TreeView) | 70% Markdown viewer
    - Collapsible left panel with floating 20x20 toggle button
    - Full Markdown rendering (H1-H6, bold, italic, code, tables, lists…)
    - Click-to-navigate via sitemap headings
    - External XAML loading from ./WPF/
    - Base64 graphic resources via ./Lib/UI.lib (PNG fallback from ./PNG/)
    - Config-driven behaviour (config.json)
    - Integrated logging (runtime.log)

.AUTHOR
    praetoriani (Marc Sczepanski)

.VERSION
    1.00.00

.NOTES
    Requires: PowerShell 7.0+, .NET Framework 4.8+ / .NET 6+
    GitHub:   https://github.com/praetoriani
#>

param(
    [string]$ConfigPath  = "$PSScriptRoot\config.json",
    [string]$MarkdownFile = ""          # Optional: open file directly on start
)

Set-StrictMode -Version Latest

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1 – GLOBAL SCRIPT VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

$script:Config          = $null
$script:LogFilePath     = $null
$script:LogEnabled      = $false
$script:WindowRef       = $null
$script:ImageCache      = @{}
$script:PanelVisible    = $true         # Toggle state for left panel
$script:CurrentFile     = ""           # Path of currently loaded MD file
$script:HeadingAnchors  = @{}          # Maps heading text → FlowDocument paragraph

# Image path caches for hover effects (populated in Initialize-Images)
$script:ImgPaths        = @{}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2 – ASSEMBLY LOADING
# ═══════════════════════════════════════════════════════════════════════════════

try {
    Add-Type -AssemblyName PresentationFramework  -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore       -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase            -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms   -ErrorAction Stop   # OpenFileDialog
}
catch {
    Write-Host "[FATAL] Assembly loading failed: $_" -ForegroundColor Red
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3 – LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

function Initialize-Logging {
    param([pscustomobject]$Config)
    try {
        $script:LogEnabled = $false
        if ($Config.debug.enabled -eq "true") {
            $script:LogFilePath = Join-Path $PSScriptRoot $Config.debug.file
            if (Test-Path $script:LogFilePath) {
                Remove-Item $script:LogFilePath -Force -EA SilentlyContinue
            }
            $null = New-Item $script:LogFilePath -ItemType File -Force -EA Stop
            $script:LogEnabled = $true
        }
    } catch { Write-Host "[WARN] Logging init failed: $_" -ForegroundColor Yellow }
}

function Write-LogEntry {
    param(
        [string]$Severity = "INFO",
        [string]$Message  = ""
    )
    if (-not $script:LogEnabled -or [string]::IsNullOrEmpty($script:LogFilePath)) { return }
    try {
        $ts   = Get-Date -Format $script:Config.debug.datetime
        $icon = if ($script:Config.debug.severityLevel.$Severity) {
                    $script:Config.debug.severityLevel.$Severity
                } else { "[$Severity] -> " }
        "[$ts] $icon $Message" |
            Out-File -FilePath $script:LogFilePath -Append -Encoding UTF8 -EA SilentlyContinue
    } catch {}
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4 – CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

function Load-Configuration {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "[ERROR] config.json not found: $Path" -ForegroundColor Red
        return $null
    }
    try {
        return (Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json -EA Stop)
    } catch {
        Write-Host "[ERROR] config.json parse error: $_" -ForegroundColor Red
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5 – IMAGE UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

function Resolve-ImagePath {
    param([string]$ImageName)
    $p = Join-Path $PSScriptRoot "PNG" | Join-Path -ChildPath $ImageName
    if (Test-Path $p) { return (Resolve-Path $p).Path }
    Write-LogEntry -Severity "WARN" -Message "Image not found: $p"
    return $null
}

function Load-BitmapImage {
    param([string]$Path, [string]$Name = "?", [switch]$Fresh)
    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path $Path)) { return $null }
    if (-not $Fresh -and $script:ImageCache.ContainsKey($Path)) {
        return $script:ImageCache[$Path]
    }
    try {
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource   = New-Object System.Uri($Path, [System.UriKind]::Absolute)
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        if (-not $Fresh) { $script:ImageCache[$Path] = $bmp }
        Write-LogEntry -Severity "DEBUG" -Message "Image loaded: $Name"
        return $bmp
    } catch {
        Write-LogEntry -Severity "ERROR" -Message "Image load failed [$Name]: $_"
        return $null
    }
}

# Attach hover effect (normal/hover image swap) to a Label/Image pair
function Register-HoverEffect {
    param(
        [System.Windows.Controls.Label] $LabelCtrl,
        [System.Windows.Controls.Image] $ImageCtrl,
        [string]$NormalPath,
        [string]$HoverPath
    )
    if ($null -eq $LabelCtrl -or $null -eq $ImageCtrl) { return }
    $np = $NormalPath; $hp = $HoverPath
    if ($np) { $ImageCtrl.Source = (Load-BitmapImage -Path $np -Name "btn-normal") }

    $ImageCtrl.Add_MouseEnter({
        $img = Load-BitmapImage -Path $hp -Name "btn-hover" -Fresh
        if ($img) { $this.Source = $img }
    }.GetNewClosure())

    $ImageCtrl.Add_MouseLeave({
        $img = Load-BitmapImage -Path $np -Name "btn-normal" -Fresh
        if ($img) { $this.Source = $img }
    }.GetNewClosure())
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6 – XAML LOADING
# ═══════════════════════════════════════════════════════════════════════════════

function Load-XamlFile {
    param([string]$FileName)
    try {
        $p = Join-Path $PSScriptRoot "WPF" | Join-Path -ChildPath $FileName
        if (-not (Test-Path $p)) {
            Write-LogEntry -Severity "ERROR" -Message "XAML not found: $p"
            return $null
        }
        $content = Get-Content $p -Raw -Encoding UTF8
        Write-LogEntry -Severity "INFO" -Message "XAML loaded: $FileName"
        return $content
    } catch {
        Write-LogEntry -Severity "ERROR" -Message "XAML load failed [$FileName]: $_"
        return $null
    }
}

function New-WindowFromXaml {
    param([string]$XamlContent)
    try {
        $xml    = [xml]$XamlContent
        $reader = [System.Xml.XmlNodeReader]::new($xml)
        return [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-LogEntry -Severity "ERROR" -Message "XAML parse failed: $_"
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7 – MARKDOWN PARSER & RENDERER
#
#   Converts raw Markdown text into a WPF FlowDocument.
#   Supported elements:
#     H1–H6  │ **bold** / __bold__  │ *italic* / _italic_
#     ***bold-italic***             │ `inline code`
#     ```code blocks```            │ > blockquote
#     --- / *** horizontal rule    │ - / * / + unordered list
#     1. ordered list              │ | GFM tables |
#     [text](url) links            │ plain paragraphs
#
#   Each heading gets a named Paragraph so the sitemap can scroll to it.
# ═══════════════════════════════════════════════════════════════════════════════

function Convert-MarkdownToFlowDocument {
    param(
        [string[]]$Lines,
        [pscustomobject]$ViewerConfig
    )

    Write-LogEntry -Severity "INFO" -Message "Building FlowDocument from Markdown…"

    $fd = New-Object System.Windows.Documents.FlowDocument
    $fd.Background   = [System.Windows.Media.Brushes]::Transparent
    $fd.FontFamily   = New-Object System.Windows.Media.FontFamily($ViewerConfig.fontFamily)
    $fd.FontSize     = $ViewerConfig.baseFontSize
    $fd.Foreground   = New-Object System.Windows.Media.SolidColorBrush(
                           [System.Windows.Media.ColorConverter]::ConvertFromString(
                               $ViewerConfig.bodyColor))
    $fd.PagePadding  = New-Object System.Windows.Thickness(28, 20, 28, 20)
    $fd.LineHeight   = $ViewerConfig.baseFontSize * 1.6

    # ── colour helpers ────────────────────────────────────────────────────────
    function Get-Brush([string]$hex) {
        New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString($hex))
    }

    $headingColors = @{
        1 = $ViewerConfig.h1Color
        2 = $ViewerConfig.h2Color
        3 = $ViewerConfig.h3Color
        4 = $ViewerConfig.h4Color
        5 = $ViewerConfig.h4Color
        6 = $ViewerConfig.h4Color
    }
    $headingSizes  = @{ 1=28; 2=22; 3=18; 4=16; 5=14; 6=13 }

    # ── inline parser: returns List[Inline] ──────────────────────────────────
    function Parse-Inlines {
        param([string]$text)
        $inlines = New-Object System.Collections.Generic.List[System.Windows.Documents.Inline]

        # Process inline elements with simple regex scan
        $remaining = $text
        while ($remaining.Length -gt 0) {
            # Bold+italic
            if ($remaining -match '^\*\*\*(.+?)\*\*\*') {
                $r = New-Object System.Windows.Documents.Run($Matches[1])
                $r.FontWeight = [System.Windows.FontWeights]::Bold
                $r.FontStyle  = [System.Windows.FontStyles]::Italic
                $inlines.Add($r)
                $remaining = $remaining.Substring($Matches[0].Length)
                continue
            }
            # Bold
            if ($remaining -match '^(\*\*|__)(.+?)(\*\*|__)') {
                $r = New-Object System.Windows.Documents.Run($Matches[2])
                $r.FontWeight = [System.Windows.FontWeights]::Bold
                $inlines.Add($r)
                $remaining = $remaining.Substring($Matches[0].Length)
                continue
            }
            # Italic
            if ($remaining -match '^([*_])(.+?)\1') {
                $r = New-Object System.Windows.Documents.Run($Matches[2])
                $r.FontStyle = [System.Windows.FontStyles]::Italic
                $inlines.Add($r)
                $remaining = $remaining.Substring($Matches[0].Length)
                continue
            }
            # Inline code
            if ($remaining -match '^`(.+?)`') {
                $r = New-Object System.Windows.Documents.Run($Matches[1])
                $r.FontFamily  = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
                $r.Background  = Get-Brush $ViewerConfig.codeBackground
                $r.Foreground  = Get-Brush $ViewerConfig.codeForeground
                $r.FontSize    = $ViewerConfig.baseFontSize - 1
                $inlines.Add($r)
                $remaining = $remaining.Substring($Matches[0].Length)
                continue
            }
            # Link [text](url)
            if ($remaining -match '^\[(.+?)\]\((.+?)\)') {
                $hl = New-Object System.Windows.Documents.Hyperlink
                $hl.Inlines.Add($Matches[1])
                $hl.Foreground     = Get-Brush $ViewerConfig.linkColor
                $hl.TextDecorations = $null
                try { $hl.NavigateUri = New-Object System.Uri($Matches[2]) } catch {}
                $hl.Add_RequestNavigate({
                    param($s,$e)
                    Start-Process $e.Uri.AbsoluteUri
                    $e.Handled = $true
                })
                $inlines.Add($hl)
                $remaining = $remaining.Substring($Matches[0].Length)
                continue
            }
            # Plain character (consume one char at a time for safety)
            $inlines.Add((New-Object System.Windows.Documents.Run($remaining[0])))
            $remaining = $remaining.Substring(1)
        }
        return $inlines
    }

    # ── state machine for fenced code blocks ─────────────────────────────────
    $inCodeBlock = $false
    $codeLines   = [System.Collections.Generic.List[string]]::new()
    $codeLanguage = ""

    function Flush-CodeBlock {
        if ($codeLines.Count -eq 0) { return }
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin     = New-Object System.Windows.Thickness(0, 8, 0, 8)
        $para.Background = Get-Brush $ViewerConfig.codeBackground
        $para.Padding    = New-Object System.Windows.Thickness(12, 8, 12, 8)
        foreach ($cl in $codeLines) {
            $r = New-Object System.Windows.Documents.Run("$cl`n")
            $r.FontFamily = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
            $r.Foreground = Get-Brush $ViewerConfig.codeForeground
            $r.FontSize   = $ViewerConfig.baseFontSize - 1
            $para.Inlines.Add($r)
        }
        $fd.Blocks.Add($para)
        $codeLines.Clear()
    }

    # ── table accumulator ─────────────────────────────────────────────────────
    $inTable    = $false
    $tableRows  = [System.Collections.Generic.List[string[]]]::new()
    $tableIsHeader = $false

    function Flush-Table {
        if ($tableRows.Count -eq 0) { return }
        $table = New-Object System.Windows.Documents.Table
        $table.CellSpacing = 0
        $table.Margin      = New-Object System.Windows.Thickness(0, 8, 0, 8)
        $table.BorderBrush = Get-Brush $ViewerConfig.tableBorderColor
        $table.BorderThickness = New-Object System.Windows.Thickness(1)

        $rg = New-Object System.Windows.Documents.TableRowGroup
        $isFirst = $true
        foreach ($row in $tableRows) {
            $tr = New-Object System.Windows.Documents.TableRow
            if ($isFirst) {
                $tr.Background = Get-Brush "#1A1A2A"
                $isFirst = $false
            }
            foreach ($cell in $row) {
                $tc = New-Object System.Windows.Documents.TableCell
                $tc.BorderBrush     = Get-Brush $ViewerConfig.tableBorderColor
                $tc.BorderThickness = New-Object System.Windows.Thickness(0, 0, 1, 1)
                $tc.Padding         = New-Object System.Windows.Thickness(8, 4, 8, 4)
                $p   = New-Object System.Windows.Documents.Paragraph
                foreach ($il in (Parse-Inlines -text $cell.Trim())) { $p.Inlines.Add($il) }
                $tc.Blocks.Add($p)
                $tr.Cells.Add($tc)
            }
            $rg.Rows.Add($tr)
        }
        $table.RowGroups.Add($rg)
        $fd.Blocks.Add($table)
        $tableRows.Clear()
    }

    # ── main line-by-line loop ────────────────────────────────────────────────
    foreach ($line in $Lines) {

        # ── fenced code block toggle ──────────────────────────────────────────
        if ($line -match '^```(.*)') {
            if (-not $inCodeBlock) {
                $inCodeBlock  = $true
                $codeLanguage = $Matches.Trim()[1]
            } else {
                $inCodeBlock = $false
                Flush-CodeBlock
            }
            continue
        }
        if ($inCodeBlock) {
            $codeLines.Add($line)
            continue
        }

        # ── GFM table rows ────────────────────────────────────────────────────
        if ($line -match '^\|.+\|') {
            # Skip separator line (|---|---|)
            if ($line -match '^\|[\s\-:\|]+\|$') { continue }
            $cells = $line.Trim('|') -split '\|'
            $tableRows.Add($cells)
            $inTable = $true
            continue
        } elseif ($inTable) {
            Flush-Table
            $inTable = $false
        }

        # ── horizontal rule ───────────────────────────────────────────────────
        if ($line -match '^(\-{3,}|\*{3,}|_{3,})\s*$') {
            $para = New-Object System.Windows.Documents.Paragraph
            $para.Margin = New-Object System.Windows.Thickness(0, 6, 0, 6)
            $r = New-Object System.Windows.Documents.Run(" ")
            $r.FontSize   = 1
            $r.Background = Get-Brush $ViewerConfig.hrColor
            $para.Inlines.Add($r)
            $para.Background = Get-Brush $ViewerConfig.hrColor
            $para.Padding    = New-Object System.Windows.Thickness(0, 1, 0, 0)
            $fd.Blocks.Add($para)
            continue
        }

        # ── headings H1–H6 ────────────────────────────────────────────────────
        if ($line -match '^(#{1,6})\s+(.+)$') {
            $level = $Matches.Length[1]
            $text  = $Matches.Trim()[2]
            $para  = New-Object System.Windows.Documents.Paragraph
            $para.Margin     = New-Object System.Windows.Thickness(
                                   0, $(if ($level -le 2) { 20 } else { 12 }),
                                   0, $(if ($level -le 2) { 8  } else { 4  }))
            $para.FontSize   = $headingSizes[$level]
            $para.FontWeight = [System.Windows.FontWeights]::SemiBold
            $para.Foreground = Get-Brush $headingColors[$level]
            $para.Tag        = "heading:$text"   # used for anchor navigation

            foreach ($il in (Parse-Inlines -text $text)) { $para.Inlines.Add($il) }

            # Register anchor for sitemap navigation
            $script:HeadingAnchors[$text] = $para
            $fd.Blocks.Add($para)
            continue
        }

        # ── blockquote ────────────────────────────────────────────────────────
        if ($line -match '^>\s?(.*)') {
            $inner = $Matches[1]
            $para  = New-Object System.Windows.Documents.Paragraph
            $para.Margin          = New-Object System.Windows.Thickness(16, 4, 0, 4)
            $para.Padding         = New-Object System.Windows.Thickness(12, 4, 8, 4)
            $para.BorderBrush     = Get-Brush "#4455AA"
            $para.BorderThickness = New-Object System.Windows.Thickness(3, 0, 0, 0)
            $para.Foreground      = Get-Brush $ViewerConfig.blockquoteColor
            $para.FontStyle       = [System.Windows.FontStyles]::Italic
            foreach ($il in (Parse-Inlines -text $inner)) { $para.Inlines.Add($il) }
            $fd.Blocks.Add($para)
            continue
        }

        # ── unordered list ────────────────────────────────────────────────────
        if ($line -match '^(\s*)([-*+])\s+(.+)$') {
            $indent = [math]::Floor($Matches.Length / 2) + 1[1]
            $inner  = $Matches[3]
            $list   = New-Object System.Windows.Documents.List
            $list.Margin      = New-Object System.Windows.Thickness(16 * $indent, 2, 0, 2)
            $list.MarkerStyle = [System.Windows.TextMarkerStyle]::Disc
            $li    = New-Object System.Windows.Documents.ListItem
            $para  = New-Object System.Windows.Documents.Paragraph
            foreach ($il in (Parse-Inlines -text $inner)) { $para.Inlines.Add($il) }
            $li.Blocks.Add($para)
            $list.ListItems.Add($li)
            $fd.Blocks.Add($list)
            continue
        }

        # ── ordered list ──────────────────────────────────────────────────────
        if ($line -match '^\s*\d+\.\s+(.+)$') {
            $inner = $Matches[1]
            $list  = New-Object System.Windows.Documents.List
            $list.Margin      = New-Object System.Windows.Thickness(16, 2, 0, 2)
            $list.MarkerStyle = [System.Windows.TextMarkerStyle]::Decimal
            $li    = New-Object System.Windows.Documents.ListItem
            $para  = New-Object System.Windows.Documents.Paragraph
            foreach ($il in (Parse-Inlines -text $inner)) { $para.Inlines.Add($il) }
            $li.Blocks.Add($para)
            $list.ListItems.Add($li)
            $fd.Blocks.Add($list)
            continue
        }

        # ── blank line ────────────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # ── plain paragraph ───────────────────────────────────────────────────
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3)
        foreach ($il in (Parse-Inlines -text $line)) { $para.Inlines.Add($il) }
        $fd.Blocks.Add($para)
    }

    # Flush any remaining code block or table
    if ($inCodeBlock) { Flush-CodeBlock }
    if ($inTable)     { Flush-Table    }

    Write-LogEntry -Severity "INFO" -Message "FlowDocument built successfully"
    return $fd
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8 – SITEMAP BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

function Build-Sitemap {
    param(
        [string[]]$Lines,
        [System.Windows.Controls.TreeView]$TreeView
    )
    Write-LogEntry -Severity "INFO" -Message "Building sitemap…"
    $TreeView.Items.Clear()
    $script:HeadingAnchors = @{}   # reset before re-parse

    $h1Node = $null
    $h2Node = $null

    foreach ($line in $Lines) {
        if ($line -match '^(#{1,6})\s+(.+)$') {
            $level = $Matches.Length[1]
            $text  = $Matches.Trim()[2]

            $prefix = switch ($level) {
                1 { "" }       2 { "  " }
                3 { "    " }   4 { "      " }
                default { "        " }
            }
            $weight = if ($level -le 2) {
                [System.Windows.FontWeights]::SemiBold
            } else {
                [System.Windows.FontWeights]::Normal
            }
            $fgColor = switch ($level) {
                1 { "#DDEEFF" }  2 { "#AABBDD" }
                3 { "#8899BB" }  default { "#667788" }
            }

            $item              = New-Object System.Windows.Controls.TreeViewItem
            $item.Header       = "$prefix$text"
            $item.FontSize     = if ($level -le 2) { 12 } else { 11 }
            $item.FontWeight   = $weight
            $item.Foreground   = New-Object System.Windows.Media.SolidColorBrush(
                                     [System.Windows.Media.ColorConverter]::ConvertFromString($fgColor))
            $item.Background   = [System.Windows.Media.Brushes]::Transparent
            $item.Padding      = New-Object System.Windows.Thickness(4, 3, 4, 3)
            $item.Tag          = $text     # used to locate the anchor paragraph

            $item.Add_MouseLeftButtonUp({
                param($sender, $e)
                $headingText = $sender.Tag
                if ($script:HeadingAnchors.ContainsKey($headingText)) {
                    $para = $script:HeadingAnchors[$headingText]
                    $para.BringIntoView()
                }
                $e.Handled = $true
            }.GetNewClosure())

            # Build a simple two-level tree (H1 → H2 children)
            switch ($level) {
                1 {
                    $h1Node = $item
                    $h2Node = $null
                    $TreeView.Items.Add($item)
                }
                2 {
                    $h2Node = $item
                    if ($h1Node) { $h1Node.Items.Add($item) }
                    else         { $TreeView.Items.Add($item) }
                }
                default {
                    if ($h2Node)      { $h2Node.Items.Add($item) }
                    elseif ($h1Node)  { $h1Node.Items.Add($item) }
                    else              { $TreeView.Items.Add($item) }
                }
            }
        }
    }

    # Expand all root items by default
    foreach ($item in $TreeView.Items) { $item.IsExpanded = $true }
    Write-LogEntry -Severity "INFO" -Message "Sitemap built with $($TreeView.Items.Count) root nodes"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 9 – FILE LOADING
# ═══════════════════════════════════════════════════════════════════════════════

function Open-MarkdownFile {
    param(
        [string]$FilePath = "",
        [System.Windows.Controls.TreeView]$SitemapTree,
        [System.Windows.Controls.FlowDocumentScrollViewer]$DocViewer,
        [System.Windows.Controls.Label]$FileNameLabel,
        [System.Windows.Controls.Label]$StatusLabel
    )

    # Show OpenFileDialog if no path given
    if ([string]::IsNullOrEmpty($FilePath)) {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title  = "Open Markdown File"
        $ofd.Filter = "Markdown Files (*.md;*.markdown)|*.md;*.markdown|All Files (*.*)|*.*"
        $ofd.InitialDirectory = [System.Environment]::GetFolderPath("MyDocuments")
        if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $FilePath = $ofd.FileName
    }

    if (-not (Test-Path $FilePath)) {
        [System.Windows.MessageBox]::Show(
            "File not found:`n$FilePath",
            "Error", "OK", "Error") | Out-Null
        return
    }

    Write-LogEntry -Severity "INFO" -Message "Opening file: $FilePath"
    $StatusLabel.Content   = "Loading…"
    $FileNameLabel.Content = [System.IO.Path]::GetFileName($FilePath)
    $script:CurrentFile    = $FilePath

    try {
        $raw   = Get-Content -Path $FilePath -Encoding UTF8 -Raw
        $lines = $raw -split "`r?`n"

        # Build sitemap (must run first to populate HeadingAnchors)
        Build-Sitemap -Lines $lines -TreeView $SitemapTree

        # Build FlowDocument
        $script:HeadingAnchors = @{}   # will be repopulated by Convert-Markdown…
        $fd = Convert-MarkdownToFlowDocument -Lines $lines -ViewerConfig $script:Config.viewer
        $DocViewer.Document = $fd

        $headingCount = ($lines | Where-Object { $_ -match '^#{1,6}\s' }).Count
        $StatusLabel.Content = "Loaded: $([System.IO.Path]::GetFileName($FilePath))  |  $($lines.Count) lines  |  $headingCount headings"
        Write-LogEntry -Severity "INFO" -Message "File loaded successfully: $FilePath"
    } catch {
        $StatusLabel.Content = "Error loading file"
        Write-LogEntry -Severity "ERROR" -Message "File load failed: $_"
        [System.Windows.MessageBox]::Show(
            "Error loading file:`n$_", "Load Error", "OK", "Error") | Out-Null
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10 – PANEL TOGGLE
# ═══════════════════════════════════════════════════════════════════════════════

function Toggle-SitemapPanel {
    param(
        [System.Windows.Controls.ColumnDefinition]$LeftCol,
        [System.Windows.Controls.ColumnDefinition]$RightCol,
        [System.Windows.Controls.Border]$LeftPanel,
        [System.Windows.Controls.Button]$ToggleBtn
    )
    if ($script:PanelVisible) {
        # Hide panel
        $LeftCol.Width          = New-Object System.Windows.GridLength(0)
        $RightCol.Width         = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $LeftPanel.Visibility   = [System.Windows.Visibility]::Collapsed
        $ToggleBtn.Content      = "›"
        $ToggleBtn.ToolTip      = "Show Sitemap Panel"
        $script:PanelVisible    = $false
        Write-LogEntry -Severity "DEBUG" -Message "Sitemap panel hidden"
    } else {
        # Show panel
        $LeftCol.Width          = New-Object System.Windows.GridLength(3, [System.Windows.GridUnitType]::Star)
        $RightCol.Width         = New-Object System.Windows.GridLength(7, [System.Windows.GridUnitType]::Star)
        $LeftPanel.Visibility   = [System.Windows.Visibility]::Visible
        $ToggleBtn.Content      = "‹"
        $ToggleBtn.ToolTip      = "Hide Sitemap Panel"
        $script:PanelVisible    = $true
        Write-LogEntry -Severity "DEBUG" -Message "Sitemap panel shown"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 11 – POPUP WINDOWS
# ═══════════════════════════════════════════════════════════════════════════════

function Show-AboutWindow {
    param([System.Windows.Window]$Owner)
    $xaml = Load-XamlFile -FileName $script:Config.screen.aboutwin
    if (-not $xaml) { return }
    $win = New-WindowFromXaml -XamlContent $xaml
    if (-not $win) { return }
    $win.Owner = $Owner

    $closeImg = $win.FindName("AboutBtnCloseImage")
    $closeBtn = $win.FindName("AboutBtnClose")
    $okBtn    = $win.FindName("AboutOkButton")

    $closePath = Resolve-ImagePath -ImageName $script:Config.paths.btnClose
    $hoverPath = Resolve-ImagePath -ImageName $script:Config.paths.btnCloseHover
    Register-HoverEffect -LabelCtrl $closeBtn -ImageCtrl $closeImg `
                         -NormalPath $closePath -HoverPath $hoverPath

    $closeBtn.Add_PreviewMouseLeftButtonDown({ $win.Close() })
    $okBtn.Add_Click({ $win.Close() })

    $win.FindName("AboutTitleBar").Add_MouseLeftButtonDown({
        try { $win.DragMove() } catch {}
    })
    $win.ShowDialog() | Out-Null
}

function Show-HelpWindow {
    param([System.Windows.Window]$Owner)
    $xaml = Load-XamlFile -FileName $script:Config.screen.helpwin
    if (-not $xaml) { return }
    $win = New-WindowFromXaml -XamlContent $xaml
    if (-not $win) { return }
    $win.Owner = $Owner

    $closeImg = $win.FindName("HelpBtnCloseImage")
    $closeBtn = $win.FindName("HelpBtnClose")
    $okBtn    = $win.FindName("HelpOkButton")

    $closePath = Resolve-ImagePath -ImageName $script:Config.paths.btnClose
    $hoverPath = Resolve-ImagePath -ImageName $script:Config.paths.btnCloseHover
    Register-HoverEffect -LabelCtrl $closeBtn -ImageCtrl $closeImg `
                         -NormalPath $closePath -HoverPath $hoverPath

    $closeBtn.Add_PreviewMouseLeftButtonDown({ $win.Close() })
    $okBtn.Add_Click({ $win.Close() })

    $win.FindName("HelpTitleBar").Add_MouseLeftButtonDown({
        try { $win.DragMove() } catch {}
    })
    $win.ShowDialog() | Out-Null
}

function Show-SettingsWindow {
    param([System.Windows.Window]$Owner)
    $xaml = Load-XamlFile -FileName $script:Config.screen.settingswin
    if (-not $xaml) { return }
    $win = New-WindowFromXaml -XamlContent $xaml
    if (-not $win) { return }
    $win.Owner = $Owner

    $closeImg   = $win.FindName("SettingsBtnCloseImage")
    $closeBtn   = $win.FindName("SettingsBtnClose")
    $saveBtn    = $win.FindName("SettingsSaveButton")
    $cancelBtn  = $win.FindName("SettingsCancelButton")
    $fontSlider = $win.FindName("FontSizeSlider")
    $fontValue  = $win.FindName("FontSizeValue")

    $closePath = Resolve-ImagePath -ImageName $script:Config.paths.btnClose
    $hoverPath = Resolve-ImagePath -ImageName $script:Config.paths.btnCloseHover
    Register-HoverEffect -LabelCtrl $closeBtn -ImageCtrl $closeImg `
                         -NormalPath $closePath -HoverPath $hoverPath

    $closeBtn.Add_PreviewMouseLeftButtonDown({ $win.Close() })
    $cancelBtn.Add_Click({ $win.Close() })

    # Initialise slider to current config value
    if ($fontSlider) {
        $fontSlider.Value = $script:Config.viewer.baseFontSize
        $fontValue.Text   = "$($script:Config.viewer.baseFontSize) pt"
        $fontSlider.Add_ValueChanged({
            $v = [math]::Round($fontSlider.Value)
            $fontValue.Text = "$v pt"
        })
    }

    $saveBtn.Add_Click({
        if ($fontSlider) {
            $script:Config.viewer.baseFontSize = [math]::Round($fontSlider.Value)
            Write-LogEntry -Severity "INFO" -Message "Font size updated to $($script:Config.viewer.baseFontSize) pt"
        }
        $win.Close()
    })

    $win.FindName("SettingsTitleBar").Add_MouseLeftButtonDown({
        try { $win.DragMove() } catch {}
    })
    $win.ShowDialog() | Out-Null
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 12 – WPF MAIN WINDOW INITIALISATION
# ═══════════════════════════════════════════════════════════════════════════════

function Initialize-MainWindow {
    param([pscustomobject]$Config)

    Write-LogEntry -Severity "INFO" -Message "Initialising main window…"

    # Load UI.lib (Base64 graphics – falls back to PNG if empty)
    $uiLibPath = Join-Path $PSScriptRoot "Lib\UI.lib"
    if (Test-Path $uiLibPath) {
        Write-LogEntry -Severity "INFO" -Message "Loading UI.lib…"
        . $uiLibPath
    }

    # Load XAML
    $xamlContent = Load-XamlFile -FileName $Config.screen.mainwin
    if (-not $xamlContent) { return $null }

    $window = New-WindowFromXaml -XamlContent $xamlContent
    if (-not $window) { return $null }
    $script:WindowRef = $window

    # ── Resolve UI elements ───────────────────────────────────────────────────
    $titleBar        = $window.FindName("TitleBar")
    $titleText       = $window.FindName("TitleText")
    $versionText     = $window.FindName("VersionText")
    $fileNameLabel   = $window.FindName("FileNameLabel")
    $statusLabel     = $window.FindName("StatusBarLabel")
    $sitemapTree     = $window.FindName("SitemapTree")
    $docViewer       = $window.FindName("DocViewer")
    $toggleBtn       = $window.FindName("TogglePanelButton")
    $leftPanel       = $window.FindName("LeftPanel")
    $leftCol         = $window.FindName("LeftColumn")
    $rightCol        = $window.FindName("RightColumn")
    $windowIconCtrl  = $window.FindName("WindowIcon")

    # Title bar buttons + their images
    $btnClose        = $window.FindName("BtnClose")
    $btnCloseImg     = $window.FindName("BtnCloseImage")
    $btnMin          = $window.FindName("BtnMinimize")
    $btnMinImg       = $window.FindName("BtnMinimizeImage")
    $btnMax          = $window.FindName("BtnMaximize")
    $btnMaxImg       = $window.FindName("BtnMaximizeImage")
    $btnOpen         = $window.FindName("BtnOpenFile")
    $btnOpenImg      = $window.FindName("BtnOpenFileImage")
    $btnInfo         = $window.FindName("BtnInfo")
    $btnInfoImg      = $window.FindName("BtnInfoImage")
    $btnHelp         = $window.FindName("BtnHelp")
    $btnHelpImg      = $window.FindName("BtnHelpImage")
    $btnSettings     = $window.FindName("BtnSettings")
    $btnSettingsImg  = $window.FindName("BtnSettingsImage")

    Write-LogEntry -Severity "DEBUG" -Message "UI elements resolved"

    # ── Set title / version ───────────────────────────────────────────────────
    $titleText.Text   = $Config.app.name
    $versionText.Text = "v$($Config.app.version)"

    # ── Window size from config ───────────────────────────────────────────────
    $window.Width     = $Config.window.width
    $window.Height    = $Config.window.height
    $window.MinWidth  = $Config.window.minWidth
    $window.MinHeight = $Config.window.minHeight

    # ── Load window icon ──────────────────────────────────────────────────────
    $iconPath = Resolve-ImagePath -ImageName $Config.paths.windowIcon
    if ($iconPath -and $windowIconCtrl) {
        $windowIconCtrl.Source = Load-BitmapImage -Path $iconPath -Name "appicon"
    }

    # ── Register hover effects for all title-bar buttons ─────────────────────
    $btnDefs = @(
        @{ Label=$btnClose;    Img=$btnCloseImg;    Normal=$Config.paths.btnClose;    Hover=$Config.paths.btnCloseHover    }
        @{ Label=$btnMin;      Img=$btnMinImg;      Normal=$Config.paths.btnMinimize; Hover=$Config.paths.btnMinimizeHover }
        @{ Label=$btnMax;      Img=$btnMaxImg;      Normal=$Config.paths.btnMaximize; Hover=$Config.paths.btnMaximizeHover }
        @{ Label=$btnOpen;     Img=$btnOpenImg;     Normal=$Config.paths.btnOpenFile; Hover=$Config.paths.btnOpenFileHover }
        @{ Label=$btnInfo;     Img=$btnInfoImg;     Normal=$Config.paths.btnInfo;     Hover=$Config.paths.btnInfoHover     }
        @{ Label=$btnHelp;     Img=$btnHelpImg;     Normal=$Config.paths.btnHelp;     Hover=$Config.paths.btnHelpHover     }
        @{ Label=$btnSettings; Img=$btnSettingsImg; Normal=$Config.paths.btnSettings; Hover=$Config.paths.btnSettingsHover }
    )
    foreach ($def in $btnDefs) {
        $nPath = Resolve-ImagePath -ImageName $def.Normal
        $hPath = Resolve-ImagePath -ImageName $def.Hover
        Register-HoverEffect -LabelCtrl $def.Label -ImageCtrl $def.Img `
                             -NormalPath $nPath -HoverPath $hPath
    }

    # ── Title bar: drag to move ───────────────────────────────────────────────
    $titleBar.Add_MouseLeftButtonDown({
        try { $script:WindowRef.DragMove() } catch {}
    })

    # ── Button: Close ─────────────────────────────────────────────────────────
    $btnClose.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Write-LogEntry -Severity "INFO" -Message "Close button clicked"
        $script:WindowRef.Close()
        $e.Handled = $true
    })

    # ── Button: Minimize ──────────────────────────────────────────────────────
    $btnMin.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        $script:WindowRef.WindowState = [System.Windows.WindowState]::Minimized
        $e.Handled = $true
    })

    # ── Button: Maximize / Restore ────────────────────────────────────────────
    $btnMax.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        if ($script:WindowRef.WindowState -eq [System.Windows.WindowState]::Maximized) {
            $script:WindowRef.WindowState = [System.Windows.WindowState]::Normal
        } else {
            $script:WindowRef.WindowState = [System.Windows.WindowState]::Maximized
        }
        $e.Handled = $true
    })

    # ── Button: Open File ─────────────────────────────────────────────────────
    $btnOpen.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Open-MarkdownFile -SitemapTree $sitemapTree `
                          -DocViewer $docViewer `
                          -FileNameLabel $fileNameLabel `
                          -StatusLabel $statusLabel
        $e.Handled = $true
    })

    # ── Button: Info (About) ──────────────────────────────────────────────────
    $btnInfo.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Show-AboutWindow -Owner $script:WindowRef
        $e.Handled = $true
    })

    # ── Button: Help ──────────────────────────────────────────────────────────
    $btnHelp.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Show-HelpWindow -Owner $script:WindowRef
        $e.Handled = $true
    })

    # ── Button: Settings ──────────────────────────────────────────────────────
    $btnSettings.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Show-SettingsWindow -Owner $script:WindowRef
        $e.Handled = $true
    })

    # ── Toggle panel button ───────────────────────────────────────────────────
    $toggleBtn.Add_Click({
        Toggle-SitemapPanel -LeftCol   $leftCol `
                            -RightCol  $rightCol `
                            -LeftPanel $leftPanel `
                            -ToggleBtn $toggleBtn
    })

    # ── Keyboard shortcuts ────────────────────────────────────────────────────
    $window.Add_KeyDown({
        param($s, $e)
        switch ($true) {
            ($e.Key -eq [System.Windows.Input.Key]::O -and
             $e.KeyboardDevice.Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
                Open-MarkdownFile -SitemapTree $sitemapTree `
                                  -DocViewer $docViewer `
                                  -FileNameLabel $fileNameLabel `
                                  -StatusLabel $statusLabel
                $e.Handled = $true
            }
            ($e.Key -eq [System.Windows.Input.Key]::W -and
             $e.KeyboardDevice.Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
                $docViewer.Document  = $null
                $sitemapTree.Items.Clear()
                $fileNameLabel.Content = "No file loaded"
                $statusLabel.Content   = "Ready"
                $script:CurrentFile    = ""
                $e.Handled = $true
            }
            ($e.Key -eq [System.Windows.Input.Key]::F1) {
                Show-HelpWindow -Owner $script:WindowRef
                $e.Handled = $true
            }
            ($e.Key -eq [System.Windows.Input.Key]::OemComma -and
             $e.KeyboardDevice.Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
                Show-SettingsWindow -Owner $script:WindowRef
                $e.Handled = $true
            }
            ($e.Key -eq [System.Windows.Input.Key]::System -and
             $e.SystemKey -eq [System.Windows.Input.Key]::F4) {
                $script:WindowRef.Close()
                $e.Handled = $true
            }
        }
    })

    Write-LogEntry -Severity "INFO" -Message "Main window initialised"
    return $window
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 13 – MAIN LOOP  (Orchestration Entry Point)
# ═══════════════════════════════════════════════════════════════════════════════

function Invoke-MainLoop {
    <#
    .SYNOPSIS
        Primary orchestration function. Called once at startup.
        Bootstraps config → logging → UI → event loop.
    #>

    # 1. Load configuration
    $script:Config = Load-Configuration -Path $ConfigPath
    if ($null -eq $script:Config) {
        Write-Host "[FATAL] Configuration loading failed" -ForegroundColor Red
        exit 1
    }

    # 2. Start logging
    Initialize-Logging -Config $script:Config
    Write-LogEntry -Severity "INFO" -Message "ModernMDV v$($script:Config.app.version) starting"
    Write-LogEntry -Severity "INFO" -Message "PSScriptRoot: $PSScriptRoot"
    Write-LogEntry -Severity "INFO" -Message "PowerShell: $($PSVersionTable.PSVersion)"

    # 3. Build main window
    $window = Initialize-MainWindow -Config $script:Config
    if ($null -eq $window) {
        Write-LogEntry -Severity "ERROR" -Message "Main window creation failed"
        Write-Host "[FATAL] Window creation failed" -ForegroundColor Red
        exit 1
    }

    # 4. If a file was passed as argument, open it immediately
    if (-not [string]::IsNullOrEmpty($MarkdownFile)) {
        Write-LogEntry -Severity "INFO" -Message "Auto-opening file: $MarkdownFile"
        $window.Add_Loaded({
            Open-MarkdownFile -FilePath $MarkdownFile `
                              -SitemapTree $window.FindName("SitemapTree") `
                              -DocViewer   $window.FindName("DocViewer") `
                              -FileNameLabel $window.FindName("FileNameLabel") `
                              -StatusLabel $window.FindName("StatusBarLabel")
        })
    }

    # 5. Run WPF message loop (blocking)
    Write-LogEntry -Severity "INFO" -Message "Entering WPF message loop"
    $window.ShowDialog() | Out-Null

    # 6. Cleanup
    Write-LogEntry -Severity "INFO" -Message "ModernMDV closed — session ended"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

try {
    Invoke-MainLoop
} catch {
    Write-LogEntry -Severity "ERROR" -Message "Unhandled exception: $_"
    Write-Host "[FATAL] $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}