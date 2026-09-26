-- =============================================================================
-- 0006_agri_mining.sql
-- Agricultural projects and mining projects.
--
-- Both follow the same shape: identity -> costs -> production/sales -> result.
-- This symmetry is deliberate: adding a future business unit (Energy, Forestry)
-- copies this pattern, it does not invent a new one.
-- ---------------------------------------------------------------------------

create type public.project_status as enum
  ('planning','active','on_hold','completed','cancelled','closed');

-- =============================================================================
-- AGRICULTURE
-- =============================================================================
create table public.agricultural_projects (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,          -- PHG-AG-0001
  name            text not null,
  business_unit_id uuid not null references public.business_units(id) on delete restrict,
  department_id   uuid references public.departments(id) on delete set null,
  branch_id       uuid references public.branches(id) on delete set null,

  country         text not null,
  region          text,
  district        text,
  locality        text,
  gps_coordinates text,
  land_size_value numeric(14,2) not null check (land_size_value > 0),
  land_size_unit  text not null default 'hectare'
                    check (land_size_unit in ('hectare','acre','sqm','sqft')),
  tenure          text,
  lease_reference text,

  crop            text not null,                 -- Maize | Cassava | Tomato | …
  variety         text,
  season          text,
  farming_method  text default 'rainfed'
                    check (farming_method in ('rainfed','irrigated','greenhouse','hydroponic')),

  project_manager_id uuid references public.employees(id) on delete set null,
  agronomist_id   uuid references public.employees(id) on delete set null,
  start_date      date not null,
  expected_harvest_date date,
  actual_harvest_date    date,
  status          public.project_status not null default 'planning',
  status_changed_at timestamptz not null default now(),

  expected_yield_value numeric(14,2),
  expected_yield_unit  text default 'tonnes',
  actual_yield_value   numeric(14,2),
  actual_yield_unit    text default 'tonnes',

  expected_revenue numeric(18,4),
  revenue_currency char(3),
  actual_revenue   numeric(18,4),
  actual_currency  char(3),

  farm_manager     text,
  worker_count     integer check (worker_count is null or worker_count >= 0),
  irrigation_source text,
  storage_capacity_tonnes numeric(12,2),
  is_public        boolean not null default false,

  notes            text,
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create index agri_projects_unit_idx   on public.agricultural_projects (business_unit_id) where deleted_at is null;
create index agri_projects_status_idx on public.agricultural_projects (status) where deleted_at is null;
create index agri_projects_crop_idx   on public.agricultural_projects (lower(crop)) where deleted_at is null;
create index agri_projects_manager_idx on public.agricultural_projects (project_manager_id) where deleted_at is null;

create type public.agri_cost_category as enum
  ('seeds','seedlings','fertiliser','pesticides','herbicides','irrigation',
   'labour','machinery','fuel','transport','land_preparation','equipment',
   'storage','certification','insurance','rent','other');

create table public.agricultural_costs (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.agricultural_projects(id) on delete cascade,
  category       public.agri_cost_category not null,
  description    text not null,
  supplier_id    uuid references public.suppliers(id) on delete set null,
  amount         numeric(18,4) not null check (amount >= 0),
  currency       char(3) not null,
  exchange_rate  numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  quantity       numeric(14,2),
  unit           text,
  incurred_on    date not null,
  is_approved    boolean not null default false,
  approved_by    uuid references public.users(id) on delete set null,
  document_path  text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index agri_costs_project_idx  on public.agricultural_costs (project_id) where deleted_at is null;
create index agri_costs_category_idx on public.agricultural_costs (category) where deleted_at is null;

create table public.agricultural_harvests (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.agricultural_projects(id) on delete cascade,
  harvest_date   date not null,
  quantity       numeric(14,2) not null check (quantity >= 0),
  unit           text not null default 'tonnes',
  grade          text,
  buyer_id       uuid references public.customers(id) on delete set null,
  buyer_name     text,
  unit_price     numeric(18,4),
  currency       char(3),
  total_value    numeric(18,4),
  storage_location text,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index agri_harvests_project_idx on public.agricultural_harvests (project_id) where deleted_at is null;

-- =============================================================================
-- MINING
-- =============================================================================
create type public.license_status as enum
  ('application','granted','under_review','suspended','expired','revoked');

create table public.mining_projects (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,          -- PHG-MIN-0001
  name            text not null,
  business_unit_id uuid not null references public.business_units(id) on delete restrict,
  department_id   uuid references public.departments(id) on delete set null,
  branch_id       uuid references public.branches(id) on delete set null,

  country         text not null,
  region          text,
  district        text,
  locality        text,
  gps_coordinates text,
  site_area_value numeric(14,2),
  site_area_unit  text default 'hectare',
  tenure          text,

  mineral         text,                          -- free-form: no mineral is assumed
  mineral_category text,                         -- metallic | non_metallic | …
  commodity_notes text,
  concession_type text,                          -- exploration | mining | artisanal
  license_number  text,
  license_status  public.license_status,
  license_issued_on date,
  license_expires_on date,
  license_holder  text,
  license_document_path text,

  project_manager_id uuid references public.employees(id) on delete set null,
  geologist_id    uuid references public.employees(id) on delete set null,
  start_date      date not null,
  expected_commissioning date,
  commissioning_date date,
  status          public.project_status not null default 'planning',
  status_changed_at timestamptz not null default now(),
  status_reason   text,

  method          text,                          -- open_pit | underground | alluvial | dredging
  reserve_estimate text,
  resource_grade  text,
  plant_capacity  numeric(14,2),
  plant_capacity_unit text default 'tonnes/day',
  workforce       integer,
  is_public       boolean not null default false,

  notes           text,
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create index mining_projects_unit_idx   on public.mining_projects (business_unit_id) where deleted_at is null;
create index mining_projects_status_idx on public.mining_projects (status) where deleted_at is null;
create index mining_projects_lic_idx    on public.mining_projects (license_status) where deleted_at is null;
create index mining_projects_manager_idx on public.mining_projects (project_manager_id) where deleted_at is null;

create type public.mining_cost_category as enum
  ('licensing','permits','land_acquisition','exploration','drilling','blastings',
   'equipment','equipment_hire','fuel','power','labour','contractors','transport',
   'processing','marketing','royalties','taxes','insurance','consultancy','other');

create table public.mining_costs (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.mining_projects(id) on delete cascade,
  category       public.mining_cost_category not null,
  description    text not null,
  supplier_id    uuid references public.suppliers(id) on delete set null,
  amount         numeric(18,4) not null check (amount >= 0),
  currency       char(3) not null,
  exchange_rate  numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  incurred_on    date not null,
  is_approved    boolean not null default false,
  approved_by    uuid references public.users(id) on delete set null,
  document_path  text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index mining_costs_project_idx  on public.mining_costs (project_id) where deleted_at is null;
create index mining_costs_category_idx on public.mining_costs (category) where deleted_at is null;

create table public.mining_production (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.mining_projects(id) on delete cascade,
  production_date date not null,
  quantity       numeric(14,2) not null check (quantity >= 0),
  unit           text not null default 'tonnes',
  grade          text,
  source         text,                           -- pit | plant | hand-sorted
  stock_location text,
  notes          text,
  recorded_by    uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index mining_production_project_idx on public.mining_production (project_id) where deleted_at is null;

create table public.mining_sales (
  id             uuid primary key default gen_random_uuid(),
  reference      text not null unique,
  project_id     uuid not null references public.mining_projects(id) on delete cascade,
  customer_id    uuid references public.customers(id) on delete set null,
  buyer_name     text not null,
  commodity      text,
  quantity       numeric(14,2) not null check (quantity >= 0),
  unit           text not null default 'tonnes',
  unit_price     numeric(18,4) not null check (unit_price >= 0),
  total_value    numeric(18,4) not null check (total_value >= 0),
  currency       char(3) not null,
  sale_date      date not null,
  payment_terms_days integer not null default 0,
  amount_received numeric(18,4) not null default 0,
  status         public.sale_status not null default 'inquiry',
  document_path  text,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index mining_sales_project_idx on public.mining_sales (project_id) where deleted_at is null;
create index mining_sales_date_idx    on public.mining_sales (sale_date desc) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- project_documents : shared for agriculture and mining
-- ---------------------------------------------------------------------------
create table public.project_documents (
  id             uuid primary key default gen_random_uuid(),
  project_domain text not null check (project_domain in ('agriculture','mining')),
  project_id     uuid not null,
  document_type  text not null,
  title          text not null,
  storage_path   text not null,
  file_name      text not null,
  mime_type      text not null,
  size_bytes     bigint not null check (size_bytes > 0),
  issued_on      date,
  expires_on     date,
  is_confidential boolean not null default true,
  uploaded_by    uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index project_documents_lookup_idx on public.project_documents (project_domain, project_id)
  where deleted_at is null;
