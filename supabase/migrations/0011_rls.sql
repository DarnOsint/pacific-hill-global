-- =============================================================================
-- 0011_rls.sql
-- Row Level Security for every table.
--
-- Layers (see docs/ARCHITECTURE.md §6):
--   1. navigation  — lib/rbac/can()            (cosmetic)
--   2. server      — requirePermission()        (hard gate)
--   3. database    — these policies            (hard gate, unbypassable by app code)
--
-- Policy naming: <table>_<verb>_<scope>
-- Reads:    who can see the row at all
-- Writes:   who can create / modify / delete
-- ============================================================================

-- =============================================================================
-- PART A — IDENTITY
-- =============================================================================

alter table public.users enable row level security;
alter table public.employees enable row level security;
alter table public.departments enable row level security;
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.employee_documents enable row level security;
alter table public.user_sessions enable row level security;

-- users ---------------------------------------------------------------------
-- Self always. Others only with an employee-management permission.
create policy users_select_self on public.users
  for select using (id = authz.current_user_id());

create policy users_select_staff on public.users
  for select using (
    authz.has_any_permission(array['employees.view','employees.view_sensitive',
                                  'employees.create','employees.edit','roles.manage'])
  );

create policy users_update_self on public.users
  for update using (id = authz.current_user_id())
  with check (id = authz.current_user_id());

create policy users_update_staff on public.users
  for update using (authz.has_any_permission(array['employees.edit','roles.manage']))
  with check (authz.has_any_permission(array['employees.edit','roles.manage']));

-- No INSERT/DELETE for clients: user rows are created by the auth trigger using
-- the service role only. See 0012_triggers.sql handle_new_user().

-- employees -----------------------------------------------------------------
create policy employees_select on public.employees
  for select using (
    deleted_at is null
    and (
      user_id = authz.current_user_id()
      or authz.has_any_permission(array['employees.view','employees.view_sensitive',
                                        'employees.create','employees.edit','employees.disable'])
    )
  );

create policy employees_insert on public.employees
  for insert with check (authz.has_permission('employees.create'));

create policy employees_update_staff on public.employees
  for update using (authz.has_permission('employees.edit'))
  with check (authz.has_permission('employees.edit'));

create policy employees_update_self on public.employees
  for update using (user_id = authz.current_user_id())
  with check (user_id = authz.current_user_id());

create policy employees_delete on public.employees
  for delete using (authz.has_permission('employees.delete'));

-- departments ---------------------------------------------------------------
create policy departments_select on public.departments
  for select using (deleted_at is null and authz.has_permission('org.view'));

create policy departments_insert on public.departments
  for insert with check (authz.has_permission('org.manage_departments'));

create policy departments_update on public.departments
  for update using (authz.has_permission('org.manage_departments'))
  with check (authz.has_permission('org.manage_departments'));

create policy departments_delete on public.departments
  for delete using (authz.has_permission('org.manage_departments'));

-- permissions (catalogue) ---------------------------------------------------
create policy permissions_select on public.permissions
  for select using (authz.is_staff() or authz.has_permission('roles.view'));

-- roles ---------------------------------------------------------------------
create policy roles_select on public.roles
  for select using (is_active and authz.has_permission('roles.view'));

create policy roles_manage on public.roles
  for all using (authz.has_permission('roles.manage'))
  with check (authz.has_permission('roles.manage'));

-- role_permissions ---------------------------------------------------------
create policy role_permissions_select on public.role_permissions
  for select using (authz.has_permission('roles.view'));

create policy role_permissions_manage on public.role_permissions
  for all using (authz.has_permission('roles.manage'))
  with check (authz.has_permission('roles.manage'));

-- user_roles ----------------------------------------------------------------
-- A user may read their own assignments. Anything else needs roles.view.
create policy user_roles_select_own on public.user_roles
  for select using (user_id = authz.current_user_id());

create policy user_roles_select_admin on public.user_roles
  for select using (authz.has_any_permission(array['roles.view','roles.assign']));

create policy user_roles_manage on public.user_roles
  for all using (authz.has_permission('roles.assign'))
  with check (authz.has_permission('roles.assign'));

-- employee_documents -------------------------------------------------------
create policy employee_documents_select on public.employee_documents
  for select using (
    deleted_at is null
    and (not is_sensitive or authz.can_view_sensitive_employee()
         or authz.has_permission('documents.view_sensitive'))
  );

-- Attaching a document to an employee record.
--
-- Two separate questions, deliberately not collapsed into one:
--   1. may the caller attach documents to records at all?  documents.upload or
--      employees.edit.
--   2. may the caller attach a document flagged `is_sensitive`?  That needs
--      documents.view_sensitive or employees.view_sensitive.
--
-- The second condition is load-bearing. Without it, anyone holding the ordinary
-- `documents.upload` permission could attach a passport or tax document to a
-- record and have it treated by HR as a verified, sensitive document — turning a
-- file-upload right into a way to plant apparently-official paperwork.
create policy employee_documents_insert on public.employee_documents
  for insert with check (
    authz.has_any_permission(array['documents.upload','employees.edit'])
    and (
      not is_sensitive
      or authz.has_any_permission(
            array['documents.view_sensitive','employees.view_sensitive','employees.edit'])
    )
  );

