-- =============================================================================
-- 0013_views.sql
-- Reporting views. These are the single source of truth for every total,
-- roll-up and profitability figure shown in the product and in exports.
--
-- The base currency is read from company_settings (never hardcoded), so
-- changing it in settings changes every report.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- vehicle_financials : the profitability model.
--
--   total_acquisition_cost = purchase price (in base)
--                          + every itemised expense (in base)
--   gross_profit          = sale price (in base) - total_acquisition_cost
--
-- Exchange rate semantics: a record's own `exchange_rate` is
-- "1 unit of record currency = N base currency". If absent, the rate is 1,
-- which is correct only when record currency == base currency; the service
-- layer always writes an explicit rate for a cross-currency purchase.
-- ---------------------------------------------------------------------------
create or replace view public.vehicle_financials
as
with cfg as (
  select coalesce(
    (select base_currency from public.company_settings
      order by created_at limit 1),
    'USD')::char(3) as base_currency
),
expense_rollup as (
  select e.vehicle_id,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1)), 0)::numeric(18,4) as expenses_base,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1))
                  filter (where e.category = 'shipping'), 0)::numeric(18,4)        as shipping_base,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1))
                  filter (where e.category in ('clearing', 'customs_duty',
                                               'port_charges')), 0)::numeric(18,4) as clearing_base,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1))
                  filter (where e.category in ('repair', 'parts')), 0)::numeric(18,4) as repair_parts_base,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1))
                  filter (where e.category = 'transportation'), 0)::numeric(18,4)   as transport_base,
         coalesce(sum(e.amount * coalesce(e.exchange_rate, 1))
                  filter (where e.category not in ('shipping','clearing','customs_duty',
                     'port_charges','repair','parts','transportation')), 0)::numeric(18,4) as other_base,
         coalesce(count(*), 0)::int as expense_count
    from public.vehicle_expenses e
   where e.deleted_at is null
   group by e.vehicle_id
),
live_sale as (
  select distinct on (s.vehicle_id)
         s.vehicle_id, s.id, s.sale_price, s.sale_currency, s.exchange_rate,
         s.expected_sale_price, s.expected_sale_currency,
         s.commission_rate, s.deposit_amount,
         s.status, s.sale_date, s.buyer_name, s.sales_person_id, s.discount_amount
    from public.vehicle_sales s
   where s.deleted_at is null
     and s.status not in ('cancelled', 'refunded')
   order by s.vehicle_id, s.created_at desc
)
select
  v.id                                                   as vehicle_id,
  v.stock_number,
  v.make,
  v.model,
  v.model_year,
  v.chassis_number,
  v.status,
  v.purchase_date,
  v.purchase_price,
  v.purchase_currency,
  v.assigned_sales_person_id,
  v.business_unit_id,
  v.is_public,
  (select base_currency from cfg)                  as base_currency,

  -- acquisition ------------------------------------------------------------
  round(v.purchase_price * coalesce(v.exchange_rate, 1), 4)          as purchase_base,
  coalesce(er.expenses_base, 0)                                       as expenses_base,
  coalesce(er.shipping_base, 0)                                       as shipping_base,
  coalesce(er.clearing_base, 0)                                       as clearing_base,
  coalesce(er.repair_parts_base, 0)                                   as repair_parts_base,
  coalesce(er.transport_base, 0)                                      as transport_base,
  coalesce(er.other_base, 0)                                          as other_base,
  coalesce(er.expense_count, 0)                                       as expense_count,
  round(v.purchase_price * coalesce(v.exchange_rate, 1)
        + coalesce(er.expenses_base, 0), 4)                            as total_acquisition_base,

  -- sale ------------------------------------------------------------------
  ls.id                            as sale_id,
  ls.status                        as sale_status,
  ls.sale_date,
  ls.buyer_name,
  ls.sales_person_id,
  round(ls.sale_price * coalesce(ls.exchange_rate, 1), 4)             as sale_base,
  ls.expected_sale_price           as expected_sale_price,
  round(coalesce(ls.expected_sale_price, 0) * coalesce(ls.exchange_rate, 1), 4)
                                                           as expected_sale_base,

  -- profit ----------------------------------------------------------------
  round(coalesce(ls.sale_price * coalesce(ls.exchange_rate, 1), 0)
        - (v.purchase_price * coalesce(v.exchange_rate, 1)
           + coalesce(er.expenses_base, 0)), 4)                        as gross_profit_base,
  round(coalesce(ls.expected_sale_price * coalesce(ls.exchange_rate, 0), 0)
        - (v.purchase_price * coalesce(v.exchange_rate, 1)
           + coalesce(er.expenses_base, 0)), 4)                        as expected_gross_profit_base,
  case
    when ls.id is null then null
    when ls.sale_price * coalesce(ls.exchange_rate, 1) = 0 then 0
    else round(
      ((ls.sale_price * coalesce(ls.exchange_rate, 1)
        - (v.purchase_price * coalesce(v.exchange_rate, 1)
           + coalesce(er.expenses_base, 0)))
       / nullif(ls.sale_price * coalesce(ls.exchange_rate, 1), 0)) * 100, 2)
  end                                                                 as margin_percent,

  -- inventory value of unsold stock
  case when ls.id is null or ls.status not in ('sold','deposit_paid')
       then round(v.purchase_price * coalesce(v.exchange_rate, 1)
                  + coalesce(er.expenses_base, 0), 4)
       else 0 end                                                    as inventory_value_base,

  round(coalesce(ls.sale_price * coalesce(ls.exchange_rate, 1), 0)
        - coalesce(ls.discount_amount * coalesce(ls.exchange_rate, 1), 0), 4) as net_sale_base

