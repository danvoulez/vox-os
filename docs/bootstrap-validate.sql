-- Vox v1 official bootstrap validation

select
  w.slug as workspace_slug,
  c.slug as character_slug,
  c.display_name,
  c.status,
  cv.version_no,
  cv.title as canon_title
from public.characters c
join public.workspaces w on w.id = c.workspace_id
left join public.character_versions cv on cv.id = c.current_canon_version_id
where w.slug = 'voulezvous'
  and c.slug = 'vox';

select
  count(*) as axioms_count
from public.character_axioms
where character_id = (
  select id
  from public.characters
  where slug = 'vox'
);

select
  slug,
  name,
  status
from public.scenes
where character_id = (
  select id
  from public.characters
  where slug = 'vox'
)
order by slug;

select
  policy_type,
  autonomy_level
from public.policies
where character_id = (
  select id
  from public.characters
  where slug = 'vox'
)
order by policy_type;

select
  asset_type,
  status,
  count(*) as assets
from public.assets
where character_id = (
  select id
  from public.characters
  where slug = 'vox'
)
group by asset_type, status
order by asset_type, status;

select
  action,
  target_type,
  created_at
from public.audit_logs
where target_id in (
  select id from public.characters where slug = 'vox'
  union all
  select current_canon_version_id from public.characters where slug = 'vox'
)
order by created_at desc;

