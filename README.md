# WinTools Portable Downloads

Dieses Repository enthält PowerShell-Skripte zum Herunterladen portabler Windows-Werkzeuge. Jedes Programm liegt in einem eigenen Unterordner von `Portable-Tools`. ZIP-Pakete werden dort entpackt; EXE-Dateien werden dort gespeichert. Winhance wird zusätzlich über seinen offiziellen Installer automatisch im Portable-Modus vorbereitet. Winhance selbst und die übrigen Programme werden nicht gestartet. Die Windows-Einstellungen werden erst nach Prüfung und Bestätigung in Winhance angewendet.

```text
WinTools/
├── README.md
├── configs/
│   └── Winhance_Config_20261101.winhance
├── scripts/
│   ├── Download-PortableTools.ps1
│   ├── Install-Online.ps1
│   ├── Prepare-TaskbarPins.ps1
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
irm https://raw.githubusercontent.com/timex05/WinTools/main/scripts/Install-Online.ps1 | iex
```

Das legt `WinTools` im Benutzerprofil an. Zuerst werden die aktuelle Konfiguration `WinTools\configs\Winhance_Config_20261101.winhance`, die Hilfsskripte und die README geladen. Danach werden die portablen Programme nach `WinTools\Portable-Tools` heruntergeladen und Winhance Portable vorbereitet. Ein zweiter Skriptaufruf ist dafür nicht nötig. Fehler beim Abruf der Begleitdateien werden angezeigt und verhindern den Tool-Download nicht. Der Einzeiler verwendet den aktuellen `main`-Stand; der alte Link mit `7426848` enthält noch die gelöschten Config-Dateinamen und sollte nicht mehr verwendet werden.

## Lokal ausführen

```powershell
.\scripts\Download-PortableTools.ps1
.\scripts\Update-PortableTools.ps1
.\scripts\Uninstall-PortableTools.ps1
```

`Update` entfernt den bisherigen Programmordner und lädt die aktuellen Ausgaben neu. `Uninstall` entfernt nur einen Programmordner, der vom Downloadskript markiert wurde. Ein anderer Zielordner kann mit `-Destination 'D:\MeineTools'` übergeben werden.

Enthalten sind die portablen Ausgaben von CPU-Z, HWMonitor, HWiNFO, WizTree, CrystalDiskInfo, CrystalDiskMark, Revo Uninstaller, HDD Low Level Format Tool, ServiWin, Rufus, GPU-Z und DDU. Zusätzlich wird Winhance Portable eingerichtet. Nicht erreichbare Downloads werden übersprungen. Mit `.\scripts\Download-PortableTools.ps1 -Verbose` werden zusätzliche Diagnosemeldungen angezeigt.

Die Dateien kommen von den offiziellen Downloadseiten, deren verlinkten Mirrors oder GitHub-Releases der Entwickler. GPU-Z wird über die Mirror-Auswahl von TechPowerUp geladen und benötigt kein `winget`. HWiNFO übermittelt beim ZIP-Download die Hersteller-Downloadseite als Herkunftsseite (Referer), da der Hersteller einen Hotlink-Schutz verwendet. Bei einem fehlgeschlagenen Download wird der nächste offizielle ZIP-Mirror versucht. CrystalDiskInfo und CrystalDiskMark verwenden nach Auflösung des Herstellerlinks den direkten SourceForge-Dateidownload. Revo Uninstaller verwendet den aktuellen ZIP-Link der Herstellerseite. Für ZIPs mit Deflate64-Kompression, wie das Revo-Paket, nutzt das Skript bei Bedarf die ZIP-Funktion des Windows-Explorers. Dafür wird kein zusätzliches Programm benötigt. ZIPs werden zunächst in einem temporären Ordner entpackt und erst nach erfolgreichem Abschluss in den Tool-Ordner verschoben.

Fehlende Tools lassen sich durch erneutes Ausführen des Einzeilers oder von `Download-PortableTools.ps1` nachladen. Bereits gefüllte Tool-Ordner werden dabei nicht erneuert. Enthält ein fehlgeschlagener Download noch Dateien, zuerst nur den betroffenen Unterordner in `Portable-Tools` löschen und erneut herunterladen. Bei einem zuvor fehlgeschlagenen Revo-Entpackversuch betrifft das `Portable-Tools\RevoUninstaller`. Die Skripte wurden unter Linux erstellt; ein Lauf unter Windows wurde hier nicht ausgeführt.

