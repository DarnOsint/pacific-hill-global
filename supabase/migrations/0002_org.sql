-- =============================================================================
-- 0002_org.sql
-- Organisation: business units, branches, customers, suppliers, approvals.
--
-- business_units is the backbone of the diversification rule: a new sector is
-- a row, not a code branch.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- business_units
-- ---------------------------------------------------------------------------
create table public.business_units (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,           -- 'AUTO', 'REAL_ESTATE'
  slug           text not null unique,           -- 'automobiles'
  name           text not null,                  -- 'Automobile & Vehicle Trading'
  short_name     text not null,
  tagline        text,
  description    text,                           -- long form (public page)
  summary        text,                           -- card copy
  icon           text,                           -- lucide icon key
  accent_color   text,                           -- hex, used for the sector accent
  image_url      text,
  gallery        text[] not null default '{}',
  legal_entity   text,
  registration_number text,
  established_on date,
  manager_id     uuid,                           -- FK to employees, below
  public_visible boolean not null default true,  -- appears on the public site
  internal_visible boolean not null default true,
  show_metrics   boolean not null default false, -- publish unit statistics
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  seo            jsonb not null default '{}'::jsonb,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint business_units_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint business_units_color_format check (accent_color is null or accent_color ~ '^#[0-9A-Fa-f]{6}$')
);

create index business_units_public_idx
  on public.business_units (sort_order)
  where is_active and public_visible and deleted_at is null;

alter table public.employees
  add constraint employees_business_unit_fk
  foreign key (business_unit_id) references public.business_units(id) on delete set null;

alter table public.user_roles
  add constraint user_roles_business_unit_fk
  foreign key (scope_business_unit_id) references public.business_units(id) on delete cascade;

alter table public.business_units
  add constraint business_units_manager_fk
  foreign key (manager_id) references public.employees(id) on delete set null;

