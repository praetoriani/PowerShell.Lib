# PowerShell Runspaces – Vollständige Dokumentation

> **Autor:** Generiert mit Perplexity AI  
> **Datum:** April 2026  
> **PowerShell-Version:** 5.1 / 7.x (Core)  
> **Zielgruppe:** PowerShell-Entwickler mit Grundkenntnissen

---

## Inhaltsverzeichnis

1. [Was sind Runspaces?](#1-was-sind-runspaces)
2. [Wie funktionieren Runspaces?](#2-wie-funktionieren-runspaces)
3. [Runspaces in einem PowerShell-Modul verwenden](#3-runspaces-in-einem-powershell-modul-verwenden)
4. [Scope und Variablen-Zugriff](#4-scope-und-variablen-zugriff)
5. [Synchrone vs. asynchrone Ausführung](#5-synchrone-vs-asynchrone-ausführung)
6. [Status eines Runspace prüfen](#6-status-eines-runspace-prüfen)
7. [Vorteile von Runspaces](#7-vorteile-von-runspaces)
8. [Use Cases für Runspaces](#8-use-cases-für-runspaces)
9. [Parameter und Variablen übergeben](#9-parameter-und-variablen-übergeben)
10. [Exitcode eines Runspace](#10-exitcode-eines-runspace)
11. [Rückgabewerte aus einem Runspace](#11-rückgabewerte-aus-einem-runspace)
12. [Interaktion mit einem Runspace (IPC)](#12-interaktion-mit-einem-runspace-ipc)

---

## 1. Was sind Runspaces?

### Definition

Ein **Runspace** ist in PowerShell die grundlegende Ausführungsumgebung (Execution Environment), innerhalb derer Befehle und Skripte ausgeführt werden. Technisch gesehen ist ein Runspace ein isolierter, eigenständiger Container, der Folgendes kapselt:

- Den aktuellen **Zustand der PowerShell-Session** (Variablen, Funktionen, Aliases, Module)
- Die verfügbaren **Befehle und Cmdlets** (InitialSessionState)
- Den aktuellen **Execution Context** (Scope-Stack, Aufrufstack)
- Die **Sprachbeschränkungen** (Language Mode, z. B. `ConstrainedLanguage`)

Jede interaktive PowerShell-Konsole, jedes Skript und jeder `Start-Job`-Hintergrundauftrag läuft **bereits in einem Runspace** – man hat ihn nur meist nicht bewusst als solchen wahrgenommen. Wenn du eine PowerShell-Konsole öffnest, erstellt der Host (z. B. `powershell.exe` oder `pwsh.exe`) intern automatisch einen Standard-Runspace für dich.

### Herkunft und technische Basis

Runspaces sind kein reines PowerShell-Konzept, sondern stammen aus dem **.NET-Framework** (Namespace `System.Management.Automation.Runspaces`). PowerShell ist vollständig in .NET implementiert, und Runspaces sind die zugrunde liegende Abstraktion, die das Hosting von PowerShell in beliebigen .NET-Anwendungen ermöglicht. Die Kernklassen sind:

| Klasse | Beschreibung |
|--------|-------------|
| `System.Management.Automation.Runspaces.Runspace` | Basisklasse, repräsentiert einen einzelnen Runspace |
| `System.Management.Automation.Runspaces.RunspaceFactory` | Fabrik-Klasse zum Erstellen von Runspaces und Runspace-Pools |
| `System.Management.Automation.PowerShell` | Repräsentiert eine PowerShell-Pipeline, die in einem Runspace ausgeführt wird |
| `System.Management.Automation.Runspaces.InitialSessionState` | Definiert den Anfangszustand eines Runspace |
| `System.Management.Automation.Runspaces.RunspacePool` | Pool mehrerer Runspaces für parallele Verarbeitung |

### Abgrenzung zu anderen Parallelisierungskonzepten

| Konzept | Prozess | Thread | Isolation | Overhead | Kommunikation |
|---------|---------|--------|-----------|----------|---------------|
| `Start-Job` | Neuer Prozess | Eigener Thread | Vollständig | Hoch (neuer Prozess + Serialisierung) | Serialisierung (CLIXML) |
| `Start-ThreadJob` | Gleicher Prozess | Eigener Thread | Mittel (SharedState möglich) | Niedrig | Direkte .NET-Objekte |
| **Runspace (manuell)** | Gleicher Prozess | Eigener Thread | Konfigurierbar | Sehr niedrig | Direkte .NET-Objekte, SharedVariables |
| `ForEach-Object -Parallel` | Gleicher Prozess | Thread-Pool | Konfigurierbar | Niedrig | `$using:`-Scope |
| Externer Prozess | Neuer Prozess | - | Vollständig | Sehr hoch | Pipes, Named Pipes, Sockets |

> **Fazit:** Runspaces bieten das beste Verhältnis aus Leistung, Flexibilität und Isolation für parallele Verarbeitung innerhalb von PowerShell.

---

## 2. Wie funktionieren Runspaces?

### Das grundlegende Modell

Runspaces arbeiten nach dem **Thread-Pool-Modell** des .NET CLR. Wenn du einen neuen Runspace erstellst und öffnest, reserviert .NET einen Thread aus dem verwalteten Thread-Pool (oder erstellt einen neuen, falls nötig). Dieser Thread bleibt für den Runspace reserviert, bis dieser geschlossen und disposed wird.

```
[Haupt-Prozess: pwsh.exe / dein Skript]
│
├─ [Haupt-Runspace]      ← Dein normaler PS-Scope
│     ├── Variablen, Funktionen, Module
│     └── Pipeline (Cmdlets)
│
├─ [Runspace 2]          ← Manuell erstellter Hintergrund-Runspace
│     ├── Eigene Variablen, eigene Module
│     └── PowerShell-Pipeline (ScriptBlock)
│
└─ [Runspace 3]          ← Weiterer paralleler Runspace
      ├── Eigene Variablen
      └── PowerShell-Pipeline (ScriptBlock)
```

### Der Lebenszyklus eines Runspace

Ein Runspace durchläuft folgende **Zustände** (`RunspaceState`):

```
BeforeOpen  →  Opening  →  Opened  →  Closing  →  Closed  →  Broken
                                ↑
                           (Hier läuft Code)
```

| Zustand | Bedeutung |
|---------|-----------|
| `BeforeOpen` | Runspace wurde erstellt, aber noch nicht geöffnet |
| `Opening` | `Open()` / `OpenAsync()` wurde aufgerufen, Initialisierung läuft |
| `Opened` | Runspace ist bereit für Ausführung |
| `Closing` | `Close()` wurde aufgerufen |
| `Closed` | Runspace ist geschlossen und gibt Ressourcen frei |
| `Broken` | Runspace ist in einen Fehlerzustand geraten |

### Der vollständige Lebenszyklus in Code

```powershell
# 1. Runspace erstellen
$runspace = [runspacefactory]::CreateRunspace()

# 2. Runspace öffnen (Thread wird allokiert, InitialSessionState wird angewendet)
$runspace.Open()

# 3. PowerShell-Instanz erstellen und dem Runspace zuweisen
$ps = [powershell]::Create()
$ps.Runspace = $runspace

# 4. ScriptBlock hinzufügen
[void]$ps.AddScript({
    "Hallo aus dem Runspace! PID: $PID"
    Get-Date
})

# 5. Asynchron starten
$asyncHandle = $ps.BeginInvoke()

# 6. Auf Fertigstellung warten und Ergebnis abrufen
$result = $ps.EndInvoke($asyncHandle)

# 7. Ressourcen freigeben (WICHTIG!)
$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

### InitialSessionState – Die Runspace-Konfiguration

Der `InitialSessionState` bestimmt, was im Runspace von Anfang an verfügbar ist. Es gibt drei Hauptvarianten:

```powershell
# Variante 1: Standard (alle Standard-Cmdlets geladen) – langsamster Start
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

# Variante 2: Minimale Konfiguration – nur absolutes Minimum geladen – schnellster Start
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()

# Variante 3: Leere Konfiguration – nichts geladen, maximale Kontrolle
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::Create()

# Runspace mit benutzerdefiniertem ISS erstellen
$runspace = [runspacefactory]::CreateRunspace($iss)
```

Du kannst dem `InitialSessionState` gezielt Funktionen, Variablen, Module und Cmdlets hinzufügen:

```powershell
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()

# Modul vorladen
$iss.ImportPSModule("ActiveDirectory")

# Variable einbetten
$iss.Variables.Add(
    [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
        "MeineVariable", "Hallo Welt", "Beschreibung"
    )
)

# Funktion einbetten
$functionDef = 'function Get-Greeting { param($Name) "Hallo, $Name!" }'
$iss.Commands.Add(
    [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
        "Get-Greeting", $functionDef
    )
)

$runspace = [runspacefactory]::CreateRunspace($iss)
$runspace.Open()
```

---

## 3. Runspaces in einem PowerShell-Modul verwenden

### Warum Runspaces in Modulen?

In einem Modul (`.psm1`) möchtest du möglicherweise:
- Lang laufende Operationen im Hintergrund ausführen
- Parallele Verarbeitung von Daten anbieten
- Einen persistenten Hintergrund-Thread für Monitoring oder Event-Handling betreiben

### Grundstruktur eines Moduls mit Runspace

```powershell
# MyModule.psm1

# Modul-Scope-Variablen für den Runspace (persistent für die gesamte Modul-Session)
$script:BackgroundRunspace = $null
$script:BackgroundPS        = $null
$script:AsyncHandle         = $null
$script:SharedData          = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

function Start-BackgroundWorker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [hashtable]$Parameters = @{}
    )

    # Aufräumen falls noch ein alter Runspace läuft
    if ($script:BackgroundRunspace -and $script:BackgroundRunspace.RunspaceStateInfo.State -eq 'Opened') {
        Stop-BackgroundWorker
    }

    # InitialSessionState mit Modul-Funktionen konfigurieren
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()

    # Wichtig: Den gleichen Modul-Pfad importieren, damit Hilfsfunktionen verfügbar sind
    $iss.ImportPSModule($PSScriptRoot)

    # Runspace erstellen und öffnen
    $script:BackgroundRunspace = [runspacefactory]::CreateRunspace($iss)
    $script:BackgroundRunspace.Name = "MyModule_Background"
    $script:BackgroundRunspace.Open()

    # Shared-Data-Queue dem Runspace zugänglich machen
    $script:BackgroundRunspace.SessionStateProxy.SetVariable(
        "SharedQueue", $script:SharedData
    )

    # PowerShell-Instanz erstellen
    $script:BackgroundPS = [powershell]::Create()
    $script:BackgroundPS.Runspace = $script:BackgroundRunspace

    [void]$script:BackgroundPS.AddScript($ScriptBlock)

    foreach ($param in $Parameters.GetEnumerator()) {
        [void]$script:BackgroundPS.AddParameter($param.Key, $param.Value)
    }

    # Asynchron starten
    $script:AsyncHandle = $script:BackgroundPS.BeginInvoke()

    Write-Verbose "Hintergrund-Worker gestartet (Runspace: $($script:BackgroundRunspace.Name))"
}

function Stop-BackgroundWorker {
    [CmdletBinding()]
    param()

    if ($script:BackgroundPS) {
        if (-not $script:AsyncHandle.IsCompleted) {
            $script:BackgroundPS.Stop()
        }
        try {
            $script:BackgroundPS.EndInvoke($script:AsyncHandle) | Out-Null
        } catch { }
        $script:BackgroundPS.Dispose()
        $script:BackgroundPS = $null
    }

    if ($script:BackgroundRunspace) {
        $script:BackgroundRunspace.Close()
        $script:BackgroundRunspace.Dispose()
        $script:BackgroundRunspace = $null
    }

    Write-Verbose "Hintergrund-Worker gestoppt."
}

function Get-WorkerStatus {
    [CmdletBinding()]
    param()

    if (-not $script:BackgroundRunspace) {
        return [PSCustomObject]@{ Status = "Nicht gestartet"; IsCompleted = $false }
    }

    [PSCustomObject]@{
        Status      = $script:BackgroundRunspace.RunspaceStateInfo.State
        IsCompleted = $script:AsyncHandle?.IsCompleted ?? $false
        Errors      = $script:BackgroundPS?.Streams.Error
    }
}

function Receive-WorkerResult {
    [CmdletBinding()]
    param()

    if (-not $script:AsyncHandle?.IsCompleted) {
        Write-Warning "Worker ist noch nicht fertig."
        return
    }

    $result = $script:BackgroundPS.EndInvoke($script:AsyncHandle)
    return $result
}

# Cleanup beim Entladen des Moduls
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Stop-BackgroundWorker
}

Export-ModuleMember -Function 'Start-BackgroundWorker', 'Stop-BackgroundWorker',
                              'Get-WorkerStatus', 'Receive-WorkerResult'
```

### RunspacePool in einem Modul für Parallelverarbeitung

```powershell
# MyParallelModule.psm1

$script:RunspacePool = $null

function Initialize-RunspacePool {
    param(
        [int]$MinThreads = 1,
        [int]$MaxThreads = [Environment]::ProcessorCount
    )

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool($MinThreads, $MaxThreads, $iss, $Host)
    $script:RunspacePool.Open()
    Write-Verbose "RunspacePool geöffnet (Min: $MinThreads, Max: $MaxThreads)"
}

function Invoke-Parallel {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [hashtable]$AdditionalParams = @{}
    )

    begin {
        if (-not $script:RunspacePool -or $script:RunspacePool.RunspacePoolStateInfo.State -ne 'Opened') {
            Initialize-RunspacePool
        }
        $jobs = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $script:RunspacePool
            [void]$ps.AddScript($ScriptBlock)
            [void]$ps.AddParameter("InputObject", $item)

            foreach ($kv in $AdditionalParams.GetEnumerator()) {
                [void]$ps.AddParameter($kv.Key, $kv.Value)
            }

            $jobs.Add([PSCustomObject]@{
                PowerShell  = $ps
                AsyncHandle = $ps.BeginInvoke()
            })
        }
    }

    end {
        foreach ($job in $jobs) {
            try {
                $job.PowerShell.EndInvoke($job.AsyncHandle)
            } finally {
                $job.PowerShell.Dispose()
            }
        }
    }
}
```

---

## 4. Scope und Variablen-Zugriff

### Isolation ist der Standard

Runspaces sind standardmäßig **vollständig isoliert**. Das bedeutet:

- Variablen aus dem Ersteller-Scope sind im Runspace **nicht** automatisch verfügbar
- Funktionen aus dem Ersteller-Scope sind im Runspace **nicht** automatisch verfügbar
- Geladene Module aus dem Ersteller-Scope sind im Runspace **nicht** automatisch geladen
- Der Runspace hat eine eigene **Drive-Struktur** (`Get-PSDrive` liefert ggf. andere Ergebnisse)

```powershell
$meineVariable = "Ich bin im Haupt-Scope"

$ps = [powershell]::Create()
[void]$ps.AddScript({
    # Diese Zeile gibt NICHTS aus, weil $meineVariable hier nicht existiert!
    Write-Host "Variable: $meineVariable"
})
$ps.Invoke()
# Output: "Variable: " (leer)
$ps.Dispose()
```

### Variablen aus dem Ersteller-Scope übergeben

Es gibt **vier Methoden**, um Daten in einen Runspace zu bekommen:

#### Methode 1: Parameter (`AddParameter` / `AddArgument`)

```powershell
$wert = "Hallo Welt"

$ps = [powershell]::Create()
[void]$ps.AddScript({
    param($MeinWert)
    Write-Host "Empfangen: $MeinWert"
})
[void]$ps.AddParameter("MeinWert", $wert)
$ps.Invoke()
# Output: "Empfangen: Hallo Welt"
$ps.Dispose()
```

#### Methode 2: SessionStateProxy (direkte Variable im Runspace setzen)

```powershell
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()

# Variable direkt in den Runspace-Scope schreiben
$runspace.SessionStateProxy.SetVariable("ExterneVariable", "Ich komme von außen")

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    Write-Host "Variable: $ExterneVariable"
})
$ps.Invoke()
# Output: "Variable: Ich komme von außen"

$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

#### Methode 3: InitialSessionState (beim Erstellen des Runspace)

```powershell
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
$iss.Variables.Add(
    [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
        "KonfigWert", "Produktiv", "Umgebung"
    )
)

$runspace = [runspacefactory]::CreateRunspace($iss)
$runspace.Open()

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({ Write-Host "Umgebung: $KonfigWert" })
$ps.Invoke()
# Output: "Umgebung: Produktiv"
```

#### Methode 4: Shared Objects (Thread-sichere Referenzen)

Beim Teilen von Objekten zwischen Runspaces muss auf **Thread-Sicherheit** geachtet werden! Verwende thread-sichere .NET-Typen:

```powershell
# Thread-sichere Collections
$sharedQueue    = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$sharedDict     = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
$sharedBag      = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# Synchronisierungsprimitiven
$mutex          = [System.Threading.Mutex]::new($false, "MeinMutex")
$semaphore      = [System.Threading.SemaphoreSlim]::new(1, 1)
$resetEvent     = [System.Threading.ManualResetEventSlim]::new($false)

# Beispiel: Runspace schreibt in eine gemeinsame Queue
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("Queue", $sharedQueue)

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    1..5 | ForEach-Object {
        $Queue.Enqueue("Eintrag $_")
        Start-Sleep -Milliseconds 200
    }
})
$asyncHandle = $ps.BeginInvoke()

# Im Haupt-Thread können wir die Queue lesen, während der Runspace schreibt
while (-not $asyncHandle.IsCompleted) {
    $item = $null
    while ($sharedQueue.TryDequeue([ref]$item)) {
        Write-Host "Empfangen: $item"
    }
    Start-Sleep -Milliseconds 100
}

$ps.EndInvoke($asyncHandle) | Out-Null
$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

> **⚠️ Warnung:** Normale PowerShell-Arrays (`@()`), `[System.Collections.ArrayList]` und Hashtables (` @{}`) sind **nicht thread-sicher**! Gleichzeitiger Schreibzugriff aus mehreren Runspaces kann zu Race Conditions und korrupten Daten führen. Verwende immer die `System.Collections.Concurrent.*`-Typen.

---

## 5. Synchrone vs. asynchrone Ausführung

### Synchrone Ausführung mit `Invoke()`

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({ Start-Sleep -Seconds 3; "Fertig!" })

# BLOCKIERT den aktuellen Thread für 3 Sekunden
$ergebnis = $ps.Invoke()

Write-Host "Ergebnis: $ergebnis"
$ps.Dispose()
```

**`Invoke()`** blockiert den aufrufenden Thread, bis der ScriptBlock vollständig ausgeführt wurde. Das ist nützlich, wenn du das Ergebnis sofort brauchst und keine parallele Verarbeitung stattfinden soll.

### Asynchrone Ausführung mit `BeginInvoke()` / `EndInvoke()`

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    Start-Sleep -Seconds 3
    "Fertig nach 3 Sekunden!"
})

# Startet sofort und gibt einen IAsyncResult-Handle zurück – blockiert NICHT
$asyncHandle = $ps.BeginInvoke()

Write-Host "Runspace läuft im Hintergrund..."

# Wir können weiter arbeiten
1..5 | ForEach-Object {
    Write-Host "Haupt-Thread arbeitet: $_"
    Start-Sleep -Milliseconds 500
}

# Warten bis der Runspace fertig ist und Ergebnis holen
$ergebnis = $ps.EndInvoke($asyncHandle)
Write-Host "Ergebnis: $ergebnis"

$ps.Dispose()
```

### Warten mit Timeout

```powershell
$asyncHandle = $ps.BeginInvoke()

# Warte maximal 5 Sekunden
$fertig = $asyncHandle.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds(5))

if ($fertig) {
    $ergebnis = $ps.EndInvoke($asyncHandle)
    Write-Host "Fertig: $ergebnis"
} else {
    Write-Warning "Timeout! Runspace wird abgebrochen."
    $ps.Stop()
}
$ps.Dispose()
```

### Callback bei Fertigstellung

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({ Start-Sleep -Seconds 2; "Ergebnis" })

# Callback wird aufgerufen, sobald der Runspace fertig ist
$callback = [System.AsyncCallback]{
    param($asyncResult)
    $fertig_ps = $asyncResult.AsyncState
    $output = $fertig_ps.EndInvoke($asyncResult)
    Write-Host "Callback aufgerufen! Ergebnis: $output"
    $fertig_ps.Dispose()
}

$asyncHandle = $ps.BeginInvoke($null, $callback, $ps)
Write-Host "Callback registriert, weiter im Haupt-Thread..."
Start-Sleep -Seconds 5  # Warte, damit Callback Zeit hat
```

### Vergleich der Ausführungsmodi

| Methode | Blockiert? | Rückgabe | Verwendung |
|---------|-----------|----------|------------|
| `Invoke()` | Ja | `PSDataCollection` direkt | Einfache, sequenzielle Ausführung |
| `BeginInvoke()` + `EndInvoke()` | Nein / Erst bei `EndInvoke()` | `IAsyncResult` Handle | Asynchron, Polling oder Warten |
| `BeginInvoke()` + Callback | Nein | Callback-Aufruf | Fire-and-Forget mit Benachrichtigung |
| `InvokeAsync()` (PS 7+) | Nein | `Task<PSDataCollection>` | Modern, `async/await`-Stil in .NET |

---

## 6. Status eines Runspace prüfen

### Zustand des Runspace selbst

```powershell
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()

# RunspaceState abfragen
$runspace.RunspaceStateInfo.State
# Mögliche Werte: BeforeOpen, Opening, Opened, Closing, Closed, Broken

# Availability (ob gerade Code ausgeführt wird)
$runspace.RunspaceAvailability
# Mögliche Werte: Available, Busy, None
```

### Zustand des asynchronen Handles

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({ Start-Sleep -Seconds 5 })
$asyncHandle = $ps.BeginInvoke()

# IAsyncResult-Properties
$asyncHandle.IsCompleted       # $true wenn fertig
$asyncHandle.CompletedSynchronously  # $true wenn synchron abgeschlossen

# AsyncWaitHandle für WaitOne()-Aufrufe
$asyncHandle.AsyncWaitHandle.WaitOne(0)  # Sofortige Prüfung ohne Warten
```

### Zustand der PowerShell-Instanz

```powershell
# InvocationStateInfo gibt detaillierten Zustand
$ps.InvocationStateInfo.State
# Mögliche Werte: NotStarted, Running, Stopping, Stopped, Completed, Failed, Disconnected

# Fehler prüfen
if ($ps.HadErrors) {
    $ps.Streams.Error | ForEach-Object {
        Write-Warning "Fehler: $_"
    }
}
```

### Polling-Pattern für mehrere Runspaces

```powershell
$jobs = @(
    @{ PS = [powershell]::Create(); Handle = $null }
    @{ PS = [powershell]::Create(); Handle = $null }
    @{ PS = [powershell]::Create(); Handle = $null }
)

# Alle starten
foreach ($job in $jobs) {
    [void]$job.PS.AddScript({ Start-Sleep -Seconds (Get-Random -Min 1 -Max 5); "Job fertig!" })
    $job.Handle = $job.PS.BeginInvoke()
}

# Polling bis alle fertig sind
$alleErgebnisse = @()
while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {

    $fertige = $jobs | Where-Object { $_.Handle.IsCompleted -and $_.Handle -ne $null }

    foreach ($job in $fertige) {
        $alleErgebnisse += $job.PS.EndInvoke($job.Handle)
        $job.PS.Dispose()
        $job.Handle = $null  # Als verarbeitet markieren
    }

    Start-Sleep -Milliseconds 100
}

$alleErgebnisse | ForEach-Object { Write-Host "Ergebnis: $_" }
```

### Fortschritts-Monitoring über Streams

```powershell
# Progress und Verbose Streams abonnieren
$ps = [powershell]::Create()

# Event-Handler für Echtzeit-Output
$ps.Streams.Information.DataAdded += {
    param($sender, $e)
    Write-Host "[INFO] $($sender[$e.Index].MessageData)"
}

$ps.Streams.Progress.DataAdded += {
    param($sender, $e)
    $progress = $sender[$e.Index]
    Write-Progress -Activity $progress.Activity -Status $progress.StatusDescription -PercentComplete $progress.PercentComplete
}

[void]$ps.AddScript({
    Write-Information "Starte Verarbeitung..."
    1..10 | ForEach-Object {
        Write-Progress -Activity "Verarbeitung" -Status "Schritt $_" -PercentComplete ($_ * 10)
        Start-Sleep -Milliseconds 200
    }
})

$asyncHandle = $ps.BeginInvoke()
$ps.EndInvoke($asyncHandle) | Out-Null
$ps.Dispose()
```

---

## 7. Vorteile von Runspaces

### 1. Kein neuer Prozess – niedrigerer Overhead

Im Vergleich zu `Start-Job` erstellt ein Runspace **keinen neuen Prozess**. Es wird kein neues `pwsh.exe` gestartet, keine neuen Format/Type-Dateien geladen, kein vollständiger PowerShell-Startup durchgeführt. Das spart:

- **Startup-Zeit:** `Start-Job` benötigt ~500ms-2s, ein Runspace startet in Millisekunden
- **Arbeitsspeicher:** Kein duplizierter Prozess-Heap
- **CPU:** Kein Overhead durch Prozess-Erstellung

### 2. Direkte .NET-Objekte – keine Serialisierung

`Start-Job` serialisiert alle Daten zwischen Prozessen als CLIXML. Das bedeutet:

```powershell
# Mit Start-Job: Objekte werden deserialisiert → verlieren Methoden!
$job = Start-Job { [System.Diagnostics.Process]::GetCurrentProcess() }
$result = Receive-Job $job
$result.GetType().Name  # "Deserialized.System.Diagnostics.Process"
$result.Kill()          # FEHLER! Methode nicht verfügbar auf deserialisierten Objekten

# Mit Runspace: Echte .NET-Objekte bleiben erhalten
$ps = [powershell]::Create()
[void]$ps.AddScript({ [System.Diagnostics.Process]::GetCurrentProcess() })
$result = $ps.Invoke()
$result[0].GetType().Name  # "System.Diagnostics.Process"
$result[0].Responding       # Methoden/Properties vollständig verfügbar!
$ps.Dispose()
```

### 3. Volle Kontrolle über die Umgebung

Mit `InitialSessionState` kannst du genau steuern:
- Welche Cmdlets/Funktionen verfügbar sind (Whitelisting)
- Welche Variablen vorgeladen sind
- Welcher Language Mode gilt (`FullLanguage`, `ConstrainedLanguage`, `RestrictedLanguage`)
- Welche Module geladen sind

### 4. Echte Parallelität mit RunspacePool

Ein `RunspacePool` verwaltet automatisch einen Thread-Pool und führt `n` Aufgaben gleichzeitig aus, genau wie ein `ThreadPool` in anderen Sprachen.

### 5. Feingranulare Steuerung

- Asynchrones Starten/Stoppen einzelner Runspaces
- Event-basierte Benachrichtigungen bei Fertigstellung
- Direkte Interaktion über `SessionStateProxy`
- Streams (Error, Warning, Verbose, Debug, Information, Progress) separat abrufbar

---

## 8. Use Cases für Runspaces

### Use Case 1: Parallele Server-Abfragen

```powershell
# Problem: 100 Server nacheinander abfragen dauert lange
# Lösung: Alle parallel abfragen

$server = 1..100 | ForEach-Object { "Server$_" }

$pool = [runspacefactory]::CreateRunspacePool(1, 20)
$pool.Open()

$jobs = $server | ForEach-Object {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($ServerName)
        [PSCustomObject]@{
            Server   = $ServerName
            Online   = Test-Connection -ComputerName $ServerName -Count 1 -Quiet
            Zeit     = Get-Date
        }
    })
    [void]$ps.AddParameter("ServerName", $_)
    [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
}

$results = $jobs | ForEach-Object {
    $_.PS.EndInvoke($_.Handle)
    $_.PS.Dispose()
}

$pool.Close(); $pool.Dispose()
$results | Sort-Object Server
```

### Use Case 2: GUI-Applikation mit Hintergrundaufgaben

```powershell
# WPF/WinForms-Formulare laufen auf dem STA-Thread (Single Threaded Apartment)
# Lange Operationen würden die GUI einfrieren – Runspaces verhindern das

Add-Type -AssemblyName PresentationFramework

$window = [Windows.Markup.XamlReader]::Parse(@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Runspace Demo" Height="150" Width="300">
    <StackPanel Margin="10">
        <Button Name="StartBtn" Content="Starten" Margin="0,0,0,10"/>
        <TextBlock Name="StatusText" Text="Bereit"/>
    </StackPanel>
</Window>
"@)

$startBtn  = $window.FindName("StartBtn")
$statusTxt = $window.FindName("StatusText")

$startBtn.Add_Click({
    $statusTxt.Text = "Lädt..."

    # Runspace für Hintergrundarbeit (nicht STA, da keine GUI-Elemente)
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        Start-Sleep -Seconds 3
        "Daten geladen!"
    })

    $handle = $ps.BeginInvoke()

    # Timer zur Überprüfung (bleibt auf GUI-Thread!)
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $result = $ps.EndInvoke($handle)
            $statusTxt.Text = $result
            $ps.Dispose()
            $timer.Stop()
        }
    })
    $timer.Start()
})

