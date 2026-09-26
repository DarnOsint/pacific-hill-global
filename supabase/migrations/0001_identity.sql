-- =============================================================================
-- 0001_identity.sql
-- Identity: users, employees, departments, roles, permissions, assignments.
--
-- The authorisation model is documented in docs/RBAC.md.
-- This migration implements the four tables that model it plus the employee
-- profile that carries HR data.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- users : 1:1 mirror of auth.users, plus application-level account state.
--         Account lifecycle (active/suspended/disabled) lives here so that a
--         deactivated employee loses access immediately, without needing to
--         revoke Supabase sessions.
-- ---------------------------------------------------------------------------
create table public.users (
  id                  uuid primary key references auth.users(id) on delete cascade,
  email               text        not null,
  email_normalised    text        not null unique,
  full_name           text        not null,
  avatar_url          text,
  locale              text        not null default 'en',
  timezone            text        not null default 'UTC',
  account_status      text        not null default 'pending'
                        check (account_status in ('pending','active','suspended','disabled')),
  status_reason       text,
  status_changed_at   timestamptz,
  status_changed_by   uuid references public.users(id) on delete set null,
  mfa_enabled         boolean     not null default false,
  mfa_secret          text,                     -- sealed TOTP secret, nullable
  mfa_recovery_codes  text[],                   -- hashed recovery codes
  last_login_at       timestamptz,
  last_login_ip       inet,
  failed_login_count  integer     not null default 0,
  locked_until        timestamptz,
  password_changed_at timestamptz,
  must_change_password boolean    not null default false,
  session_absolute_deadline timestamptz,
  data                jsonb       not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint users_email_format check (email_normalised = lower(trim(email_normalised)))
);

comment on column public.users.mfa_secret is
  'Sealed TOTP shared secret. Only ever written by the MFA enrolment service.';

create index users_status_idx  on public.users (account_status) where deleted_at is null;
create index users_name_trgm  on public.users using gin (full_name gin_trgm_ops);
create index users_deleted_idx on public.users (deleted_at);

