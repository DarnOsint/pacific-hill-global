-- =============================================================================
-- 0008_comms.sql
-- Internal communication: DMs, group chat, notifications, announcements.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- message_threads : one row per conversation. `kind` distinguishes direct from
-- a thread that is the parent of a group's shared history.
-- ---------------------------------------------------------------------------
create type public.thread_kind as enum ('direct','group');

create table public.message_threads (
  id             uuid primary key default gen_random_uuid(),
  kind           public.thread_kind not null default 'direct',
  subject        text,
  -- deterministic pair key for direct threads: sorted 'uuidA:uuidB'
  direct_key     text unique,
  created_by     uuid references public.users(id) on delete set null,
  last_message_at timestamptz,
  last_message_preview text,
  message_count  integer not null default 0,
  is_archived    boolean not null default false,
  archived_by    uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint message_threads_direct_key_ck check (
    (kind = 'direct'  and direct_key is not null) or
    (kind = 'group'   and direct_key is null)
  )
);

create index message_threads_recent_idx on public.message_threads (last_message_at desc nulls last)
  where not is_archived and deleted_at is null;

-- ---------------------------------------------------------------------------
-- thread_participants : the only place that grants DM read access.
-- ---------------------------------------------------------------------------
create table public.thread_participants (
  thread_id    uuid not null references public.message_threads(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  role         text not null default 'member' check (role in ('owner','admin','member')),
  unread_count integer not null default 0 check (unread_count >= 0),
  last_read_at timestamptz,
  last_read_message_id uuid,
  is_muted     boolean not null default false,
  joined_at    timestamptz not null default now(),
  left_at      timestamptz,
  primary key (thread_id, user_id)
);

create index thread_participants_user_idx on public.thread_participants (user_id) where left_at is null;

-- ---------------------------------------------------------------------------
-- group_chats
-- ---------------------------------------------------------------------------
create table public.group_chats (
  id             uuid primary key default gen_random_uuid(),
  slug           text unique,
  name           text not null,
  description    text,
  purpose        text,
  colour         text check (colour is null or colour ~ '^#[0-9A-Fa-f]{6}$'),
  icon           text,
  avatar_url     text,
  business_unit_id uuid references public.business_units(id) on delete set null,
  department_id  uuid references public.departments(id) on delete set null,
  is_private     boolean not null default true,   -- discoverable in the directory?
  is_announcement_only boolean not null default false, -- read-only broadcast
  created_by     uuid references public.users(id) on delete set null,
  last_message_at timestamptz,
  member_count   integer not null default 0,
  is_archived    boolean not null default false,
  archived_by    uuid references public.users(id) on delete set null,
  archived_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint group_chats_slug_format check (slug is null or slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

create index group_chats_active_idx on public.group_chats (last_message_at desc nulls last)
  where not is_archived and deleted_at is null;

create table public.group_chat_members (
  group_id     uuid not null references public.group_chats(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  role         text not null default 'member' check (role in ('owner','admin','member')),
  unread_count integer not null default 0 check (unread_count >= 0),
  last_read_at timestamptz,
  is_muted     boolean not null default false,
  joined_at    timestamptz not null default now(),
  removed_at   timestamptz,
  removed_by   uuid references public.users(id) on delete set null,
  primary key (group_id, user_id)
);

create index group_chat_members_user_idx on public.group_chat_members (user_id) where removed_at is null;

-- ---------------------------------------------------------------------------
-- messages : one table for DMs and group chat. A message belongs to a thread
-- and optionally to a group; exactly one of (thread_id) / (group_id) is set.
-- ---------------------------------------------------------------------------
create type public.message_kind as enum ('text','file','system','announcement');

create table public.messages (
  id            uuid primary key default gen_random_uuid(),
  thread_id     uuid references public.message_threads(id) on delete cascade,
  group_id      uuid references public.group_chats(id) on delete cascade,
  sender_id     uuid references public.users(id) on delete set null,
  kind          public.message_kind not null default 'text',
  body          text not null,
  reply_to_id   uuid references public.messages(id) on delete set null,
  attachments   jsonb not null default '[]'::jsonb,  -- [{name,path,size,mime}]
  mentions      uuid[] not null default '{}',
  is_edited     boolean not null default false,
  edited_at     timestamptz,
  is_deleted    boolean not null default false,   -- soft delete: body cleared by trigger
  deleted_by    uuid references public.users(id) on delete set null,
  deleted_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint messages_target_ck check (
    (thread_id is not null and group_id is null) or
    (thread_id is null and group_id is not null)
  )
);

create index messages_thread_idx on public.messages (thread_id, created_at)
  where not is_deleted;
create index messages_group_idx  on public.messages (group_id, created_at)
  where not is_deleted;
create index messages_sender_idx on public.messages (sender_id, created_at desc)
  where not is_deleted;
create index messages_body_trgm  on public.messages using gin (body gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- notifications : the single source for the bell, the counters, and (later)
-- web push. Every producer writes here; nothing else renders a badge.
-- ---------------------------------------------------------------------------
create type public.notification_kind as enum
  ('message','group_message','task_assigned','task_due','task_completed',
   'announcement','approval_request','approval_decision','mention','system',
   'document','lead','system_alert');

create table public.notifications (
  id             uuid primary key default gen_random_uuid(),
  recipient_id   uuid not null references public.users(id) on delete cascade,
  kind           public.notification_kind not null,
  title          text not null,
  body           text,
  url            text,
  actor_id       uuid references public.users(id) on delete set null,
  resource_type  text,
  resource_id    uuid,
  metadata       jsonb not null default '{}'::jsonb,
  priority       text not null default 'normal' check (priority in ('low','normal','high')),
  read_at        timestamptz,
  emailed_at     timestamptz,
  created_at     timestamptz not null default now(),
  constraint notifications_no_self check (actor_id is null or actor_id <> recipient_id)
);

create index notifications_inbox_idx on public.notifications (recipient_id, created_at desc);
create index notifications_unread_idx on public.notifications (recipient_id, created_at desc)
  where read_at is null;
create index notifications_actor_idx  on public.notifications (actor_id)
  where actor_id is not null;

-- ---------------------------------------------------------------------------
-- announcements : internal notices, with priority and expiry
-- ---------------------------------------------------------------------------
create type public.announcement_audience as enum
  ('all','department','business_unit','roles','individuals');

create table public.announcements (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  body           text not null,
  priority       text not null default 'normal'
                   check (priority in ('low','normal','high','critical')),
  category       text not null default 'general'
                   check (category in ('general','hr','operations','finance','safety','it','event')),
  audience_type  public.announcement_audience not null default 'all',
  audience_department_id uuid references public.departments(id) on delete cascade,
  audience_business_unit_id uuid references public.business_units(id) on delete cascade,
  audience_role_ids uuid[] not null default '{}',
  audience_user_ids uuid[] not null default '{}',
  require_acknowledgement boolean not null default false,
  attachment_paths jsonb not null default '[]'::jsonb,
  status         public.content_status not null default 'draft',
  published_at   timestamptz,
  published_by   uuid references public.users(id) on delete set null,
  expires_at     timestamptz,
  pinned         boolean not null default false,
  view_count     integer not null default 0,
  ack_count      integer not null default 0,
  author_id      uuid not null references public.users(id) on delete restrict,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint announcements_published_ck check (status <> 'published' or published_at is not null)
);

create index announcements_active_idx on public.announcements (published_at desc)
  where status = 'published' and deleted_at is null;

create table public.announcement_acknowledgements (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id         uuid not null references public.users(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

-- ---------------------------------------------------------------------------
-- message_attachments : object-storage references for message files
-- ---------------------------------------------------------------------------
create table public.message_attachments (
  id           uuid primary key default gen_random_uuid(),
  message_id   uuid not null references public.messages(id) on delete cascade,
  storage_path text not null,
  file_name    text not null,
  mime_type    text not null,
  size_bytes   bigint not null check (size_bytes > 0),
  uploaded_by  uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

create index message_attachments_msg_idx on public.message_attachments (message_id);
