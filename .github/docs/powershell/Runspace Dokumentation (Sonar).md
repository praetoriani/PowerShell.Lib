# Runspaces in PowerShell

## Einordnung
Runspaces sind die eigentlichen Ausführungsumgebungen von PowerShell. Wenn du `pwsh.exe` startest, erzeugt der Host einen PowerShell-Runspace; jeder Runspace besitzt seinen eigenen Sitzungszustand, seine eigenen Scopes, seine aktuell verfügbaren Befehle und optional Sprach- oder Sicherheitsbeschränkungen. [page:1][web:17][web:18]

Praktisch bedeutet das: Ein Runspace ist nicht einfach nur „ein Thread“, sondern eine vollständige PowerShell-Laufzeitumgebung innerhalb eines Prozesses. Er kann auf einem eigenen Thread laufen, aber das Entscheidende ist die isolierte Session-State-Umgebung, in der Skripte, Variablen, Funktionen und Module verwaltet werden. [page:1][page:2][web:31]

## 1) Was genau sind Runspaces?
Ein Runspace ist die Betriebsumgebung, in der PowerShell-Befehle ausgeführt werden. Microsoft beschreibt ihn als die Umgebung für die von einer Host-Anwendung aufgerufenen Befehle; dazu gehören die aktuell vorhandenen Befehle und Daten sowie aktive Spracheinschränkungen. [page:1]

Man kann sich einen Runspace als „PowerShell-Sitzung im Kleinen“ vorstellen: Er besitzt einen eigenen Session State, eigene Scopes und eine eigene Auflösung von Variablen, Funktionen und Aliases. Zwischen unterschiedlichen Runspaces gibt es keinen direkten gemeinsamen Scope-Container. [page:2][web:18]

Wichtige Abgrenzung:
- **Scope** = Sichtbarkeits- und Lebensdauerbereich von Variablen/Funktionen innerhalb eines Runspace. [page:2]
- **Runspace** = die komplette Ausführungsumgebung. [page:1][web:18]
- **RunspacePool** = ein Pool mehrerer wiederverwendbarer Runspaces für parallele Arbeit. [web:21][web:29]

## 2) Wie funktionieren Runspaces?
Ein Runspace wird erstellt, geöffnet und dann an ein `PowerShell`-Objekt gebunden, das die auszuführenden Commands oder ScriptBlocks enthält. Typischerweise passiert das über `RunspaceFactory.CreateRunspace()` oder für parallele Szenarien über `RunspaceFactory.CreateRunspacePool(...)`. [web:17][web:20][web:21][web:29]

Der grobe Ablauf ist:
1. Runspace oder RunspacePool erzeugen. [web:17][web:21]
2. Optional den Initialzustand definieren, etwa über `InitialSessionState`, um Module, Cmdlets oder Einschränkungen vorzugeben. [page:1]
3. Runspace öffnen. [web:20]
4. `PowerShell`-Instanz erzeugen und den Runspace oder Pool zuweisen. [web:20][web:21]
5. Script/Commands hinzufügen. [web:20][web:21]
6. Synchron per `Invoke()` oder asynchron per `BeginInvoke()` ausführen. [web:21][web:23]
7. Ergebnisse mit `EndInvoke()` abholen und anschließend sauber aufräumen (`Dispose()`, `Close()`). [web:20][web:21][web:29]

Technisch kapselt der Runspace also die PowerShell-Engine samt Session State. Das `PowerShell`-Objekt repräsentiert dagegen den konkreten Ausführungsauftrag, also das, was in diesem Runspace tatsächlich laufen soll. [web:18][web:20]

## 3) Wie kann ich in einem PowerShell-Modul einen Runspace verwenden?
In einem Modul kannst du Runspaces genauso verwenden wie in einem normalen Skript, aber du solltest sie bewusst kapseln. Besonders sinnvoll ist das für Hintergrundverarbeitung, parallele API-Aufrufe, Vorberechnung von Caches, Datei- oder Netzwerk-Scans sowie GUI-nahe Aufgaben mit dedizierten Threads. [page:2][web:24][web:31]

Ein gutes Muster in Modulen ist:
- eine interne Hilfsfunktion zum Erzeugen eines RunspacePools,
- eine interne Worker-Funktion bzw. ein ScriptBlock,
- öffentliche Modulbefehle, die Jobs starten, Status zurückgeben und Ergebnisse einsammeln. [web:21][web:24]

