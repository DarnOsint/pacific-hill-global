-- =============================================================================
-- seed/002_roles.sql
-- Initial role catalogue. Roles are DATA. Adding a role does not require a
-- code change, a migration, or a deploy.
--
-- Scope note: a role's `scope_type` is the *default* scope applied when a user
-- is granted it without an explicit scope. A user's effective reach is the union
-- of every grant they hold.
-- ============================================================================

insert into public.roles (slug, name, description, scope_type, is_system, sort_order) values
('director',              'Director',                'Principal executive. Full authority across every business unit, including publishing and system configuration.', 'global',       true, 10),
('general_manager',       'General Manager',         'Runs day-to-day operations across all units. Full operational and financial access; cannot change the permission catalogue.', 'global',     true, 20),
('department_manager',    'Department Manager',      'Manages one department: its records, its team tasks and its internal notices.', 'department',  true, 30),
('business_unit_manager', 'Business Unit Manager',   'Manages the records and team of a single business unit.', 'business_unit', true, 35),
('sales_person',          'Sales Person',            'Sells vehicles and properties. Sees assigned stock, customers and their own commissions.', 'business_unit', true, 40),
('receptionist',          'Receptionist',            'Front desk: visitors, enquiries, appointments, switchboard. No financial access.', 'global', true, 50),
('finance_officer',       'Finance Officer',         'Records and approves income and expenses, maintains currencies, exports financial reports.', 'global',       true, 60),
('administrative_officer','Administrative Officer',  'HR and office administration: employee records, customers, suppliers, documents. No financial access.', 'global', true, 70),
('hr_officer',            'HR / Personnel Officer',  'Owns the employee lifecycle including sensitive HR records and employee documents.', 'global',       true, 80),
('operations_officer',    'Operations Officer',      'Runs logistics, freight and trading operations for a business unit.', 'business_unit', true, 90),
('employee',              'Employee',                'Standard employee: directory, own profile, messages, groups, own tasks and notices.', 'global', true, 100)
on conflict (slug) do update
   set name        = excluded.name,
       description = excluded.description,
       scope_type  = excluded.scope_type,
       is_system   = true,
       is_active   = true;

-- ---------------------------------------------------------------------------
-- Permission bundles
-- ---------------------------------------------------------------------------
-- Director: every permission in the catalogue. This is asserted by
-- src/lib/rbac tests (docs/RBAC.md §8) and is the only role that must.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r cross join public.permissions p
 where r.slug = 'director'
on conflict do nothing;

-- General Manager: everything except the identity/access control plane.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'general_manager'
   and p.key not in ('permissions.manage', 'roles.manage', 'settings.manage', 'employees.delete')
on conflict do nothing;

-- Department Manager: their department's business records and their team.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'department_manager'
   and p.key in (
     -- org
     'org.view','employees.view',
     -- website
     'website.view','website.edit','website.publish',
     -- vehicles
     'vehicles.view','vehicles.create','vehicles.edit',
     'vehicle_expenses.view','vehicle_expenses.create','vehicle_expenses.edit',
     'vehicle_repairs.view','vehicle_repairs.manage',
     'vehicle_shipping.view','vehicle_shipping.manage',
     'vehicle_sales.view','vehicle_sales.create','vehicle_sales.edit',
     'vehicle_finance.view',
     -- real estate
     'properties.view','properties.create','properties.edit',
     'property_sales.view','property_sales.create','property_sales.edit','properties.publish',
     -- agriculture
     'agriculture.view','agriculture.create','agriculture.edit','agriculture.financials',
     -- mining
     'mining.view','mining.create','mining.edit','mining.financials',
     -- finance (scoped read + expense capture)
     'finance.view','finance.create_expense',
     -- comms
     'messages.send','messages.view_own','messages.moderate',
     'group_chats.view','group_chats.create','group_chats.manage','group_chats.post',
     'announcements.view','announcements.create','announcements.publish',
     -- tasks
     'tasks.view_own','tasks.view_department','tasks.view_all',
     'tasks.create','tasks.assign','tasks.update_any',
     -- documents
     'documents.view','documents.upload',
     -- sales
     'leads.view','leads.assign','leads.manage','sales.create','sales.view_team',
     -- reports
     'reports.view','reports.export','reports.view_financial',
     -- activity
     'activity.view_department','activity.view_unit'
   )
on conflict do nothing;

-- Business Unit Manager: a single unit, end to end.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'business_unit_manager'
   and p.key in (
     'org.view','employees.view','website.view',
     'vehicles.view','vehicles.create','vehicles.edit',
     'vehicle_expenses.view','vehicle_expenses.create','vehicle_expenses.edit',
     'vehicle_repairs.view','vehicle_repairs.manage',
     'vehicle_shipping.view','vehicle_shipping.manage',
     'vehicle_sales.view','vehicle_sales.create','vehicle_sales.edit',
     'vehicle_finance.view',
     'properties.view','properties.create','properties.edit',
     'property_sales.view','property_sales.create','property_sales.edit','properties.publish',
     'agriculture.view','agriculture.create','agriculture.edit','agriculture.financials',
     'mining.view','mining.create','mining.edit','mining.financials',
     'finance.view','finance.create_expense',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.create','group_chats.manage','group_chats.post',
     'announcements.view','announcements.create',
     'tasks.view_own','tasks.view_department','tasks.create','tasks.assign','tasks.update_any',
     'documents.view','documents.upload',
     'leads.view','leads.assign','sales.create','sales.view_team',
     'reports.view','reports.export',
     'activity.view_unit','activity.view_department'
   )