[void]$window.ShowDialog()
```

### Use Case 3: Echtzeit-Dateiverarbeitung (Producer-Consumer)

```powershell
# Producer: Liest Dateien und stellt sie in eine Queue
# Consumer-Runspaces: Verarbeiten Dateien parallel

$queue      = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$fertig     = [System.Threading.ManualResetEventSlim]::new($false)
$ergebnisse = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# Producer-Runspace
$producerPS = [powershell]::Create()
$producerPS.Runspace = [runspacefactory]::CreateRunspace()
$producerPS.Runspace.Open()
$producerPS.Runspace.SessionStateProxy.SetVariable("Queue", $queue)
$producerPS.Runspace.SessionStateProxy.SetVariable("Fertig", $fertig)

[void]$producerPS.AddScript({
    Get-ChildItem -Path "C:\Logs" -Filter "*.log" | ForEach-Object {
        $Queue.Enqueue($_.FullName)
    }
    $Fertig.Set()  # Signal: Alle Dateien in Queue
})

$producerHandle = $producerPS.BeginInvoke()

# Consumer-Runspaces (parallel)
$consumers = 1..4 | ForEach-Object {
    $ps = [powershell]::Create()
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("Queue", $queue)
    $rs.SessionStateProxy.SetVariable("Fertig", $fertig)
    $rs.SessionStateProxy.SetVariable("Ergebnisse", $ergebnisse)
    $ps.Runspace = $rs

    [void]$ps.AddScript({
        while (-not ($Fertig.IsSet -and $Queue.IsEmpty)) {
            $datei = $null
            if ($Queue.TryDequeue([ref]$datei)) {
                $inhalt = Get-Content $datei -Raw
                $zeilenAnzahl = ($inhalt -split "`n").Count
                $Ergebnisse.Add([PSCustomObject]@{
                    Datei  = $datei
                    Zeilen = $zeilenAnzahl
                })
            } else {
                Start-Sleep -Milliseconds 50
            }
        }
    })

    [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke(); RS = $rs }
}

