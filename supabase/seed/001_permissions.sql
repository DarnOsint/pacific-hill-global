-- =============================================================================
-- seed/001_permissions.sql
-- The permission catalogue. This file is the authority for what capabilities
-- exist. Adding a capability = adding a row here + one guard call in code.
-- ============================================================================

insert into public.permissions (key, label, description, category, is_sensitive) values
-- platform ----------------------------------------------------------------
-- `platform.admin` is the single permission that produces `isSuperuser` in
-- src/lib/rbac/guards.ts. It is intentionally narrow and explicit: it is NOT
-- implied by seniority, role name, or "has a lot of permissions". Everything
-- else in the platform is gated by ordinary scoped permissions.
('platform.admin',            'Platform administrator',      'Unrestricted access: role/permission management, audit log, and all business units', 'platform', true),

-- website -----------------------------------------------------------------
('website.view',              'View website CMS',            'Read pages, sections and drafts', 'website', false),
('website.edit',              'Edit website content',        'Create and modify pages, sections, news', 'website', false),
('website.publish',           'Publish website content',     'Publish, unpublish and archive live content', 'website', true),
('website.media.manage',      'Manage website media',        'Upload, organise and delete site images', 'website', false),
('website.leads.view',        'View website enquiries',      'Read public contact-form submissions', 'website', false),

-- employees ---------------------------------------------------------------
('employees.view',            'View employees',              'See the employee directory and profiles', 'employees', false),
('employees.view_sensitive',  'View sensitive HR data',      'National ID, tax ID, passport, bank, salary, next of kin', 'employees', true),
('employees.create',          'Create employees',            'Add new employee records and accounts', 'employees', true),
('employees.edit',            'Edit employees',              'Modify any employee record', 'employees', true),
('employees.edit_self',       'Edit own profile',            'Modify permitted fields on own profile', 'employees', false),
('employees.disable',         'Disable employees',           'Suspend or disable an account', 'employees', true),
('employees.delete',          'Delete employees',            'Permanently remove an employee record', 'employees', true),

-- organisation ------------------------------------------------------------
('org.view',                  'View organisation structure', 'Departments, business units, branches', 'org', false),
('org.manage_departments',    'Manage departments',          'Create and edit departments', 'org', true),
('org.manage_business_units', 'Manage business units',       'Create, edit and archive business units', 'org', true),
('org.manage_branches',       'Manage branches',             'Create and edit offices and branches', 'org', true),
('org.manage_customers',      'Manage customers',            'Create and edit customer records', 'org', false),
('org.manage_suppliers',      'Manage suppliers',            'Create and edit supplier records', 'org', false),
('leads.view',                'View all leads',              'See every enquiry, not only your own', 'leads', false),
('leads.manage',              'Manage all leads',            'Assign and progress any enquiry', 'leads', true),

-- access control ----------------------------------------------------------
('roles.view',                'View roles',                  'Read the role catalogue and its permissions', 'access', false),
('roles.manage',              'Manage roles',                'Create and edit roles and their permission bundles', 'access', true),
('roles.assign',              'Assign roles',                'Grant or revoke a role for a user', 'access', true),
('permissions.manage',        'Manage permissions',          'Extend or retire the permission catalogue', 'access', true),

