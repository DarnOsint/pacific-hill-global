-- =============================================================================
-- 0007_finance.sql
-- Company-wide finance: currencies, FX, income, expenses, transactions.
--
-- Every amount is stored with its own currency plus the rate used, and a
-- base-currency equivalent is computed in SQL. Nothing is converted in a
-- component.
-- =============================================================================

create type public.record_status as enum
  ('draft','pending_approval','approved','rejected','posted','cancelled');

create type public.payment_method as enum
  ('cash','bank_transfer','mobile_money','cheque','card','credit','barter','other');

-- ---------------------------------------------------------------------------
-- currencies : configurable; the base currency is a company setting.
-- ---------------------------------------------------------------------------
create table public.currencies (
  code           char(3) primary key,
  name           text not null,
  symbol         text,
  minor_unit     smallint not null default 2 check (minor_unit between 0 and 4),
  is_active      boolean not null default true,
  is_base        boolean not null default false,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create unique index currencies_base_idx on public.currencies ((true)) where is_base;

-- ---------------------------------------------------------------------------
-- fx_rates : historical rates, one row per currency per day.
-- ---------------------------------------------------------------------------
create table public.fx_rates (
  id           uuid primary key default gen_random_uuid(),
  base_code    char(3) not null,
  quote_code   char(3) not null,
  rate         numeric(18,8) not null check (rate > 0),
  rate_date    date not null,
  source       text not null default 'manual',
  created_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (quote_code, rate_date),
  constraint fx_rates_distinct check (base_code <> quote_code)
);

create index fx_rates_lookup_idx on public.fx_rates (quote_code, rate_date desc);

-- ---------------------------------------------------------------------------
-- FX helpers
--
-- `fx_rates.rate` means: 1 unit of `base_code` is worth `rate` units of
-- `quote_code`. So converting an amount FROM quote_code TO base_code multiplies
-- by `rate`.
--
-- Assets such as a listed property price carry a currency but no stored rate:
-- the rate in force is whatever the finance team last published. These helpers
-- resolve that, so reporting views never have to invent a rate of 1 for a
-- non-base currency and silently understate value.
-- ---------------------------------------------------------------------------

-- The rate to use on a given date: the most recent published rate at or before
-- it. Falls back to 1 only when the currency is already the base (or is unknown
-- and therefore genuinely 1:1 with the base for reporting purposes).
create or replace function public.fx_rate(
  p_quote_code  char(3),
  p_base_code   char(3),
  p_on_date     date default current_date
) returns numeric
language sql stable
as $$
  select case
    when p_quote_code is null then 1
    when p_base_code is null then 1
    when upper(p_quote_code::text) = upper(p_base_code::text) then 1
    else coalesce((
      select r.rate
        from public.fx_rates r
       where r.quote_code = upper(p_quote_code::text)
         and r.base_code = upper(p_base_code::text)
         and r.rate_date <= coalesce(p_on_date, current_date)
       order by r.rate_date desc
       limit 1
    ), 1)
  end
$$;

comment on function public.fx_rate(char(3), char(3), date) is
  'Rate to convert p_quote_code into p_base_code on p_on_date. Returns 1 when '
  'the currencies match or no rate has been published.';

-- Convert an amount from a quote currency into the company base currency.
create or replace function public.fx_to_base(
  p_amount     numeric,
  p_quote_code char(3),
  p_base_code  char(3),
  p_on_date    date default current_date
) returns numeric
language sql immutable
as $$
  select coalesce(p_amount, 0) * public.fx_rate(p_quote_code, p_base_code, p_on_date)
$$;

comment on function public.fx_to_base(numeric, char(3), char(3), date) is
  'Convert p_amount from p_quote_code into p_base_code using the rate in force '
  'on p_on_date. Used by reporting views for amounts that carry a currency but '
  'no stored rate.';

-- ---------------------------------------------------------------------------
-- expenses : general company expenses
-- ---------------------------------------------------------------------------
create type public.expense_category as enum
  ('fuel','transport','office_supplies','rent','utilities','repairs','marketing',
   'salaries','shipping','government_fees','professional_fees','insurance',
   'telecommunications','maintenance','security','travel','entertainment',
   'donations','tax','other');

create table public.expenses (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique,
  expense_date     date not null,
  department_id    uuid references public.departments(id) on delete set null,
  business_unit_id uuid references public.business_units(id) on delete set null,
  branch_id        uuid references public.branches(id) on delete set null,
  category         public.expense_category not null,
  description      text not null,
  amount           numeric(18,4) not null check (amount > 0),
  currency         char(3) not null,
  exchange_rate    numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  vendor_id        uuid references public.suppliers(id) on delete set null,
  vendor_name      text,
  payment_method   public.payment_method not null default 'bank_transfer',
  paid_from_account text,
  receipt_path     text,
  requested_by     uuid references public.users(id) on delete set null,  -- the employee who needs it
  recorded_by      uuid not null references public.users(id) on delete restrict,
  approved_by      uuid references public.users(id) on delete set null,
  approved_at      timestamptz,
  status           public.record_status not null default 'draft',
  approval_id      uuid references public.approvals(id) on delete set null,
  notes            text,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create index expenses_date_idx   on public.expenses (expense_date desc) where deleted_at is null;
create index expenses_unit_idx   on public.expenses (business_unit_id) where deleted_at is null;
create index expenses_dept_idx   on public.expenses (department_id) where deleted_at is null;
create index expenses_category_idx on public.expenses (category) where deleted_at is null;
create index expenses_status_idx on public.expenses (status) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- income : company income records
-- ---------------------------------------------------------------------------
create type public.income_source as enum
  ('vehicle_sale','property_sale','agriculture','mining','rental','dividend',
   'interest','service_fee','commission','logistics','trading','other');

create table public.income (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique,
  income_date      date not null,
  business_unit_id uuid references public.business_units(id) on delete set null,
  department_id    uuid references public.departments(id) on delete set null,
  source           public.income_source not null,
  description      text not null,
  customer_id      uuid references public.customers(id) on delete set null,
  customer_name    text,
  amount           numeric(18,4) not null check (amount > 0),
  currency         char(3) not null,
  exchange_rate    numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  payment_method   public.payment_method not null default 'bank_transfer',
  payment_reference text,
  received_in_account text,
  supporting_document_path text,
  recorded_by      uuid not null references public.users(id) on delete restrict,
  approved_by      uuid references public.users(id) on delete set null,
  approved_at      timestamptz,
  status           public.record_status not null default 'draft',
  approval_id      uuid references public.approvals(id) on delete set null,
  notes            text,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create index income_date_idx on public.income (income_date desc) where deleted_at is null;
create index income_unit_idx on public.income (business_unit_id) where deleted_at is null;
create index income_source_idx on public.income (source) where deleted_at is null;
create index income_status_idx on public.income (status) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- financial_transactions : the double-entry-lite ledger.
-- Every posted money movement lands here exactly once, tagged with its origin,
-- so the income/expense screens and the bank reconciliation are the same data.
-- ---------------------------------------------------------------------------
create type public.transaction_direction as enum ('in','out');
create type public.transaction_category as enum
  ('operating','investing','financing','payroll','tax','loan','capital','other');

create table public.financial_transactions (
  id                uuid primary key default gen_random_uuid(),
  reference         text not null unique,
  transaction_date  date not null,
  direction         public.transaction_direction not null,
  category          public.transaction_category not null default 'operating',
  business_unit_id  uuid references public.business_units(id) on delete set null,
  department_id     uuid references public.departments(id) on delete set null,
  description       text not null,
  amount            numeric(18,4) not null check (amount > 0),
  currency          char(3) not null,
  exchange_rate     numeric(18,8) check (exchange_rate is null or exchange_rate > 0),
  payment_method    public.payment_method,
  counterparty      text,
  counterparty_account text,
  bank_account      text,
  source_type       text,                 -- 'expense' | 'income' | 'vehicle_sale' …
  source_id         uuid,
  status            public.record_status not null default 'approved',
  posted_by         uuid references public.users(id) on delete set null,
  posted_at         timestamptz,
  approved_by       uuid references public.users(id) on delete set null,
  attachment_path   text,
  notes             text,
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

-- One ledger entry per originating record, whichever screen created it.
create unique index financial_transactions_source_idx
  on public.financial_transactions (source_type, source_id)
  where source_type is not null and deleted_at is null;

create index financial_tx_date_idx on public.financial_transactions (transaction_date desc)
  where deleted_at is null;
create index financial_tx_unit_idx on public.financial_transactions (business_unit_id)
  where deleted_at is null;

-- ---------------------------------------------------------------------------
-- financial_periods : closes a period so history cannot be silently edited.
-- ---------------------------------------------------------------------------
create table public.financial_periods (
  id            uuid primary key default gen_random_uuid(),
  period_start  date not null,
  period_end    date not null,
  label         text not null,
  is_closed     boolean not null default false,
  closed_by     uuid references public.users(id) on delete set null,
  closed_at     timestamptz,
  unique (period_start, period_end),
  constraint financial_periods_range_ck check (period_end >= period_start)
);

-- ---------------------------------------------------------------------------
-- budgets : per business unit / department, per period
-- ---------------------------------------------------------------------------
create table public.budgets (
  id               uuid primary key default gen_random_uuid(),
  label            text not null,
  period_start     date not null,
  period_end       date not null,
  business_unit_id uuid references public.business_units(id) on delete cascade,
  department_id    uuid references public.departments(id) on delete cascade,
  category         public.expense_category,
  budgeted_amount  numeric(18,4) not null check (budgeted_amount >= 0),
  currency         char(3) not null,
  notes            text,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
