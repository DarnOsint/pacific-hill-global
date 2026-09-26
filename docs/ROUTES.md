# Route Map

Three isolated surfaces. `◎` = authentication required, `⛨` = permission required
(keys from `docs/RBAC.md`).

---

## 1. Public corporate site — `(marketing)`

| Route | Purpose |
|---|---|
| `/` | Corporate homepage (hero, businesses, sectors, statistics, news, enquiry) |
| `/about` | Company profile, leadership, values, history |
| `/businesses` | All business units, driven by `business_units` rows |
| `/businesses/[slug]` | Generic sector page for any unit (no per-sector route needed) |
| `/businesses/automobiles` | Curated sector page + public vehicle inventory |
| `/vehicles` | Public vehicle listings (approved for publication only) |
| `/vehicles/[stockNumber]` | Vehicle detail |
| `/properties` | Public real estate listings |
| `/properties/[slug]` | Property detail |
| `/news` | Published news & updates |
| `/news/[slug]` | Article |
| `/contact` | Contact details, offices, enquiry form |
| `/legal/privacy`, `/legal/terms` | Compliance pages |
| `robots.txt`, `sitemap.xml`, `manifest.webmanifest` | Generated |

`/businesses/[slug]` is the generic renderer. `/businesses/automobiles` exists
only because the automobile unit needs a live inventory grid on the same page —
it is a thin wrapper over the generic renderer, not a parallel implementation.

---

## 2. Authentication — `(auth)`

| Route | Purpose |
|---|---|
| `/login` | Email + password, optional `mfa` field (disabled by env until enabled) |
| `/login/mfa` | TOTP challenge (feature-flagged) |
| `/forgot-password` | Request reset link |
| `/reset-password` | Set new password (recovery session required) |
| `/auth/callback` | Supabase code exchange / PKCE / token refresh |
| `/auth/signout` | POST-only sign out |

---

## 3. Employee portal — `/portal` `◎`

Accessible to every active employee. Sidebar entries are permission-filtered.

| Route | Gate |
|---|---|
| `/portal` | `◎` — role-adaptive dashboard |
| `/portal/directory` | `◎` |
| `/portal/profile` | `◎` (self-service fields only) |
| `/portal/tasks` | `tasks.view_own` |
| `/portal/tasks/[id]` | owner / assignee / `tasks.update_any` |
| `/portal/announcements` | `announcements.view` |
| `/portal/messages` | `messages.send` |
| `/portal/messages/[threadId]` | participant only |
| `/portal/groups` | `group_chats.view` |
| `/portal/groups/[id]` | member or `group_chats.manage` |
| `/portal/notifications` | `◎` |
| `/portal/documents` | `documents.view` |
| `/portal/activity` | own activity + anything `activity.view_all` grants |
| `/portal/vehicles` | `vehicles.view` (scoped: assigned / own unit) |
| `/portal/properties` | `properties.view` (scoped) |
| `/portal/approvals` | `finance.approve` or `approvals.review` |
| `/portal/email` | Company email surface (provider adapter) |

### Portal behaviour rules
* Dashboard content is **assembled from permissions**, never from a role switch.
  A Sales Person's dashboard cannot render a finance card because the finance
  card itself calls `can('finance.view')`.
* Mobile: sidebar collapses to a bottom tab bar with Messages, Tasks, Notices,
  Notifications. Tables become stacked cards below `sm`.

---

## 4. Administration — `/admin` `◎`

### 4.1 Control centre
| Route | Gate |
|---|---|
| `/admin` | `◎` + any `platform.*` or admin permission — else 403 |
| `/admin/website` | `website.view` |
| `/admin/website/pages` | `website.view` |
| `/admin/website/pages/[id]` | `website.view` (editor requires `website.edit`) |
| `/admin/website/media` | `website.media.manage` |
| `/admin/website/news` | `website.edit` |
| `/admin/website/settings` | `website.edit` |

### 4.2 People & access
| Route | Gate |
|---|---|
| `/admin/employees` | `employees.view` |
| `/admin/employees/new` | `employees.create` |
| `/admin/employees/[id]` | `employees.view` (+ `employees.view_sensitive` for HR fields) |
| `/admin/departments` | `org.view` / `org.manage_departments` |
| `/admin/business-units` | `org.view` / `org.manage_business_units` |
| `/admin/branches` | `org.view` / `org.manage_branches` |
| `/admin/roles` | `roles.view` |
| `/admin/roles/[id]` | `roles.manage` |
| `/admin/permissions` | `permissions.manage` |
| `/admin/assignments` | `roles.assign` |

### 4.3 Business records
| Route | Gate |
|---|---|
| `/admin/vehicles` | `vehicles.view` |
| `/admin/vehicles/[id]` | `vehicles.view` (tabs: overview, expenses, repairs, shipping, sale) |
| `/admin/properties` | `properties.view` |
| `/admin/properties/[id]` | `properties.view` |
| `/admin/agriculture` | `agriculture.view` |
| `/admin/agriculture/[id]` | `agriculture.view` |
| `/admin/mining` | `mining.view` |
| `/admin/mining/[id]` | `mining.view` |
| `/admin/customers`, `/admin/suppliers` | `org.manage_*` / view |

### 4.4 Finance
| Route | Gate |
|---|---|
| `/admin/finance` | `finance.view` |
| `/admin/finance/expenses` | `finance.view` |
| `/admin/finance/income` | `finance.view` |
| `/admin/finance/transactions` | `finance.view_all` |
| `/admin/finance/currencies` | `finance.manage_currencies` |
| `/admin/approvals` | `finance.approve` |

### 4.5 Platform
| Route | Gate |
|---|---|
| `/admin/communications` | `announcements.create` |
| `/admin/communications/groups` | `group_chats.manage` |
| `/admin/tasks` | `tasks.view_all` |
| `/admin/documents` | `documents.view` |
| `/admin/audit-logs` | `audit_logs.view` |
| `/admin/reports` | `reports.view` |
| `/admin/reports/[slug]` | `reports.view` + module permission |
| `/admin/settings` | `settings.manage` |

---

## 5. Reports — `/reports/[slug]` `◎`

Print-optimised document routes used for PDF output via the browser's
*Print → Save as PDF*. Same permission gates as `/admin/reports/[slug]`.

---

## 6. API & server surface

| Route | Method | Notes |
|---|---|---|
| `/api/auth/callback` | GET/POST | OAuth / PKCE code exchange |
| `/api/health` | GET | Unauthenticated liveness, no internal detail |
| `/api/realtime/token` | POST | Issues realtime token for current user |
| `/api/search` | GET | Permission-scoped global search |
| `/api/cron/expire` | GET | `CRON_SECRET`-protected: task/announcement expiry |
| `/api/files/[id]` | GET | Signed-URL redirect after permission check |
| `/api/uploads/sign` | POST | Issues a signed upload URL after permission check |
| `/api/email/webhook` | POST | Inbound company-email provider webhook, signature-verified |

All business mutations are **server actions**; route handlers exist only for
things a browser cannot call: webhooks, signed URLs, cron, health, realtime.

---

## 7. URL and access invariants

1. `/portal/**` and `/admin/**` never appear in the sitemap, never in
   `robots.txt`, and are marked `noindex, nofollow, noarchive`.
2. Every admin/portal page exports `robots: { index: false }` via metadata.
3. Direct URL access to an unauthorised `/admin/*` page returns **403**.
4. Unauthenticated access to `/portal/*` or `/admin/*` redirects to
   `/login?next=<path>` (validated to be a same-origin path).
5. `next` is always validated: must start with a single `/` and must not
   contain `//` or a scheme — otherwise it is discarded.