### Beispiel: einfacher Runspace aus einem Modul heraus
```powershell
function Start-InternalRunspaceTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [hashtable]$Variables
    )

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    if ($Variables) {
        foreach ($key in $Variables.Keys) {
            $runspace.SessionStateProxy.SetVariable($key, $Variables[$key])
        }
    }

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($ScriptBlock)

    $handle = $ps.BeginInvoke()

    [pscustomobject]@{
        PowerShell = $ps
        Runspace   = $runspace
        Handle     = $handle
    }
}

function Receive-InternalRunspaceTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Task
    )

    process {
        try {
            $Task.PowerShell.EndInvoke($Task.Handle)
        }
        finally {
            $Task.PowerShell.Dispose()
            $Task.Runspace.Close()
            $Task.Runspace.Dispose()
        }
    }
}
```

Dieses Muster eignet sich für ein Modul, weil der öffentliche Befehl nur ein kontrolliertes Objekt zurückgibt, mit dem der Aufrufer weiterarbeiten kann. Wichtig ist das Aufräumen im `finally`-Block, damit keine offenen Runspaces oder `PowerShell`-Instanzen liegen bleiben. [web:20][web:21][web:29]

### Besser für mehrere Tasks: RunspacePool
Für wiederholte parallele Arbeit ist ein RunspacePool fast immer besser als für jede Aufgabe einen komplett neuen Runspace zu erzeugen. Ein Pool reduziert Erstellungs- und Initialisierungskosten und erlaubt dir, die Parallelität sauber zu begrenzen. [web:21][web:24][web:29]

```powershell
function New-ModuleRunspacePool {
    [CmdletBinding()]
    param(
        [int]$MinRunspaces = 1,
        [int]$MaxRunspaces = [Math]::Max(2, [Environment]::ProcessorCount)
    )

    $pool = [runspacefactory]::CreateRunspacePool($MinRunspaces, $MaxRunspaces)
    $pool.Open()
    return $pool
}
```

In einem größeren Modul lohnt es sich oft, den Pool intern zu cachen und beim Modul-Unload oder explizit per Cleanup-Funktion zu schließen. Das verhindert Leaks und vereinfacht Wiederverwendung. [web:21][web:29]

## 4) Greifen Runspace und Ersteller auf den gleichen Scope zu?
Kurz: **Nein, nicht automatisch.** Jeder Runspace hat seine eigenen Container für Sitzungsstatus und Scopes; auf Sitzungsstatus und Scopes kann nicht über Runspace-Instanzen hinweg direkt zugegriffen werden. [page:2]

Das ist einer der wichtigsten Punkte überhaupt: Ein neuer Runspace erbt nicht einfach deine aktuellen lokalen Variablen, Funktionen oder Script-Scopes so, wie eine normale Funktionsausführung im selben Runspace es tun würde. Wenn der Code im Runspace auf einen Namen zugreift, durchsucht PowerShell nur die Scope-Hierarchie dieses Runspace. [page:2]

### Was ist also sichtbar?
Sichtbar ist nur das, was innerhalb dieses Runspace vorhanden ist, also zum Beispiel:
- Inhalte des InitialSessionState. [page:1]
- Variablen, die du explizit via `SessionStateProxy.SetVariable()` injizierst. [web:20]
- ScriptBlocks, Commands, Parameter und Argumente, die du an die `PowerShell`-Instanz übergibst. [web:21][web:24]
- Module oder Funktionen, die du im Runspace selbst lädst oder definierst. [page:2]

### Wichtige Modul-Besonderheit
Module haben ohnehin einen eigenen Session-State-/Scope-Container, der parallel zum importierenden Scope läuft. Das heißt: Schon ohne Runspaces existiert bei Modulen eine gewisse Scope-Isolation. Ein zusätzlicher Runspace ist also noch einmal eine weitere Isolationsgrenze. [page:2]

### Scope Creep bei RunspacePools
In Praxisbeispielen wird häufig darauf hingewiesen, dass bei `AddScript()` lokaler Scope gezielt aktiviert werden sollte, um unbeabsichtigtes „Scope Creep“ zu vermeiden; dazu kann die `UseLocalScope`-Variante von `AddScript()` genutzt werden. Das ist besonders in langlebigen Pools wichtig, wenn Worker mehrfach verwendet werden. [web:22]

