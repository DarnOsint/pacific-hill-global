-- =============================================================================
-- 0010_authz.sql
-- Authorisation helper functions used directly by RLS policies.
--
-- These are SECURITY DEFINER and owned by the table owner so that they can read
-- user_roles / role_permissions / permissions *despite* those tables having RLS
-- enabled. That is what avoids the infinite recursion a naive policy would
-- create, and it means a policy author can never accidentally grant themselves
-- access.
--
-- Contract (docs/RBAC.md):
--   authorisation = permission AND scope
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Identity primitives
-- ---------------------------------------------------------------------------
create or replace function authz.current_user_id()
returns uuid
language sql stable security definer set search_path = ''
as $$ select auth.uid() $$;

create or replace function authz.current_employee_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select e.id
  from public.employees e
  where e.user_id = authz.current_user_id()
    and e.deleted_at is null
  limit 1
$$;

create or replace function authz.current_department_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select e.department_id
  from public.employees e
  where e.user_id = authz.current_user_id()
    and e.deleted_at is null
  limit 1
$$;

-- An account is usable only when the user row is active and the linked employee
-- record is not terminated. Deactivating either one revokes access immediately.
create or replace function authz.is_account_active()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select u.account_status = 'active'
       and u.deleted_at is null
       and (u.locked_until is null or u.locked_until < now())
       and (u.session_absolute_deadline is null
            or u.session_absolute_deadline > now())
     from public.users u
     where u.id = authz.current_user_id()),
    false)
$$;

-- ---------------------------------------------------------------------------
-- Effective permission set
-- ---------------------------------------------------------------------------
create or replace function authz.has_permission(p_key text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r
      on r.id = ur.role_id
     and r.is_active
     and r.deleted_at is null
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where ur.user_id = authz.current_user_id()
      and ur.revoked_at is null
      and (ur.expires_at is null or ur.expires_at > now())
      and p.key = p_key
  )
$$;

create or replace function authz.has_any_permission(p_keys text[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r
      on r.id = ur.role_id and r.is_active and r.deleted_at is null
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where ur.user_id = authz.current_user_id()
      and ur.revoked_at is null
      and (ur.expires_at is null or ur.expires_at > now())
      and p.key = any(p_keys)
  )
$$;

-- ---------------------------------------------------------------------------
-- Scope: which departments / business units does the caller reach?
-- ---------------------------------------------------------------------------
create or replace function authz.department_scope()
returns uuid[]
language sql stable security definer set search_path = ''
as $$
  select coalesce(array_agg(distinct s) filter (where s is not null), '{}'::uuid[])
  from (
    select null::uuid as s
    union all
    select ur.scope_department_id from public.user_roles ur
      join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
     where ur.user_id = authz.current_user_id()
       and ur.revoked_at is null
       and (ur.expires_at is null or ur.expires_at > now())
       and ur.scope_type = 'department'
    union all
    -- A global assignment reaches every department.
    select d.id from public.departments d
     where exists (
       select 1 from public.user_roles ur
        join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
        where ur.user_id = authz.current_user_id()
          and ur.revoked_at is null
          and (ur.expires_at is null or ur.expires_at > now())
          and ur.scope_type = 'global')
  ) t
$$;

create or replace function authz.business_unit_scope()
returns uuid[]
language sql stable security definer set search_path = ''
as $$
  select coalesce(array_agg(distinct s) filter (where s is not null), '{}'::uuid[])
  from (
    select null::uuid as s
    union all
    select ur.scope_business_unit_id from public.user_roles ur
      join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
     where ur.user_id = authz.current_user_id()
       and ur.revoked_at is null
       and (ur.expires_at is null or ur.expires_at > now())
       and ur.scope_type = 'business_unit'
    union all
    select bu.id from public.business_units bu
     where exists (
       select 1 from public.user_roles ur
        join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
        where ur.user_id = authz.current_user_id()
          and ur.revoked_at is null
          and (ur.expires_at is null or ur.expires_at > now())
          and ur.scope_type = 'global')
  ) t
$$;

-- Does the caller hold at least one GLOBAL role assignment?
--
-- This must be a separate question from `department_scope()`. A global holder
-- and someone assigned to all five current departments return the same array
-- from `department_scope()`, and the arrays diverge the moment a sixth
-- department is created. Callers that need to distinguish "reaches everything"
-- from "reaches these five" ask this function instead of counting array length.
create or replace function authz.has_global_scope()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
     where ur.user_id = authz.current_user_id()
       and ur.revoked_at is null
       and (ur.expires_at is null or ur.expires_at > now())
       and ur.scope_type = 'global'
  )
$$;

-- Scoped permission checks ---------------------------------------------------

