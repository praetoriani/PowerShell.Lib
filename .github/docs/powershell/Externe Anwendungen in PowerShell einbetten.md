# Machbarkeitsanalyse: Externe Anwendungen in PowerShell WPF/XML einbetten

**Autor:** Systemanalyse & Dokumentation  
**Datum:** April 2026  
**Technologie:** PowerShell 5.1 / 7.x · WPF · Win32 API · .NET

---

## Executive Summary

Das Einbetten externer Anwendungsfenster (z. B. KeePass, Notepad++) in eine PowerShell-WPF-Applikation ist **technisch grundsätzlich machbar**, basiert jedoch auf einem undokumentierten und von Microsoft nicht offiziell unterstützten Verfahren: der Win32-API-Funktion `SetParent()`. Das Konzept funktioniert, indem das Fenster-Handle (HWND) einer externen Anwendung als Kind-Fenster in ein WPF-Hostfenster „umgehängt" wird. Die Umsetzung in reinem PowerShell erfordert `Add-Type`-basierte P/Invoke-Definitionen und eine `HwndHost`-Ableitung. Der Ansatz bringt erhebliche technische Einschränkungen mit sich — insbesondere rund um DPI-Skalierung, Prozessisolation, Berechtigungen (UIPI) und Renderingverhalten — die beim Design berücksichtigt werden müssen.

---

## 1. Technisches Grundprinzip

### 1.1 Was bedeutet „Fenster einbetten"?

Windows verwaltet jede sichtbare GUI-Fläche als **Fenster-Objekt** mit einem eindeutigen Handle (HWND). Jedes Fenster hat genau einen **Besitzprozess** und ein optionales **Eltern-Fenster** (Parent). Die Win32-Funktion `SetParent(hWndChild, hWndNewParent)` erlaubt es, das Parent-Fenster eines beliebigen Fensters zur Laufzeit zu ändern — auch prozessübergreifend.

Das Resultat: Das Fenster von KeePass oder Notepad++ erscheint visuell **innerhalb** des WPF-Containers, obwohl es weiterhin im eigenen Prozess läuft. Der Nutzer sieht nur ein Fenster, hat aber zwei separate Prozesse im Hintergrund.

### 1.2 Beteiligte Win32-API-Funktionen

| Funktion | DLL | Zweck |
|---|---|---|
| `SetParent(hChild, hParent)` | `user32.dll` | Verknüpft das externe Fenster mit dem WPF-Host-Handle |
| `SetWindowLong(hWnd, GWL_STYLE, style)` | `user32.dll` | Ändert Window-Style (WS_POPUP → WS_CHILD) |
| `GetWindowLong(hWnd, GWL_STYLE)` | `user32.dll` | Liest aktuellen Window-Style |
| `MoveWindow(hWnd, x, y, cx, cy, repaint)` | `user32.dll` | Positioniert das eingebettete Fenster |
| `SetWindowPos(hWnd, ...)` | `user32.dll` | Erweiterte Positions- & Z-Order-Kontrolle |
| `ShowWindow(hWnd, state)` | `user32.dll` | Steuert Sichtbarkeit |
| `FindWindow(className, title)` | `user32.dll` | Sucht Fenster nach Klasse oder Titel |
| `AttachThreadInput(tid1, tid2, attach)` | `user32.dll` | Synchronisiert Input-Queues zwischen Prozessen |

### 1.3 WPF-seitige Schlüsselklassen

**`HwndHost`** (Namespace: `System.Windows.Interop`) ist die WPF-seitige Brücke. Sie erlaubt es, ein Win32-HWND in die WPF-Elementhierarchie einzubetten. Die Klasse muss abgeleitet und `BuildWindowCore` überschrieben werden, um dort `SetParent` aufzurufen.

**`HwndSource`** wird benötigt, um umgekehrt WPF-Inhalte in Win32-Fenster einzubetten — für den vorliegenden Use-Case weniger relevant, aber wichtig für spätere Hybridszenarien.

---

## 2. Architektur & Lösungsansätze

