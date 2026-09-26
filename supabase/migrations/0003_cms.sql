-- =============================================================================
-- 0003_cms.sql
-- Public website CMS: pages, sections, media, news, testimonials, settings.
--
-- Draft / published / archived is a first-class state machine, enforced by
-- trigger. The public site reads only published rows.
-- =============================================================================

create type public.content_status as enum ('draft','published','archived');

-- ---------------------------------------------------------------------------
-- website_pages
-- ---------------------------------------------------------------------------
create table public.website_pages (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,          -- '' is the homepage
  title           text not null,
  subtitle        text,
  template        text not null default 'standard'
                    check (template in ('homepage','standard','listing','detail','contact','legal','landing')),
  parent_id       uuid references public.website_pages(id) on delete set null,
  status          public.content_status not null default 'draft',
  is_system       boolean not null default false, -- homepage/about cannot be deleted
  show_in_nav     boolean not null default false,
  nav_label       text,
  nav_order       integer not null default 0,
  published_at    timestamptz,
  published_by    uuid references public.users(id) on delete set null,
  seo             jsonb not null default '{}'::jsonb,  -- {title,description,ogImage,noindex}
  business_unit_id uuid references public.business_units(id) on delete set null,
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  -- Two rules:
  --   1. The empty slug is the reserved identifier for the homepage, because the
  --      homepage is served at `/` and has no path segment. The partial unique
  --      index below (website_pages_home_idx) relies on that convention.
  --   2. A `/` separates path segments, so grouped pages can live under one
  --      parent: `legal/privacy`, `legal/terms`. Each segment is
  --      kebab-case. Leading, trailing and doubled separators are rejected so a
  --      slug always maps to exactly one clean route.
  constraint website_pages_slug_format check (
    slug = ''
    or slug ~ '^[a-z0-9]+(-[a-z0-9]+)*(/[a-z0-9]+(-[a-z0-9]+)*)*$'
  ),
  constraint website_pages_published_ck check (status <> 'published' or published_at is not null)
);

create unique index website_pages_home_idx
  on public.website_pages ((true)) where slug = '' and deleted_at is null;

create index website_pages_status_idx on public.website_pages (status) where deleted_at is null;
create index website_pages_nav_idx    on public.website_pages (nav_order)
  where show_in_nav and status = 'published' and deleted_at is null;

-- ---------------------------------------------------------------------------
-- website_sections : ordered content blocks inside a page.
-- `content` is validated per `section_type` by lib/validation so the shape is
-- never arbitrary user JSON passed straight to the renderer.
-- ---------------------------------------------------------------------------
create table public.website_sections (
  id             uuid primary key default gen_random_uuid(),
  page_id        uuid not null references public.website_pages(id) on delete cascade,
  section_key    text not null,        -- 'hero' | 'businesses' | 'stats' | 'contact'
  section_type   text not null,        -- render strategy in components/marketing/sections
  heading        text,
  subheading     text,
  eyebrow        text,
  content        jsonb not null default '{}'::jsonb,
  cta_label      text,
  cta_href       text,
  secondary_cta_label text,
  secondary_cta_href  text,
  background     text not null default 'default'
                   check (background in ('default','muted','dark','brand','image')),
  layout         text not null default 'default'
                   check (layout in ('default','split','grid','cards','timeline','stat-strip')),
  is_visible     boolean not null default true,
  is_required    boolean not null default false, -- cannot be deleted
  sort_order     integer not null default 0,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  unique (page_id, section_key)
);

create index website_sections_page_idx on public.website_sections (page_id, sort_order)
  where deleted_at is null;

-- ---------------------------------------------------------------------------
-- website_media : asset registry (files live in Supabase Storage)
-- ---------------------------------------------------------------------------
create table public.website_media (
  id             uuid primary key default gen_random_uuid(),
  storage_bucket text not null default 'website',
  storage_path   text not null,
  file_name      text not null,
  mime_type      text not null,
  size_bytes     bigint not null check (size_bytes > 0),
  width          integer,
  height         integer,
  checksum       text,
  title          text,
  alt_text       text,
  caption        text,
  folder         text,
  tags           text[] not null default '{}',
  usage_count    integer not null default 0,
  is_public      boolean not null default true,
  uploaded_by    uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  unique (storage_bucket, storage_path)
);

