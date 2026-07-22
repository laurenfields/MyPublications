<#
.SYNOPSIS
    Fetches publications and per-year citation counts from OpenAlex, keyed by ORCID.

.DESCRIPTION
    Pulls every work OpenAlex attributes to the ORCID in config/profile.json, drops the
    works listed in that file's `excluded_works` (misattributions and duplicate deposits),
    and writes a cleaned dataset to data/publications.json plus rolled-up totals to
    data/summary.json.

    OpenAlex is used rather than ORCID's own API because ORCID carries no citation data.
    Both are keyed on the same ORCID, so the join is exact.

    No API key required. OpenAlex asks for an email in the User-Agent to get you into
    their faster "polite pool" - set -Email or the OPENALEX_EMAIL environment variable.

.PARAMETER Email
    Contact email sent to OpenAlex for polite-pool access. Defaults to $env:OPENALEX_EMAIL.

.PARAMETER ConfigPath
    Path to profile.json. Defaults to config/profile.json next to this script.

.PARAMETER OutputDir
    Where to write publications.json and summary.json. Defaults to data/.

.EXAMPLE
    .\Fetch-Publications.ps1
    Refresh the dataset using the configured ORCID.

.EXAMPLE
    .\Fetch-Publications.ps1 -Email you@university.edu
    Refresh via the OpenAlex polite pool.
#>
[CmdletBinding()]
param(
    [string] $Email      = $env:OPENALEX_EMAIL,
    [string] $ConfigPath,
    [string] $OutputDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config\profile.json' }
if (-not $OutputDir)  { $OutputDir  = Join-Path $root 'data' }

if (-not (Test-Path $ConfigPath)) { throw "Config not found: $ConfigPath" }

# Read and write through .NET rather than Get-Content/Out-File: Windows PowerShell 5.1
# reads as ANSI by default and writes UTF-8 with a BOM, either of which corrupts the
# non-ASCII characters in this data (en dashes in affiliations, accented author names).
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cfg = [System.IO.File]::ReadAllText($ConfigPath) | ConvertFrom-Json

if (-not $cfg.orcid) { throw "profile.json is missing an 'orcid' field." }
Write-Host "Fetching works for ORCID $($cfg.orcid) ..." -ForegroundColor Cyan

# --- Build the request -------------------------------------------------------
$ua = if ($Email) { "MyPublications/1.0 (mailto:$Email)" } else { 'MyPublications/1.0' }
if (-not $Email) {
    Write-Warning "No email set - using the OpenAlex common pool (slower). Pass -Email or set OPENALEX_EMAIL."
}

$fields = @(
    'id','doi','title','publication_year','publication_date','cited_by_count',
    'counts_by_year','authorships','primary_location','open_access','type'
) -join ','

# OpenAlex caps per-page at 200; page through in case the list outgrows one page.
$works  = [System.Collections.Generic.List[object]]::new()
$page   = 1
do {
    $uri = "https://api.openalex.org/works" +
           "?filter=author.orcid:$($cfg.orcid)" +
           "&per-page=200&page=$page&select=$fields"
    $resp = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = $ua }
    foreach ($w in $resp.results) { $works.Add($w) | Out-Null }
    $page++
} while ($resp.results.Count -eq 200)

Write-Host "  OpenAlex returned $($works.Count) works." -ForegroundColor DarkGray

# --- Apply the exclusion list ------------------------------------------------
$excluded = @{}
foreach ($e in $cfg.excluded_works) { $excluded[$e.id] = $e }

$kept    = [System.Collections.Generic.List[object]]::new()
$dropped = [System.Collections.Generic.List[object]]::new()
foreach ($w in $works) {
    $shortId = $w.id -replace 'https://openalex\.org/', ''
    if ($excluded.ContainsKey($shortId)) { $dropped.Add($excluded[$shortId]) | Out-Null }
    else                                 { $kept.Add($w) | Out-Null }
}

foreach ($d in $dropped) {
    Write-Host "  excluded $($d.id) ($($d.year), $($d.reason))" -ForegroundColor DarkYellow
}

# Warn if the config lists an exclusion OpenAlex no longer returns - it may have been
# fixed upstream, in which case the entry can be retired from profile.json.
foreach ($id in $excluded.Keys) {
    if ($works.id -notcontains "https://openalex.org/$id") {
        Write-Warning "Exclusion $id no longer appears in OpenAlex results - it may be safe to remove from profile.json."
    }
}

# --- Normalise ---------------------------------------------------------------
$orcidUrl  = "https://orcid.org/$($cfg.orcid)"
$preprints = @($cfg.preprint_venues)