## 5) Wird ein Runspace synchron oder asynchron ausgeführt?
Beides ist möglich. Der Runspace selbst ist zunächst nur die Umgebung; die konkrete Ausführung hängt davon ab, wie du die zugehörige `PowerShell`-Instanz startest. [web:18][web:23]

Typisch gilt:
- `Invoke()` = synchron, der aufrufende Code wartet bis zur Fertigstellung. [web:23]
- `BeginInvoke()` = asynchron, du bekommst ein `IAsyncResult`-Handle zurück und kannst später mit `EndInvoke()` abschließen. [web:20][web:21][web:23]

In vielen Runspace-Beispielen spricht man deshalb von „parallel“ oder „asynchron“, obwohl technisch präziser gesagt werden müsste: **Runspaces ermöglichen parallele bzw. nebenläufige Ausführung, wenn du sie asynchron oder in Pools einsetzt.** Ein einzelner Runspace kann genauso gut synchron benutzt werden. [web:21][web:24][web:31]

## 6) Woher weiß ich, ob der Runspace noch aktiv ist?
Wenn du asynchron mit `BeginInvoke()` arbeitest, bekommst du ein Handle (`IAsyncResult`) zurück. Dessen Eigenschaft `IsCompleted` zeigt dir, ob die Pipeline bereits fertig ist. Genau dieses Muster wird in mehreren Runspace-Beispielen verwendet. [web:21][web:24]

Beispiel:
```powershell
$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({ Start-Sleep -Seconds 5; 'fertig' })

$async = $ps.BeginInvoke()

while (-not $async.IsCompleted) {
    Start-Sleep -Milliseconds 200
}

$result = $ps.EndInvoke($async)
```

Darüber hinaus gibt es mehrere Ebenen von „aktiv“:
- **Pipeline aktiv?** Prüfen über `IAsyncResult.IsCompleted`. [web:21][web:24]
- **Runspace geöffnet?** Über den Runspace-Zustand bzw. ob er noch geöffnet ist; ein geschlossener/disposeter Runspace ist definitiv nicht mehr nutzbar. [web:29]
- **Pool aktiv?** Beim Pool gilt analog: Solange er offen ist, können weitere Aufgaben eingeplant werden. `Close()` schließt alle enthaltenen Runspaces und beendet interne Ressourcen. [web:29]

### Praktisches Task-Objekt
Für Module ist es oft hilfreich, Metadaten zu speichern:
```powershell
[pscustomobject]@{
    Id         = [guid]::NewGuid()
    PowerShell = $ps
    Runspace   = $runspace
    Handle     = $async
    StartedAt  = Get-Date
}
```

Dann kann eine Statusfunktion etwa `Handle.IsCompleted`, Startzeit, Laufzeit und eventuell Fehlerstreams auswerten. Das ist in der Praxis wesentlich robuster als „blind“ auf das Ende zu warten. [web:21][web:24]

## 7) Welche Vorteile bringt die Verwendung von Runspaces?
Der größte Vorteil ist Performance bei nebenläufiger Arbeit innerhalb desselben Prozesses. Runspaces sind typischerweise leichtergewichtig als ein neuer PowerShell-Prozess oder klassische Out-of-Process-Jobs, weil sie im selben Prozess laufen und denselben Host nutzen können. [web:31][page:2]

Weitere Vorteile:
- **Parallele Verarbeitung:** Mehrere unabhängige Aufgaben können gleichzeitig laufen. [web:20][web:21]
- **Wiederverwendung über Pools:** Ein RunspacePool vermeidet wiederholte teure Initialisierung. [web:21][web:29]
- **Mehr Kontrolle:** Du bestimmst InitialSessionState, geladene Module, Variablen, Threadoptionen oder ApartmentState. [page:1][web:20]
- **Gute Integration in Hosts/Module/GUI:** Besonders nützlich in eingebetteten Hosts oder für responsive Oberflächen. [web:20][web:31]

### Typischer Geschwindigkeitsvorteil
Runspaces lohnen sich vor allem dann, wenn du viele ähnliche, voneinander unabhängige Aufgaben hast, etwa Netzwerkabfragen gegen mehrere Systeme oder Dateioperationen in Chargen. Wenn die Aufgaben winzig sind, kann der Verwaltungsaufwand den Gewinn aber auch auffressen. [web:21][web:24]

## 8) Welche Use Cases gibt es?
Runspaces sind ideal für Workloads, die sich in mehrere voneinander unabhängige Einheiten zerlegen lassen. Das ist der klassische Fall für Parallelisierung. [web:21][web:24][web:31]

