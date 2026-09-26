/**
 * The permission catalogue in TypeScript.
 *
 * This is a *type-level* mirror of `supabase/seed/001_permissions.sql`. It
 * exists so permission keys are checked at compile time rather than discovered
 * as a typo in production — the database remains the source of truth for what a
 * user *holds*, but this file guarantees you cannot reference a key that does
 * not exist.
 *
 * Adding a permission:
 *   1. add the row in supabase/seed/001_permissions.sql
 *   2. add the key to `PERMISSIONS` below
 *   3. run `npm run test:rbac` (docs/RBAC.md §8) to confirm role bundles
 *
 * NEVER add role names to this file. Authorisation is permission-based.
 */

export const PERMISSIONS = {
  /* platform ------------------------------------------------------------ */
  // The single permission that produces `isSuperuser`. Intentionally narrow and
  // explicit — never implied by seniority, role name, or permission count.
  PLATFORM_ADMIN: "platform.admin",

  /* website ------------------------------------------------------------- */
  WEBSITE_VIEW: "website.view",
  WEBSITE_EDIT: "website.edit",
  WEBSITE_PUBLISH: "website.publish",
  WEBSITE_MEDIA_MANAGE: "website.media.manage",
  WEBSITE_LEADS_VIEW: "website.leads.view",

  /* employees ----------------------------------------------------------- */
  EMPLOYEES_VIEW: "employees.view",
  EMPLOYEES_VIEW_SENSITIVE: "employees.view_sensitive",
  EMPLOYEES_CREATE: "employees.create",
  EMPLOYEES_EDIT: "employees.edit",
  EMPLOYEES_EDIT_SELF: "employees.edit_self",
  EMPLOYEES_DISABLE: "employees.disable",
  EMPLOYEES_DELETE: "employees.delete",

  /* organisation -------------------------------------------------------- */
  ORG_VIEW: "org.view",
  ORG_MANAGE_DEPARTMENTS: "org.manage_departments",
  ORG_MANAGE_BUSINESS_UNITS: "org.manage_business_units",
  ORG_MANAGE_BRANCHES: "org.manage_branches",
  ORG_MANAGE_CUSTOMERS: "org.manage_customers",
  ORG_MANAGE_SUPPLIERS: "org.manage_suppliers",
  LEADS_VIEW: "leads.view",
  LEADS_MANAGE: "leads.manage",
  LEADS_ASSIGN: "leads.assign",

  /* access control ------------------------------------------------------ */
  ROLES_VIEW: "roles.view",
  ROLES_MANAGE: "roles.manage",
  ROLES_ASSIGN: "roles.assign",
  PERMISSIONS_MANAGE: "permissions.manage",

  /* vehicles ------------------------------------------------------------ */
  VEHICLES_VIEW: "vehicles.view",
  VEHICLES_CREATE: "vehicles.create",
  VEHICLES_EDIT: "vehicles.edit",
  VEHICLES_DELETE: "vehicles.delete",
  VEHICLE_EXPENSES_VIEW: "vehicle_expenses.view",
  VEHICLE_EXPENSES_CREATE: "vehicle_expenses.create",
  VEHICLE_EXPENSES_EDIT: "vehicle_expenses.edit",
  VEHICLE_EXPENSES_DELETE: "vehicle_expenses.delete",
  VEHICLE_REPAIRS_VIEW: "vehicle_repairs.view",
  VEHICLE_REPAIRS_MANAGE: "vehicle_repairs.manage",
  VEHICLE_SHIPPING_VIEW: "vehicle_shipping.view",
  VEHICLE_SHIPPING_MANAGE: "vehicle_shipping.manage",
  VEHICLE_SALES_VIEW: "vehicle_sales.view",
  VEHICLE_SALES_CREATE: "vehicle_sales.create",
  VEHICLE_SALES_EDIT: "vehicle_sales.edit",
  VEHICLE_SALES_DELETE: "vehicle_sales.delete",
  VEHICLE_FINANCE_VIEW: "vehicle_finance.view",

  /* real estate --------------------------------------------------------- */
  PROPERTIES_VIEW: "properties.view",
  PROPERTIES_CREATE: "properties.create",
  PROPERTIES_EDIT: "properties.edit",
  PROPERTIES_DELETE: "properties.delete",
  PROPERTIES_PUBLISH: "properties.publish",
  PROPERTY_SALES_VIEW: "property_sales.view",
  PROPERTY_SALES_CREATE: "property_sales.create",
  PROPERTY_SALES_EDIT: "property_sales.edit",

  /* agriculture --------------------------------------------------------- */
  AGRICULTURE_VIEW: "agriculture.view",
  AGRICULTURE_CREATE: "agriculture.create",
  AGRICULTURE_EDIT: "agriculture.edit",
  AGRICULTURE_DELETE: "agriculture.delete",
  AGRICULTURE_FINANCIALS: "agriculture.financials",

  /* mining -------------------------------------------------------------- */
  MINING_VIEW: "mining.view",
  MINING_CREATE: "mining.create",
  MINING_EDIT: "mining.edit",
  MINING_DELETE: "mining.delete",
  MINING_FINANCIALS: "mining.financials",

  /* finance ------------------------------------------------------------- */
  FINANCE_VIEW: "finance.view",
  FINANCE_VIEW_ALL: "finance.view_all",
  FINANCE_CREATE_INCOME: "finance.create_income",
  FINANCE_CREATE_EXPENSE: "finance.create_expense",
  FINANCE_EDIT: "finance.edit",
  FINANCE_DELETE: "finance.delete",
  FINANCE_APPROVE: "finance.approve",
  FINANCE_MANAGE_CURRENCIES: "finance.manage_currencies",
  FINANCE_MANAGE_BUDGETS: "finance.manage_budgets",
  FINANCE_MANAGE_SETTINGS: "finance.manage_settings",
  FINANCE_CLOSE_PERIOD: "finance.close_period",
  FINANCE_REPORTS_EXPORT: "finance.reports.export",

  /* communication -------------------------------------------------------- */
  MESSAGES_SEND: "messages.send",
  MESSAGES_VIEW_OWN: "messages.view_own",
  MESSAGES_MODERATE: "messages.moderate",
  GROUP_CHATS_VIEW: "group_chats.view",
  GROUP_CHATS_CREATE: "group_chats.create",
  GROUP_CHATS_MANAGE: "group_chats.manage",
  GROUP_CHATS_POST: "group_chats.post",
  ANNOUNCEMENTS_VIEW: "announcements.view",
  ANNOUNCEMENTS_CREATE: "announcements.create",
  ANNOUNCEMENTS_PUBLISH: "announcements.publish",

  /* tasks ---------------------------------------------------------------- */
  TASKS_VIEW_OWN: "tasks.view_own",
  TASKS_VIEW_DEPARTMENT: "tasks.view_department",
  TASKS_VIEW_ALL: "tasks.view_all",
  TASKS_CREATE: "tasks.create",
  TASKS_ASSIGN: "tasks.assign",
  TASKS_UPDATE_ANY: "tasks.update_any",
  TASKS_DELETE: "tasks.delete",

  /* documents ------------------------------------------------------------ */
  DOCUMENTS_VIEW: "documents.view",
  DOCUMENTS_UPLOAD: "documents.upload",
  DOCUMENTS_DELETE: "documents.delete",
  DOCUMENTS_VIEW_SENSITIVE: "documents.view_sensitive",

  /* sales ---------------------------------------------------------------- */
  SALES_CREATE: "sales.create",
  SALES_VIEW_TEAM: "sales.view_team",

  /* reports -------------------------------------------------------------- */
  REPORTS_VIEW: "reports.view",
  REPORTS_EXPORT: "reports.export",
  REPORTS_VIEW_FINANCIAL: "reports.view_financial",

  /* platform ------------------------------------------------------------- */
  AUDIT_LOGS_VIEW: "audit_logs.view",
  ACTIVITY_VIEW_ALL: "activity.view_all",
  ACTIVITY_VIEW_DEPARTMENT: "activity.view_department",
  ACTIVITY_VIEW_UNIT: "activity.view_unit",
  SETTINGS_VIEW: "settings.view",
  SETTINGS_MANAGE: "settings.manage",
} as const;

