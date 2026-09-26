-- =============================================================================
-- seed/004_cms_content.sql
-- Default public website content: pages, homepage sections, statistics,
-- testimonials and news placeholders. All editable by the Director in the CMS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------
insert into public.website_pages (slug, title, subtitle, template, status, is_system, show_in_nav, nav_label, nav_order, published_at)
values
('',        'Pacific Hill Global',            'Diversified business. Enduring value.',        'homepage', 'published', true,  true,  'Home',      10, now()),
('about',    'About Pacific Hill Global',     'Who we are and how we operate',                  'standard', 'published', true,  true,  'About',     20, now()),
('businesses','Our Businesses',               'Six operating sectors, one accountable group',   'listing',  'published', true,  true,  'Businesses',30, now()),
('news',     'News & Updates',                'Announcements from across the group',           'listing',  'published', true,  true,  'News',      40, now()),
('contact',  'Contact Us',                    'Reach our offices and our team',                'contact',  'published', true,  true,  'Contact',   50, now()),
('legal/privacy', 'Privacy Policy',           'How we handle information',                     'legal',    'published', true,  false, null, 0,   now()),
('legal/terms',   'Terms of Use',             'Terms governing use of this site',               'legal',    'published', true,  false, null, 0,   now())
on conflict (slug) do update
   set title = excluded.title, subtitle = excluded.subtitle, template = excluded.template;

-- Additional public pages that are driven by business-unit rows.
do $$
declare
  u record;
begin
  for u in select slug, short_name from public.business_units where public_visible and is_active loop
    insert into public.website_pages (slug, title, subtitle, template, status, is_system, show_in_nav, nav_label, nav_order, published_at)
    values ('businesses/' || u.slug, u.short_name, null, 'standard', 'published', false, false, null, 0, now())
    on conflict (slug) do update set title = excluded.title;
  end loop;
end $$;

-- Public inventory / listings pages.
insert into public.website_pages (slug, title, subtitle, template, status, is_system, show_in_nav, nav_label, nav_order, published_at)
values
('vehicles',   'Vehicle Inventory', 'Vehicles available for sale',            'listing', 'published', false, true, 'Vehicles',  25, now()),
('properties', 'Property Listings', 'Land, homes and commercial properties',  'listing', 'published', false, true, 'Properties',27, now())
on conflict (slug) do update set title = excluded.title;

-- ---------------------------------------------------------------------------
-- Homepage sections
-- Insert keyed on (page_id, section_key) so re-running the seed is safe.
-- ---------------------------------------------------------------------------
insert into public.website_sections
  (page_id, section_key, section_type, eyebrow, heading, subheading, content, cta_label, cta_href,
   secondary_cta_label, secondary_cta_href, background, layout, sort_order, is_required, is_visible)
