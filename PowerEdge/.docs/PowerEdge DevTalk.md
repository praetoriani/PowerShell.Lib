<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

## Was ist PowerEdge?

PowerEdge (v1.00.02) ist eine WPF-basierte Host-Anwendung, geschrieben in PowerShell, die einen Microsoft Edge WebView2-Browser in ein rahmenloses WPF-Fenster einbettet . Das Ziel: lokale HTML-Dateien (oder beliebige URLs) als vollwertige Desktop-App präsentieren, ohne einen sichtbaren Browser zu öffnen. Es ist quasi ein „PowerShell-eigener Electron-Ersatz" auf Basis von WebView2.

Die wichtigsten Kernbestandteile sind :

- `PowerEdge.ps1` – das Hauptskript, das Parameter verarbeitet, Assemblies lädt und den UI-Runspace startet
- `data/fxlib/` – externe Funktionsbibliotheken (`LoadURL.ps1`, `LoadURLafter.ps1`, `LoadWebViewDLLs.ps1`, `LoadXAMLui.ps1`, `ResolveHttpRoot.ps1`, `NewStatusObject.ps1`)
- `data/config.json` – Pfad-Konfiguration für GUI, WebApp-Verzeichnis, Lib-Verzeichnis usw.
- `data/ui/` – XAML-Datei für das Hauptfenster

***

## Die Parameter `-Hidden` und `-Timeout` im Detail

Der aktuelle Code verarbeitet `-Hidden` und `-Timeout` bereits vollständig im UI-Runspace . Der relevante Block lautet:

```powershell
if ($syncHash.Hidden -eq $true -and $syncHash.Timeout -gt 0) {
    $window.Visibility = [System.Windows.Visibility]::Hidden
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($syncHash.Timeout)
    $capturedWindow = $window
    $capturedTimer  = $timer
    $timer.Add_Tick({
        $capturedWindow.Visibility = [System.Windows.Visibility]::Visible
        $capturedWindow.Activate()
        $capturedWindow.Focus()
        $capturedTimer.Stop()
    })
    $timer.Start()
}
```

**Was passiert dabei konkret:**

1. Das Fenster wird sofort auf `Hidden` gesetzt – es ist unsichtbar, aber die WPF-Instanz läuft im Hintergrund
2. Ein `DispatcherTimer` mit dem angegebenen Timeout startet
3. Nach Ablauf des Timers wird das Fenster auf `Visible` gesetzt und in den Fokus gebracht

***

## `LoadURLafter` – wie die Funktion arbeitet

`LoadURLafter` ist eine separate Funktion in `data/fxlib/LoadURLafter.ps1` . Sie nimmt drei Parameter entgegen:

- `$WebView` – das WebView2-Control-Objekt
- `$URL` – Ziel-URL oder lokaler Dateipfad
- `$DelayMs` – Verzögerung in Millisekunden

Intern erstellt sie ebenfalls einen `DispatcherTimer`, der nach `$DelayMs` Millisekunden `CoreWebView2.Navigate($targetUri)` aufruft und sich dann selbst stoppt . Sie ist also **nicht an die `-Hidden`/`-Timeout`-Logik gekoppelt** – sie ist eine eigenständige Funktion, die man manuell aufrufen muss.

***

## Analyse deines Szenarios

Du beschreibst folgendes Vorhaben:

> 1. `LoadURLafter` wird am Ende des Programmstarts aufgerufen, mit einem Timeout von **5 Sekunden**
> 2. Wenn `-Hidden` erkannt wird, wird für die Dauer von `-Timeout` ein XAML-Dialog angezeigt mit „Bitte warten. Das Programm wird geladen"
> 3. Start mit `-Hidden -Timeout 6000`

**Deine Schlussfolgerung:** Während des versteckten Starts erscheint der Hinweis-Dialog, und nach 6 Sekunden wird das Fenster mit der URL aus `LoadURLafter` angezeigt.

Das klingt zunächst logisch, aber es gibt **mehrere kritische Punkte**, die du bedenken musst:

***

## ⚠️ Problem 1: Zwei Timer mit unterschiedlichen Laufzeiten laufen parallel

Du hast:

- **`LoadURLafter`-Timer**: 5.000 ms → navigiert zur neuen URL
- **`-Timeout`-Timer** (im Hauptcode): 6.000 ms → macht das Fenster sichtbar

Das bedeutet: Die Navigation zur neuen URL **findet 1 Sekunde statt, bevor das Fenster überhaupt sichtbar wird**. Das ist technisch kein Fehler, aber du solltest dir bewusst sein, dass der WebView2 die URL bereits im Hintergrund lädt, noch während das Fenster verborgen ist. In der Praxis ist das sogar ein **Vorteil** (die Seite ist beim Erscheinen des Fensters bereits geladen), aber es entspricht nicht der intuitiven Erwartung „zuerst sichtbar, dann URL laden".

***

## ⚠️ Problem 2: Wo und wie wird `LoadURLafter` aufgerufen?

`LoadURLafter` ist eine Funktion aus der `fxlib`, die per Dot-Sourcing im **Haupt-Runspace** (außerhalb des UI-Runspace) geladen wird . Das UI hingegen läuft in einem **separaten STA-Runspace**. Das bedeutet:

- Du **kannst `LoadURLafter` nicht einfach am Ende des Hauptskripts aufrufen**, weil das `$webView`-Objekt nur innerhalb des UI-Runspace existiert.
- `LoadURLafter` benötigt das `$webView`-Objekt als Parameter – dieses ist nach dem `$window.ShowDialog()`-Aufruf im UI-Runspace gebunden und nicht direkt von außen zugänglich.
- **Du müsstest den Aufruf von `LoadURLafter` innerhalb des `$uiScript`-Blocks platzieren**, zum Beispiel im `Add_Loaded`-Event-Handler oder nach der erfolgreichen `CoreWebView2InitializationCompleted`-Initialisierung.

Der korrekte Ort wäre innerhalb des `Add_CoreWebView2InitializationCompleted`-Callbacks:

```powershell
$webView.Add_CoreWebView2InitializationCompleted({
    param($sender, $e)
    if ($e.IsSuccess) {
        $fileUri = [System.Uri]::new($syncHash.HtmlPath)
        $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)
        if ($null -ne $loadingOverlay) { $loadingOverlay.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($null -ne $statusText)     { $statusText.Text = "Ready" }

        # LoadURLafter HIER aufrufen – WebView2 ist initialisiert, $webView verfügbar
        $afterResult = LoadURLafter -WebView $webView -URL "https://deine-url.de" -DelayMs 5000
    }
})
```


***

## ⚠️ Problem 3: Der XAML-Warndialog und Sichtbarkeit

Du möchtest, dass **während des Hidden-Starts ein XAML-Dialog** erscheint. Hier gibt es einen fundamentalen Widerspruch: Das Fenster selbst ist auf `Hidden` gesetzt. Ein Dialog, der **als Child** des Hauptfensters erstellt wird (z. B. via `Window.ShowDialog()` oder als XAML-`Window`), erbt die Sichtbarkeit nicht zwingend – er könnte trotzdem erscheinen.

Wenn du ein separates `Window`-Objekt (ohne Parent-Referenz auf das versteckte Hauptfenster) erstellst und `ShowDialog()` darauf aufrufst, **wird dieses sichtbar**, auch wenn das Hauptfenster `Hidden` ist. Das ist sogar dein gewünschtes Verhalten. Allerdings musst du darauf achten:

