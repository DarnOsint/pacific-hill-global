-- =============================================================================
-- 0005_realestate.sql
-- Real estate: land, houses, commercial, residential, developments.
-- ---------------------------------------------------------------------------

create type public.property_type as enum
  ('land','residential_house','apartment','commercial','office','industrial',
   'warehouse','farmland','development_site','other');

create type public.property_status as enum
  ('available','reserved','sold','under_development','unavailable');

create type public.property_tenure as enum
  ('freehold','leasehold','customary','share_ownership','concession','other');

create table public.real_estate_properties (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,           -- PHG-RE-0001
  title          text not null,
  slug           text not null unique,
  business_unit_id uuid not null references public.business_units(id) on delete restrict,
  department_id  uuid references public.departments(id) on delete set null,
  branch_id      uuid references public.branches(id) on delete set null,

  property_type  public.property_type not null,
  status         public.property_status not null default 'available',
  status_changed_at timestamptz not null default now(),

  -- location ------------------------------------------------------------
  country        text not null,
  region         text,
  city           text,
  district       text,
  locality       text,
  address        text,
  latitude       numeric(9,6),
  longitude      numeric(9,6),
  map_url        text,

  -- physical ------------------------------------------------------------
  size_value     numeric(14,2) not null check (size_value > 0),
  size_unit      text not null default 'sqm'
                   check (size_unit in ('sqm','sqft','acre','hectare','plot')),
  size_label     text,                            -- human readable, e.g. "500 sqm"
  bedrooms       smallint,
  bathrooms      smallint,
  floors         smallint,
  year_built     smallint,
  construction_status text
                   check (construction_status in ('completed','in_progress','planned','renovating')),

  -- commercial ----------------------------------------------------------
  tenure         public.property_tenure,
  title_reference text,
  plot_number    text,
  survey_number  text,
  zoning         text,

  -- pricing -------------------------------------------------------------
  price          numeric(18,4) not null check (price >= 0),
  currency       char(3) not null,
  price_negotiable boolean not null default true,
  rental_price   numeric(18,4) check (rental_price is null or rental_price >= 0),
  rental_currency char(3),
  rental_period  text check (rental_period in ('month','year')),
  expected_roi   numeric(6,2),

  -- ownership -----------------------------------------------------------
  owner_type     text not null default 'company'
                   check (owner_type in ('company','partner','third_party')),
  owner_name     text,
  ownership_note text,
  ownership_document_path text,

  -- media / docs --------------------------------------------------------
  summary        text,
  description    text,
  features       text[] not null default '{}',
  amenities      text[] not null default '{}',
  photos         text[] not null default '{}',
  video_url      text,
  floor_plan_url text,

  -- sales ---------------------------------------------------------------
  assigned_sales_person_id uuid references public.employees(id) on delete set null,
  listed_at      timestamptz,
  date_sold      date,

  -- publication ---------------------------------------------------------
  is_public      boolean not null default false,
  is_featured    boolean not null default false,
  published_at   timestamptz,
  published_by   uuid references public.users(id) on delete set null,
  seo            jsonb not null default '{}'::jsonb,

  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index properties_unit_idx   on public.real_estate_properties (business_unit_id) where deleted_at is null;
create index properties_status_idx on public.real_estate_properties (status) where deleted_at is null;
create index properties_type_idx   on public.real_estate_properties (property_type) where deleted_at is null;
create index properties_sales_idx  on public.real_estate_properties (assigned_sales_person_id) where deleted_at is null;
create index properties_loc_idx    on public.real_estate_properties (country, city) where deleted_at is null;
create index properties_public_idx on public.real_estate_properties (listed_at desc)
  where is_public and status = 'available' and deleted_at is null;

-- ---------------------------------------------------------------------------
-- property_sales
-- ---------------------------------------------------------------------------
create table public.property_sales (
  id             uuid primary key default gen_random_uuid(),
  reference      text not null unique,
  property_id    uuid not null references public.real_estate_properties(id) on delete restrict,
  customer_id    uuid references public.customers(id) on delete set null,
  buyer_name     text not null,
  buyer_type     text not null default 'individual'
                   check (buyer_type in ('individual','company','government','institution')),
  contact_email  text,
  contact_phone  text,
  country        text,

  sale_price     numeric(18,4) not null check (sale_price >= 0),
  currency       char(3) not null,
  exchange_rate  numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  deposit_amount numeric(18,4) not null default 0 check (deposit_amount >= 0),
  discount_amount numeric(18,4) not null default 0 check (discount_amount >= 0),
  commission_rate numeric(6,3) check (commission_rate is null or commission_rate >= 0),
  status         public.sale_status not null default 'inquiry',
  payment_method text,
  payment_reference text,
  sale_date      date,
  handover_date  date,
  title_transferred boolean not null default false,
  title_transfer_reference text,
  sales_person_id uuid references public.employees(id) on delete set null,
  contract_path  text,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create unique index property_sales_one_active_idx
  on public.property_sales (property_id)
  where status <> 'cancelled' and deleted_at is null;
create index property_sales_property_idx on public.property_sales (property_id) where deleted_at is null;
create index property_sales_salesperson_idx on public.property_sales (sales_person_id) where deleted_at is null;
create index property_sales_date_idx on public.property_sales (sale_date desc) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- property_documents
-- ---------------------------------------------------------------------------
create table public.property_documents (
  id             uuid primary key default gen_random_uuid(),
  property_id    uuid not null references public.real_estate_properties(id) on delete cascade,
  document_type  text not null
                   check (document_type in ('title_deed','survey','valuation','purchase_agreement',
                     'building_permit','environmental','photographs','floor_plan','other')),
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

create index property_documents_property_idx on public.property_documents (property_id) where deleted_at is null;