select p.id, v.section_key, v.section_type, v.eyebrow, v.heading, v.subheading,
       -- `summary` is the short lead shown under a heading. It has no column of
       -- its own, so it is merged into the content document. Rows that do not
       -- provide one yield null and are stripped.
       v.content::jsonb || jsonb_strip_nulls(jsonb_build_object('summary', v.summary)),
       v.cta_label, v.cta_href, v.secondary_cta_label, v.secondary_cta_href,
       v.background, v.layout, v.sort_order, v.is_required, true
  from public.website_pages p
  cross join (values
  ('hero','hero','Group',
   'Pacific Hill Global',
   'Diversified business. Enduring value.',
   null,
   jsonb_build_object(
     'kicker', 'A diversified business group operating across Africa and beyond',
     'lead', 'We build and operate businesses where disciplined capital, local knowledge and long-term commitment create real, durable value.',
     'image', '/images/hero/hero-main.jpg',
     'imageAlt', 'Pacific Hill Global corporate operations',
     'stats', jsonb_build_array(
       jsonb_build_object('label','Business sectors','value','6'),
       jsonb_build_object('label','Vehicles delivered','value','2,400+'),
       jsonb_build_object('label','Hectares under management','value','3,100'),
       jsonb_build_object('label','Years of operation','value','10+')
     )
   ),
   'Explore our businesses','/businesses','Talk to our team','/contact',
   'dark','default', 10, true),

  ('introduction','prose','Who we are',
   'One group, six operating businesses',
   'Capital, management and accountability under a single roof.',
   null,
   jsonb_build_object(
     'lead', 'Pacific Hill Global was built on a simple conviction: businesses do better when they share governance, capital and operational discipline. Rather than spread our attention thinly, we concentrate on sectors we understand and hold ourselves to a standard in each of them.',
     'body', E'We invest with a long horizon. We employ locally and develop our people. We document every transaction and treat our counterparties and communities with respect. It is an unglamorous way to run a group of businesses, and it is the reason our work repeats.\n\nEach of our sectors is run as a distinct operation with its own management, targets and reporting — held together by a common set of financial controls, a single company account structure, and governance that reports to the Director.',
     'pillars', jsonb_build_array(
       jsonb_build_object('title','Accountability','body','Every transaction is recorded, approved against a threshold, and visible in the company ledger.'),
       jsonb_build_object('title','Local understanding','body','We operate with the people and the regulatory reality of each market we enter.'),
       jsonb_build_object('title','Long horizons','body','We build for durable value rather than short-term turnover, in assets and in people.')
     )
   ),
   null,null,null,null,'muted','split', 20, true),

  ('businesses','business-grid','What we do',
   'Our businesses',
   'Six sectors. One operating standard.',
   null,
   '{}'::jsonb,
   'View all businesses','/businesses',null,null,
   'default','cards', 30, true),

  ('why','feature-list','Why Pacific Hill Global',
   'Why work with us',
   'A counterparty that finishes what it starts.',
   null,
   jsonb_build_object(
     'items', jsonb_build_array(
       jsonb_build_object('title','Documented and traceable','body','Clear title, clean paperwork and records you can verify. We do not ask for trust we have not earned.'),
       jsonb_build_object('title','One point of contact','body','A single relationship manager across vehicles, property, land and trade — not a queue of departments.'),
       jsonb_build_object('title','Transparent pricing','body','The cost of what we do is stated up front: acquisition, freight, clearing, preparation and margin, itemised.'),
       jsonb_build_object('title','After-sales support','body','Registration, transfer, servicing support and spare parts sourcing continue long after the sale.')
     )
   ),
   null,null,null,null,'muted','cards', 40, false),

  ('sectors','sector-cards','Sector spotlight',
   'Inside our operations',
   'How each business runs',
   null,
   '{}'::jsonb,
   null,null,null,null,
   'default','cards', 50, false),

  ('statistics','stat-strip','By the numbers',
   'Pacific Hill Global at a glance',
   'Our scale today',
   null,
   '{}'::jsonb,
   null,null,null,null,
   'brand','stat-strip', 60, false),

  ('news','news-list','Latest updates',
   'News & updates',
   'Recent from the group',
   null,
   jsonb_build_object('limit', 3),
   'All updates','/news',null,null,
   'default','default', 70, false),

  ('testimonials','testimonials','Client perspective',
   'What our clients say',
   'Built on completed work',
   null,
   '{}'::jsonb,
   null,null,null,null,
   'muted','cards', 75, false),

  ('contact_cta','contact','Get in touch',
   'Start a conversation',
   'Tell us what you are looking to do',
   'Whether you are sourcing vehicles, looking for land, planning an import or exploring an investment, the first conversation costs nothing and usually saves time.',
   jsonb_build_object('showChannels', true, 'showForm', true),
   'Send an enquiry','/contact',null,null,
   'dark','split', 80, true)
  ) as v(section_key, section_type, eyebrow, heading, subheading, summary, content,
        cta_label, cta_href, secondary_cta_label, secondary_cta_href,
        background, layout, sort_order, is_required)
 where p.slug = ''
on conflict (page_id, section_key) do update
   set heading = excluded.heading,
       subheading = excluded.subheading,
       content = excluded.content,
       cta_label = excluded.cta_label,
       cta_href = excluded.cta_href,
       background = excluded.background,
       layout = excluded.layout,
       sort_order = excluded.sort_order,
       is_visible = true;

-- ---------------------------------------------------------------------------
-- About page sections
-- ---------------------------------------------------------------------------
insert into public.website_sections
  (page_id, section_key, section_type, eyebrow, heading, subheading, content, background, layout, sort_order)
