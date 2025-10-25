# Power.Ctrl.app 🚀

> **Version:** v1.00.10  
> **Autor:** Praetoriani  
> **Datum:** 28.09.2025

Eine moderne, minimalistische PowerShell WPF-Anwendung für schnelle Windows-Systemsteuerung mit elegantem Dark Mode Interface.

## 📋 Überblick

**Power.Ctrl.app** ist eine benutzerfreundliche Systemsteuerungs-Anwendung, die vier wesentliche Windows-Aktionen über eine moderne grafische Oberfläche bereitstellt:
- 🔒 **Arbeitsplatz sperren**
- 👤 **Benutzer abmelden**
- 🔄 **Computer neu starten**
- ⚡ **Computer herunterfahren**

## ✨ Features

- 🎨 **Modern Dark Mode UI** - Schlankes, dunkles WPF-Interface
- 🌍 **Vollständige Lokalisierung** - Deutsch/Englisch mit automatischer Spracherkennung
- 📍 **Flexible Positionierung** - Center, Lower-Left, Lower-Right
- ✅ **Bestätigungsdialoge** - Sicherheitsabfragen vor Systemaktionen
- 📝 **Optionales Logging** - Detaillierte Protokollierung mit Zeitstempeln
- 🎯 **Shell32.dll Icons** - Native Windows-Systemsymbole
- ⚡ **Robuste Architektur** - Stabile WPF Application-Verwaltung
- 💻 **Windows 11 Ready** - Optimiert für moderne Windows-Versionen

## 🔧 Systemanforderungen

- **Betriebssystem:** Windows 10/11
- **PowerShell:** Version 5.0 oder höher
- **.NET Framework:** 4.7.2 oder höher (normalerweise vorinstalliert)
- **Berechtigung:** Administratorrechte empfohlen für alle Systemaktionen

## 📦 Installation & Start

### Schnellstart
1. Alle Dateien in einen Ordner Ihrer Wahl kopieren
2. PowerShell als Administrator öffnen
3. In den Ordner navigieren: `cd C:\Pfad\Zu\Power.Ctrl.app`
4. Anwendung starten: `.\Power.Ctrl.app.ps1`

### Erstmalige Einrichtung
Falls PowerShell-Ausführungsrichtlinien dies verhindern:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## ⚙️ Konfiguration

Alle Einstellungen werden über **globale Variablen** im Hauptskript konfiguriert:

### Sprache 🌍
```powershell
$global:globalLanguage = "de-de"  # oder "en-us"
```

### Fensterposition 📍
```powershell
$global:globalWindowPosition = "center"  # "lowerleft", "lowerright"
```

### Bestätigungsdialoge ✅
```powershell
$global:globalShowConfirmationDialog = $true  # $false für direkte Ausführung
```

### Logging-System 📝
```powershell
$global:globalCreateLogFile = $false  # $true für Protokollierung
```

## 📁 Dateien & Struktur

```
Power.Ctrl.app/
├── Power.Ctrl.app.ps1     # Hauptanwendung
├── app-ui-main.xaml       # Hauptfenster-Interface
├── app-ui-popup.xaml      # Bestätigungsdialog
├── de-de.json            # Deutsche Lokalisierung
├── en-us.json            # Englische Lokalisierung
├── Power.Ctrl.app.log    # Log-Datei (wenn aktiviert)
└── README-DE.md          # Diese Datei
```

## 🎮 Bedienung

### Hauptfenster
- **4 große Buttons** mit Icons für jede Systemaktion
- **Tooltips** beim Hovern über Buttons
- **Automatische Spracherkennung** basierend auf Konfiguration

### Bestätigungsdialog
- **Ja/Nein-Buttons** für Sicherheitsabfrage
- **Spezifische Nachrichten** je nach gewählter Aktion
- **ESC** oder **X-Button** = Zurück zum Hauptfenster

### Tastenkombinationen
- **ESC** - Anwendung beenden (im Hauptfenster)
- **Alt+F4** - Anwendung beenden

## 📋 Log-System

Bei aktiviertem Logging (`$globalCreateLogFile = $true`):
- **Datei:** `Power.Ctrl.app.log` im Anwendungsordner
- **Format:** `[DD.MM.YYYY ; HH:MM:SS] Nachricht`
- **Inhalt:** Alle Konsolen-Ausgaben mit Zeitstempel
- **Rotation:** Bei jedem Start neue Datei (alte wird gelöscht)

### Beispiel-Log:
```
[28.09.2025 ; 21:05:33] Power.Ctrl.app v1.00.10 wird gestartet
[28.09.2025 ; 21:05:34] Hauptfenster erfolgreich geladen
[28.09.2025 ; 21:05:45] Aktion angefordert: lock
[28.09.2025 ; 21:05:47] Benutzer hat Aktion bestätigt
[28.09.2025 ; 21:05:47] Arbeitsplatz erfolgreich gesperrt
```

## 🔍 Troubleshooting

### ❌ PowerShell Ausführungsrichtlinien
**Problem:** `Ausführung von Skripts ist auf diesem System deaktiviert`
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ Fehlende .NET Framework Assemblies
**Problem:** `Der Typ "System.Windows.Application" wurde nicht gefunden`
- Windows Update ausführen
- .NET Framework 4.7.2 oder höher installieren

### ❌ Icons werden nicht angezeigt
**Problem:** Graue Rechtecke statt Icons
- Windows neu starten
- Anwendung als Administrator ausführen
- Shell32.dll Integrität prüfen: `sfc /scannow`

### ❌ Fensterpositionierung ungenau
**Problem:** Fenster nicht exakt positioniert
- Bildschirmauflösung/Skalierung prüfen
- Windows Display-Einstellungen überprüfen
- Mehrere Monitore: Primären Monitor definieren

### ❌ Sprachdateien nicht gefunden
**Problem:** `Sprachdatei nicht gefunden`
- Sicherstellen, dass `de-de.json` und `en-us.json` im gleichen Ordner liegen
- Dateiberechtigungen prüfen
- Pfad ohne Sonderzeichen verwenden

### ❌ Logging funktioniert nicht
**Problem:** Log-Datei wird nicht erstellt
- Schreibberechtigung im Anwendungsordner prüfen
- `$globalCreateLogFile = $true` konfigurieren
- Anwendung als Administrator starten

## 🛡️ Sicherheit

- **Bestätigungsdialoge** verhindern versehentliche Systemaktionen
- **Keine Netzwerkverbindungen** - Rein lokale Anwendung
- **Shell32.dll Integration** - Verwendet nur Windows-eigene Ressourcen
- **Saubere PowerShell-Ausführung** - Keine versteckten Prozesse

## 🔄 Updates & Wartung

- **Automatische Updates:** Nicht verfügbar
- **Manuelle Updates:** Neue Version herunterladen und Dateien ersetzen
- **Konfiguration:** Bleibt bei Updates erhalten (globale Variablen)
- **Kompatibilität:** Abwärtskompatibel mit vorherigen Konfigurationen

## 📞 Support & Kontakt

**Power.Ctrl.app** ist ein Open-Source-Projekt. Bei Fragen oder Problemen:

- 📖 **Dokumentation:** Siehe `Changelog.md` für Versionshistorie
- 🔧 **Konfiguration:** Alle Einstellungen in globalen Variablen
- 🛠️ **Troubleshooting:** Siehe Abschnitt oben

## 📜 Lizenz

Dieses Projekt ist unter einer Open-Source-Lizenz verfügbar. Verwendung auf eigene Verantwortung.

---

**Entwickelt mit ❤️ für die Windows PowerShell Community**