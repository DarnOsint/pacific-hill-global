-- =============================================================================
-- 0017_seed_idempotency.sql
-- Make the CMS seed re-runnable.
--
-- The problem: `company_statistics` and `testimonials` were seeded with a bare
-- `on conflict do nothing`. With no conflict target and no unique constraint to
-- violate, that clause never suppresses anything, so every run of the seed
-- appended another copy of each row. Re-running 004_cms_content.sql doubled
-- both tables (6 stats became 12, 3 testimonials became 6) and the duplicates
-- then rendered on the public homepage.
--
-- The fix has two parts, and the order matters:
--
--   1. Deduplicate first, keeping the oldest row of each group. The unique
--      indexes cannot be created until this runs, because the duplicates would
--      violate them.
--   2. Then add the unique indexes that make the conflict target meaningful.
--
-- A partial index (WHERE deleted_at is null) is used so an editor can soft-delete
-- a row and the Director can later re-add a replacement with the same label
-- without colliding. `company_statistics.label` is the natural key; for
-- testimonials the pair (author_name, sort_order) identifies a seeded
-- placeholder, since quote text is free-form and editable.
-- =============================================================================

-- 1. Deduplicate ------------------------------------------------------------

delete from public.company_statistics a
using public.company_statistics b
 where a.label = b.label
   and a.deleted_at is null
   and b.deleted_at is null
   and a.id > b.id;

delete from public.testimonials a
using public.testimonials b
 where a.author_name = b.author_name
   and a.sort_order = b.sort_order
   and a.deleted_at is null
   and b.deleted_at is null
   and a.id > b.id;

-- 2. Enforce it -------------------------------------------------------------

create unique index company_statistics_label_key
  on public.company_statistics (label)
  where deleted_at is null;

create unique index testimonials_author_sort_key
  on public.testimonials (author_name, sort_order)
  where deleted_at is null;
