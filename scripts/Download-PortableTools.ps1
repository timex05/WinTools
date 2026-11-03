# Downloads portable Windows tools and prepares Winhance in portable mode.
# Run from PowerShell: .\scripts\Download-PortableTools.ps1
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Portable-Tools'),
    [switch]$SkipWinhanceSetup
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

function Format-DownloadBytes {
    param([double]$Bytes)
    if ($Bytes -ge 1073741824) { return ('{0:N1} GiB' -f ($Bytes / 1073741824)) }
    if ($Bytes -ge 1048576) { return ('{0:N1} MiB' -f ($Bytes / 1048576)) }
    if ($Bytes -ge 1024) { return ('{0:N1} KiB' -f ($Bytes / 1024)) }
    return ('{0:N0} Bytes' -f $Bytes)
}

function Format-DownloadTime {
    param([double]$Seconds)
    $duration = [TimeSpan]::FromSeconds([Math]::Max(0, $Seconds))
    return ('{0:00}:{1:00}:{2:00}' -f [Math]::Floor($duration.TotalHours), $duration.Minutes, $duration.Seconds)
}

function Set-ToolPhase {
    param([string]$Phase)
    $ProgressPreference = 'Continue'
    $status = '{0}/{1}: {2} | Gesamtzeit {3}' -f $downloadState.Index, $downloadState.Total, $downloadState.Name, (Format-DownloadTime $downloadState.Clock.Elapsed.TotalSeconds)
    $percent = [int][Math]::Floor(100 * ($downloadState.Index - 1) / $downloadState.Total)
    Write-Progress -Id 1 -Activity 'WinTools - Programme herunterladen' -Status $status -CurrentOperation $Phase -PercentComplete $percent
}

function Start-ToolProgress {
    param([string]$Name)
    $downloadState.Index++
    $downloadState.Name = $Name
    $downloadState.Before = $downloaded
    $downloadState.Existing = $false
    Write-Host ('[{0,2}/{1}] {2}' -f $downloadState.Index, $downloadState.Total, $Name) -ForegroundColor Cyan
    Set-ToolPhase 'Suche Download ...'
}

function Complete-ToolProgress {
    $ProgressPreference = 'Continue'
    Write-Progress -Id 2 -ParentId 1 -Activity 'Dateidownload' -Completed
    if ($downloaded -gt $downloadState.Before) {
        if ($downloadState.Existing) {
            Write-Host '        Bereits vorhanden' -ForegroundColor DarkGray
        } else {
            Write-Host '        Fertig' -ForegroundColor Green
        }
    } else {
        Write-Host '        Nicht verfuegbar - uebersprungen (Details mit -Verbose)' -ForegroundColor Yellow
    }
}

function Show-TransferProgress {
    param([string]$Name, [long]$Received, [long]$Total, [double]$Seconds)
    $ProgressPreference = 'Continue'
    $rate = $Received / [Math]::Max(0.001, $Seconds)
    $percent = -1
    $remaining = -1
    $size = 'Groesse unbekannt'
    $bytes = '{0:N0} Bytes' -f $Received
    if ($Total -gt 0) {
        $percent = [int][Math]::Min(100, [Math]::Floor(100.0 * $Received / $Total))
        $size = '{0}% | {1} / {2}' -f $percent, (Format-DownloadBytes $Received), (Format-DownloadBytes $Total)
        $bytes = '{0:N0} / {1:N0} Bytes' -f $Received, $Total
        if ($rate -gt 0) {
            $remaining = [int][Math]::Min([int]::MaxValue, [Math]::Ceiling([Math]::Max(0, $Total - $Received) / $rate))
        }
    } else {
        $size = '{0} | {1}' -f (Format-DownloadBytes $Received), $size
    }
    $eta = if ($remaining -ge 0) { Format-DownloadTime $remaining } else { '--:--:--' }
    $status = '{0} | {1}/s' -f $size, (Format-DownloadBytes $rate)
    $detail = '{0} | Zeit {1} | Rest ca. {2}' -f $bytes, (Format-DownloadTime $Seconds), $eta
    Set-ToolPhase 'Download laeuft ...'
    Write-Progress -Id 2 -ParentId 1 -Activity "Download: $Name" -Status $status -CurrentOperation $detail -PercentComplete $percent -SecondsRemaining $remaining
}

