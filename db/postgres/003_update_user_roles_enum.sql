begin;

-- ============================================================================
-- UPDATE USER ROLES TO NEW ENUM VALUES
-- ============================================================================
-- This migration updates the role column constraint to use new enum values:
-- Old: 'sales', 'manager', 'finance', 'admin'
-- New: 'ADMIN', 'MANAGER', 'DEV', 'EMPLOYEE'

-- Step 1: Drop the existing constraint
alter table public.users
    drop constraint if exists users_role_check;

-- Step 2: Update existing role values to new enum values
update public.users
set role = case
    when role = 'admin' then 'ADMIN'
    when role = 'manager' then 'MANAGER'
    when role = 'sales' then 'EMPLOYEE'
    when role = 'finance' then 'DEV'
    else 'EMPLOYEE'  -- default fallback
end;

-- Step 3: Add the new constraint with updated values
alter table public.users
    add constraint users_role_check
    check (role in ('ADMIN', 'MANAGER', 'DEV', 'EMPLOYEE'));

commit;
