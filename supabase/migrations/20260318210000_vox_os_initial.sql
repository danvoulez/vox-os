create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null,
  role text not null check (role in ('owner', 'editor', 'reviewer', 'viewer', 'system_service')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.characters (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  slug text not null,
  display_name text not null,
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  current_canon_version_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, slug)
);

create table if not exists public.character_profiles (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null unique references public.characters(id) on delete cascade,
  short_bio text,
  archetype text,
  tone_profile jsonb not null default '{}'::jsonb,
  voice_profile jsonb not null default '{}'::jsonb,
  appearance_profile jsonb not null default '{}'::jsonb,
  relationship_profile jsonb not null default '{}'::jsonb,
  public_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.character_axioms (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  category text not null check (category in ('identity', 'behavior', 'visual', 'ethics', 'brand')),
  statement text not null,
  priority int not null default 100,
  is_mutable boolean not null default false,
  source_commit_id uuid null,
  created_at timestamptz not null default now()
);

create table if not exists public.character_versions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  version_no int not null,
  title text not null,
  snapshot jsonb not null default '{}'::jsonb,
  diff_from_previous jsonb not null default '{}'::jsonb,
  created_by uuid null,
  created_at timestamptz not null default now(),
  unique (character_id, version_no)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_characters_current_canon_version'
  ) then
    alter table public.characters
      add constraint fk_characters_current_canon_version
      foreign key (current_canon_version_id)
      references public.character_versions(id)
      on delete set null;
  end if;
end;
$$;

create table if not exists public.scenes (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  name text not null,
  slug text not null,
  setting text,
  mood text,
  behavior_notes text,
  visual_notes text,
  wardrobe_rules jsonb not null default '{}'::jsonb,
  allowed_props jsonb not null default '[]'::jsonb,
  forbidden_props jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'approved', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (character_id, slug)
);

create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  scene_id uuid null references public.scenes(id) on delete set null,
  asset_type text not null check (asset_type in ('image', 'video', 'audio', 'text', 'reference')),
  storage_bucket text not null default 'vox-assets',
  storage_path text not null,
  checksum text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'approved', 'canonical', 'archived')),
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.asset_tags (
  asset_id uuid not null references public.assets(id) on delete cascade,
  tag text not null,
  primary key (asset_id, tag)
);

create table if not exists public.memory_events (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  event_type text not null,
  source_type text not null check (source_type in ('manual', 'chat', 'system', 'import', 'api')),
  source_ref text,
  scene_id uuid null references public.scenes(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  importance_score numeric(5,2) not null default 0,
  novelty_score numeric(5,2) not null default 0,
  confidence_score numeric(5,2) not null default 1,
  review_state text not null default 'new' check (review_state in ('new', 'queued', 'consolidated', 'ignored')),
  event_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.memory_facts (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  fact_type text not null check (fact_type in ('episodic', 'semantic', 'canonical_candidate')),
  statement text not null,
  supporting_event_ids uuid[] not null default '{}',
  confidence_score numeric(5,2) not null default 0.5,
  status text not null default 'candidate' check (status in ('candidate', 'approved', 'rejected', 'superseded')),
  approved_by uuid null,
  approved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.drafts (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  scene_id uuid null references public.scenes(id) on delete set null,
  based_on_version_id uuid null references public.character_versions(id) on delete set null,
  draft_type text not null check (draft_type in ('caption', 'script', 'dialogue', 'prompt', 'scene_plan', 'voice_line')),
  input_payload jsonb not null default '{}'::jsonb,
  output_payload jsonb not null default '{}'::jsonb,
  validation_payload jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'in_review', 'approved', 'rejected', 'committed')),
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('draft', 'fact', 'asset', 'scene', 'canon_change')),
  target_id uuid not null,
  decision text not null check (decision in ('approve', 'reject', 'request_changes')),
  notes text,
  reviewed_by uuid null,
  reviewed_at timestamptz not null default now()
);

