# Data License Review

This document is a competition-readiness review, not legal advice. The goal is to prevent Beacon from entering a public hackathon with ambiguous third-party content.

## Current Knowledge Bundle

Current development bundle:

| Metric | Value |
| --- | --- |
| Source records | 6,302 |
| Entries | 14,229 |
| Generated at | 2026-04-13T12:35:17.402Z |

Current conservative competition-safe preview:

| Metric | Value |
| --- | ---: |
| Safe source records | 96 |
| Safe entries | 1,300 |
| Removed source records | 6,206 |
| Removed entries | 12,929 |

This preview is intentionally strict. It is safe enough to expose the licensing gap, but it should be expanded with more license-cleared government and public-domain material before the final Kaggle submission.

Largest authorities in the current bundle:

| Authority | Source records | Risk |
| --- | ---: | --- |
| MSD Manual | 3,346 | High, requires permission or removal for competition build. |
| Merck Manual Professional Edition | 2,831 | High, requires permission or removal for competition build. |
| CDC | 64 | Generally suitable with attribution and no logos/third-party assets. |
| MedlinePlus | 15 | High for AI/RAG use; page terms include restrictive AI/indexing language. |
| Ready.gov | 15 | Generally suitable with attribution and no logos/third-party assets. |
| American Red Cross | 7 | Review required; use summaries/links unless permission is clear. |
| National Park Service | 4 | Generally suitable with attribution and no logos/third-party assets. |
| National Weather Service / NOAA | 4 | Generally suitable with attribution and no logos/third-party assets. |
| NHS | 3 | Review required; Crown copyright and NHS API/content terms apply. |
| WHO | 3 | Review required; WHO materials can have specific license restrictions. |

## Competition-Safe Rule

For the final Kaggle submission, use one of these two paths:

1. **Safe profile, recommended** - ship a competition knowledge profile using government/publicly reusable sources only, plus hand-authored summaries and source links.
2. **Permission profile** - keep third-party medical references only where written permission or clear reuse rights are documented.

Do not rely on "publicly visible website" as permission to bundle full text, embeddings, chunks, or retrieval indexes.

## Recommended Competition-Safe Sources

Prefer these for the Kaggle demo and public release notes:

- CDC emergency, outdoor hazard, radiation, poisoning, heat/cold materials.
- Ready.gov / FEMA disaster preparedness and shelter-in-place content.
- NPS wilderness planning and outdoor emergency guidance.
- NWS / NOAA lightning, heat, cold, flood, and severe weather safety pages.
- US Army FM 21-76 / FM 3-05.70 survival manual where distribution status is confirmed.
- NIH/NINDS/NIDDK public health pages where terms allow reuse.
- Stop the Bleed materials only if the specific poster/content reuse rights are confirmed.

## Sources That Need Action

| Source family | Current status | Required action before final submission |
| --- | --- | --- |
| MSD Manual / Merck Manual | Large share of current bundle. | Remove from competition build or obtain explicit permission. |
| MedlinePlus encyclopedia pages | Some pages include restrictive AI/indexing language in raw HTML. | Remove from competition build unless permission is confirmed. |
| Hugging Face first-aid dataset | Dataset license must be verified. | Keep only if license is clear and compatible. |
| American Red Cross pages | Publicly accessible, but content reuse terms need review. | Prefer source links and short summaries unless permission is clear. |
| NHS pages | Crown copyright/API terms need review. | Verify terms or replace with public/government alternatives. |
| WHO PDFs/pages | WHO licenses vary by publication. | Verify publication-specific license. |

## Required Repository Hygiene

Before final Kaggle submission:

- Add a source manifest with authority, URL, retrieval date, license, and competition status.
- Exclude high-risk raw HTML/PDF files from the competition release branch if permission is not clear.
- Generate a new `offline_knowledge.json` from the competition-safe manifest.
- Update README claims so they match the actual competition bundle.
- Keep source URLs visible in evidence cards and docs.

Preview the current competition-safe profile:

```bash
npm run competition:knowledge:safe
```

Write the candidate filtered bundle only when intentionally preparing a competition build:

```bash
npm run competition:knowledge:safe -- --write
```

## Suggested Safe-Build Acceptance Test

The competition-safe bundle should still answer these scenarios using cleared sources:

- Forest lost, no signal, night approaching.
- Heavy bleeding.
- Choking.
- Thunderstorm on a ridge.
- Heat illness.
- Hypothermia.
- Radiation/shelter-in-place.
- Pandemic/biological hazard.
- Cyber/AI disruption basic preparedness.

If quality drops after removing restricted sources, add more cleared government/public-domain material rather than reintroducing restricted full text.
