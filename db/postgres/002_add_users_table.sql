begin;

-- =========================
-- USERS TABLE
-- =========================
create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    role text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists idx_users_name
    on public.users (name);

create index if not exists idx_users_role
    on public.users (role);

-- =========================
-- SEED INITIAL USERS
-- =========================

-- =========================
-- MIGRATE CLIENT_INFO.ASSIGNED_TO
-- =========================

-- Step 1: Add new column for user_id
alter table public.client_info
    add column if not exists assigned_to_user_id uuid;

-- Step 2: Populate the new column by mapping names to UUIDs
update public.client_info ci
set assigned_to_user_id = u.id
from public.users u
where ci.assigned_to = u.name;

-- Step 3: Make the new column not null after data migration
alter table public.client_info
    alter column assigned_to_user_id set not null;

-- Step 4: Add foreign key constraint
alter table public.client_info
    add constraint fk_client_info_assigned_to_user
    foreign key (assigned_to_user_id)
    references public.users(id)
    on delete restrict;

-- Step 5: Drop the old assigned_to column
alter table public.client_info
    drop column if exists assigned_to;

-- Step 6: Rename the new column to assigned_to
alter table public.client_info
    rename column assigned_to_user_id to assigned_to;

-- Step 7: Create index on the new assigned_to (uuid) column
create index if not exists idx_client_info_assigned_to
    on public.client_info (assigned_to);

-- =========================
-- UPDATE CLIENT_UPDATES.CREATED_BY
-- =========================
-- Note: created_by in client_updates is also text (user name)
-- We'll keep it as text for now since it's just for audit trail
-- If needed, we can migrate this later to uuid as well

commit;
