# UI-Preview-Tool

Ein kleines, eigenständiges WPF-Tool für PowerShell-Entwickler, um **XAML-/XML-Dateien schnell als Vorschau** anzuschauen – ohne das komplette Programm starten zu müssen.

Der typische Anwendungsfall: Du änderst in deiner PowerShell-GUI nur ein paar Pixel (z. B. einen Button weiter nach rechts) und willst sofort sehen, ob es besser aussieht – ohne die ganze Anwendung neu zu starten.

---

## Warum dieses Tool?

| Skript | Stärke | Schwäche |
|--------|--------|----------|
| `WPF-XAML-Preview.ps1` | Lädt XAML zuverlässig (minimale, sichere Bereinigung) | Keine eigene UI – nur Datei-Dialog + O/Q-Konsolenmenü |
| `XML-XAML-Preview.ps1` | Hat eine kleine UI | Scheitert oft, weil es **zu aggressiv** bereinigt (entfernt `xmlns`, Bindings, Styles, ResourceDictionaries) und dadurch gültiges XAML zerstört |
| **`UI-Preview-Tool.ps1`** | **Eigene, schöne WPF-UI** + robuste, **gestufte** XAML-Bereinigung | – |

Das Kernproblem von `XML-XAML-Preview.ps1` war die übermäßige Bereinigung. `UI-Preview-Tool.ps1` übernimmt stattdessen den bewährten, minimal-invasiven Ansatz von `WPF-XAML-Preview.ps1` und verschärft die Bereinigung **nur dann**, wenn das Laden tatsächlich fehlschlägt.

---

## Features

- **Inline-Vorschau** – Der Inhalt von `Window`/`UserControl` wird direkt im Tool gerendert (Fenster-Ressourcen wie Styles bleiben erhalten).
- **Auto-Reload** – Änderst du die Datei auf der Festplatte, lädt sich die Vorschau automatisch neu (mit 400 ms Entprellung). Perfekt für schnelles Iterieren.
- **Zoom** – Fit-to-Window, Zoom rein/raus, Reset auf 100 %. Standardmäßig wird die Vorschau bei **100 %** angezeigt.
- **Zentrierte Vorschau** – Der Inhalt wird im Vorschaubereich horizontal und vertikal mittig angezeigt (scrollt weiterhin, wenn er größer als der Bereich ist).
- **Drag & Drop** – Datei einfach ins Fenster ziehen.
- **Recent Files** – Zuletzt geöffnete Dateien (werden in `ui-preview-recent.json` gespeichert), inklusive **Clear History**-Button zum Leeren der Liste.
- **Show as Window** – Window-basiertes XAML zusätzlich als echtes, separates Fenster anzeigen.
- **View Code** – Zeigt den rohen Code der aktuellen Datei in einem schreibgeschützten Schnellansicht-Fenster an (nur zum Ansehen, nicht zum Bearbeiten).
- **Robuste, gestufte XAML-Bereinigung** – entfernt Event-Handler, `x:Class`, `mc:Ignorable`, `d:`-Attribute, Custom-Namespaces und nicht auflösbare Bindings – nur so weit wie nötig.
- **Tastenkürzel** – `Ctrl+O` (öffnen), `Ctrl+R` / `F5` (neu laden).

---

## Voraussetzungen

- Windows 10/11
- Windows PowerShell 5.1 **oder** PowerShell 7+ (Windows)
- Keine zusätzlichen Module nötig – nur die in Windows integrierten WPF-Assemblies.

---

## Verwendung

### Start

```powershell
# Aus dem Ordner des Skripts:
.\UI-Preview-Tool.ps1

# Oder von überall:
powershell -File "C:\Pfad\zu\UI-Preview-Tool.ps1"
```

Beim Start wird das Konsolenfenster ausgeblendet und die Tool-Oberfläche angezeigt. Beim Schließen des Tools wird die Konsole wiederhergestellt.

### Bedienung

1. **Datei öffnen** über den Button `Open...`, per `Ctrl+O` oder per Drag & Drop ins Fenster.
2. Die Vorschau erscheint sofort im rechten Bereich – standardmäßig bei **100 % Zoom** und **mittig** im Vorschaubereich.
3. **Auto-Reload** ist standardmäßig aktiv: Speichere deine XAML-Datei in deinem Editor, und die Vorschau aktualisiert sich automatisch.
4. Mit den Zoom-Buttons (`-`, `+`, `Fit`, `100%`) kannst du die Darstellung anpassen.
5. `Show as Window` öffnet Window-basiertes XAML zusätzlich als echtes Fenster.
6. `View Code` zeigt den rohen Code der aktuellen Datei in einem schreibgeschützten Fenster an.
7. `Clear History` (unten im linken Bereich) leert die Recent-Files-Liste.

---

## Wie die XAML-Bereinigung funktioniert