Es gibt drei wesentliche Implementierungsstrategien, die sich in Komplexität und Stabilität unterscheiden.

### Lösungsansatz A: Direktes SetParent (Einfachste Variante)

Der direkteste Weg: Externer Prozess starten, auf das Hauptfenster-Handle warten, `SetParent` aufrufen, Fenster in WPF-Border einpassen. Kein `HwndHost` erforderlich, dafür aber auch keine saubere Integration in das WPF-Layout-System.

**Einsatzszenario:** Schnelle Prototypen, unkritische Umgebungen.

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# Win32 API Imports
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32Interop {
    [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll")] public static extern int  SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern int  GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int GWL_STYLE   = -16;
    public const int WS_CHILD    = 0x40000000;
    public const int WS_POPUP    = unchecked((int)0x80000000);
    public const int WS_VISIBLE  = 0x10000000;
    public const int SW_MAXIMIZE = 3;
}
"@

# XAML-Layout
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Embedded App Host" Height="700" Width="1000"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="40"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal" Background="#2D2D2D">
            <Button Name="btnEmbed" Content="Notepad++ einbetten" Margin="8,4"
                    Padding="12,4" Background="#0078D4" Foreground="White" BorderThickness="0"/>
        </StackPanel>
        <Border Name="hostBorder" Grid.Row="1" Background="#1E1E1E"/>
    </Grid>
</Window>
"@

$reader   = New-Object System.Xml.XmlNodeReader $xaml
$window   = [System.Windows.Markup.XamlReader]::Load($reader)
$btnEmbed = $window.FindName("btnEmbed")
$hostBorder = $window.FindName("hostBorder")

$embeddedProcess = $null

$btnEmbed.Add_Click({
    # Prozess starten
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "C:\Program Files\Notepad++\notepad++.exe"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    $embeddedProcess = [System.Diagnostics.Process]::Start($psi)

    # Warten bis das Fenster bereit ist
    $embeddedProcess.WaitForInputIdle()
    Start-Sleep -Milliseconds 500

    $childHwnd = $embeddedProcess.MainWindowHandle

    # Parent-HWND des WPF-Containers ermitteln
    $hwndSource = [System.Windows.Interop.HwndSource]::FromVisual($hostBorder)
    $parentHwnd = $hwndSource.Handle

    # WS_POPUP entfernen, WS_CHILD setzen - MUSS VOR SetParent geschehen!
    $style = [Win32Interop]::GetWindowLong($childHwnd, [Win32Interop]::GWL_STYLE)
    $style = ($style -band -bnot [Win32Interop]::WS_POPUP) -bor [Win32Interop]::WS_CHILD
    [Win32Interop]::SetWindowLong($childHwnd, [Win32Interop]::GWL_STYLE, $style) | Out-Null

    # Einbetten
    [Win32Interop]::SetParent($childHwnd, $parentHwnd) | Out-Null

    # Größe anpassen
    $w = [int]$hostBorder.ActualWidth
    $h = [int]$hostBorder.ActualHeight
    [Win32Interop]::MoveWindow($childHwnd, 0, 0, $w, $h, $true) | Out-Null
})

# Cleanup beim Schließen
$window.Add_Closing({
    if ($embeddedProcess -and -not $embeddedProcess.HasExited) {
        $embeddedProcess.Kill()
    }
})

$window.ShowDialog() | Out-Null
```

---

### Lösungsansatz B: HwndHost-Integration (Empfohlene Variante)

`HwndHost` ist die saubere WPF-native Methode. Das externe Fenster wird korrekt in die WPF-Visual-Tree-Hierarchie eingebettet, Layout-Ereignisse (SizeChanged, Loaded) werden korrekt weitergeleitet.

**Einsatzszenario:** Produktionsnahe Implementierungen, saubere WPF-Integration.

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows;

public class ExternalAppHost : HwndHost {
    private IntPtr _childHwnd;
    private int    _width;
    private int    _height;

    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll")] static extern int    SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] static extern int    GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] static extern bool   MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")] static extern bool   ShowWindow(IntPtr hWnd, int nCmdShow);

    private const int GWL_STYLE  = -16;
    private const int WS_CHILD   = 0x40000000;
    private const int WS_POPUP   = unchecked((int)0x80000000);
    private const int WS_VISIBLE = 0x10000000;

    public ExternalAppHost(IntPtr childHwnd, int width, int height) {
        _childHwnd = childHwnd;
        _width     = width;
        _height    = height;
    }

    protected override HandleRef BuildWindowCore(HandleRef hwndParent) {
        // WS_POPUP → WS_CHILD MUSS VOR SetParent gesetzt werden
        int style = GetWindowLong(_childHwnd, GWL_STYLE);
        style = (style & ~WS_POPUP) | WS_CHILD | WS_VISIBLE;
        SetWindowLong(_childHwnd, GWL_STYLE, style);

        SetParent(_childHwnd, hwndParent.Handle);
        MoveWindow(_childHwnd, 0, 0, _width, _height, true);
        ShowWindow(_childHwnd, 1);

        return new HandleRef(this, _childHwnd);
    }

    protected override void DestroyWindowCore(HandleRef hwnd) {
        // Fenster vom Parent lösen statt zerstören (externer Prozess lebt weiter)
        SetParent(_childHwnd, IntPtr.Zero);
    }

    public void Resize(int width, int height) {
        _width  = width;
        _height = height;
        if (_childHwnd != IntPtr.Zero)
            MoveWindow(_childHwnd, 0, 0, width, height, true);
    }
}
"@ -ReferencedAssemblies "PresentationFramework","PresentationCore","WindowsBase","System.Runtime.InteropServices"

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HwndHost Demo – Embedded Applications"
        Height="800" Width="1200"
        WindowStartupLocation="CenterScreen"
        Background="#1C1C1C">
    <DockPanel>
        <ToolBar DockPanel.Dock="Top" Background="#2D2D2D" Height="44">
            <Button Name="btnKeePass"  Content="🔑 KeePass"   Padding="12,6" Margin="4,0"
                    Background="#0078D4" Foreground="White" BorderThickness="0"/>
            <Button Name="btnNotepad"  Content="📝 Notepad++" Padding="12,6" Margin="4,0"
                    Background="#0078D4" Foreground="White" BorderThickness="0"/>
            <Button Name="btnRelease"  Content="⏏ Freigeben"  Padding="12,6" Margin="4,0"
                    Background="#CC3300" Foreground="White" BorderThickness="0"/>
        </ToolBar>
        <Border Name="hostBorder" Background="#000000"/>
    </DockPanel>
</Window>
"@

$reader     = New-Object System.Xml.XmlNodeReader $xaml
$window     = [System.Windows.Markup.XamlReader]::Load($reader)
$hostBorder = $window.FindName("hostBorder")
$btnKeePass = $window.FindName("btnKeePass")
$btnNotepad = $window.FindName("btnNotepad")
$btnRelease = $window.FindName("btnRelease")

$currentProcess = $null
$currentHost    = $null

function Embed-Application {
    param([string]$ExePath)

    if ($currentProcess -and -not $currentProcess.HasExited) {
        $currentProcess.Kill()
    }

    $proc = [System.Diagnostics.Process]::Start($ExePath)
    $proc.WaitForInputIdle()
    Start-Sleep -Milliseconds 600

    $w = [int]$hostBorder.ActualWidth
    $h = [int]$hostBorder.ActualHeight

    $script:currentProcess = $proc
    $script:currentHost    = New-Object ExternalAppHost($proc.MainWindowHandle, $w, $h)

    $hostBorder.Child = $script:currentHost
}

$btnKeePass.Add_Click({ Embed-Application "C:\Program Files (x86)\KeePass Password Safe 2\KeePass.exe" })
$btnNotepad.Add_Click({ Embed-Application "C:\Program Files\Notepad++\notepad++.exe" })

$btnRelease.Add_Click({
    $hostBorder.Child = $null
    if ($currentProcess -and -not $currentProcess.HasExited) {
        # Fenster wieder zum Desktop freigeben
        $currentProcess = $null
    }
})

$hostBorder.Add_SizeChanged({
    if ($currentHost) {
        $w = [int]$hostBorder.ActualWidth
        $h = [int]$hostBorder.ActualHeight
        $currentHost.Resize($w, $h)
    }
})

$window.Add_Closing({
    if ($currentProcess -and -not $currentProcess.HasExited) {
        $currentProcess.Kill()
    }
})

$window.ShowDialog() | Out-Null
```

---

### Lösungsansatz C: Multi-Tab-Modus mit TabControl

Eine Erweiterung von Ansatz B: Mehrere externe Anwendungen werden simultan gehosted und über ein `TabControl` als Tabs dargestellt — ähnlich wie NETworkManager es mit PowerShell-Konsolen und PuTTY-Sessions realisiert.

```powershell
# XAML-Erweiterung: TabControl als Host
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Multi-App Host" Height="800" Width="1200">
    <DockPanel>
        <Menu DockPanel.Dock="Top">
            <MenuItem Header="_Neu">
                <MenuItem Name="miNotepad" Header="Notepad++ öffnen"/>
                <MenuItem Name="miKeePass" Header="KeePass öffnen"/>
            </MenuItem>
        </Menu>
        <TabControl Name="tabControl" Background="#1C1C1C"/>
    </DockPanel>
</Window>
"@

# Pro Tab: Ein eigener HwndHost-Container
# Jeder Tab kapselt Prozess-Handle + ExternalAppHost-Instanz
# (Vollimplementierung baut auf Ansatz B auf)
```

**Wichtig beim Multi-Tab-Ansatz:** Wenn ein Tab nicht sichtbar ist, sollte das eingebettete Fenster mit `ShowWindow(hWnd, SW_HIDE)` ausgeblendet werden, da WPF tabs nicht automatisch die Sichtbarkeit des HWND-Inhalts steuert.

---

## 3. Bekannte Einschränkungen & Problemfelder

Dies ist der kritischste Abschnitt der Analyse. Die folgenden Einschränkungen sind teils fundamental und durch das Windows-Betriebssystem bedingt.

### 3.1 UIPI – User Interface Privilege Isolation ⚠️ KRITISCH

**Windows User Interface Privilege Isolation (UIPI)** verhindert, dass Prozesse mit niedrigeren Integritätsstufen Nachrichten an Prozesse mit höheren Integritätsstufen senden. Konkret:

- Wenn **KeePass als Administrator** läuft und das PowerShell-WPF-Fenster **nicht**, schlägt `SetParent()` **lautlos fehl** — kein Fehler, kein Exception, aber kein Einbetten.
- Lösung: Entweder beide Prozesse auf gleichem Integritätslevel ausführen, oder das Host-Skript ebenfalls mit Administratorrechten starten.

```powershell
# Prüfen ob Skript als Admin läuft
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "UIPI: Für Anwendungen mit Administratorrechten ist ein Admin-Start erforderlich!"
}
```

### 3.2 DPI-Skalierung (Multi-Monitor) ⚠️ KRITISCH

Windows leitet `WM_DPICHANGED`-Nachrichten **nicht prozessübergreifend** weiter. Das bedeutet: Wenn das WPF-Hostfenster auf einen Monitor mit 150% DPI verschoben wird, bemerkt das eingebettete externe Fenster diese Änderung nicht automatisch.

**Symptome:**
- Eingebettetes Fenster erscheint versetzt oder in falscher Größe
- Schriften werden unscharf (Bitmap-Skalierung statt natives Rendering)
- Auf Multi-Monitor-Setups (verschiedene DPI per Monitor) besonders ausgeprägt

**Lösungsansatz von NETworkManager (Open Source Referenzimplementierung):**

```csharp
// NETworkManager sendet WM_DPICHANGED manuell nach SetParent
// Quelle: github.com/BornToBeRoot/NETworkManager
private void HandleDpiChanged(double newDpi) {
    if (_childHwnd == IntPtr.Zero) return;
    
    // Neue Größe berechnen und an Child weitergeben
    var rect = new RECT(0, 0, (int)ActualWidth, (int)ActualHeight);
    SendMessage(_childHwnd, WM_DPICHANGED, 
        MakeDpiParam(newDpi), 
        ref rect);
}
```

### 3.3 Window-Style-Kompatibilität

Nicht alle Anwendungen lassen sich problemlos als `WS_CHILD` betreiben:

| Anwendungstyp | Kompatibilität | Anmerkung |
|---|---|---|
| Einfache Win32-Apps (Notepad) | ✅ Gut | Funktioniert zuverlässig |
| .NET WinForms-Apps | ✅ Gut | Meist problemlos |
| Notepad++ | ⚠️ Mittel | Menüleiste kann außerhalb erscheinen, Tab-Bar manchmal problematisch |
| KeePass 2.x (.NET WinForms) | ⚠️ Mittel | Tray-Icon und Sicherheitsdialoge agieren separat |
| Qt-basierte Anwendungen | ⚠️ Mittel | Eigenes Rendering, gelegentliche Z-Order-Probleme |
| WPF-Anwendungen | ⚠️ Schwierig | Eigenes DX-Rendering-Subsystem, kann Konflikte erzeugen |
| Electron/CEF-Apps (VS Code, etc.) | ❌ Problematisch | Chrome-Rendering-Engine ignoriert WS_CHILD korrekt |
| UWP/MSIX-Apps | ❌ Nicht möglich | Sandbox verhindert prozessübergreifendes Window Parenting |

### 3.4 Menüleisten & Top-Level-Elemente

Anwendungen wie Notepad++ oder KeePass haben Menüleisten und Dialoge, die als **Top-Level-Fenster** realisiert sind. Diese können **außerhalb** des WPF-Containers erscheinen, da sie nicht automatisch umgeparentet werden:

- Modale Dialoge (Speichern, Öffnen, Einstellungen) erscheinen als separate Fenster
- Kontextmenüs rendern außerhalb des Containers
- Tray-Icons bleiben unabhängig
- Splash-Screens erscheinen separat beim Start

### 3.5 Rendering-Artefakte (Airspace Problem)

WPF rendert über DirectX, Win32-Fenster rendern über GDI/GDI+. Wenn beide im gleichen Bereich dargestellt werden, entsteht das klassische **WPF Airspace Problem**:

- WPF kann nichts über dem eingebetteten HWND rendern (kein WPF-Overlay)
- Tooltips, Popups oder WPF-Animationen, die über das eingebettete Fenster hinausragen, werden abgeschnitten
- Das externe Fenster sitzt immer **über** allen WPF-Elementen in diesem Bereich

### 3.6 Resize- & Layout-Synchronisation

Das eingebettete Fenster passt sich nicht automatisch an Layout-Änderungen des WPF-Containers an. `SizeChanged`-Events müssen manuell abonniert und `MoveWindow` aufgerufen werden:

```powershell
$hostBorder.Add_SizeChanged({
    param($sender, $e)
    if ($null -ne $script:currentHost) {
        $w = [Math]::Max(1, [int]$e.NewSize.Width)
        $h = [Math]::Max(1, [int]$e.NewSize.Height)
        $script:currentHost.Resize($w, $h)
    }
})
```

### 3.7 Prozess-Lifecycle-Management

Wird das WPF-Hostfenster geschlossen ohne den eingebetteten Prozess vorher zu beenden, kann der externe Prozess als **Zombie-Prozess** im Hintergrund weiterlaufen:

```powershell
$window.Add_Closing({
    param($sender, $cancelArgs)
    # Alle eingebetteten Prozesse korrekt beenden
    foreach ($proc in $script:embeddedProcesses) {
        if (-not $proc.HasExited) {
            try { $proc.CloseMainWindow() | Out-Null }
            catch { $proc.Kill() }
        }
    }
})
```

### 3.8 Focus- & Input-Probleme

Prozessübergreifende Fokuswechsel erfordern `AttachThreadInput`, was weitere Komplexität einführt und in bestimmten Konstellationen zu Input-Loop-Hänger führen kann:

```csharp
// Manchmal notwendig für korrekte Fokus-Weiterleitung
[DllImport("user32.dll")]
static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
```

---

## 4. Praxisnahe Referenzimplementierung: NETworkManager

**NETworkManager** (Open Source, GitHub: `BornToBeRoot/NETworkManager`) ist das bekannteste und am ausgereiftesten Beispiel dieser Technik in .NET/WPF. Es bettet **PowerShell-Konsolen** und **PuTTY-SSH-Sessions** als Tabs in eine WPF-Anwendung ein.

Die wichtigsten Erkenntnisse aus dem NETworkManager-Quellcode:

1. **Separate DPI-Behandlung** für Konsol-Hosts (Console API) vs. GUI-Prozesse (WM_DPICHANGED)
2. **Robustes SizeChanged-Handling** mit Debouncing zur Vermeidung von Resize-Flimmern
3. **Tab-Visibility-Management:** Verstecke HWND-Inhalte bei nicht-aktivem Tab via `ShowWindow(SW_HIDE/SW_SHOW)`
4. **Retry-Logik** beim Warten auf das Hauptfenster (nicht alle Apps sind nach `WaitForInputIdle` bereit)

**Relevante Quelldatei:** `NETworkManager/Controls/PowerShellControl.xaml.cs` auf GitHub

---

## 5. PowerShell-spezifische Besonderheiten

### 5.1 Add-Type und Kompilierungsoverhead

Jeder `Add-Type`-Aufruf mit C#-Quellcode kompiliert zur Laufzeit. Bei umfangreichen P/Invoke-Definitionen empfiehlt sich:

```powershell
# Kompiliertes Assembly cachen (einmal pro Session)
if (-not ([System.Management.Automation.PSTypeName]'Win32Interop').Type) {
    Add-Type -TypeDefinition $win32Source -ReferencedAssemblies "PresentationFramework","WindowsBase"
}
```

### 5.2 STA-Thread-Anforderung

WPF-Anwendungen in PowerShell **müssen** im **Single-Threaded Apartment (STA)** laufen. Beim Start von `powershell.exe` ist STA der Standard; bei `pwsh.exe` (PowerShell 7) muss es explizit angegeben werden:

```powershell
# Für PowerShell 7 / pwsh.exe:
# Starten mit: pwsh.exe -STA -File ".\MeinSkript.ps1"

# Oder im Skript prüfen:
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne "STA") {
    Write-Error "Dieses Skript erfordert STA-Modus. Starte mit: pwsh -STA"
    exit 1
}
```

### 5.3 Timing beim Prozessstart

Verschiedene Anwendungen benötigen unterschiedlich lange bis ihr Hauptfenster verfügbar ist. `WaitForInputIdle()` ist nicht immer ausreichend:

```powershell
function Wait-ForMainWindow {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutMs = 10000
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
        if ($stopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
            throw "Timeout: Hauptfenster nicht gefunden nach ${TimeoutMs}ms"
        }
        Start-Sleep -Milliseconds 100
        $Process.Refresh()
    }
    Start-Sleep -Milliseconds 300  # Zusätzlicher Buffer für vollständiges Rendering
    return $Process.MainWindowHandle
}
```

### 5.4 Handle-Abruf aus WPF-Elementen

Nicht jedes WPF-Element hat ein eigenes HWND. `HwndSource.FromVisual()` liefert nur dann ein gültiges Handle, wenn das Element bereits im Visual Tree dargestellt wird:

```powershell
# FALSCH: Vor dem Window.Show() aufrufen → liefert $null
$hwndSource = [System.Windows.Interop.HwndSource]::FromVisual($myBorder)

# RICHTIG: Im Loaded-Event oder nach ShowDialog() aufrufen
$myBorder.Add_Loaded({
    $hwndSource = [System.Windows.Interop.HwndSource]::FromVisual($myBorder)
    if ($hwndSource) { $parentHwnd = $hwndSource.Handle }
})
```

---

## 6. Sicherheitsaspekte

| Aspekt | Risiko | Maßnahme |
|---|---|---|
| Prozessrechte (UIPI) | Hoch | Rechte-Level beider Prozesse angleichen |
| Code-Injection-Vektoren | Mittel | `SetWindowLong` kann für Manipulation missbraucht werden — nur vertrauenswürdige Targets |
| Prozess-Isolation | Mittel | Externer Prozess läuft unkontrolliert; Absturz beeinflusst nicht den Host |
| Datenweitergabe | Niedrig | Keine implizite Datenweitergabe durch HWND-Parenting |
| Antivirus / EDR | Mittel | P/Invoke + Prozessmanipulation kann Heuristiken triggern |

---

## 7. Empfehlungen & Fazit

### 7.1 Wann ist der Ansatz sinnvoll?

✅ **Geeignet für:**
- Administrative Toolsuiten (z. B. SSH-Client + Notepad-Editor in einem Fenster)
- IT-Operations-Dashboards mit eingebetteten Konsolen
- Entwicklungsumgebungen mit mehreren integrierten Tools
- Proof-of-Concepts und interne Werkzeuge

❌ **Nicht geeignet für:**
- Sicherheitskritische Anwendungen (KeePass-Passworte in eingebettetem Modus riskant)
- Produktionsumgebungen mit strengen UAC/UIPI-Regeln
- UWP-Apps oder moderne Store-Anwendungen (technisch unmöglich)
- Anwendungen mit starkem visuellen Overlay-Bedarf

### 7.2 Entwicklungsreihenfolge (Empfehlung)

1. **Phase 1:** Direktes `SetParent` mit einem einfachen Prozess (Notepad.exe) testen
2. **Phase 2:** `HwndHost`-Klasse implementieren und in WPF integrieren
3. **Phase 3:** DPI-Handling und `SizeChanged`-Events implementieren
4. **Phase 4:** Multi-Tab-Support mit Prozess-Lifecycle-Management
5. **Phase 5:** Fehlerbehandlung, Logging und Absicherung gegen UIPI

### 7.3 Gesamtbewertung

| Kriterium | Bewertung |
|---|---|
| **Technische Machbarkeit** | ✅ Möglich (nachgewiesen durch NETworkManager u.a.) |
| **Implementierungsaufwand** | ⚠️ Mittel-Hoch (P/Invoke, Threading, DPI-Handling) |
| **Stabilität** | ⚠️ Mittel (abhängig von Zielanwendung) |
| **Offizielle Unterstützung** | ❌ Nicht offiziell von Microsoft dokumentiert/empfohlen |
| **PowerShell-Tauglichkeit** | ✅ Gut umsetzbar via Add-Type + HwndHost |
| **Langzeitstabilität** | ⚠️ Windows-Update könnte Verhalten ändern |

Das Konzept ist **machbar und in der Praxis erprobt**, erfordert aber ein solides Verständnis der Win32-Fenster-Hierarchie und WPF-Interop. Für interne Tools und Prototypen ist es ein hervorragender Ansatz; für kritische Produktionsumgebungen sollten die Einschränkungen sorgfältig abgewogen werden.

---

## 8. Weiterführende Ressourcen

- **Microsoft Docs:** [WPF and Win32 Interoperation](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/wpf-and-win32-interoperation)
- **Microsoft Docs:** [Walkthrough: Hosting a Win32 Control in WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/walkthrough-hosting-a-win32-control-in-wpf)
- **NETworkManager (GitHub):** [BornToBeRoot/NETworkManager](https://github.com/BornToBeRoot/NETworkManager) — Referenzimplementierung für eingebettete Konsolen
- **Stack Overflow:** [Embed Window from another application in WPF](https://stackoverflow.com/questions/4608130)
- **BornToBeRoot Blog:** [Fixing DPI Scaling for Embedded Processes in WPF](https://borntoberoot.net/NETworkManager/blog/deep-dive-fixing-dpi-scaling-for-embedded-processes-in-wpf)
- **Win32 API Docs:** [SetParent function (winuser.h)](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setparent)

