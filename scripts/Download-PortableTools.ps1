# Downloads portable Windows tools and the Winhance installer without running them.
# Run from PowerShell: .\scripts\Download-PortableTools.ps1
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
if ((Test-Path $Destination) -and
    @(Get-ChildItem -LiteralPath $Destination -Force).Count -gt 0 -and
    -not (Test-Path (Join-Path $Destination '.wintools-portable-tools'))) { return }
$null = New-Item -ItemType Directory -Path $Destination -Force
$Destination = (Resolve-Path $Destination).Path
Set-Content -LiteralPath (Join-Path $Destination '.wintools-portable-tools') -Value 'WinTools portable tools' -Encoding Ascii

function Get-ResponseUri {
    param($Response, [string]$Fallback)
    if ($Response.BaseResponse.ResponseUri) { return $Response.BaseResponse.ResponseUri.AbsoluteUri }
    if ($Response.BaseResponse.RequestMessage.RequestUri) { return $Response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri }
    return $Fallback
}

function Get-PageLinks {
    param([string]$Page)
    $response = Invoke-WebRequest -Uri $Page -UseBasicParsing -MaximumRedirection 10 -UserAgent 'WinTools-Portable-Downloader' -TimeoutSec 60
    $base = [uri](Get-ResponseUri -Response $response -Fallback $Page)
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
    $response = Invoke-WebRequest -Uri $Page -UseBasicParsing -UserAgent 'WinTools-Portable-Downloader' -TimeoutSec 60
    $base = [uri]$Page
    foreach ($match in [regex]::Matches($response.Content, '(?is)<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>(.*?)</a>')) {
        $text = [regex]::Replace($match.Groups[2].Value, '<[^>]+>', '')
        if ($text -match $Label) {
            return ([uri]::new($base, [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value))).AbsoluteUri
        }
    }
}

function Save-Portable {
    param([string]$Name, [string]$Url, [string]$FileName, [string]$Method = 'Get', [hashtable]$Body)
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
        $request = @{
            Uri = $Url
            UseBasicParsing = $true
            OutFile = $temporary
            MaximumRedirection = 10
            UserAgent = 'WinTools-Portable-Downloader'
            TimeoutSec = 300
            Method = $Method
        }
        if ($Body) { $request.Body = $Body }
        Invoke-WebRequest @request
        if ((Get-Item $temporary).Length -lt 1024) {
            Write-Verbose "$Name returned an incomplete download."
            return $false
        }
        $stream = [IO.File]::OpenRead($temporary)
        try {
            $header = New-Object byte[] 4
            $null = $stream.Read($header, 0, 4)
        } finally { $stream.Dispose() }
        $isZip = $header[0] -eq 0x50 -and $header[1] -eq 0x4b
        $isExe = $header[0] -eq 0x4d -and $header[1] -eq 0x5a
        if (($FileName -match '\.zip$' -and -not $isZip) -or
            ($FileName -match '\.exe$' -and -not $isExe)) {
            Write-Verbose "$Name returned HTML or an unexpected file format."
            return $false
        }
        if ($isZip) {
            $archive = Join-Path $toolDirectory $FileName
            Move-Item -LiteralPath $temporary -Destination $archive
            try { Expand-Archive -LiteralPath $archive -DestinationPath $toolDirectory -Force }
            finally { Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue }
        } else {
            Move-Item -LiteralPath $temporary -Destination $path
        }
        return $true
    } catch {
        Write-Verbose ("{0}: {1}" -f $Name, $_.Exception.Message)
        return $false
    }
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
    @{ Name = 'HWiNFO'; Page = 'https://www.hwinfo.com/download/'; Pattern = '(?i)/hwi_\d+\.zip(?:\?|$)' },
    @{ Name = 'WizTree'; Page = 'https://diskanalyzer.com/download'; Pattern = '(?i)wiztree[^/?]*portable[^/?]*\.zip(?:\?|$)' },
    @{ Name = 'RevoUninstaller'; Url = 'https://download.revouninstaller.com/download/RevoUninstaller_Portable.zip' },
    @{ Name = 'HDDLLF'; Page = 'https://hddguru.com/software/HDD-LLF-Low-Level-Format-Tool/'; Pattern = '(?i)HDDLowLevelFormatTool[^/?]*Portable\.exe(?:\?|$)' },
    @{ Name = 'ServiWin'; Url = 'https://www.nirsoft.net/utils/serviwin-x64.zip' }
)