-- vehicles ----------------------------------------------------------------
('vehicles.view',             'View vehicles',               'Read the vehicle inventory', 'vehicles', false),
('vehicles.create',           'Register vehicles',           'Add a newly purchased vehicle', 'vehicles', true),
('vehicles.edit',             'Edit vehicles',               'Modify vehicle details and status', 'vehicles', true),
('vehicles.delete',           'Delete vehicles',             'Remove a vehicle record', 'vehicles', true),
('vehicle_expenses.view',     'View vehicle expenses',       'Read itemised vehicle costs', 'vehicle_expenses', true),
('vehicle_expenses.create',   'Record vehicle expenses',     'Add a cost line to a vehicle', 'vehicle_expenses', true),
('vehicle_expenses.edit',     'Edit vehicle expenses',       'Modify or approve a vehicle cost line', 'vehicle_expenses', true),
('vehicle_expenses.delete',   'Delete vehicle expenses',     'Remove a vehicle cost line', 'vehicle_expenses', true),
('vehicle_repairs.view',      'View vehicle repairs',        'Read repair work orders', 'vehicle_repairs', false),
('vehicle_repairs.manage',    'Manage vehicle repairs',      'Create and update repair work orders', 'vehicle_repairs', true),
('vehicle_shipping.view',     'View shipping records',       'Read inbound logistics legs', 'vehicle_shipping', false),
('vehicle_shipping.manage',   'Manage shipping records',     'Update shipping, port and clearing details', 'vehicle_shipping', true),
('vehicle_sales.view',        'View vehicle sales',          'Read vehicle sales', 'vehicle_sales', true),
('vehicle_sales.create',      'Record vehicle sales',        'Create a vehicle sale', 'vehicle_sales', true),
('vehicle_sales.edit',        'Edit vehicle sales',          'Update a vehicle sale', 'vehicle_sales', true),
('vehicle_sales.delete',      'Delete vehicle sales',        'Remove a vehicle sale record', 'vehicle_sales', true),
('vehicle_finance.view',      'View vehicle financials',     'See acquisition cost, margin and profit per vehicle', 'vehicle_finance', true),

-- real estate -------------------------------------------------------------
('properties.view',            'View properties',            'Read the property portfolio', 'realestate', false),
('properties.create',          'Create properties',          'Add a property or plot', 'realestate', true),
('properties.edit',            'Edit properties',            'Modify property details, pricing, status', 'realestate', true),
('properties.delete',          'Delete properties',          'Remove a property record', 'realestate', true),
('properties.publish',         'Publish properties',         'Make a property visible on the public site', 'realestate', true),
('property_sales.view',        'View property sales',        'Read property sales', 'realestate', true),
('property_sales.create',      'Record property sales',      'Create a property sale', 'realestate', true),
('property_sales.edit',        'Edit property sales',        'Update a property sale', 'realestate', true),

-- agriculture -------------------------------------------------------------
('agriculture.view',            'View agricultural projects', 'Read agricultural projects', 'agriculture', false),
('agriculture.create',          'Create agricultural projects','Add a new agricultural project','agriculture', true),
('agriculture.edit',            'Edit agricultural projects', 'Modify project and harvest records', 'agriculture', true),
('agriculture.delete',          'Delete agricultural projects','Remove an agricultural project', 'agriculture', true),
('agriculture.financials',      'View agricultural financials','See project costs, revenue and profit', 'agriculture', true),

-- mining ------------------------------------------------------------------
('mining.view',                 'View mining projects',      'Read mining projects and licences', 'mining', false),
('mining.create',               'Create mining projects',    'Add a new mining project', 'mining', true),
('mining.edit',                 'Edit mining projects',      'Modify project, production and licence records', 'mining', true),
('mining.delete',               'Delete mining projects',    'Remove a mining project', 'mining', true),
('mining.financials',           'View mining financials',    'See project costs, revenue and profit', 'mining', true),

-- finance -----------------------------------------------------------------
('finance.view',                'View financials',           'Read income and expense records in scope', 'finance', true),
('finance.view_all',            'View all financials',       'Read every financial record regardless of unit', 'finance', true),
('finance.create_income',       'Record income',             'Add a company income record', 'finance', true),
('finance.create_expense',      'Record expenses',           'Add a company expense record', 'finance', true),
('finance.edit',                'Edit financial records',    'Modify income, expenses and transactions', 'finance', true),
('finance.delete',              'Delete financial records',  'Remove a financial record', 'finance', true),
('finance.approve',             'Approve financial actions', 'Approve or reject expenses, sales and adjustments', 'finance', true),
('finance.manage_currencies',   'Manage currencies and FX',  'Maintain currency list and exchange rates', 'finance', true),
('finance.manage_budgets',      'Manage budgets',            'Set and maintain budgets', 'finance', true),
('finance.manage_settings',     'Manage finance settings',   'Configure approval rules and thresholds', 'finance', true),
('finance.close_period',        'Close financial periods',   'Lock a period so history cannot be edited', 'finance', true),
('finance.reports.export',      'Export financial reports',  'Download finance data as CSV or Excel', 'finance', true),