create policy employee_documents_delete on public.employee_documents
  for delete using (authz.has_permission('documents.delete'));

-- user_sessions ------------------------------------------------------------
create policy user_sessions_select_own on public.user_sessions
  for select using (user_id = authz.current_user_id());

create policy user_sessions_delete_own on public.user_sessions
  for delete using (user_id = authz.current_user_id());

-- =============================================================================
-- PART B — ORGANISATION
-- =============================================================================

alter table public.business_units enable row level security;
alter table public.branches enable row level security;
alter table public.customers enable row level security;
alter table public.suppliers enable row level security;
alter table public.leads enable row level security;
alter table public.approval_rules enable row level security;
alter table public.approvals enable row level security;

-- business_units ------------------------------------------------------------
-- Public sees active + public_visible. Staff sees everything.
create policy business_units_public on public.business_units
  for select using (
    deleted_at is null
    and (
      (is_active and public_visible)
      or authz.has_permission('org.manage_business_units')
      or (internal_visible and authz.is_staff())
    )
  );

create policy business_units_manage on public.business_units
  for all using (authz.has_permission('org.manage_business_units'))
  with check (authz.has_permission('org.manage_business_units'));

-- branches ------------------------------------------------------------------
create policy branches_public on public.branches
  for select using (deleted_at is null and is_active
                    and (is_public or authz.has_permission('org.view')));

create policy branches_manage on public.branches
  for all using (authz.has_permission('org.manage_branches'))
  with check (authz.has_permission('org.manage_branches'));

-- customers / suppliers -----------------------------------------------------
create policy customers_select on public.customers
  for select using (
    deleted_at is null
    and (authz.has_permission('org.manage_customers')
         or assigned_sales_person_id = authz.current_employee_id()
         or authz.can_view_finance())
  );

create policy customers_manage on public.customers
  for all using (authz.has_permission('org.manage_customers'))
  with check (authz.has_permission('org.manage_customers'));

create policy suppliers_select on public.suppliers
  for select using (
    deleted_at is null
    and (authz.has_permission('org.manage_suppliers')
         or authz.can_view_finance()
         or authz.has_permission('vehicles.create')
         or authz.has_permission('vehicles.edit')
         or authz.has_permission('agriculture.edit')
         or authz.has_permission('mining.edit'))
  );
create policy suppliers_manage on public.suppliers
  for all using (authz.has_permission('org.manage_suppliers'))
  with check (authz.has_permission('org.manage_suppliers'));

-- leads ---------------------------------------------------------------------
-- Anonymous visitors may insert a contact-form enquiry; they may never read.
create policy leads_public_insert on public.leads
  for insert with check (
    created_by is null
    and status = 'new'
    and assigned_to is null
    and (deleted_at is null)
  );

create policy leads_select on public.leads
  for select using (
    deleted_at is null
    and (assigned_to = authz.current_employee_id()
         or authz.has_permission('leads.view')
         or authz.has_permission('leads.manage'))
  );

create policy leads_update on public.leads
  for update using (authz.has_permission('leads.manage')
                    or assigned_to = authz.current_employee_id())
  with check (authz.has_permission('leads.manage')
              or assigned_to = authz.current_employee_id());

-- approval_rules ------------------------------------------------------------
create policy approval_rules_select on public.approval_rules
  for select using (is_active and (deleted_at is null)
                    and (authz.has_permission('finance.approve')
                         or authz.has_permission('finance.manage_settings')));

create policy approval_rules_manage on public.approval_rules
  for all using (authz.has_permission('finance.manage_settings'))
  with check (authz.has_permission('finance.manage_settings'));

-- approvals -----------------------------------------------------------------
create policy approvals_select on public.approvals
  for select using (
    deleted_at is null
    and (requested_by = authz.current_user_id()
         or requested_for = authz.current_user_id()
         or authz.has_permission('finance.approve'))
  );

create policy approvals_insert on public.approvals
  for insert with check (requested_by = authz.current_user_id()
                         or authz.has_permission('finance.approve'));

create policy approvals_update on public.approvals
  for update using (authz.has_permission('finance.approve')
                    or requested_by = authz.current_user_id())
  with check (authz.has_permission('finance.approve'));

-- =============================================================================
-- PART C — CMS
-- =============================================================================

alter table public.website_pages enable row level security;
alter table public.website_sections enable row level security;
alter table public.website_media enable row level security;
alter table public.news_posts enable row level security;
alter table public.testimonials enable row level security;
alter table public.company_statistics enable row level security;
alter table public.company_settings enable row level security;

