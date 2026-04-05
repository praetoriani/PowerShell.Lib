<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***

# 📘 PowerShell Classes – Vollständige Dokumentation

## Von den Grundlagen bis zur Expertenstufe


***

## Was sind PowerShell Classes?

Eine **Klasse** (engl. *class*) ist ein Blueprint – eine Vorlage – aus der zur Laufzeit beliebig viele Objekte (sog. *Instanzen*) erzeugt werden können. Jedes dieser Objekte hat dieselbe Struktur (Eigenschaften und Methoden), aber individuelle Werte.  Ab **PowerShell 5.0** unterstützt PowerShell eine formale, direkt in der Skriptsprache integrierte Syntax für Klassen – zuvor musste man dafür auf eingebetteten C\#-Code zurückgreifen.

Der entscheidende Unterschied zu einfachen Hashtabellen oder `PSCustomObject`-Objekten liegt in der **Typsicherheit**, der **Wiederverwendbarkeit** durch Vererbung und dem klar definierten **Verhalten** durch Methoden. Klassen sind damit das Kernkonzept der objektorientierten Programmierung (OOP) – nun nativ in PowerShell verfügbar.

***

## Wann und warum Classes verwenden?

Bevor man lernt, *wie* man Klassen definiert, muss man verstehen, *warum* man sie überhaupt einsetzt. Ohne Klassen löst man wiederkehrende Probleme oft mit Hashtabellen oder `PSCustomObject`. Klassen bieten jedoch strukturelle Vorteile, die mit zunehmender Komplexität eines Projekts unverzichtbar werden.


| Szenario | Ohne Class | Mit Class |
| :-- | :-- | :-- |
| Datenstruktur definieren | `[hashtable]` / `PSCustomObject` | Typsichere Klasse mit deklarierten Eigenschaften |
| Verhalten kapseln | Separate Funktionen | Methoden direkt in der Klasse |
| Wiederverwendung | Copy-Paste | Vererbung |
| Typenprüfung | Keine | Starke .NET-Typisierung |
| DSC-Ressourcen | Eingeschränkt | Klassen als DSC-Ressource definierbar |
| Eigene Exceptions | Nicht möglich | `class MyException : Exception {}` |

Die Microsoft-Dokumentation nennt folgende **unterstützte Szenarien** explizit:

- Benutzerdefinierte Typen mit OOP-Semantik (Klassen, Eigenschaften, Methoden, Vererbung)
- Definition von DSC-Ressourcen direkt in PowerShell
- Benutzerdefinierte Attribute für Variablen und Parameter
- Benutzerdefinierte Ausnahmen (Exceptions), die per Typname gefangen werden können

***

## Grundlegende Syntax einer Klasse

Die allgemeine Definitionssyntax lautet:

```powershell
class <Klassenname> [: [<Basisklasse>][,<Interface-Liste>]] {
    [[<Attribut>] [hidden] [static] <Eigenschaftsdefinition> ...]
    [<Klassenname>([<Konstruktor-Parameter>]) { <Konstruktorrumpf> } ...]
    [[<Attribut>] [hidden] [static] <Methodendefinition> ...]
}
```

Das kleinstmögliche, lauffähige Beispiel ist:

```powershell
class Device {
    [string]$Brand
}

$dev = [Device]::new()
$dev.Brand = "Fabrikam, Inc."
$dev
```

**Ausgabe:**

```
Brand
-----
Fabrikam, Inc.
```


***

## Eigenschaften (Properties)

Eigenschaften sind **typisierte Variablen**, die im Gültigkeitsbereich einer Klasse deklariert werden. Jede Eigenschaft kann einen beliebigen .NET-Typ oder auch eine andere selbst definierte Klasse als Typ haben.

```powershell
class Benutzer {
    [string]  $Benutzername
    [int]     $ID
    [datetime]$Erstellt
    [bool]    $IstAktiv = $true   # Standardwert direkt bei Deklaration
}
```


### `hidden` – Versteckte Eigenschaften

Das Schlüsselwort `hidden` blendet eine Eigenschaft aus der normalen Anzeige und aus `Get-Member` aus – sie ist dennoch öffentlich zugänglich, nur nicht sofort sichtbar.

```powershell
class Konto {
    [string] $Name
    hidden [string] $Passwort   # Nicht in Get-Member sichtbar ohne -Force
}
```

Um hidden-Member anzuzeigen: `Get-Member -Force`

### `static` – Statische Eigenschaften