- Der Dialog muss auf dem **gleichen STA-Thread** (dem UI-Runspace) laufen
- Da `ShowDialog()` blockierend ist, müsste der Dialog als **nicht-blockierendes Window** (`Show()` statt `ShowDialog()`) oder als **DispatcherTimer-gesteuerter Overlay** innerhalb des bestehenden Fensters realisiert werden
- Eine einfachere Alternative: Du fügest dem bestehenden Hauptfenster ein `Grid`-Overlay mit dem „Bitte warten"-Text hinzu (ähnlich dem vorhandenen `LoadingOverlay`-Element), das sichtbar ist, während das Fenster selbst nach `Visible` wechselt

***

## ⚠️ Problem 4: Timing-Kette und Race Conditions

Das Gesamttiming deines Szenarios sieht so aus:


| Zeitpunkt | Ereignis |
| :-- | :-- |
| 0 ms | Start, Fenster auf `Hidden`, beide Timer starten |
| 5.000 ms | `LoadURLafter`-Timer feuert → Navigation zur neuen URL |
| 6.000 ms | `-Timeout`-Timer feuert → Fenster wird `Visible` |

Das funktioniert, **wenn** `LoadURLafter` innerhalb des UI-Runspace aufgerufen wird und `CoreWebView2` zu diesem Zeitpunkt bereits vollständig initialisiert ist. Da die WebView2-Initialisierung asynchron läuft (`EnsureCoreWebView2Async`), muss sichergestellt sein, dass der `CoreWebView2InitializationCompleted`-Callback bereits gefeuert hat, bevor der `LoadURLafter`-Timer nach 5 Sekunden versucht, `CoreWebView2.Navigate()` aufzurufen. In der Praxis ist das bei lokalen HTML-Dateien innerhalb von Sekunden der Fall – aber eine explizite Null-Prüfung auf `$WebView.CoreWebView2` (die in `LoadURLafter` bereits eingebaut ist ) schützt dich hier.

***

## Zusammenfassung: Ist deine Idee korrekt?

**Grundsätzlich ja – das Konzept ist stimmig**, aber du übersieht drei Dinge:

1. **`LoadURLafter` muss zwingend innerhalb des UI-Runspace (im `$uiScript`-Block) aufgerufen werden**, nicht im Hauptskript, da das `$webView`-Objekt nur dort existiert.
2. **Der XAML-Warndialog muss als `Show()` (nicht `ShowDialog()`) oder als Overlay im bestehenden Fenster** realisiert werden, um die UI-Schleife nicht zu blockieren – sonst friert die gesamte WPF-Oberfläche ein.
3. **Die Timing-Reihenfolge ist sinnvoll** (URL-Laden vor dem Einblenden), aber du solltest dir bewusst sein, dass die URL bereits 1 Sekunde vor der Fenstersichtbarkeit geladen wird – das ist in deinem Fall sogar erwünscht (kein weißes Flackern beim Einblenden).

***

<div align="center">⁂</div>

***

## Frage 1 — Das Logo oben links (TitleBarLogo)

**Ja, das ist die `PowerEdge.ico`-Datei.** Im XAML ist das Element wie folgt definiert :

```xml
<Image x:Name="TitleBarLogo"
       Width="20" Height="20"
       VerticalAlignment="Center"
       RenderOptions.BitmapScalingMode="HighQuality"/>
```

Die `Source` wird **nicht** im XAML gesetzt, sondern dynamisch in `PowerEdge.ps1` per PowerShell zur Laufzeit zugewiesen :

```powershell
if ($null -ne $titleBarLogo -and (Test-Path -LiteralPath $syncHash.AppIcon)) {
    $titleBarLogo.Source = [System.Windows.Media.Imaging.BitmapImage]::new(
        [System.Uri]::new($syncHash.AppIcon)
    )
}
```

Dabei zeigt `$syncHash.AppIcon` auf `$global:AppIcon = Join-Path $PSScriptRoot "PowerEdge.ico"`.

### Größer machen

Ja, ganz einfach. Du musst nur `Width` und `Height` im XAML erhöhen. Aktuell ist es `20×20`. Wenn du es z. B. auf `28×28` oder `32×32` setzt, wird das Icon größer dargestellt:

```xml
<Image x:Name="TitleBarLogo"
       Width="32" Height="32"
       VerticalAlignment="Center"
       RenderOptions.BitmapScalingMode="HighQuality"/>
```

Beachte: Der TitleBar hat eine fixe Höhe von `40px` , also sollte das Icon nicht größer als ca. `30×30` sein, damit es nicht abgeschnitten wird.

### SVG-Datei an dieser Stelle verwenden?

**Leider nicht direkt** — das ist eine wichtige Einschränkung von WPF. Das `<Image>`-Element in WPF unterstützt nativ **keine SVG-Dateien**. WPF kann nur folgende Bildformate direkt laden: BMP, PNG, JPG, GIF, TIFF, ICO und WDP (Windows Media Photo). SVG ist kein natives WPF-Format.

Es gibt jedoch **zwei Wege**, SVG trotzdem zu nutzen:

1. **SVG zu PNG/ICO konvertieren** (einfachste Lösung): Du wandelst dein SVG mit einem Tool (z. B. Inkscape, ImageMagick oder einem Online-Konverter) in eine `.png`- oder `.ico`-Datei um. Da du ohnehin eine `PowerEdge.ico` hast, wäre es ideal, das SVG in ein hochauflösendes Multi-Size-ICO zu konvertieren (16×16, 32×32, 64×64, 256×256 alle in einer `.ico`-Datei).
2. **SharpVectors NuGet-Bibliothek** (für „echtes" SVG in WPF): Es gibt die Bibliothek [SharpVectors (SVG\#)](https://github.com/ElinamLLC/SharpVectors), die SVG-Rendering in WPF ermöglicht. Du würdest die DLL in `data\lib\` ablegen und dann im XAML einen eigenen Namespace nutzen. Das ist deutlich aufwändiger und für ein kleines Logo-Icon meist übertrieben.

**Empfehlung**: Konvertiere dein SVG zu einer mehrstufigen `.ico`-Datei. Das ist die sauberste und aufwandsärmste Lösung.

***

## Frage 2 — Der zentrierte Text „PowerEdge" in der Titelleiste

Dieser Text wird an **zwei Stellen** gesetzt:

### Im XAML (Standardwert)

Das Element im XAML heißt `TitleBarText` und hat einen fest eingetragenen Standardtext :

```xml
<TextBlock x:Name="TitleBarText"
           Grid.Column="1"
           Text="PowerEdge"
           Foreground="{StaticResource BrushTextMuted}"
           FontFamily="Segoe UI"
           FontSize="12"
           FontWeight="Normal"
           HorizontalAlignment="Center"
           VerticalAlignment="Center"/>
```

Das ist der Text, den du im Screenshot siehst. Er steht in der mittleren Spalte des `TitleBarPanel`-Grids (3 Spalten: Logo | Titel | Buttons) und ist bewusst zentriert und in einem gedimmten `BrushTextMuted` (\#888888) gehalten.

### Zur Laufzeit (dynamisch aus PowerShell)

In `PowerEdge.ps1` wird dieser Text zur Laufzeit überschrieben :

```powershell
$titleBar = $window.FindName("TitleBarText")
...
if ($null -ne $titleBar) { $titleBar.Text = $syncHash.WindowTitle }
```

`$syncHash.WindowTitle` wiederum kommt vom `-WindowTitle`-Parameter beim Programmstart. Wenn du das Skript mit `-WindowTitle "Mein Titel"` startest, steht dort „Mein Titel". Ohne den Parameter greift der Standardwert `"PowerEdge"`.

Du kannst den zentrierten Titel also jederzeit anpassen, ohne den XAML-Code zu ändern — einfach per Parameter beim Start:

```powershell
.\PowerEdge.ps1 -WindowTitle "Mein Projekt Dashboard"
```


***

## Frage 3 — Das `⊕`-Symbol beim Verschieben des Fensters

### Was ist das?

Das Symbol `⊕` (ein weißes Kreuz in einem Kreis) ist der **Windows-Systemcursor für „Fenster verschieben"** — der sogenannte `SizeAll`-Cursor. Es ist kein Icon aus deinem Projekt, sondern ein **Standard-Windows-Cursor**, der aktiviert wird, wenn die Maus über die Titelleiste fährt.

### Wo ist das im Code definiert?

Direkt im XAML, am `TitleBarPanel`-Grid :

```xml
<Grid x:Name="TitleBarPanel"
      Background="Transparent"
      Cursor="SizeAll">
```

Das `Cursor="SizeAll"` weist WPF an, den Verschiebe-Cursor über dem gesamten TitleBar-Bereich anzuzeigen. Das ist eine bewusste Design-Entscheidung: Sie gibt dem Nutzer visuelles Feedback, dass er das Fenster an dieser Stelle anfassen und verschieben kann.

### Kann man einen anderen Cursor verwenden?

**Ja, absolut.** In WPF gibt es eine ganze Reihe eingebauter Cursor. Du musst nur den Wert von `Cursor` im XAML ändern:


| Cursor-Wert | Aussehen / Zweck |
| :-- | :-- |
| `Arrow` | Standard-Pfeilcursor (kein spezieller Hinweis) |
| `Hand` | Zeigefinger (wie bei Links) |
| `SizeAll` | Das `⊕`-Symbol (aktuell verwendet) |
| `ScrollAll` | Ähnlich wie SizeAll, aber für Scroll-Kontext |
| `None` | Cursor wird unsichtbar |

Wenn du einfach den normalen Pfeil-Cursor möchtest (kein besonderes Symbol beim Hovern), änderst du es einfach zu:

```xml
<Grid x:Name="TitleBarPanel"
      Background="Transparent"
      Cursor="Arrow">
```


### Einen komplett eigenen Cursor verwenden

Du kannst auch eine eigene `.cur`- oder `.ani`-Cursor-Datei verwenden:

```xml
<Grid x:Name="TitleBarPanel"
      Background="Transparent">
    <Grid.Cursor>
        <Cursor>data\assets\mycursor.cur</Cursor>
    </Grid.Cursor>
</Grid>
```

Alternativ kann der Cursor auch zur Laufzeit per PowerShell gesetzt werden:

```powershell
$titleBarPanel = $window.FindName("TitleBarPanel")
$titleBarPanel.Cursor = [System.Windows.Input.Cursors]::Arrow
```

Das gibt dir maximale Flexibilität, ohne den XAML-Code zu verändern.

***

<div align="center">⁂</div>

***

## Thema 1 — `localserver.ps1` in PowerEdge integrieren

### Was kann `localserver.ps1`?

Die `localserver.ps1` definiert eine vollständige PowerShell-Klasse `[LocalServer]`, die einen .NET-`HttpListener` kapselt . Sie läuft in einem **eigenen MTA-Runspace** (Background-Thread) und **blockiert den aufrufenden Thread nicht**. Unterstützte Features :

- Static-File-Serving mit MIME-Typ-Erkennung (HTML, CSS, JS, JSON, Bilder, Fonts, Video, Audio, Archive, PWA-Manifeste)
- **SPA-Fallback** (unbekannte Routen → `index.html`) für React, Angular, Vue usw.
- Optionales Directory-Listing
- Pfad-Traversal-Guard (Sicherheit: niemand kann Dateien außerhalb des Web-Roots laden)
- Custom-Response-Header (Standard: Security-Header wie `X-Frame-Options`)
- Graceful Start/Stop-Lifecycle mit `CancellationTokenSource`


### Warum überhaupt einen lokalen HTTP-Server?

Ohne lokalen Server lädt WebView2 HTML-Dateien per `file:///`-Protokoll. Das hat einen gravierenden Nachteil: **Browser und WebView2 erzwingen für `file://`-URLs strikte CORS-Restriktionen**. Das bedeutet konkret:

- Kein `fetch()` zu anderen lokalen Dateien
- Keine ES6-Modules (`import`/`export`) aus lokalen Dateien
- Kein Laden von Web Fonts via `@font-face` aus dem lokalen Dateisystem
- Keine PWA-Features (`ServiceWorker`, `manifest.json`)
- SPAs (React, Angular, Vue) funktionieren **nicht** über `file://`, da ihr Client-Side-Router Pfade wie `/about` oder `/dashboard` erwartet

Mit `http://localhost:PORT/` laufen alle diese Szenarien einwandfrei.

### Schritt-für-Schritt-Integration

Der `[LocalServer]` läuft in einem **MTA-Runspace** (Multi-Threaded Apartment), während der WPF-UI-Runspace **STA** (Single-Threaded Apartment) benötigt . Die beiden Runspaces sind vollständig getrennt. Das ist kein Problem, da der Server nur HTTP bedient und nichts direkt mit WPF interagiert.

**Schritt 1: `localserver.ps1` dot-sourcen**

In `PowerEdge.ps1`, direkt nach dem bestehenden `fxlib`-Dot-Sourcing-Block:

```powershell
# Bestehender Block (bereits vorhanden):
$fxLibPath = Join-Path $PSScriptRoot "data\fxlib"
Get-ChildItem -Path $fxLibPath -Filter "*.ps1" | ForEach-Object { . $_.FullName }

# NEU — LocalServer-Klasse laden:
$localServerScript = Join-Path $PSScriptRoot "data\core\localserver.ps1"
if (Test-Path $localServerScript) {
    try { . $localServerScript }
    catch { Write-Error "PowerEdge: Failed to load localserver.ps1: $($_.Exception.Message)"; exit 1 }
}
```

**Schritt 2: Parameter ergänzen**

Oben im `param()`-Block neue optionale Parameter hinzufügen:

```powershell
[Parameter(Mandatory = $false)]
[switch]$UseLocalServer,

[Parameter(Mandatory = $false)]
[int]$ServerPort = 8080,

[Parameter(Mandatory = $false)]
[string]$WebRoot = ""
```

**Schritt 3: Server vor dem UI-Runspace starten**

Nach der Parametervalidierung und vor dem `$syncHash`-Block:

```powershell
$global:LocalServer = $null

if ($UseLocalServer) {
    $webRootPath = if ($WebRoot) { $WebRoot } else { Join-Path $PSScriptRoot "data\web" }
    try {
        $global:LocalServer = [LocalServer]::new($webRootPath, "http://localhost:$ServerPort/")
        $global:LocalServer.SpaFallback = $true
        $global:LocalServer.Start()
        Write-Verbose "PowerEdge: LocalServer started on http://localhost:$ServerPort/"
        # httpRoot auf localhost umbiegen
        $resolvedHtmlPath = "http://localhost:$ServerPort/index.html"
    }
    catch {
        Write-Error "PowerEdge: Failed to start LocalServer: $($_.Exception.Message)"; exit 1
    }
}
```

**Schritt 4: Server beim Schließen des Fensters stoppen**

Im `$uiScript`-Block, nach dem `$window.Add_Loaded`-Block:

```powershell
$window.Add_Closed({
    # Server sauber herunterfahren, wenn das Fenster geschlossen wird
    if ($null -ne $using:global:LocalServer -and $using:global:LocalServer.IsRunning()) {
        $using:global:LocalServer.Stop()
    }
})
```

Da `$global:LocalServer` im Haupt-Runspace lebt und der `Closed`-Event im UI-Runspace feuert, muss es über den `syncHash` übergeben werden:

```powershell
$syncHash = [hashtable]::Synchronized(@{
    ...
    LocalServer = $global:LocalServer   # NEU
    ...
})
```

Und im `$uiScript`:

```powershell
$window.Add_Closed({
    if ($null -ne $syncHash.LocalServer -and $syncHash.LocalServer.IsRunning()) {
        $syncHash.LocalServer.Stop()
    }
})
```

**Startbeispiel für eine Angular/React-App:**

```powershell
.\PowerEdge.ps1 -UseLocalServer -ServerPort 4200 -WebRoot "C:\MeinProjekt\dist\my-app"
```


***

## Thema 2 — Dot-Sourcing vs. Modul vs. Klassen-Datei

Das ist eine der wichtigsten Architekturentscheidungen für PowerShell-Projekte. Hier ein vollständiger Vergleich:

### Vergleich der drei Ansätze

| Kriterium | Einzelne `.ps1`-Dateien (aktuell) | `PowerEdge.Core`-Modul (`.psm1`/`.psd1`) | `PowerEdge.Core.ps1` mit Klasse |
| :-- | :-- | :-- | :-- |
| **Einfachheit** | ✅ Sehr einfach, kein Overhead | ⚠️ Erfordert `.psd1`-Manifest | ✅ Eine einzelne Datei |
| **Portabilität** | ✅ Alles liegt im Projektordner | ⚠️ Modul muss installiert oder mit Pfad geladen werden | ✅ Eine Datei, selbstständig |
| **Isolation / Namespace** | ❌ Funktionen landen im globalen Scope | ✅ Modul-Scope, kein Namespace-Konflikt | ✅ Klassen-Scope isoliert Methoden |
| **IntelliSense / Tab-Completion** | ❌ Keine Typinformationen | ✅ Volle Unterstützung in VS Code mit PowerShell Extension | ✅ Bei Methoden-Aufruf via `[Klasse]::` |
| **Testbarkeit (Pester)** | ⚠️ Nur mit Dot-Sourcing des Testcodes | ✅ `Import-Module` in Pester-Tests | ✅ Klasse direkt testbar |
| **Versionierung** | ❌ Keine eingebaute Versionierung | ✅ Version im `.psd1`-Manifest | ❌ Nur Kommentar im Code |
| **Runspace-Kompatibilität** | ✅ Dot-Sourcing im Runspace möglich | ⚠️ `Import-Module` in neuem Runspace nötig | ✅ Klasse muss im Runspace neu geladen werden |
| **Deployment-Komplexität** | ✅ Einfach: Ordner kopieren | ⚠️ Modul-Pfad registrieren oder `$env:PSModulePath` anpassen | ✅ Eine Datei kopieren |
| **Übersichtlichkeit bei Wachstum** | ❌ Viele lose Dateien | ✅ Klare Struktur durch `Public/Private/Classes` | ⚠️ Klasse wird mit wachsenden Methoden groß |

### Empfehlung für PowerEdge

PowerEdge ist eine **eigenständige, portable Desktop-Anwendung** — sie soll funktionieren, indem man den Projektordner kopiert, ohne vorher etwas installieren zu müssen. Das spricht **gegen** ein echtes PowerShell-Modul im klassischen Sinne (Installation in `$env:PSModulePath`).

Der **beste Mittelweg** ist tatsächlich dein dritter Vorschlag — eine `PowerEdge.Core.ps1` mit einer eigenen Klasse — aber mit einer wichtigen Nuance:

```powershell
# data\core\PowerEdge.Core.ps1

class PowerEdgeCore {

    # ── Path-Resolution ──────────────────────────────────────────────────
    static [PSCustomObject] ResolveHttpRoot([string]$InputPath) { ... }

    # ── WebView2-DLL-Loading ──────────────────────────────────────────────
    static [PSCustomObject] LoadWebViewDLLs([string]$LibDir) { ... }

    # ── XAML-Loading ──────────────────────────────────────────────────────
    static [PSCustomObject] LoadXAMLui([string]$XamlFilePath) { ... }

    # ── URL-Navigation ────────────────────────────────────────────────────
    static [PSCustomObject] LoadURL([object]$WebView, [string]$URL) { ... }
    static [PSCustomObject] LoadURLafter([object]$WebView, [string]$URL, [int]$DelayMs) { ... }

    # ── Status-Helper ─────────────────────────────────────────────────────
    static [PSCustomObject] NewStatusObject([int]$Code, [string]$Msg) { ... }
}
```

**Warum `static`?** Da du keine Instanz von `PowerEdgeCore` benötigst (kein zustandsbehaftetes Objekt), sind `static`-Methoden ideal. Aufruf dann direkt via `[PowerEdgeCore]::ResolveHttpRoot($path)` — kein `New-Object`, kein Dot-Sourcing nötig.

**Das Problem mit PowerShell-Klassen und Runspaces** ist jedoch wichtig: Wenn du eine Klasse im Haupt-Runspace via Dot-Sourcing lädst, ist sie im STA-UI-Runspace **nicht verfügbar** — Klassen leben nicht im `SessionStateProxy`, sondern im Parse-Context. Du müsstest die Datei auch im `$uiScript`-Block erneut dot-sourcen:

```powershell
$uiScript = {
    . "$using:PSScriptRoot\data\core\PowerEdge.Core.ps1"
    # Ab jetzt steht [PowerEdgeCore] zur Verfügung
    ...
}
```

Das ist kein großes Problem — es ist nur wichtig, es zu wissen.

***

## Thema 3 — VPDLX-Integration in PowerEdge

### Was ist VPDLX?

VPDLX (Virtual PowerShell Data-Logger eXtension) ist dein eigenes PowerShell-Modul für In-Memory-Logging mit Export-Funktion . Es verwendet eine `[Logfile]`-Klasse mit Methoden wie `.Info()`, `.Warn()`, `.Error()` und kann Logs in txt, csv, json, html und ndjson exportieren. Die Architektur ist vollständig klassen-basiert mit einem `FileStorage`-Singleton und TypeAccelerators.

### Passt VPDLX zu PowerEdge?

**Ja, sehr gut sogar.** PowerEdge hat aktuell kein Logging-System — Fehler gehen via `Write-Error`/`Write-Warning` in die Konsole (die direkt beim Start versteckt wird). VPDLX würde das lösen: Alle Events (Start, Navigation, Fehler, Server-Status) könnten in einem virtuellen Log gesammelt und bei Bedarf in eine Datei exportiert werden.

### Integrationskonzept

Die Herausforderung ist dieselbe wie bei der Klasse: VPDLX muss in **beiden Runspaces** (Haupt-Runspace und STA-UI-Runspace) verfügbar sein, da Events wie `CoreWebView2InitializationCompleted` im UI-Runspace feuern.

**Schritt 1: VPDLX-Modulpfad in `config.json` eintragen**

```json
{
  "appcore": {
    ...
    "vpdlxpath": "..\\..\\VPDLX"
  }
}
```

Alternativ legst du eine Kopie von VPDLX direkt unter `data\modules\VPDLX\` ab — das erhält die Portabilität.

**Schritt 2: Im Haupt-Runspace von `PowerEdge.ps1` laden**

```powershell
# Nach dem fxlib-Dot-Sourcing:
$vpdlxPath = Join-Path $PSScriptRoot "data\modules\VPDLX\VPDLX.psd1"
if (Test-Path $vpdlxPath) {
    Import-Module $vpdlxPath -Force -ErrorAction Stop
    # Haupt-Log erstellen
    $result = VPDLXnewlogfile -LogfileName "PowerEdge"
    if ($result.code -eq 0) {
        VPDLXwritelogfile -LogfileName "PowerEdge" -Level "INFO" -Message "PowerEdge $global:AppVers starting..."
    }
}
```

**Schritt 3: `syncHash` mit Log-Referenz erweitern**

Da Klassen-Instanzen (hier `[Logfile]`) nicht direkt über Runspace-Grenzen übergeben werden können, übergibt man den **Logfile-Namen** als String und ruft VPDLX im UI-Runspace nach einem erneuten `Import-Module` auf:

```powershell
$syncHash = [hashtable]::Synchronized(@{
    ...
    VpdlxModulePath = $vpdlxPath     # Pfad zum Modul
    LogfileName     = "PowerEdge"    # Name des Logs
    ...
})
```

**Schritt 4: Im `$uiScript`-Block VPDLX laden und nutzen**

```powershell
$uiScript = {
    ...
    # VPDLX im UI-Runspace laden
    $vpdlxPath = $syncHash.VpdlxModulePath
    if ($vpdlxPath -and (Test-Path $vpdlxPath)) {
        Import-Module $vpdlxPath -Force -ErrorAction SilentlyContinue
        VPDLXnewlogfile -LogfileName $syncHash.LogfileName -ErrorAction SilentlyContinue
    }

    # Inline-Helper für bequemes Logging
    function Write-PELog {
        param([string]$Level = "INFO", [string]$Message)
        VPDLXwritelogfile -LogfileName $syncHash.LogfileName -Level $Level -Message $Message `
            -ErrorAction SilentlyContinue
    }

    # Dann in Events nutzen:
    $window.Add_Loaded({
        Write-PELog "INFO" "Window loaded, initializing WebView2..."
    })

    $webView.Add_CoreWebView2InitializationCompleted({
        param($sender, $e)
        if ($e.IsSuccess) {
            Write-PELog "INFO" "WebView2 initialized successfully."
            $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)
            Write-PELog "INFO" "Navigation started: $($fileUri.AbsoluteUri)"
        } else {
            Write-PELog "ERROR" "WebView2 init failed: $($e.InitializationException.Message)"
        }
    })
    ...
}
```

**Schritt 5: Log beim Beenden exportieren**

Im Haupt-Runspace, nach `$psInstance.EndInvoke($asyncHandle)`:

```powershell
# Log in Datei exportieren wenn VPDLX geladen ist
if (Get-Module -Name VPDLX) {
    $logDir = Join-Path $PSScriptRoot "data\logs"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    VPDLXexportlogfile -LogfileName "PowerEdge" `
        -ExportAs "html" `
        -ExportPath "$logDir\PowerEdge_$timestamp.html" `
        -Override
    VPDLXwritelogfile -LogfileName "PowerEdge" -Level "INFO" -Message "Application closed cleanly."
}
```


***

## Thema 4 — Interaktive Statusmeldungen in der Statusleiste

### Wie es aktuell funktioniert

Das `StatusText`-Element ist ein normaler `TextBlock` in der Statusleiste . Es wird bereits in `PowerEdge.ps1` zur Laufzeit beschrieben:

```powershell
$statusText = $window.FindName("StatusText")
...
if ($null -ne $statusText) { $statusText.Text = "Loading web application..." }
// später:
if ($null -ne $statusText) { $statusText.Text = "Ready" }
```

Du kannst dieses System problemlos ausbauen und Statusmeldungen an beliebigen Stellen setzen.

### Statusmeldungen beim Navigieren anzeigen

Der WebView2 hat einen eingebauten `NavigationStarting`- und `NavigationCompleted`-Event genau für diesen Zweck:

```powershell
$webView.Add_CoreWebView2InitializationCompleted({
    param($sender, $e)
    if ($e.IsSuccess) {

        # Event: Navigation beginnt
        $sender.CoreWebView2.Add_NavigationStarting({
            param($s, $navArgs)
            $url = $navArgs.Uri
            # URL kürzen für die Anzeige
            $displayUrl = if ($url.Length -gt 60) { $url.Substring(0,57) + "..." } else { $url }
            if ($null -ne $statusText) {
                $statusText.Dispatcher.Invoke({
                    $statusText.Text = "Loading: $displayUrl"
                })
            }
        })

        # Event: Navigation abgeschlossen
        $sender.CoreWebView2.Add_NavigationCompleted({
            param($s, $navArgs)
            if ($null -ne $statusText) {
                $statusText.Dispatcher.Invoke({
                    $statusText.Text = if ($navArgs.IsSuccess) { "Ready" } else { "Navigation failed (Error: $($navArgs.WebErrorStatus))" }
                })
            }
        })

        # Initiale Navigation
        $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)
    }
})
```

Das `$statusText.Dispatcher.Invoke({ ... })` ist wichtig: Da der `NavigationStarting`/`NavigationCompleted`-Callback möglicherweise auf einem anderen Thread feuert als der WPF-UI-Thread, muss die UI-Aktualisierung über den `Dispatcher` marshalled werden.

### Weitere Statusmeldungen, die Sinn ergeben

```powershell
# Beim Server-Start (wenn LocalServer integriert):
$statusText.Text = "LocalServer starting on port $ServerPort..."

# Nach erfolgreichem Server-Start:
$statusText.Text = "LocalServer running · http://localhost:$ServerPort/"

# Beim Schließen:
$window.Add_Closing({
    if ($null -ne $statusText) { $statusText.Text = "Shutting down..." }
})

# Beim Download (falls WebView2 Downloads erlaubt):
$webView.CoreWebView2.Add_DownloadStarting({
    param($s, $args)
    $statusText.Text = "Downloading: $($args.DownloadOperation.Uri)"
})
```


***

## Thema 5 — Tooltips bei den Window-Control-Buttons

### Wie es aktuell definiert ist

Der Tooltip-Text ist direkt im XAML als `ToolTip`-Property gesetzt :

```xml
<Button x:Name="BtnMinimize"
        Style="{StaticResource WinCtrlBtn}"
        Background="{StaticResource BrushBtnMinimize}"
        ToolTip="Minimize"/>

<Button x:Name="BtnMaximize"
        ...
        ToolTip="Maximize / Restore"/>

<Button x:Name="BtnClose"
        ...
        ToolTip="Close"/>
```

Den Text kannst du **direkt im XAML** ändern — oder zur Laufzeit per PowerShell:

```powershell
$btnMinimize.ToolTip = "Fenster minimieren"
$btnMaximize.ToolTip = "Maximieren / Wiederherstellen"
$btnClose.ToolTip    = "PowerEdge beenden"
```


### Tooltip grafisch vollständig anpassen

WPF-Tooltips können komplett mit XAML gestaltet werden. Statt `ToolTip="Text"` verwendest du eine `ToolTip`-Property mit einem `ToolTip`-Element als komplexes Objekt:

```xml
<Button x:Name="BtnClose"
        Style="{StaticResource WinCtrlBtn}"
        Background="{StaticResource BrushBtnClose}">
    <Button.ToolTip>
        <ToolTip Background="#1A1A1A"
                 BorderBrush="#00B4C8"
                 BorderThickness="1"
                 Padding="10,6"
                 HasDropShadow="True">
            <StackPanel Orientation="Horizontal">
                <!-- Kleines Icon (optional) -->
                <Ellipse Width="8" Height="8"
                         Fill="#E05055"
                         VerticalAlignment="Center"
                         Margin="0,0,8,0"/>
                <TextBlock Text="PowerEdge beenden"
                           Foreground="#E8E8E8"
                           FontFamily="Segoe UI"
                           FontSize="12"/>
            </StackPanel>
        </ToolTip>
    </Button.ToolTip>
</Button>
```


### Tooltip-Timing steuern

Du kannst auch `ToolTipService`-Properties setzen, um das Verhalten zu steuern:

```xml
<Button x:Name="BtnClose"
        ToolTipService.InitialShowDelay="600"
        ToolTipService.ShowDuration="4000"
        ToolTipService.BetweenShowDelay="200"
        ...>
```

| Property | Bedeutung | Standard (ms) |
| :-- | :-- | :-- |
| `InitialShowDelay` | Wie lange hovern, bis Tooltip erscheint | 400 |
| `ShowDuration` | Wie lange der Tooltip sichtbar bleibt | 5000 |
| `BetweenShowDelay` | Pause zwischen zwei Tooltip-Anzeigen | 100 |

### Globaler Tooltip-Style als Resource

Statt jeden Tooltip einzeln zu stylen, kannst du in `Window.Resources` einen globalen `TargetType="ToolTip"`-Style definieren — dieser gilt automatisch für alle Tooltips im Fenster:

```xml
<Window.Resources>
    ...
    <Style TargetType="ToolTip">
        <Setter Property="Background"       Value="#1A1A1A"/>
        <Setter Property="Foreground"       Value="#E8E8E8"/>
        <Setter Property="BorderBrush"      Value="#2A2A2A"/>
        <Setter Property="BorderThickness"  Value="1"/>
        <Setter Property="Padding"          Value="8,5"/>
        <Setter Property="FontFamily"       Value="Segoe UI"/>
        <Setter Property="FontSize"         Value="12"/>
        <Setter Property="HasDropShadow"    Value="True"/>
    </Style>
    ...
</Window.Resources>
```

Das ist der empfohlene Weg, da du damit das Design zentral pflegst und alle zukünftigen Tooltips automatisch das richtige Styling erhalten, ohne jede `Button`-Definition anfassen zu müssen .

***

<div align="center">⁂</div>

***

## Überblick: Die vier Strategien im Vergleich

Es gibt grundsätzlich vier verschiedene Ansätze, um VPDLX in PowerEdge auf aktuellem Stand zu halten. Bevor wir ins Detail gehen, hier das Gesamtbild:


| Strategie | Automatisierung | Komplexität | Offline-Nutzung | Kontrolle über Version |
| :-- | :-- | :-- | :-- | :-- |
| **Manuelles Kopieren** | ❌ Keine | ✅ Minimal | ✅ Vollständig | ✅ Vollständig |
| **In-App Update-Checker** | ⚠️ Semi-Auto | ⚠️ Mittel | ✅ Vollständig | ✅ Vollständig |
| **Git Submodule** | ✅ Mit `git pull` | ⚠️ Mittel | ✅ Vollständig | ✅ Vollständig |
| **GitHub Actions Sync** | ✅ Vollautomatisch | ❌ Hoch | ✅ Vollständig | ⚠️ Verzögert (nach Push) |


***

## Strategie 1 — In-App Update-Checker in PowerEdge

Das ist dein eigener Vorschlag: PowerEdge befragt beim Start die GitHub-API, vergleicht Versionen und lädt VPDLX bei Bedarf herunter.

### Wie funktioniert das technisch?

GitHub stellt für jedes Repository eine öffentliche REST-API bereit. Der relevante Endpunkt lautet:

```
https://api.github.com/repos/praetoriani/PowerShell.Mods/contents/VPDLX/VPDLX.psd1
```

Aus dieser Antwort kannst du den Base64-codierten Dateiinhalt dekodieren und per Regex die `ModuleVersion`-Zeile herauslesen — **ohne einen Release zu benötigen** (dein VPDLX-Repo hat aktuell keinen dedizierten VPDLX-Release, nur einen für PSAppCoreLib) .

Ein alternativer, noch einfacherer Endpunkt ist die **Raw-URL**:

```
https://raw.githubusercontent.com/praetoriani/PowerShell.Mods/main/VPDLX/VPDLX.psd1
```

Die lässt sich direkt per `Invoke-WebRequest` abrufen, ohne Base64-Dekodierung.

### Vollständige Implementierung als PowerShell-Funktion

Diese Funktion kannst du als `CheckVpdlxUpdate.ps1` in `data\fxlib\` ablegen und dann per Dot-Sourcing in `PowerEdge.ps1` laden:

```powershell
function Invoke-VpdlxUpdateCheck {
    <#
    .SYNOPSIS
        Prüft ob eine neuere Version von VPDLX verfügbar ist und lädt sie ggf. herunter.
    .PARAMETER LocalModulePath
        Pfad zum lokalen VPDLX-Ordner (z.B. "$PSScriptRoot\data\modules\VPDLX")
    .PARAMETER Force
        Erzwingt Download auch wenn die Version identisch ist
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalModulePath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $result = [PSCustomObject]@{
        Code        = -1
        Message     = ""
        LocalVers   = "unknown"
        RemoteVers  = "unknown"
        Updated     = $false
    }

    # ── Schritt 1: Lokale Version lesen ─────────────────────────────────
    $localPsd1 = Join-Path $LocalModulePath "VPDLX.psd1"
    if (Test-Path $localPsd1) {
        $localContent = Get-Content $localPsd1 -Raw
        if ($localContent -match "ModuleVersion\s*=\s*'([^']+)'") {
            $result.LocalVers = $matches[1]
        }
    } else {
        # Kein lokales Modul vorhanden — Erstinstallation
        $result.LocalVers = "0.0.0"
    }

    # ── Schritt 2: Remote-Version von GitHub lesen ───────────────────────
    $rawUrl = "https://raw.githubusercontent.com/praetoriani/PowerShell.Mods/main/VPDLX/VPDLX.psd1"
    try {
        $remoteContent = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 8 |
                         Select-Object -ExpandProperty Content
        if ($remoteContent -match "ModuleVersion\s*=\s*'([^']+)'") {
            $result.RemoteVers = $matches[1]
        } else {
            $result.Code    = -2
            $result.Message = "Remote VPDLX.psd1 konnte nicht geparst werden."
            return $result
        }
    }
    catch {
        $result.Code    = -3
        $result.Message = "GitHub nicht erreichbar: $($_.Exception.Message)"
        return $result
    }

    # ── Schritt 3: Versionen vergleichen ────────────────────────────────
    $localVer  = [System.Version]$result.LocalVers
    $remoteVer = [System.Version]$result.RemoteVers

    if ($remoteVer -le $localVer -and -not $Force) {
        $result.Code    = 0
        $result.Message = "VPDLX ist aktuell (v$($result.LocalVers))."
        return $result
    }

    # ── Schritt 4: Dateiliste aus GitHub API holen ───────────────────────
    # Wir lesen die FileList aus VPDLX.psd1 — sie enthält alle Dateipfade
    $apiBase = "https://raw.githubusercontent.com/praetoriani/PowerShell.Mods/main/VPDLX"
    $filesToDownload = @(
        "VPDLX.psm1",
        "VPDLX.psd1",
        "VPDLX.Precheck.ps1",
        "Classes\VPDLXClasses.ps1",
        "Private\VPDLXreturn.ps1",
        "Public\VPDLXnewlogfile.ps1",
        "Public\VPDLXislogfile.ps1",
        "Public\VPDLXdroplogfile.ps1",
        "Public\VPDLXreadlogfile.ps1",
        "Public\VPDLXwritelogfile.ps1",
        "Public\VPDLXexportlogfile.ps1",
        "Public\VPDLXgetalllogfiles.ps1",
        "Public\VPDLXresetlogfile.ps1",
        "Public\VPDLXfilterlogfile.ps1"
    )

    # ── Schritt 5: Herunterladen ─────────────────────────────────────────
    try {
        foreach ($relativePath in $filesToDownload) {
            # Windows-Backslash → URL-Slash
            $urlPath   = $relativePath -replace '\\', '/'
            $fileUrl   = "$apiBase/$urlPath"
            $localFile = Join-Path $LocalModulePath $relativePath

            # Unterordner anlegen falls nötig (Classes\, Private\, Public\)
            $localDir = Split-Path $localFile -Parent
            if (-not (Test-Path $localDir)) {
                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
            }

            Invoke-WebRequest -Uri $fileUrl -OutFile $localFile -UseBasicParsing -TimeoutSec 15
        }

        $result.Code    = 0
        $result.Message = "VPDLX erfolgreich auf v$($result.RemoteVers) aktualisiert."
        $result.Updated = $true
    }
    catch {
        $result.Code    = -4
        $result.Message = "Download fehlgeschlagen bei '$relativePath': $($_.Exception.Message)"
    }

    return $result
}
```


### Integration in PowerEdge.ps1

Am Anfang des Hauptskripts, bevor der UI-Runspace gestartet wird:

```powershell
# VPDLX Update-Check (nur wenn Netzwerk verfügbar ist)
$vpdlxLocalPath = Join-Path $PSScriptRoot "data\modules\VPDLX"
$updateResult = Invoke-VpdlxUpdateCheck -LocalModulePath $vpdlxLocalPath

if ($updateResult.Code -eq 0 -and $updateResult.Updated) {
    Write-Host "[PowerEdge] VPDLX wurde auf v$($updateResult.RemoteVers) aktualisiert." -ForegroundColor Green
} elseif ($updateResult.Code -lt 0) {
    Write-Warning "[PowerEdge] VPDLX Update-Check: $($updateResult.Message)"
}
```


***

## Strategie 2 — Git Submodule

Das ist die **eleganteste und professionellste Lösung** für dein Szenario. Ein Git Submodule ist ein Zeiger in deinem Repository, der auf einen bestimmten Commit eines anderen Repositories verweist. Das VPDLX-Verzeichnis lebt dabei physisch im Filesystem von PowerEdge, aber git weiß, dass es aus einem anderen Repository stammt.

### Wie Submodules funktionieren

Wenn du ein Submodule hinzufügst, passieren zwei Dinge: Es wird eine `.gitmodules`-Datei im Root deines Repositories angelegt, und der Ordner erhält einen speziellen Git-Commit-Pointer anstatt normaler Dateien. Das bedeutet, du hast **volle Kontrolle darüber, auf welchen exakten Commit** der Submodule zeigt — er wird **nicht automatisch mitgezogen**, wenn das Upstream-Repo neue Commits bekommt. Das ist Absicht, keine Einschränkung.

### Einrichtung (einmalig)

```bash
# Im Root-Verzeichnis deines PowerShell.Lib-Repos:
cd C:\Repos\PowerShell.Lib

# Submodule hinzufügen — VPDLX landet in PowerEdge/data/modules/VPDLX
git submodule add https://github.com/praetoriani/PowerShell.Mods PowerEdge/data/modules/VPDLX

# Da du nur den VPDLX-Unterordner willst, nicht das ganze PowerShell.Mods-Repo,
# musst du Sparse Checkout verwenden (siehe unten)
```

⚠️ **Wichtiger Hinweis:** Git Submodules zeigen immer auf ein **gesamtes Repository**, nicht auf einen Unterordner. Da VPDLX ein Unterordner von `PowerShell.Mods` ist (nicht ein eigenes Repo), gibt es drei Alternativen:

**Option A (empfohlen): VPDLX in ein eigenes Repository auslagern**

Das wäre die sauberste Lösung. Ein eigenes `PowerShell.VPDLX`-Repository, das ausschließlich VPDLX enthält. Dann funktioniert das Submodule direkt:

```bash
git submodule add https://github.com/praetoriani/PowerShell.VPDLX PowerEdge/data/modules/VPDLX
```

**Option B: Sparse Checkout im Submodule**

Falls VPDLX in `PowerShell.Mods` verbleibt, kannst du das gesamte Repo als Submodule einbinden, aber nur den VPDLX-Ordner per Sparse Checkout auschecken:

```bash
git submodule add https://github.com/praetoriani/PowerShell.Mods PowerEdge/data/modules/VPDLXSource
```

Dann in `.git/modules/PowerEdge/data/modules/VPDLXSource/info/sparse-checkout`:

```
/VPDLX/
```

**Option C: Submodule auf einen Symlink-Trick verzichten und direkt auf PowerShell.Mods zeigen**

Das ganzes Repo als Submodule, dann in PowerEdge den Pfad `data/modules/VPDLXSource/VPDLX` referenzieren. Weniger elegant, aber funktional.

### Update auf neueste Version

```bash
# Den Submodule auf den neuesten Commit des Upstream-Repos aktualisieren:
git submodule update --remote PowerEdge/data/modules/VPDLX

# Dann den aktualisierten Pointer committen:
git add PowerEdge/data/modules/VPDLX
git commit -m "chore: update VPDLX submodule to latest"
git push
```

Das Update ist **bewusst manuell** — du entscheidest, wann PowerEdge eine neue VPDLX-Version übernimmt. Das ist einer der wichtigsten Vorteile von Submodules gegenüber automatischem Syncing.

### Klonen mit Submodule

Wer PowerEdge neu klont, muss die Submodule explizit mitladen:

```bash
# Beim erstmaligen Klonen alles auf einmal:
git clone --recurse-submodules https://github.com/praetoriani/PowerShell.Lib

# Oder nachträglich:
git submodule init
git submodule update
```


***

## Strategie 3 — GitHub Actions: Automatischer Sync via Workflow

Das ist deine dritte Idee und absolut umsetzbar. GitHub Actions kann auf Push-Events im `PowerShell.Mods`-Repo reagieren und automatisch eine Aktion im `PowerShell.Lib`-Repo auslösen.

### Wie das Prinzip funktioniert

Es gibt zwei saubere Wege:

**Weg A: Repository Dispatch (Event-getriebener Cross-Repo-Trigger)**

`PowerShell.Mods` sendet nach jedem Push ein `repository_dispatch`-Event an `PowerShell.Lib`. Der Workflow in `PowerShell.Lib` reagiert darauf, klont VPDLX und commitet es.

**Weg B: Scheduled Sync (Zeitbasiertes Polling)**

Ein Cron-Job in `PowerShell.Lib` läuft z. B. täglich und prüft, ob VPDLX sich geändert hat.

Ich zeige dir hier **Weg A (Repository Dispatch)**, da er sofortig und ereignisgesteuert ist.

### Schritt 1: Personal Access Token (PAT) erstellen

Damit der Workflow in `PowerShell.Mods` Zugriff auf `PowerShell.Lib` bekommt, brauchst du ein PAT mit `repo`-Scope. Erstelle es unter [github.com/settings/tokens](https://github.com/settings/tokens) und speichere es als Secret:

- In `PowerShell.Mods` → Settings → Secrets and variables → Actions → New repository secret
- Name: `POWERLIB_DISPATCH_TOKEN`
- Value: Dein PAT


### Schritt 2: Trigger-Workflow in `PowerShell.Mods`

Lege diese Datei unter `.github/workflows/notify-powerlib.yml` im `PowerShell.Mods`-Repo an:

```yaml
name: Notify PowerEdge on VPDLX Update

on:
  push:
    branches: [ main ]
    paths:
      - 'VPDLX/**'   # Nur bei Änderungen im VPDLX-Ordner triggern

jobs:
  dispatch:
    runs-on: ubuntu-latest
    steps:
      - name: Send Repository Dispatch to PowerShell.Lib
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.POWERLIB_DISPATCH_TOKEN }}
          script: |
            await github.rest.repos.createDispatchEvent({
              owner: 'praetoriani',
              repo: 'PowerShell.Lib',
              event_type: 'vpdlx-updated',
              client_payload: {
                vpdlx_sha: context.sha,
                vpdlx_ref: context.ref,
                triggered_by: context.actor
              }
            });