-- Public reads published pages/sections; drafts require website.view.
create policy website_pages_public on public.website_pages
  for select using (
    deleted_at is null
    and (status = 'published' or authz.has_permission('website.view'))
  );

create policy website_pages_manage on public.website_pages
  for all using (authz.has_permission('website.edit'))
  with check (authz.has_permission('website.edit'));

create policy website_sections_public on public.website_sections
  for select using (
    deleted_at is null
    and exists (
      select 1 from public.website_pages p
       where p.id = website_sections.page_id
         and p.deleted_at is null
         and (p.status = 'published' or authz.has_permission('website.view'))
    )
  );

create policy website_sections_manage on public.website_sections
  for all using (authz.has_permission('website.edit'))
  with check (authz.has_permission('website.edit'));

create policy website_media_public on public.website_media
  for select using (deleted_at is null and (is_public or authz.has_permission('website.media.manage')));

create policy website_media_manage on public.website_media
  for all using (authz.has_permission('website.media.manage'))
  with check (authz.has_permission('website.media.manage'));

create policy news_public on public.news_posts
  for select using (
    deleted_at is null and (status = 'published' or authz.has_permission('website.view'))
  );

create policy news_manage on public.news_posts
  for all using (authz.has_permission('website.edit'))
  with check (authz.has_permission('website.edit'));

create policy testimonials_public on public.testimonials
  for select using (deleted_at is null and status = 'published');

create policy testimonials_manage on public.testimonials
  for all using (authz.has_permission('website.edit'))
  with check (authz.has_permission('website.edit'));

create policy statistics_public on public.company_statistics
  for select using (deleted_at is null and (is_public or authz.has_permission('website.edit')));

create policy statistics_manage on public.company_statistics
  for all using (authz.has_permission('website.edit'))
  with check (authz.has_permission('website.edit'));

-- company_settings: readable by any signed-in user (base currency is needed to
-- render money anywhere), writable only by settings.manage.
create policy company_settings_select on public.company_settings
  for select using (authz.has_any_permission(array['settings.view','settings.manage']));

create policy company_settings_manage on public.company_settings
  for all using (authz.has_permission('settings.manage'))
  with check (authz.has_permission('settings.manage'));

-- =============================================================================
-- PART D — AUTOMOBILES
-- =============================================================================

alter table public.vehicles enable row level security;
alter table public.vehicle_expenses enable row level security;
alter table public.vehicle_repairs enable row level security;
alter table public.vehicle_shipping enable row level security;
alter table public.vehicle_sales enable row level security;
alter table public.vehicle_documents enable row level security;

-- Public inventory listing: only explicitly published, ready-for-sale vehicles.
create policy vehicles_public on public.vehicles
  for select using (
    deleted_at is null
    and is_public
    and status = 'ready_for_sale'
    and business_unit_id in (select id from public.business_units
                              where is_active and public_visible and deleted_at is null)
  );

-- Internal read: vehicle viewers, the assigned sales person, or finance.
create policy vehicles_internal_select on public.vehicles
  for select using (
    deleted_at is null
    and authz.has_permission_in_business_unit('vehicles.view', business_unit_id)
  );

create policy vehicles_salesperson_select on public.vehicles
  for select using (
    deleted_at is null
    and assigned_sales_person_id = authz.current_employee_id()
  );

create policy vehicles_insert on public.vehicles
  for insert with check (
    authz.has_permission_in_business_unit('vehicles.create', business_unit_id)
  );

create policy vehicles_update on public.vehicles
  for update using (
    authz.has_permission_in_business_unit('vehicles.edit', business_unit_id)
    or authz.has_permission('vehicles.delete')
  )
  with check (
    authz.has_permission_in_business_unit('vehicles.edit', business_unit_id)
  );

create policy vehicles_delete on public.vehicles
  for delete using (authz.has_permission_in_business_unit('vehicles.delete', business_unit_id));

-- Public photos of published vehicles are readable by anyone.
create policy vehicles_public_photos on public.vehicles
  for select using (is_public and status = 'ready_for_sale' and deleted_at is null);

-- expenses ------------------------------------------------------------------
create policy vehicle_expenses_select on public.vehicle_expenses
  for select using (
    deleted_at is null
    and authz.has_permission_in_business_unit('vehicle_finance.view', business_unit_id)
  );

create policy vehicle_expenses_insert on public.vehicle_expenses
  for insert with check (
    authz.has_permission_in_business_unit('vehicle_expenses.create', business_unit_id)
  );

create policy vehicle_expenses_update on public.vehicle_expenses
  for update using (
    authz.has_permission_in_business_unit('vehicle_expenses.edit', business_unit_id)
  )
  with check (
    authz.has_permission_in_business_unit('vehicle_expenses.edit', business_unit_id)
  );

