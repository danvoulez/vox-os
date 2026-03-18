-- Vox v1 curated asset ingest
-- Run this after:
-- 1. pushing the schema
-- 2. running docs/bootstrap.sql
-- 3. uploading the files to the matching Storage paths
--
-- Optionally replace USER_ID with a UUID to override actor attribution.
-- By default, this script auto-resolves dan@danvoulez.com, falling back to dan@logline.world.

do $$
declare
  v_actor_id uuid := coalesce(
    nullif('USER_ID', 'USER_ID')::uuid,
    (select id from auth.users where email = 'dan@danvoulez.com' limit 1),
    (select id from auth.users where email = 'dan@logline.world' limit 1)
  );
  v_workspace_id uuid;
  v_character_id uuid;
begin
  select id into v_workspace_id
  from public.workspaces
  where slug = 'voulezvous';

  if v_workspace_id is null then
    raise exception 'Workspace "voulezvous" not found. Run docs/bootstrap.sql first.';
  end if;

  select id into v_character_id
  from public.characters
  where workspace_id = v_workspace_id
    and slug = 'vox';

  if v_character_id is null then
    raise exception 'Character "vox" not found. Run docs/bootstrap.sql first.';
  end if;

  create temporary table tmp_vox_assets (
    local_filename text,
    storage_path text,
    asset_type text,
    status text,
    scene_slug text,
    checksum text,
    width int,
    height int,
    metadata jsonb,
    tags text[]
  ) on commit drop;

  insert into tmp_vox_assets (
    local_filename,
    storage_path,
    asset_type,
    status,
    scene_slug,
    checksum,
    width,
    height,
    metadata,
    tags
  )
  values
    (
      '6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg',
      'workspaces/voulezvous/characters/vox/images/bastidor-vv/vox-lisbon-cafe-v1.jpeg',
      'image',
      'approved',
      'bastidor-vv',
      '097108d25bc3e8f4b50473a6475df99b7351873766333d875c77409605f85314',
      613,
      1282,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg",
        "local_source_path":"assets/6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg",
        "scene_family":"bastidor-vv",
        "notes":"Strong brand-linked portrait; useful for face, smile, cap, and public-presence canon.",
        "dimensions":{"width":613,"height":1282}
      }'::jsonb,
      array['vox', 'portrait', 'urban', 'lisbon', 'pink-cap', 'voulezvous-shirt', 'bastidor-vv']
    ),
    (
      'CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg',
      'workspaces/voulezvous/characters/vox/images/lounge-casa/vox-lounge-sofa-01.jpeg',
      'image',
      'approved',
      'lounge-casa',
      '8aa7c7f467081294df23943680035d42f72177ffc606f411baf01fa0e4dc73e9',
      400,
      360,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg",
        "local_source_path":"assets/CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg",
        "scene_family":"lounge-casa",
        "notes":"Strong lounge reference with relaxed posture and branded shirt.",
        "dimensions":{"width":400,"height":360}
      }'::jsonb,
      array['vox', 'lounge-casa', 'interior', 'sofa', 'voulezvous-shirt']
    ),
    (
      'D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg',
      'workspaces/voulezvous/characters/vox/images/lounge-casa/vox-lounge-sofa-frontal-01.jpeg',
      'image',
      'approved',
      'lounge-casa',
      'be5cdd76ea9b996c31830c83c0249260a1488595f018ad6489c1e6942c36e329',
      400,
      360,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg",
        "local_source_path":"assets/D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg",
        "scene_family":"lounge-casa",
        "notes":"Frontal lounge reference with clear face and mood.",
        "dimensions":{"width":400,"height":360}
      }'::jsonb,
      array['vox', 'lounge-casa', 'frontal', 'interior', 'sofa']
    ),
    (
      'E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg',
      'workspaces/voulezvous/characters/vox/images/praia-solar/vox-beach-run-01.jpeg',
      'image',
      'approved',
      'praia-solar',
      'a4827b0274c24003d27e13b003a9387f73e0b612917042983b1313dd5fa771a0',
      400,
      360,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg",
        "local_source_path":"assets/E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg",
        "scene_family":"praia-solar",
        "notes":"Athletic beach-motion reference reinforcing Praia Solar.",
        "dimensions":{"width":400,"height":360}
      }'::jsonb,
      array['vox', 'praia-solar', 'beach', 'running', 'pink-cap', 'athletic']
    ),
    (
      '6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg',
      'workspaces/voulezvous/characters/vox/references/vox-turnaround-cap-01.jpeg',
      'reference',
      'approved',
      null,
      '990a2ab7af0a5575c13a4551ed282c4a8b3919391d3860b036624dab546278ee',
      400,
      360,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg",
        "local_source_path":"assets/6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg",
        "reference_type":"turnaround",
        "notes":"Useful as a turnaround/reference sheet for face shape, cap, and expressions.",
        "dimensions":{"width":400,"height":360}
      }'::jsonb,
      array['vox', 'turnaround', 'pink-cap', 'portrait-sheet', 'reference']
    ),
    (
      '02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg',
      'workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-black-pink-01.jpeg',
      'reference',
      'approved',
      null,
      '59606ff9e71600496a6151a28e44f4757a0285ac2ba5988683613e968b943d59',
      936,
      840,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg",
        "local_source_path":"assets/02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg",
        "reference_type":"brand",
        "notes":"Clean brand mark variant on dark background.",
        "dimensions":{"width":936,"height":840}
      }'::jsonb,
      array['voulezvous', 'logo', 'brand', 'black-background', 'pink']
    ),
    (
      '23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg',
      'workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-neon-pink-01.jpeg',
      'reference',
      'approved',
      null,
      '902d2f0d42d8b42198d7c7a317d5a521c1368eef33f97f77b8315a1b4d02350a',
      936,
      840,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg",
        "local_source_path":"assets/23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg",
        "reference_type":"brand",
        "notes":"Glow/neon version for moodboards and branded environments.",
        "dimensions":{"width":936,"height":840}
      }'::jsonb,
      array['voulezvous', 'logo', 'brand', 'neon', 'pink']
    ),
    (
      '3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg',
      'workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-white-pink-01.jpeg',
      'reference',
      'approved',
      null,
      '782a0ab5ea30ae81ded50943a8ec9b6c38bab350e30d6fc41fc7e9f9cd8cf61c',
      938,
      835,
      '{
        "origin":"legacy_pre_infra",
        "ingest_batch":"vox-v1-curated-2026-03-18",
        "local_filename":"3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg",
        "local_source_path":"assets/3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg",
        "reference_type":"brand",
        "notes":"Clean light-background logo reference.",
        "dimensions":{"width":938,"height":835}
      }'::jsonb,
      array['voulezvous', 'logo', 'brand', 'white-background', 'pink']
    );

  update public.assets
  set scene_id = scenes.id,
      asset_type = src.asset_type,
      storage_bucket = 'vox-assets',
      storage_path = src.storage_path,
      checksum = src.checksum,
      metadata = coalesce(public.assets.metadata, '{}'::jsonb) || src.metadata,
      status = src.status,
      created_by = coalesce(v_actor_id, public.assets.created_by),
      updated_at = now()
  from tmp_vox_assets src
  left join public.scenes scenes
    on scenes.character_id = v_character_id
   and scenes.slug = src.scene_slug
  where public.assets.character_id = v_character_id
    and (
      public.assets.checksum = src.checksum
      or public.assets.storage_path = src.storage_path
    );

  insert into public.assets (
    character_id,
    scene_id,
    asset_type,
    storage_bucket,
    storage_path,
    checksum,
    metadata,
    status,
    created_by
  )
  select
    v_character_id,
    scenes.id,
    src.asset_type,
    'vox-assets',
    src.storage_path,
    src.checksum,
    src.metadata,
    src.status,
    v_actor_id
  from tmp_vox_assets src
  left join public.scenes scenes
    on scenes.character_id = v_character_id
   and scenes.slug = src.scene_slug
  where not exists (
    select 1
    from public.assets existing
    where existing.character_id = v_character_id
      and (
        existing.checksum = src.checksum
        or existing.storage_path = src.storage_path
      )
  );

  insert into public.asset_tags (asset_id, tag)
  select distinct
    assets.id,
    tag_name
  from tmp_vox_assets src
  join public.assets assets
    on assets.character_id = v_character_id
   and assets.checksum = src.checksum
  cross join lateral unnest(src.tags) as tag_name
  where not exists (
    select 1
    from public.asset_tags existing
    where existing.asset_id = assets.id
      and existing.tag = tag_name
  );

  insert into public.audit_logs (
    workspace_id,
    actor_id,
    action,
    target_type,
    target_id,
    payload
  )
  select
    v_workspace_id,
    v_actor_id,
    'assets.bootstrap.vox_v1_curated',
    'character',
    v_character_id,
    jsonb_build_object(
      'batch', 'vox-v1-curated-2026-03-18',
      'asset_count', 8,
      'source', 'docs/assets-bootstrap.sql'
    )
  where not exists (
    select 1
    from public.audit_logs existing
    where existing.action = 'assets.bootstrap.vox_v1_curated'
      and existing.target_id = v_character_id
      and existing.payload ->> 'batch' = 'vox-v1-curated-2026-03-18'
  );
end
$$;
