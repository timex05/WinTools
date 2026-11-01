# Can be run locally or via: irm https://raw.githubusercontent.com/timex05/WinTools/main/scripts/Install-Online.ps1 | iex
param([string]$Target = (Join-Path $env:USERPROFILE 'WinTools'))

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$source = 'https://raw.githubusercontent.com/timex05/WinTools/main'
$scriptDirectory = Join-Path $Target 'scripts'
$configDirectory = Join-Path $Target 'configs'
$downloadScript = Join-Path $scriptDirectory 'Download-PortableTools.ps1'

# Start the tool downloads before fetching optional documentation and profiles.
try {
    $null = New-Item -ItemType Directory -Path $scriptDirectory -Force
    Invoke-WebRequest -Uri "$source/scripts/Download-PortableTools.ps1" -UseBasicParsing -OutFile $downloadScript
    $downloader = [scriptblock]::Create((Get-Content -LiteralPath $downloadScript -Raw))
    & $downloader -Destination (Join-Path $Target 'Portable-Tools')
} catch {}

# Keep the helper scripts and profiles for later use; failures are independent.
$files = @(
    'scripts/Update-PortableTools.ps1',
    'scripts/Uninstall-PortableTools.ps1',
    'scripts/Install-Online.ps1',
    'README.md',
    'configs/gaming-safe.winhance',
    'configs/gaming-extreme.winhance'
)

try { $null = New-Item -ItemType Directory -Path $configDirectory -Force } catch {}
foreach ($file in $files) {
    try {
        Invoke-WebRequest -Uri "$source/$file" -UseBasicParsing -OutFile (Join-Path $Target $file)
    } catch {}
}