# Warten bis alle fertig
$producerPS.EndInvoke($producerHandle) | Out-Null
$consumers | ForEach-Object {
    $_.PS.EndInvoke($_.Handle) | Out-Null
    $_.PS.Dispose()
    $_.RS.Close()
    $_.RS.Dispose()
}

$ergebnisse | Sort-Object Datei
```

### Use Case 4: Timeout-Enforcement

```powershell
function Invoke-WithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 30,
        [hashtable]$Parameters = @{}
    )

    $ps = [powershell]::Create()
    [void]$ps.AddScript($ScriptBlock)
    foreach ($kv in $Parameters.GetEnumerator()) {
        [void]$ps.AddParameter($kv.Key, $kv.Value)
    }

    $handle = $ps.BeginInvoke()
    $abgeschlossen = $handle.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))

    if ($abgeschlossen) {
        $ergebnis = $ps.EndInvoke($handle)
        $ps.Dispose()
        return $ergebnis
    } else {
        $ps.Stop()
        $ps.Dispose()
        throw [TimeoutException]"ScriptBlock hat nach $TimeoutSeconds Sekunden nicht geantwortet."
    }
}

# Verwendung
try {
    $result = Invoke-WithTimeout -ScriptBlock {
        Start-Sleep -Seconds 60  # Zu lange!
        "Fertig"
    } -TimeoutSeconds 5
} catch [TimeoutException] {
    Write-Warning "Timeout: $_"
}
```

### Use Case 5: Kontinuierliches Monitoring / Hintergrund-Daemon

```powershell
# Runspace läuft als permanenter Hintergrund-Thread und überwacht Events
$sharedLog = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

