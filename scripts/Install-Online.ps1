# Can be run locally or via: irm https://raw.githubusercontent.com/timex05/WinTools/main/scripts/Install-Online.ps1 | iex
param([string]$Target = (Join-Path $env:USERPROFILE 'WinTools'))

$ErrorActionPreference = 'Stop'
$source = 'https://raw.githubusercontent.com/timex05/WinTools/main'
$scriptDirectory = Join-Path $Target 'scripts'
$configDirectory = Join-Path $Target 'configs'
$files = @(
    'Download-PortableTools.ps1',
    'Update-PortableTools.ps1',
    'Uninstall-PortableTools.ps1',
    'Install-Online.ps1'
)

try {
    $null = New-Item -ItemType Directory -Path $scriptDirectory -Force
    $null = New-Item -ItemType Directory -Path $configDirectory -Force
    foreach ($file in $files) {
        Invoke-WebRequest -Uri "$source/scripts/$file" -UseBasicParsing -OutFile (Join-Path $scriptDirectory $file)
    }
    Invoke-WebRequest -Uri "$source/README.md" -UseBasicParsing -OutFile (Join-Path $Target 'README.md')
    Invoke-WebRequest -Uri "$source/configs/gaming-safe.winhance" -UseBasicParsing -OutFile (Join-Path $configDirectory 'gaming-safe.winhance')
    Invoke-WebRequest -Uri "$source/configs/gaming-extreme.winhance" -UseBasicParsing -OutFile (Join-Path $configDirectory 'gaming-extreme.winhance')
    & (Join-Path $scriptDirectory 'Download-PortableTools.ps1') -Destination (Join-Path $Target 'Portable-Tools')
} catch {}
