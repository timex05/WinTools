# WinTools

Script-only repository for downloading portable Windows diagnostic/maintenance tools and for maintaining two Winhance v2 profiles. There is no build system, test suite, package manager, or CI.

## Layout

- `scripts/Download-PortableTools.ps1` — the tool catalog and downloader. Default destination is `<repo>/Portable-Tools` (gitignored), derived from `$PSScriptRoot`; moving the script changes that default.
- `scripts/Update-PortableTools.ps1` — runs Uninstall, then Download. With a marked destination this wipes everything and re-downloads it.
- `scripts/Uninstall-PortableTools.ps1` — deletes the destination only if it contains the `.wintools-portable-tools` marker.
- `scripts/Install-Online.ps1` — bootstrap for `irm .../main/scripts/Install-Online.ps1 | iex`. Writes to `%USERPROFILE%\WinTools`, downloads an explicit file list, then runs Download. The decisions CSV is intentionally not downloaded.
- `configs/gaming-safe.winhance` — minimal profile: Game Mode and windowed-game optimizations only.
- `configs/gaming-extreme.winhance` — aggressive full profile with app removals/installs and customization.
- `configs/gaming-extreme-entscheidungen.csv` — German decision log for the extreme profile. UTF-8 BOM, CRLF, `;` delimiter; not read by any script.
- `Portable-Tools/` — generated output. Never commit downloads or extracted tools; `.gitignore` only covers this directory.

Git history still contains the old committed binary folders. The current script-only layout is intentional; do not restore or re-add those tools.

## Commands

No build/test/lint. Scripts target Windows PowerShell (5.1-compatible, no `pwsh`-only syntax). This Linux checkout has no `pwsh`, so they cannot be executed or syntax-checked here. README states they have not been run on Windows yet.

On Windows:

```powershell
.\scripts\Download-PortableTools.ps1
.\scripts\Update-PortableTools.ps1
.\scripts\Uninstall-PortableTools.ps1
# all accept -Destination 'D:\Tools'
```

Validate the JSON profiles on Linux:

```bash
python3 -m json.tool configs/gaming-safe.winhance >/dev/null
python3 -m json.tool configs/gaming-extreme.winhance >/dev/null
```

## Downloader rules

- Add a tool to the relevant block in `Download-PortableTools.ps1` (`$tools`, CrystalDisk*, GitHub, GPU-Z, DDU). `Name` becomes the subfolder name.
- `Save-Portable` only accepts `.zip` and `.exe` URLs. ZIPs are checked by magic bytes, extracted, and deleted; EXEs are kept. Other formats are skipped.
- GPU-Z uses TechPowerUp's download form and mirror-selection POST to obtain the standalone EXE; no tool needs `winget`. The WinGet package is typed as `exe`, and its static download URL can be unavailable.
- Winhance is downloaded as the official `Winhance.Installer.exe`, which offers a Portable option. Never run the installer automatically.
- Missing downloads, bad mirrors, and network errors are swallowed on purpose; only a success count is printed. Do not turn these into hard failures without a deliberate design change.
- A non-empty tool folder is never refreshed, even if stale. Delete `Portable-Tools/<Tool>` and re-run, or use Update to wipe everything.
- The marker file gates both overwrite and uninstall. A non-empty destination without `.wintools-portable-tools` is left untouched.
- Anything fetched by `Install-Online.ps1` must be added to its `$files`/download list; otherwise online installs will not include it.
- `Install-Online.ps1` hardcodes `https://raw.githubusercontent.com/timex05/WinTools/main`; pushing to `main` changes what users execute immediately.

## Winhance profiles

- Keep `gaming-safe` limited to Game Mode and windowed-game optimizations; it must not remove apps or change security, services, or power plans.
- Keep `gaming-extreme` aligned with `gaming-extreme-entscheidungen.csv`; update the CSV when changing a decision.
- The documented policy excludes hardware-specific registry tweaks and disabling security features or Windows Update. Do not add them.
- README tells users to keep Winhance's Review Mode enabled; do not recommend bypassing it.

## Docs and language

- README and the CSV are German; script comments are English. Match the file you edit.
- Preserve the CSV's UTF-8 BOM, CRLF endings, and semicolon delimiter (it is meant for German Excel).
- README is user documentation and is also installed by the online bootstrap; keep its install behavior and file lists in sync with the scripts.
