-- =============================================================================
-- 0004_automobiles.sql
-- Automobile business unit: vehicle inventory, expenses, repairs, shipping,
-- sales, and the derived profitability model.
--
-- MONEY RULE: every total is computed in Postgres. The browser never sends or
-- computes a total. See docs/ARCHITECTURE.md §9.8.
-- =============================================================================

create type public.vehicle_status as enum
  ('purchased','in_transit','arrived','under_repair','ready_for_sale',
   'reserved','sold','cancelled');

create type public.vehicle_condition as enum
  ('new','used_excellent','used_good','used_fair','project','unknown');

-- ---------------------------------------------------------------------------
-- vehicles
-- ---------------------------------------------------------------------------
create table public.vehicles (
  id                uuid primary key default gen_random_uuid(),
  stock_number      text not null unique,          -- PHG-AUTO-0001
  business_unit_id  uuid not null references public.business_units(id) on delete restrict,
  department_id     uuid references public.departments(id) on delete set null,
  branch_id         uuid references public.branches(id) on delete set null,

  make              text not null,
  model             text not null,
  variant           text,
  model_year        smallint not null check (model_year between 1900 and 2100),
  colour            text,
  interior_colour   text,
  body_type         text,
  transmission      text check (transmission in ('automatic','manual','cvt','dct','other')),
  fuel_type         text,
  engine_number     text,
  chassis_number    text,                          -- VIN
  plate_number      text,
  mileage_km        integer check (mileage_km >= 0),
  odometer_unit     text not null default 'km' check (odometer_unit in ('km','mi')),
  condition         public.vehicle_condition not null default 'used_good',
  steering          text check (steering in ('left','right')),
  seats             smallint,
  fuel_capacity_l   numeric(6,2),

  -- acquisition --------------------------------------------------------
  supplier_id       uuid references public.suppliers(id) on delete set null,
  country_purchased text,
  purchase_date     date not null,
  purchase_price    numeric(18,4) not null check (purchase_price >= 0),
  purchase_currency char(3) not null,
  exchange_rate     numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  purchase_invoice_ref text,
  payment_status    text not null default 'unpaid'
                      check (payment_status in ('unpaid','partial','paid','financed')),

  -- status -------------------------------------------------------------
  status            public.vehicle_status not null default 'purchased',
  status_changed_at timestamptz not null default now(),
  status_changed_by uuid references public.users(id) on delete set null,

  -- ownership / assignment --------------------------------------------
  assigned_sales_person_id uuid references public.employees(id) on delete set null,
  current_location  text,
  arrival_date      date,
  ready_for_sale_at timestamptz,
  notes             text,

  -- publication --------------------------------------------------------
  is_public         boolean not null default false,
  public_title      text,
  public_description text,
  public_photos     text[] not null default '{}',

  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,

  constraint vehicles_stock_format check (stock_number ~ '^PHG-[A-Z0-9-]{2,24}$'),
  constraint vehicles_rate_required check (
    purchase_currency is not null
  )
);

create index vehicles_unit_idx    on public.vehicles (business_unit_id) where deleted_at is null;
create index vehicles_status_idx  on public.vehicles (status) where deleted_at is null;
create index vehicles_make_idx    on public.vehicles (lower(make), lower(model)) where deleted_at is null;
create index vehicles_sales_idx   on public.vehicles (assigned_sales_person_id) where deleted_at is null;
create index vehicles_supplier_idx on public.vehicles (supplier_id) where deleted_at is null;
create index vehicles_purchase_idx on public.vehicles (purchase_date desc) where deleted_at is null;
create index vehicles_public_idx  on public.vehicles (stock_number)
  where is_public and status = 'ready_for_sale' and deleted_at is null;
create index vehicles_chassis_idx on public.vehicles (chassis_number)
  where chassis_number is not null and deleted_at is null;

-- ---------------------------------------------------------------------------
-- vehicle_expenses : every additional cost, itemised.
-- category drives the cost buckets the Director sees in the profitability report.
-- ---------------------------------------------------------------------------
create type public.vehicle_expense_category as enum
  ('shipping','port_charges','clearing','inspection','transportation',
   'repair','parts','customs_duty','registration','insurance','storage',
   'documentation','commission','other');

