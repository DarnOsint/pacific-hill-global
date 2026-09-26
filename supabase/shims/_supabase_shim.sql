-- =============================================================================
-- shims/_supabase_shim.sql
--
-- Validation harness only. NOT part of the deployment migrations.
--
-- The schema is written against Supabase, which provides an `auth` schema and a
-- handful of `auth.*` SQL functions. To verify the migrations compile we
-- reproduce that surface in a plain PostgreSQL database.
--
-- This file must never be applied to a real database. It is applied only by
-- scripts/validate-migrations.sh, into a scratch database.
-- ============================================================================

create schema if not exists auth;

-- Minimal stand-in for auth.users. Only the columns the schema references.
create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  email_confirmed_at timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  user_meta_data     jsonb not null default '{}'::jsonb
);

-- Supabase exposes these as SQL functions callable from policies and triggers.
-- They read GUCs that the harness sets per simulated session.
create or replace function auth.uid() returns uuid
  language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.email() returns text
  language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.email', true), '');
$$;

create or replace function auth.role() returns text
  language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon');
$$;

create or replace function auth.jwt() returns jsonb
  language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

-- The Supabase dashboard/editor role used by the seed scripts. Our roles are
-- declared by migration 0011, but the grants below are the Supabase defaults.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant usage on schema public, auth to anon, authenticated, service_role;
