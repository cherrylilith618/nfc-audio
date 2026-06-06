[CmdletBinding()]
param(
    [string]$Inbox = (Join-Path $PSScriptRoot '..\inbox'),
    [string]$BaseUrl = 'https://cherrylilith618.github.io/nfc-audio',
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$inboxPath = [System.IO.Path]::GetFullPath($Inbox)
$templatePath = Join-Path $repo 'templates\track.html'
$tracksPath = Join-Path $repo 'tracks'
$linksPath = Join-Path $repo 'nfc-links.txt'

foreach ($command in 'ffmpeg', 'ffprobe', 'git') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $command"
    }
}

if (-not (Test-Path -LiteralPath $inboxPath)) {
    New-Item -ItemType Directory -Path $inboxPath | Out-Null
}

$files = Get-ChildItem -LiteralPath $inboxPath -File -Filter '*.mp3' | Sort-Object Name
if (-not $files) {
    throw "No MP3 files found in inbox. Use names such as 01_title.mp3."
}

New-Item -ItemType Directory -Path $tracksPath -Force | Out-Null
$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
$links = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    if ($file.BaseName -notmatch '^(?<slug>\d{2})[_ -](?<title>.+)$') {
        throw "Invalid filename: $($file.Name). Example: 01_title.mp3"
    }

    $slug = $Matches.slug
    $title = $Matches.title.Trim()
    $trackPath = Join-Path $tracksPath $slug
    New-Item -ItemType Directory -Path $trackPath -Force | Out-Null

    $durationSeconds = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 -- $file.FullName)
    $duration = [TimeSpan]::FromSeconds([math]::Round($durationSeconds)).ToString('mm\:ss')

    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $trackPath 'audio.mp3') -Force
    & ffmpeg -hide_banner -loglevel error -y -i $file.FullName `
        -filter_complex 'aformat=channel_layouts=mono,showwavespic=s=1400x500:colors=4f46e5|06b6d4' `
        -frames:v 1 -update 1 (Join-Path $trackPath 'waveform.png')
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create waveform: $($file.Name)"
    }

    $encodedTitle = [System.Net.WebUtility]::HtmlEncode($title)
    $html = $template.Replace('{{TITLE}}', $encodedTitle).
        Replace('{{SLUG}}', $slug).
        Replace('{{DURATION}}', $duration)
    Set-Content -LiteralPath (Join-Path $trackPath 'index.html') -Value $html -Encoding UTF8

    $links.Add(('{0}  {1}/tracks/{0}/' -f $slug, $BaseUrl.TrimEnd('/')))
}

Set-Content -LiteralPath $linksPath -Value $links -Encoding UTF8
Write-Host ''
Write-Host 'Generated NFC URLs:' -ForegroundColor Green
$links | ForEach-Object { Write-Host $_ }

if ($NoPush) {
    Write-Host ''
    Write-Host 'Skipped GitHub publishing.'
    exit 0
}

Push-Location $repo
try {
    & git add -- tracks nfc-links.txt
    $changes = & git status --porcelain
    if ($changes) {
        & git commit -m "Publish NFC audio tracks"
        if ($LASTEXITCODE -ne 0) {
            throw 'Git commit failed.'
        }
    }

    & git push origin main
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub push failed. Check the network or publisher key.'
    }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Published. GitHub Pages normally updates within one minute.' -ForegroundColor Green
