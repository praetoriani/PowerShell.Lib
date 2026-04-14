# Edge² SplashScreen Implementation Guide

Dieses Dokument beschreibt die notwendigen Änderungen an `PowerEdge.ps1` zur Integration der SplashScreen-Funktionalität.

## Übersicht

Die Implementierung fügt folgende Features hinzu:
1. **SplashScreen-Anzeige** wenn `-Hidden` Parameter verwendet wird
2. **Automatisches Laden zweier URLs** mit konfigurierbarem Timing
3. **Startup-Konfiguration** aus config.json

## Dateien erstellt

- ✅ `data/ui/startup.window.xml` - SplashScreen XAML
- ✅ `data/config.json` - Erweitert um "startup" Block
- ✅ `data/fxlib/ShowSplashScreen.ps1` - SplashScreen Helper-Funktion

## Notwendige Änderungen in PowerEdge.ps1

### 1. Startup-Konfiguration laden (nach Zeile ~120)

```powershell
# Load startup configuration from config.json
$global:startURL = if ($peCore.PSObject.Properties['startup']) { $peCore.startup.starturl } else { "" }
$global:secondURL = if ($peCore.PSObject.Properties['startup']) { $peCore.startup.secondurl } else { "" }
$global:secondURLDelay = if ($peCore.PSObject.Properties['startup']) { $peCore.startup.secondurldelay } else { 0 }
```

### 2. SplashScreen starten wenn -Hidden verwendet wird (nach Zeile ~230, VOR dem UI-Runspace)

```powershell
# Start splash screen if -Hidden mode is active
if ($Hidden.IsPresent -and $Timeout -gt 0) {
    ShowSplashScreen -Timeout $Timeout -AppIcon $global:appicon -UiPath $global:uipath
}
```

### 3. URL-Lade-Logik im UI-Runspace ergänzen (im WebView2InitializationCompleted Event)

Ersetze den bestehenden Navigate-Aufruf:

```powershell
# ALT:
$fileUri = [System.Uri]::new($syncHash.HtmlPath)
$sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)

# NEU:
if ($syncHash.StartURL -ne "") {
    # Load initial startup URL
    $sender.CoreWebView2.Navigate($syncHash.StartURL)
    
    # Schedule second URL load if configured
    if ($syncHash.SecondURL -ne "" -and $syncHash.SecondURLDelay -gt 0) {
        LoadURLafter -WebView $sender -URL $syncHash.SecondURL -DelayMs $syncHash.SecondURLDelay
    }
} else {
    # Fallback: use original HTML path
    $fileUri = [System.Uri]::new($syncHash.HtmlPath)
    $sender.CoreWebView2.Navigate($fileUri.AbsoluteUri)
}
```

### 4. SyncHash erweitern (Zeile ~180)

Füge folgende Einträge dem `$syncHash` hinzu:

```powershell
$syncHash = [hashtable]::Synchronized(@{
    # ... existing entries ...
    StartURL = $global:startURL
    SecondURL = $global:secondURL
    SecondURLDelay = $global:secondURLDelay
})  
```

## Verwendung

### Szenario: Desktop-Verknüpfung startet PowerEdge mit SplashScreen

**Verknüpfungs-Ziel:**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\PowerEdge.ps1" -Hidden -Timeout 6000
```

**Ablauf:**
1. PowerEdge startet hidden
2. SplashScreen wird als separater Prozess angezeigt ("Bitte warten...")
3. Im Hintergrund: starturl wird sofort geladen
4. Nach 3000ms (config.json): secondurl wird geladen
5. Nach 6000ms Timeout: SplashScreen verschwindet, PowerEdge-Fenster wird sichtbar

## Konfiguration in config.json

```json
"startup": {
    "starturl":      "http://localhost:8080/home.html",
    "secondurl":     "http://localhost:8080/app.html",
    "secondurldelay": 3000
}
```

## Test ohne config.json startup-Block

Falls `config.json` den "startup"-Block nicht enthält:
- Fallback: PowerEdge lädt die normale HTML-Datei aus `-httpRoot`
- Kein SplashScreen (da `-Hidden` ohne URLs keinen Sinn macht)

## Wichtige Hinweise

1. **SplashScreen ist ein separater Prozess** → wird auch bei hidden window angezeigt
2. **Kein Close-Button im SplashScreen** → schließt automatisch nach Timeout
3. **URLs müssen gültig sein** → sonst bleibt WebView2 leer
4. **ShowSplashScreen.ps1 wird automatisch geladen** (dotsourcing aus data/fxlib)

## Commit Summary

Alle Änderungen verwenden die Commit-Message: **"Edge² Update"**

---

**Status:** ✅ Bereit zur Integration in PowerEdge.ps1  
**Version:** 1.00.02  
**Autor:** Praetoriani  
**Datum:** 14.04.2026