function Receive-PortableFile {
    param([string]$Name, [string]$Url, [string]$OutFile, [string]$Method, [hashtable]$Body, [string]$Referer)
    # Stream the response so Windows PowerShell 5.1 can show live byte counts.
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.Method = $Method
    $request.UserAgent = 'WinTools-Portable-Downloader'
    # Some vendors reject direct file requests without their download page.
    if ($Referer) { $request.Referer = $Referer }
    $request.MaximumAutomaticRedirections = 10
    $request.Timeout = 300000
    $request.ReadWriteTimeout = 300000
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        Show-TransferProgress -Name $Name -Received 0 -Total -1 -Seconds 0
        if ($Body) {
            $pairs = foreach ($key in $Body.Keys) {
                '{0}={1}' -f [Net.WebUtility]::UrlEncode([string]$key), [Net.WebUtility]::UrlEncode([string]$Body[$key])
            }
            $payload = [Text.Encoding]::UTF8.GetBytes(($pairs -join '&'))
            $request.ContentType = 'application/x-www-form-urlencoded'
            $request.ContentLength = $payload.Length
            $bodyStream = $request.GetRequestStream()
            try { $bodyStream.Write($payload, 0, $payload.Length) }
            finally { $bodyStream.Dispose() }
        }
        $response = $request.GetResponse()
        $inputStream = $response.GetResponseStream()
        $outputStream = [IO.File]::Create($OutFile)
        $buffer = New-Object byte[] 65536
        [long]$received = 0
        $lastUpdate = -1.0
        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $outputStream.Write($buffer, 0, $read)
            $received += $read
            $downloadState.Bytes += $read
            if (($clock.Elapsed.TotalSeconds - $lastUpdate) -ge 0.2) {
                Show-TransferProgress -Name $Name -Received $received -Total $response.ContentLength -Seconds $clock.Elapsed.TotalSeconds
                $lastUpdate = $clock.Elapsed.TotalSeconds
            }
        }
        if ($response.ContentLength -ge 0 -and $received -ne $response.ContentLength) {
            throw 'The download ended before all expected bytes arrived.'
        }
        Show-TransferProgress -Name $Name -Received $received -Total $response.ContentLength -Seconds $clock.Elapsed.TotalSeconds
    } finally {
        $clock.Stop()
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        $request.Abort()
        $ProgressPreference = 'Continue'
        Write-Progress -Id 2 -ParentId 1 -Activity "Download: $Name" -Completed
    }
}

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

function Expand-PortableArchive {
    param([string]$Archive, [string]$DestinationPath)
    try {
        Expand-Archive -LiteralPath $Archive -DestinationPath $DestinationPath -Force
        return
    } catch {
        Write-Verbose ("Expand-Archive failed; trying Windows ZIP support: {0}" -f $_.Exception.Message)
    }

    # Windows PowerShell 5.1 cannot expand Deflate64 ZIPs (for example Revo).
    # Read the file list without opening compressed streams, then use Explorer.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $root = [IO.Path]::GetFullPath($DestinationPath).TrimEnd('\') + '\'
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $files = @(foreach ($entry in $zip.Entries) {
            $path = [IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
            if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'ZIP entry points outside the extraction directory.'
            }
            if ($entry.Name) { @{ Path = $path; Length = $entry.Length } }
        })
    } finally { $zip.Dispose() }
    if ($files.Count -eq 0) { throw 'ZIP contains no files.' }

    # The caller supplies a temporary directory; discard the failed extraction.
    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $DestinationPath -Force
    $shell = New-Object -ComObject Shell.Application
    try {
        $sourceFolder = $shell.NameSpace($Archive)
        $targetFolder = $shell.NameSpace($DestinationPath)
        if (-not $sourceFolder -or -not $targetFolder) { throw 'Windows could not open the ZIP or destination.' }
        # Suppress progress, overwrite confirmations, and error dialogs.
        $targetFolder.CopyHere($sourceFolder.Items(), 4 + 16 + 1024)

        # CopyHere is asynchronous. Keep the ZIP until every file is complete.
        $deadline = [DateTime]::UtcNow.AddSeconds(120)
        do {
            $complete = $true
            foreach ($file in $files) {
                try {
                    $stream = [IO.File]::Open($file.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
                    try {
                        if ($stream.Length -ne $file.Length) { $complete = $false }
                    } finally { $stream.Dispose() }
                } catch { $complete = $false }
                if (-not $complete) { break }
            }
            if ($complete) { return }
            Start-Sleep -Milliseconds 200
        } while ([DateTime]::UtcNow -lt $deadline)
        throw 'Windows ZIP extraction timed out.'
    } finally {
        if ($targetFolder) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($targetFolder) }
        if ($sourceFolder) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($sourceFolder) }
        $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

