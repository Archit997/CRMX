begin;

-- Canonical status master seed data is stored in db/postgres/seeds/status_master_seed.json.

-- =========================
-- STATUS MASTER
-- =========================
create table if not exists public.status_master (
    status_no integer primary key,
    status_name text not null,
    category text not null check (category in ('Lead', 'Client', 'Critical')),
    description text,
    is_active boolean not null default true
);

create index if not exists idx_status_master_category
    on public.status_master (category);

create index if not exists idx_status_master_is_active
    on public.status_master (is_active);

-- =========================
-- CLIENT INFO
-- =========================
create table if not exists public.client_info (
    client_id bigint generated always as identity primary key,
    client_name text not null,
    company_name text,
    phone text not null,
    whatsapp_number text,
    email text,
    city text,
    assigned_to text not null,
    current_status_no integer not null references public.status_master(status_no),
    requirement_summary text,
    priority text not null check (priority in ('Hot', 'Warm', 'Cold')),
    created_date date not null default current_date,
    last_updated timestamptz not null default now()
);

create index if not exists idx_client_info_phone
    on public.client_info (phone);

-- create index if not exists idx_client_info_whatsapp_number
--     on public.client_info (whatsapp_number);

create index if not exists idx_client_info_assigned_to
    on public.client_info (assigned_to);

create index if not exists idx_client_info_current_status_no
    on public.client_info (current_status_no);

create index if not exists idx_client_info_priority
    on public.client_info (priority);

create index if not exists idx_client_info_last_updated
    on public.client_info (last_updated desc);

-- =========================
-- CLIENT UPDATES
-- =========================
create table if not exists public.client_updates (
    update_id bigint generated always as identity primary key,
    client_id bigint not null references public.client_info(client_id) on delete cascade,
    update_type text not null check (
        update_type in ('Status Change', 'Call', 'WhatsApp', 'Document Sent', 'Follow-up')
    ),
    old_status_no integer references public.status_master(status_no),
    new_status_no integer not null references public.status_master(status_no),
    request_type text not null check (request_type in ('Information', 'Document', 'None')),
    request_subtype text not null check (request_subtype in ('Price', 'Quotation', 'Receipt', 'Delivery', 'None')),
    note text not null,
    followup_date date,
    followup_time time,
    created_by text not null,
    created_at timestamptz not null default now()
);

create index if not exists idx_client_updates_client_id
    on public.client_updates (client_id);

create index if not exists idx_client_updates_created_at
    on public.client_updates (created_at desc);

create index if not exists idx_client_updates_new_status_no
    on public.client_updates (new_status_no);

create index if not exists idx_client_updates_followup_date
    on public.client_updates (followup_date);

-- =========================
-- INITIAL STATUS MASTER DATA
-- =========================
insert into public.status_master (status_no, status_name, category, description, is_active) values
    (1, 'New Lead', 'Lead', null, true),
    (2, 'Contacted', 'Lead', null, true),
    (3, 'Asked for Information', 'Lead', null, true),
    (4, 'Information Sent', 'Lead', null, true),
    (5, 'Asked for Document', 'Lead', null, true),
    (6, 'Document Sent', 'Lead', null, true),
    (7, 'Follow-up Required', 'Lead', null, true),
    (8, 'Negotiation Phase', 'Client', null, true),
    (9, 'Payment Pending', 'Client', null, true),
    (10, 'Order Confirmed', 'Client', null, true),
    (11, 'Delivered / Completed', 'Client', null, true),
    (12, 'After-Sales Follow-up', 'Client', null, true),
    (13, 'On Hold', 'Critical', null, true),
    (14, 'Lost', 'Critical', null, true)
on conflict (status_no) do update
set
    status_name = excluded.status_name,
    category = excluded.category,
    description = excluded.description,
    is_active = excluded.is_active;

commit;
