-- =============================================================================
-- 0009_work.sql
-- Tasks, documents, audit log, activity feed.
-- =============================================================================

create type public.task_status as enum
  ('todo','in_progress','pending','completed','cancelled');
create type public.task_priority as enum ('low','normal','high','urgent');

-- ---------------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------------
create table public.tasks (
  id              uuid primary key default gen_random_uuid(),
  reference       text not null unique,
  title           text not null,
  description     text,
  status          public.task_status not null default 'todo',
  priority        public.task_priority not null default 'normal',
  module          text not null default 'general',   -- vehicles | realestate | …
  task_type       text,                               -- approval | report | operation | admin
  business_unit_id uuid references public.business_units(id) on delete set null,
  department_id   uuid references public.departments(id) on delete set null,
  project_domain  text,
  project_id      uuid,
  resource_type   text,
  resource_id     uuid,

  created_by      uuid not null references public.users(id) on delete restrict,
  assigned_to     uuid references public.users(id) on delete set null,
  assigned_by     uuid references public.users(id) on delete set null,
  assigned_at     timestamptz,
  due_at          timestamptz,
  start_at        timestamptz,
  completed_at    timestamptz,
  completion_note text,
  progress_percent smallint check (progress_percent between 0 and 100),
  estimated_hours numeric(6,2),
  actual_hours    numeric(6,2),
  is_visible_to_all boolean not null default false,
  requires_approval boolean not null default false,
  approval_id     uuid references public.approvals(id) on delete set null,
  watchers        uuid[] not null default '{}',
  reminders_sent_at timestamptz,
  cancelled_at    timestamptz,
  cancel_reason   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  constraint tasks_dates_ck check (due_at is null or start_at is null or due_at >= start_at),
  constraint tasks_completion_ck check (status <> 'completed' or completed_at is not null)
);

create index tasks_assignee_idx on public.tasks (assigned_to, status) where deleted_at is null;
create index tasks_creator_idx  on public.tasks (created_by, status) where deleted_at is null;
create index tasks_dept_idx     on public.tasks (department_id, status) where deleted_at is null;
create index tasks_unit_idx     on public.tasks (business_unit_id, status) where deleted_at is null;
create index tasks_due_idx      on public.tasks (due_at) where deleted_at is null and status not in ('completed','cancelled');
create index tasks_resource_idx on public.tasks (resource_type, resource_id) where deleted_at is null;

