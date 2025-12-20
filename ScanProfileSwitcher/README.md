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
5. Das Programm mit dem gescannt wird, muss beendet werden!
6. Erst nach Neustart des Scanner-Programms sind die Änderungen verfügbar!

## ⚠️ Fehlermeldungen

Das Programm kann folgende Fehler anzeigen:

| Fehler | Bedeutung | 
|--------|-----------|
| "Die Konfigurations-Datei konnte nicht geladen werden" | Das Programm kann nicht gestartet werden, da eine wichtige Datei fehlt. |
| "Das Verzeichnis für Scanner-Profile konnte nicht gefunden werden" | Es konnte kein installierter TWAIN-Treiber gefunden werden. |
| "Die erforderlichen Scanner-Profil-Dateien wurden nicht gefunden" | Es fehlen Vorlagen für wichtige Scanner-Profile. |
| "Die Änderungen am Scanner-Profil konnten nicht gespeichert werden" | Es ist kein Schreibzugriff auf Profil-Dateien möglich. |

In den meisten Fällen sollte es helfen, wenn Sie zuerst das eigentliche Scanner-Programm beenden und im Anschluss eine Neusinstallation des TWAIN-Treibers über den Kiosk durchführen. Im Anschluss doppelklicken Sie das **"ScanProfileSwitcher"**-Symbol auf Ihrem Desktop. Sollten nach wie Vor Fehler auftreten, kontaktieren Sie bitte ihre IT-Abteilung. 

## 🔧 Anforderungen

- **Betriebssystem**: Windows 10 oder Windows 11
- **PowerShell**: Version 5.0 oder höher (standardmäßig enthalten)
- **Berechtigungen**: Benutzerberechtigungen ausreichend (keine Admin-Rechte erforderlich)
- **TWAIN-Treiber**: Muss installiert sein

## 💡 Aktuelle Einstellung anzeigen

Die aktuelle Einstellung wird beim Programmstart automatisch angezeigt. Das derzeit aktive Profil wird mit einem Häkchen gekennzeichnet.

## 📞 Support

Bei Problemen oder Fragen kontaktieren Sie bitte Ihre IT-Abteilung.