Statische Eigenschaften gehören **der Klasse selbst**, nicht einzelnen Instanzen. Sie existieren für die gesamte Sitzung und werden für alle Instanzen geteilt.

```powershell
class Zaehler {
    static [int] $AnzahlInstanzen = 0
    [string] $Name

    Zaehler([string]$name) {
        $this.Name = $name
        [Zaehler]::AnzahlInstanzen++
    }
}

$a = [Zaehler]::new("Alpha")
$b = [Zaehler]::new("Beta")
[Zaehler]::AnzahlInstanzen   # Ausgabe: 2
```


***

## Konstruktoren

Ein **Konstruktor** ist eine spezielle Methode, die beim Erstellen einer Instanz automatisch ausgeführt wird. Er hat denselben Namen wie die Klasse und keinen Rückgabetyp.  Klassen können mehrere Konstruktoren mit unterschiedlichen Parameterlisten haben – sogenannte **Überladungen**.

```powershell
class Buch {
    [string] $Titel
    [string] $Autor
    [int]    $Seiten

    # Standard-Konstruktor (keine Parameter)
    Buch() {
        $this.Titel  = "Unbekannt"
        $this.Autor  = "Unbekannt"
        $this.Seiten = 0
    }

    # Konstruktor mit Parametern
    Buch([string]$titel, [string]$autor, [int]$seiten) {
        $this.Titel  = $titel
        $this.Autor  = $autor
        $this.Seiten = $seiten
    }

    # Convenience-Konstruktor via Hashtable
    Buch([hashtable]$props) {
        foreach ($key in $props.Keys) {
            $this.$key = $props[$key]
        }
    }
}
```


### Drei Wege, eine Instanz zu erstellen[^1_1]

```powershell
# Methode 1: Über ::new()
$b1 = [Buch]::new("Der Hobbit", "J.R.R. Tolkien", 310)

# Methode 2: Über New-Object (älterer Stil)
$b2 = New-Object -TypeName Buch -ArgumentList "1984", "Orwell", 328

# Methode 3: Über Hashtabellen-Syntax (nur mit Standardkonstruktor)
$b3 = [Buch]@{ Titel = "Dune"; Autor = "Herbert"; Seiten = 412 }
```


### Die Shared-Init-Pattern

Da Konstruktoren sich in PowerShell nicht gegenseitig aufrufen können (keine Konstruktorkette), empfiehlt sich das **Init-Muster**: alle Konstruktoren delegieren an eine gemeinsame `hidden`-Methode.

```powershell
class Produkt {
    [string] $Name
    [double] $Preis

    Produkt()                              { $this.Init(@{}) }
    Produkt([string]$n, [double]$p)        { $this.Init(@{Name=$n; Preis=$p}) }
    Produkt([hashtable]$props)             { $this.Init($props) }

    hidden [void] Init([hashtable]$props) {
        foreach ($k in $props.Keys) { $this.$k = $props[$k] }
    }
}
```


***

## Methoden

Methoden definieren das **Verhalten** einer Klasse – also welche Aktionen Objekte dieser Klasse ausführen können. Jede Methode muss einen Rückgabetyp deklarieren; wenn sie nichts zurückgibt, lautet dieser `[void]`.

```powershell
class Rechner {
    [double] $Wert

    Rechner([double]$startwert) {
        $this.Wert = $startwert
    }

    [double] Addiere([double]$zahl) {
        return $this.Wert + $zahl
    }

    [double] Multipliziere([double]$zahl) {
        return $this.Wert * $zahl
    }

    [void] Setze([double]$neuerWert) {
        $this.Wert = $neuerWert
    }

    [string] ToString() {
        return "Rechner mit Wert: $($this.Wert)"
    }
}

$r = [Rechner]::new(10)
$r.Addiere(5)      # 15
$r.Multipliziere(3) # 30
"$r"               # "Rechner mit Wert: 10"
```


### Wichtige Regeln für Methoden

- In Klassenmethoden wird **nichts automatisch in die Pipeline geschrieben** – nur explizit per `return`.
- Fehler müssen mit `throw` signalisiert werden – `Write-Error` wird nicht weitergegeben.
- Die automatische Variable `$this` verweist immer auf die aktuelle Instanz.
- `$PSBoundParameters` und `$PSCmdlet` sind in Methoden **nicht** zu verwenden.


### Methoden-Überladungen

Mehrere Methoden mit demselben Namen, aber unterschiedlichen Parameterlisten, nennt man **Überladungen**.

