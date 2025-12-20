<#
.SYNOPSIS
    UTF-8 with BOM Encoding Patch Script
    Konvertiert ALLE Dateien im aktuellen Verzeichnis und allen Unterverzeichnissen
    zu UTF-8 with BOM Format.

.DESCRIPTION
    Dieses Skript durchsucht rekursiv alle Dateien in der Verzeichnisstruktur
    und konvertiert sie zu UTF-8 with BOM Encoding.
    
    UTF-8 with BOM ist essentiell für:
    - XAML-Dateien mit Umlauten (ä, ö, ü)
    - PowerShell-Skripte mit deutschen Texten
    - JSON-Dateien mit Sonderzeichen
    - Markdown-Dateien mit Sonderzeichen

.EXAMPLE
    .\UTF8-BOM-Patch.ps1
    # Patcht alle Dateien im aktuellen Verzeichnis und Unterverzeichnissen

.EXAMPLE
    .\UTF8-BOM-Patch.ps1 -Path "C:\MyProject"
    # Patcht alle Dateien in C:\MyProject und Unterverzeichnissen

.PARAMETER Path
    Der Pfad zum Verzeichnis, das gepatcht werden soll.
    Standard: Aktuelles Verzeichnis (.)

.PARAMETER Extension
    Dateiendungen, die gepatcht werden sollen (komma-separiert).
    Standard: *.ps1,*.xaml,*.json,*.md,*.xml,*.txt

.PARAMETER Force
    Ohne Bestätigung patchen.
    Standard: Benutzer wird gefragt

.NOTES
    Author: PowerShell Development Team
    Date: 2025-12-20
    Version: 1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory = $false)]
    [string[]]$Extension = @("*.ps1", "*.xaml", "*.json", "*.md", "*.xml", "*.txt", "*.ps1xml", "*.psd1"),
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Error Handling
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Funktion: Datei zu UTF-8 with BOM konvertieren
function Convert-FileToUTF8BOM {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # Datei einlesen mit automatischer Encoding-Erkennung
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        
        # UTF-8 with BOM Encoding
        $utf8BOM = New-Object System.Text.UTF8Encoding($true)
        $bytes = $utf8BOM.GetBytes($content)
        
        # Mit BOM schreiben
        [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        
        return $true
    }
    catch {
        Write-Warning "Fehler bei Datei '$FilePath': $_"
        return $false
    }
}

# Funktion: BOM-Status prüfen
function Test-UTF8BOM {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # UTF-8 BOM = EF BB BF (3 Bytes)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

# Main Script
Write-Host "`n" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "    UTF-8 with BOM ENCODING PATCH" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "`n" -ForegroundColor Cyan

# Pfad validieren
if (-not (Test-Path -Path $Path -PathType Container)) {
    Write-Error "Pfad nicht gefunden: $Path"
    exit 1
}

Write-Host "Zielverzeichnis: $Path" -ForegroundColor Green
Write-Host "Dateitypen: $($Extension -join ', ')" -ForegroundColor Green
Write-Host "`n" -ForegroundColor Cyan

# Alle Dateien finden
$filesToPatch = @()
foreach ($ext in $Extension) {
    $filesToPatch += Get-ChildItem -Path $Path -Filter $ext -Recurse -File -ErrorAction SilentlyContinue
}

if ($filesToPatch.Count -eq 0) {
    Write-Host "Keine Dateien zum Patchen gefunden." -ForegroundColor Yellow
    exit 0
}

Write-Host "Gefundene Dateien: $($filesToPatch.Count)" -ForegroundColor Green
Write-Host "`n" -ForegroundColor Cyan

# Bestätigung (falls nicht -Force)
if (-not $Force) {
    Write-Host "Folgende Dateien werden zu UTF-8 with BOM konvertiert:" -ForegroundColor Yellow
    Write-Host "`n"
    
    $filesToPatch | ForEach-Object {
        Write-Host "  - $($_.FullName)" -ForegroundColor Gray
    }
    
    Write-Host "`n"
    $response = Read-Host "Fortfahren? (Ja/Nein)"
    
    if ($response -ne "Ja" -and $response -ne "ja" -and $response -ne "J") {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        exit 0
    }
}

# Patchen
Write-Host "`nPatche Dateien..."`n -ForegroundColor Cyan

$successCount = 0
$failureCount = 0
$skipCount = 0

foreach ($file in $filesToPatch) {
    $fileFullPath = $file.FullName
    
    # Prüfen, ob bereits UTF-8 BOM hat
    if (Test-UTF8BOM -FilePath $fileFullPath) {
        Write-Host "[SKIP] $fileFullPath" -ForegroundColor Gray
        $skipCount++
    }
    else {
        if (Convert-FileToUTF8BOM -FilePath $fileFullPath) {
            Write-Host "[OK]   $fileFullPath" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Host "[ERR]  $fileFullPath" -ForegroundColor Red
            $failureCount++
        }
    }
}

# Zusammenfassung
Write-Host "`n" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "    ZUSAMMENFASSUNG" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "`n" -ForegroundColor Cyan

Write-Host "Erfolgreich konvertiert: " -ForegroundColor Green -NoNewline
Write-Host $successCount -ForegroundColor Yellow

Write-Host "Bereits UTF-8 BOM:      " -ForegroundColor Green -NoNewline
Write-Host $skipCount -ForegroundColor Gray

Write-Host "Fehler:                 " -ForegroundColor Green -NoNewline
Write-Host $failureCount -ForegroundColor Red

Write-Host "Gesamt:                 " -ForegroundColor Green -NoNewline
Write-Host $filesToPatch.Count -ForegroundColor Cyan

Write-Host "`n" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "    Fertig!" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "`n" -ForegroundColor Cyan

# Erfolgreicher Exit
exit 0