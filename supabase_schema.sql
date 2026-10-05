-- MFUKO WA MAPATO YA KANISA — STEP 9 production cloud foundation
-- Run this in the Supabase SQL editor for a NEW project.
-- Never ship a service_role/secret key in Flutter.

create extension if not exists pgcrypto;

create table if not exists public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.church_members (
  church_id uuid not null references public.churches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','treasurer','editor','viewer')),
  status text not null default 'active' check (status in ('active','disabled')),
  created_at timestamptz not null default now(),
  primary key (church_id, user_id)
);

create table if not exists public.sync_records (
  church_id uuid not null references public.churches(id) on delete cascade,
  entity_type text not null,
  sync_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  device_id text,
  updated_by uuid references auth.users(id),
  primary key (church_id, entity_type, sync_id)
);

create index if not exists idx_sync_records_church_updated
  on public.sync_records(church_id, updated_at);

create table if not exists public.device_registry (
  church_id uuid not null references public.churches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (church_id, device_id)
);

create or replace function public.is_church_member(p_church uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.church_members m
    where m.church_id = p_church
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.church_role(p_church uuid)
returns text
language sql stable security definer set search_path = public
as $$
  select m.role from public.church_members m
  where m.church_id = p_church
    and m.user_id = auth.uid()
    and m.status = 'active'
  limit 1;
$$;

alter table public.churches enable row level security;
alter table public.church_members enable row level security;
alter table public.sync_records enable row level security;
alter table public.device_registry enable row level security;

drop policy if exists church_select_member on public.churches;
create policy church_select_member on public.churches for select to authenticated
using (public.is_church_member(id));

drop policy if exists member_select_self_or_admin on public.church_members;
create policy member_select_self_or_admin on public.church_members for select to authenticated
using (user_id = auth.uid() or public.church_role(church_id) = 'admin');

drop policy if exists sync_select_member on public.sync_records;
create policy sync_select_member on public.sync_records for select to authenticated
using (public.is_church_member(church_id));

drop policy if exists sync_insert_editor on public.sync_records;
create policy sync_insert_editor on public.sync_records for insert to authenticated
with check (public.is_church_member(church_id)
  and public.church_role(church_id) in ('admin','treasurer','editor')
  and updated_by = auth.uid());

drop policy if exists sync_update_editor on public.sync_records;
create policy sync_update_editor on public.sync_records for update to authenticated
using (public.is_church_member(church_id)
  and public.church_role(church_id) in ('admin','treasurer','editor'))
with check (public.is_church_member(church_id)
  and public.church_role(church_id) in ('admin','treasurer','editor')
  and updated_by = auth.uid());

drop policy if exists device_select_self on public.device_registry;
create policy device_select_self on public.device_registry for select to authenticated
using (user_id = auth.uid() or public.church_role(church_id) = 'admin');

drop policy if exists device_insert_self on public.device_registry;
create policy device_insert_self on public.device_registry for insert to authenticated
with check (user_id = auth.uid() and public.is_church_member(church_id));

drop policy if exists device_update_self on public.device_registry;
create policy device_update_self on public.device_registry for update to authenticated
using (user_id = auth.uid() or public.church_role(church_id) = 'admin')
with check (user_id = auth.uid() or public.church_role(church_id) = 'admin');

-- Realtime is optional; the app remains correct without it because sync is durable.
alter publication supabase_realtime add table public.sync_records;

-- Server-side compare-and-set: a stale device can never overwrite a newer cloud row.
create or replace function public.upsert_sync_record(
  p_church_id uuid,
  p_entity_type text,
  p_sync_id uuid,
  p_payload jsonb,
  p_updated_at timestamptz,
  p_deleted boolean,
  p_device_id text
) returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  old_updated timestamptz;
  r text;
begin
  if not public.is_church_member(p_church_id) then raise exception 'NO_ACCESS'; end if;
  r := public.church_role(p_church_id);
  if r not in ('admin','treasurer','editor') then raise exception 'READ_ONLY'; end if;

  select updated_at into old_updated from public.sync_records
    where church_id=p_church_id and entity_type=p_entity_type and sync_id=p_sync_id;

  if old_updated is not null and old_updated >= p_updated_at then
    return false;
  end if;

  insert into public.sync_records(church_id,entity_type,sync_id,payload,updated_at,deleted,device_id,updated_by)
  values(p_church_id,p_entity_type,p_sync_id,p_payload,p_updated_at,p_deleted,p_device_id,auth.uid())
  on conflict (church_id,entity_type,sync_id) do update set
    payload=excluded.payload,
    updated_at=excluded.updated_at,
    deleted=excluded.deleted,
    device_id=excluded.device_id,
    updated_by=excluded.updated_by;
  return true;
end;
$$;

grant execute on function public.upsert_sync_record(uuid,text,uuid,jsonb,timestamptz,boolean,text) to authenticated;

-- Data API privileges (RLS still decides which rows are allowed).
grant select on public.churches to authenticated;
grant select on public.church_members to authenticated;
grant select, insert, update on public.sync_records to authenticated;
grant select, insert, update on public.device_registry to authenticated;