```powershell
class Gruss {
    [string] Sag()                       { return "Hallo!" }
    [string] Sag([string]$name)          { return "Hallo, $name!" }
    [string] Sag([string]$name, [int]$n) { return ("Hallo, $name! " * $n).Trim() }
}

$g = [Gruss]::new()
$g.Sag()                    # Hallo!
$g.Sag("Welt")              # Hallo, Welt!
$g.Sag("Welt", 3)           # Hallo, Welt! Hallo, Welt! Hallo, Welt!
```


### Statische Methoden

Statische Methoden werden direkt über den Klassennamen aufgerufen – ohne eine Instanz zu erstellen.  Die `$this`-Variable steht in statischen Methoden **nicht** zur Verfügung.

```powershell
class MathHelfer {
    static [double] KreisFlaeche([double]$radius) {
        return [Math]::PI * $radius * $radius
    }
    static [double] Potenz([double]$basis, [int]$exp) {
        return [Math]::Pow($basis, $exp)
    }
}

[MathHelfer]::KreisFlaeche(5)    # 78.5398...
[MathHelfer]::Potenz(2, 10)      # 1024
```


***

## Vererbung (Inheritance)

Vererbung ist das **mächtigste Feature** von PowerShell Classes. Eine **abgeleitete Klasse** (Subklasse / Child) erbt alle Eigenschaften und Methoden ihrer **Basisklasse** (Superklasse / Parent) und kann diese erweitern oder überschreiben.

PowerShell unterstützt **keine Mehrfachvererbung** – eine Klasse kann immer nur von genau einer Basisklasse erben. Allerdings ist die Vererbung transitiv, d.h. Klassen können Ketten bilden.

```powershell
# Basisklasse
class Tier {
    [string] $Name
    [int]    $Alter

    Tier([string]$name, [int]$alter) {
        $this.Name  = $name
        $this.Alter = $alter
    }

    [string] Laut() {
        return "..."
    }

    [string] Beschreibung() {
        return "$($this.Name) ist $($this.Alter) Jahre alt und macht: $($this.Laut())"
    }
}

# Abgeleitete Klasse – erbt von Tier
class Hund : Tier {
    [string] $Rasse

    # Konstruktor ruft Basisklassen-Konstruktor mit :base() auf
    Hund([string]$name, [int]$alter, [string]$rasse) : base($name, $alter) {
        $this.Rasse = $rasse
    }

    # Methode überschreiben (Override)
    [string] Laut() {
        return "Wuff!"
    }

    # Neue Methode der abgeleiteten Klasse
    [string] Apportiere() {
        return "$($this.Name) bringt den Ball zurück!"
    }
}

class Katze : Tier {
    Katze([string]$name, [int]$alter) : base($name, $alter) {}

    [string] Laut() {
        return "Miau!"
    }
}

$hund  = [Hund]::new("Bello", 3, "Labrador")
$katze = [Katze]::new("Minka", 5)

$hund.Beschreibung()    # Bello ist 3 Jahre alt und macht: Wuff!
$katze.Beschreibung()   # Minka ist 5 Jahre alt und macht: Miau!
$hund.Apportiere()      # Bello bringt den Ball zurück!
```


### Der `:base()`-Aufruf

Beim Definieren eines Konstruktors in der abgeleiteten Klasse wird der Basisklassen-Konstruktor mit `: base(<Parameter>)` aufgerufen. Dies stellt sicher, dass die geerbten Eigenschaften korrekt initialisiert werden.

### Methoden überschreiben

Eine abgeleitete Klasse kann jede geerbte Methode überschreiben, indem sie sie mit denselben Parametertypen neu definiert. Der Rückgabetyp darf dabei abweichen.

***

## Abstrakte und Interface-ähnliche Muster

PowerShell unterstützt keine echten abstrakten Klassen oder Interfaces in der Skriptsprache selbst – diese müssen in C\# definiert werden.  Man kann jedoch ähnliche Muster nachbilden, indem Basisklassen-Methoden einen `throw` auslösen, der erzwingt, dass abgeleitete Klassen die Methode implementieren müssen.

```powershell
class AbstrakteBasisklasse {
    [string] Berechne() {
        throw [System.NotImplementedException]::new(
            "Methode 'Berechne' muss in der abgeleiteten Klasse implementiert werden!"
        )
    }
}

class Quadrat : AbstrakteBasisklasse {
    [double] $Seite

    Quadrat([double]$seite) { $this.Seite = $seite }

    [string] Berechne() {
        $flaeche = $this.Seite * $this.Seite
        return "Quadrat mit Seite $($this.Seite): Fläche = $flaeche"
    }
}

$q = [Quadrat]::new(4)
$q.Berechne()   # Quadrat mit Seite 4: Fläche = 16
```


