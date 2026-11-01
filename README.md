# WinTools Portable Downloads

Dieses Repository enthält PowerShell-Skripte zum Herunterladen portabler Windows-Werkzeuge. Jedes Programm liegt in einem eigenen Unterordner von `Portable-Tools`. ZIP-Pakete werden dort entpackt; direkt startbare EXE-Dateien werden dort gespeichert. Die Skripte installieren und starten keine Programme.

```text
WinTools/
├── README.md
├── configs/
│   ├── gaming-safe.winhance
│   ├── gaming-extreme.winhance
│   └── gaming-extreme-entscheidungen.csv
├── scripts/
│   ├── Download-PortableTools.ps1
│   ├── Install-Online.ps1
│   ├── Update-PortableTools.ps1
│   └── Uninstall-PortableTools.ps1
└── Portable-Tools/
    ├── CPU-Z/
    ├── CrystalDiskInfo/
    ├── HWiNFO/
    └── ...
```

## Online starten

In PowerShell ausführen:

```powershell
irm https://raw.githubusercontent.com/timex05/WinTools/7426848/scripts/Install-Online.ps1 | iex
```

Der Link verwendet die feste Installer-Version `7426848`, damit keine zwischengespeicherte ältere Version über den `main`-Link gestartet wird. Der Installer lädt die Tools sowie die Begleitdateien weiterhin aus dem aktuellen `main`-Stand.

Das legt `WinTools` im Benutzerprofil an und startet direkt den Download der portablen Programme nach `WinTools\Portable-Tools`. Ein zweiter Skriptaufruf ist nicht nötig. Anschließend werden die README, beide Winhance-Konfigurationen und die übrigen Skripte gespeichert. Fehler beim Abruf dieser Begleitdateien verhindern den Tool-Download nicht. Die Entscheidungs-CSV bleibt im Repository und wird nicht heruntergeladen.

## Lokal ausführen

```powershell
.\scripts\Download-PortableTools.ps1
.\scripts\Update-PortableTools.ps1
.\scripts\Uninstall-PortableTools.ps1
```

`Update` entfernt den bisherigen Programmordner und lädt die aktuellen Ausgaben neu. `Uninstall` entfernt nur einen Programmordner, der vom Downloadskript markiert wurde. Ein anderer Zielordner kann mit `-Destination 'D:\MeineTools'` übergeben werden.

Enthalten sind die portablen Ausgaben von CPU-Z, HWMonitor, HWiNFO, WizTree, CrystalDiskInfo, CrystalDiskMark, Revo Uninstaller, HDD Low Level Format Tool, ServiWin, Rufus, GPU-Z und DDU. Downloads, die vom Anbieter nicht als portable Fassung angeboten werden, werden ausgelassen. Auch nicht erreichbare Downloads werden ohne Fehlermeldung übersprungen.

Für GPU-Z wird `winget` benötigt. Die übrigen Dateien kommen von den offiziellen Downloadseiten oder GitHub-Releases der Entwickler. Die Skripte wurden unter Linux erstellt; ein Lauf unter Windows wurde hier nicht ausgeführt.

## Gaming-Konfigurationen für Winhance

Die Datei [`configs/gaming-safe.winhance`](configs/gaming-safe.winhance) aktiviert nur **Game Mode** und **Optimierungen für Fensterspiele**. Sie entfernt keine Apps und ändert weder Sicherheitsfunktionen noch Dienste oder Energiepläne.

Die Datei [`configs/gaming-extreme.winhance`](configs/gaming-extreme.winhance) ist das umfangreichere Windows-11-Gaming-Profil. Sie wählt Chrome, Steam, Epic Games Launcher, Discord, OBS Studio und Revo Uninstaller zur Installation. Sie entfernt 31 nicht genutzte Windows-Apps sowie Recall, darunter Xbox, Xbox Game Bar, Copilot, OneDrive, OneNote und Media Player. Microsoft Store sowie Xbox Identity Provider und Xbox Live In-Game Experience bleiben erhalten. Die einzelnen Entscheidungen stehen in [`configs/gaming-extreme-entscheidungen.csv`](configs/gaming-extreme-entscheidungen.csv).

Das extreme Profil aktiviert Spielmodus, Optimierungen für Fensterspiele und die Option **Task beenden** im Taskleisten-Kontextmenü. Startmenü, Taskleiste, Explorer und Design folgen den gewählten Einstellungen: keine Empfehlungen, Taskleiste links mit Suchsymbol und ohne Widgets, Explorer-Start bei „Dieser PC“, klassisches Kontextmenü, sichtbare Dateiendungen und versteckte Dateien, dunkles Design ohne Transparenzeffekte. Hardwareabhängige Registry-Tweaks und das Abschalten von Sicherheitsfunktionen sind nicht enthalten.

Die **Windows Update Policy** steht im extremen Profil auf **Disabled / Deaktiviert (Index 3)**. Dieser Winhance-Modus deaktiviert auch die Update-Dienste und blockiert Windows-Updates einschließlich Sicherheitsupdates. Zum manuellen Aktualisieren in Winhance unter **Optimize → Windows Update → Windows Update Policy** zuerst **Normal (Windows Default)** anwenden und anschließend in den Windows-Einstellungen nach Updates suchen. Nach Abschluss kann wieder **Disabled** gewählt werden. Laut [Winhance-Dokumentation und Quellcode](https://github.com/memstechtips/Winhance/blob/main/src/Winhance.Core/Features/Optimize/Models/UpdateOptimizations.cs) können bei deaktivierten Updates auch Microsoft-Store-App-Installationen blockiert werden.

Winhance kann Autostart-Apps global um zehn Sekunden verzögern, aber nicht pro App aus dieser Konfiguration entfernen oder beim Spielstart automatisch beenden. Autostart einzelner Apps unter **Einstellungen → Apps → Autostart** oder im Task-Manager verwalten. Die aktivierte Option **Task beenden** erlaubt das manuelle Beenden laufender Apps per Rechtsklick auf der Taskleiste.

Winhance ist nicht Teil des automatischen Downloads, weil seine portable Ausgabe über den eigenen Installer bereitgestellt wird. In Winhance Portable **Import Config** → **Import my own config** wählen und die gewünschte `.winhance`-Datei öffnen. Im standardmäßig aktivierten Review Mode alle Änderungen prüfen und **Apply Config** wählen. Die Funktion zum Überspringen der Prüfung ausgeschaltet lassen. Bei `gaming-extreme.winhance` App-Entfernungen und App-Installationen im Importdialog ausdrücklich auswählen, wenn sie sofort ausgeführt werden sollen.
