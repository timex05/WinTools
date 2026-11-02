# Can be run locally or via: irm https://raw.githubusercontent.com/timex05/WinTools/main/scripts/Install-Online.ps1 | iex
param(
    [string]$Target = (Join-Path $env:USERPROFILE 'WinTools'),
    [switch]$SkipWinhanceSetup
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$source = 'https://raw.githubusercontent.com/timex05/WinTools/main'
$scriptDirectory = Join-Path $Target 'scripts'
$configDirectory = Join-Path $Target 'configs'
$downloadScript = Join-Path $scriptDirectory 'Download-PortableTools.ps1'

# Fetch the current config before starting the longer tool downloads.
$files = @(
    'configs/Winhance_Config_20261101.winhance',
    'scripts/Prepare-TaskbarPins.ps1',
    'scripts/Update-PortableTools.ps1',
    'scripts/Uninstall-PortableTools.ps1',
    'scripts/Install-Online.ps1',
    'README.md'
)
try {
    $null = New-Item -ItemType Directory -Path $scriptDirectory -Force
    $null = New-Item -ItemType Directory -Path $configDirectory -Force
} catch { Write-Warning "Zielordner konnten nicht angelegt werden: $($_.Exception.Message)" }
foreach ($file in $files) {
    $path = Join-Path $Target $file
    $temporary = $path + '.part'
    try {
        Invoke-WebRequest -Uri "$source/$file" -UseBasicParsing -OutFile $temporary -TimeoutSec 60
        if ($file -like '*.winhance') {
            $config = Get-Content -LiteralPath $temporary -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($config.Version -ne '2.0' -or -not $config.Customize) {
                throw 'Die heruntergeladene Datei ist keine Winhance-v2-Konfiguration.'
            }
        }
        Move-Item -LiteralPath $temporary -Destination $path -Force
        if ($file -like '*.winhance') { Write-Host "Winhance-Konfiguration gespeichert: $path" -ForegroundColor Green }
    } catch {
        Write-Warning ("{0} konnte nicht geladen werden: {1}" -f $file, $_.Exception.Message)
    } finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
}

# A missing companion file must not prevent the tool downloads.
try {
    $null = New-Item -ItemType Directory -Path $scriptDirectory -Force
    Invoke-WebRequest -Uri "$source/scripts/Download-PortableTools.ps1" -UseBasicParsing -OutFile $downloadScript
    Write-Host "Lade portable Programme nach $(Join-Path $Target 'Portable-Tools') ..."
    $downloader = [scriptblock]::Create((Get-Content -LiteralPath $downloadScript -Raw))
    & $downloader -Destination (Join-Path $Target 'Portable-Tools') -SkipWinhanceSetup:$SkipWinhanceSetup
} catch {
    Write-Warning "Tool-Download konnte nicht ausgefuehrt werden: $($_.Exception.Message)"
}