create policy vehicle_expenses_delete on public.vehicle_expenses
  for delete using (
    authz.has_permission_in_business_unit('vehicle_expenses.delete', business_unit_id)
  );

-- repairs -------------------------------------------------------------------
create policy vehicle_repairs_select on public.vehicle_repairs
  for select using (
    deleted_at is null
    and exists (select 1 from public.vehicles v
                 where v.id = vehicle_repairs.vehicle_id and v.deleted_at is null
                   and (authz.has_permission_in_business_unit('vehicles.view', v.business_unit_id)
                        or v.assigned_sales_person_id = authz.current_employee_id()))
  );

create policy vehicle_repairs_manage on public.vehicle_repairs
  for all using (
    exists (select 1 from public.vehicles v
             where v.id = vehicle_repairs.vehicle_id and v.deleted_at is null
               and authz.has_permission_in_business_unit('vehicles.edit', v.business_unit_id))
  )
  with check (
    exists (select 1 from public.vehicles v
             where v.id = vehicle_repairs.vehicle_id and v.deleted_at is null
               and authz.has_permission_in_business_unit('vehicles.edit', v.business_unit_id))
  );

-- shipping ------------------------------------------------------------------
create policy vehicle_shipping_select on public.vehicle_shipping
  for select using (
    deleted_at is null
    and exists (select 1 from public.vehicles v
                 where v.id = vehicle_shipping.vehicle_id and v.deleted_at is null
                   and (authz.has_permission_in_business_unit('vehicles.view', v.business_unit_id)
                        or authz.has_permission('vehicle_finance.view')))
  );

create policy vehicle_shipping_manage on public.vehicle_shipping
  for all using (
    exists (select 1 from public.vehicles v
             where v.id = vehicle_shipping.vehicle_id and v.deleted_at is null
               and authz.has_permission_in_business_unit('vehicles.edit', v.business_unit_id))
  )
  with check (
    exists (select 1 from public.vehicles v
             where v.id = vehicle_shipping.vehicle_id and v.deleted_at is null
               and authz.has_permission_in_business_unit('vehicles.edit', v.business_unit_id))
  );

-- sales ---------------------------------------------------------------------
create policy vehicle_sales_select on public.vehicle_sales
  for select using (
    deleted_at is null
    and (sales_person_id = authz.current_employee_id()
         or authz.has_any_permission(array['vehicle_sales.view','vehicle_finance.view',
                                           'vehicles.view','finance.view']))
  );

create policy vehicle_sales_insert on public.vehicle_sales
  for insert with check (
    authz.has_any_permission(array['vehicle_sales.create','sales.create'])
    and exists (select 1 from public.vehicles v
                 where v.id = vehicle_sales.vehicle_id and v.deleted_at is null
                   and (v.assigned_sales_person_id = authz.current_employee_id()
                        or authz.has_permission_in_business_unit('vehicle_sales.create', v.business_unit_id)))
  );

create policy vehicle_sales_update on public.vehicle_sales
  for update using (
    sales_person_id = authz.current_employee_id()
    or authz.has_permission('vehicle_sales.edit')
  )
  with check (
    sales_person_id = authz.current_employee_id()
    or authz.has_permission('vehicle_sales.edit')
  );

create policy vehicle_sales_delete on public.vehicle_sales
  for delete using (authz.has_permission('vehicle_sales.delete'));

-- vehicle_documents ---------------------------------------------------------
create policy vehicle_documents_select on public.vehicle_documents
  for select using (
    deleted_at is null
    and (not is_confidential
         or exists (select 1 from public.vehicles v
                     where v.id = vehicle_documents.vehicle_id and v.deleted_at is null
                       and (authz.has_permission_in_business_unit('vehicles.view', v.business_unit_id)
                            or authz.has_permission('documents.view_sensitive'))))
  );

create policy vehicle_documents_insert on public.vehicle_documents
  for insert with check (authz.has_permission('documents.upload'));

create policy vehicle_documents_delete on public.vehicle_documents
  for delete using (authz.has_permission('documents.delete'));

-- =============================================================================
-- PART E — REAL ESTATE
-- =============================================================================

alter table public.real_estate_properties enable row level security;
alter table public.property_sales enable row level security;
alter table public.property_documents enable row level security;

create policy properties_public on public.real_estate_properties
  for select using (
    deleted_at is null
    and is_public
    and status = 'available'
    and business_unit_id in (select id from public.business_units
                              where is_active and public_visible and deleted_at is null)
  );

create policy properties_internal_select on public.real_estate_properties
  for select using (
    deleted_at is null
    and (authz.has_permission_in_business_unit('properties.view', business_unit_id)
         or assigned_sales_person_id = authz.current_employee_id())
  );

create policy properties_insert on public.real_estate_properties
  for insert with check (authz.has_permission_in_business_unit('properties.create', business_unit_id));

