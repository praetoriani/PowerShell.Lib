# ScanProfileSwitcher - Benutzerhandbuch

## 📋 Überblick

**ScanProfileSwitcher** ist eine benutzerfreundliche Windows-Anwendung zur Verwaltung von TWAIN-Scanner-Profilen. Das Programm ermöglicht es Ihnen, schnell zwischen zwei Scanner-Konfigurationen zu wechseln:

- **Standard-Profil**: Scannt nur die Vorderseite von Dokumenten
- **Duplex-Profil**: Scannt automatisch Vorder- und Rückseite von Dokumenten

## 🚀 Schnellstart

### Programmstart

1. Suchen Sie auf Ihrem Desktop nach dem Icon **"ScanProfileSwitcher"**
2. Doppelklicken Sie auf das Icon, um das Programm zu starten
3. Das Programm startet automatisch mit der aktuellen Konfiguration

### Grundlegende Bedienung

1. **Profil auswählen**: Klicken Sie auf eine der beiden Optionen:
   - ☑ Standard-Profil (Scannt nur die Vorderseite)
   - ☑ Duplex-Profil (Scannt Vorder- und Rückseite)

2. **Einstellung speichern**: Klicken Sie auf **"Speichern"**

3. **Programm beenden**: Klicken Sie auf **"Beenden"** oder schließen Sie das Fenster

## 📝 Wichtige Hinweise

### Gegenseitige Ausschließlichkeit

Es ist **nicht möglich**, beide Profile gleichzeitig auszuwählen. Wenn Sie ein Profil auswählen, wird das andere automatisch abgewählt.

### Ungespeicherte Änderungen

Wenn Sie Änderungen vornehmen und das Programm schließen, ohne zu speichern, werden folgende Dialoge angezeigt:

- **Beim Klick auf "Beenden"-Button**: Ein Bestätigungsdialog fragt, ob Sie die Änderungen wirklich verwerfen möchten
- **Beim Schließen des Fensters**: Ein ähnlicher Dialog wird angezeigt

### Keine Änderungen

Wenn Sie keine Änderungen vorgenommen haben und auf "Speichern" klicken, passiert nichts - das ist normales Verhalten.

## 💾 Das passiert beim Speichern

Wenn Sie das profil speichern:

1. Das aktuelle Scanner-Profil wird durch das ausgewählte Profil ersetzt
2. Die Einstellung wird in der Konfiguration gespeichert
3. Ein Erfolgsdialog wird angezeigt
4. Das Programm wird automatisch beendet
5. Die neue Einstellung ist sofort nach Neustart verfügbar

## ⚠️ Fehlermeldungen

Das Programm kann folgende Fehler anzeigen:

| Fehler | Bedeutung | Lösung |
|--------|-----------|--------|
| "Die Konfigurations-Datei konnte nicht geladen werden" | Die config.json ist beschädigt oder fehlt | Kontaktieren Sie Ihren Administrator |
| "Das Verzeichnis für Scanner-Profile konnte nicht gefunden werden" | Der Pfad zu den Scanner-Profilen existiert nicht | Wenden Sie sich an Ihren IT-Administrator |
| "Die erforderlichen Scanner-Profil-Dateien wurden nicht gefunden" | Standard oder Duplex Profil fehlen | Führen Sie eine Neuinstallation durch |
| "Die Änderungen am Scanner-Profil konnten nicht gespeichert werden" | Schreibzugriff auf Profile-Dateien fehlt | Starten Sie das Programm neu oder kontaktieren Sie Ihren Administrator |

## 🔧 Anforderungen

- **Betriebssystem**: Windows 10 oder Windows 11
- **PowerShell**: Version 5.0 oder höher (standardmäßig enthalten)
- **Berechtigungen**: Benutzerberechtigungen ausreichend (keine Admin-Rechte erforderlich)
- **TWAIN-Treiber**: Muss installiert sein

## 💡 Aktuelle Einstellung anzeigen

Die aktuelle Einstellung wird beim Programmstart automatisch angezeigt. Das derzeit aktive Profil wird mit einem Häkchen gekennzeichnet.

## 📞 Support

Bei Problemen oder Fragen kontaktieren Sie bitte Ihren IT-Administrator.
