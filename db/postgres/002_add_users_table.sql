begin;

-- ============================================================================
-- USERS TABLE
-- ============================================================================
-- public.users is the application profile table for Supabase Auth users.
-- id MUST match auth.users.id so OTP authentication and CRMX app roles stay linked.

create table if not exists public.users (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null,
    role text not null check (role in ('sales', 'manager', 'finance', 'admin')),
    phone text not null,
    contact text,
    approval_status text not null default 'pending'
        check (approval_status in ('pending', 'approved', 'rejected')),
    is_active boolean not null default false,
    verified_by uuid references public.users(id) on delete set null,
    verified_at timestamptz,
    rejection_reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.users
    add column if not exists phone text,
    add column if not exists contact text,
    add column if not exists approval_status text not null default 'pending',
    add column if not exists is_active boolean not null default false,
    add column if not exists verified_by uuid references public.users(id) on delete set null,
    add column if not exists verified_at timestamptz,
    add column if not exists rejection_reason text,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'users_role_check'
          and conrelid = 'public.users'::regclass
    ) then
        alter table public.users
            add constraint users_role_check
            check (role in ('sales', 'manager', 'finance', 'admin'));
    end if;

    if not exists (
        select 1
        from pg_constraint
        where conname = 'users_approval_status_check'
          and conrelid = 'public.users'::regclass
    ) then
        alter table public.users
            add constraint users_approval_status_check
            check (approval_status in ('pending', 'approved', 'rejected'));
    end if;

    if not exists (
        select 1
        from pg_constraint
        where conname = 'users_phone_unique'
          and conrelid = 'public.users'::regclass
    ) then
        alter table public.users
            add constraint users_phone_unique unique (phone);
    end if;
end $$;

create unique index if not exists idx_users_name
    on public.users (name);

create index if not exists idx_users_role
    on public.users (role);

create index if not exists idx_users_approval_status
    on public.users (approval_status);

create index if not exists idx_users_is_active
    on public.users (is_active);

-- ============================================================================
-- CLIENT_INFO.ASSIGNED_TO MIGRATION
-- ============================================================================
-- 001_init_crmx_tables.sql creates assigned_to as text. New backend code expects
-- assigned_to to be the UUID of public.users.id. This migration converts the
-- column only when all existing assigned_to names can be mapped to users.

alter table public.client_info
    add column if not exists assigned_to_user_id uuid;

update public.client_info ci
set assigned_to_user_id = u.id
from public.users u
where ci.assigned_to_user_id is null
  and ci.assigned_to = u.name;

do $$
declare
    assigned_to_type text;
    unmapped_count integer;
begin
    select data_type
    into assigned_to_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'client_info'
      and column_name = 'assigned_to';

    if assigned_to_type = 'text' then
        select count(*)
        into unmapped_count
        from public.client_info
        where assigned_to_user_id is null;

        if unmapped_count = 0 then
            alter table public.client_info
                alter column assigned_to_user_id set not null;

            if not exists (
                select 1
                from pg_constraint
                where conname = 'fk_client_info_assigned_to_user'
                  and conrelid = 'public.client_info'::regclass
            ) then
                alter table public.client_info
                    add constraint fk_client_info_assigned_to_user
                    foreign key (assigned_to_user_id)
                    references public.users(id)
                    on delete restrict;
            end if;

            alter table public.client_info
                drop column assigned_to;

            alter table public.client_info
                rename column assigned_to_user_id to assigned_to;
        end if;
    end if;
end $$;

create index if not exists idx_client_info_assigned_to
    on public.client_info (assigned_to);

commit;