```


### Schritt 3: Empfangs-Workflow in `PowerShell.Lib`

Lege diese Datei unter `.github/workflows/sync-vpdlx.yml` im `PowerShell.Lib`-Repo an:

```yaml
name: Sync VPDLX from PowerShell.Mods

on:
  repository_dispatch:
    types: [ vpdlx-updated ]

jobs:
  sync-vpdlx:
    runs-on: ubuntu-latest
    permissions:
      contents: write   # Schreibrecht für den Commit

    steps:
      - name: Checkout PowerShell.Lib
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Checkout PowerShell.Mods (nur VPDLX-Ordner per Sparse Checkout)
        uses: actions/checkout@v4
        with:
          repository: praetoriani/PowerShell.Mods
          path: _vpdlx_source
          sparse-checkout: |
            VPDLX
          sparse-checkout-cone-mode: false

      - name: Sync VPDLX nach PowerEdge/data/modules/VPDLX
        run: |
          # Zielordner leeren und neu befüllen
          rm -rf PowerEdge/data/modules/VPDLX
          mkdir -p PowerEdge/data/modules/VPDLX
          cp -r _vpdlx_source/VPDLX/. PowerEdge/data/modules/VPDLX/

          # Temporären Checkout-Ordner aufräumen
          rm -rf _vpdlx_source

      - name: VPDLX Version aus psd1 lesen
        id: vpdlx_version
        run: |
          VERSION=$(grep "ModuleVersion" PowerEdge/data/modules/VPDLX/VPDLX.psd1 \
                    | grep -oP "'\K[^']+")
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Commit und Push
        run: |
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git add PowerEdge/data/modules/VPDLX/

          # Nur committen wenn sich tatsächlich etwas geändert hat
          if git diff --cached --quiet; then
            echo "Keine Änderungen — VPDLX bereits aktuell."
          else
            git commit -m "chore(deps): sync VPDLX v${{ steps.vpdlx_version.outputs.version }} from PowerShell.Mods"
            git push
          fi
