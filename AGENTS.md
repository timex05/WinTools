# WinTools

Script-only repository for downloading portable Windows diagnostic/maintenance tools and maintaining a Winhance v2 configuration. There is no build system, test suite, package manager, or CI.

## Layout

- `scripts/Download-PortableTools.ps1` — the tool catalog and downloader. Default destination is `<repo>/Portable-Tools` (gitignored), derived from `$PSScriptRoot`; moving the script changes that default.
- `scripts/Update-PortableTools.ps1` — runs Uninstall, then Download. With a marked destination this wipes everything and re-downloads it.
- `scripts/Uninstall-PortableTools.ps1` — deletes the destination only if it contains the `.wintools-portable-tools` marker.
- `scripts/Install-Online.ps1` — bootstrap for `irm .../main/scripts/Install-Online.ps1 | iex`. Writes to `%USERPROFILE%\WinTools`, fetches the current config and companions first, then runs Download. Failures are reported independently.
- `scripts/Prepare-TaskbarPins.ps1` — prepares Explorer and installed Chrome shortcuts for the user's manual taskbar pin action. This is the cross-edition Windows 11 fallback; Winhance has no arbitrary app-pin config field.
- `configs/Winhance_Config_20261101.winhance` — the user's exported Winhance v2 profile, with Widgets disabled. Preserve its CRLF endings. The old gaming profiles and decisions CSV were intentionally deleted; do not restore them.
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
python3 -m json.tool configs/Winhance_Config_20261101.winhance >/dev/null
```

## Downloader rules

- Add a tool to the relevant block in `Download-PortableTools.ps1` (`$tools`, CrystalDisk*, GitHub, GPU-Z, DDU). `Name` becomes the subfolder name.
- `Save-Portable` only accepts `.zip` and `.exe` URLs. ZIPs are checked by magic bytes, extracted, and deleted; EXEs are kept. Other formats are skipped.
- GPU-Z uses TechPowerUp's download form and mirror-selection POST to obtain the standalone EXE; no tool needs `winget`. The WinGet package is typed as `exe`, and its static download URL can be unavailable.
- At the user's request, the official `Winhance.Installer.exe` is run automatically with `/CURRENTUSER /SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /TASKS="portableinstall" /DIR="..."`. Use an empty temporary output folder: the installer deletes existing files in its output directory. Verify `Winhance.exe` and `portable.marker` before moving output into the tool folder. Never launch Winhance or apply its config automatically. `-SkipWinhanceSetup` opts out of setup.
- Missing downloads, bad mirrors, and network errors are non-fatal. Progress and per-tool status are shown; Winhance setup failures are warnings. Do not turn these into hard failures without a deliberate design change.
- A non-empty tool folder is never refreshed, even if stale. Winhance may complete portable setup if its folder contains only the previously downloaded installer. Otherwise delete `Portable-Tools/<Tool>` and re-run, or use Update to wipe everything.
- The marker file gates both overwrite and uninstall. A non-empty destination without `.wintools-portable-tools` is left untouched.
- Anything fetched by `Install-Online.ps1` must be added to its `$files`/download list; otherwise online installs will not include it.
- `Install-Online.ps1` hardcodes `https://raw.githubusercontent.com/timex05/WinTools/main`; pushing to `main` changes what users execute immediately.

## Winhance configuration

- Edit the current exported profile without changing unrelated settings. `Customize.Features.Taskbar` is included and `taskbar-widgets.IsSelected` is `false` to hide weather/widgets.
- The documented policy excludes hardware-specific registry tweaks and disabling security features or Windows Update. Do not add them.
- README tells users to keep Winhance's Review Mode enabled; do not recommend bypassing it.

## Docs and language

- README and user-facing script output are German; script comments are English. Match the file you edit.
- README is user documentation and is also installed by the online bootstrap; keep its install behavior and file lists in sync with the scripts.
