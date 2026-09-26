-- =============================================================================
-- 0014_functions.sql
-- Server-callable functions: audit writes, effective permission set, search.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- audit write. audit_logs has no INSERT policy for clients by design; this
-- security-definer function is the only client-writable path, and it fills in
-- actor identity from the session rather than trusting parameters.
-- ---------------------------------------------------------------------------
create or replace function public.write_audit(
  p_action        text,
  p_resource_type text,
  p_resource_id   uuid default null,
  p_resource_label text default null,
  p_summary       text default null,
  p_metadata      jsonb default '{}'::jsonb,
  p_severity      text default 'info'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_actor   uuid := auth.uid();
  v_email   text;
  v_role    text;
  v_ip      inet;
begin
  if v_actor is null then
    raise exception 'audit write requires an authenticated session' using errcode = '28000';
  end if;

  select u.email into v_email from public.users u where u.id = v_actor;
  select r.slug into v_role
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.user_id = v_actor and ur.revoked_at is null
   order by case when r.slug = 'director' then 0 else 1 end
   limit 1;

  v_ip := nullif(current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', '')::inet;

  insert into public.audit_logs
    (actor_id, actor_email, actor_role_slug, action, resource_type, resource_id,
     resource_label, summary, metadata, ip_address, user_agent, severity)
  values
    (v_actor, v_email, v_role, p_action::public.audit_action, p_resource_type,
     p_resource_id, p_resource_label,
     coalesce(p_summary, p_action), coalesce(p_metadata, '{}'::jsonb),
     v_ip,
     nullif(current_setting('request.headers', true)::jsonb ->> 'user-agent', ''),
     coalesce(p_severity, 'info'))
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.write_audit(text, text, uuid, text, text, jsonb, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- effective permission set for the current user.
-- The application calls this once per request to build its UserContext; the
-- database remains the authority (RLS), this is for UI and fast guards.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_permissions()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'userId', authz.current_user_id(),
    'employeeId', authz.current_employee_id(),
    'departmentId', authz.current_department_id(),
    -- The real stored value, not a re-derived approximation. `account_status` is
    -- a text column with a check constraint over
    -- (pending|active|suspended|disabled); collapsing it to a boolean loses the
    -- difference between "never approved" and "suspended by an administrator",
    -- which the login page needs in order to give the right message.
    'accountStatus', coalesce(
      (select u.account_status from public.users u where u.id = auth.uid()),
      'pending'
    ),
    'isActive', authz.is_account_active(),
    'isStaff', authz.is_staff(),
    'isSuperuser', authz.is_platform_admin(),
    -- Explicit global flag. The client must not infer "global" from receiving a
    -- long list of department ids, which silently changes meaning as the
    -- organisation grows.
    'globalScope', authz.has_global_scope(),
    'permissions', coalesce((
      select jsonb_agg(distinct p.key order by p.key)
        from public.user_roles ur
        join public.roles r on r.id = ur.role_id and r.is_active and r.deleted_at is null
        join public.role_permissions rp on rp.role_id = r.id
        join public.permissions p on p.id = rp.permission_id
       where ur.user_id = auth.uid()
         and ur.revoked_at is null
         and (ur.expires_at is null or ur.expires_at > now())
    ), '[]'::jsonb),
    'scopes', jsonb_build_object(
      'departments', to_jsonb(authz.department_scope()),
      'businessUnits', to_jsonb(authz.business_unit_scope())
    )
  )
$$;

grant execute on function public.get_my_permissions() to authenticated;

-- ---------------------------------------------------------------------------
-- direct-message thread key: deterministic pair identifier.
-- ---------------------------------------------------------------------------
create or replace function public.direct_thread_key(a uuid, b uuid)
returns text
language sql immutable
as $$
  select case when a < b then a::text || ':' || b::text else b::text || ':' || a::text end
$$;

-- ---------------------------------------------------------------------------
-- global search. One query, permission-filtered per domain. A sales person
-- must not be able to discover a financial record by searching for it.
-- ---------------------------------------------------------------------------
create or replace function public.global_search(p_query text, p_limit int default 20)
returns table (
  domain      text,
  result_type text,
  result_id   uuid,
  title       text,
  subtitle    text,
  url         text,
  score       real
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_q text := btrim(p_query);
  v_n int := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  if v_q = '' or length(v_q) < 2 then
    return;
  end if;

  -- employees (directory scope) -------------------------------------------
  if authz.is_account_active() then
    return query
    select 'directory', 'employee', e.id, e.full_name,
           coalesce(e.job_title, '') || ' · ' || coalesce(d.name, ''),
           '/portal/directory?employee=' || e.id,
           ts_rank(to_tsvector('english', coalesce(e.full_name,'') || ' ' || coalesce(e.job_title,'') || ' ' || coalesce(e.employee_number,'')),
                   plainto_tsquery('english', v_q))
      from public.employees e
      left join public.departments d on d.id = e.department_id
     where e.deleted_at is null
       and (e.user_id = authz.current_user_id() or authz.has_permission('employees.view'))
       and (e.full_name || ' ' || coalesce(e.job_title,'') || ' ' || coalesce(e.employee_number,''))
           ilike '%' || v_q || '%'
     order by 2 desc
     limit v_n;
  end if;

  -- vehicles ---------------------------------------------------------------
  if authz.has_permission('vehicles.view') then
    return query
    select 'vehicles', 'vehicle', v.id,
           v.stock_number || ' — ' || v.make || ' ' || v.model,
           coalesce(v.chassis_number, ''), '/admin/vehicles/' || v.id, 0.9::real
      from public.vehicles v
     where v.deleted_at is null
       and (v.make || ' ' || v.model || ' ' || v.stock_number || ' ' || coalesce(v.chassis_number,''))
           ilike '%' || v_q || '%'
     order by v.created_at desc
     limit v_n;
  end if;

  -- properties -------------------------------------------------------------
  if authz.has_permission('properties.view') then
    return query
    select 'realestate', 'property', p.id, p.title,
           p.property_type::text || ' · ' || coalesce(p.city, p.country),
           '/admin/properties/' || p.id, 0.9::real
      from public.real_estate_properties p
     where p.deleted_at is null
       and (p.title || ' ' || p.code || ' ' || coalesce(p.city,'') || ' ' || coalesce(p.country,''))
           ilike '%' || v_q || '%'
     order by p.created_at desc
     limit v_n;
  end if;

  -- projects (agriculture + mining) ---------------------------------------
  if authz.has_permission('agriculture.view') then
    return query
    select 'agriculture', 'project', a.id, a.name,
           a.crop || ' · ' || coalesce(a.locality, a.country),
           '/admin/agriculture/' || a.id, 0.8::real
      from public.agricultural_projects a
     where a.deleted_at is null
       and (a.name || ' ' || a.code || ' ' || a.crop || ' ' || coalesce(a.locality,''))
           ilike '%' || v_q || '%'
     limit v_n;
  end if;

  if authz.has_permission('mining.view') then
    return query
    select 'mining', 'project', m.id, m.name,
           coalesce(m.mineral, '') || ' · ' || coalesce(m.locality, m.country),
           '/admin/mining/' || m.id, 0.8::real
      from public.mining_projects m
     where m.deleted_at is null
       and (m.name || ' ' || m.code || ' ' || coalesce(m.mineral,'') || ' ' || coalesce(m.locality,''))
           ilike '%' || v_q || '%'
     limit v_n;
  end if;

  -- customers / suppliers --------------------------------------------------
  if authz.has_permission('org.manage_customers') then
    return query
    select 'customers', 'customer', c.id, c.display_name,
           coalesce(c.country, ''), '/admin/customers/' || c.id, 0.7::real
      from public.customers c
     where c.deleted_at is null and c.display_name ilike '%' || v_q || '%'
     limit v_n;
  end if;

  -- documents --------------------------------------------------------------
  if authz.has_permission('documents.view') then
    return query
    select 'documents', 'document', d.id, d.title,
           d.domain || ' · ' || d.file_name, '/portal/documents/' || d.id, 0.6::real
      from public.documents d
     where d.deleted_at is null
       and not d.is_archived
       and (d.confidentiality in ('public','internal')
            or authz.has_permission('documents.view_sensitive'))
       and (d.title || ' ' || d.file_name) ilike '%' || v_q || '%'
     limit v_n;
  end if;

  -- tasks ------------------------------------------------------------------
  return query
  select 'tasks', 'task', t.id, t.title,
         t.status::text || ' · ' || coalesce(to_char(t.due_at,'DD Mon'), 'no due date'),
         '/portal/tasks/' || t.id, 0.5::real
    from public.tasks t
   where t.deleted_at is null
     and authz.can_access_task(t.*)
     and (t.title || ' ' || coalesce(t.description,'')) ilike '%' || v_q || '%'
   limit v_n;
end;
$$;

grant execute on function public.global_search(text, int) to authenticated;
