# Asset Intake

## Overview

- Local folder scanned: `assets/`
- Total files found: `30` JPEG images
- Current state: local reference set only
- Recommended ingest mode: curate first, upload to Supabase Storage second

This batch mixes at least two distinct asset families:

- Vox character imagery
- VoulezVous brand imagery

That is useful, because Vox canon needs both:

- character references for visual consistency
- brand references for identity/context alignment

## Reviewed references

These files were visually reviewed and are strong candidates for the first curated intake set.

### Vox character references

`assets/6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg`

- Type: `image`
- Suggested status: `approved`
- Suggested tags: `vox`, `portrait`, `urban`, `lisbon`, `pink-cap`, `voulezvous-shirt`
- Notes: strong brand-linked portrait; useful for face, smile, cap, and public-presence canon

`assets/CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg`

- Type: `image`
- Suggested status: `approved`
- Suggested tags: `vox`, `lounge-casa`, `interior`, `sofa`, `voulezvous-shirt`
- Notes: good reference for the `Lounge Casa` scene

`assets/D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg`

- Type: `image`
- Suggested status: `approved`
- Suggested tags: `vox`, `lounge-casa`, `frontal`, `interior`, `sofa`
- Notes: cleaner frontal composition for the same scene family

`assets/E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg`

- Type: `image`
- Suggested status: `approved`
- Suggested tags: `vox`, `praia-solar`, `beach`, `running`, `pink-cap`, `athletic`
- Notes: strong movement/athletic reference for the beach canon

`assets/6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg`

- Type: `image`
- Suggested status: `approved`
- Suggested tags: `vox`, `turnaround`, `pink-cap`, `portrait-sheet`, `reference`
- Notes: useful as a model/reference sheet for face shape, cap, and expression range

### VoulezVous brand references

`assets/02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg`

- Type: `reference`
- Suggested status: `approved`
- Suggested tags: `voulezvous`, `logo`, `brand`, `black-background`, `pink`
- Notes: clean brand mark variant on dark background

`assets/23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg`

- Type: `reference`
- Suggested status: `approved`
- Suggested tags: `voulezvous`, `logo`, `brand`, `neon`, `pink`
- Notes: glow/neon version; useful for moodboards and branded environments

`assets/3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg`

- Type: `reference`
- Suggested status: `approved`
- Suggested tags: `voulezvous`, `logo`, `brand`, `white-background`, `pink`
- Notes: clean logo version on light background

## Duplicate note

At least one exact duplicate cluster exists by SHA-256:

- `assets/298A5895-6D71-460E-A3D0-F75C4863C67F_4_5005_c.jpeg`
- `assets/84BBE5D0-357B-427C-8946-9513FAAAD496_4_5005_c.jpeg`
- `assets/A9515588-7507-41ED-9E7A-DD6117A02FE5_4_5005_c.jpeg`

All three share the checksum:

`5c6121ed54d7e35b757b65ba039ee4cffaea2bdaceb508d166bfab28517b29b8`

Recommendation: ingest only one of them unless there is provenance value in keeping all three.

## Canon impact

This intake reinforces the current Vox v1 direction instead of contradicting it:

- recurring pink cap is strongly supported
- VoulezVous-branded clothing is now visually supported
- `Praia Solar` and `Lounge Casa` both have concrete image references
- brand-linked public presence is visually supported

One adjustment I would now consider valid:

- `Bastidor VV` does not need to be only backstage/ops; it can also include branded urban-presence imagery where Vox appears as the public face of VoulezVous

## Suggested ingestion model

For the first real asset ingest, I would separate them into:

### Canon-supporting Vox assets

- `6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg`
- `CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg`
- `D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg`
- `E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg`
- `6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg`

### Brand references

- `02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg`
- `23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg`
- `3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg`

### Remaining local candidates

The remaining files should stay as `draft` or `reference` until reviewed one by one.

## Recommended next step

After this intake, the clean operational next move is:

1. Upload the curated subset with [upload-vox-v1-assets.sh](/Users/ubl-ops/Vox-OS/scripts/upload-vox-v1-assets.sh).
2. Register them in Postgres with [assets-bootstrap.sql](/Users/ubl-ops/Vox-OS/docs/assets-bootstrap.sql).
3. Use [vox-v1.assets.json](/Users/ubl-ops/Vox-OS/docs/canon/vox-v1.assets.json) as the manifest of truth for this first batch.
4. Keep the three VoulezVous logo files as `reference` or `approved`, but not `canonical` character assets.