```


### Was dieser Workflow bewirkt

```
[Du pushst in PowerShell.Mods/VPDLX/]
        │
        ▼
[notify-powerlib.yml feuert]
        │
        ▼  repository_dispatch event "vpdlx-updated"
        │
        ▼
[sync-vpdlx.yml startet in PowerShell.Lib]
        │
        ├── Checkout PowerShell.Lib (main)
        ├── Sparse-Checkout von VPDLX aus PowerShell.Mods
        ├── Kopiert VPDLX nach PowerEdge/data/modules/VPDLX/
        └── Commitet "chore(deps): sync VPDLX v1.02.07 from PowerShell.Mods"
```

Das Ergebnis: Sobald du VPDLX im `PowerShell.Mods`-Repo pushst, ist innerhalb von ca. 30–60 Sekunden automatisch der aktuelle Stand auch in `PowerEdge` committed.

***

## Strategie 4 — Hybridlösung (Empfehlung)

Keine der drei Strategien ist allein perfekt. Die beste Lösung für dein konkretes Szenario ist eine **Kombination aus GitHub Actions Sync und dem In-App Update-Checker**:

```
PowerShell.Mods (VPDLX gepusht)
        │
        ▼ GitHub Action (automatisch)
PowerShell.Lib / PowerEdge/data/modules/VPDLX/ (immer aktuell im Repo)
        │
        ▼ git pull (wenn Nutzer das Repo aktualisiert)
