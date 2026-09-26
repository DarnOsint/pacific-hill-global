-- =============================================================================
-- 0016_public_org.sql
-- The public organisation chart.
--
-- The About page publishes an "org-structure" section describing who is
-- accountable for what, but `public.departments` is an HR table: it carries
-- `head_id` (a user FK) and is governed by permission-gated RLS that
-- deliberately denies anonymous visitors.
--
-- The wrong fix would be a permissive SELECT policy on the base table, which
-- would publish employee identity as a side effect of publishing a chart.
--
-- Instead this migration adds a view that is itself the access-control
-- decision. A view is read with its owner's privileges, so it bypasses the
-- base table's RLS, which means the projection below is the security boundary:
-- only the columns safe to publish are selected, and only active, undeleted
-- rows are visible. `head_id`, `created_by` and `updated_by` are intentionally
-- absent — no individual is named by this view.
-- =============================================================================

create or replace view public.public_org_units as
select
  d.id,
  d.code,
  d.name,
  d.description,
  p.code as parent_code,
  d.sort_order
from public.departments d
left join public.departments p
       on p.id = d.parent_id
      and p.deleted_at is null
where d.deleted_at is null
  and d.is_active;

comment on view public.public_org_units is
  'Public-safe organisation chart. Exposes only publishable columns of active '
  'departments; deliberately omits head_id and audit columns so no employee is '
  'identified. Grants are explicit below.';

-- Grants are stated rather than inherited so the exposure is auditable in one
-- place. `anon` is required for prerendering the marketing site at build time.
grant select on public.public_org_units to anon, authenticated;

revoke all on public.public_org_units from public;

-- ---------------------------------------------------------------------------
-- public_contact : the contact details the website is allowed to publish.
--
-- `company_settings` mixes publishable branding (email, WhatsApp, address) with
-- material that must never reach a public page: `tax_number`,
-- `registration_number`, `base_currency`, `approval_threshold_default` and
-- `feature_flags`. It is also permission-gated to `settings.view`, so the
-- marketing site cannot read it with the anon key at all.
--
-- Granting a broad read policy to fix that would publish the tax number. The
-- projection below names every column that is intended for the public, so the
-- exposure is explicit and reviewable. `phone` is projected but deliberately
-- left null in the seed: the group is WhatsApp-only and a `tel:` link must not
-- be reintroduced by seeding a value here.
-- ---------------------------------------------------------------------------
create or replace view public.public_contact as
select
  company_name,
  legal_name,
  tagline,
  description,
  founded_year,
  email,
  phone,
  whatsapp,
  address,
  city,
  country,
  logo_url,
  social_links
from public.company_settings;

comment on view public.public_contact is
  'Publishable company/contact projection. Excludes tax_number, '
  'registration_number, base_currency, approval_threshold_default and '
  'feature_flags from public.company_settings.';

grant select on public.public_contact to anon, authenticated;

revoke all on public.public_contact from public;
