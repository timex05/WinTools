# Removes only a tool folder created by Download-PortableTools.ps1.
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools')
)

$marker = Join-Path $Destination '.toolstick-portable-tools'
if (Test-Path -LiteralPath $marker) {
    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
}
