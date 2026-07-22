# TODO — Publications page with citation charts, published live

**Started:** 2026-07-21 · **Rebuilt:** 2026-07-22 · **Status:** in progress

## Goal

An interactive HTML page of published papers, with charts of how citations have
grown over time, published live on GitHub Pages at a shareable address.

The page is for **Lauren Fields, ORCID `0000-0001-8155-642X`**, confirmed by
Lauren directly.

## Correction — 2026-07-22

**The 2026-07-21 build fetched the wrong researcher.** The spec named Lauren's
ORCID, but `fetch_papers.py` was run against `0000-0002-9575-0255` — Brendan
MacLean of the MacCoss lab. The resulting `papers.json` / `papers.csv` describe
111 works and 21,812 citations that are not Lauren's, and the spec's own notes
recorded the mismatch without catching it ("every work lists Brendan MacLean").

Those files were never committed, so nothing wrong was ever published. They
remain uncommitted in the old working folder
(`C:\Users\field\Documents\GitHub\MyPublications`) pending deletion.

The project was rebuilt from scratch on 2026-07-22 against the correct ORCID.
The design decisions below survived the rebuild; the data and the toolchain did
not.

## Plan

- [x] Create `MyPublications` repo, push to GitHub as public
- [x] Fetch all works from OpenAlex by ORCID (venue, year, type, link, citations
      by year), save structured data
- [x] Review the list: flag and drop anything not the author's
- [x] Design the page (layout, accent color, featured numbers, charts)
- [x] Rebuild against the correct ORCID (2026-07-22)
- [x] Build `index.html`, review in browser, refine
- [ ] Push, turn on GitHub Pages, confirm the live URL
- [ ] Mark this spec done and commit

## Notes and decisions — current build (2026-07-22)

- **23 works, 259 citations, h-index 10.** Matches Lauren's ORCID record exactly.
- **Name-collision exclusions are real here.** OpenAlex returns 30 works for this
  ORCID; 6 belong to other researchers merged in by name, including a 170-citation
  JACS paper that alone would have inflated the total from 259 to 429. A 7th is a
  Figshare duplicate. All 7 are recorded in `config/profile.json` with reasons.
  Lauren confirmed the two 2015 Antarctic-fish papers are a different Lauren Fields.
- **PowerShell, not Python.** This machine has neither Python nor Node on PATH.
  The toolchain is `Invoke-RestMethod` plus .NET file APIs, which ship with Windows.
- **Read and write through .NET, not `Get-Content`/`Out-File`.** PowerShell 5.1
  reads as ANSI and writes UTF-8 with a BOM; either corrupts the en dash in
  "University of Wisconsin–Madison" and any accented author name. This bit the
  first build and is fixed in both scripts.
- **Preprints are kept, badged — not dropped.** The earlier plan dropped all
  preprints as duplicates of published versions. That is wrong for this dataset:
  Lauren confirmed the bioRxiv *EndoGenius: Enabling comprehensive identification*
  is a **sequel** to the 2024 J. Proteome Res. *EndoGenius: Optimized Neuropeptide
  Identification*, not a preprint of it. 4 preprints are included with a badge.
- **The current year is partial.** 2026 is shown with a dashed final segment, a
  hollow endpoint, and an asterisk so a half-finished year doesn't read as a decline.

## Design (interview answers, carried forward)

- **Layout:** single column — header with name/affiliation, a row of stat
  cards, two charts side by side, then the paper list grouped by year. *Kept.*
- **Featured numbers:** citations, publications, h-index, first-author count.
  *Kept; h-index computed from the data.*
- **Charts:** cumulative citations (area) and papers per year (bar). *Kept.*
- **Accent color:** changed from teal `#0f766e` to a validated blue
  (`#2a78d6` light / `#3987e5` dark). Both charts are single-series sequential,
  and the blue ships with a matching dark-mode step; the teal had no validated
  dark counterpart.
- **Chart.js from CDN:** dropped. Charts are hand-rolled inline SVG with the same
  hover tooltips, so the page has zero external requests — it works offline, from
  `file://`, and can't break when a CDN moves. This also removes the reason the
  old build needed `papers.js`: the data is embedded directly in `index.html`.