$monitorRS = [runspacefactory]::CreateRunspace()
$monitorRS.Open()
$monitorRS.SessionStateProxy.SetVariable("Log", $sharedLog)

$monitorPS = [powershell]::Create()
$monitorPS.Runspace = $monitorRS

[void]$monitorPS.AddScript({
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path   = "C:\WatchDir"
    $watcher.Filter = "*.txt"
    $watcher.EnableRaisingEvents = $true

    $action = {
        $Log.Enqueue("$(Get-Date -Format 'HH:mm:ss') - Geändert: $($Event.SourceEventArgs.FullPath)")
    }

    Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
    Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

    # Schleife hält Runspace am Leben
    while ($true) { Start-Sleep -Seconds 1 }
})

$handle = $monitorPS.BeginInvoke()
Write-Host "Überwachung gestartet. Drücke CTRL+C zum Beenden."

try {
    while ($true) {
        $eintrag = $null
        while ($sharedLog.TryDequeue([ref]$eintrag)) {
            Write-Host $eintrag
        }
        Start-Sleep -Milliseconds 500
    }
} finally {
    $monitorPS.Stop()
    $monitorPS.Dispose()
    $monitorRS.Close()
    $monitorRS.Dispose()
}
```

---

## 9. Parameter und Variablen übergeben

### Methode 1: `AddParameter()` (benannte Parameter)

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    param(
        [string]$Name,
        [int]$Alter,
        [string[]]$Tags
    )
    "Name: $Name, Alter: $Alter, Tags: $($Tags -join ', ')"
})

[void]$ps.AddParameter("Name",  "Max Mustermann")
[void]$ps.AddParameter("Alter", 30)
[void]$ps.AddParameter("Tags",  @("PowerShell", "Developer"))

$ps.Invoke()
$ps.Dispose()
```