***

## `$this` – Die Instanz-Referenz

`$this` ist die zentrale automatische Variable in Klassenmethoden. Sie verweist immer auf die aktuelle Instanz des Objekts und ermöglicht den Zugriff auf alle Eigenschaften und anderen Methoden der Klasse.

```powershell
class Temperatur {
    [double] $Celsius

    Temperatur([double]$c) { $this.Celsius = $c }

    [double] InFahrenheit()  { return ($this.Celsius * 9/5) + 32 }
    [double] InKelvin()      { return $this.Celsius + 273.15 }

    [string] ToString() {
        return "$($this.Celsius)°C = $($this.InFahrenheit())°F = $($this.InKelvin()) K"
    }
}

$t = [Temperatur]::new(100)
"$t"   # 100°C = 212°F = 373.15 K
```


***

## Praktische Anwendungsbeispiele

### Beispiel 1: Konfigurations-Manager

Ein klassischer Anwendungsfall ist das Kapseln von Konfigurationslogik. Statt Hashtabellen durch Skripte zu reichen, wird die Konfiguration als typisiertes Objekt modelliert:

```powershell
class AppKonfiguration {
    [string]  $Umgebung
    [string]  $LogPfad
    [int]     $Timeout
    [bool]    $DebugModus
    hidden [hashtable] $InterneEinstellungen

    AppKonfiguration() {
        $this.Umgebung  = "Produktion"
        $this.LogPfad   = "C:\Logs"
        $this.Timeout   = 30
        $this.DebugModus = $false
        $this.InterneEinstellungen = @{}
    }

    AppKonfiguration([string]$umgebung) {
        $this.Umgebung  = $umgebung
        $this.LogPfad   = "C:\Logs\$umgebung"
        $this.Timeout   = if ($umgebung -eq "Entwicklung") { 120 } else { 30 }
        $this.DebugModus = ($umgebung -eq "Entwicklung")
        $this.InterneEinstellungen = @{}
    }

    [void] SetzeEinstellung([string]$key, [object]$value) {
        $this.InterneEinstellungen[$key] = $value
    }

    [object] HoleEinstellung([string]$key) {
        if ($this.InterneEinstellungen.ContainsKey($key)) {
            return $this.InterneEinstellungen[$key]
        }
        throw "Einstellung '$key' nicht gefunden."
    }

    [string] ToString() {
        return "[AppKonfiguration] Umgebung=$($this.Umgebung), Debug=$($this.DebugModus)"
    }
}

$cfg = [AppKonfiguration]::new("Entwicklung")
$cfg.SetzeEinstellung("APIKey", "abc123")
"$cfg"
$cfg.HoleEinstellung("APIKey")
```


### Beispiel 2: Logging-Klasse für Skripte

```powershell
class Logger {
    [string] $LogDatei
    [string] $Praefix
    hidden static [Logger] $Instanz = $null

    hidden Logger([string]$pfad, [string]$praefix) {
        $this.LogDatei = $pfad
        $this.Praefix  = $praefix
    }

    # Singleton-Pattern
    static [Logger] HoleInstanz([string]$pfad, [string]$praefix) {
        if ($null -eq [Logger]::Instanz) {
            [Logger]::Instanz = [Logger]::new($pfad, $praefix)
        }
        return [Logger]::Instanz
    }

    [void] Info([string]$nachricht) {
        $this.Schreibe("INFO", $nachricht)
    }

    [void] Warnung([string]$nachricht) {
        $this.Schreibe("WARN", $nachricht)
    }

    [void] Fehler([string]$nachricht) {
        $this.Schreibe("ERROR", $nachricht)
        Write-Warning $nachricht
    }

    hidden [void] Schreibe([string]$level, [string]$nachricht) {
        $zeitstempel = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $zeile = "[$zeitstempel] [$level] [$($this.Praefix)] $nachricht"
        Add-Content -Path $this.LogDatei -Value $zeile
        Write-Verbose $zeile
    }
}

$log = [Logger]::HoleInstanz("C:\Logs\app.log", "MeinSkript")
$log.Info("Skript gestartet")
$log.Warnung("Kein Netzwerk gefunden")
$log.Fehler("Verbindung fehlgeschlagen")
```