create table public.task_comments (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references public.tasks(id) on delete cascade,
  author_id  uuid not null references public.users(id) on delete restrict,
  body       text not null,
  is_system  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index task_comments_task_idx on public.task_comments (task_id, created_at) where deleted_at is null;

create table public.task_attachments (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.tasks(id) on delete cascade,
  storage_path text not null,
  file_name    text not null,
  mime_type    text not null,
  size_bytes   bigint not null check (size_bytes > 0),
  uploaded_by  uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- documents : the platform-wide file registry. Files live in object storage;
-- this table holds only metadata and the owning context.
-- ---------------------------------------------------------------------------
create table public.documents (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  description   text,
  -- domain: vehicles | realestate | agriculture | mining | finance |
  --         employees | corporate | general
  domain        text not null,
  storage_bucket text not null default 'documents',
  storage_path  text not null,
  file_name     text not null,
  mime_type     text not null,
  size_bytes    bigint not null check (size_bytes > 0),
  checksum      text,
  business_unit_id uuid references public.business_units(id) on delete set null,
  department_id uuid references public.departments(id) on delete set null,
  resource_type text,
  resource_id   uuid,
  tags          text[] not null default '{}',
  confidentiality text not null default 'internal'
                  check (confidentiality in ('public','internal','confidential','restricted')),
  is_archived   boolean not null default false,
  version       smallint not null default 1,
  effective_from date,
  effective_to  date,
  uploaded_by   uuid references public.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index documents_domain_idx   on public.documents (domain, created_at desc) where deleted_at is null;
create index documents_resource_idx on public.documents (resource_type, resource_id) where deleted_at is null;
create index documents_unit_idx     on public.documents (business_unit_id) where deleted_at is null;
create index documents_tags_idx     on public.documents using gin (tags);
create index documents_title_trgm   on public.documents using gin (title gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- audit_logs : append-only. No UPDATE, no DELETE, for any role.
-- ---------------------------------------------------------------------------
create type public.audit_action as enum
  ('auth.login','auth.login_failed','auth.logout','auth.password_changed',
   'auth.password_reset_requested','auth.password_reset_completed',
   'auth.mfa_enrolled','auth.mfa_disabled','auth.session_revoked',
   'employee.created','employee.updated','employee.deactivated','employee.activated',
   'employee.deleted','employee.role_assigned','employee.role_revoked',
   'role.created','role.updated','role.deleted','permission.granted','permission.revoked',
   'website.page_created','website.page_updated','website.page_deleted',
   'website.section_updated','website.published','website.unpublished','website.archived',
   'website.media_uploaded','website.media_deleted','website.settings_updated',
   'business_unit.created','business_unit.updated','business_unit.deleted',
   'department.created','department.updated','department.deleted',
   'vehicle.created','vehicle.updated','vehicle.deleted','vehicle.status_changed',
   'vehicle.expense_created','vehicle.expense_updated','vehicle.expense_deleted',
   'vehicle.repair_recorded','vehicle.shipping_updated','vehicle.sale_created','vehicle.sale_updated',
   'property.created','property.updated','property.deleted','property.sale_created',
   'property.published','property.unpublished',
   'agriculture.project_created','agriculture.project_updated','agriculture.cost_recorded',
   'mining.project_created','mining.project_updated','mining.cost_recorded',
   'mining.license_updated','mining.sale_created',
   'finance.income_created','finance.income_updated','finance.income_deleted',
   'finance.expense_created','finance.expense_updated','finance.expense_deleted',
   'finance.transaction_posted','finance.period_closed','finance.currency_updated',
   'approval.requested','approval.approved','approval.rejected','approval.cancelled',
   'message.sent','message.deleted','group.created','group.updated','group.member_added',
   'group.member_removed','group.archived',
   'announcement.created','announcement.published','announcement.unpublished','announcement.deleted',
   'task.created','task.assigned','task.updated','task.completed','task.deleted',
   'document.uploaded','document.downloaded','document.deleted',
   'settings.updated','audit.exported','system.backup');

create table public.audit_logs (
  id            uuid primary key default gen_random_uuid(),
  actor_id      uuid references public.users(id) on delete set null,
  actor_email   text,                     -- denormalised: survives user deletion
  actor_role_slug text,                   -- denormalised snapshot for context
  action        public.audit_action not null,
  resource_type text not null,
  resource_id   uuid,
  resource_label text,
  summary       text not null,
  before_state  jsonb,
  after_state   jsonb,
  metadata      jsonb not null default '{}'::jsonb,
  ip_address    inet,
  user_agent    text,
  request_id    text,
  severity      text not null default 'info' check (severity in ('info','notice','warning','critical')),
  created_at    timestamptz not null default now()
);

create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_actor_idx   on public.audit_logs (actor_id, created_at desc);
create index audit_logs_resource_idx on public.audit_logs (resource_type, resource_id);
create index audit_logs_action_idx   on public.audit_logs (action, created_at desc);
create index audit_logs_severity_idx on public.audit_logs (severity, created_at desc)
  where severity in ('warning','critical');

comment on table public.audit_logs is
  'Append-only. UPDATE and DELETE are blocked by trigger for every role, '
  'including service_role. Retention is enforced by scheduled archival, not deletion in place.';

-- ---------------------------------------------------------------------------
-- activity_feed : the human-readable company activity stream ("Toyota Land
-- Cruiser added to inventory"). Derived, denormalised, permission-filtered at
-- read time. Unlike audit_logs this is product surface, not evidence.
-- ---------------------------------------------------------------------------
create table public.activity_feed (
  id             uuid primary key default gen_random_uuid(),
  actor_id       uuid references public.users(id) on delete set null,
  actor_name     text,
  actor_avatar   text,
  verb           text not null,             -- 'added', 'recorded', 'published'
  summary        text not null,
  detail         text,
  domain         text not null,             -- vehicles | finance | hr | website …
  business_unit_id uuid references public.business_units(id) on delete cascade,
  department_id  uuid references public.departments(id) on delete cascade,
  resource_type  text,
  resource_id    uuid,
  url            text,
  visibility     text not null default 'company'
                   check (visibility in ('private','department','business_unit','company')),
  audience_user_ids uuid[] not null default '{}',
  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);

create index activity_feed_recent_idx on public.activity_feed (created_at desc);
create index activity_feed_actor_idx  on public.activity_feed (actor_id, created_at desc);
create index activity_feed_domain_idx on public.activity_feed (domain, created_at desc);
