# Active Directory Benutzer Export Tool

Ein professionelles PowerShell-Tool zum Export von Active Directory Benutzerdaten mit moderner WPF-Benutzeroberfläche.

## Überblick

Dieses Tool ermöglicht es, Benutzerdaten aus dem Active Directory zu exportieren und als CSV-Datei zu speichern. Es verfügt über eine benutzerfreundliche grafische Oberfläche mit umfassender Fehlerbehandlung.

## Dateien

Das komplette Programm besteht aus folgenden Dateien:

### Hauptskript
- `UserData-LDAP-Export.ps1` - Das Hauptskript mit der kompletten Anwendungslogik

### XAML-Dialoge
- `user-authentication.xaml` - Anmeldedialog für AD-Zugangsdaten
- `error-no-input.xaml` - Fehlerdialog bei leeren Eingabefeldern
- `error-user-invalid.xaml` - Fehlerdialog bei ungültigen Anmeldedaten
- `error-ldap-access.xaml` - Fehlerdialog bei LDAP-Zugriffsproblemen
- `error-csv-export.xaml` - Fehlerdialog bei CSV-Export-Problemen
- `script-finished.xaml` - Erfolgsmeldung nach abgeschlossenem Export

## Voraussetzungen

### System-Anforderungen
- Windows 10/11 oder Windows Server 2016+
- PowerShell 5.1 oder höher
- .NET Framework 4.7.2 oder höher

### PowerShell Module
- **ActiveDirectory** - Wird für AD-Zugriff benötigt
  ```powershell
  # Installation auf Windows 10/11
  Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

  # Installation auf Windows Server
  Install-WindowsFeature RSAT-AD-PowerShell
  ```

### Berechtigungen
- **Domain User** - Mindestberechtigung für AD-Zugriff
- **Leseberechtigung** auf die zu exportierende OU
- **Lokale Schreibberechtigung** für CSV-Export

## Konfiguration

### Globale Variablen im Hauptskript anpassen

Öffnen Sie `UserData-LDAP-Export.ps1` und passen Sie folgende Variablen an:

```powershell
# OU-Pfad für den Export (wird rekursiv durchsucht)
$global:ExportScope = "DC=domain,DC=com"  # Beispiel: "OU=Mitarbeiter,DC=firma,DC=local"

# Zu exportierende Benutzerattribute
$global:ExportAttributes = @(
    'SamAccountName',
    'UserPrincipalName', 
    'GivenName',
    'Surname',
    'DisplayName',
    'EmailAddress',
    # ... weitere Attribute nach Bedarf
)
```

### Beispiel-Konfigurationen

```powershell
# Export aller Benutzer aus einer bestimmten OU
$global:ExportScope = "OU=Users,OU=Company,DC=contoso,DC=com"

# Export aller Benutzer aus der gesamten Domain
$global:ExportScope = "DC=contoso,DC=com"

# Export nur aus einer spezifischen Unterabteilung
$global:ExportScope = "OU=IT,OU=Departments,DC=contoso,DC=com"
```

## Verwendung

### 1. Installation
1. Alle 7 Dateien in dasselbe Verzeichnis kopieren
2. PowerShell als Administrator öffnen
3. Ausführungsrichtlinie setzen (falls erforderlich):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### 2. Programm starten
```powershell
.\UserData-LDAP-Export.ps1
```

### 3. Ablauf des Programms

1. **Anmeldung**: Eingabe der AD-Anmeldedaten
2. **Validierung**: Überprüfung der Anmeldedaten gegen AD
3. **Scope-Test**: Überprüfung des konfigurierten OU-Pfads
4. **Datenexport**: Abruf der Benutzerdaten aus AD
5. **Datei speichern**: Auswahl des Speicherorts für CSV-Datei
6. **Fertigstellung**: Erfolgsmeldung nach abgeschlossenem Export

## Features

### ✅ Umfassende Funktionalität
- **Sichere Authentifizierung** mit AD-Validierung
- **Rekursiver OU-Export** - alle Unterordner werden automatisch durchsucht
- **Konfigurierbare Attribute** - nur benötigte Felder exportieren
- **Deutsche Lokalisierung** - alle Dialoge und CSV-Spalten auf Deutsch

