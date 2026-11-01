# Downloads portable Windows tools into one parent folder, one subfolder per tool.
# Run from PowerShell: .\scripts\Download-PortableTools.ps1
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools')
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
if ((Test-Path $Destination) -and
    @(Get-ChildItem -LiteralPath $Destination -Force).Count -gt 0 -and
    -not (Test-Path (Join-Path $Destination '.wintools-portable-tools'))) { return }
$null = New-Item -ItemType Directory -Path $Destination -Force
$Destination = (Resolve-Path $Destination).Path
Set-Content -LiteralPath (Join-Path $Destination '.wintools-portable-tools') -Value 'WinTools portable tools' -Encoding Ascii

function Get-PageLinks {
    param([string]$Page)
    $response = Invoke-WebRequest -Uri $Page -UseBasicParsing -MaximumRedirection 10
    $base = [uri]$response.BaseResponse.ResponseUri.AbsoluteUri
    if (-not $base) { $base = $Page }
    $matches = [regex]::Matches($response.Content, '(?is)href\s*=\s*["'']([^"''#]+)["'']')
    foreach ($match in $matches) {
        try { ([uri]::new([uri]$base, [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value))).AbsoluteUri } catch {}
    }
}

function Get-LatestLink {
    param([string]$Page, [string]$Pattern)
    $links = @(Get-PageLinks $Page)
    $links | Where-Object { $_ -match $Pattern } | Select-Object -First 1
}

function Get-LabeledLink {
    param([string]$Page, [string]$Label)
    $response = Invoke-WebRequest -Uri $Page -UseBasicParsing
    $base = [uri]$Page
    foreach ($match in [regex]::Matches($response.Content, '(?is)<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>(.*?)</a>')) {
        $text = [regex]::Replace($match.Groups[2].Value, '<[^>]+>', '')
        if ($text -match $Label) {
            return ([uri]::new($base, [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value))).AbsoluteUri
        }
    }
}

function Save-Portable {
    param([string]$Name, [string]$Url, [string]$FileName)
    if (-not $Url) { return $false }
    if (-not $FileName) {
        $FileName = [uri]::UnescapeDataString(([uri]$Url).Segments[-1])
    }
    if ($FileName -notmatch '\.(zip|exe)$') { return $false }
    $FileName = $FileName -replace '[\\/:*?"<>|]', '_'
    $toolDirectory = Join-Path $Destination $Name
    $path = Join-Path $toolDirectory $FileName
    if (Test-Path $path) { return $true }
    if ((Test-Path $toolDirectory) -and @(Get-ChildItem -LiteralPath $toolDirectory -Force).Count -gt 0) { return $true }
    $null = New-Item -ItemType Directory -Path $toolDirectory -Force
    $temporary = Join-Path $toolDirectory ($FileName + '.part')
    try {
        Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $temporary -MaximumRedirection 10
        if ((Get-Item $temporary).Length -lt 1024) { return $false }
        $stream = [IO.File]::OpenRead($temporary)
        try {
            $header = New-Object byte[] 4
            $null = $stream.Read($header, 0, 4)
        } finally { $stream.Dispose() }
        $isZip = $header[0] -eq 0x50 -and $header[1] -eq 0x4b
        $isExe = $header[0] -eq 0x4d -and $header[1] -eq 0x5a
        if (($FileName -match '\.zip$' -and -not $isZip) -or
            ($FileName -match '\.exe$' -and -not $isExe)) { return $false }
        if ($isZip) {
            $archive = Join-Path $toolDirectory $FileName
            Move-Item -LiteralPath $temporary -Destination $archive
            try { Expand-Archive -LiteralPath $archive -DestinationPath $toolDirectory -Force }
            finally { Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue }
        } else {
            Move-Item -LiteralPath $temporary -Destination $path
        }
        return $true
    } catch { return $false }
    finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
}

function Get-GitHubAsset {
    param([string]$Repository, [string]$Pattern)
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers @{ 'User-Agent' = 'WinTools-Portable-Downloader' }
    $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
}

$downloaded = 0

