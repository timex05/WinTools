# Creates shortcuts for the final, manual taskbar pin action on Windows 11.
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $Destination '.wintools-portable-tools'))) {
    throw 'Bitte zuerst Download-PortableTools.ps1 fuer diesen Zielordner ausfuehren.'
}
$shortcutDirectory = Join-Path (Resolve-Path $Destination).Path 'Taskleisten-Verknuepfungen'
$null = New-Item -ItemType Directory -Path $shortcutDirectory -Force

# Chrome supports per-user and machine-wide installs in different directories.
$chromeCandidates = @(
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    )) {
        if (Test-Path -LiteralPath $key) { (Get-Item -LiteralPath $key).GetValue('') }
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) { Join-Path $base 'Google\Chrome\Application\chrome.exe' }
    }
)
$chrome = $chromeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
$apps = @(@{ Name = 'Explorer'; Path = (Join-Path $env:WINDIR 'explorer.exe') })
if ($chrome) {
    $apps += @{ Name = 'Google Chrome'; Path = $chrome }
} else {
    Write-Warning 'Google Chrome wurde nicht gefunden. Zuerst ueber Winhance installieren, dann dieses Skript erneut ausfuehren.'
}

$shell = New-Object -ComObject WScript.Shell
try {
    foreach ($app in $apps) {
        $shortcut = $shell.CreateShortcut((Join-Path $shortcutDirectory ($app.Name + '.lnk')))
        try {
            $shortcut.TargetPath = $app.Path
            $shortcut.WorkingDirectory = Split-Path -Parent $app.Path
            $shortcut.IconLocation = $app.Path + ',0'
            $shortcut.Save()
        } finally { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }
    }
} finally { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }

Write-Host "Verknuepfungen vorbereitet: $shortcutDirectory" -ForegroundColor Green
Write-Host 'Jeweils Rechtsklick -> Weitere Optionen anzeigen -> An Taskleiste anheften.'
Write-Host 'Alternativ die App starten und ihr Taskleistensymbol mit Rechtsklick anheften.'
Write-Host 'Winhance-Konfiguration vorher anwenden; Taskleiste bereinigen kann Pins entfernen.'
Invoke-Item -LiteralPath $shortcutDirectory