Lokale PowerEdge-Installation (aktuell)
        │
        ▼ Invoke-VpdlxUpdateCheck (Fallback im laufenden Betrieb)
Erkennt falls lokale Kopie veraltet ist (z.B. ohne git pull)
```

Die GitHub Action sorgt dafür, dass das **Repo** immer aktuell ist. Der In-App-Checker ist ein zusätzliches Sicherheitsnetz für Nutzer, die PowerEdge nicht via Git benutzen, sondern als ZIP-Download.

***

## Zusammenfassung der Empfehlungen

- **Für maximale Kontrolle und git-basierte Workflows**: Git Submodule (erfordert, dass VPDLX ein eigenes Repository bekommt)
- **Für vollständige Automatisierung ohne manuelle Schritte**: GitHub Actions Dispatch-Workflow (Strategie 3) — sobald du in VPDLX pushst, ist PowerEdge automatisch aktuell
- **Als Offline-/ZIP-Fallback für Endnutzer**: In-App Update-Checker (Strategie 1) zusätzlich zum Actions-Workflow
- **Pragmatisch und sofort umsetzbar**: Den GitHub-Actions-Workflow in `PowerShell.Mods` und `PowerShell.Lib` anlegen — das braucht keine Repo-Umstrukturierung und funktioniert mit deiner bestehenden Ordnerstruktur direkt