create or replace function authz.has_permission_in_department(p_key text, p_department_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_permission(p_key)
     and (p_department_id is null or p_department_id = any(authz.department_scope()))
$$;

create or replace function authz.has_permission_in_business_unit(p_key text, p_business_unit_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_permission(p_key)
     and (p_business_unit_id is null or p_business_unit_id = any(authz.business_unit_scope()))
$$;

-- ---------------------------------------------------------------------------
-- Composite checks
-- ---------------------------------------------------------------------------

-- Anything that makes a user "staff" rather than a plain employee account.
create or replace function authz.is_staff()
returns boolean
language sql stable security definer set search_path = ''
as $$
  -- Note: permission keys are unprefixed except for `platform.admin`.
  select authz.has_any_permission(array[
    'platform.admin','settings.manage','audit_logs.view','permissions.manage',
    'employees.view','employees.create','employees.edit',
    'roles.view','roles.manage','roles.assign',
    'website.view','website.edit',
    'vehicles.view','vehicles.create',
    'properties.view','properties.create',
    'agriculture.view','agriculture.create',
    'mining.view','mining.create',
    'finance.view','finance.create_expense','finance.create_income',
    'tasks.view_department','tasks.view_all',
    'group_chats.manage','announcements.create',
    'org.view','org.manage_business_units','org.manage_departments',
    'documents.view','reports.view'
  ])
$$;

-- Is the caller a platform administrator? This is the ONLY definition of
-- "superuser" in the system. It backs `isSuperuser` in
-- src/lib/rbac/guards.ts, so it must stay a single explicit permission rather
-- than anything derived from role name or permission count.
create or replace function authz.is_platform_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_permission('platform.admin')
$$;

-- May the caller read this employee record? Self, or anyone with HR/admin read.
create or replace function authz.can_access_employee(p_target_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.current_user_id() = p_target_user_id
      or authz.has_any_permission(array['employees.view','employees.view_sensitive',
                                         'employees.edit','roles.manage'])
$$;

-- May the caller hand a task to this person?
--
-- Deliberately NOT `can_access_employee(...)`: read access and write authority
-- are different questions, and reusing the read predicate here would let anyone
-- who can see a colleague's record assign them work. A caller must hold
-- `tasks.assign`, or be assigning to themselves, and the target must be an
-- active account — an assignment to a disabled or deleted user is rejected
-- rather than silently accepted.
create or replace function authz.can_assign_task_to(p_target_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
      from public.users u
     where u.id = p_target_user_id
       and u.deleted_at is null
       and u.account_status = 'active'
  )
  and (
    authz.has_permission('tasks.assign')
    or authz.current_user_id() = p_target_user_id
  )
$$;

-- Sensitive HR columns. Used to column-restrict employees reads.
create or replace function authz.can_view_sensitive_employee()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_any_permission(array['employees.view_sensitive','permissions.manage'])
$$;

-- May the caller act on this lead / enquiry?
create or replace function authz.can_access_lead(p_lead_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select l.assigned_to = authz.current_employee_id()
      or authz.has_any_permission(array['leads.view','leads.manage','org.manage_customers'])
    from public.leads l
    where l.id = p_lead_id and l.deleted_at is null
$$;

-- Finance visibility: either general finance read, or the vehicle-finance
-- specific read used by the automobile module.
create or replace function authz.can_view_finance()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_any_permission(array[
    'finance.view','finance.view_all','finance.create_income','finance.create_expense',
    'finance.edit','finance.approve','finance.reports.export',
    'vehicle_finance.view','reports.view_financial'
  ])
$$;

create or replace function authz.can_view_all_finance()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select authz.has_any_permission(array[
    'finance.view_all','finance.edit','finance.approve',
    'finance.create_income','finance.create_expense','reports.view_financial'
  ])
$$;

-- Group chat membership check, usable from message policies.
create or replace function authz.is_group_member(p_group_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.group_chat_members m
    where m.group_id = p_group_id
      and m.user_id = authz.current_user_id()
      and m.removed_at is null
  )
  or authz.has_permission('group_chats.manage')
$$;

create or replace function authz.is_group_admin(p_group_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.group_chat_members m
    where m.group_id = p_group_id
      and m.user_id = authz.current_user_id()
      and m.removed_at is null
      and m.role in ('owner','admin')
  )
  or authz.has_permission('group_chats.manage')
$$;

create or replace function authz.is_thread_participant(p_thread_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.thread_participants tp
    where tp.thread_id = p_thread_id
      and tp.user_id = authz.current_user_id()
      and tp.left_at is null
  )
$$;

-- Task visibility: owner, assignee, watcher, creator, or a team-level read.
create or replace function authz.can_access_task(p_task public.tasks)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_task.created_by = authz.current_user_id()
      or p_task.assigned_to = authz.current_user_id()
      or authz.current_user_id() = any(p_task.watchers)
      or p_task.is_visible_to_all
      or authz.has_permission('tasks.view_all')
      or (p_task.department_id is not null
          and authz.has_permission_in_department('tasks.view_department', p_task.department_id))
      or (p_task.business_unit_id is not null
          and authz.has_permission_in_business_unit('tasks.view_department', p_task.business_unit_id))
$$;

-- Can the caller read this announcement? Audience-aware.
create or replace function authz.can_read_announcement(p_announcement_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.announcements a
    where a.id = p_announcement_id
      and a.deleted_at is null
      and (a.status = 'published' or authz.has_permission('announcements.create'))
      and (
        a.audience_type = 'all'
        or authz.has_permission('announcements.publish')
        or (a.audience_type = 'department'
            and a.audience_department_id = any(authz.department_scope()))
        or (a.audience_type = 'business_unit'
            and a.audience_business_unit_id = any(authz.business_unit_scope()))
        or (a.audience_type = 'roles'
            and exists (
              select 1
              from public.user_roles ur
              join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
              where ur.user_id = authz.current_user_id()
                and ur.revoked_at is null
                and (ur.expires_at is null or ur.expires_at > now())
                and r.id = any(a.audience_role_ids)
            ))
        or (a.audience_type = 'individuals'
            and authz.current_user_id() = any(a.audience_user_ids))
      )
  )
$$;

-- Grants --------------------------------------------------------------------
grant execute on all functions in schema authz to authenticated;
grant execute on all functions in schema authz to anon;