XAML-Dateien aus Visual Studio oder PowerShell-Projekten enthalten oft Referenzen, die in einer eigenständigen Vorschau nicht existieren (Code-Behind-Methoden, Custom-Controls, DataContexts). Das Tool bereinigt das XAML in **drei Stufen** – es beginnt minimal und verschärft nur bei Fehlern:

| Stufe | Entfernt |
|-------|----------|
| **0 (immer)** | `x:Class`, `mc:Ignorable`, `d:`-Attribute, Event-Handler (`Click`, `Loaded`, `TextChanged`, ...), `x:Name` → `Name` |
| **1 (bei Fehler)** | Custom-Namespace-Deklarationen (`xmlns:local="clr-namespace:..."`) und Custom-Elemente (`<local:MyControl/>`) |
| **2 (bei Fehler)** | Bindings (`{Binding ...}`, `{TemplateBinding ...}`) und Ressourcen-Referenzen (`{StaticResource ...}`, `{DynamicResource ...}`) |

Dadurch werden **Standard-WPF-Controls, Styles und Layouts** (Grid, StackPanel, TabControl, DataGrid, ...) unverändert gerendert – genau das, was bei `XML-XAML-Preview.ps1` durch die aggressive Bereinigung kaputtging.

---

## Projektstruktur

```
UI-Preview-Tool/
├── UI-Preview-Tool.ps1              ← Das Tool (englischer Code, kommentiert)
├── README.md                       ← Englische Übersicht
├── Documentation.de.md             ← Deutsche Anleitung (diese Datei)
├── Documentation.en.md             ← Englische Anleitung
├── .gitignore                      ← Nur relevante Dateien für das Repo
├── Example-Test.xaml               ← Demo-Datei
├── Complex-Layout-Test.xaml        ← Demo-Datei
├── Simple-Form-Demo.xaml           ← Demo-Datei
├── DataGrid-Demo.xaml              ← Demo-Datei
└── ui-preview-recent.json           ← Wird automatisch erzeugt (Recent Files)
```

---

## Technische Hinweise

- **Inline-Vorschau:** Ein `Window` oder `UserControl` kann nicht in ein anderes Fenster eingebettet werden. Das Tool extrahiert deshalb den Inhalt (`Content`) und rendert ihn im Vorschaubereich. Fenster-Ressourcen werden dabei in den Vorschau-Container übernommen, damit Styles weiterhin greifen.
- **Zentrierung:** Der Vorschau-Container liegt in einem `Grid`, dessen `MinWidth`/`MinHeight` per XAML-Binding an die Größe des ScrollViewers gebunden sind. So bleibt der Inhalt zentriert, wenn er kleiner als der Bereich ist, und scrollt weiterhin, wenn er größer ist.
- **Auto-Reload:** Ein `FileSystemWatcher` überwacht die Datei. Da dessen Events auf einem Hintergrund-Thread eintreffen, werden sie über den WPF-`Dispatcher` auf den UI-Thread gemarshallt und mit einem `DispatcherTimer` (400 ms) entprellt.
- **Zoom:** Die Vorschau wird über eine `ScaleTransform` (LayoutTransform) skaliert. „Fit" misst die natürliche Größe des Inhalts und skaliert passend zum Viewport.
- **Recent Files:** Die Liste wird als JSON neben dem Skript gespeichert. Nicht mehr vorhandene Dateien werden beim Laden automatisch herausgefiltert.

---

## Fehlerbehandlung

- Ungültige oder nicht ladbare XAML-Dateien erzeugen eine klare Fehlermeldung in der Statusleiste (rot hinterlegt).
- Das Tool versucht automatisch alle drei Bereinigungsstufen, bevor es aufgibt.
- Fehler beim Laden brechen die Vorschau nicht ab – das Tool bleibt bedienbar.

---

## Lizenz

Dieses Projekt ist unter der **Apache License 2.0** lizenziert. Siehe die Datei `LICENSE` im Repository.

---

## Version

**v1.02.00**

- Autor: praetoriani (https://github.com/praetoriani)
- Mitwirkender: paladin-xerox (https://github.com/paladin-xerox)

### Änderungen in v1.02.00

- Umbenennung des Tools in **UI-Preview-Tool**.
- Veröffentlichung als eigenständiger Ordner im Repository `PowerShell.Lib`.
- README, englische/deutsche Dokumentation, `.gitignore` und GitHub-Workflow hinzugefügt.
- Demo-XAML-Dateien auf Englisch übersetzt und neue Demo-Dateien ergänzt.

### Änderungen in v1.01.00

- Vorschau startet standardmäßig bei **100 % Zoom** (statt Fit).
- Vorschau wird im Vorschaubereich **horizontal und vertikal mittig** angezeigt.
- Neuer **Clear History**-Button zum Leeren der Recent-Files-Liste.
- Neue **View Code**-Option zum Ansehen des rohen Codes in einem schreibgeschützten Fenster.