$pubs = foreach ($w in $kept) {
    $authors = @($w.authorships.author.display_name)

    # Locate the profile author to record first/middle/last authorship.
    $me = $w.authorships | Where-Object { $_.author.orcid -eq $orcidUrl } | Select-Object -First 1
    if (-not $me) {
        # Fall back to a name match when OpenAlex has not stamped the ORCID on this record.
        $me = $w.authorships |
              Where-Object { $_.author.display_name -like "*$($cfg.name.Split(' ')[-1])*" } |
              Select-Object -First 1
    }

    $venue = $w.primary_location.source.display_name
    if (-not $venue) { $venue = 'Unpublished / no venue listed' }

    # Titles arrive with HTML entities and stray inline markup from publisher feeds.
    $title = [System.Net.WebUtility]::HtmlDecode(($w.title -replace '<[^>]+>', '')).Trim()

    [pscustomobject]@{
        title       = $title
        year        = $w.publication_year
        date        = $w.publication_date
        venue       = $venue
        doi         = $w.doi
        url         = if ($w.doi) { $w.doi } else { $w.id }
        authors     = $authors
        author_count= $authors.Count
        position    = if ($me) { $me.author_position } else { $null }
        citations   = $w.cited_by_count
        by_year     = @($w.counts_by_year | Sort-Object year |
                        ForEach-Object { [pscustomobject]@{ year = $_.year; count = $_.cited_by_count } })
        is_preprint = [bool]($preprints -contains $venue)
        open_access = [bool]$w.open_access.is_oa
        type        = $w.type
        openalex_id = $w.id
    }
}

$pubs = @($pubs | Sort-Object @{Expression='year';Descending=$true}, @{Expression='citations';Descending=$true})

# --- Roll-up stats -----------------------------------------------------------
# Citations received per calendar year, summed across every paper.
$perYear = @{}
foreach ($p in $pubs) {
    foreach ($c in $p.by_year) { $perYear[$c.year] = ([int]$perYear[$c.year]) + $c.count }
}

$cumulative = 0
$growth = foreach ($y in ($perYear.Keys | Sort-Object)) {
    $cumulative += $perYear[$y]
    [pscustomobject]@{ year = $y; received = $perYear[$y]; cumulative = $cumulative }
}

# h-index: the largest h where h papers each have >= h citations.
$desc = @($pubs.citations | Sort-Object -Descending)
$h = 0
for ($i = 0; $i -lt $desc.Count; $i++) { if ($desc[$i] -ge ($i + 1)) { $h = $i + 1 } }

$byYear = foreach ($g in ($pubs | Group-Object year | Sort-Object Name)) {
    [pscustomobject]@{
        year       = [int]$g.Name
        papers     = $g.Count
        citations  = ($g.Group | Measure-Object citations -Sum).Sum
    }
}

$summary = [pscustomobject]@{
    name             = $cfg.name
    orcid            = $cfg.orcid
    affiliation      = $cfg.affiliation
    tagline          = $cfg.tagline
    generated_utc    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    current_year     = (Get-Date).Year
    total_papers     = $pubs.Count
    total_citations  = ($pubs | Measure-Object citations -Sum).Sum
    h_index          = $h
    i10_index        = @($pubs | Where-Object { $_.citations -ge 10 }).Count
    first_author     = @($pubs | Where-Object { $_.position -eq 'first' }).Count
    preprints        = @($pubs | Where-Object { $_.is_preprint }).Count
    open_access      = @($pubs | Where-Object { $_.open_access }).Count
    excluded_count   = $dropped.Count
    citation_growth  = @($growth)
    papers_by_year   = @($byYear)
}

# --- Write -------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$pubsPath = Join-Path $OutputDir 'publications.json'
$sumPath  = Join-Path $OutputDir 'summary.json'

[System.IO.File]::WriteAllText($pubsPath, ($pubs    | ConvertTo-Json -Depth 8), $Utf8NoBom)
[System.IO.File]::WriteAllText($sumPath,  ($summary | ConvertTo-Json -Depth 8), $Utf8NoBom)

Write-Host ""
Write-Host "Wrote $($pubs.Count) publications -> $pubsPath" -ForegroundColor Green
Write-Host "Wrote summary               -> $sumPath"  -ForegroundColor Green
Write-Host ""
Write-Host ("  {0} citations | h-index {1} | i10 {2} | {3} first-author | {4} preprints" -f `
    $summary.total_citations, $summary.h_index, $summary.i10_index,
    $summary.first_author, $summary.preprints) -ForegroundColor Cyan