create table public.vehicle_expenses (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles(id) on delete cascade,
  business_unit_id uuid references public.business_units(id) on delete restrict,
  category       public.vehicle_expense_category not null,
  description    text not null,
  vendor_id      uuid references public.suppliers(id) on delete set null,
  vendor_name    text,
  invoice_ref    text,
  amount         numeric(18,4) not null check (amount >= 0),
  currency       char(3) not null,
  exchange_rate  numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  incurred_on    date not null,
  is_approved    boolean not null default false,
  approved_by    uuid references public.users(id) on delete set null,
  approved_at    timestamptz,
  approval_id    uuid references public.approvals(id) on delete set null,
  receipt_path   text,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index vehicle_expenses_vehicle_idx on public.vehicle_expenses (vehicle_id) where deleted_at is null;
create index vehicle_expenses_category_idx on public.vehicle_expenses (category) where deleted_at is null;
create index vehicle_expenses_date_idx     on public.vehicle_expenses (incurred_on desc) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- vehicle_repairs : a work order; its line costs also live in vehicle_expenses
-- so the profitability roll-up stays single-sourced.
-- ---------------------------------------------------------------------------
create type public.repair_status as enum ('planned','in_progress','awaiting_parts','completed','cancelled');

create table public.vehicle_repairs (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles(id) on delete cascade,
  reference      text not null unique,
  title          text not null,
  description    text,
  problem_reported text,
  diagnosis      text,
  work_performed text,
  status         public.repair_status not null default 'planned',
  vendor_id      uuid references public.suppliers(id) on delete set null,
  workshop_name  text,
  started_on     date,
  completed_on   date,
  labour_hours   numeric(8,2),
  parts_used     text,
  total_cost     numeric(18,4) not null default 0 check (total_cost >= 0),
  currency       char(3) not null default 'USD',
  warranty       boolean not null default false,
  technician     text,
  approved_by    uuid references public.users(id) on delete set null,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint vehicle_repairs_dates_ck check (completed_on is null or started_on is null
                                             or completed_on >= started_on)
);

create index vehicle_repairs_vehicle_idx on public.vehicle_repairs (vehicle_id) where deleted_at is null;
create index vehicle_repairs_status_idx  on public.vehicle_repairs (status) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- vehicle_shipping : inbound logistics leg (port-to-yard)
-- ---------------------------------------------------------------------------
create type public.shipping_status as enum
  ('booked','picked_up','in_transit','customs','clearing','delivered','cancelled');

create table public.vehicle_shipping (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles(id) on delete cascade,
  reference      text not null unique,
  shipping_line  text,
  vessel_name    text,
  voyage_number  text,
  container_number text,
  bill_of_lading text,
  mode           text not null default 'sea'
                   check (mode in ('sea','road','rail','air','land')),
  origin_port    text,
  origin_country text,
  destination_port text,
  destination_country text,
  departure_date date,
  arrival_date   date,
  estimated_arrival_date date,
  status         public.shipping_status not null default 'booked',
  freight_cost   numeric(18,4) not null default 0 check (freight_cost >= 0),
  insurance_cost numeric(18,4) not null default 0 check (insurance_cost >= 0),
  port_charges   numeric(18,4) not null default 0 check (port_charges >= 0),
  clearing_cost  numeric(18,4) not null default 0 check (clearing_cost >= 0),
  inspection_cost numeric(18,4) not null default 0 check (inspection_cost >= 0),
  other_costs    numeric(18,4) not null default 0 check (other_costs >= 0),
  total_cost     numeric(18,4) not null default 0 check (total_cost >= 0),
  currency       char(3) not null default 'USD',
  documents_path text,
  notes          text,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint vehicle_shipping_dates_ck check (arrival_date is null or departure_date is null
                                              or arrival_date >= departure_date)
);

create index vehicle_shipping_vehicle_idx on public.vehicle_shipping (vehicle_id) where deleted_at is null;
create index vehicle_shipping_status_idx  on public.vehicle_shipping (status) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- vehicle_sales : the sale. Exactly one active sale per vehicle (enforced).
-- ---------------------------------------------------------------------------
create type public.sale_status as enum ('inquiry','negotiation','deposit_paid','sold','cancelled','refunded');

create table public.vehicle_sales (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles(id) on delete restrict,
  reference      text not null unique,
  customer_id    uuid references public.customers(id) on delete set null,
  buyer_name     text not null,
  buyer_type     text not null default 'individual'
                   check (buyer_type in ('individual','company','government','institution')),
  contact_email  text,
  contact_phone  text,
  country        text,

  sale_price         numeric(18,4) not null check (sale_price >= 0),
  sale_currency      char(3) not null,
  exchange_rate      numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  expected_sale_price numeric(18,4) check (expected_sale_price is null or expected_sale_price >= 0),
  expected_sale_currency char(3),

  commission_rate numeric(6,3) check (commission_rate is null or commission_rate >= 0),
  discount_amount numeric(18,4) not null default 0 check (discount_amount >= 0),

  status         public.sale_status not null default 'inquiry',
  deposit_amount numeric(18,4) not null default 0 check (deposit_amount >= 0),
  deposit_paid_at timestamptz,
  balance_paid_at timestamptz,
  payment_method text,
  payment_reference text,
  sale_date      date,
  expected_delivery_date date,
  delivered_at   timestamptz,

  sales_person_id uuid references public.employees(id) on delete set null,
  contract_path  text,
  notes          text,

  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,

  constraint vehicle_sales_dates_ck check (
    (status <> 'sold') or (sale_date is not null)
  )
);

-- One live (non-cancelled) sale per vehicle.
create unique index vehicle_sales_one_active_idx
  on public.vehicle_sales (vehicle_id)
  where status <> 'cancelled' and deleted_at is null;

create index vehicle_sales_vehicle_idx on public.vehicle_sales (vehicle_id) where deleted_at is null;
create index vehicle_sales_customer_idx on public.vehicle_sales (customer_id) where deleted_at is null;
create index vehicle_sales_salesperson_idx on public.vehicle_sales (sales_person_id) where deleted_at is null;
create index vehicle_sales_date_idx  on public.vehicle_sales (sale_date desc) where deleted_at is null;
create index vehicle_sales_status_idx on public.vehicle_sales (status) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- vehicle_documents
-- ---------------------------------------------------------------------------
create table public.vehicle_documents (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles(id) on delete cascade,
  document_type  text not null
                   check (document_type in ('purchase_invoice','bill_of_lading','customs',
                     'clearance','inspection','registration','insurance','title',
                     'service_history','photo','other')),
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

create index vehicle_documents_vehicle_idx on public.vehicle_documents (vehicle_id) where deleted_at is null;
