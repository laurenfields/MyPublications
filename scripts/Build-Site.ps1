<#
.SYNOPSIS
    Builds the self-contained publications page from the fetched data.

.DESCRIPTION
    Reads data/publications.json and data/summary.json, injects them into
    templates/page.html, and writes index.html at the project root.

    The output is a single file with no external requests - no CDN scripts, no web
    fonts, no runtime API calls. It opens from disk and deploys to any static host.

    Run Fetch-Publications.ps1 first, or use Update-All.ps1 to do both.

.PARAMETER OutputPath
    Where to write the page. Defaults to index.html at the project root.

.EXAMPLE
    .\Build-Site.ps1
    Rebuild index.html from the current data.
#>
[CmdletBinding()]
param(
    [string] $OutputPath,
    [string] $TemplatePath,
    [string] $DataDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
if (-not $TemplatePath) { $TemplatePath = Join-Path $root 'templates\page.html' }
if (-not $DataDir)      { $DataDir      = Join-Path $root 'data' }
if (-not $OutputPath)   { $OutputPath   = Join-Path $root 'index.html' }

$pubsPath = Join-Path $DataDir 'publications.json'
$sumPath  = Join-Path $DataDir 'summary.json'

foreach ($p in @($TemplatePath, $pubsPath, $sumPath)) {
    if (-not (Test-Path $p)) {
        throw "Missing $p. Run Fetch-Publications.ps1 first."
    }
}

# Read through .NET, not Get-Content: PowerShell 5.1 reads as ANSI by default, which
# mangles the non-ASCII characters in the data and template (en dashes, accented names).
$pubsJson = [System.IO.File]::ReadAllText($pubsPath).Trim()
$sumJson  = [System.IO.File]::ReadAllText($sumPath).Trim()
$summary  = $sumJson | ConvertFrom-Json

# The JSON rides inside <script type="application/json">, so the only sequence that can
# break out of the element is a literal "</script". Escaping the slash keeps the JSON
# valid while making that impossible.
function Protect-JsonForScriptTag([string] $json) {
    return $json -replace '</', '<\/'
}

$title = "$($summary.name) - Publications"
$desc  = "$($summary.total_papers) publications and $($summary.total_citations) citations by $($summary.name), $($summary.affiliation)."

$html = [System.IO.File]::ReadAllText($TemplatePath)
$html = $html.Replace('__PUBLICATIONS__', (Protect-JsonForScriptTag $pubsJson))
$html = $html.Replace('__SUMMARY__',      (Protect-JsonForScriptTag $sumJson))
$html = $html.Replace('__TITLE__',        [System.Net.WebUtility]::HtmlEncode($title))
$html = $html.Replace('__DESCRIPTION__',  [System.Net.WebUtility]::HtmlEncode($desc))

foreach ($token in @('__PUBLICATIONS__', '__SUMMARY__', '__TITLE__', '__DESCRIPTION__')) {
    if ($html.Contains($token)) { throw "Template token $token was not substituted." }
}

# UTF-8 without BOM - a BOM ahead of <!doctype> puts some browsers into quirks mode.
[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.UTF8Encoding]::new($false))

$kb = [math]::Round((Get-Item $OutputPath).Length / 1KB, 1)
Write-Host "Built $OutputPath ($kb KB, self-contained)" -ForegroundColor Green
Write-Host ("  {0} publications | {1} citations | h-index {2}" -f `
    $summary.total_papers, $summary.total_citations, $summary.h_index) -ForegroundColor Cyan
