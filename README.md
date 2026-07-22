# MyPublications

A self-contained web page of Lauren Fields' publications, with charts showing how
citations have grown over time. Data comes from [OpenAlex](https://openalex.org),
keyed to [ORCID 0000-0001-8155-642X](https://orcid.org/0000-0001-8155-642X).

## Quick start

```powershell
# Refresh citation data and rebuild the page
.\scripts\Update-All.ps1

# Refresh, rebuild, and push the live site
.\scripts\Update-All.ps1 -Publish
```

Then open `index.html`.

Run this every month or two. OpenAlex reindexes on its own schedule, so daily runs
won't show anything new.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The built page. Self-contained — no CDN, no fonts, no API calls at view time. Deploys anywhere static. |
| `config/profile.json` | Your ORCID, display details, and the exclusion list. **Edit this**, not the scripts. |
| `data/publications.json` | The 23 publications with per-year citation counts. Generated. |
| `data/summary.json` | Totals, h-index, and the chart series. Generated. |
| `templates/page.html` | The page template. Edit for design changes, then rebuild. |
| `scripts/Fetch-Publications.ps1` | Pulls from OpenAlex, applies exclusions, writes the data files. |
| `scripts/Build-Site.ps1` | Injects the data into the template, writes `index.html`. |
| `scripts/Update-All.ps1` | Both of the above, plus optional publish. |

Everything under `data/` and `index.html` is generated — they're committed so the
live site works without a build step, but never edit them by hand. Your edits go in
`config/profile.json` or `templates/page.html`.

## The exclusion list

OpenAlex merges researchers who share a name into a single author profile. Six works
returned under this ORCID belong to a **different Lauren Fields** (and to several other
people entirely), including a 170-citation JACS paper. Left in, they would have
inflated the citation total from 259 to 515 and the h-index from 10 to 12.

Each exclusion is recorded in `config/profile.json` with the reason and enough detail
to re-check it later. If OpenAlex ever fixes an attribution upstream, the fetch script
warns that the entry can be retired.

**When you publish something new**, it appears automatically — no config change needed.
Only add to `excluded_works` if a paper that isn't yours shows up.

## Co-first authorship

Shared first authorship is declared in the paper itself ("these authors contributed
equally") and appears in **no** bibliographic database — not OpenAlex, not ORCID, not
Crossref. Author order alone can't tell a co-first author apart from a second author,
so these are listed by hand in `config/profile.json`:

```json
"co_first_author_works": [
  { "id": "W4401026903", "note": "MotifQuest (JASMS 2024) - co-first with Tina C. Dang" }
]
```

Get the ID from the paper's `openalex_id` in `data/publications.json`, minus the URL
prefix. The page then shows a "Co-first author" badge and counts it toward the
first-author total. A typo'd ID is warned about on the next fetch rather than silently
ignored.

Currently 14 first-author papers: 11 sole-first and 3 shared.

## Notes on the numbers

- **Citation counts are OpenAlex's**, and will read lower than Google Scholar, which
  indexes preprints, theses, and books that OpenAlex doesn't. Neither is wrong; they
  count different things. The page says so in the footer.
- **The current year is partial.** The growth chart marks it with a dashed segment, a
  hollow endpoint, and an asterisk, so a half-finished year doesn't look like a decline.
- **bioRxiv entries are kept as distinct works.** They aren't preprints of the journal
  papers listed beside them — in particular *EndoGenius: Enabling comprehensive
  identification and quantitation* (bioRxiv 2025) is a sequel to *EndoGenius: Optimized
  Neuropeptide Identification* (J. Proteome Res. 2024), not an earlier draft of it.
  They carry a "Preprint" badge on the page.

## Requirements

Windows PowerShell 5.1 (built into Windows) and git. No Node, no Python, no package
install. The scripts use `Invoke-RestMethod` and .NET file APIs only.

OpenAlex needs no API key. Setting a contact email gets you into their faster "polite
pool":

```powershell
$env:OPENALEX_EMAIL = "lfields2@uw.edu"
```

## A note on the repo layout

This is a git repository nested inside the `ClaudeLab` repository. Git treats it as an
independent repo and won't track its contents from the parent — that's intended, so this
project can be public while `ClaudeLab` stays as it is.