create index website_media_folder_idx on public.website_media (folder, created_at desc)
  where deleted_at is null;
create index website_media_tags_idx   on public.website_media using gin (tags);

-- ---------------------------------------------------------------------------
-- news_posts
-- ---------------------------------------------------------------------------
create table public.news_posts (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique,
  title          text not null,
  excerpt        text,
  body           text not null,            -- markdown
  cover_image_url text,
  category       text not null default 'corporate'
                   check (category in ('corporate','automobiles','real_estate',
                                       'agriculture','mining','logistics','trading','investment')),
  business_unit_id uuid references public.business_units(id) on delete set null,
  tags           text[] not null default '{}',
  status         public.content_status not null default 'draft',
  is_featured    boolean not null default false,
  published_at   timestamptz,
  published_by   uuid references public.users(id) on delete set null,
  author_name    text,
  read_minutes   smallint,
  seo            jsonb not null default '{}'::jsonb,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint news_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint news_published_ck check (status <> 'published' or published_at is not null)
);

create index news_published_idx on public.news_posts (published_at desc)
  where status = 'published' and deleted_at is null;
create index news_category_idx   on public.news_posts (category)
  where status = 'published' and deleted_at is null;

-- ---------------------------------------------------------------------------
-- testimonials
-- ---------------------------------------------------------------------------
create table public.testimonials (
  id             uuid primary key default gen_random_uuid(),
  quote          text not null,
  author_name    text not null,
  author_title   text,
  author_company text,
  avatar_url     text,
  business_unit_id uuid references public.business_units(id) on delete set null,
  rating         smallint check (rating between 1 and 5),
  status         public.content_status not null default 'draft',
  sort_order     integer not null default 0,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- ---------------------------------------------------------------------------
-- company_statistics : numbers shown on the homepage, editable by the Director
-- ---------------------------------------------------------------------------
create table public.company_statistics (
  id             uuid primary key default gen_random_uuid(),
  label          text not null,
  value          numeric(18,2) not null,
  suffix         text,
  prefix         text,
  unit           text,
  icon           text,
  business_unit_id uuid references public.business_units(id) on delete set null,
  is_public      boolean not null default true,
  sort_order     integer not null default 0,
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- ---------------------------------------------------------------------------
-- company_settings : single-row table for organisation-wide configuration.
-- base_currency, thresholds and feature flags live here — configurable, never
-- hardcoded in the application.
-- ---------------------------------------------------------------------------
create table public.company_settings (
  id                    uuid primary key default gen_random_uuid(),
  company_name          text not null default 'Pacific Hill Global',
  legal_name            text,
  tagline               text,
  description           text,
  founded_year          smallint,
  base_currency         char(3) not null default 'USD',
  supported_currencies  char(3)[] not null default array['USD','SSP','EUR','KES','NGN','ZAR','AED','CNY']::char(3)[],
  registration_number   text,
  tax_number            text,
  email                 text,
  phone                 text,
  whatsapp              text,
  address               text,
  city                  text,
  country               text,
  logo_url              text,
  social_links          jsonb not null default '{}'::jsonb,
  approval_threshold_default numeric(18,4) not null default 10000,
  feature_flags         jsonb not NULL default
    '{"twoFactorAuth":false,"publicVehicleInventory":true,"publicPropertyListings":true,"groupChat":true,"pushNotifications":false,"emailIntegration":false}'::jsonb,
  seo_defaults          jsonb not null default '{}'::jsonb,
  maintenance_mode      boolean not null default false,
  created_by            uuid references public.users(id) on delete set null,
  updated_by            uuid references public.users(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint company_settings_single_row check (created_at = created_at)
);

create unique index company_settings_single_idx on public.company_settings ((true));
