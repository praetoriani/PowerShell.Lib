# WinISO Image Mounter — Entwicklerdokumentation

Diese Anwendung wurde bewusst im **exakten visuellen Stil deines PowerEdge-Projekts** gebaut. Die Farbpalette, das Fenster-Chrome (abgerundete Ecken, Schlagschatten, eigene Titelleiste, Ampel-Buttons als Ellipse-Template) und der Lade-Mechanismus für UI/Config stammen 1:1 aus `PowerEdge.ps1` und `data\ui\main.window.xml`, die du mir bereitgestellt hast.

## 1. Ordnerstruktur (bitte lokal so anlegen)

```
WinIsoImageMounter\
│   WinIsoImageMounter.ps1
│   WinIsoImageMounter.ico        ← optional, dein eigenes Icon
│
└───data\
    │   config.json
    │
    ├───ui\
    │       main.window.xml
    │
    ├───lang\
    │       en-us.json
    │       de-de.json
    │
    └───fxlib\
            Functions.ps1
```

Alle sechs generierten Dateien tragen bereits den korrekten Dateinamen – du musst sie nur in die oben gezeigten Unterordner verschieben (`config.json` → `data\`, `main.window.xml` → `data\ui\`, `en-us.json`/`de-de.json` → `data\lang\`, `Functions.ps1` → `data\fxlib\`).

## 2. Woher stammt das Design?

Aus deinem echten PowerEdge-Repo habe ich `data/ui/main.window.xml` gelesen (nicht `main.window.grey.xml` – die trug versehentlich denselben Inhalt wie `main.window.light.xml`, beide "Light Theme"). `main.window.xml` ist das **echte Dark Theme**:

| Element | Wert |
|---|---|
| Hintergrund | `#121212` (BrushBg) |
| Oberflächen | `#1A1A1A` / `#1F1F1F` |
| Titelleiste | `#0F0F0F` |
| Akzentfarbe | `#00B4C8` (Teal) |
| Fenster-Ecken | `CornerRadius="10"`, `DropShadowEffect` (Blur 32, Depth 8) |
| Ampel-Buttons | 14×14 Ellipse-Template, Farben Orange/Grün/Rot |

Diese Werte habe ich unverändert in `main.window.xml` übernommen. Da PowerEdge selbst keine Eingabefelder/Buttons besitzt (es hostet nur WebView2), habe ich `TextBox`-, `Button`- und `Label`-Styles **neu entworfen, aber aus derselben Farbpalette** – damit alles wie aus einem Guss wirkt.

## 3. Wie funktioniert der Code?

- **Kein Inline-XAML**: `WinIsoImageMounter.ps1` lädt `data\ui\main.window.xml` per `[xml]`-Cast + `XamlReader::Load()` (Funktion `Import-XamlWindow` in `Functions.ps1`) – genau das Muster aus `PowerEdge.ps1`.
- **Keine hartkodierten Texte**: Jeder sichtbare String kommt aus `data\lang\<code>.json` (`Get-LanguageTable`). Standardsprache ist `en-us` (aus `config.json` → `appconfig.defaultlanguage`), du kannst mit `-Language de-de` starten.
- **Konsole minimieren**: `Set-ConsoleWindowState -Mode 6` ruft `user32.dll!ShowWindow` per P/Invoke auf (identisches Muster wie PowerEdge, nur mit `SW_MINIMIZE` statt `SW_HIDE`, weil du explizit "minimiert" verlangt hast).
- **Fenster zentrieren / nicht verschiebbar in Größe / kein Minimieren/Maximieren**: `WindowStyle="None"`, `ResizeMode="NoResize"`, `WindowStartupLocation="CenterScreen"` in der XAML. Die Titelleiste zeigt bewusst **nur** den Close-Button (kein `BtnMinimize`/`BtnMaximize` wie bei PowerEdge).
- **Datei-Dialog (*.wim)**: `System.Windows.Forms.OpenFileDialog` mit `Filter = "...|*.wim"` – dieser Dialog ist unter Windows 10/11 bereits der native, moderne Explorer-Stil-Dialog.
- **Ordner-Dialog**: `System.Windows.Forms.FolderBrowserDialog`. **Wichtiger Hinweis**: Unter **PowerShell 7.x** (`pwsh.exe`, .NET 5+) rendert dieser Dialog automatisch im modernen Windows-11-Explorer-Stil. Unter **Windows PowerShell 5.1** (.NET Framework, `powershell.exe`) zeigt er noch die klassische Baumansicht, weil .NET Framework nie die moderne Neuimplementierung erhalten hat. Für den optisch exakten Windows-11-Look starte das Skript mit `pwsh.exe`.
- **Rote Fehler-Optik statt MessageBox**: `Show-FieldError` / `Clear-FieldError` setzen `Background`/`BorderBrush` der `TextBox` auf die Brushes `BrushInputError` (`#3A1516`) bzw. `BrushInputErrorBrdr` (`#E05055` – identisch zur PowerEdge-Close-Button-Farbe).
- **DISM-Aufruf**: `Invoke-DismMount` startet `cmd.exe /c DISM /Mount-Wim /WimFile:"..." /index:1 /MountDir:"..."` über `Start-Process -Wait -WindowStyle Normal`. Das neue Konsolenfenster zeigt die DISM-Ausgabe live an und schließt sich automatisch, sobald der Befehl fertig ist (weil `cmd /c` dann zurückkehrt). Danach setzt `Reset-FormState` beide Eingabefelder und die Statuszeile zurück – unabhängig vom Exit-Code, exakt wie gewünscht.
- **Icon-Buttons**: Anstatt Text zeigen "Öffnen"/"Suchen" bereits jetzt ein **Vektor-Ordner-Symbol** (`Path`-Geometrie in einem `Viewbox`), keinen Text. Das ist bewusst kein Platzhalter-Text, sondern schon eine echte Grafik – du kannst sie jederzeit gegen eine eigene PNG/SVG tauschen (siehe Abschnitt 5).

## 4. Warum eine neue Runspace-Architektur nicht nötig war

PowerEdge startet die UI in einer eigenen STA-Runspace, weil es einen WebView2-Control hostet, der einen eigenen Nachrichten-Loop-Kontext braucht. WinISO Image Mounter enthält kein WebView2 und läuft daher als klassisches Single-Thread-WPF-Skript mit `$window.ShowDialog()` im Hauptthread – einfacher, robuster, und für dieses Szenario völlig ausreichend.

## 5. Anpassungsmöglichkeiten

| Was ändern? | Wo? |
|---|---|
| Fenstergröße | `Width`/`Height` in `main.window.xml` (`<Window ...>`) |
| Farben/Akzent | `Window.Resources` → `SolidColorBrush`-Definitionen in `main.window.xml` |
| Texte/Übersetzungen | `data\lang\en-us.json`, `de-de.json` (neue Sprache = neue Datei nach demselben Schema) |
| DISM-Index | `data\config.json` → `dism.wimIndex` (Standard: `1`) |
| Icon-Buttons durch Bilddatei ersetzen | In `main.window.xml` den `<Viewbox>`-Block durch ein `<Image Source="..."/>` ersetzen |
| App-Icon | `WinIsoImageMounter.ico` neben das Hauptskript legen (wird automatisch geladen, sonst einfach ignoriert) |
| Standardsprache | `data\config.json` → `appconfig.defaultlanguage` |

## 6. Was du noch tun musst

1. Ordnerstruktur wie in Abschnitt 1 anlegen und Dateien verschieben.
2. Optional ein eigenes `.ico` als `WinIsoImageMounter.ico` neben das Hauptskript legen.
3. Skript mit Administratorrechten ausführen (DISM-Mount benötigt erhöhte Rechte) – am besten via `pwsh.exe` für den modernen Ordner-Dialog.
4. Testen: ungültige/leere Eingaben → Feld wird rot; gültige Eingaben → DISM-Konsole öffnet sich, mountet, schließt sich, Formular wird zurückgesetzt.

Damit hast du eine 1:1 im PowerEdge-Look gehaltene, vollständig lokalisierte, kommentierte und modular aufgebaute Anwendung.