-- communication -----------------------------------------------------------
('messages.send',               'Send messages',              'Direct and group messages', 'comms', false),
('messages.view_own',           'Read own messages',          'Access personal conversations', 'comms', false),
('messages.moderate',           'Moderate all messages',     'Read and remove any message', 'comms', true),
('group_chats.view',            'View group chats',           'See groups you belong to', 'comms', false),
('group_chats.create',          'Create group chats',         'Create a new group', 'comms', true),
('group_chats.manage',          'Manage group chats',         'Rename, add or remove members, archive groups', 'comms', true),
('group_chats.post',            'Post in group chats',        'Send messages to groups', 'comms', false),
('announcements.view',          'View announcements',         'Read internal notices', 'comms', false),
('announcements.create',        'Create announcements',      'Draft internal notices', 'comms', true),
('announcements.publish',       'Publish announcements',      'Publish notices to the portal', 'comms', true),

-- tasks -------------------------------------------------------------------
('tasks.view_own',              'View own tasks',             'Tasks assigned to or created by you', 'tasks', false),
('tasks.view_department',       'View department tasks',      'Tasks for your department or business unit', 'tasks', false),
('tasks.view_all',              'View all tasks',             'Every task in the company', 'tasks', true),
('tasks.create',                'Create tasks',               'Raise new tasks', 'tasks', false),
('tasks.assign',                'Assign tasks',               'Assign tasks to other employees', 'tasks', true),
('tasks.update_any',            'Update any task',            'Change any task regardless of ownership', 'tasks', true),
('tasks.delete',                'Delete tasks',               'Remove tasks', 'tasks', true),

-- documents ---------------------------------------------------------------
('documents.view',              'View documents',             'Read internal documents', 'documents', false),
('documents.upload',            'Upload documents',           'Add files to the document store', 'documents', false),
('documents.delete',            'Delete documents',           'Remove documents', 'documents', true),
('documents.view_sensitive',    'View confidential documents','Read confidential and restricted documents', 'documents', true),

-- sales -------------------------------------------------------------------
('leads.assign',                'Assign leads',               'Assign enquiries to sales staff', 'sales', true),
('sales.create',                'Record sales',               'Create a sale on a vehicle or property', 'sales', true),
('sales.view_team',             'View team sales',            'See sales made by colleagues in your unit', 'sales', true),

-- reports -----------------------------------------------------------------
('reports.view',                'View reports',               'Open the reporting module', 'reports', false),
('reports.export',              'Export reports',             'Download report data', 'reports', false),
('reports.view_financial',      'View financial reports',     'Open reports containing financial data', 'reports', true),

-- platform ----------------------------------------------------------------
('audit_logs.view',             'View audit logs',            'Read the security audit trail', 'platform', true),
('activity.view_all',           'View all company activity',  'See activity across every department', 'platform', true),
('activity.view_department',    'View department activity',   'See activity for your department', 'platform', false),
('activity.view_unit',          'View unit activity',         'See activity for your business unit', 'platform', false),
('settings.view',               'View system settings',       'Read platform configuration', 'platform', true),
('settings.manage',             'Manage system settings',     'Change platform-wide configuration', 'platform', true)
on conflict (key) do update
   set label       = excluded.label,
       description = excluded.description,
       category    = excluded.category,
       is_sensitive = excluded.is_sensitive;
