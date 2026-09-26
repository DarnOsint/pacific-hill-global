-- =============================================================================
-- seed/003_reference_data.sql
-- Reference data every installation needs: currencies, departments, business
-- units, branches. This is deliberately modest — the Director adds the rest
-- through the admin UI, and the schema supports it without a code change.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Currencies
-- ---------------------------------------------------------------------------
insert into public.currencies (code, name, symbol, minor_unit, is_base, is_active, sort_order) values
('USD', 'United States Dollar', '$',   2, true,  true, 10),
('SSP', 'South Sudanese Pound', 'SSP', 2, false, true, 20),
('EUR', 'Euro',                '€',   2, false, true, 30),
('KES', 'Kenyan Shilling',     'KSh', 2, false, true, 40),
('UGX', 'Ugandan Shilling',    'USh', 0, false, true, 50),
('NGN', 'Nigerian Naira',      '₦',   2, false, true, 60),
('ZAR', 'South African Rand',  'R',   2, false, true, 70),
('AED', 'UAE Dirham',          'AED', 2, false, true, 80),
('CNY', 'Chinese Yuan',        '¥',   2, false, true, 90),
('JPY', 'Japanese Yen',        '¥',   0, false, true, 100),
('GBP', 'Pound Sterling',      '£',   2, false, true, 110)
on conflict (code) do update
   set name = excluded.name, symbol = excluded.symbol, is_active = true;

-- ---------------------------------------------------------------------------
-- Departments
-- ---------------------------------------------------------------------------
insert into public.departments (code, name, description, sort_order) values
('MGT',  'Management',        'Executive leadership and company-wide governance', 10),
('ADMIN','Administration',    'Office administration, records and front desk',     20),
('FIN',  'Finance',           'Accounting, treasury, payroll and reporting',       30),
('SALES','Sales',             'Vehicle and property sales, client relationships',    40),
('AUTO', 'Automobile',        'Vehicle sourcing, logistics, preparation, retail',   50),
('RE',   'Real Estate',       'Property acquisition, development and sales',       60),
('AGRI', 'Agriculture',       'Farming operations and agronomy',                   70),
('MIN',  'Mining',            'Exploration, licensing and production',             80),
('OPS',  'Operations',        'Logistics, freight forwarding and import/export',   90),
('HR',   'Human Resources',   'People operations, recruitment and welfare',         100),
('IT',   'Information Technology', 'Platform, systems and data',                 110)
on conflict (code) do update
   set name = excluded.name, description = excluded.description, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Business units — the diversification backbone.
-- Adding a sector (Energy, Forestry, Manufacturing) is an INSERT into this
-- table, not a code change.
-- ---------------------------------------------------------------------------
insert into public.business_units
  (code, slug, name, short_name, tagline, summary, icon, accent_color, sort_order, show_metrics) values
('AUTO', 'automobiles', 'Automobile & Vehicle Trading',
 'Automobiles', 'Sourcing, preparing and delivering quality vehicles across borders',
 'We source, prepare and deliver vehicles from verified international suppliers, managing every stage from purchase and freight to clearing, presentation and sale.',
 'car', '#1D4ED8', 10, true),

('RE', 'real-estate', 'Real Estate & Land',
 'Real Estate', 'Land, property and development investments',
 'From residential land and family homes to commercial and development sites, we acquire, manage and sell property backed by clear documentation and secure title.',
 'building-2', '#0F766E', 20, true),

('AGRI', 'agriculture', 'Agriculture & Food Production',
 'Agriculture', 'Modern farming from field to market',
 'We operate farm projects across our network, managing inputs, labour, harvest and offtake with an emphasis on yield, quality and reliable supply to buyers.',
 'sprout', '#15803D', 30, true),

('MIN', 'mining', 'Mining & Natural Resources',
 'Mining', 'Responsible resource development',
 'We pursue mineral projects with proper licensing, transparent ownership and a long-term view of the communities and regions in which we operate.',
 'pickaxe', '#7C2D12', 40, true),

('LOG', 'logistics', 'Logistics & Freight Forwarding',
 'Logistics', 'Moving cargo reliably across borders and regions',
 'Sea, road and air freight, customs clearance and in-land delivery, coordinated so that importers and exporters can plan with confidence.',
 'truck', '#1E40AF', 50, true),

('TRD', 'general-trading', 'Importation & General Trading',
 'General Trading', 'Importing and distributing everyday essentials',
 'We import and distribute essential goods, maintaining supply relationships and managing the documentation, customs and delivery chain end to end.',
 'package', '#4338CA', 60, true)
on conflict (code) do update
   set name = excluded.name, short_name = excluded.short_name, tagline = excluded.tagline,
       summary = excluded.summary, icon = excluded.icon, accent_color = excluded.accent_color,
       sort_order = excluded.sort_order;

update public.business_units set description = summary, is_active = true, public_visible = true
 where description is null;

-- Give every unit a longer description (used on its public sector page).
update public.business_units set description =
  'Pacific Hill Global operates a full ' || lower(name) || ' practice. ' || summary
 where description is null or description = summary;

-- ---------------------------------------------------------------------------
-- Branches
-- ---------------------------------------------------------------------------
insert into public.branches (code, name, business_unit_id, country, city, address_line1, phone, is_head_office, is_public) values
('HQ', 'Head Office', null, 'South Sudan', 'Juba', 'Central Business District, Juba', '+211 000 000 000', true, true)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Company settings (single row)
-- ---------------------------------------------------------------------------
insert into public.company_settings
  (company_name, legal_name, tagline, description, founded_year,
   base_currency, email, phone, whatsapp, address, city, country)
select
  'Pacific Hill Global',
  'Pacific Hill Global',
  'Diversified business. Enduring value.',
  'Pacific Hill Global is a diversified business group operating across automobile trading, real estate and land, agriculture, mining, logistics and freight forwarding, and importation and general trading.',
  2015,
  'USD',
  'info@pacifichillglobal.com',
  '+211 000 000 000',
  '+211 000 000 000',
  'Central Business District, Juba',
  'Juba',
  'South Sudan'
where not exists (select 1 from public.company_settings);

-- ---------------------------------------------------------------------------
-- Approval rules — thresholds live here, not in code.
-- ---------------------------------------------------------------------------
insert into public.approval_rules
  (code, name, description, action_key, threshold_amount, threshold_currency, required_permission, required_level)
values
('EXP_LARGE',  'Large expense approval',      'Expenses above the threshold require Finance approval',        'expense.create',   5000,  'USD', 'finance.approve', 1),
('EXP_CRIT',   'Critical expense approval',   'Very large expenses require Director approval',                'expense.create',  25000,  'USD', 'settings.manage', 2),
('VEH_PURCH',  'Vehicle purchase approval',   'New vehicle acquisitions require Finance sign-off',           'vehicle.create',  15000,  'USD', 'finance.approve', 1),
('VEH_SALE',   'Vehicle sale approval',       'Vehicle sales below margin floor require Director approval',  'vehicle.sale',      0,  'USD', 'settings.manage', 2),
('PROP_SALE',  'Property sale approval',      'Property sales require Finance sign-off',                     'property.sale',    0,  'USD', 'finance.approve', 1),
('WEB_PUB',    'Website publication',         'Publishing to the public site is a controlled action',          'website.publish',   0,  'USD', 'website.publish', 1)
on conflict (code) do update
   set name = excluded.name, threshold_amount = excluded.threshold_amount,
       required_permission = excluded.required_permission, is_active = true;
