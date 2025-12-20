# ScanProfileSwitcher

## Übersicht

**ScanProfileSwitcher** ist eine PowerShell-basierte GUI-Anwendung zum Verwalten von TWAIN-Scanner-Profilen unter Windows. Das Programm ermöglicht das einfache Wechseln zwischen verschiedenen Scanner-Konfigurationen.

### Features

- ✅ **Einfache GUI** - Intuitive Oberfläche mit WPF
- ✅ **Zwei Scanner-Profile** - Standard (einseitig) und Duplex (zweiseitig)
- ✅ **Konfigurationsverwaltung** - Automatische Verwaltung von Scanner-Einstellungen
- ✅ **Fehlerbehandlung** - Robustes Fehlerlogging und Benutzer-Benachrichtigungen
- ✅ **UTF-8 Encoding** - Vollständige Unterstützung für deutsche Umlaute
- ✅ **Keine Admin-Rechte erforderlich** - Läuft im Benutzerkontext

## Installation

Siehe [INSTALL.md](INSTALL.md) für detaillierte Installationsanleitung.

## Verwendung

```powershell
C:\kkh\ScanProfileSwitcher\ScanProfileSwitcher.ps1
```

## Verzeichnisstruktur

```
ScanProfileSwitcher/
├── ScanProfileSwitcher.ps1          # Hauptanwendung
├── config.json                     # Konfigurationsdatei
├── UTF8-BOM-Patch.ps1              # Encoding-Patch-Skript
├── GUI/                            # XAML-GUI-Dateien
│   ├── main-app-win.xaml
│   ├── popup-close.xaml
│   ├── popup-save.xaml
│   ├── popup-warn.xaml
│   └── popup-error.xaml
├── README.md                       # Diese Datei
├── INSTALL.md                      # Installationsanleitung
├── CHANGELOG.md                    # Änderungslog
└── LICENSE                         # Lizenz
```

## Anforderungen

- Windows 10/11
- PowerShell 5.0 oder höher
- .NET Framework 4.5+
- WPF-Unterstützung (standardmäßig vorhanden)

## Konfiguration

Die Anwendung wird durch die Datei `config.json` konfiguriert:

```json
{
  "applicationName": "ScanProfileSwitcher",
  "version": "1.0.6",
  "currentProfile": "STANDARD",
  "language": "de-DE"
}
```

## Fehlerbehandlung

Fehler werden in der Datei `error.log` protokolliert. Im Fehlerfall:

1. Überprüfen Sie die `error.log`-Datei
2. Vergewissern Sie sich, dass alle Scanner-Profile vorhanden sind
3. Starten Sie das Programm neu

## Technische Details

### UTF-8 mit BOM

Alle Dateien werden mit UTF-8 BOM-Encoding gespeichert. Dies ist essentiell für:

- Korrekte Anzeige von Umlauten (ä, ö, ü, ß)
- Konsistente PowerShell-Ausführung
- Korrekte XAML-Interpretation

### Encoding-Patch

Falls Encoding-Probleme auftreten, führen Sie aus:

```powershell
.\UTF8-BOM-Patch.ps1
```

Dies konvertiert alle Dateien rekursiv zu UTF-8 mit BOM.

## Support

Für Fragen oder Probleme siehe [INSTALL.md](INSTALL.md).

## Lizenz

Siehe [LICENSE](LICENSE) für Lizenzinformationen.

---

**Version:** 1.0.6  
**Letztes Update:** 20.12.2025  
**Status:** Production Ready ✔️
