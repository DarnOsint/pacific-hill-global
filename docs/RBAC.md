# RBAC — Authorisation Model

> Implementation contract. Any code that authorises access must resolve through
> this model. No exceptions, no shortcuts, no role-name comparisons.

---

## 1. Why permissions, not roles

Role names are business vocabulary — they change (`Sales Person` becomes
`Account Executive`). Permissions are capability contracts — they are stable and
meaningful. Therefore:

* **Authorisation asks "may this user do X, in scope Y?"**
* Never "is this user role Z?"

The Director is not special-cased anywhere. The Director merely holds every
permission, at `GLOBAL` scope, and is granted the ability to administer the
permission catalogue itself.

```sql
-- FORBIDDEN
if (user.role === 'director') allow();
if (canPublishHomepage(user)) { /* ... roleName hardcoded ... */ }

-- REQUIRED
await requirePermission('website.publish');
```

---

## 2. The four tables

```
permissions        role_permissions      roles            user_roles
────────────       ────────────────      ─────            ─────────
key        PK ───▶ permission_id  PK ──▶ id       PK ◀── role_id
label              role_id                name            user_id
description        permission_id          slug            scope_type
category           scope                  description     scope_department_id
                                                        scope_business_unit_id
                                                        granted_by
                                                        granted_at
                                                        expires_at
```

* `permissions` — atomic capability. One row = one thing.
* `roles` — a named, reusable bundle. Adding a role is a data operation.
* `role_permissions` — the bundle contents.
* `user_roles` — who holds which bundle, and **where**.

---

## 3. Scoping

`user_roles.scope_type` ∈ `GLOBAL | DEPARTMENT | BUSINESS_UNIT`.

| Scope | Grants | Typical holder |
|---|---|---|
| `GLOBAL` | Everywhere | Director, General Manager, Finance Officer |
| `DEPARTMENT` | Rows belonging to that department | Department Manager |
| `BUSINESS_UNIT` | Rows belonging to that business unit | Business Unit Manager |

Effective check for permission `p` in scope `s`:

```
effective(user, p, s) =
      ∃ assignment a : a has p, and a.scope covers s
```

"s_covers": `GLOBAL` covers everything; `DEPARTMENT` covers its department id;
`BUSINESS_UNIT` covers its business unit id. Scopes are **additive** — holding
`GLOBAL` plus `DEPARTMENT` for two departments grants both.

This means a new department or business unit requires **zero** RBAC changes.

---

## 4. Permission catalogue

Namespaced with dots. The namespace is the module; the verb is the capability.

### `website` — public site management
| Permission | Meaning |
|---|---|
| `website.view` | Read pages/sections incl. drafts |
| `website.edit` | Create and modify pages and sections |
| `website.publish` | Publish / unpublish / archive live content |
| `website.media.manage` | Upload, reorder, delete site media |
| `website.leads.view` | Read public enquiries |

### `employees`
`employees.view`, `employees.view_sensitive`, `employees.create`, `employees.edit`,
`employees.edit_self`, `employees.disable`, `employees.delete`

### `org` — departments, business units, branches
`org.view`, `org.manage_departments`, `org.manage_business_units`,
`org.manage_branches`, `org.manage_customers`, `org.manage_suppliers`

### `access` — the RBAC console
`roles.view`, `roles.manage`, `permissions.manage`, `roles.assign`

### `vehicles`
`vehicles.view`, `vehicles.create`, `vehicles.edit`, `vehicles.delete`,
`vehicle_expenses.view`, `vehicle_expenses.create`, `vehicle_expenses.edit`,
`vehicle_expenses.delete`, `vehicle_sales.view`, `vehicle_sales.create`,
`vehicle_sales.edit`, `vehicle_sales.delete`, `vehicle_finance.view`

### `realestate`
`properties.view`, `properties.create`, `properties.edit`, `properties.delete`,
`property_sales.view`, `property_sales.create`, `property_sales.edit`,
`properties.publish`

### `agriculture`
`agriculture.view`, `agriculture.create`, `agriculture.edit`,
`agriculture.delete`, `agriculture.financials`

### `mining`
`mining.view`, `mining.create`, `mining.edit`, `mining.delete`,
`mining.financials`

### `finance`
`finance.view`, `finance.view_all`, `finance.create_income`,
`finance.create_expense`, `finance.edit`, `finance.delete`, `finance.approve`,
`finance.manage_currencies`, `finance.reports.export`

### `comms`
`messages.send`, `messages.view_own`, `messages.moderate`, `group_chats.view`,
`group_chats.create`, `group_chats.manage`, `group_chats.post`,
`announcements.view`, `announcements.create`, `announcements.publish`

### `tasks`
`tasks.view_own`, `tasks.view_department`, `tasks.view_all`, `tasks.create`,
`tasks.assign`, `tasks.update_any`, `tasks.delete`

### `documents`
`documents.view`, `documents.upload`, `documents.delete`, `documents.view_sensitive`