from public.vehicles v
left join expense_rollup er on er.vehicle_id = v.id
left join live_sale       ls on ls.vehicle_id = v.id
where v.deleted_at is null;

comment on view public.vehicle_financials is
  'Authoritative vehicle profitability. All *_base columns are in '
  'company_settings.base_currency. Never recompute these in application code.';

-- ---------------------------------------------------------------------------
-- vehicle_summary : company-level automobile KPIs
-- ---------------------------------------------------------------------------
create or replace view public.vehicle_summary
as
with s as (select * from public.vehicle_financials)
select
  count(*)                                                       as total_vehicles,
  count(*) filter (where status = 'sold')                        as sold_vehicles,
  count(*) filter (where status in ('purchased','in_transit','arrived',
                                    'under_repair','ready_for_sale','reserved'))::int
                                                                  as in_stock_vehicles,
  count(*) filter (where status = 'ready_for_sale')              as ready_for_sale,
  count(*) filter (where status = 'reserved')                    as reserved_vehicles,
  coalesce(sum(total_acquisition_base), 0)                       as total_acquisition,
  coalesce(sum(expenses_base), 0)                                as total_expenses,
  coalesce(sum(shipping_base), 0)                                as total_shipping,
  coalesce(sum(repair_parts_base), 0)                            as total_repairs,
  coalesce(sum(sale_base) filter (where sale_status = 'sold'), 0) as total_revenue,
  coalesce(sum(gross_profit_base) filter (where sale_status = 'sold'), 0) as total_gross_profit,
  coalesce(sum(inventory_value_base), 0)                         as inventory_value,
  round(coalesce(avg(gross_profit_base) filter (where sale_status = 'sold'), 0), 2)
                                                                  as average_profit_per_vehicle,
  round(coalesce(avg(margin_percent) filter (where sale_status = 'sold'), 0), 2)
                                                                  as average_margin_percent
from s;

-- ---------------------------------------------------------------------------
-- property_financials
-- ---------------------------------------------------------------------------
create or replace view public.property_financials
as
with cfg as (
  select coalesce((select base_currency from public.company_settings
                    order by created_at limit 1), 'USD')::char(3) as base_currency
),
live_sale as (
  select distinct on (s.property_id)
         s.property_id, s.id, s.sale_price, s.currency, s.exchange_rate,
         s.status, s.sale_date, s.buyer_name, s.sales_person_id, s.discount_amount
    from public.property_sales s
   where s.deleted_at is null and s.status not in ('cancelled','refunded')
   order by s.property_id, s.created_at desc
)
select
  p.id                        as property_id,
  p.code,
  p.title,
  p.property_type,
  p.status,
  p.country,
  p.city,
  p.size_value,
  p.size_unit,
  p.price,
  p.currency,
  p.business_unit_id,
  p.assigned_sales_person_id,
  p.listed_at,
  p.is_public,
  (select base_currency from cfg)                               as base_currency,
  -- The asking price carries a currency but no stored rate: it is converted at
  -- the rate in force, not treated as 1:1 with the base currency.
  public.fx_to_base(p.price, p.currency,
                    (select base_currency from cfg), p.created_at::date) as ask_base,
  ls.id                      as sale_id,
  ls.status                  as sale_status,
  ls.sale_date,
  ls.buyer_name,
  -- A completed sale carries the rate that was agreed at the time, so that row
  -- is authoritative and must not be re-converted at today's rate.
  round(coalesce(ls.sale_price * coalesce(ls.exchange_rate, 1), 0), 4)  as sale_base,
  round(coalesce(ls.sale_price * coalesce(ls.exchange_rate, 1), 0)
        - public.fx_to_base(p.price, p.currency,
                            (select base_currency from cfg), p.created_at::date), 4)
                                                                 as gross_profit_base,
  case when ls.id is null or ls.status <> 'sold'
       then public.fx_to_base(p.price, p.currency,
                              (select base_currency from cfg), p.created_at::date)
       else 0 end                                                as inventory_value_base