create table if not exists public.commits (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  commit_type text not null check (commit_type in ('canon', 'scene', 'asset', 'memory_policy', 'system_policy')),
  title text not null,
  summary text,
  diff jsonb not null default '{}'::jsonb,
  source_review_id uuid null references public.reviews(id) on delete set null,
  authored_by uuid null,
  created_at timestamptz not null default now()
);

create table if not exists public.policies (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  policy_type text not null check (policy_type in ('autonomy', 'memory', 'publishing', 'safety', 'review')),
  rules jsonb not null default '{}'::jsonb,
  autonomy_level int not null default 0 check (autonomy_level between 0 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_id uuid null,
  action text not null,
  target_type text not null,
  target_id uuid null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_workspace_members_user_id on public.workspace_members(user_id);
create index if not exists idx_characters_workspace_id on public.characters(workspace_id);
create index if not exists idx_character_axioms_character_id on public.character_axioms(character_id);
create index if not exists idx_character_versions_character_id on public.character_versions(character_id);
create index if not exists idx_scenes_character_id on public.scenes(character_id);
create index if not exists idx_assets_character_id on public.assets(character_id);
create index if not exists idx_assets_scene_id on public.assets(scene_id);
create index if not exists idx_memory_events_character_id on public.memory_events(character_id);
create index if not exists idx_memory_events_review_state on public.memory_events(review_state);
create index if not exists idx_memory_facts_character_id on public.memory_facts(character_id);
create index if not exists idx_memory_facts_status on public.memory_facts(status);
create index if not exists idx_drafts_character_id on public.drafts(character_id);
create index if not exists idx_drafts_status on public.drafts(status);
create index if not exists idx_commits_character_id on public.commits(character_id);
create index if not exists idx_policies_character_id on public.policies(character_id);
create index if not exists idx_audit_logs_workspace_id on public.audit_logs(workspace_id);
create index if not exists idx_audit_logs_target on public.audit_logs(target_type, target_id);

drop trigger if exists trg_workspaces_updated_at on public.workspaces;
create trigger trg_workspaces_updated_at
before update on public.workspaces
for each row execute function public.set_updated_at();

drop trigger if exists trg_characters_updated_at on public.characters;
create trigger trg_characters_updated_at
before update on public.characters
for each row execute function public.set_updated_at();

drop trigger if exists trg_character_profiles_updated_at on public.character_profiles;
create trigger trg_character_profiles_updated_at
before update on public.character_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_scenes_updated_at on public.scenes;
create trigger trg_scenes_updated_at
before update on public.scenes
for each row execute function public.set_updated_at();

drop trigger if exists trg_assets_updated_at on public.assets;
create trigger trg_assets_updated_at
before update on public.assets
for each row execute function public.set_updated_at();

drop trigger if exists trg_memory_facts_updated_at on public.memory_facts;
create trigger trg_memory_facts_updated_at
before update on public.memory_facts
for each row execute function public.set_updated_at();

drop trigger if exists trg_drafts_updated_at on public.drafts;
create trigger trg_drafts_updated_at
before update on public.drafts
for each row execute function public.set_updated_at();

drop trigger if exists trg_policies_updated_at on public.policies;
create trigger trg_policies_updated_at
before update on public.policies
for each row execute function public.set_updated_at();

create or replace function public.is_workspace_member(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_members wm
    where wm.workspace_id = p_workspace_id
      and wm.user_id = auth.uid()
  );
$$;

create or replace function public.workspace_role(p_workspace_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select wm.role
  from public.workspace_members wm
  where wm.workspace_id = p_workspace_id
    and wm.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.has_workspace_role(p_workspace_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_members wm
    where wm.workspace_id = p_workspace_id
      and wm.user_id = auth.uid()
      and wm.role = any (p_roles)
  );
$$;

create or replace function public.has_character_role(p_character_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.characters c
    join public.workspace_members wm on wm.workspace_id = c.workspace_id
    where c.id = p_character_id
      and wm.user_id = auth.uid()
      and wm.role = any (p_roles)
  );
$$;

create or replace function public.asset_character_id(p_asset_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select a.character_id
  from public.assets a
  where a.id = p_asset_id;
$$;

create or replace function public.review_target_character_id(p_target_type text, p_target_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
begin
  if p_target_type = 'draft' then
    select d.character_id into v_character_id from public.drafts d where d.id = p_target_id;
  elsif p_target_type = 'fact' then
    select f.character_id into v_character_id from public.memory_facts f where f.id = p_target_id;
  elsif p_target_type = 'asset' then
    select a.character_id into v_character_id from public.assets a where a.id = p_target_id;
  elsif p_target_type = 'scene' then
    select s.character_id into v_character_id from public.scenes s where s.id = p_target_id;
  else
    v_character_id := null;
  end if;

  return v_character_id;
end;
$$;

grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.workspace_role(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, text[]) to authenticated;
grant execute on function public.has_character_role(uuid, text[]) to authenticated;
grant execute on function public.asset_character_id(uuid) to authenticated;
grant execute on function public.review_target_character_id(text, uuid) to authenticated;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.characters enable row level security;
alter table public.character_profiles enable row level security;
alter table public.character_axioms enable row level security;
alter table public.character_versions enable row level security;
alter table public.scenes enable row level security;
alter table public.assets enable row level security;
alter table public.asset_tags enable row level security;
alter table public.memory_events enable row level security;
alter table public.memory_facts enable row level security;
alter table public.drafts enable row level security;
alter table public.reviews enable row level security;
alter table public.commits enable row level security;
alter table public.policies enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "workspaces_select_member" on public.workspaces;
create policy "workspaces_select_member"
on public.workspaces
for select
to authenticated
using (public.is_workspace_member(id));

drop policy if exists "workspaces_modify_owner_plus" on public.workspaces;
create policy "workspaces_modify_owner_plus"
on public.workspaces
for all
to authenticated
using (public.has_workspace_role(id, array['owner', 'system_service']))
with check (public.has_workspace_role(id, array['owner', 'system_service']));

drop policy if exists "workspace_members_select_member" on public.workspace_members;
create policy "workspace_members_select_member"
on public.workspace_members
for select
to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists "workspace_members_modify_owner_plus" on public.workspace_members;
create policy "workspace_members_modify_owner_plus"
on public.workspace_members
for all
to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'system_service']))
with check (public.has_workspace_role(workspace_id, array['owner', 'system_service']));

drop policy if exists "characters_select_member" on public.characters;
create policy "characters_select_member"
on public.characters
for select
to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists "characters_modify_editor_plus" on public.characters;
create policy "characters_modify_editor_plus"
on public.characters
for all
to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_workspace_role(workspace_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "character_profiles_select_member" on public.character_profiles;
create policy "character_profiles_select_member"
on public.character_profiles
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "character_profiles_modify_editor_plus" on public.character_profiles;
create policy "character_profiles_modify_editor_plus"
on public.character_profiles
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "character_axioms_select_member" on public.character_axioms;
create policy "character_axioms_select_member"
on public.character_axioms
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "character_axioms_modify_editor_plus" on public.character_axioms;
create policy "character_axioms_modify_editor_plus"
on public.character_axioms
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "character_versions_select_member" on public.character_versions;
create policy "character_versions_select_member"
on public.character_versions
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "character_versions_insert_reviewer_plus" on public.character_versions;
create policy "character_versions_insert_reviewer_plus"
on public.character_versions
for insert
to authenticated
with check (public.has_character_role(character_id, array['owner', 'reviewer', 'system_service']));

drop policy if exists "character_versions_update_reviewer_plus" on public.character_versions;
create policy "character_versions_update_reviewer_plus"
on public.character_versions
for update
to authenticated
using (public.has_character_role(character_id, array['owner', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'reviewer', 'system_service']));

drop policy if exists "scenes_select_member" on public.scenes;
create policy "scenes_select_member"
on public.scenes
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "scenes_modify_editor_plus" on public.scenes;
create policy "scenes_modify_editor_plus"
on public.scenes
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "assets_select_member" on public.assets;
create policy "assets_select_member"
on public.assets
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "assets_modify_editor_plus" on public.assets;
create policy "assets_modify_editor_plus"
on public.assets
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "asset_tags_select_member" on public.asset_tags;
create policy "asset_tags_select_member"
on public.asset_tags
for select
to authenticated
using (public.has_character_role(public.asset_character_id(asset_id), array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "asset_tags_modify_editor_plus" on public.asset_tags;
create policy "asset_tags_modify_editor_plus"
on public.asset_tags
for all
to authenticated
using (public.has_character_role(public.asset_character_id(asset_id), array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(public.asset_character_id(asset_id), array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "memory_events_select_member" on public.memory_events;
create policy "memory_events_select_member"
on public.memory_events
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "memory_events_modify_editor_plus" on public.memory_events;
create policy "memory_events_modify_editor_plus"
on public.memory_events
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "memory_facts_select_member" on public.memory_facts;
create policy "memory_facts_select_member"
on public.memory_facts
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "memory_facts_modify_reviewer_plus" on public.memory_facts;
create policy "memory_facts_modify_reviewer_plus"
on public.memory_facts
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "drafts_select_member" on public.drafts;
create policy "drafts_select_member"
on public.drafts
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "drafts_modify_editor_plus" on public.drafts;
create policy "drafts_modify_editor_plus"
on public.drafts
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "reviews_select_member" on public.reviews;
create policy "reviews_select_member"
on public.reviews
for select
to authenticated
using (
  public.has_character_role(
    public.review_target_character_id(target_type, target_id),
    array['owner', 'editor', 'reviewer', 'viewer', 'system_service']
  )
);

drop policy if exists "reviews_modify_reviewer_plus" on public.reviews;
create policy "reviews_modify_reviewer_plus"
on public.reviews
for all
to authenticated
using (
  public.has_character_role(
    public.review_target_character_id(target_type, target_id),
    array['owner', 'reviewer', 'system_service']
  )
)
with check (
  public.has_character_role(
    public.review_target_character_id(target_type, target_id),
    array['owner', 'reviewer', 'system_service']
  )
);

drop policy if exists "commits_select_member" on public.commits;
create policy "commits_select_member"
on public.commits
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "commits_insert_reviewer_plus" on public.commits;
create policy "commits_insert_reviewer_plus"
on public.commits
for insert
to authenticated
with check (public.has_character_role(character_id, array['owner', 'reviewer', 'system_service']));

drop policy if exists "policies_select_member" on public.policies;
create policy "policies_select_member"
on public.policies
for select
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'viewer', 'system_service']));

drop policy if exists "policies_modify_editor_plus" on public.policies;
create policy "policies_modify_editor_plus"
on public.policies
for all
to authenticated
using (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']))
with check (public.has_character_role(character_id, array['owner', 'editor', 'reviewer', 'system_service']));

drop policy if exists "audit_logs_select_member" on public.audit_logs;
create policy "audit_logs_select_member"
on public.audit_logs
for select
to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists "audit_logs_insert_editor_plus" on public.audit_logs;
create policy "audit_logs_insert_editor_plus"
on public.audit_logs
for insert
to authenticated
with check (public.has_workspace_role(workspace_id, array['owner', 'editor', 'reviewer', 'system_service']));

create or replace view public.vox_memoria_curta as
select
  id,
  character_id as vox_id,
  event_type,
  payload,
  importance_score,
  confidence_score,
  event_at,
  created_at
from public.memory_events
where review_state in ('new', 'queued');

create or replace view public.vox_memoria_consolidada as
select
  id,
  character_id as vox_id,
  fact_type,
  statement,
  supporting_event_ids,
  confidence_score,
  status,
  created_at,
  updated_at
from public.memory_facts
where status = 'candidate';

create or replace view public.vox_memoria_importante as
select
  id,
  character_id as vox_id,
  fact_type,
  statement,
  supporting_event_ids,
  confidence_score,
  approved_at,
  created_at
from public.memory_facts
where status = 'approved';

insert into storage.buckets (id, name, public)
values ('vox-assets', 'vox-assets', false)
on conflict (id) do nothing;