select p.id, v.section_key, v.section_type, v.eyebrow, v.heading, v.subheading,
       -- `summary` is the short lead a section shows under its heading. It has
       -- no column of its own, so it is merged into the content document rather
       -- than dropped.
       v.content::jsonb || jsonb_strip_nulls(jsonb_build_object('summary', v.summary)),
       v.background, v.layout, v.sort_order
  from public.website_pages p
  cross join (values
  ('page_hero','page-hero',null,'About Pacific Hill Global','Who we are','From a single vehicle trading operation to a diversified group.','{}'::jsonb,'dark','default',10),
  ('story','prose',null,'Our story','How we grew','Six sectors built one at a time, on the same operating principle.',
    jsonb_build_object(
      'lead','Pacific Hill Global began in vehicle trading. The discipline that business demanded — clear sourcing, honest pricing, reliable delivery — turned out to be useful everywhere else we went.',
      'body',E'We moved into property and land when our own clients asked us to. Into agriculture and mining when we could secure properly documented, genuinely productive assets rather than speculative claims. Into logistics and importation because our own supply chain needed to be better than the one we were paying for.\n\nEach addition was a deliberate extension of the same capability: acquire responsibly, document completely, operate actively, and account for every shilling.',
      'pillars', jsonb_build_array(
        jsonb_build_object('title','Leadership','body','Executive oversight across all sectors, with a Director holding final accountability for capital allocation and disclosure.'),
        jsonb_build_object('title','Operations','body','Sector-level management with departmental support in finance, administration, human resources and technology.'),
        jsonb_build_object('title','Governance','body','Approval thresholds, a consolidated ledger, and a full audit trail on every material action.')
      )
    ),'muted','split',20),
  ('values','value-grid',null,'What we hold to','Our values','Four commitments we are willing to be measured against.',
    jsonb_build_object('items', jsonb_build_array(
      jsonb_build_object('title','Honesty in every number','body','Our financial records are complete. If a figure is not known, it is reported as unknown rather than estimated.'),
      jsonb_build_object('title','Property with clean title','body','We acquire land and property only where documentation is verifiable and transferable.'),
      jsonb_build_object('title','People before output','body','We hire locally, train deliberately and retain the people who know the work.'),
      jsonb_build_object('title','Community presence','body','Our operations are built in the regions they serve, with a genuine local stake.')
    )),'default','cards',30),
  ('structure','org-structure',null,'How we are structured','Departments and business units','A short org chart that says who is accountable for what.','{}'::jsonb,'default','default',40)
  ) as v(section_key, section_type, eyebrow, heading, subheading, summary, content, background, layout, sort_order)
 where p.slug = 'about'
on conflict (page_id, section_key) do update
   set heading = excluded.heading, content = excluded.content, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Company statistics
-- ---------------------------------------------------------------------------
insert into public.company_statistics (label, value, suffix, icon, sort_order, is_public)
values
('Business sectors',        6,     '',  'layers',    10, true),
('Vehicles sourced',        2400,  '+', 'car',       20, true),
('Hectares managed',        3100,  '',  'sprout',    30, true),
('Properties transacted',   380,   '+', 'building',  40, true),
('Years operating',         10,    '+', 'calendar',  50, true),
('Employees',               120,   '+', 'users',     60, true)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Testimonials (clearly illustrative; the Director edits or removes these)
-- ---------------------------------------------------------------------------
insert into public.testimonials (quote, author_name, author_title, author_company, rating, status, sort_order)
values
('They delivered exactly what was promised, on the date they said, with the paperwork already in order. That is rarer than it should be.',
 'Verified client', 'Vehicle purchaser', 'Private buyer', 5, 'published', 10),
('We inspected the land before paying and found the title issue their lawyer had already flagged. No surprises afterwards.',
 'Land acquisition client', 'Director', 'Agribusiness group', 5, 'published', 20),
('Clear communication throughout a long import. Every cost was shown to us as it was incurred, which is exactly what we needed.',
 'Import client', 'Managing Director', 'Retail group', 5, 'published', 30)
on conflict do nothing;