Während des Downloads zeigt PowerShell den Gesamtfortschritt über alle 13 Programme und den Fortschritt der aktuellen Datei: Prozent, übertragene und gesamte Bytes, lesbare Dateigrößen, Geschwindigkeit, Laufzeit und geschätzte Restzeit. Meldet der Server keine Dateigröße, werden übertragene Bytes, Geschwindigkeit und Laufzeit angezeigt; Prozent und Restzeit bleiben unbekannt. Die Phasen Downloadsuche, Prüfung und Entpacken werden ebenfalls angezeigt. Jedes Programm erhält eine Statuszeile für „Fertig“, „Bereits vorhanden“ oder „Nicht verfügbar“. Am Ende stehen die Anzahl verfügbarer Programme, die übertragene Datenmenge und die Gesamtzeit. Das gilt auch beim Online-Start und beim Aktualisieren.

## Winhance Portable und Konfiguration

Winhance wird automatisch als `Portable-Tools\Winhance\Winhance.exe` vorbereitet. Der offizielle Installer wird mit den Optionen für **Portable**, den aktuellen Benutzer und den gewünschten Zielordner ausgeführt. Die portable Ausgabe wird anhand von `Winhance.exe` und `portable.marker` geprüft. Die Anwendung wird nicht automatisch gestartet. Die verwendeten Installer-Optionen sind im [offiziellen Winhance-Installer](https://github.com/memstechtips/Winhance/blob/v26.06.12/extras/Winhance.Installer.iss) definiert.

Bereits eingerichtete portable Ausgaben werden übersprungen. Liegt aus einem früheren Lauf nur `Winhance.Installer.exe` im Winhance-Ordner, wird die Portable-Einrichtung beim nächsten Lauf nachgeholt. Andere vorhandene Dateien werden nicht überschrieben. Schlägt die Einrichtung fehl, erscheint eine Warnung; der Installer bleibt zur manuellen Verwendung erhalten. Mit `-SkipWinhanceSetup` bei Download, Update oder dem lokal ausgeführten Online-Installer lässt sich ausschließlich der Installer herunterladen.

Die aktuelle Datei ist [`configs/Winhance_Config_20261101.winhance`](configs/Winhance_Config_20261101.winhance). Die früheren Profile `gaming-safe` und `gaming-extreme` wurden durch diesen eigenen Export ersetzt. Der Export enthält App-Entfernungen, die Installation von Chrome, Discord, OBS Studio, Steam, Epic Games Launcher und Revo Uninstaller sowie zahlreiche Windows-Einstellungen. **Show Widgets** ist ausgeschaltet, damit die Wetteranzeige in der Taskleiste verschwindet. Alle anderen exportierten Einstellungen bleiben erhalten.

Winhance starten und **Import Config → Import my own config** wählen. Beim Online-Start liegt die Datei unter `%USERPROFILE%\WinTools\configs\Winhance_Config_20261101.winhance`. Im standardmäßig aktivierten **Review Mode** die Änderungen prüfen und anschließend **Apply Config** wählen. Die Funktion zum Überspringen der Prüfung ausgeschaltet lassen. App-Entfernungen und App-Installationen im Importdialog ausdrücklich auswählen, wenn sie sofort ausgeführt werden sollen. Falls die Wetteranzeige nach dem Anwenden noch sichtbar ist, einmal ab- und wieder anmelden.

## Explorer und Chrome an die Taskleiste anheften

Winhance unterstützt in seiner Config keine frei wählbaren App-Pins. Microsofts [Automatisierung über Taskleisten-Layouts](https://learn.microsoft.com/en-us/windows/configuration/taskbar/pinned-apps) verwendet Verwaltungsrichtlinien und ist kein allgemeiner Weg für alle Windows-11-Editionen. Das Hilfsskript bereitet deshalb Verknüpfungen für den manuellen Anheftschritt vor.

Nach dem Anwenden der Winhance-Konfiguration und der Chrome-Installation aus dem WinTools-Ordner ausführen:

```powershell
.\scripts\Prepare-TaskbarPins.ps1
# Bei einem eigenen Tool-Ziel:
.\scripts\Prepare-TaskbarPins.ps1 -Destination 'D:\MeineTools'
```

Das Skript öffnet `Portable-Tools\Taskleisten-Verknuepfungen` mit Verknüpfungen zu Explorer und dem tatsächlich installierten Chrome. Jeweils **Rechtsklick → Weitere Optionen anzeigen → An Taskleiste anheften** wählen. Alternativ beide Apps öffnen und am jeweiligen Taskleistensymbol per Rechtsklick **An Taskleiste anheften** wählen. Diese manuelle Vorgehensweise ist auch für Windows 11 Home geeignet. „Clean Taskbar“ in Winhance danach nicht ausführen, da es die Pins wieder entfernt.