### ✅ Moderne Benutzeroberfläche
- **WPF-basierte Dialoge** mit professionellem Design
- **Intuitive Bedienung** mit klaren Schaltflächen
- **Minimierte Konsole** - nur für Logging sichtbar
- **Responsive Design** - passt sich verschiedenen Bildschirmgrößen an

### ✅ Robuste Fehlerbehandlung
- **Spezifische Fehlerdialoge** für verschiedene Problemtypen
- **Umfassendes Logging** in englischer Sprache für Administratoren
- **Graceful Exit** - sauberes Beenden bei Problemen
- **Input-Validierung** - verhindert leere oder ungültige Eingaben

### ✅ Sicherheit & Compliance
- **SecureString** für Passwort-Handling
- **Minimal Privileges** - nur Lesezugriff auf AD erforderlich
- **Audit Trail** - vollständige Protokollierung aller Aktionen
- **Clean Exit** - keine Passwörter im Speicher nach Programmende

## CSV-Export Details

### Exportierte Spalten (deutsche Bezeichnungen)
- Anmeldename (SamAccountName)
- Benutzerprinzipalname (UserPrincipalName)
- Vorname (GivenName)
- Nachname (Surname)
- Anzeigename (DisplayName)
- E-Mail-Adresse (EmailAddress/Mail)
- Berufsbezeichnung (Title)
- Abteilung (Department)
- Unternehmen (Company)
- Vorgesetzter (Manager - aufgelöst zu DisplayName)
- ... und viele weitere

### CSV-Format
- **Encoding**: UTF-8 (unterstützt deutsche Umlaute)
- **Trennzeichen**: Semikolon (;) - Excel-kompatibel für deutsche Systeme
- **Dateiname**: Automatisch mit Timestamp (z.B. AD-Benutzer-Export-20250921-1430.csv)

## Troubleshooting

### Häufige Probleme

#### "ActiveDirectory module not available"
```powershell
# Lösung: RSAT-Tools installieren
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

#### "XAML file not found"
- Stellen Sie sicher, dass alle 7 Dateien im selben Verzeichnis sind
- Überprüfen Sie die Dateiberechtigungen

#### "AD scope access test failed"
- Überprüfen Sie den OU-Pfad in `$global:ExportScope`
- Stellen Sie sicher, dass Sie Leseberechtigung auf die OU haben
- Testen Sie die Netzwerkverbindung zum Domain Controller

#### "Credential validation failed"
- Überprüfen Sie Benutzername und Passwort
- Stellen Sie sicher, dass das Konto nicht gesperrt ist
- Überprüfen Sie die Domain-Verbindung

### Erweiterte Konfiguration

#### Zusätzliche AD-Attribute hinzufügen
```powershell
$global:ExportAttributes = @(
    # Standard-Attribute
    'SamAccountName', 'DisplayName', 'EmailAddress',

    # Erweiterte Attribute
    'EmployeeID', 'EmployeeNumber', 'extensionAttribute1',
    'telephoneNumber', 'mobile', 'physicalDeliveryOfficeName'
)
```

#### Mehrere OUs exportieren
Für mehrere OUs müssen Sie das Skript mehrmals ausführen oder die Logik entsprechend anpassen.

## Support & Weiterentwicklung

### Logging
Das Programm erstellt detaillierte Logs in der Konsole:
- **INFO**: Normale Programmschritte
- **SUCCESS**: Erfolgreiche Operationen
- **WARNING**: Warnungen (nicht kritisch)
- **ERROR**: Fehler die das Programm beenden

### Anpassungen
Das Programm ist modular aufgebaut und kann erweitert werden um:
- Weitere Exportformate (Excel, JSON, XML)
- Filter für bestimmte Benutzergruppen
- Automatisierte Exports (Scheduling)
- E-Mail-Versand der Ergebnisse

## Lizenz & Copyright

Erstellt von Praetoriani
Website: https://github.com/praetoriani
Version: 1.00.00

Dieses Tool ist für den internen Gebrauch entwickelt und kann frei angepasst werden.
