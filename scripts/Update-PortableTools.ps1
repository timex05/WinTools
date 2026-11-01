# Replaces the old portable download folder with current releases.
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools')
)

& (Join-Path $PSScriptRoot 'Uninstall-PortableTools.ps1') -Destination $Destination
& (Join-Path $PSScriptRoot 'Download-PortableTools.ps1') -Destination $Destination
