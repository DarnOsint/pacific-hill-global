-- =============================================================================
-- 0012_triggers.sql
-- Triggers: timestamps, audit immutability, referential safety, derived views.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- updated_at on every table that has one
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'users','employees','departments','permissions','roles','user_roles',
    'employee_documents','business_units','branches','customers','suppliers',
    'leads','approval_rules','approvals','website_pages','website_sections',
    'website_media','news_posts','testimonials','company_statistics',
    'company_settings','vehicles','vehicle_expenses','vehicle_repairs',
    'vehicle_shipping','vehicle_sales','vehicle_documents',
    'real_estate_properties','property_sales','property_documents',
    'agricultural_projects','agricultural_costs','agricultural_harvests',
    'mining_projects','mining_costs','mining_production','mining_sales',
    'project_documents','currencies','fx_rates','expenses','income',
    'financial_transactions','financial_periods','budgets',
    'message_threads','group_chats','tasks','task_comments','documents'
  ]
  loop
    execute format(
      'drop trigger if exists trg_%1$s_touch on public.%1$I;
       create trigger trg_%1$s_touch
         before update on public.%1$I
         for each row execute function public.touch_updated_at();',
      t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- audit_logs and activity_feed are append-only for EVERY role
-- ---------------------------------------------------------------------------
drop trigger if exists trg_audit_logs_immutable on public.audit_logs;
create trigger trg_audit_logs_immutable
  before update or delete on public.audit_logs
  for each row execute function public.deny_audit_mutation();

drop trigger if exists trg_approval_decisions_immutable on public.approvals;
create trigger trg_approval_decisions_immutable
  before delete on public.approvals
  for each row execute function public.deny_audit_mutation();

-- ---------------------------------------------------------------------------
-- messaging side effects: unread counters, thread previews, activity.
-- All SECURITY DEFINER so they can write tables the caller cannot write.
-- ---------------------------------------------------------------------------
create or replace function public.bump_thread_on_message()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.message_threads
     set last_message_at = new.created_at,
         last_message_preview = left(new.body, 160),
         message_count = message_count + 1
   where id = new.thread_id;

  if new.mentions is not null and array_length(new.mentions, 1) > 0 then
    insert into public.notifications (recipient_id, kind, title, body, url, actor_id, resource_type, resource_id)
    select m.user_id,
           'mention',
           'You were mentioned',
           left(new.body, 200),
           '/portal/messages/' || new.thread_id,
           new.sender_id,
           'message',
           new.id
      from unnest(new.mentions) as m(user_id)
     where m.user_id is not null
       and m.user_id <> new.sender_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_messages_bump_thread on public.messages;
create trigger trg_messages_bump_thread
  after insert on public.messages
  for each row execute function public.bump_thread_on_message();

-- Group messages increment each member's unread badge (except the sender).
create or replace function public.bump_group_on_message()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.group_chats
     set last_message_at = new.created_at
   where id = new.group_id;

  update public.group_chat_members
     set unread_count = unread_count + 1
   where group_id = new.group_id
     and user_id <> new.sender_id
     and removed_at is null;

  insert into public.notifications (recipient_id, kind, title, body, url, actor_id, resource_type, resource_id)
  select m.user_id, 'group_message', 'New group message', left(new.body, 200),
         '/portal/groups/' || new.group_id, new.sender_id, 'group', new.group_id
    from public.group_chat_members m
   where m.group_id = new.group_id
     and m.user_id <> new.sender_id
     and m.removed_at is null
     and not m.is_muted;

  return new;
end;
$$;

drop trigger if exists trg_messages_bump_group on public.messages;
create trigger trg_messages_bump_group
  after insert on public.messages
  for each row
  when (new.group_id is not null)
  execute function public.bump_group_on_message();

-- Soft-delete a message: clear the body so the content is genuinely gone while
-- the conversation shape is preserved.
create or replace function public.soft_delete_message()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.is_deleted = false and new.is_deleted = true then
    new.body := '[message removed]';
    new.attachments := '[]'::jsonb;
    new.deleted_at := now();
    new.deleted_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_messages_soft_delete on public.messages;
create trigger trg_messages_soft_delete
  before update on public.messages
  for each row execute function public.soft_delete_message();

-- Group member count maintenance
create or replace function public.sync_group_member_count()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.group_chats g
     set member_count = (
       select count(*) from public.group_chat_members m
        where m.group_id = coalesce(new.group_id, old.group_id)
          and m.removed_at is null
     )
   where g.id = coalesce(new.group_id, old.group_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_group_members_count_ins on public.group_chat_members;
create trigger trg_group_members_count_ins
  after insert on public.group_chat_members
  for each row execute function public.sync_group_member_count();

drop trigger if exists trg_group_members_count_upd on public.group_chat_members;
create trigger trg_group_members_count_upd
  after update of removed_at on public.group_chat_members
  for each row execute function public.sync_group_member_count();

-- ---------------------------------------------------------------------------
-- Task lifecycle side effects
-- ---------------------------------------------------------------------------
create or replace function public.sync_task_lifecycle()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'completed' and (old.status is distinct from 'completed') then
    new.completed_at := coalesce(new.completed_at, now());
  end if;
  if new.status = 'cancelled' and (old.status is distinct from 'cancelled') then
    new.cancelled_at := coalesce(new.cancelled_at, now());
  end if;
  if new.assigned_to is not null and new.assigned_to is distinct from old.assigned_to then
    new.assigned_at := coalesce(new.assigned_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tasks_lifecycle on public.tasks;
create trigger trg_tasks_lifecycle
  before update on public.tasks
  for each row execute function public.sync_task_lifecycle();

-- Vehicle status / sale coherence: closing a sale moves the vehicle.
create or replace function public.sync_vehicle_sale_status()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_vehicle uuid := coalesce(new.vehicle_id, old.vehicle_id);
begin
  update public.vehicles v
     set status = case new.status
                    when 'sold'     then 'sold'::public.vehicle_status
                    when 'cancelled' then case when v.status = 'sold'
                                                then 'ready_for_sale'::public.vehicle_status
                                                else v.status end
                    when 'deposit_paid' then 'reserved'::public.vehicle_status
                    else v.status end,
         status_changed_at = now(),
         status_changed_by = auth.uid()
   where v.id = v_vehicle
     and v.deleted_at is null;
  return new;
end;
$$;

drop trigger if exists trg_vehicle_sales_status on public.vehicle_sales;
create trigger trg_vehicle_sales_status
  after update of status on public.vehicle_sales
  for each row
  when (new.status is distinct from old.status)
  execute function public.sync_vehicle_sale_status();

-- Property status / sale coherence.
create or replace function public.sync_property_sale_status()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_property uuid := coalesce(new.property_id, old.property_id);
begin
  update public.real_estate_properties p
     set status = case new.status
                    when 'sold'      then 'sold'::public.property_status
                    when 'cancelled' then case when p.status = 'sold'
                                                then 'available'::public.property_status
                                                else p.status end
                    when 'deposit_paid' then 'reserved'::public.property_status
                    else p.status end,
         status_changed_at = now(),
         date_sold = case when new.status = 'sold'
                          then coalesce(new.sale_date, current_date)
                          else p.date_sold end
   where p.id = v_property
     and p.deleted_at is null;
  return new;
end;
$$;

drop trigger if exists trg_property_sales_status on public.property_sales;
create trigger trg_property_sales_status
  after update of status on public.property_sales
  for each row
  when (new.status is distinct from old.status)
  execute function public.sync_property_sale_status();

-- ---------------------------------------------------------------------------
-- Publishing coherence: published rows must carry a published_at.
-- ---------------------------------------------------------------------------
create or replace function public.sync_publish_timestamp()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'published' and (old.status is distinct from 'published') then
    new.published_at := coalesce(new.published_at, now());
    new.published_by := coalesce(new.published_by, auth.uid());
  end if;
  if new.status = 'draft' then
    new.published_at := null;
    new.published_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_pages_publish on public.website_pages;
create trigger trg_pages_publish
  before update of status on public.website_pages
  for each row execute function public.sync_publish_timestamp();

drop trigger if exists trg_news_publish on public.news_posts;
create trigger trg_news_publish
  before update of status on public.news_posts
  for each row execute function public.sync_publish_timestamp();

-- ---------------------------------------------------------------------------
-- new auth user -> users row (mirrors auth.users into the app profile)
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.users (id, email, email_normalised, full_name, account_status)
  values (
    new.id,
    coalesce(new.email, ''),
    lower(coalesce(new.email, '')),
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1)),
    'pending'
  )
  on conflict (id) do update
     set email = excluded.email,
         email_normalised = excluded.email_normalised;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- reference generation for human-readable document numbers
-- ---------------------------------------------------------------------------
create or replace function public.next_reference(p_prefix text, p_table regclass, p_column text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_count bigint;
begin
  execute format('select count(*) from %s where %I is not null', p_table, p_column)
    into v_count;
  return p_prefix || '-' || to_char(now(), 'YYYY') || '-' || lpad((v_count + 1)::text, 5, '0');
end;
$$;

grant execute on function public.next_reference(text, regclass, text) to authenticated;