Typische Use Cases:
- Abfragen vieler Server, APIs oder Geräte parallel. [web:24][web:21]
- Inventarisierung, Health Checks, Ping-/Port-Tests, Remote-Abfragen. [web:24]
- Datei- und Datenverarbeitung in Batches. [web:21]
- GUI-Skripte oder Tools, bei denen die Oberfläche responsiv bleiben soll, während Hintergrundarbeit läuft. [web:20]
- Vorberechnen von Cache-Daten oder Hintergrund-Refresh in Modulen. [web:24]
- Eigene Host-Anwendungen, die PowerShell einbetten. [page:1][web:17]

Weniger geeignet sind Runspaces für stark voneinander abhängige, sequentielle Schritte oder wenn die Hauptkomplexität nicht CPU/IO-Wartezeit, sondern gemeinsame mutable Zustände und Synchronisation sind. Dann erzeugt Parallelisierung schnell mehr Fehlerquellen als Nutzen. [page:2][web:24]

## 9) Kann ich einem Runspace Parameter und/oder Variablen übergeben?
Ja, auf mehreren Wegen. Das ist in der Praxis Standard. [web:20][web:21][web:24]

### Parameter per AddArgument / AddParameter
Wenn du einen ScriptBlock mit `param(...)` definierst, kannst du Werte übergeben:
```powershell
$script = {
    param(
        [string]$ComputerName,
        [int]$Timeout
    )

    Test-Connection -ComputerName $ComputerName -Count 1 -TimeoutSeconds $Timeout
}

$ps = [powershell]::Create()
$ps.RunspacePool = $pool
[void]$ps.AddScript($script)
[void]$ps.AddArgument('server01')
[void]$ps.AddArgument(2)
```
Dieses Muster ist in Runspace-Beispielen sehr verbreitet. [web:21]

Alternativ kannst du bei Inline-Scripts häufig `AddParameter()` nutzen, wie in Praxisbeispielen gezeigt. [web:24]

### Variablen per SessionStateProxy
Wenn du eine Variable direkt im Runspace verfügbar machen willst, kannst du sie vor der Ausführung setzen:
```powershell
$runspace.SessionStateProxy.SetVariable('SyncHash', $syncHash)
```
Genau dieses Vorgehen wird häufig genutzt, um gemeinsam genutzte Strukturen explizit in den Runspace zu injizieren. [web:20]

### Funktionen und Module bereitstellen
Wenn dein Worker bestimmte Funktionen braucht, musst du sie im Runspace definieren oder das entsprechende Modul dort importieren. Dass eine Funktion im aufrufenden Scope existiert, reicht nicht automatisch aus, weil Runspaces keine Scopes teilen. [page:2]

## 10) Kann ein Runspace einen eigenen Exitcode haben?
Nicht im klassischen Sinn wie ein separater Prozess. Ein Runspace ist kein eigenständiger OS-Prozess, sondern eine Ausführungsumgebung innerhalb des aktuellen Prozesses. Deshalb gibt es keinen natürlichen, vom Betriebssystem verwalteten separaten Prozess-Exitcode pro Runspace. [page:1][web:18]

Was du aber sehr wohl machen kannst:
- Einen **fachlichen Rückgabecode** als Zahl oder Objekt zurückgeben. [web:21]
- Fehler über Error-Streams bzw. Exceptions signalisieren. [web:21][web:23]
- Im Ergebnisobjekt selbst Eigenschaften wie `Success`, `ExitCode`, `ErrorMessage` führen. [web:21][web:24]

Ein sinnvolles Muster ist:
```powershell
$script = {
    param([string]$Path)

    try {
        if (-not (Test-Path $Path)) {
            [pscustomobject]@{
                Success  = $false
                ExitCode = 2
                Message  = 'Pfad nicht gefunden'
            }
            return
        }

        [pscustomobject]@{
            Success  = $true
            ExitCode = 0
            Message  = 'OK'
        }
    }
    catch {
        [pscustomobject]@{
            Success  = $false
            ExitCode = 1
            Message  = $_.Exception.Message
        }
    }
}
```

Wenn du wirklich einen Betriebssystem-Exitcode brauchst, ist eher ein separater Prozess oder Job mit eigenem Host passend, nicht bloß ein zusätzlicher Runspace. [page:1][web:31]

