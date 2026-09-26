#!/usr/bin/env bash
#
# Apply the seed files to a real database.
#
# `npm run db:validate` proves the seeds run against a throwaway local database.
# This script is the other half: it applies the same files to the database named
# by DATABASE_URL, which is what you want for a development or preview Supabase
# project.
#
# It is deliberately NOT wired into `npm run build` or any deploy step. Seeds are
# developer data, not schema; production gets migrations only. Running this
# against production would overwrite content an editor has changed.
#
# Every file is applied in a single transaction so a failure part-way through
# leaves the database untouched rather than half-seeded.
#
# Usage:
#   DATABASE_URL='postgresql://...' npm run db:seed
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "error: DATABASE_URL is not set." >&2
  echo "" >&2
  echo "Use the Supabase connection string for the project you want to seed," >&2
  echo "for example:" >&2
  echo "  DATABASE_URL='postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres' \\" >&2
  echo "    npm run db:seed" >&2
  echo "" >&2
  echo "To validate the seeds without touching a real database, use:" >&2
  echo "  npm run db:validate" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "error: psql is not on PATH. Install the PostgreSQL client tools." >&2
  exit 1
fi

echo "==> Applying seeds to the configured database"
for file in "$ROOT"/supabase/seed/*.sql; do
  printf '    %-32s' "$(basename "$file")"
  if output=$(psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 --single-transaction -f "$file" 2>&1); then
    printf 'ok\n'
  else
    printf 'FAILED\n'
    echo "$output" | sed 's/^/    /'
    exit 1
  fi
done

echo
echo "==> Resulting content"
psql "$DATABASE_URL" -q -tA -F ' = ' -c "
  select 'website_pages',       count(*) from public.website_pages
  union all select 'website_sections', count(*) from public.website_sections
  union all select 'business_units',   count(*) from public.business_units
  union all select 'testimonials',     count(*) from public.testimonials
  union all select 'company_settings', count(*) from public.company_settings
  order by 1;"