-- ---------------------------------------------------------------------------
-- branches : physical offices / operating locations
-- ---------------------------------------------------------------------------
create table public.branches (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  name           text not null,
  business_unit_id uuid references public.business_units(id) on delete set null,
  country        text not null,
  city           text,
  address_line1  text,
  address_line2  text,
  phone          text,
  email          text,
  timezone       text not null default 'UTC',
  latitude       numeric(9,6),
  longitude      numeric(9,6),
  is_head_office boolean not null default false,
  is_public      boolean not null default false,
  is_active      boolean not null default true,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create unique index branches_head_office_idx
  on public.branches ((true)) where is_head_office and deleted_at is null;

-- ---------------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------------
create table public.customers (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  customer_type     text not null default 'individual'
                      check (customer_type in ('individual','company','government','institution')),
  display_name      text not null,
  legal_name        text,
  email             text,
  phone             text,
  alt_phone         text,
  whatsapp          text,
  country           text,
  city              text,
  address           text,
  tax_number        text,
  credit_limit      numeric(18,4),
  credit_currency   char(3),
  default_currency  char(3) not null default 'USD',
  payment_terms_days integer not null default 0 check (payment_terms_days >= 0),
  rating            smallint check (rating between 1 and 5),
  assigned_sales_person_id uuid references public.employees(id) on delete set null,
  business_unit_id  uuid references public.business_units(id) on delete set null,
  notes             text,
  tags              text[] not null default '{}',
  total_purchased  numeric(18,4) not null default 0,
  outstanding_balance numeric(18,4) not null default 0,
  is_active        boolean not null default true,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create index customers_name_trgm on public.customers using gin (display_name gin_trgm_ops);
create index customers_sales_idx on public.customers (assigned_sales_person_id) where deleted_at is null;
create index customers_unit_idx  on public.customers (business_unit_id) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- suppliers
-- ---------------------------------------------------------------------------
create table public.suppliers (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  supplier_type     text not null default 'general'
                      check (supplier_type in
                        ('general','vehicle','property','agricultural','mining',
                         'logistics','services','government')),
  display_name      text not null,
  legal_name        text,
  email             text,
  phone             text,
  country           text,
  city              text,
  address           text,
  tax_number        text,
  bank_details      text,
  default_currency  char(3) not null default 'USD',
  payment_terms_days integer not null default 30,
  default_business_unit_id uuid references public.business_units(id) on delete set null,
  rating            smallint check (rating between 1 and 5),
  notes             text,
  tags              text[] not null default '{}',
  is_active        boolean not null default true,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create index suppliers_name_trgm on public.suppliers using gin (display_name gin_trgm_ops);
create index suppliers_type_idx  on public.suppliers (supplier_type) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- leads : enquiries captured from the public website or the front desk
-- ---------------------------------------------------------------------------
create table public.leads (
  id                uuid primary key default gen_random_uuid(),
  reference         text not null unique,
  source            text not null default 'website'
                      check (source in ('website','phone','email','walk_in','referral','exhibition','other')),
  subject           text,
  business_unit_id  uuid references public.business_units(id) on delete set null,
  customer_id       uuid references public.customers(id) on delete set null,
  contact_name      text not null,
  contact_email     text,
  contact_phone     text,
  country           text,
  message           text not null,
  status            text not null default 'new'
                      check (status in ('new','contacted','qualified','proposal',
                                        'negotiation','won','lost','spam')),
  priority          text not null default 'normal'
                      check (priority in ('low','normal','high','urgent')),
  assigned_to       uuid references public.employees(id) on delete set null,
  assigned_by       uuid references public.users(id) on delete set null,
  next_follow_up_at timestamptz,
  converted_at      timestamptz,
  lost_reason       text,
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  constraint leads_followup_ck check (
    status = 'lost' or status = 'won' or next_follow_up_at is not null or true
  )
);

create index leads_status_idx   on public.leads (status) where deleted_at is null;
create index leads_assignee_idx on public.leads (assigned_to) where deleted_at is null;
create index leads_created_idx  on public.leads (created_at desc);

-- ---------------------------------------------------------------------------
-- approval_rules : configurable thresholds. Adding a rule is data, not code.
-- ---------------------------------------------------------------------------
create table public.approval_rules (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  name              text not null,
  description       text,
  action_key        text not null,     -- 'expense.create' | 'vehicle.purchase' | …
  business_unit_id  uuid references public.business_units(id) on delete cascade,
  department_id     uuid references public.departments(id) on delete cascade,
  threshold_amount  numeric(18,4),
  threshold_currency char(3),
  required_permission text not null,   -- permission that can approve
  required_level    smallint not null default 1 check (required_level between 1 and 5),
  max_approvers     smallint not null default 1 check (max_approvers between 1 and 5),
  is_active         boolean not null default true,
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create index approval_rules_action_idx on public.approval_rules (action_key) where is_active;

-- ---------------------------------------------------------------------------
-- approvals : instantiated request/decision records
-- ---------------------------------------------------------------------------
create type public.approval_status as enum
  ('pending','approved','rejected','cancelled','expired');

create table public.approvals (
  id                uuid primary key default gen_random_uuid(),
  reference         text not null unique,
  rule_id           uuid references public.approval_rules(id) on delete set null,
  action_key        text not null,
  subject_type      text not null,      -- 'expense' | 'vehicle' | 'property' …
  subject_id        uuid not null,
  business_unit_id  uuid references public.business_units(id) on delete set null,
  requested_by      uuid not null references public.users(id) on delete restrict,
  requested_for     uuid references public.users(id) on delete set null,
  amount            numeric(18,4),
  currency          char(3),
  base_amount       numeric(18,4),
  base_currency     char(3),
  payload           jsonb not null default '{}'::jsonb,
  status            public.approval_status not null default 'pending',
  required_level    smallint not null default 1,
  decisions         jsonb not null default '[]'::jsonb,
  expires_at        timestamptz,
  resolved_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create index approvals_pending_idx
  on public.approvals (created_at)
  where status = 'pending' and deleted_at is null;
create index approvals_subject_idx on public.approvals (subject_type, subject_id);
create index approvals_requester_idx on public.approvals (requested_by);