-- ---------------------------------------------------------------------------
-- departments : orthogonal to business_units.
-- An employee has ONE primary department, but may be assigned to several
-- business units (via role scope or explicit assignment).
-- ---------------------------------------------------------------------------
create table public.departments (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  name         text not null,
  description  text,
  parent_id    uuid references public.departments(id) on delete set null,
  head_id      uuid references public.users(id) on delete set null,
  is_active    boolean not null default true,
  sort_order   integer not null default 0,
  created_by   uuid references public.users(id) on delete set null,
  updated_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create index departments_active_idx on public.departments (sort_order) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- employees : HR profile. Split from users because:
--   - a user row may exist before an employee record is created (invited)
--   - HR data must be independently permission-gated (employees.view_sensitive)
-- ---------------------------------------------------------------------------
create table public.employees (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid unique references public.users(id) on delete set null,
  employee_number   text not null unique,        -- e.g. PHG-EMP-001
  full_name         text not null,
  preferred_name    text,
  photo_url         text,
  job_title         text,
  department_id     uuid references public.departments(id) on delete set null,
  business_unit_id  uuid,                        -- FK added in 0002 (org)
  branch_id         uuid,                        -- FK added in 0002 (org)
  manager_id        uuid references public.employees(id) on delete set null,
  work_email        text,
  work_phone        text,
  mobile_phone      text,
  date_of_birth     date,
  national_id       text,                        -- sensitive
  tax_id            text,                        -- sensitive
  passport_number   text,                        -- sensitive
  bank_account      text,                        -- sensitive
  address           text,
  city              text,
  country           text,
  employment_type   text check (employment_type in
                      ('full_time','part_time','contract','intern','consultant')),
  date_employed     date,
  date_terminated   date,
  employment_status text not null default 'active'
                      check (employment_status in
                        ('applicant','probation','active','on_leave','suspended','terminated')),
  emergency_contact jsonb not null default '{}'::jsonb,   -- sensitive
  skills            text[] not null default '{}',
  bio               text,
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  constraint employees_dates_ck check (date_terminated is null or date_employed is null
                                      or date_terminated >= date_employed)
);

comment on table public.employees is
  'HR profile. Columns national_id, tax_id, passport_number, bank_account, '
  'emergency_contact, date_of_birth are gated behind employees.view_sensitive.';

create index employees_dept_idx  on public.employees (department_id) where deleted_at is null;
create index employees_unit_idx  on public.employees (business_unit_id) where deleted_at is null;
create index employees_mgr_idx   on public.employees (manager_id);
create index employees_status_idx on public.employees (employment_status) where deleted_at is null;
create index employees_name_trgm on public.employees using gin (full_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- permissions : the atomic capability catalogue. Adding a capability is a row
-- insert, never a code change.
-- ---------------------------------------------------------------------------
create table public.permissions (
  id           uuid primary key default gen_random_uuid(),
  key          text not null unique,             -- 'vehicles.create'
  label        text not null,
  description  text,
  category     text not null,                    -- namespace: vehicles, finance…
  is_sensitive boolean not null default false,   -- show a warning in the UI
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint permissions_key_format check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')
);

create index permissions_category_idx on public.permissions (category, key);

-- ---------------------------------------------------------------------------
-- roles : a named bundle of permissions. Never used directly in authorisation
-- logic — only via role_permissions / user_roles.
-- ---------------------------------------------------------------------------
create table public.roles (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,             -- 'finance_officer'
  name         text not null,
  description  text,
  scope_type   text not null default 'global'
                 check (scope_type in ('global','department','business_unit')),
  is_system    boolean not null default false,    -- system roles cannot be deleted
  is_active    boolean not null default true,
  sort_order   integer not null default 100,
  created_by   uuid references public.users(id) on delete set null,
  updated_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create unique index roles_slug_system_idx on public.roles (slug) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- role_permissions : bundle contents.
-- ---------------------------------------------------------------------------
create table public.role_permissions (
  role_id        uuid not null references public.roles(id) on delete cascade,
  permission_id  uuid not null references public.permissions(id) on delete cascade,
  granted_by     uuid references public.users(id) on delete set null,
  granted_at     timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create index role_permissions_perm_idx on public.role_permissions (permission_id);

-- ---------------------------------------------------------------------------
-- user_roles : who holds which bundle, and where.
-- Scope columns make authorisation "permission AND scope".
-- ---------------------------------------------------------------------------
create table public.user_roles (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references public.users(id) on delete cascade,
  role_id                uuid not null references public.roles(id) on delete cascade,
  scope_type             text not null default 'global'
                           check (scope_type in ('global','department','business_unit')),
  scope_department_id    uuid references public.departments(id) on delete cascade,
  scope_business_unit_id uuid,
  granted_by             uuid references public.users(id) on delete set null,
  granted_at             timestamptz not null default now(),
  expires_at             timestamptz,
  revoked_at             timestamptz,
  revoked_by             uuid references public.users(id) on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint user_roles_scope_ck check (
    (scope_type = 'global'      and scope_department_id is null and scope_business_unit_id is null) or
    (scope_type = 'department'  and scope_department_id is not null) or
    (scope_type = 'business_unit' and scope_business_unit_id is not null)
  )
);

create index user_roles_user_idx   on public.user_roles (user_id) where revoked_at is null;
create index user_roles_role_idx   on public.user_roles (role_id);
create index user_roles_expiry_idx on public.user_roles (expires_at)
  where revoked_at is null and expires_at is not null;

-- ---------------------------------------------------------------------------
-- employee_attachments : employee documents (contracts, IDs, certificates)
-- ---------------------------------------------------------------------------
create table public.employee_documents (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  title        text not null,
  document_type text not null,
  storage_path text not null,
  file_name    text not null,
  mime_type    text not null,
  size_bytes   bigint not null check (size_bytes > 0),
  is_sensitive boolean not null default true,
  expires_at   date,
  uploaded_by  uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create index employee_documents_emp_idx on public.employee_documents (employee_id);

-- ---------------------------------------------------------------------------
-- user_sessions : application-level session registry, used for absolute
-- session deadlines and for showing "active devices" to the user.
-- ---------------------------------------------------------------------------
create table public.user_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  session_id   text not null unique,
  user_agent   text,
  ip_address   inet,
  country      text,
  started_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at   timestamptz not null,
  ended_at     timestamptz,
  ended_reason text
);

create index user_sessions_user_idx on public.user_sessions (user_id) where ended_at is null;
