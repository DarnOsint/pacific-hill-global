-- =============================================================================
-- 0000_extensions.sql
-- Extensions, schemas, and shared helpers.
-- =============================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid, digest
create extension if not exists "pg_trgm";    -- fuzzy search on names/codes
create extension if not exists "unaccent";   -- accent-insensitive search
create extension if not exists "btree_gin";

-- Dedicated schema for authorisation helpers so RLS policies can call them
-- without exposing them in the public API surface.
create schema if not exists authz;
revoke all on schema authz from public;
grant usage on schema authz to authenticated;

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Immutable audit log guard: audit_logs must never be updated or deleted.
-- ---------------------------------------------------------------------------
create or replace function public.deny_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'audit_logs is append-only (attempted %)', tg_op
    using errcode = '42501';
end;
$$;

-- ---------------------------------------------------------------------------
-- Guard: block UPDATE/DELETE on append-only tables regardless of role
-- (including service_role, which bypasses RLS but not triggers).
-- ---------------------------------------------------------------------------
create or replace function public.deny_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'table % is append-only; % is not permitted', tg_table_name, tg_op
    using errcode = '42501';
end;
$$;
