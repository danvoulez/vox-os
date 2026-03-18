# Vox OS

Supabase-first foundation for Vox OS / Vox Studio.

This repository bootstraps the backend state layer described in the Vox OS PRD:

- canonical character state with versioning
- layered memory (`memory_events` -> `memory_facts` -> `character_versions`)
- scenes and multimodal assets
- drafts, reviews, commits, and audit logs
- RLS-first multi-tenant data model
- Edge Functions for ingest, review, draft generation, validation, and canon commits

## Current scope

This first implementation is intentionally backend-heavy and UI-agnostic:

- `supabase/migrations`: initial schema, helper SQL functions, RLS, and legacy compatibility views
- `supabase/functions`: core operational functions for Vox OS workflows
- `supabase/seed.sql`: optional local seed scaffold

## Remote project

- Supabase project ref: `mbfyewvolvqyarrafugu`
- Supabase URL: [https://mbfyewvolvqyarrafugu.supabase.co](https://mbfyewvolvqyarrafugu.supabase.co)

## Quick start

1. Authenticate the CLI:

```bash
supabase login
```

2. Link this repo to the remote project:

```bash
supabase link --project-ref mbfyewvolvqyarrafugu
```

3. Push the schema:

```bash
supabase db push
```

4. Set function secrets you plan to use:

```bash
supabase secrets set \
  OPENAI_API_KEY=... \
  OPENAI_MODEL=gpt-5-mini \
  GITHUB_TOKEN=... \
  GITHUB_OWNER=danvoulez \
  GITHUB_REPO=vox-os
```

5. Deploy the functions:

```bash
supabase functions deploy memory-ingest
supabase functions deploy fact-consolidate
supabase functions deploy draft-generate
supabase functions deploy canon-validate
supabase functions deploy scene-validate
supabase functions deploy review-decide
supabase functions deploy commit-canon
supabase functions deploy github-commit-export
```

## GitHub versioning

This repository is the long-term versioning trail for Vox OS.

- exported canon snapshots land under `canon/<character>/`
- exported approved commit payloads land under `commits/<character>/`
- reports can land under `reports/<character>/`

The regular validation pipeline lives in [.github/workflows/vox-versioning-validate.yml](/Users/ubl-ops/Vox-OS/.github/workflows/vox-versioning-validate.yml).

## Recommended rollout

1. Push the migration and confirm the schema in Supabase Studio.
2. Run [bootstrap.sql](docs/bootstrap.sql) to canonize Vox v1.
3. Confirm the generated snapshot against [vox-v1.snapshot.json](docs/canon/vox-v1.snapshot.json).
4. Start ingesting memory events and reviewing facts.
5. Use `commit-canon` for all canon changes after v1.

## Cron jobs

The migration does not hardcode cron jobs because hosted schedules need your live project URL and service-role key. After deploy, create schedules for:

- hourly memory review
- hourly GitHub export for pending commits
- nightly consistency scan
- weekly canon report

Those jobs can call the Edge Functions added in this repo using `pg_cron` + `pg_net`, or your external scheduler of choice.