export type Permission = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

export const ALL_PERMISSIONS = Object.values(PERMISSIONS) as Permission[];

/** Category prefixes, used to group the permissions table in the admin UI. */
export const PERMISSION_CATEGORIES = {
  website: "Website & CMS",
  employees: "Employees",
  org: "Organisation",
  leads: "Leads & Enquiries",
  access: "Roles & Access",
  vehicles: "Automobiles",
  vehicle_expenses: "Vehicle Expenses",
  vehicle_repairs: "Vehicle Repairs",
  vehicle_shipping: "Vehicle Logistics",
  vehicle_sales: "Vehicle Sales",
  vehicle_finance: "Vehicle Finance",
  realestate: "Real Estate",
  agriculture: "Agriculture",
  mining: "Mining",
  finance: "Finance",
  comms: "Communication",
  tasks: "Tasks",
  documents: "Documents",
  sales: "Sales",
  reports: "Reports",
  platform: "Platform",
} as const satisfies Record<string, string>;

/* -------------------------------------------------------------------------- */
/* Predicate helpers                                                           */
/* -------------------------------------------------------------------------- */

/** A permission the user holds, with optional scope narrowing. */
export type Scope =
  | { type: "global" }
  | { type: "department"; departmentId: string }
  | { type: "businessUnit"; businessUnitId: string };