function Save-Portable {
    param([string]$Name, [string]$Url, [string]$FileName, [string]$Method = 'Get', [hashtable]$Body, [string]$Referer)
    if (-not $Url) { return $false }
    if (-not $FileName) {
        $FileName = [uri]::UnescapeDataString(([uri]$Url).Segments[-1])
    }
    if ($FileName -notmatch '\.(zip|exe)$') { return $false }
    $FileName = $FileName -replace '[\\/:*?"<>|]', '_'
    $toolDirectory = Join-Path $Destination $Name
    $path = Join-Path $toolDirectory $FileName
    if ((Test-Path $path) -or
        ((Test-Path $toolDirectory) -and @(Get-ChildItem -LiteralPath $toolDirectory -Force).Count -gt 0)) {
        $downloadState.Existing = $true
        return $true
    }
    $null = New-Item -ItemType Directory -Path $toolDirectory -Force
    $temporary = Join-Path $toolDirectory ($FileName + '.part')
    try {
        Receive-PortableFile -Name $Name -Url $Url -OutFile $temporary -Method $Method -Body $Body -Referer $Referer
        Set-ToolPhase 'Pruefe Download ...'
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
            $staging = Join-Path ([IO.Path]::GetTempPath()) ('WinTools-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $staging
                Set-ToolPhase 'Entpacke ZIP ...'
                Expand-PortableArchive -Archive $archive -DestinationPath $staging
                Get-ChildItem -LiteralPath $staging -Force | Move-Item -Destination $toolDirectory -Force
            } finally {
                Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
            }
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

function Initialize-WinhancePortable {
    param([string]$ToolDirectory)
    $executable = Join-Path $ToolDirectory 'Winhance.exe'
    $marker = Join-Path $ToolDirectory 'portable.marker'
    if ((Test-Path -LiteralPath $executable) -and (Test-Path -LiteralPath $marker)) {
        $downloadState.Existing = $true
        return
    }

    # Leave existing files alone, including incomplete or non-portable installs.
    $otherFiles = @(Get-ChildItem -LiteralPath $ToolDirectory -Force | Where-Object { $_.Name -ne 'Winhance.Installer.exe' })
    if ($otherFiles.Count -gt 0) {
        throw 'Winhance folder contains other files. Remove the incomplete folder before retrying.'
    }
    $installer = Join-Path $ToolDirectory 'Winhance.Installer.exe'
    if (-not (Test-Path -LiteralPath $installer)) { throw 'Winhance installer is missing.' }

    # The official installer cleans its output directory. Use a separate, empty
    # staging directory so it cannot delete the downloaded installer or configs.
    $workDirectory = Join-Path ([IO.Path]::GetTempPath()) ('WinTools-Winhance-' + [guid]::NewGuid().ToString('N'))
    $staging = Join-Path $workDirectory 'Winhance'
    $setupCopy = Join-Path $workDirectory 'Winhance.Installer.exe'
    try {
        $null = New-Item -ItemType Directory -Path $workDirectory
        Copy-Item -LiteralPath $installer -Destination $setupCopy
        Set-ToolPhase 'Richte Winhance Portable ein ...'
        Write-Host '        Winhance Portable wird vorbereitet ...'
        $arguments = @(
            '/CURRENTUSER', '/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
            '/TASKS="portableinstall"', ('/DIR="{0}"' -f $staging)
        )
        $process = Start-Process -FilePath $setupCopy -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw ("Winhance installer exited with code {0}." -f $process.ExitCode) }
        if (-not ((Test-Path -LiteralPath (Join-Path $staging 'Winhance.exe')) -and
                  (Test-Path -LiteralPath (Join-Path $staging 'portable.marker')))) {
            throw 'Winhance installer did not produce a portable application in the requested directory.'
        }
        Get-ChildItem -LiteralPath $staging -Force | Move-Item -Destination $ToolDirectory
        $downloadState.Existing = $false
    } finally {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$downloaded = 0

# Direct vendor links, selected from the current official download pages.
$tools = @(
    @{ Name = 'CPU-Z'; Page = 'https://www.cpuid.com/softwares/cpu-z.html'; Pattern = '/downloads/cpu-z/cpu-z_[^/?]+-en\.zip(?:\?|$)'; Landing = $true },
    @{ Name = 'HWMonitor'; Page = 'https://www.cpuid.com/softwares/hwmonitor.html'; Pattern = '/downloads/hwmonitor/hwmonitor_[^/?]+\.zip(?:\?|$)'; Landing = $true },
    @{ Name = 'HWiNFO'; Page = 'https://www.hwinfo.com/download/'; Pattern = '(?i)/hwi_\d+\.zip(?:\?|$)'; Referer = 'https://www.hwinfo.com/download/' },
    @{ Name = 'WizTree'; Page = 'https://diskanalyzer.com/download'; Pattern = '(?i)wiztree[^/?]*portable[^/?]*\.zip(?:\?|$)' },
    @{ Name = 'RevoUninstaller'; Page = 'https://www.revouninstaller.com/start-freeware-download-portable/'; Pattern = '(?i)/RevoUninstaller_Portable\.zip(?:\?|$)' },
    @{ Name = 'HDDLLF'; Page = 'https://hddguru.com/software/HDD-LLF-Low-Level-Format-Tool/'; Pattern = '(?i)HDDLowLevelFormatTool[^/?]*Portable\.exe(?:\?|$)' },
    @{ Name = 'ServiWin'; Url = 'https://www.nirsoft.net/utils/serviwin-x64.zip' },
    @{ Name = 'FurMark 2'; Page = 'https://www.geeks3d.com/furmark/downloads/'; Pattern = '(?i)FurMark_2_[^/?]*_win64\.zip(?:\?|$)' },
    @{ Name = 'Prime95'; Page = 'https://www.mersenne.org/download/'; Pattern = '(?i)p95v[\d.]+b\d+\.win64\.zip(?:\?|$)' }
)

$downloadState = @{
    Index = 0
    Total = $tools.Count + 6
    Name = ''
    Before = 0
    Existing = $false
    Bytes = [long]0
    Clock = [Diagnostics.Stopwatch]::StartNew()
}
Write-Host "`nWinTools - Portable Downloads" -ForegroundColor Cyan
Write-Host "Ziel: $Destination`n"

foreach ($tool in $tools) {
    Start-ToolProgress $tool.Name
    try {
        $urls = if ($tool.Url) { @($tool.Url) } else { @(Get-PageLinks -Page $tool.Page | Where-Object { $_ -match $tool.Pattern }) }
        foreach ($url in $urls) {
            $fileName = $null
            if ($tool.Landing) {
                $fileName = [uri]::UnescapeDataString(([uri]$url).Segments[-1])
                $url = Get-LatestLink -Page $url -Pattern 'download\.cpuid\.com/.+\.zip(?:\?|$)'
            }
            if (Save-Portable -Name $tool.Name -Url $url -FileName $fileName -Referer $tool.Referer) {
                $downloaded++
                break
            }
        }
    } catch { Write-Verbose ("{0}: {1}" -f $tool.Name, $_.Exception.Message) }
    Complete-ToolProgress
}

# Resolve the vendor's HTML redirect, then use SourceForge's binary download endpoint.
foreach ($item in @(
    @{ Name = 'CrystalDiskInfo'; Product = 'CrystalDiskInfo' },
    @{ Name = 'CrystalDiskMark'; Product = 'CrystalDiskMark' }
)) {
    Start-ToolProgress $item.Name
    try {
        $landing = "https://crystalmark.info/redirect.php?product=$($item.Product)"
        $url = Get-LatestLink -Page $landing -Pattern '^https://sourceforge\.net/projects/[^/]+/files/.+\.zip/download(?:\?|$)'
        if ($url -match '^https://sourceforge\.net/projects/([^/]+)/files/(.+\.zip)/download(?:\?|$)') {
            $directUrl = 'https://downloads.sourceforge.net/project/{0}/{1}' -f $Matches[1], $Matches[2]
            $fileName = [uri]::UnescapeDataString(([uri]$directUrl).Segments[-1])
            if (Save-Portable -Name $item.Name -Url $directUrl -FileName $fileName) { $downloaded++ }
        }
    } catch { Write-Verbose ("{0}: {1}" -f $item.Name, $_.Exception.Message) }
    Complete-ToolProgress
}

# GitHub release assets are versioned and published by the respective developers.
Start-ToolProgress 'Rufus'
try {
    $asset = Get-GitHubAsset -Repository 'pbatard/rufus' -Pattern '^rufus-[\d.]+p\.exe$'
    if ($asset -and (Save-Portable -Name 'Rufus' -Url $asset.browser_download_url -FileName $asset.name)) { $downloaded++ }
} catch {}
Complete-ToolProgress

# Only Winhance's official installer is executed, in portable mode without launch.
Start-ToolProgress 'Winhance'
try {
    if (Save-Portable -Name 'Winhance' -Url 'https://github.com/memstechtips/Winhance/releases/latest/download/Winhance.Installer.exe') {
        if (-not $SkipWinhanceSetup) {
            Initialize-WinhancePortable -ToolDirectory (Join-Path $Destination 'Winhance')
        }
        $downloaded++
    }
} catch {
    Write-Warning ("Winhance Portable konnte nicht vorbereitet werden: {0}" -f $_.Exception.Message)
}
Complete-ToolProgress

# GPU-Z's download form selects a live mirror and supplies its signed download redirect.
Start-ToolProgress 'GPU-Z'
try {
    $gpuPath = Join-Path (Join-Path $Destination 'GPU-Z') 'GPU-Z.exe'
    if (Test-Path $gpuPath) {
        $downloadState.Existing = $true
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
Complete-ToolProgress

# DDU's official release is a self-extracting portable executable.
Start-ToolProgress 'DDU'
try {
    $article = Get-LabeledLink -Page 'https://www.wagnardsoft.com/software/ddu' -Label 'Download Display Driver Uninstaller'
    $url = Get-LabeledLink -Page $article -Label 'Download DDU.*Portable'
    if (Save-Portable -Name 'DDU' -Url $url -FileName 'DDU-portable.exe') { $downloaded++ }
} catch {}
Complete-ToolProgress

$downloadState.Clock.Stop()
& {
    $ProgressPreference = 'Continue'
    Write-Progress -Id 1 -Activity 'WinTools - Programme herunterladen' -Completed
}
Write-Host ("`n{0}/{1} Programme verfuegbar | Uebertragen: {2} | Gesamtzeit: {3}" -f $downloaded, $downloadState.Total, (Format-DownloadBytes $downloadState.Bytes), (Format-DownloadTime $downloadState.Clock.Elapsed.TotalSeconds))
Write-Host "Ziel: $Destination"
