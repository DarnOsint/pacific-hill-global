#!/usr/bin/env bash
# =============================================================================
# scripts/validate-migrations.sh
#
# Compiles every migration in supabase/migrations against a throwaway PostgreSQL
# database, using supabase/shims/_supabase_shim.sql to stand in for the parts of
# Supabase (the `auth` schema and `auth.*` functions) that only exist on the
# platform.
#
# This catches the class of error that is easy to miss by reading: a column that
# a view references but the table never declared, a function called before it
# exists, a policy referencing an enum value that is not in the type.
#
#   ./scripts/validate-migrations.sh
#
# Requires a reachable PostgreSQL. Set PGHOST/PGPORT/PGUSER, or let it use the
# local defaults. The scratch database is always dropped and recreated.
#
# NOTE: this validates that the SQL *compiles*. It does not validate the security
# posture — that needs the Supabase linter and a review of the RLS policies.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="${PHG_VALIDATION_DB:-phg_migration_check}"

MIGRATIONS_DIR="$ROOT/supabase/migrations"
SHIM="$ROOT/supabase/shims/_supabase_shim.sql"

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "error: $MIGRATIONS_DIR not found" >&2
  exit 1
fi
if [[ ! -f "$SHIM" ]]; then
  echo "error: $SHIM not found" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "error: psql not found on PATH" >&2
  exit 1
fi

# psql aborts a script on the first error only if ON_ERROR_STOP is set. We want
# to stop at the first error, so the reported file and statement are accurate.
export ON_ERROR_STOP=1

echo "==> Recreating scratch database '$DB'"
psql -d postgres -q -v ON_ERROR_STOP=1 \
  -c "drop database if exists \"$DB\";" \
  -c "create database \"$DB\";"

echo "==> Applying Supabase shims"
psql -d "$DB" -q -v ON_ERROR_STOP=1 -f "$SHIM" >/dev/null

failed=0
applied=0

for file in "$MIGRATIONS_DIR"/*.sql; do
  name="$(basename "$file")"
  printf '    %-32s' "$name"
  if output=$(psql -d "$DB" -q -v ON_ERROR_STOP=1 --single-transaction -f "$file" 2>&1); then
    printf 'ok\n'
    applied=$((applied + 1))
  else
    printf 'FAILED\n'
    echo "--- $output" | sed 's/^/    /'
    failed=1
    # Stop at the first failure: later migrations depend on earlier ones, so
    # continuing would report a cascade of misleading errors.
    break
  fi
done

if [[ $failed -ne 0 ]]; then
  echo
  echo "==> MIGRATIONS DID NOT COMPILE"
  exit 1
fi

echo
echo "==> All $applied migrations compiled"

# A cheap structural sanity pass: the objects the application queries by name
# must exist. Missing ones fail at runtime, not at build time, so they are
# worth asserting here.
echo "==> Verifying expected objects exist"
psql -d "$DB" -q -v ON_ERROR_STOP=1 <<'SQL'
do $$
declare
  missing text := '';
  obj      text;
  -- 'schema.function' for functions, 'schema.relation' for tables/views.
  want     text[] := array[
    'public.get_my_permissions',
    'public.write_audit',
    'public.global_search',
    'public.direct_thread_key',
    'public.fx_rate',
    'public.fx_to_base',
    'authz.has_permission',
    'authz.has_permission_in_department',
    'authz.has_permission_in_business_unit',
    'authz.is_platform_admin',
    'authz.has_global_scope',
    'authz.department_scope',
    'authz.business_unit_scope',
    'authz.can_access_task',
    'authz.can_read_announcement',
    'authz.can_assign_task_to',
    'public.property_financials',
    'public.vehicle_financials',
    'public.mining_financials',
    'public.agriculture_financials',
    'public.dashboard_counters'
  ];
begin
  foreach obj in array want loop
    -- to_regclass resolves relations; to_regprocedure needs the full
    -- zero-argument signature. A function is matched on its bare name because
    -- every function the app calls is unique by name in this schema.
    if to_regclass(obj) is null
       and to_regprocedure(obj || '()') is null
       and not exists (
         select 1 from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname || '.' || p.proname = obj
       )
    then
      missing := missing || E'\n      - ' || obj;
    end if;
  end loop;

  if missing <> '' then
    raise exception 'missing expected objects:%', missing;
  end if;

  raise notice 'all % expected objects present', array_length(want, 1);
end
$$;
SQL

if [[ "${PHG_VALIDATION_SEED:-1}" == "1" ]]; then
  echo "==> Applying seeds"
  for file in "$ROOT"/supabase/seed/*.sql; do
    printf '    %-32s' "$(basename "$file")"
    if output=$(psql -d "$DB" -q -v ON_ERROR_STOP=1 --single-transaction -f "$file" 2>&1); then
      printf 'ok\n'
    else
      printf 'FAILED\n'
      echo "--- $output" | sed 's/^/    /'
      exit 1
    fi
  done

  echo
  echo "==> Row counts"
  psql -d "$DB" -q -tA -F ' = ' -c "
    select 'permissions',        count(*) from public.permissions
    union all select 'roles',               count(*) from public.roles
    union all select 'role_permissions',    count(*) from public.role_permissions
    union all select 'currencies',          count(*) from public.currencies
    union all select 'business_units',      count(*) from public.business_units
    union all select 'departments',         count(*) from public.departments
    union all select 'branches',            count(*) from public.branches
    union all select 'website_pages',       count(*) from public.website_pages
    union all select 'website_sections',    count(*) from public.website_sections
    union all select 'testimonials',        count(*) from public.testimonials
    union all select 'company_settings',    count(*) from public.company_settings
    union all select 'approval_rules',      count(*) from public.approval_rules
    order by 1;"
fi

echo
if [[ "${PHG_KEEP_VALIDATION_DB:-0}" == "1" ]]; then
  echo "==> Keeping '$DB' for inspection (PHG_KEEP_VALIDATION_DB=1)"
else
  psql -d postgres -q -c "drop database if exists \"$DB\";"
  echo "==> Dropped '$DB'"
fi