### Methode 2: `AddArgument()` (positionelle Parameter)

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    param($Erster, $Zweiter)
    "$Erster und $Zweiter"
})

[void]$ps.AddArgument("Hallo")
[void]$ps.AddArgument("Welt")

$ps.Invoke()
$ps.Dispose()
```

### Methode 3: Hashtable als einzelner Parameter

```powershell
$config = @{
    Server   = "SQL-01"
    Database = "Produktion"
    Timeout  = 30
}

$ps = [powershell]::Create()
[void]$ps.AddScript({
    param([hashtable]$Config)
    "Verbinde mit $($Config.Server)\$($Config.Database) (Timeout: $($Config.Timeout)s)"
})
[void]$ps.AddParameter("Config", $config)

$ps.Invoke()
$ps.Dispose()
```

### Methode 4: `SessionStateProxy.SetVariable()`

```powershell
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()

# Komplexe Objekte übergeben (keine Serialisierung!)
$runspace.SessionStateProxy.SetVariable("GlobKonfig", [PSCustomObject]@{
    Umgebung  = "Prod"
    LogLevel  = "Info"
    MaxRetry  = 3
})

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    "Umgebung: $($GlobKonfig.Umgebung), MaxRetry: $($GlobKonfig.MaxRetry)"
})
$ps.Invoke()

