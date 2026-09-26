# Pacific Hill Global — Platform Architecture

> Status: **authoritative design document**. Code must conform to this document.
> If code and this document disagree, this document is a bug (or the code is).

---

## 1. System Goals

Pacific Hill Global (PHG) is a **diversified business group**. The platform must:

1. Present a premium, credible public corporate presence.
2. Provide a secure internal operating system for employees.
3. Provide a Director-grade administration control centre.
4. Allow **new business units, departments, roles and modules to be added through
   configuration and data — never through a code rewrite.**

The last point is the architectural constraint that drives every decision below.

### 1.1 The diversification rule (single most important design rule)

> **A business unit is a row, never a code branch.**

The public website renders business units from the `business_units` table. There is
no `if (unit === 'mining')` in a component. The automobile module is special only
because vehicles have deep sub-domain modelling (expenses, repairs, shipping,
sales) — that is a *module* difference, not a *company structure* difference.

---

## 2. Runtime Topology

```
                        ┌──────────────────────────────┐
   Public Internet      │   Vercel Edge Network        │
                        │   • CDN / static assets      │
                        │   • next/image optimizer     │
                        │   • WAF + rate limits        │
                        └──────────────┬───────────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │   Next.js 16 (App Router)     │
                        │   ┌────────────────────────┐  │
                        │   │ Route Handlers (RSC)   │  │
                        │   │ Server Actions         │  │
                        │   │ Route Handlers /api/*  │  │
                        │   └───────────┬────────────┘  │
                        │               │               │
                        │   ┌───────────▼────────────┐  │
                        │   │ lib/  (server services)│  │
                        │   │  auth → rbac → audit   │  │
                        │   │  validation → storage  │  │
                        │   │  queries (data access) │  │
                        │   └───────────┬────────────┘  │
                        └───────────────┼───────────────┘
                                        │  Supabase JS (SSR cookie session)
                        ┌───────────────▼───────────────┐
                        │  Supabase                     │
                        │  ├── Auth      (identities)   │
                        │  ├── Postgres  + RLS          │
                        │  ├── Storage   (objects)      │
                        │  └── (optional) Edge Fn      │
                        └───────────────────────────────┘
```

**Trust boundary rule:** everything left of Postgres is untrusted. Every request is
re-authorised server-side. The browser is a rendering surface, never an authority.

---

## 3. Environment Separation

Three deployments of one codebase. Same source, different `NEXT_PUBLIC_APP_ENV`.

| Surface | Route space | Auth required | Data source | Cache policy |
|---|---|---|---|---|
| **Public** | `/` | No | `website_*` published rows only | ISR / static + revalidate-on-publish |
| **Portal** | `/portal/*` | Yes, any active employee | Authorised rows via RLS | `private, no-store` |
| **Admin** | `/admin/*` | Yes, admin-scoped permission | Authorised rows via RLS | `private, no-store` |

Guards live in **two** independent places and both must pass:

1. **Next.js middleware** — refreshes the Supabase session cookie, coarse-gates
   `/portal` and `/admin` (is there *a* user? is the account active?).
2. **Server-side layout guards + RLS** — the real authorisation. Middleware is a
   fast UX redirect, *not* a security control. A user who hand-crafts a request
   past middleware still hits `requirePermission()` and Postgres RLS.

---

## 4. Layered Module Pattern

Every functional module follows the same six layers. No exceptions — this is what
keeps a 40-module platform maintainable.

```
┌─────────────────────────────────────────────────────────────┐
│ L6  Presentation     app/(surface)/<module>/page.tsx       │
│                     + module components                     │
├─────────────────────────────────────────────────────────────┤
│ L5  UI Primitives    components/ui/*  (button, table,      │
│                     dialog, form, empty, error, toast)     │
├─────────────────────────────────────────────────────────────┤
│ L4  Server Actions   app/actions/<module>.ts  "use server" │
│                     thin: parse → guard → service → audit  │
├─────────────────────────────────────────────────────────────┤
│ L3  Services         lib/services/<module>.ts              │
│                     business logic, permissions, audit      │
├─────────────────────────────────────────────────────────────┤
│ L2  Data Access      lib/queries/<module>.ts                │
│                     typed Supabase queries, no auth logic   │
├─────────────────────────────────────────────────────────────┤
│ L1  Database         supabase/migrations/*.sql             │
│                     tables, constraints, triggers, RLS      │
└─────────────────────────────────────────────────────────────┘
```

**Hard rules**

* **L4 actions never contain SQL and never contain business math.**
* **L3 services never import React.**
* **L2 queries never check permissions** (RLS already does; services do the
  explicit, human-readable check for defence-in-depth and for correct errors).
* **L1 is the last line of defence.** If L3 has a bug, RLS still holds.

---

## 5. Request Lifecycle (a protected mutation)