### `reports`
`reports.view`, `reports.export`, `reports.view_financial`

### `platform`
`audit_logs.view`, `activity.view_all`, `settings.view`, `settings.manage`

---

## 5. Initial role seeds

| Role | Scope | Summary of permissions |
|---|---|---|
| **Director** | `GLOBAL` | Everything, including `permissions.manage`, `settings.manage`, `website.publish` |
| **General Manager** | `GLOBAL` | All operational + financial, **not** `permissions.manage` |
| **Department Manager** | `DEPARTMENT` | Department business modules, team tasks, announcements in scope |
| **Business Unit Manager** | `BUSINESS_UNIT` | Single unit's records, team tasks |
| **Sales Person** | `BUSINESS_UNIT` | View assigned vehicles/properties/customers, create sales, own tasks |
| **Receptionist** | `GLOBAL` | Visitors, enquiries, appointments, directory, own tasks, messages |
| **Finance Officer** | `GLOBAL` | `finance.*`, `vehicle_finance.view`, `reports.*`, read business records |
| **Administrative Officer** | `GLOBAL` | `employees.create/edit`, `org.manage_customers/suppliers`, `documents.*`, no `employees.view_sensitive` |
| **HR / Personnel Officer** | `GLOBAL` | `employees.*` incl. sensitive, `documents.view_sensitive`, no finance |
| **Operations Officer** | `BUSINESS_UNIT` | Logistics/trading records, own tasks, documents |
| **Employee** | `GLOBAL` | Read directory, own profile, messages, chat, tasks, announcements |

Seeds live in `supabase/seed/roles.sql` and are **data**, not code.

---

## 6. Enforcement in code

### 6.1 Three primitives (`src/lib/rbac/`)

```ts
requireUser()                       // 401 if no session; returns UserContext
requireActiveAccount()              // 403 if deactivated/suspended/locked
requirePermission('vehicles.create')// 403 if not held (scope optional)
can('vehicles.create')              // boolean, for navigation
```

`UserContext` is resolved once per request (React `cache()`) and contains
`userId`, `employeeId`, `permissions: string[]`, `scopes: Scope[]`,
`departmentId`, `isSuperuser` (the Director bootstrap grant), `sessionExpiresAt`.

### 6.2 Server action shape (canonical)

```ts
'use server';
import { z } from 'zod';
import { requirePermission } from '@/lib/rbac/require';
import { createVehicle } from '@/lib/services/vehicles';
import { audit } from '@/lib/audit';

const Schema = z.object({ /* ... */ });

export async function createVehicleAction(input: unknown) {
  const actor = await requirePermission('vehicles.create');
  const data  = Schema.parse(input);
  const result = await createVehicle(actor, data);
  await audit.write(actor, 'vehicle.created', 'vehicle', result.id, { stock: result.stockNumber });
  revalidatePath('/admin/vehicles');
  return { ok: true, data: result };
}
```

Note the ordering: **parse → guard → service → audit**. Guards are never
skipped because "the UI already hides the button".

### 6.3 Enforcement in Postgres

`authz` schema exposes functions usable directly in RLS policies:

```sql
authz.has_permission(perm_key text)                       -- any effective scope
authz.has_permission_in(perm_key text, bu_id uuid)        -- business unit
authz.has_permission_in_department(perm_key text, d_id uuid)
authz.can_access_employee(target_user uuid)                -- self or HR/Admin
authz.current_employee_id() uuid
authz.is_staff() bool
```

Policies call these; they never trust a value passed from the client.

---

## 7. Rules that cannot be broken

1. **Navigation visibility is cosmetic.** It is a UX affordance only.
2. **Every protected page** verifies `requireUser()` + route permission in a
   server layout or `generateMetadata`/page guard. Typing `/admin/finance` as a
   Sales Person yields **403 Forbidden**, never a render and never a redirect
   loop.
3. **Every server action and route handler** repeats the check. Layout guards are
   not sufficient because actions are directly reachable.
4. **No `hasRole()`, no `role ===`, no `isDirector` flag** in authorisation code.
   `isSuperuser` exists solely to bootstrap a brand-new installation and is
   stored as a permission (`platform.superuser`).
5. **Deactivating an employee** must immediately revoke: set
   `employees.status = 'inactive'`, which RLS reads directly. Sessions already
   issued are rejected by `requireActiveAccount()`.
6. **Permission removal** takes effect on the next request — no cache longer than
   a single request may hold a permission set.
7. **Scope escalation** requires an explicit `user_roles` insert, which is audited.

---

## 8. Testing requirement

`src/lib/rbac/permissions.test.ts` (and the guard tests) must assert, for every
role seed:

* the Director holds every permission in the catalogue;
* `website.publish` is held by no other role than those explicitly granted;
* a scoped role does not grant outside its scope;
* `requirePermission` throws 403 for an unheld key.

This test is the executable form of §7.
