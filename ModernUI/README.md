# ModernUI - Frameless WPF Framework für PowerShell

![Version](https://img.shields.io/badge/version-1.00.00-blue)
![Language](https://img.shields.io/badge/language-PowerShell-green)
![Framework](https://img.shields.io/badge/framework-WPF-orange)

## 📋 Übersicht

**ModernUI** ist ein modernes GUI-Framework für PowerShell basierend auf WPF (Windows Presentation Foundation). Es ermöglicht die Erstellung rahmenloser Fenster mit PNG-Hintergrundbildern und bietet eine saubere, wartbare Architektur für GUI-Anwendungen.

### ✨ Hauptmerkmale

- 🎨 **Rahmenlose Fenster** mit vollständiger Transparenzunterstützung
- 🖼️ **PNG-Hintergrund-Overlay** für modernes Design
- 🎯 **ActionBar / TitleBar** mit Icon, Titel und Schließen-Button
- 🖱️ **Fenster-Dragging** über die Titelleiste
- 🔧 **Zentrale Konfiguration** über JSON-Datei
- 📦 **Globale Variablen** für einfache Verwaltung
- 🎛️ **RunMainApp-Funktion** als zentrale Orchestrierungsstelle
- 🛑 **Zentrale AppExit-Funktion** für sauberes Beenden

---

## 🗂️ Verzeichnisstruktur

```
ModernUI/
├── ModernUI.ps1          # Hauptanwendungsskript
├── ModernUI.xaml         # WPF UI-Definition
├── config.json           # Konfigurationsdatei
├── README.md             # Dokumentation
├── CHANGELOG.md          # Änderungshistorie
└── PNG/                  # Grafik-Verzeichnis (wird separat befüllt)
    ├── ModernUI-WinBG.png        # Hintergrund (800x600)
    ├── appicon.png               # Anwendungs-Icon (24x24)
    ├── axn-winclose-normal.png   # Schließen-Button normal (24x24)
    └── axn-winclose-hover.png    # Schließen-Button hover (24x24)
```

---

## 🚀 Schnelstart

### Voraussetzungen

- Windows 10/11
- PowerShell 5.1 oder höher
- .NET Framework 4.5 oder höher
- WPF assemblies (normalerweise vorinstalliert)

### Installation

1. **Klonen oder herunterladen** des Repository
2. **PNG-Grafiken** in das Verzeichnis `ModernUI\PNG\` kopieren:
   - `ModernUI-WinBG.png` (Hintergrund, 800x600 Pixel)
   - `appicon.png` (Icon, 24x24 Pixel)
   - `axn-winclose-normal.png` (Normal-Zustand, 24x24 Pixel)
   - `axn-winclose-hover.png` (Hover-Zustand, 24x24 Pixel)

### Ausführung

```powershell
# Navigieren Sie zum ModernUI-Verzeichnis
cd .\ModernUI

# Skript ausführen (mit erhöhten Berechtigungen empfohlen)
.\ModernUI.ps1
```

---

## ⚙️ Konfiguration

Die Datei `config.json` enthält alle Konfigurationseinstellungen:

```json
{
  "appname": "ModernUI",
  "appdesc": "ModernUI for PowerShell",
  "appver": "v1.00.00",
  "devname": "Praetoriani",
  "website": "https://github.com/praetoriani",
  "modernui": {
    "window": "PNG\\ModernUI-WinBG.png",
    "appicon": "PNG\\appicon.png",
    "appclose": {
      "normal": "PNG\\axn-winclose-normal.png",
      "hover": "PNG\\axn-winclose-hover.png"
    }
  }
}
```

### Konfigurationsoptionen

| Schlüssel | Wert | Beschreibung |
|-----------|------|-------------|
| `appname` | String | Name der Anwendung |
| `appdesc` | String | Beschreibung der Anwendung |
| `appver` | String | Versionsnummer |
| `devname` | String | Entwickler-Name |
| `website` | String | Webseite / Repository-Link |
| `modernui.window` | Pfad | Hintergrund-PNG relativ zu ModernUI-Verzeichnis |
| `modernui.appicon` | Pfad | Anwendungs-Icon PNG |
| `modernui.appclose.normal` | Pfad | Schließen-Button Normalzustand |
| `modernui.appclose.hover` | Pfad | Schließen-Button Hover-Zustand |

---

## 🏗️ Architektur

### Globale Variablen

```powershell
$Global:ModernUI_Config      # Konfigurationsdaten aus JSON
$Global:ModernUI_State       # Aktueller Anwendungszustand
$Global:ModernUI_XAML        # XAML-Inhalt als String
$Global:ScriptPath           # Pfad des ausführenden Skripts
```

### Funktionen

#### Umgebungsprüfung
- **`Test-ModernUIEnvironment`**: Prüft erforderliche Verzeichnisse und Dateien

#### Konfiguration
- **`Load-ModernUIConfig`**: Lädt `config.json` in globale Variable
- **`ConvertTo-Hashtable`**: Konvertiert PSObject zu Hashtable (rekursiv)

#### XAML & UI
- **`Load-ModernUIXAML`**: Lädt XAML und setzt Bilder aus Konfiguration

#### Event-Handling
- **`Register-EventHandlers`**: Registriert alle UI-Event-Handler
  - Fenster-Dragging
  - Close-Button Funktionalität
  - Window-Lifecycle-Events

#### Anwendungssteuerung
- **`Invoke-AppExit`**: **Zentrale Exit-Funktion** - wird für sauberes Beenden verwendet
- **`Initialize-ModernUI`**: Initialisiert Framework und Dependencies
- **`Invoke-RunMainApp`**: **Hauptorkhestrierungsfunktion** - koordiniert alle Schritte

---

## 🎛️ Verwendung als Entwickler

### Fenster draggbar machen

Das Fenster ist bereits durch die TitleBar draggbar. Dieser Code ist implementiert:

```powershell
$titleBar.Add_MouseLeftButtonDown({
    $Window.DragMove()
})
```

### Benutzerdefinierten Code hinzufügen

Um neue Funktionen hinzuzufügen, folgen Sie diesem Muster:

1. **Neue Funktion definieren**
2. **In `Initialize-ModernUI` aufrufen** (falls Initialisierung notwendig)
3. **In `Invoke-RunMainApp` orchestrieren** (falls Teil des Hauptablaufs)

### Beispiel: Button-Handler

```powershell
function Register-CustomEventHandlers {
    param([System.Windows.Window]$Window)
    
    $myButton = $Window.FindName("MyButton")
    if ($null -ne $myButton) {
        $myButton.Add_Click({
            Write-Host "Button geklickt!"
            # Ihre Logik hier
        })
    }
}
```

---

## 🐛 Fehlerbehandlung

Die Anwendung implementiert umfassende Fehlerbehandlung:

- Prüfung aller erforderlichen Dateien
- Try-Catch-Blöcke in kritischen Funktionen
- Aussagekräftige Fehlermeldungen
- Sauberes Cleanup beim Beenden

---

## 📝 Entwicklungshinweise

### Performance-Optimierung

- PNG-Grafiken sollten optimiert sein (nicht zu groß)
- Große XAML-Strukturen können zu Verzögerungen führen
- Verwenden Sie `Dispose()` für Ressourcen bei Bedarf

### Best Practices

1. ✅ Immer `Invoke-AppExit` für Beendigung verwenden
2. ✅ Globale Variablen für gemeinsame Daten nutzen
3. ✅ Funktionen klein und fokussiert halten
4. ✅ Aussagekräftige Fehlermeldungen ausgeben
5. ✅ Code dokumentieren

### Debugging

```powershell
# PowerShell Debugging aktivieren
Set-PSDebug -Trace 1

# Script mit erweiterten Ausgaben ausführen
.\ModernUI.ps1 -Verbose
```

---

## 🔄 Zukünftige Versionen

Geplante Verbesserungen für kommende Versionen:

- [ ] Fenster-Maximieren/Minimieren
- [ ] Größenänderung (Resize)
- [ ] Mehrere Fenster-Layouts
- [ ] Themensystem (Dark/Light Mode)
- [ ] Animation unterstützung
- [ ] Erweiterte Konfigurationsoptionen

---

## 📄 Lizenz

MIT License - Siehe LICENSE Datei

---

## 👤 Autor

**Praetoriani**  
GitHub: [github.com/praetoriani](https://github.com/praetoriani)

---

## 🤝 Unterstützung

Bei Fragen oder Problemen:

1. GitHub Issues öffnen
2. Detailliertes Error-Log bereitstellen
3. PowerShell-Version angeben
4. Benutzte PNG-Grafiken überprüfen

---

## 📚 Weiterführende Ressourcen

- [Microsoft WPF Dokumentation](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/)
- [PowerShell WPF Guide](https://docs.microsoft.com/en-us/powershell/)
- [XAML Syntax Reference](https://docs.microsoft.com/en-us/dotnet/desktop/xaml-services/)

---

**Version 1.00.00** | Dezember 2025