```
Browser ──POST /admin/vehicles (server action)
   │
   ├─ 1. Zod parse            → 400 + field errors        (lib/validation)
   ├─ 2. requireUser()        → 401 redirect to /login    (lib/auth)
   ├─ 3. requireActive()      → 403 account deactivated   (lib/auth)
   ├─ 4. requirePermission()  → 403 /forbidden            (lib/rbac)
   │        └── permission keys from DB, role names never hardcoded
   ├─ 5. rate limit (per user+action)                      (lib/rate-limit)
   ├─ 6. service: domain validation, business rules,
   │      money normalisation, approval trigger            (lib/services)
   ├─ 7. data access: insert via RLS-scoped client         (lib/queries)
   ├─ 8. audit.write()       → audit_logs row             (lib/audit)
   └─ 9. revalidatePath() + structured result {ok|data|error}
```

Failures at steps 1–5 never reach the database. Failures at 6–7 never mutate
without an audit row (the audit insert is in the same request; for critical
financial writes it is additionally written inside a Postgres RPC that is
transactional with the mutation — see `docs/DATABASE.md` §7).

---

## 6. RBAC Architecture

Full detail in [`RBAC.md`](./RBAC.md). Summary of the model:

* **Permissions** are atomic strings: `vehicles.create`, `finance.view_all`.
* **Roles** are named bundles of permissions: `director`, `finance_officer`, …
* **Assignments** (`user_roles`) carry a **scope**: `GLOBAL`, a `department_id`, or
  a `business_unit_id`. So "Automobile Department Manager" is a *scoped role
  assignment*, not a new role.
* Authorisation is `permission AND scope`. Never `role === 'director'`.
* The permission set is seeded as data; new permissions are added by inserting a
  row, not by shipping code.

Three enforcement points, all derived from the same source of truth:

| Layer | Mechanism | Purpose |
|---|---|---|
| Navigation | `lib/rbac/can()` (server) | Only show what the user may use |
| Server action | `requirePermission()` | Hard gate; 403 on failure |
| Postgres | `authz.has_permission()` in RLS | Hard gate; no code path can bypass |

---

## 7. Data Architecture

Full detail in [`DATABASE.md`](./DATABASE.md). Conventions that must hold everywhere:

* `uuid` primary keys, `gen_random_uuid()`.
* `created_at`, `updated_at` on **every** table; triggers maintain `updated_at`.
* `created_by`, `updated_by` (`uuid`, FK `users.id`, `ON DELETE SET NULL`) on
  every business table.
* `status` enum or lookup where the entity has a lifecycle.
* Soft delete (`deleted_at`) on business records; hard delete only for
  permission/policy rows.
* Money as `numeric(18,4)` + `currency_code char(3)` + `exchange_rate numeric(18,8)`
  + generated `base_amount`. Never `float`. See [`money`](../src/lib/money.ts).
* Multi-tenancy-ready: every business table carries `business_unit_id`.
* **No large binaries in the database.** Objects live in Supabase Storage; the DB
  stores only path, size, mime, owner and checksum.

### 7.1 Data domains

| Domain | Tables | Module |
|---|---|---|
| Identity | `users`, `employees`, `departments`, `roles`, `permissions`, `role_permissions`, `user_roles`, `branches` | `employees` |
| Organisation | `business_units`, `customers`, `suppliers`, `approval_rules`, `approvals` | `org` |
| CMS | `website_pages`, `website_sections`, `website_media`, `news_posts`, `testimonials`, `enquiries`, `company_settings` | `website` |
| Automobile | `vehicles`, `vehicle_expenses`, `vehicle_repairs`, `vehicle_shipping`, `vehicle_sales` | `automobiles` |
| Real estate | `real_estate_properties`, `property_images`, `property_sales` | `realestate` |
| Agriculture | `agricultural_projects`, `agricultural_costs`, `agricultural_harvests` | `agriculture` |
| Mining | `mining_projects`, `mining_costs`, `mining_production`, `mining_sales` | `mining` |
| Finance | `expenses`, `income`, `financial_transactions`, `currencies`, `fx_rates` | `finance` |
| Comms | `message_threads`, `messages`, `group_chats`, `group_chat_members`, `notifications`, `announcements` | `comms` |
| Work | `tasks`, `task_comments`, `task_attachments` | `tasks` |
| Platform | `documents`, `audit_logs`, `activity_feed` | `platform` |

---

## 8. Caching & Performance

Public and private surfaces are optimised differently on purpose.

| Surface | Rendering | Cache | Why |
|---|---|---|---|
| Public marketing | RSC + ISR | `revalidate: 300`, tag `public` | Fast global delivery; invalidated on publish |
| CMS preview | dynamic | `no-store` | Must always show draft |
| Portal / Admin | dynamic | `no-store` | Personalised, permission-filtered |
| Reference data (currencies, units, departments) | RSC | `revalidate: 3600` | Rarely changes, read often |

* `revalidatePath()` / `revalidateTag()` are called **by the publish server action**,
  not by revalidation APIs exposed to the browser.
* Portal bundles are code-split per surface: a public visitor never downloads
  chart, table or editor code. `next/dynamic` for heavy client components.