# Direct vendor links, selected from the current official download pages.
$tools = @(
    @{ Name = 'CPU-Z'; Page = 'https://www.cpuid.com/softwares/cpu-z.html'; Pattern = '/downloads/cpu-z/cpu-z_[^/?]+-en\.zip(?:\?|$)'; Landing = $true },
    @{ Name = 'HWMonitor'; Page = 'https://www.cpuid.com/softwares/hwmonitor.html'; Pattern = '/downloads/hwmonitor/hwmonitor_[^/?]+\.zip(?:\?|$)'; Landing = $true },
    @{ Name = 'HWiNFO'; Page = 'https://www.hwinfo.com/download/'; Pattern = '(?i)(hwinfo|hwi)[^/?]*\.zip(?:\?|$)' },
    @{ Name = 'WizTree'; Page = 'https://diskanalyzer.com/download'; Pattern = '(?i)wiztree[^/?]*portable[^/?]*\.zip(?:\?|$)' },
    @{ Name = 'RevoUninstaller'; Page = 'https://www.revouninstaller.com/start-freeware-download-portable/'; Pattern = '(?i)RevoUninstaller_Portable\.zip(?:\?|$)' },
    @{ Name = 'HDDLLF'; Page = 'https://hddguru.com/software/HDD-LLF-Low-Level-Format-Tool/'; Pattern = '(?i)HDDLowLevelFormatTool[^/?]*Portable\.exe(?:\?|$)' },
    @{ Name = 'ServiWin'; Url = 'https://www.nirsoft.net/utils/serviwin-x64.zip' }
)

foreach ($tool in $tools) {
    try {
        $url = if ($tool.Url) { $tool.Url } else { Get-LatestLink -Page $tool.Page -Pattern $tool.Pattern }
        if ($tool.Landing -and $url) {
            $fileName = [uri]::UnescapeDataString(([uri]$url).Segments[-1])
            $url = Get-LatestLink -Page $url -Pattern 'download\.cpuid\.com/.+\.zip(?:\?|$)'
            if (Save-Portable -Name $tool.Name -Url $url -FileName $fileName) { $downloaded++ }
        } elseif (Save-Portable -Name $tool.Name -Url $url) { $downloaded++ }
    } catch {}
}

# Crystal Dew World's current standard ZIP links lead through its redirect page.
foreach ($item in @(
    @{ Name = 'CrystalDiskInfo'; Product = 'CrystalDiskInfo' },
    @{ Name = 'CrystalDiskMark'; Product = 'CrystalDiskMark' }
)) {
    try {
        $landing = "https://crystalmark.info/redirect.php?product=$($item.Product)"
        $response = Invoke-WebRequest -Uri $landing -UseBasicParsing
        $redirect = $response.BaseResponse.ResponseUri.AbsoluteUri
        if ($redirect -match '[?&]url=([^&]+)') {
            $url = [uri]::UnescapeDataString($Matches[1])
            if ($url -match 'https://sourceforge\.net/projects/[^/]+/files/[^/]+/([^/]+\.zip)/download') {
                if (Save-Portable -Name $item.Name -Url $url -FileName $Matches[1]) { $downloaded++ }
            }
        }
    } catch {}
}

# GitHub release assets are versioned and published by the respective developers.
try {
    $asset = Get-GitHubAsset -Repository 'pbatard/rufus' -Pattern '^rufus-[\d.]+p\.exe$'
    if ($asset -and (Save-Portable -Name 'Rufus' -Url $asset.browser_download_url -FileName $asset.name)) { $downloaded++ }
} catch {}

# GPU-Z is distributed as a standalone executable. WinGet downloads it without running it.
try {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $gpuDirectory = Join-Path $Destination 'GPU-Z'
        $null = New-Item -ItemType Directory -Path $gpuDirectory -Force
        $before = @(Get-ChildItem -LiteralPath $gpuDirectory -File -Filter '*.exe')
        & winget download --id TechPowerUp.GPU-Z --exact --source winget --installer-type portable --download-directory $gpuDirectory --accept-source-agreements --accept-package-agreements --disable-interactivity *> $null
        if ($LASTEXITCODE -eq 0) {
            $after = @(Get-ChildItem -LiteralPath $gpuDirectory -File -Filter '*.exe')
            if ($after.Count -gt $before.Count) { $downloaded++ }
        }
    }
} catch {}

# DDU's official release is a self-extracting portable executable.
try {
    $article = Get-LabeledLink -Page 'https://www.wagnardsoft.com/software/ddu' -Label 'Download Display Driver Uninstaller'
    $url = Get-LabeledLink -Page $article -Label 'Download DDU.*Portable'
    if (Save-Portable -Name 'DDU' -Url $url -FileName 'DDU-portable.exe') { $downloaded++ }
} catch {}

Write-Host "$downloaded portable Programme in $Destination"