## 11) Kann ein Runspace Rückgaben liefern?
Ja, selbstverständlich. Die Ausführungsergebnisse kommen über die Pipeline zurück, und bei asynchroner Ausführung holst du sie mit `EndInvoke()` ab. [web:20][web:21][web:23]

Dabei kann ein Runspace nahezu alles zurückgeben, was auch normale PowerShell-Pipelines zurückgeben können, also Strings, Zahlen, Hashtables, `PSCustomObject`-Objekte oder komplexere .NET-Objekte. [web:21][web:23]

Beispiel:
```powershell
$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    [pscustomobject]@{
        Name = 'TaskA'
        Time = Get-Date
        Ok   = $true
    }
})

$async  = $ps.BeginInvoke()
$result = $ps.EndInvoke($async)
```

Zusätzlich zur normalen Ausgabe gibt es auch getrennte Streams für Fehler, Verbose, Warning usw. In robusten Modulen solltest du daher nicht nur die Rückgabe, sondern auch die Streams und Exceptions auswerten. [web:23]

## 12) Kann ich mit einem Runspace interagieren (IPC?)
Ja, aber man muss sauber zwischen **Interaktion innerhalb desselben Prozesses** und **echter IPC zwischen Prozessen** unterscheiden. Ein Runspace lebt im selben Prozess, daher ist das normalerweise **keine klassische IPC**, sondern In-Process-Kommunikation. [page:1][web:18]

### Was ist möglich?
- Gemeinsame Referenzen auf Objekte, wenn du sie explizit in den Runspace hineinreichst. [web:20][page:2]
- Gemeinsame, threadsichere Datenstrukturen, zum Beispiel synchronisierte Hashtables. Genau so wird es in Praxisbeispielen oft gemacht. [web:20]
- Polling über Statusobjekte oder Ergebnisobjekte. [web:21][web:24]
- Event-/Callback-orientierte Muster auf .NET-Ebene, wenn du selbst hostest. [web:23]

### Beispiel mit synchronisierter Hashtable
```powershell
$syncHash = [hashtable]::Synchronized(@{})
$syncHash.Status = 'Gestartet'

$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable('SyncHash', $syncHash)

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    $SyncHash.Status = 'Läuft'
    Start-Sleep -Seconds 2
    $SyncHash.Result = 42
    $SyncHash.Status = 'Fertig'
})

$handle = $ps.BeginInvoke()
```

Der aufrufende Code kann dann periodisch `$syncHash.Status` oder `$syncHash.Result` prüfen. Das ist eine einfache Form der Interaktion, aber nur dann sinnvoll, wenn die verwendeten Objekte threadsicher sind oder passend synchronisiert werden. [web:20][page:2]

### Vorsicht bei gemeinsamem Zustand
Microsoft weist bei Thread-/Parallel-Szenarien ausdrücklich darauf hin, dass Änderungen an gemeinsam verwendeten Variablen ohne threadsichere Datentypen oder Synchronisationsmechanismen zu Datenbeschädigung führen können. Dieser Hinweis stammt zwar aus dem Kontext von ThreadJobs und `Using:`, gilt vom Prinzip her aber genauso für Runspace-basierte Parallelität innerhalb eines Prozesses. [page:2]

## Architekturverständnis: Runspace, Scope, Modul, Thread
Diese Begriffe werden oft vermischt, daher hier die saubere Einordnung:

| Begriff | Bedeutung | Wichtig für Runspaces |
|--|--|--|
| Runspace | Komplette PowerShell-Ausführungsumgebung | Eigener Session State, eigene Scopes, eigene verfügbare Befehle [page:1][page:2] |
| Scope | Sichtbarkeitsbereich innerhalb eines Runspace | Variablen/Funktionen werden entlang der Scope-Hierarchie gesucht [page:2] |
| Modul | Eigener Scope-/Session-State-Container innerhalb des importierenden Runspace | Modulinterne Elemente sind gekapselt; Exporte werden sichtbar gemacht [page:2] |
| Thread | Technischer Ausführungsfaden des Prozesses | Runspaces können auf separaten Threads laufen, sind aber mehr als nur Threads [web:20][web:31] |
| RunspacePool | Sammlung wiederverwendbarer Runspaces | Standardwerkzeug für skalierbare Parallelisierung [web:21][web:29] |

## Empfehlungen für die Praxis
Wenn du Runspaces produktiv in Modulen oder größeren Skripten einsetzen willst, helfen diese Regeln fast immer:

- Verwende für mehrere ähnliche Aufgaben bevorzugt einen **RunspacePool** statt ständig neue Einzel-Runspaces zu erzeugen. [web:21][web:29]
- Übergib Daten **explizit** per Parametern, `AddArgument()` oder `SessionStateProxy.SetVariable()` statt auf implizite Sichtbarkeit zu hoffen. [web:20][web:21]
- Kapsle Runspace-Management in Hilfsfunktionen oder Klassen, damit Start, Status, Ergebnis und Cleanup an einer Stelle liegen. [web:21][web:24]
- Arbeite mit **PSCustomObject**-Rückgaben statt mit nackten Strings; dann kannst du Status, Dauer, Ergebnis und Fehler strukturiert transportieren. [web:21]
- Dispose/Close immer zuverlässig, idealerweise in `finally`. Offene Runspaces oder Pools führen sonst leicht zu Ressourcenproblemen. [web:20][web:21][web:29]
- Behandle gemeinsamen Zustand als **Synchronisationsproblem**. Ohne threadsichere Datentypen oder klare Besitzverhältnisse entstehen Race Conditions. [page:2][web:20]

## Minimalbeispiel: kompletter paralleler Ablauf mit Pool
```powershell
$pool = [runspacefactory]::CreateRunspacePool(1, 4)
$pool.Open()

$jobs = @()
$script = {
    param([string]$Name)
    Start-Sleep -Milliseconds (Get-Random -Minimum 300 -Maximum 1200)
    [pscustomobject]@{
        Name      = $Name
        ThreadId  = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        Timestamp = Get-Date
    }
}

foreach ($name in 'A','B','C','D','E') {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($script)
    [void]$ps.AddArgument($name)

    $jobs += [pscustomobject]@{
        Name       = $name
        PowerShell = $ps
        Handle     = $ps.BeginInvoke()
    }
}

while ($jobs.Handle.IsCompleted -contains $false) {
    Start-Sleep -Milliseconds 100
}

$results = foreach ($job in $jobs) {
    try {
        $job.PowerShell.EndInvoke($job.Handle)
    }
    finally {
        $job.PowerShell.Dispose()
    }
}

$pool.Close()
$pool.Dispose()

$results
```
Dieses Beispiel zeigt den typischen Lebenszyklus: Pool erstellen, Workload vorbereiten, pro Aufgabe eine `PowerShell`-Instanz erzeugen, asynchron starten, auf `IsCompleted` warten, per `EndInvoke()` Ergebnisse sammeln und anschließend alles sauber freigeben. [web:21][web:24][web:29]

## Häufige Missverständnisse
- **„Ein Runspace teilt automatisch meine Variablen.“** Nein, neue Runspaces haben eigene Session-State- und Scope-Container. [page:2]
- **„Runspace = asynchron.“** Nicht automatisch; asynchron wird es erst durch die gewählte Aufrufmethode wie `BeginInvoke()`. [web:23]
- **„Ein Runspace hat einen Exitcode wie ein Prozess.“** Nein, sinnvoller ist ein eigener Rückgabestatus im Ergebnisobjekt. [page:1][web:18]
- **„Runspaces sind immer schneller.“** Nur wenn die Aufgabe groß genug und gut parallelisierbar ist; sonst frisst das Management den Vorteil auf. [web:24]
- **„Gemeinsame Objekte sind unproblematisch.“** Nur dann, wenn du Synchronisation und Thread-Sicherheit sauber beachtest. [page:2][web:20]

## Fazit für deinen Modul-Kontext
Für PowerShell-Module sind Runspaces besonders dann stark, wenn du kontrollierte, performante Hintergrund- oder Parallelverarbeitung brauchst, ohne für jede Aufgabe einen separaten Prozess hochzuziehen. Der wichtigste mentale Hebel ist: **Runspaces sind isolierte PowerShell-Laufzeitumgebungen, keine bloßen Unter-Sopes deines aktuellen Skripts.** [page:1][page:2][web:31]

Sobald du das verinnerlicht hast, ergibt sich der Rest fast logisch: Daten explizit übergeben, Ergebnisse explizit abholen, Lebenszyklus sauber verwalten und gemeinsamen Zustand nur sehr bewusst zulassen. Für wiederkehrende Parallelität in Modulen ist ein RunspacePool in der Regel die beste Grundlage. [web:21][web:24][web:29]