* All public list queries are paginated server-side with a hard `limit`.
* Images: `next/image` with per-business-unit `sizes`; Supabase Storage
  transformations (`?width=`) for the CMS gallery.

---

## 9. Security Architecture

Full detail in [`SECURITY.md`](./SECURITY.md). Defence in depth, in order:

1. **Edge** — Vercel WAF, rate limits on `/api/auth/*` and login action.
2. **Session** — Supabase SSR cookies, `HttpOnly`, `SameSite=Lax`, host-only,
   refreshed by middleware; absolute session cap enforced in `requireUser()`.
3. **Authorisation** — permission + scope, at three layers (§6).
4. **Validation** — every input parsed by a Zod schema that is also the source of
   the TypeScript type (`z.infer`). No untyped `JSON.parse` of user input.
5. **Output** — React escaping by default; no `dangerouslySetInnerHTML` on
   user-controlled content; strict CSP with nonces for the protected surfaces.
6. **Data** — Postgres RLS, least-privilege `anon`/`authenticated` roles.
7. **Files** — allow-list of MIME types, 25 MB cap, server-side extension check,
   private buckets, signed URLs with short TTL, no executable content types.
8. **Money** — computed server-side only; the client never sends a total.
9. **Audit** — append-only `audit_logs`, no update/delete grant.
10. **Errors** — production returns an opaque incident reference, never a stack
    trace, SQL message, or Supabase error body.

---

## 10. Scale Path

The design must not require a rewrite for any of these:

| Future need | Already supported by | Effort |
|---|---|---|
| New business unit (e.g. Energy) | `business_units` row + `business_unit_id` on all business tables | Data only |
| New department | `departments` row | Data only |
| New role (e.g. Compliance Officer) | `roles` + `role_permissions` rows | Data only |
| New permission | `permissions` row + guard call | Data only |
| New subsidiary / legal entity | `business_units.legal_entity` | Data only |
| New country branch | `branches` row | Data only |
| Multi-company group | Every table has `business_unit_id`; add `companies` later without touching rows | Low |
| Human Resources module | `employees` + `documents` already modelled | Module add |
| Two-factor auth | `employees.mfa_enabled`, `employees.mfa_secret` | Adapters already present |
| Offline / PWA | Route structure + `manifest.webmanifest` + service worker | Low |
| Real-time chat | `messages` table + RLS already realtime-eligible | Low |
| Mobile apps | REST + server actions surface the same RBAC | Low |

---

## 11. Repository Layout

```
pacific-hill-global/
├─ docs/                      design documents (this folder)
├─ supabase/
│  ├─ migrations/             ordered, immutable SQL migrations
│  └─ seed/                   development-only seed data
├─ scripts/                   migrations runner, seed runner, admin bootstrap
├─ public/                    manifest, service worker, icons, robots fallback
└─ src/
   ├─ app/
   │  ├─ (marketing)/         public corporate site
   │  ├─ (auth)/              login, password reset, callback
   │  ├─ portal/              employee platform
   │  ├─ admin/               administration control centre
   │  ├─ api/                 route handlers (webhooks, realtime, exports)
   │  ├─ reports/             print-optimised report documents (PDF via print)
   │  └─ *.ts                 robots, sitemap, manifest, error boundaries
   ├─ components/             ui/ marketing/ portal/ admin/ shared/
   ├─ lib/                    supabase, auth, rbac, audit, services, queries,
   │                          validation, storage, export, money, email, utils
   ├─ types/                  database.ts (generated shape), domain.ts
   └─ middleware.ts           session refresh + coarse route gating
```

---

## 12. Delivery Phases

| Phase | Scope | Gate to next phase |
|---|---|---|
| **1 Foundation** | schema, auth, RBAC, employee accounts, public site, admin shell, responsive | every protected route enforces permission server-side; schema applied |
| **2 Internal ops** | dashboard, directory, tasks, announcements, notifications, DMs, group chat | messaging permission-scoped; notifications audited |
| **3 Business** | automobiles + expenses + sales + profit, real estate, agriculture, mining | money computed server-side; reports reconcile to the ledger |
| **4 Finance & reporting** | income, expenses, reports, exports, audit log | every financial mutation has an audit row |
| **5 Advanced** | email provider integration, PWA, push, approval workflows | optional providers behind interfaces, disabled by env |

Each phase ships independently. No phase depends on a later phase's code.

---

## 13. Non-negotiable engineering rules

1. No business logic in React components.
2. No `role === '…'` authorisation check anywhere in the codebase.
3. No money arithmetic in the browser.
4. No untyped input reaches a query.
5. No table is exposed without a permission check on the write path.
6. No secret is committed. `.env*` files are ignored; only `.env.example` is tracked.
7. No destructive change ships without a migration and a backfill.
8. Every new module ships with: permission keys, navigation entry, empty state,
   loading state, error state, audit entries, and a row in `docs/ROUTES.md`.