from public.real_estate_properties p
left join live_sale ls on ls.property_id = p.id
where p.deleted_at is null;

-- ---------------------------------------------------------------------------
-- project profitability: agriculture and mining share one shape
-- ---------------------------------------------------------------------------
create or replace view public.agriculture_financials
as
with cfg as (
  select coalesce((select base_currency from public.company_settings
                    order by created_at limit 1), 'USD')::char(3) as base_currency
),
c as (
  select cost.project_id,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1)), 0)::numeric(18,4) as total_cost,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1))
                  filter (where cost.category = 'labour'), 0)::numeric(18,4)      as labour_cost,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1))
                  filter (where cost.category in ('seeds','seedlings','fertiliser',
                     'pesticides','herbicides')), 0)::numeric(18,4)            as input_cost,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1))
                  filter (where cost.category in ('machinery','equipment','equipment',
                     'fuel')), 0)::numeric(18,4)                               as equipment_cost
    from public.agricultural_costs cost
   where cost.deleted_at is null
   group by cost.project_id
),
h as (
  select h.project_id,
         -- A harvest records a currency but no agreed rate, so it is converted
         -- at the rate in force on the harvest date. The previous expression
         -- here was `total_value * (select 1)`, which treated every currency as
         -- 1:1 with the base and understated non-USD projects.
         coalesce(sum(public.fx_to_base(h.total_value, h.currency,
                                        (select base_currency from cfg),
                                        h.harvest_date)), 0)::numeric(18,4) as realised_revenue,
         coalesce(sum(h.quantity), 0)::numeric(14,2) as total_quantity
    from public.agricultural_harvests h
   where h.deleted_at is null
   group by h.project_id
)
select p.id as project_id, p.code, p.name, p.crop, p.status, p.country,
       p.land_size_value, p.land_size_unit, p.start_date, p.actual_harvest_date,
       p.business_unit_id, p.project_manager_id, p.is_public,
       coalesce(c.total_cost, 0)                    as total_cost,
       coalesce(c.input_cost, 0)                    as input_cost,
       coalesce(c.labour_cost, 0)                   as labour_cost,
       coalesce(c.equipment_cost, 0)                as equipment_cost,
       coalesce(h.realised_revenue, 0)              as realised_revenue,
       coalesce(h.total_quantity, 0)                as total_quantity,
       round(coalesce(p.actual_revenue, 0) - coalesce(c.total_cost, 0), 4) as projected_profit,
       round(coalesce(h.realised_revenue, 0) - coalesce(c.total_cost, 0), 4) as realised_profit
  from public.agricultural_projects p
  left join c on c.project_id = p.id
  left join h on h.project_id = p.id
  where p.deleted_at is null;

