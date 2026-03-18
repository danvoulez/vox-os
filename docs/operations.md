# Operations

## Edge Function contracts

### `memory-ingest`

```json
{
  "character_id": "uuid",
  "event_type": "interaction",
  "source_type": "manual",
  "scene_id": "uuid",
  "payload": {
    "text": "Vox apareceu na praia com boné rosa"
  },
  "event_at": "2026-03-18T12:00:00Z"
}
```

### `fact-consolidate`

```json
{
  "character_id": "uuid",
  "event_ids": ["uuid1", "uuid2"]
}
```

### `draft-generate`

```json
{
  "character_id": "uuid",
  "scene_id": "uuid",
  "draft_type": "caption",
  "input": {
    "goal": "post instagram",
    "constraints": ["tom flirt leve", "sem quebrar canon"]
  }
}
```

### `canon-validate`

```json
{
  "character_id": "uuid",
  "candidate_payload": {
    "identity": {
      "display_name": "Vox"
    },
    "appearance": {}
  }
}
```

### `scene-validate`

```json
{
  "character_id": "uuid",
  "scene_id": "uuid",
  "draft_id": "uuid"
}
```

### `review-decide`

```json
{
  "target_type": "fact",
  "target_id": "uuid",
  "decision": "approve",
  "notes": "coerente com o personagem"
}
```

### `commit-canon`

```json
{
  "character_id": "uuid",
  "title": "Ajuste visual praia",
  "summary": "Boné rosa entra como item recorrente",
  "source_review_id": "uuid",
  "diff": {
    "appearance.recurring_items": {
      "add": ["boné rosa"]
    }
  }
}
```

### `github-commit-export`

```json
{
  "character_id": "uuid",
  "commit_id": "uuid"
}
```

## Suggested secret set

```bash
supabase secrets set \
  OPENAI_API_KEY=... \
  OPENAI_MODEL=gpt-5-mini \
  GITHUB_TOKEN=... \
  GITHUB_OWNER=danvoulez \
  GITHUB_REPO=vox-os
```

## Suggested cron templates

Replace the project URL and service-role key with your real values:

```sql
select cron.schedule(
  'vox-hourly-memory-review',
  '0 * * * *',
  $$
    select net.http_post(
      url := 'https://mbfyewvolvqyarrafugu.supabase.co/functions/v1/fact-consolidate',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'character_id', 'YOUR_CHARACTER_ID',
        'event_ids', jsonb_build_array('UUID-1', 'UUID-2')
      )
    );
  $$
);
```

```sql
select cron.schedule(
  'vox-hourly-github-export',
  '15 * * * *',
  $$
    select net.http_post(
      url := 'https://mbfyewvolvqyarrafugu.supabase.co/functions/v1/github-commit-export',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'character_id', 'YOUR_CHARACTER_ID',
        'commit_id', 'YOUR_PENDING_COMMIT_ID'
      )
    );
  $$
);
```