# Variablen auch wieder auslesen!
$runspace.SessionStateProxy.GetVariable("GlobKonfig")

$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

### Komplexe Typen und Closures (Vorsicht!)

```powershell
# PROBLEM: ScriptBlock-Closures können unerwartete Variablen "einschließen"
$externeVariable = "Ich bin extern"

$scriptBlock = {
    # $externeVariable ist hier NICHT verfügbar (kein automatisches Closure im Runspace-Kontext)
    Write-Host $externeVariable
}

# LÖSUNG 1: GetNewClosure() erstellt echtes Closure (kopiert Variablen in den Block)
$closureBlock = $scriptBlock.GetNewClosure()

$ps = [powershell]::Create()
[void]$ps.AddScript($closureBlock)
$ps.Invoke()  # Gibt "Ich bin extern" aus!
$ps.Dispose()
```

---

## 10. Exitcode eines Runspace

### Kein nativer Exitcode

Runspaces haben **keinen nativen Exitcode** wie externe Prozesse (`$LASTEXITCODE`). Stattdessen gibt es mehrere Möglichkeiten, den Erfolg oder Misserfolg zu kommunizieren:

### Methode 1: Fehlerbehandlung über Streams

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    try {
        # Simuliere einen Fehler
        throw "Etwas ist schiefgelaufen"
    } catch {
        # Fehler in den Error-Stream schreiben
        Write-Error $_.Exception.Message
    }
})

$ps.Invoke()

# Fehler auswerten
if ($ps.HadErrors) {
    Write-Host "Exitcode-Äquivalent: FEHLER"
    $ps.Streams.Error | ForEach-Object {
        Write-Warning "Fehler: $($_.Exception.Message)"
    }
} else {
    Write-Host "Exitcode-Äquivalent: ERFOLG"
}

$ps.Dispose()
```

### Methode 2: Rückgabewert als Statusobjekt

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    try {
        # ... Arbeit ...
        return [PSCustomObject]@{
            ExitCode = 0
            Message  = "Erfolgreich"
            Data     = @("Ergebnis1", "Ergebnis2")
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode = 1
            Message  = $_.Exception.Message
            Data     = $null
        }
    }
})

$result = $ps.Invoke()
$status = $result[0]

Write-Host "ExitCode: $($status.ExitCode)"
Write-Host "Message:  $($status.Message)"
$ps.Dispose()
```

### Methode 3: Shared Variable für Exitcode

```powershell
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("ExitCode", 0)

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    try {
        # Arbeit...
        $ExitCode = 0  # ABER: Dies erstellt lokale Variable im ScriptBlock!
    } catch {
        # Für SharedVariable muss Set-Variable mit Scope verwendet werden
        Set-Variable -Name ExitCode -Value 99 -Scope Global
    }
})
$ps.Invoke()

# Exitcode auslesen
$exitCode = $runspace.SessionStateProxy.GetVariable("ExitCode")
Write-Host "ExitCode: $exitCode"

$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

> **Empfehlung:** Verwende ein strukturiertes Rückgabeobjekt (`[PSCustomObject]`) mit einem `ExitCode`-Property. Das ist am übersichtlichsten und wartbarsten.

---

## 11. Rückgabewerte aus einem Runspace

### Alles, was auf die Pipeline geschrieben wird, ist Rückgabe

In PowerShell ist jeder Wert, der **nicht in eine Variable gespeichert** oder **explizit unterdrückt** wird, automatisch eine Ausgabe auf der Pipeline – und damit ein Rückgabewert:

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    # Alle drei Zeilen sind Rückgaben:
    "Text-Rückgabe"
    42
    [PSCustomObject]@{ Name = "Max"; Alter = 30 }

    # KEIN Rückgabewert:
    $null = Get-Date      # unterdrückt
    [void](1 + 2)         # unterdrückt
    Get-Date | Out-Null   # unterdrückt
})

$ergebnisse = $ps.Invoke()

$ergebnisse[0]  # "Text-Rückgabe"
$ergebnisse[1]  # 42
$ergebnisse[2]  # PSCustomObject
$ergebnisse[2].Name  # "Max"

$ps.Dispose()
```

