# TODO — Publications page with citation charts, published live

**Started:** 2026-07-21 · **Status:** in progress

## Goal

An interactive HTML page of published papers, with charts of how citations have
grown over time, published live on GitHub Pages at a shareable address.

This run follows the workshop's follow-along path: **Brendan MacLean, University
of Washington, ORCID `0000-0002-9575-0255`** (per Lesson 2's suggestion for a
publication list that fits the hour).

## Plan

- [x] Create `MyPublications` repo in `ws`, push to GitHub as public
- [ ] Fetch all works from OpenAlex by ORCID (venue, year, type, link, citations
      by year), with polite retry on rate limiting; save `papers.json` + a CSV to
      skim
- [ ] Review the list: summary by type, decide which types to keep, flag and drop
      anything not the author's
- [ ] Design the page (layout, accent color, featured numbers, charts) and record
      decisions here
- [ ] Build `index.html`, review in browser, refine
- [ ] Push, turn on GitHub Pages, confirm the live URL
- [ ] Mark this spec done and commit

## Notes and decisions

- Python must run with `-X utf8` (Windows default encoding chokes on Greek
  letters in titles).
