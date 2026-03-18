# Vox v1 Official Bootstrap

## Run order

1. Push the base schema migration.
2. Run `docs/bootstrap.sql`.
3. Upload the curated assets with `scripts/upload-vox-v1-assets.sh`.
4. Run `docs/assets-bootstrap.sql`.
5. Run `docs/bootstrap-validate.sql`.

## What the official bootstrap guarantees

- creates or updates the `voulezvous` workspace
- creates or updates the `vox` character
- applies the official Vox v1 profile
- upserts the 10 canonical axioms
- upserts the 3 official base scenes
- upserts the autonomy, memory, and review policies
- creates or reuses the canonical approval review
- creates or updates `character_versions.version_no = 1`
- creates or updates the matching canonical commit
- links axioms to the canonical commit
- records an idempotent bootstrap audit log

## What the asset bootstrap guarantees

- upserts the curated asset batch
- associates scene-linked assets to `praia-solar`, `lounge-casa`, and `bastidor-vv`
- inserts missing tags
- preserves prior metadata while overlaying curated metadata
- records an idempotent asset bootstrap audit log

## Expected state after success

- one active character: `vox`
- current canon version: `1`
- canonical title: `Vox v1 - Primeira Instancia Canonica`
- 10 axioms
- 3 approved scenes
- 8 curated assets registered