on conflict do nothing;

-- Sales Person: sees stock and property, records sales, owns their pipeline.
-- Explicitly NO finance, NO employee sensitive data, NO publishing.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'sales_person'
   and p.key in (
     'org.view',
     'vehicles.view',
     'vehicle_sales.view','vehicle_sales.create','vehicle_sales.edit',
     'properties.view',
     'property_sales.view','property_sales.create','property_sales.edit',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.post',
     'announcements.view',
     'tasks.view_own','tasks.create','tasks.update_any',
     'documents.view',
     'leads.view','sales.create',
     'reports.view',
     'activity.view_unit'
   )
on conflict do nothing;

-- Receptionist: front desk. No financial permission of any kind.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'receptionist'
   and p.key in (
     'org.view','employees.view','employees.edit_self',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.post',
     'announcements.view',
     'tasks.view_own','tasks.create','tasks.update_any',
     'leads.view','leads.assign',
     'documents.view','documents.upload',
     'reports.view'
   )
on conflict do nothing;

-- Finance Officer: the money role.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'finance_officer'
   and p.key in (
     'org.view','employees.view',
     'finance.view','finance.view_all',
     'finance.create_income','finance.create_expense',
     'finance.edit','finance.delete','finance.approve',
     'finance.manage_currencies','finance.manage_budgets',
     'finance.manage_settings','finance.close_period','finance.reports.export',
     'vehicles.view','vehicle_expenses.view','vehicle_expenses.create',
     'vehicle_expenses.edit','vehicle_expenses.delete','vehicle_finance.view',
     'vehicle_sales.view',
     'properties.view','property_sales.view',
     'agriculture.view','agriculture.financials',
     'mining.view','mining.financials',
     'org.manage_suppliers',
     'documents.view','documents.upload','documents.view_sensitive',
     'reports.view','reports.export','reports.view_financial',
     'website.view',
     'messages.send','messages.view_own','group_chats.view','group_chats.post',
     'announcements.view',
     'tasks.view_own','tasks.create','tasks.update_any',
     'activity.view_all'
   )
on conflict do nothing;

-- Administrative Officer: HR support and office administration, no money.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'administrative_officer'
   and p.key in (
     'org.view','org.manage_customers','org.manage_suppliers',
     'employees.view','employees.create','employees.edit','employees.edit_self',
     'leads.view','leads.manage','leads.assign',
     'website.view',
     'vehicles.view','properties.view',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.create','group_chats.post','group_chats.manage',
     'announcements.view','announcements.create',
     'tasks.view_own','tasks.view_department','tasks.create','tasks.assign','tasks.update_any',
     'documents.view','documents.upload','documents.delete',
     'reports.view',
     'activity.view_department'
   )
on conflict do nothing;

-- HR Officer: the only role besides the Director with sensitive HR access.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'hr_officer'
   and p.key in (
     'org.view','org.manage_departments','org.manage_branches',
     'employees.view','employees.view_sensitive','employees.create','employees.edit',
     'employees.edit_self','employees.disable',
     'documents.view','documents.upload','documents.delete','documents.view_sensitive',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.create','group_chats.manage','group_chats.post',
     'announcements.view','announcements.create','announcements.publish',
     'tasks.view_own','tasks.view_department','tasks.create','tasks.assign','tasks.update_any',
     'reports.view',
     'activity.view_department','activity.view_all'
   )
on conflict do nothing;

-- Operations Officer: logistics and trading execution.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'operations_officer'
   and p.key in (
     'org.view','employees.view','org.manage_customers','org.manage_suppliers',
     'vehicles.view','vehicle_shipping.view','vehicle_shipping.manage',
     'vehicle_repairs.view','vehicle_repairs.manage',
     'properties.view',
     'agriculture.view','agriculture.edit',
     'mining.view','mining.edit',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.post',
     'announcements.view',
     'tasks.view_own','tasks.view_department','tasks.create','tasks.assign','tasks.update_any',
     'documents.view','documents.upload',
     'leads.view','leads.assign',
     'reports.view',
     'activity.view_unit','activity.view_department'
   )
on conflict do nothing;

-- Employee: the floor.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.slug = 'employee'
   and p.key in (
     'employees.edit_self','org.view',
     'messages.send','messages.view_own',
     'group_chats.view','group_chats.post',
     'announcements.view',
     'tasks.view_own','tasks.create','tasks.update_any',
     'documents.view'
   )
on conflict do nothing;