foreach ($tool in $tools) {
    try {
        $urls = if ($tool.Url) { @($tool.Url) } else { @(Get-PageLinks -Page $tool.Page | Where-Object { $_ -match $tool.Pattern }) }
        foreach ($url in $urls) {
            $fileName = $null
            if ($tool.Landing) {
                $fileName = [uri]::UnescapeDataString(([uri]$url).Segments[-1])
                $url = Get-LatestLink -Page $url -Pattern 'download\.cpuid\.com/.+\.zip(?:\?|$)'
            }
            if (Save-Portable -Name $tool.Name -Url $url -FileName $fileName) {
                $downloaded++
                break
            }
        }
    } catch { Write-Verbose ("{0}: {1}" -f $tool.Name, $_.Exception.Message) }
}

# Resolve the vendor's HTML redirect, then use SourceForge's binary download endpoint.
foreach ($item in @(
    @{ Name = 'CrystalDiskInfo'; Product = 'CrystalDiskInfo' },
    @{ Name = 'CrystalDiskMark'; Product = 'CrystalDiskMark' }
)) {
    try {
        $landing = "https://crystalmark.info/redirect.php?product=$($item.Product)"
        $url = Get-LatestLink -Page $landing -Pattern '^https://sourceforge\.net/projects/[^/]+/files/.+\.zip/download(?:\?|$)'
        if ($url -match '^https://sourceforge\.net/projects/([^/]+)/files/(.+\.zip)/download(?:\?|$)') {
            $directUrl = 'https://downloads.sourceforge.net/project/{0}/{1}' -f $Matches[1], $Matches[2]
            $fileName = [uri]::UnescapeDataString(([uri]$directUrl).Segments[-1])
            if (Save-Portable -Name $item.Name -Url $directUrl -FileName $fileName) { $downloaded++ }
        }
    } catch { Write-Verbose ("{0}: {1}" -f $item.Name, $_.Exception.Message) }
}

# GitHub release assets are versioned and published by the respective developers.
try {
    $asset = Get-GitHubAsset -Repository 'pbatard/rufus' -Pattern '^rufus-[\d.]+p\.exe$'
    if ($asset -and (Save-Portable -Name 'Rufus' -Url $asset.browser_download_url -FileName $asset.name)) { $downloaded++ }
} catch {}

# Winhance provides its portable option through the official installer. Only download it.
try {
    if (Save-Portable -Name 'Winhance' -Url 'https://github.com/memstechtips/Winhance/releases/latest/download/Winhance.Installer.exe') { $downloaded++ }
} catch { Write-Verbose ("Winhance: {0}" -f $_.Exception.Message) }

# GPU-Z's download form selects a live mirror and supplies its signed download redirect.
try {
    $gpuPath = Join-Path (Join-Path $Destination 'GPU-Z') 'GPU-Z.exe'
    if (Test-Path $gpuPath) {
        $downloaded++
    } else {
        $page = 'https://www.techpowerup.com/download/techpowerup-gpu-z/'
        $response = Invoke-WebRequest -Uri $page -UseBasicParsing -UserAgent 'WinTools-Portable-Downloader' -TimeoutSec 60
        $id = [regex]::Match($response.Content, '(?is)<input\b[^>]*name=["'']id["''][^>]*value=["''](\d+)["'']').Groups[1].Value
        if ($id) {
            $mirrors = Invoke-WebRequest -Uri $page -Method Post -Body @{ id = $id } -UseBasicParsing -UserAgent 'WinTools-Portable-Downloader' -TimeoutSec 60
            foreach ($server in [regex]::Matches($mirrors.Content, '(?is)<button\b[^>]*name=["'']server_id["''][^>]*value=["''](\d+)["'']')) {
                if (Save-Portable -Name 'GPU-Z' -Url $page -FileName 'GPU-Z.exe' -Method Post -Body @{ id = $id; server_id = $server.Groups[1].Value }) {
                    $downloaded++
                    break
                }
            }
        }
    }
} catch { Write-Verbose ("GPU-Z: {0}" -f $_.Exception.Message) }

# DDU's official release is a self-extracting portable executable.
try {
    $article = Get-LabeledLink -Page 'https://www.wagnardsoft.com/software/ddu' -Label 'Download Display Driver Uninstaller'
    $url = Get-LabeledLink -Page $article -Label 'Download DDU.*Portable'
    if (Save-Portable -Name 'DDU' -Url $url -FileName 'DDU-portable.exe') { $downloaded++ }
} catch {}

Write-Host "$downloaded portable Programme in $Destination"