export type UserContext = {
  userId: string;
  employeeId: string | null;
  departmentId: string | null;
  email: string;
  fullName: string;
  avatarUrl: string | null;
  accountStatus: "pending" | "active" | "suspended" | "disabled";
  /** Every permission the user holds, regardless of scope. */
  permissions: ReadonlySet<Permission>;
  /** Every scope the user reaches. `global` means unrestricted. */
  scopes: Scope[];
  isSuperuser: boolean;
  sessionExpiresAt: string | null;
};

/** Does the context reach every scope? */
export function hasGlobalScope(ctx: UserContext): boolean {
  return ctx.scopes.some((s) => s.type === "global");
}

/** Does the context reach a specific business unit? */
export function inBusinessUnit(ctx: UserContext, businessUnitId: string | null): boolean {
  if (hasGlobalScope(ctx)) return true;
  if (!businessUnitId) return false;
  return ctx.scopes.some(
    (s) => s.type === "businessUnit" && s.businessUnitId === businessUnitId,
  );
}

/** Does the context reach a specific department? */
export function inDepartment(ctx: UserContext, departmentId: string | null): boolean {
  if (hasGlobalScope(ctx)) return true;
  if (!departmentId) return false;
  return ctx.scopes.some(
    (s) => s.type === "department" && s.departmentId === departmentId,
  );
}

/**
 * Combined permission + scope check.
 *
 * This is the app-side twin of `authz.has_permission_in_business_unit` in
 * Postgres. The database remains the authority; this exists so we can render
 * the right thing and return a correct 403 before touching a query.
 */
export function canInBusinessUnit(
  ctx: UserContext,
  permission: Permission,
  businessUnitId: string | null,
): boolean {
  if (ctx.isSuperuser) return true;
  if (!ctx.permissions.has(permission)) return false;
  return inBusinessUnit(ctx, businessUnitId);
}

export function canInDepartment(
  ctx: UserContext,
  permission: Permission,
  departmentId: string | null,
): boolean {
  if (ctx.isSuperuser) return true;
  if (!ctx.permissions.has(permission)) return false;
  return inDepartment(ctx, departmentId);
}

/** Unscoped check: does the user hold the permission at all? */
export function can(ctx: UserContext, ...permissions: Permission[]): boolean {
  if (ctx.isSuperuser) return true;
  return permissions.some((p) => ctx.permissions.has(p));
}

/** Scoped check used by most business tables. */
export function canForUnit(
  ctx: UserContext,
  permission: Permission,
  businessUnitId: string | null,
): boolean {
  return canInBusinessUnit(ctx, permission, businessUnitId);
}
