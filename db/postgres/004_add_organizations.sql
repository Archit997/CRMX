begin;

create extension if not exists pgcrypto;

create table if not exists public.organizations (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    slug text not null unique,
    join_code text not null unique,
    is_active boolean not null default true,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'organizations_name_not_blank'
          and conrelid = 'public.organizations'::regclass
    ) then
        alter table public.organizations
            add constraint organizations_name_not_blank
            check (btrim(name) <> '');
    end if;
end $$;

alter table public.users
    add column if not exists organization_id uuid
        references public.organizations(id) on delete restrict,
    add column if not exists deleted_at timestamptz,
    add column if not exists deleted_by uuid references auth.users(id)
        on delete set null;

alter table public.client_info
    add column if not exists organization_id uuid
        references public.organizations(id) on delete restrict,
    add column if not exists deleted_at timestamptz,
    add column if not exists deleted_by uuid references auth.users(id)
        on delete set null;

-- Names are display data and are not unique identifiers. Phone remains globally
-- unique because it is the Supabase authentication identifier.
drop index if exists public.idx_users_name;
drop index if exists public.idx_users_org_name_unique;
alter table public.users drop constraint if exists users_name_key;

create index if not exists idx_users_name
    on public.users (organization_id, lower(name))
    where deleted_at is null;
create index if not exists idx_users_organization
    on public.users (organization_id)
    where deleted_at is null;
create index if not exists idx_users_pending_by_organization
    on public.users (organization_id, created_at desc)
    where approval_status = 'pending' and deleted_at is null;
create index if not exists idx_clients_organization
    on public.client_info (organization_id, last_updated desc)
    where deleted_at is null;
create unique index if not exists idx_clients_org_phone_unique
    on public.client_info (organization_id, phone)
    where deleted_at is null;
create index if not exists idx_organizations_join_code
    on public.organizations (join_code);

create table if not exists public.audit_events (
    event_id bigint generated always as identity primary key,
    organization_id uuid not null references public.organizations(id)
        on delete restrict,
    actor_id uuid not null references auth.users(id) on delete restrict,
    action text not null,
    entity_type text not null,
    entity_id text not null,
    request_id text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_audit_events_org_created
    on public.audit_events (organization_id, created_at desc);
create index if not exists idx_audit_events_entity
    on public.audit_events (organization_id, entity_type, entity_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists organizations_set_updated_at
    on public.organizations;
create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

create or replace function public.prevent_audit_event_mutation()
returns trigger
language plpgsql
as $$
begin
    raise exception 'audit events are append-only';
end;
$$;

drop trigger if exists audit_events_append_only on public.audit_events;
create trigger audit_events_append_only
before update or delete on public.audit_events
for each row execute function public.prevent_audit_event_mutation();

-- Existing clients inherit their assigned employee's organization whenever one
-- is already available. Any remaining unscoped legacy rows require an explicit
-- operator-reviewed migration before production rollout.
update public.client_info ci
set organization_id = u.organization_id
from public.users u
where ci.assigned_to = u.id
  and ci.organization_id is null
  and u.organization_id is not null;

-- Flutter talks directly to Supabase only for Auth. Application tables are
-- private to the backend; no anon/authenticated PostgREST policy is created.
alter table public.organizations enable row level security;
alter table public.users enable row level security;
alter table public.client_info enable row level security;
alter table public.client_updates enable row level security;
alter table public.audit_events enable row level security;

commit;