create policy properties_update on public.real_estate_properties
  for update using (authz.has_permission_in_business_unit('properties.edit', business_unit_id))
  with check (authz.has_permission_in_business_unit('properties.edit', business_unit_id));

create policy properties_delete on public.real_estate_properties
  for delete using (authz.has_permission_in_business_unit('properties.delete', business_unit_id));

create policy property_sales_select on public.property_sales
  for select using (
    deleted_at is null
    and (sales_person_id = authz.current_employee_id()
         or authz.has_any_permission(array['property_sales.view','properties.view','finance.view']))
  );

create policy property_sales_insert on public.property_sales
  for insert with check (
    authz.has_any_permission(array['property_sales.create','sales.create'])
    and exists (select 1 from public.real_estate_properties p
                 where p.id = property_sales.property_id and p.deleted_at is null
                   and (p.assigned_sales_person_id = authz.current_employee_id()
                        or authz.has_permission_in_business_unit('property_sales.create', p.business_unit_id)))
  );

create policy property_sales_update on public.property_sales
  for update using (sales_person_id = authz.current_employee_id()
                    or authz.has_permission('property_sales.edit'))
  with check (sales_person_id = authz.current_employee_id()
              or authz.has_permission('property_sales.edit'));

create policy property_sales_delete on public.property_sales
  for delete using (authz.has_permission('properties.delete'));

create policy property_documents_select on public.property_documents
  for select using (
    deleted_at is null
    and (not is_confidential
         or exists (select 1 from public.real_estate_properties p
                     where p.id = property_documents.property_id and p.deleted_at is null
                       and (authz.has_permission_in_business_unit('properties.view', p.business_unit_id)
                            or authz.has_permission('documents.view_sensitive'))))
  );

create policy property_documents_insert on public.property_documents
  for insert with check (authz.has_permission('documents.upload'));

create policy property_documents_delete on public.property_documents
  for delete using (authz.has_permission('documents.delete'));

-- =============================================================================
-- PART F — AGRICULTURE & MINING
-- =============================================================================

alter table public.agricultural_projects enable row level security;
alter table public.agricultural_costs enable row level security;
alter table public.agricultural_harvests enable row level security;
alter table public.mining_projects enable row level security;
alter table public.mining_costs enable row level security;
alter table public.mining_production enable row level security;
alter table public.mining_sales enable row level security;
alter table public.project_documents enable row level security;

create policy agri_projects_select on public.agricultural_projects
  for select using (
    deleted_at is null
    and (is_public
         or authz.has_permission_in_business_unit('agriculture.view', business_unit_id)
         or project_manager_id = authz.current_employee_id())
  );

create policy agri_projects_manage on public.agricultural_projects
  for all using (authz.has_permission_in_business_unit('agriculture.edit', business_unit_id))
  with check (authz.has_permission_in_business_unit('agriculture.create', business_unit_id));

create policy agri_costs_select on public.agricultural_costs
  for select using (
    deleted_at is null
    and exists (select 1 from public.agricultural_projects p
                 where p.id = agricultural_costs.project_id and p.deleted_at is null
                   and (authz.has_permission_in_business_unit('agriculture.financials', p.business_unit_id)
                        or authz.can_view_finance()))
  );

create policy agri_costs_manage on public.agricultural_costs
  for all using (
    exists (select 1 from public.agricultural_projects p
             where p.id = agricultural_costs.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('agriculture.edit', p.business_unit_id))
  )
  with check (
    exists (select 1 from public.agricultural_projects p
             where p.id = agricultural_costs.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('agriculture.edit', p.business_unit_id))
  );

create policy agri_harvests_select on public.agricultural_harvests
  for select using (
    deleted_at is null
    and exists (select 1 from public.agricultural_projects p
                 where p.id = agricultural_harvests.project_id and p.deleted_at is null
                   and authz.has_permission_in_business_unit('agriculture.view', p.business_unit_id))
  );

create policy agri_harvests_manage on public.agricultural_harvests
  for all using (
    exists (select 1 from public.agricultural_projects p
             where p.id = agricultural_harvests.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('agriculture.edit', p.business_unit_id))
  )
  with check (
    exists (select 1 from public.agricultural_projects p
             where p.id = agricultural_harvests.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('agriculture.edit', p.business_unit_id))
  );

create policy mining_projects_select on public.mining_projects
  for select using (
    deleted_at is null
    and (is_public
         or authz.has_permission_in_business_unit('mining.view', business_unit_id)
         or project_manager_id = authz.current_employee_id())
  );

create policy mining_projects_manage on public.mining_projects
  for all using (authz.has_permission_in_business_unit('mining.edit', business_unit_id))
  with check (authz.has_permission_in_business_unit('mining.create', business_unit_id));