### Beispiel 3: Benutzerverwaltung mit Vererbung

Ein praxisnahes Szenario aus der IT-Administration – Benutzertypen hierarchisch modellieren:

```powershell
class ADBenutzer {
    [string] $SamAccountName
    [string] $Anzeigename
    [string] $Email
    [bool]   $Aktiviert

    ADBenutzer([string]$sam, [string]$name, [string]$email) {
        $this.SamAccountName = $sam
        $this.Anzeigename    = $name
        $this.Email          = $email
        $this.Aktiviert      = $true
    }

    [void] Deaktiviere() {
        $this.Aktiviert = $false
        Write-Output "Benutzer '$($this.SamAccountName)' deaktiviert."
    }

    [hashtable] AlsHashtable() {
        return @{
            SamAccountName = $this.SamAccountName
            DisplayName    = $this.Anzeigename
            EmailAddress   = $this.Email
            Enabled        = $this.Aktiviert
        }
    }

    [string] ToString() {
        return "$($this.Anzeigename) <$($this.Email)>"
    }
}

class DienstBenutzer : ADBenutzer {
    [string] $DienstName
    [string] $Beschreibung

    DienstBenutzer([string]$sam, [string]$dienstName, [string]$email)
        : base($sam, "SVC-$dienstName", $email) {
        $this.DienstName    = $dienstName
        $this.Beschreibung  = "Dienstkonto für $dienstName"
    }

    [hashtable] AlsHashtable() {
        $ht = ([ADBenutzer]$this).AlsHashtable()
        $ht["Description"] = $this.Beschreibung
        $ht["PasswordNeverExpires"] = $true
        return $ht
    }
}

$user = [ADBenutzer]::new("jdoe", "John Doe", "j.doe@firma.de")
$svc  = [DienstBenutzer]::new("svc-backup", "BackupService", "svc@firma.de")

"$user"
"$svc"
$svc.AlsHashtable()
```


### Beispiel 4: Klasse als DSC-Ressource

Klassen sind das Fundament für **class-based DSC resources**. Die Struktur ist klar vorgegeben:

```powershell
[DscResource()]
class DateiVorhanden {
    [DscProperty(Key)]
    [string] $Pfad

    [DscProperty(Mandatory)]
    [string] $Inhalt

    [DscProperty(NotConfigurable)]
    [bool] $Existiert

    [DateiVorhanden] Get() {
        $this.Existiert = Test-Path -Path $this.Pfad
        return $this
    }

    [bool] Test() {
        return (Test-Path -Path $this.Pfad) -and
               ((Get-Content $this.Pfad -Raw) -eq $this.Inhalt)
    }

    [void] Set() {
        Set-Content -Path $this.Pfad -Value $this.Inhalt -Encoding UTF8
    }
}
```


***

## Klassen in Modulen verwenden

Klassen werden von `Import-Module` **nicht automatisch** exportiert. Um Klassen aus einem Modul nutzbar zu machen, gibt es zwei Wege:

### Weg 1: `using module`

```powershell
# Am Anfang des Skripts, das die Klassen nutzen soll:
using module .\MeinModul.psm1

$obj = [MeineKlasse]::new()
```


### Weg 2: TypeAccelerators (empfohlen für Module)

Durch das Registrieren von Typen als TypeAccelerators werden Klassen beim `Import-Module` sofort verfügbar – ohne `using`-Anweisung:

```powershell
# Am Ende der .psm1-Datei, nach allen Klassendefinitionen:
$ExportierbareTypen = @([MeineKlasse], [AndereKlasse])

$TypeAcceleratorsKlasse = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)

foreach ($Typ in $ExportierbareTypen) {
    $TypeAcceleratorsKlasse::Add($Typ.FullName, $Typ)
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Typ in $ExportierbareTypen) {
        $TypeAcceleratorsKlasse::Remove($Typ.FullName)
    }
}.GetNewClosure()
```


***

## Parallele Ausführung und `[NoRunspaceAffinity]`

Standardmäßig ist eine PowerShell-Klasse an den **Runspace** gebunden, in dem sie erstellt wurde. Das macht die Verwendung in `ForEach-Object -Parallel` gefährlich – Methodenaufrufe werden in den Original-Runspace zurückgeleitet, was zu Deadlocks oder Zustandskorruption führen kann.

Ab **PowerShell 7.4** löst das Attribut `[NoRunspaceAffinity()]` dieses Problem:

```powershell
# UNSICHER für Parallel-Ausführung (Standard)
class UnsichereKlasse {
    static [string] VerarbeiteDaten([string]$wert) {
        return $wert.ToUpper()
    }
}

# SICHER für Parallel-Ausführung (PS 7.4+)
[NoRunspaceAffinity()]
class SichereKlasse {
    static [string] VerarbeiteDaten([string]$wert) {
        return $wert.ToUpper()
    }
}

# Verwendung in paralleler Pipeline:
$safe = [SichereKlasse]::new()
1..10 | ForEach-Object -Parallel {
    ($using:safe)::VerarbeiteDaten("wert $_")
}
```


***

## Bekannte Einschränkungen

Wer mit C\# vertraut ist, wird einige Unterschiede bemerken. PowerShell Classes haben bestimmte Limitierungen, für die es teils Workarounds gibt:


| Einschränkung | Workaround |
| :-- | :-- |
| Keine echten privaten Member | `hidden` Keyword zur Verschleierung |
| Keine Mehrfachvererbung | Transitive Vererbungskette nutzen |
| Keine abstrakten Klassen/Interfaces nativ | In C\# definieren und als Assembly einbinden |
| Keine Standardwerte in Methodenparametern | `Update-TypeData` im statischen Konstruktor |
| Keine Validierungsattribute in Methodenparametern | Parameter im Methodenrumpf neu zuweisen |
| Klassen können nicht neu geladen werden | Neue PowerShell-Sitzung starten |
| Klassen werden nicht automatisch von `Import-Module` exportiert | `using module` oder TypeAccelerators |
| `[ref]`-Typ nicht als Klassenmember nutzbar | Keinen bekannten Workaround |


***

## Schnellreferenz: Alle Schlüsselwörter

```powershell
class MeineKlasse : BasisKlasse {

    # --- Eigenschaften ---
    [string]        $OeffentlicheEigenschaft         # Normal, öffentlich
    hidden [int]    $VersteckteEigenschaft            # Nicht in Get-Member
    static [int]    $KlassenEigenschaft               # Gehört der Klasse, nicht der Instanz
    hidden static [string] $PrivatStatisch            # Beides kombiniert

    # --- Konstruktoren ---
    MeineKlasse()                    { }              # Standard-Konstruktor
    MeineKlasse([string]$p)          { }              # Überladener Konstruktor
    MeineKlasse([int]$x) : base($x)  { }              # Mit Basisklassen-Aufruf

    # --- Methoden ---
    [string] OeffentlicheMethode()   { return "" }    # Öffentlich, gibt string zurück
    [void]   AktionOhneRueckgabe()   { }              # Kein Rückgabewert
    hidden [bool] InternePruefung()  { return $true } # Verborgen
    static [string] KlassenMethode() { return "" }    # Statisch, kein $this

    # --- $this ---
    [string] BeispielMitThis() {
        return $this.OeffentlicheEigenschaft          # Zugriff auf eigene Eigenschaften
    }
}
```


***

## Vererbungshierarchie verstehen

```
BasisKlasse
    │
    ├── KindKlasseA              ← erbt alles von BasisKlasse
    │       │
    │       └── EnkelKlasseA1   ← erbt von KindKlasseA (transitiv auch BasisKlasse)
    │
    └── KindKlasseB              ← erbt alles von BasisKlasse, überschreibt Methoden
```

Diese Hierarchie ist identisch zu dem, was man aus C\#, Java oder Python kennt – und ermöglicht es, generische Logik in der Basisklasse zu platzieren und spezifisches Verhalten in den Kindklassen zu implementieren.

***

## Best Practices für PowerShell Classes

- **Immer Typen deklarieren**: `[string]$Name` statt `$Name` – erhöht die Robustheit
- **`ToString()` überschreiben**: Macht Objekte in Strings und `Write-Output` nützlich lesbar
- **`Init()`-Pattern nutzen**: Gemeinsame Initialisierungslogik in eine `hidden`-Methode auslagern
- **`throw` statt `Write-Error`**: In Methoden muss mit `throw` gearbeitet werden
- **Statische Methoden für Utilities**: Logik ohne Instanzstatus als `static` deklarieren
- **Klassen in separaten `.psm1`-Dateien**: Klare Trennung von Klassen und Funktionen
- **`using module` am Skriptanfang**: Sichert korrekte IntelliSense-Unterstützung in VS Code
- **`[NoRunspaceAffinity()]` bei Parallelisierung**: Pflicht in PS 7.4+ für parallele Szenarien

***