create or replace view public.mining_financials
as
with cfg as (
  select coalesce((select base_currency from public.company_settings
                    order by created_at limit 1), 'USD')::char(3) as base_currency
),
c as (
  select cost.project_id,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1)), 0)::numeric(18,4) as total_cost,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1))
                  filter (where cost.category in ('licensing','permits','royalties','taxes')),
                  0)::numeric(18,4)                                             as licensing_cost,
         coalesce(sum(cost.amount * coalesce(cost.exchange_rate, 1))
                  filter (where cost.category in ('equipment','equipment_hire')), 0)::numeric(18,4) as equipment_cost
    from public.mining_costs cost
   where cost.deleted_at is null
   group by cost.project_id
),
pr as (
  select production.project_id,
         coalesce(sum(production.quantity), 0)::numeric(14,2) as total_production
    from public.mining_production production
   where production.deleted_at is null
   group by production.project_id
),
s as (
  select sale.project_id,
         -- Converted at the rate in force on the sale date: mining_sales records
         -- a currency but no agreed rate, so assuming 1:1 would understate
         -- revenue for every project that is not denominated in the base.
         coalesce(sum(public.fx_to_base(sale.total_value, sale.currency,
                                        (select base_currency from cfg),
                                        sale.sale_date)), 0)::numeric(18,4) as revenue,
         coalesce(sum(sale.quantity), 0)::numeric(14,2) as sold_quantity
    from public.mining_sales sale
   where sale.deleted_at is null and sale.status <> 'cancelled'
   group by sale.project_id
)
select p.id as project_id, p.code, p.name, p.mineral, p.license_number, p.license_status,
       p.status, p.country, p.start_date, p.business_unit_id, p.project_manager_id,
       p.is_public,
       coalesce(c.total_cost, 0)          as total_cost,
       coalesce(c.licensing_cost, 0)      as licensing_cost,
       coalesce(c.equipment_cost, 0)      as equipment_cost,
       coalesce(pr.total_production, 0)   as total_production,
       coalesce(s.revenue, 0)             as revenue,
       coalesce(s.sold_quantity, 0)       as sold_quantity,
       round(coalesce(s.revenue, 0) - coalesce(c.total_cost, 0), 4) as profit
  from public.mining_projects p
  left join c  on c.project_id  = p.id
  left join pr on pr.project_id = p.id
  left join s  on s.project_id  = p.id
  where p.deleted_at is null;

-- ---------------------------------------------------------------------------
-- finance_summary : company-wide P&L inputs, base currency
-- ---------------------------------------------------------------------------
create or replace view public.finance_summary
as
with cfg as (
  select coalesce((select base_currency from public.company_settings
                    order by created_at limit 1), 'USD')::char(3) as base_currency
),
inc as (
  select business_unit_id, department_id,
         coalesce(sum(amount * coalesce(exchange_rate, 1)), 0)::numeric(18,4) as amount
    from public.income
   where deleted_at is null and status in ('approved','posted')
   group by business_unit_id, department_id
),
exp as (
  select business_unit_id, department_id,
         coalesce(sum(amount * coalesce(exchange_rate, 1)), 0)::numeric(18,4) as amount
    from public.expenses
   where deleted_at is null and status in ('approved','posted')
   group by business_unit_id, department_id
),
keys as (
  select business_unit_id, department_id from inc
  union
  select business_unit_id, department_id from exp
)
select k.business_unit_id, k.department_id,
       (select base_currency from cfg)                 as base_currency,
       coalesce(i.amount, 0)                                as total_income,
       coalesce(e.amount, 0)                                as total_expenses,
       round(coalesce(i.amount, 0) - coalesce(e.amount, 0), 4) as net_result
  from keys k
  left join inc i on i.business_unit_id is not distinct from k.business_unit_id
                and i.department_id    is not distinct from k.department_id
  left join exp e on e.business_unit_id is not distinct from k.business_unit_id
                and e.department_id    is not distinct from k.department_id;

-- ---------------------------------------------------------------------------
-- dashboard counters : one cheap query per dashboard card
-- ---------------------------------------------------------------------------
create or replace view public.dashboard_counters
as
select
  (select count(*) from public.tasks
    where deleted_at is null
      and assigned_to = authz.current_user_id()
      and status not in ('completed','cancelled'))::int      as my_open_tasks,
  (select count(*) from public.tasks
    where deleted_at is null and status not in ('completed','cancelled')
      and due_at is not null and due_at < now()
      and assigned_to = authz.current_user_id())::int       as my_overdue_tasks,
  -- notifications record read state with `read_at`, and an unread row is
  -- counted with count(*) rather than sum(unread_count): there is no such
  -- column, and summing a per-row counter to get a count is the kind of
  -- double-count that looks plausible in a dashboard.
  (select count(*) from public.notifications
    where recipient_id = authz.current_user_id() and read_at is null)::int
                                                            as unread_notifications,
  (select coalesce(sum(m.unread_count), 0) from public.thread_participants m
    where m.user_id = authz.current_user_id() and m.left_at is null)::int
                                                            as unread_messages,
  (select coalesce(sum(gm.unread_count), 0) from public.group_chat_members gm
    where gm.user_id = authz.current_user_id() and gm.removed_at is null)::int
                                                            as unread_group_messages,
  (select count(*) from public.approvals
    where status = 'pending' and deleted_at is null)::int    as pending_approvals,
  (select count(*) from public.announcements
    where status = 'published' and deleted_at is null
      and (expires_at is null or expires_at > now()))::int as active_announcements;
