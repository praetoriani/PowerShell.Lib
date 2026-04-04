<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

***

# 🗂️ ModernMDV — Projektstruktur

```
ModernMDV/
├── ModernMDV.ps1          ← Hauptskript (Einstiegspunkt + MainLoop)
├── config.json            ← Konfiguration (analog ModernUI)
├── runtime.log            ← Wird automatisch erstellt
├── WPF/
│   ├── MainWindow.xaml    ← Hauptfenster-Layout
│   ├── PopupAbout.xaml    ← Info-Dialog
│   ├── PopupHelp.xaml     ← Hilfe-Dialog
│   └── PopupSettings.xaml ← Einstellungen-Dialog
├── Lib/
│   └── UI.lib             ← Base64-Grafikressourcen (Platzhalter)
├── PNG/
│   └── *.png              ← Deine eigenen Grafiken (siehe Doku unten)
└── Docs/
    └── QUICKSTART.md      ← Schnellstart-Anleitung
```

***

## 📋 PNG-Asset-Checkliste & Bild-Spezifikationen

Alle Button-Icons für die Titelleiste werden **exakt im ModernUI-Stil** erwartet:

| Eigenschaft | Wert |
|---|---|
| **Größe** | 20 × 20 px |
| **Format** | PNG, 32-Bit RGBA (Transparenz!) |
| **Normal-Zustand** | Dezente Ikonographie, z. B. weißes Icon auf transparentem Grund |
| **Hover-Zustand** | Leichter Farbwechsel (z. B. Cyan/Blau-Akzent) oder Helligkeitserhöhung |
| **Ordner** | `./PNG/` (solange UI.lib nicht vollständig befüllt ist) |

Der Button-Reihenfolge in der Titelleiste (rechts → links = Settings → Help → Info → OpenFile ‖ Minimieren → Maximieren → Schließen) entsprechen genau die Dateinamen in `config.json`.

***

## 🚀 Starten und testen

```powershell
# Einfach starten:
pwsh -File ".\ModernMDV.ps1"

# Mit einer MD-Datei direkt:
pwsh -File ".\ModernMDV.ps1" -MarkdownFile ".\Docs\QUICKSTART.md"
```

***
Made with 💖 in Munich (Bavaria, Germany)