create policy mining_costs_select on public.mining_costs
  for select using (
    deleted_at is null
    and exists (select 1 from public.mining_projects p
                 where p.id = mining_costs.project_id and p.deleted_at is null
                   and (authz.has_permission_in_business_unit('mining.financials', p.business_unit_id)
                        or authz.can_view_finance()))
  );

create policy mining_costs_manage on public.mining_costs
  for all using (
    exists (select 1 from public.mining_projects p
             where p.id = mining_costs.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  )
  with check (
    exists (select 1 from public.mining_projects p
             where p.id = mining_costs.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  );

create policy mining_production_select on public.mining_production
  for select using (
    deleted_at is null
    and exists (select 1 from public.mining_projects p
                 where p.id = mining_production.project_id and p.deleted_at is null
                   and authz.has_permission_in_business_unit('mining.view', p.business_unit_id))
  );

create policy mining_production_manage on public.mining_production
  for all using (
    exists (select 1 from public.mining_projects p
             where p.id = mining_production.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  )
  with check (
    exists (select 1 from public.mining_projects p
             where p.id = mining_production.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  );

create policy mining_sales_select on public.mining_sales
  for select using (
    deleted_at is null
    and exists (select 1 from public.mining_projects p
                 where p.id = mining_sales.project_id and p.deleted_at is null
                   and (authz.has_permission_in_business_unit('mining.view', p.business_unit_id)
                        or authz.can_view_finance()))
  );

create policy mining_sales_manage on public.mining_sales
  for all using (
    exists (select 1 from public.mining_projects p
             where p.id = mining_sales.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  )
  with check (
    exists (select 1 from public.mining_projects p
             where p.id = mining_sales.project_id and p.deleted_at is null
               and authz.has_permission_in_business_unit('mining.edit', p.business_unit_id))
  );

create policy project_documents_select on public.project_documents
  for select using (
    deleted_at is null
    and authz.has_permission('documents.view')
    and (not is_confidential or authz.has_permission('documents.view_sensitive'))
  );

create policy project_documents_insert on public.project_documents
  for insert with check (authz.has_permission('documents.upload'));

create policy project_documents_delete on public.project_documents
  for delete using (authz.has_permission('documents.delete'));

-- =============================================================================
-- PART G — FINANCE
-- =============================================================================

alter table public.currencies enable row level security;
alter table public.fx_rates enable row level security;
alter table public.expenses enable row level security;
alter table public.income enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.financial_periods enable row level security;
alter table public.budgets enable row level security;

-- currencies / fx: readable by anyone signed in (needed to render money).
create policy currencies_select on public.currencies
  for select using (is_active or authz.has_permission('finance.view'));

create policy currencies_manage on public.currencies
  for all using (authz.has_permission('finance.manage_currencies'))
  with check (authz.has_permission('finance.manage_currencies'));

create policy fx_rates_select on public.fx_rates
  for select using (authz.can_view_finance());

create policy fx_rates_manage on public.fx_rates
  for all using (authz.has_permission('finance.manage_currencies'))
  with check (authz.has_permission('finance.manage_currencies'));

-- expenses ------------------------------------------------------------------
create policy expenses_select on public.expenses
  for select using (
    deleted_at is null
    and (authz.has_permission_in_business_unit('finance.view', business_unit_id)
         or (requested_by = authz.current_user_id()
             and authz.has_permission('finance.create_expense')))
  );

create policy expenses_insert on public.expenses
  for insert with check (
    authz.has_permission('finance.create_expense')
    and recorded_by = authz.current_user_id()
  );

create policy expenses_update on public.expenses
  for update using (
    authz.has_permission_in_business_unit('finance.edit', business_unit_id)
    or (requested_by = authz.current_user_id() and status = 'draft')
  )
  with check (
    authz.has_permission_in_business_unit('finance.edit', business_unit_id)
    or (requested_by = authz.current_user_id() and status = 'draft')
  );

create policy expenses_delete on public.expenses
  for delete using (authz.has_permission_in_business_unit('finance.delete', business_unit_id));

-- income --------------------------------------------------------------------
create policy income_select on public.income
  for select using (
    deleted_at is null
    and authz.has_permission_in_business_unit('finance.view', business_unit_id)
  );

create policy income_insert on public.income
  for insert with check (
    authz.has_permission('finance.create_income')
    and recorded_by = authz.current_user_id()
  );

create policy income_update on public.income
  for update using (authz.has_permission_in_business_unit('finance.edit', business_unit_id))
  with check (authz.has_permission_in_business_unit('finance.edit', business_unit_id));

create policy income_delete on public.income
  for delete using (authz.has_permission_in_business_unit('finance.delete', business_unit_id));

-- ledger --------------------------------------------------------------------
create policy financial_tx_select on public.financial_transactions
  for select using (
    deleted_at is null
    and (authz.has_permission_in_business_unit('finance.view_all', business_unit_id)
         or authz.has_permission('finance.view_all')
         or (authz.has_permission_in_business_unit('finance.view', business_unit_id)
             and status = 'posted'))
  );

create policy financial_tx_insert on public.financial_transactions
  for insert with check (authz.has_any_permission(array['finance.create_expense','finance.create_income']));

create policy financial_tx_update on public.financial_transactions
  for update using (authz.has_permission('finance.edit'))
  with check (authz.has_permission('finance.edit'));

create policy financial_tx_delete on public.financial_transactions
  for delete using (authz.has_permission('finance.delete'));

create policy financial_periods_select on public.financial_periods
  for select using (authz.can_view_all_finance());

create policy financial_periods_manage on public.financial_periods
  for all using (authz.has_permission('finance.close_period'))
  with check (authz.has_permission('finance.close_period'));

create policy budgets_select on public.budgets
  for select using (deleted_at is null and authz.can_view_finance());

create policy budgets_manage on public.budgets
  for all using (authz.has_permission('finance.manage_budgets'))
  with check (authz.has_permission('finance.manage_budgets'));

-- =============================================================================
-- PART H — COMMUNICATION
-- =============================================================================

alter table public.message_threads enable row level security;
alter table public.thread_participants enable row level security;
alter table public.group_chats enable row level security;
alter table public.group_chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.announcements enable row level security;
alter table public.announcement_acknowledgements enable row level security;
alter table public.message_attachments enable row level security;

-- threads: visible only to participants.
create policy threads_select on public.message_threads
  for select using (authz.is_thread_participant(id) or authz.has_permission('messages.moderate'));

create policy threads_insert on public.message_threads
  for insert with check (authz.has_permission('messages.send'));

create policy threads_update on public.message_threads
  for update using (authz.has_permission('messages.moderate') or created_by = authz.current_user_id())
  with check (authz.has_permission('messages.moderate') or created_by = authz.current_user_id());

create policy participants_select on public.thread_participants
  for select using (user_id = authz.current_user_id() or authz.is_thread_participant(thread_id));

create policy participants_insert on public.thread_participants
  for insert with check (authz.has_permission('messages.moderate') or authz.is_thread_participant(thread_id));

create policy participants_update on public.thread_participants
  for update using (user_id = authz.current_user_id() or authz.has_permission('messages.moderate'))
  with check (user_id = authz.current_user_id() or authz.has_permission('messages.moderate'));

-- groups: directory of public groups, or membership for private ones.
create policy groups_select on public.group_chats
  for select using (
    deleted_at is null
    and (not is_private
         or authz.is_group_member(id)
         or authz.has_permission('group_chats.manage'))
  );

create policy groups_manage on public.group_chats
  for all using (authz.has_permission('group_chats.manage') or authz.is_group_admin(id))
  with check (authz.has_permission('group_chats.create') or authz.is_group_admin(id));

create policy group_members_select on public.group_chat_members
  for select using (user_id = authz.current_user_id() or authz.is_group_member(group_id));

create policy group_members_manage on public.group_chat_members
  for all using (authz.is_group_admin(group_id) or authz.has_permission('group_chats.manage'))
  with check (authz.is_group_admin(group_id) or authz.has_permission('group_chats.manage'));

-- messages: participants of the thread, members of the group.
create policy messages_select on public.messages
  for select using (
    not is_deleted
    and ((thread_id is not null and authz.is_thread_participant(thread_id))
      or (group_id is not null and authz.is_group_member(group_id)))
  );

create policy messages_insert on public.messages
  for insert with check (
    sender_id = authz.current_user_id()
    and authz.has_permission('messages.send')
    and (
      (thread_id is not null and authz.is_thread_participant(thread_id))
      or (group_id is not null and authz.is_group_member(group_id)
          and not (select is_announcement_only from public.group_chats where id = group_id))
    )
  );

create policy messages_update_author on public.messages
  for update using (sender_id = authz.current_user_id() and not is_deleted)
  with check (sender_id = authz.current_user_id());

create policy messages_delete_moderator on public.messages
  for delete using (authz.has_permission('messages.moderate'));

-- notifications: strictly your own.
create policy notifications_select_own on public.notifications
  for select using (recipient_id = authz.current_user_id());

create policy notifications_update_own on public.notifications
  for update using (recipient_id = authz.current_user_id())
  with check (recipient_id = authz.current_user_id());

create policy notifications_delete_own on public.notifications
  for delete using (recipient_id = authz.current_user_id());

-- announcements -------------------------------------------------------------
create policy announcements_select on public.announcements
  for select using (
    deleted_at is null
    and (status = 'published' or authz.has_permission('announcements.create'))
    and authz.can_read_announcement(id)
  );

create policy announcements_manage on public.announcements
  for all using (authz.has_permission('announcements.create'))
  with check (authz.has_permission('announcements.create'));

create policy announcements_publish on public.announcements
  for update using (authz.has_permission('announcements.publish'))
  with check (authz.has_permission('announcements.publish'));

create policy announcements_ack_select on public.announcement_acknowledgements
  for select using (user_id = authz.current_user_id() or authz.has_permission('announcements.create'));

create policy announcements_ack_insert on public.announcement_acknowledgements
  for insert with check (user_id = authz.current_user_id());

create policy message_attachments_select on public.message_attachments
  for select using (
    exists (select 1 from public.messages m
             where m.id = message_attachments.message_id
               and ((m.thread_id is not null and authz.is_thread_participant(m.thread_id))
                 or (m.group_id is not null and authz.is_group_member(m.group_id))))
  );

create policy message_attachments_insert on public.message_attachments
  for insert with check (uploaded_by = authz.current_user_id());

-- =============================================================================
-- PART I — WORK
-- =============================================================================

alter table public.tasks enable row level security;
alter table public.task_comments enable row level security;
alter table public.task_attachments enable row level security;
alter table public.documents enable row level security;
alter table public.audit_logs enable row level security;
alter table public.activity_feed enable row level security;

create policy tasks_select on public.tasks
  for select using (deleted_at is null and authz.can_access_task(tasks.*));

create policy tasks_insert on public.tasks
  for insert with check (
    authz.has_permission('tasks.create')
    and created_by = authz.current_user_id()
    and (assigned_to is null or authz.can_assign_task_to(assigned_to))
  );

create policy tasks_update on public.tasks
  for update using (authz.can_access_task(tasks.*) and authz.has_any_permission(
    array['tasks.update_any','tasks.assign','tasks.create']))
  with check (authz.has_any_permission(array['tasks.update_any','tasks.assign','tasks.create']));

create policy tasks_delete on public.tasks
  for delete using (authz.has_permission('tasks.delete'));

create policy task_comments_select on public.task_comments
  for select using (
    deleted_at is null
    and exists (select 1 from public.tasks t
                 where t.id = task_comments.task_id and t.deleted_at is null
                   and authz.can_access_task(t.*))
  );

create policy task_comments_insert on public.task_comments
  for insert with check (
    author_id = authz.current_user_id()
    and exists (select 1 from public.tasks t
                 where t.id = task_comments.task_id and t.deleted_at is null
                   and authz.can_access_task(t.*))
  );

create policy task_comments_update on public.task_comments
  for update using (author_id = authz.current_user_id())
  with check (author_id = authz.current_user_id());

create policy task_attachments_select on public.task_attachments
  for select using (
    exists (select 1 from public.tasks t
             where t.id = task_attachments.task_id and t.deleted_at is null
               and authz.can_access_task(t.*))
  );

create policy task_attachments_insert on public.task_attachments
  for insert with check (
    uploaded_by = authz.current_user_id()
    and authz.has_permission('documents.upload')
    and exists (select 1 from public.tasks t
                 where t.id = task_attachments.task_id and t.deleted_at is null
                   and authz.can_access_task(t.*))
  );

create policy task_attachments_delete on public.task_attachments
  for delete using (authz.has_permission('documents.delete'));

-- documents -----------------------------------------------------------------
create policy documents_select on public.documents
  for select using (
    deleted_at is null
    and not is_archived
    and authz.has_permission('documents.view')
    and (confidentiality in ('public','internal')
         or authz.has_any_permission(array['documents.view_sensitive','finance.view_all']))
    and (business_unit_id is null
         or authz.has_permission_in_business_unit('documents.view', business_unit_id))
  );

create policy documents_insert on public.documents
  for insert with check (
    authz.has_permission('documents.upload') and uploaded_by = authz.current_user_id()
  );

create policy documents_update on public.documents
  for update using (authz.has_permission('documents.upload') or uploaded_by = authz.current_user_id())
  with check (authz.has_permission('documents.upload'));

create policy documents_delete on public.documents
  for delete using (authz.has_permission('documents.delete'));

-- audit_logs: SELECT only, for those with audit_logs.view. No writes at all
-- from a client — inserts happen through the security-definer RPC below.
create policy audit_logs_select on public.audit_logs
  for select using (authz.has_permission('audit_logs.view'));

-- activity_feed: permission + visibility filtered.
create policy activity_feed_select on public.activity_feed
  for select using (
    (visibility = 'company' and authz.is_staff())
    or actor_id = authz.current_user_id()
    or authz.current_user_id() = any(audience_user_ids)
    or (visibility = 'department' and department_id is not null
        and authz.has_permission_in_department('activity.view_department', department_id))
    or (visibility = 'business_unit' and business_unit_id is not null
        and authz.has_permission_in_business_unit('activity.view_unit', business_unit_id))
  );

create policy activity_feed_insert on public.activity_feed
  for insert with check (authz.is_staff());
