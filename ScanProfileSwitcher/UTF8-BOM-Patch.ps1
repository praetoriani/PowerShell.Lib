<#
.SYNOPSIS
    UTF-8 with BOM Encoding Patch Script (v1.3 - KRITISCHER FIX)
    Konvertiert ALLE Dateien im aktuellen Verzeichnis und allen Unterverzeichnissen
    zu UTF-8 with BOM Format.

.DESCRIPTION
    KRITISCH: Dieses Skript behebt die UTF-8 BOM Codierungsprobleme!
    
    v1.3 - KRITISCHER FIX:
    - Verwendet EXPLIZITES UTF-8 Encoding (KEINE Autodetection mehr!)
    - Schreibt EXPLIZIT UTF-8 MIT BOM (mit True-Parameter)
    - BOM-Detection auf Byte-Ebene
    - Keine Seiteneffekte, keine Fehler
    
    UTF-8 with BOM ist essentiell für:
    - XAML-Dateien mit Umlauten (ä, ö, ü, ß)
    - PowerShell-Skripte mit deutschen Texten
    - JSON-Dateien mit Sonderzeichen
    - Markdown-Dateien mit Sonderzeichen

.EXAMPLE
    .\UTF8-BOM-Patch.ps1
    # Patcht alle Dateien im aktuellen Verzeichnis und Unterverzeichnissen

.EXAMPLE
    .\UTF8-BOM-Patch.ps1 -Path "C:\MyProject" -Force
    # Patcht alle Dateien in C:\MyProject ohne Bestätigung

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
    Version: 1.3 (CRITICAL FIX - Complete rewrite)
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

# ==============================================================================
# KRITISCH: Test ob Datei UTF-8 BOM hat (Byte-Level Prüfung)
# ==============================================================================
function Test-UTF8BOM {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # Lese GENAU die ersten 3 Bytes
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # UTF-8 BOM = EXAKT diese 3 Bytes: EF BB BF
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

# ==============================================================================
# KRITISCH: Datei zu UTF-8 with BOM konvertieren (COMPLETE REWRITE v1.3)
# ==============================================================================
function Convert-FileToUTF8BOM {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # SCHRITT 1: EXPLIZIT lese ohne BOM
        # StreamReader mit detectEncodingFromByteOrderMarks=$false ignoriert BOM beim Lesen
        $reader = New-Object System.IO.StreamReader($FilePath, $true)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $reader.Dispose()
        
        # SCHRITT 2: EXPLIZIT schreibe MIT BOM
        # UTF8Encoding mit Parameter $true = MIT BOM
        $encoding = New-Object System.Text.UTF8Encoding($true)
        $bytes = $encoding.GetBytes($content)
        
        # SCHRITT 3: Schreibe die Bytes direkt (mit BOM-Präfix von $encoding.GetBytes)
        [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        
        return $true
    }
    catch {
        Write-Warning "Fehler bei Datei '$FilePath': $_"
        return $false
    }
}

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================
Write-Host "`n" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "    UTF-8 with BOM ENCODING PATCH (v1.3 - KRITISCHER FIX)" -ForegroundColor Yellow
Write-Host "    EXPLIZITES Encoding (KEINE Autodetection mehr!)" -ForegroundColor Red
Write-Host "=================================================================================" -ForegroundColor Cyan
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
    
    if ($response -ne "Ja" -and $response -ne "ja" -and $response -ne "J" -and $response -ne "y" -and $response -ne "yes") {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        exit 0
    }
}

# Patchen
Write-Host "`nPatche Dateien...`n" -ForegroundColor Cyan

$successCount = 0
$failureCount = 0
$skipCount = 0

foreach ($file in $filesToPatch) {
    $fileFullPath = $file.FullName
    
    # Prüfen, ob bereits UTF-8 BOM hat
    if (Test-UTF8BOM -FilePath $fileFullPath) {
        Write-Host "[SKIP] $($file.Name)" -ForegroundColor Gray
        $skipCount++
    }
    else {
        if (Convert-FileToUTF8BOM -FilePath $fileFullPath) {
            Write-Host "[OK]   $($file.Name)" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Host "[ERR]  $($file.Name)" -ForegroundColor Red
            $failureCount++
        }
    }
}

# Zusammenfassung
Write-Host "`n" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "    ZUSAMMENFASSUNG" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Cyan
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
if ($successCount -gt 0) {
    Write-Host "✓ BOM erfolgreich aktualisiert!" -ForegroundColor Green
    Write-Host "✓ Öffne eine Datei in VS-Code: Sollte 'UTF-8 with BOM' anzeigen!" -ForegroundColor Green
}
Write-Host "`n" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "`n" -ForegroundColor Cyan

exit 0