### Asynchrone Rückgabe mit `EndInvoke()`

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    1..5 | ForEach-Object { "Ergebnis $_" }
})

$handle = $ps.BeginInvoke()

# EndInvoke() blockiert bis fertig und gibt PSDataCollection zurück
$ergebnisse = $ps.EndInvoke($handle)

$ergebnisse | ForEach-Object { Write-Host $_ }
$ps.Dispose()
```

### Rückgabe von komplexen Typen

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    # Komplexe .NET-Objekte werden direkt (ohne Serialisierung) zurückgegeben
    [System.Collections.Generic.Dictionary[string,int]]::new() | ForEach-Object {
        $_.Add("Eins", 1)
        $_.Add("Zwei", 2)
        $_  # Gibt Dictionary zurück
    }
})

$result = $ps.Invoke()
$dict = $result[0]
$dict["Eins"]  # 1
$dict["Zwei"]  # 2
$ps.Dispose()
```

### Streams als zusätzliche Rückgabekanäle

```powershell
$ps = [powershell]::Create()
[void]$ps.AddScript({
    Write-Output  "Normal-Ausgabe"
    Write-Error   "Fehler-Meldung"
    Write-Warning "Warnung"
    Write-Verbose "Verbose-Info" -Verbose
    Write-Debug   "Debug-Info" -Debug
    Write-Information "Information"
})

$output = $ps.Invoke()

# Jeden Stream separat abrufen
Write-Host "Output-Stream:      $($output -join ', ')"
Write-Host "Error-Stream:       $($ps.Streams.Error -join ', ')"
Write-Host "Warning-Stream:     $($ps.Streams.Warning -join ', ')"
Write-Host "Verbose-Stream:     $($ps.Streams.Verbose -join ', ')"
Write-Host "Debug-Stream:       $($ps.Streams.Debug -join ', ')"
Write-Host "Information-Stream: $($ps.Streams.Information -join ', ')"

$ps.Dispose()
```

### Echtzeit-Output während Ausführung

```powershell
# PSDataCollection ermöglicht Echtzeit-Empfang von Rückgaben
$outputCollection = [System.Management.Automation.PSDataCollection[PSObject]]::new()

$outputCollection.DataAdded += {
    param($sender, $e)
    Write-Host "[ECHTZEIT] $($sender[$e.Index])"
}

$ps = [powershell]::Create()
[void]$ps.AddScript({
    1..5 | ForEach-Object {
        "Ausgabe $_"
        Start-Sleep -Milliseconds 500
    }
})

$handle = $ps.BeginInvoke([System.Management.Automation.PSDataCollection[PSObject]]::new(), $outputCollection)
$ps.EndInvoke($handle) | Out-Null
$ps.Dispose()
```

---

## 12. Interaktion mit einem Runspace (IPC)

### Kommunikations-Muster im Überblick

| Methode | Richtung | Thread-sicher | Echtzeit | Komplexität |
|---------|----------|---------------|----------|-------------|
| Shared `ConcurrentQueue` | Bidirektional | ✅ | ✅ | Niedrig |
| `SessionStateProxy` | Bidirektional | ✅ | ✅ | Niedrig |
| `PSDataCollection` mit Events | Haupt → Runspace | ✅ | ✅ | Mittel |
| `ManualResetEvent` / `SemaphoreSlim` | Signale | ✅ | ✅ | Mittel |
| Named Pipes | Prozessübergreifend | ✅ | ✅ | Hoch |
| `Enter-PSHostProcess` | Interaktiv | N/A | N/A | Niedrig |

### Methode 1: Bidirektionale Kommunikation über ConcurrentQueues

```powershell
# Zwei Queues: eine für Befehle, eine für Antworten
$commandQueue  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$responseQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$stopSignal    = [System.Threading.CancellationTokenSource]::new()

$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("Commands",  $commandQueue)
$runspace.SessionStateProxy.SetVariable("Responses", $responseQueue)
$runspace.SessionStateProxy.SetVariable("Stop",      $stopSignal.Token)

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    while (-not $Stop.IsCancellationRequested) {
        $cmd = $null
        if ($Commands.TryDequeue([ref]$cmd)) {
            $ergebnis = switch ($cmd) {
                "DATUM"    { Get-Date }
                "UPTIME"   { (Get-Date) - [System.Diagnostics.Process]::GetCurrentProcess().StartTime }
                "PROZESSE" { (Get-Process).Count }
                default    { "Unbekannter Befehl: $cmd" }
            }
            $Responses.Enqueue([PSCustomObject]@{ Befehl = $cmd; Ergebnis = $ergebnis })
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
})

$handle = $ps.BeginInvoke()

# Im Haupt-Thread Befehle senden und Antworten empfangen
@("DATUM", "PROZESSE", "UPTIME") | ForEach-Object {
    $commandQueue.Enqueue($_)
    Start-Sleep -Milliseconds 200

    $antwort = $null
    if ($responseQueue.TryDequeue([ref]$antwort)) {
        Write-Host "[$($antwort.Befehl)] → $($antwort.Ergebnis)"
    }
}

# Runspace stoppen
$stopSignal.Cancel()
$ps.EndInvoke($handle) | Out-Null
$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

### Methode 2: Named Pipes (prozessübergreifende IPC)

```powershell
# SERVER-Seite (in einem Runspace)
$serverRS = [runspacefactory]::CreateRunspace()
$serverRS.Open()

$serverPS = [powershell]::Create()
$serverPS.Runspace = $serverRS
[void]$serverPS.AddScript({
    $pipeName = "MeinPowerShellPipe"
    $pipe = [System.IO.Pipes.NamedPipeServerStream]::new(
        $pipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Message
    )

    Write-Information "Server wartet auf Verbindung..."
    $pipe.WaitForConnection()

    $reader = [System.IO.StreamReader]::new($pipe)
    $writer = [System.IO.StreamWriter]::new($pipe)
    $writer.AutoFlush = $true

    $nachricht = $reader.ReadLine()
    Write-Information "Empfangen: $nachricht"
    $writer.WriteLine("Echo: $nachricht")

    $pipe.Disconnect()
    $pipe.Dispose()
})

$serverHandle = $serverPS.BeginInvoke()

Start-Sleep -Milliseconds 500  # Kurz warten bis Server bereit

# CLIENT-Seite (im Haupt-Thread)
$pipe = [System.IO.Pipes.NamedPipeClientStream]::new(
    ".", "MeinPowerShellPipe",
    [System.IO.Pipes.PipeDirection]::InOut
)
$pipe.Connect(5000)  # 5 Sekunden Timeout

