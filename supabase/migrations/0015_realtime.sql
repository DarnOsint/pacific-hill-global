-- =============================================================================
-- 0015_realtime.sql
-- Realtime publication for live chat, notifications and task updates.
--
-- RLS is applied to realtime as well, so a subscriber only receives rows their
-- policies already allow. Adding a table here does not weaken security.
--
-- Realtime is a convenience, not a requirement: if the publication is absent
-- (self-hosted Postgres, a restored dump without publication state) the rest of
-- the platform still works and the UI falls back to polling. So the whole
-- migration is guarded on the publication existing, not just on each table
-- being absent from it.
-- ============================================================================

do $$
declare
  v_pubname constant text := 'supabase_realtime';
  v_table   text;
  v_targets constant text[] := array[
    'messages', 'notifications', 'tasks', 'group_chat_members', 'approvals'
  ];
begin
  if not exists (select 1 from pg_publication where pubname = v_pubname) then
    raise notice
      'publication % does not exist; skipping realtime publication setup', v_pubname;
    return;
  end if;

  foreach v_table in array v_targets loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname = v_pubname and schemaname = 'public' and tablename = v_table
    ) then
      execute format('alter publication %I add table public.%I', v_pubname, v_table);
      raise notice 'added public.% to publication %', v_table, v_pubname;
    end if;
  end loop;
exception
  when undefined_object then
    -- A table was dropped by a later migration. Realtime is optional, so note
    -- it and continue rather than failing the deployment.
    raise warning 'realtime setup skipped: %', sqlerrm;
end $$;