$writer = [System.IO.StreamWriter]::new($pipe)
$reader = [System.IO.StreamReader]::new($pipe)
$writer.AutoFlush = $true

$writer.WriteLine("Hallo Server!")
$antwort = $reader.ReadLine()
Write-Host "Server antwortete: $antwort"

$pipe.Dispose()
$serverPS.EndInvoke($serverHandle) | Out-Null
$serverPS.Dispose()
$serverRS.Close()
$serverRS.Dispose()
```

### Methode 3: `Enter-PSHostProcess` (Interaktive IPC)

```powershell
# In Terminal 1: PID herausfinden
$PID  # z.B. 12345

# In Terminal 2: In den Prozess eintreten
Enter-PSHostProcess -Id 12345

# Jetzt bist du im Runspace von Terminal 1!
# Du kannst Variablen lesen/setzen, Funktionen aufrufen usw.
Get-Variable  # Zeigt Variablen von Terminal 1

# Verlassen
Exit-PSHostProcess
```

### Methode 4: `Get-Runspace` und `Debug-Runspace`

```powershell
# Alle laufenden Runspaces auflisten
Get-Runspace

# Einen spezifischen Runspace debuggen (interaktiv)
$rs = Get-Runspace -Id 2
Debug-Runspace -Runspace $rs

# Oder nach Name
Get-Runspace -Name "MeinRunspace" | Debug-Runspace
```

### Methode 5: Thread-sichere Event-Signalisierung

```powershell
# ManualResetEventSlim: Ein Runspace wartet, bis Haupt-Thread ihn "signalisiert"
$startSignal    = [System.Threading.ManualResetEventSlim]::new($false)
$ergebnisReady  = [System.Threading.ManualResetEventSlim]::new($false)
$sharedErgebnis = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("StartSignal",   $startSignal)
$runspace.SessionStateProxy.SetVariable("ErgebnisReady", $ergebnisReady)
$runspace.SessionStateProxy.SetVariable("Ergebnis",      $sharedErgebnis)

$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript({
    Write-Information "Runspace wartet auf Start-Signal..."
    $StartSignal.Wait()  # Blockiert bis Signal gesetzt wird
    Write-Information "Signal empfangen! Starte Arbeit..."

    Start-Sleep -Seconds 2
    $Ergebnis.Add("Arbeit erledigt! $(Get-Date)")

    $ErgebnisReady.Set()  # Signal zurück an Haupt-Thread
})

$handle = $ps.BeginInvoke()

Write-Host "Haupt-Thread macht andere Dinge..."
Start-Sleep -Seconds 1

Write-Host "Sendet Start-Signal..."
$startSignal.Set()

Write-Host "Wartet auf Ergebnis..."
$ergebnisReady.Wait()

$item = $null
$sharedErgebnis.TryTake([ref]$item)
Write-Host "Ergebnis: $item"

$ps.EndInvoke($handle) | Out-Null
$ps.Dispose()
$runspace.Close()
$runspace.Dispose()
```

---

## Best Practices und häufige Fehler

### ✅ Do's

```powershell
# 1. Immer Dispose() aufrufen!
try {
    $ps = [powershell]::Create()
    # ... Arbeit ...
} finally {
    $ps?.Dispose()
    $runspace?.Close()
    $runspace?.Dispose()
}

# 2. RunspacePool für viele parallele Aufgaben verwenden
$pool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$pool.Open()
# ... viele Aufgaben ...
$pool.Close()
$pool.Dispose()

# 3. Thread-sichere Collections verwenden
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# 4. Fehlerbehandlung in ScriptBlocks
[void]$ps.AddScript({
    try {
        # ... Arbeit ...
    } catch {
        Write-Error "Fehler: $($_.Exception.Message)"
    }
})

# 5. $using: in ForEach-Object -Parallel
$config = "WertAusHauptScope"
1..10 | ForEach-Object -Parallel {
    $lokalerConfig = $using:config
    "Wert: $lokalerConfig"
}
```

### ❌ Don'ts

```powershell
# FALSCH: Nicht thread-sichere Collections teilen
$results = @()  # ← NICHT thread-sicher!
$runspace.SessionStateProxy.SetVariable("Results", $results)

# FALSCH: Runspace ohne Dispose() verwenden
$ps = [powershell]::Create()
$ps.Invoke()
# ← $ps.Dispose() vergessen → Memory Leak!

# FALSCH: Zu viele Runspaces auf einmal
1..1000 | ForEach-Object {
    $ps = [powershell]::Create()  # ← Erstellt 1000 Threads!
    # Besser: RunspacePool mit MaxThreads = Prozessorkerne
}

# FALSCH: GUI-Elemente aus einem Runspace ansprechen
[void]$ps.AddScript({
    $button.Content = "Fertig"  # ← Cross-Thread Exception!
    # Korrekt: Dispatcher.Invoke() verwenden
})

# FALSCH: Endlose Runspaces ohne Stop-Mechanismus
[void]$ps.AddScript({
    while ($true) { }  # ← Kann nicht gestoppt werden ohne $ps.Stop()
})
```

---

## Schnellreferenz

```powershell
# === EINFACHER RUNSPACE ===
$ps = [powershell]::Create()
[void]$ps.AddScript({ "Hallo!" })
$ergebnis = $ps.Invoke()
$ps.Dispose()

# === ASYNCHRON ===
$handle  = $ps.BeginInvoke()
$fertig  = $handle.IsCompleted
$ps.EndInvoke($handle) | Out-Null

# === MIT RUNSPACE ===
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$ps.Runspace = $rs
$rs.Close(); $rs.Dispose()

# === MIT RUNSPACEPOOL ===
$pool = [runspacefactory]::CreateRunspacePool(1, 8)
$pool.Open()
$ps.RunspacePool = $pool
$pool.Close(); $pool.Dispose()

# === PARAMETER ÜBERGEBEN ===
[void]$ps.AddParameter("Name", "Wert")
[void]$ps.AddArgument("PositionalWert")

# === STATUS PRÜFEN ===
$rs.RunspaceStateInfo.State       # BeforeOpen/Opened/Closed/Broken
$handle.IsCompleted               # $true wenn fertig
$ps.HadErrors                     # $true bei Fehlern
$ps.Streams.Error                 # Fehler-Collection

# === SHARED DATA ===
$queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$rs.SessionStateProxy.SetVariable("Q", $queue)

# === AUFRÄUMEN (IMMER!) ===
$ps.Dispose()
$rs.Close()
$rs.Dispose()
$pool.Close()
$pool.Dispose()
```

---

*Ende der Dokumentation – Viel Erfolg mit PowerShell Runspaces!*
