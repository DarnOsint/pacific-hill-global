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
('homepage',  'Pacific Hill Global',            'Diversified business. Enduring value.',        'homepage', 'published', true,  true,  'Home',      10, now()),
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

-- The earlier draft shipped standalone `vehicles` and `properties` listing
-- pages. Both are superseded: inventory now lives on the per-business-unit
-- pages under /businesses/<slug>, and the primary nav links to /businesses.
-- Leaving these rows in place put two visible nav links in front of 404s, so
-- they are removed here. `on conflict do update` above cannot express a delete,
-- hence the explicit delete for re-runnable seeds.
delete from public.website_pages where slug in ('vehicles', 'properties');

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
 where p.slug = 'homepage'
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
-- Conflict target must name the unique index created in 0017, otherwise
-- `do nothing` suppresses nothing and re-running this seed duplicates the rows.
on conflict (label) where deleted_at is null do nothing;

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
on conflict (author_name, sort_order) where deleted_at is null do nothing;

-- ---------------------------------------------------------------------------
-- Legal and contact page content
--
-- These pages exist as `website_pages` rows but shipped with no sections, so
-- every one of them rendered the "coming soon" empty state on a live domain.
-- Sections are added here for the same key-on-(page_id, section_key) reason as
-- above, which keeps the seed re-runnable.
-- ---------------------------------------------------------------------------

-- Privacy policy: one page-hero to carry the title, one prose block for the
-- substance. Written as a real notice rather than a placeholder so the page is
-- publishable; review with counsel before relying on it commercially.
insert into public.website_sections
  (page_id, section_key, section_type, eyebrow, heading, subheading, content, background, layout, sort_order, is_required, is_visible)
select p.id, v.section_key, v.section_type, v.eyebrow, v.heading, v.subheading,
       v.content, v.background, v.layout, v.sort_order, v.is_required, true
  from public.website_pages p
  cross join (values
  ('page-hero','page-hero',null,
   'Privacy Policy',
   'How we handle information',
   null,
   jsonb_build_object('lead','This policy explains what information Pacific Hill Global collects through this website, why we collect it, and the choices available to you.'),
   'dark','default',10,false),

  ('privacy-terms','prose',null,
   'What we collect',
   'Information you give us, and information we observe',
   null,
   jsonb_build_object(
     'lead','We collect only what is needed to respond to an enquiry, to operate the staff portal, or to meet a legal obligation. We do not sell personal information.',
     'body', E'You provide information when you contact us — typically your name, email address, phone number and the substance of your enquiry. If you are a staff user, we hold the account details needed to identify you and to record your activity.\n\nWe also record limited technical information, such as the IP address and time of a request, for security and to investigate abuse.\n\nEnquiries submitted through this site are routed to the relevant operating business and retained only as long as needed to deal with the matter.'
   ),
   'muted','default',20,false),

  ('privacy-use','prose',null,
   'How we use it',
   'Purpose and lawful basis',
   null,
   jsonb_build_object(
     'body', E'We use your information to respond to you, to manage your access to the staff portal, to maintain the security of our systems, and to meet record-keeping requirements.\n\nWe do not use enquiry data for automated decision-making, and we do not share it with third parties for their own purposes. Where a service provider processes data on our behalf — for example an email or hosting provider — they are bound to use it only for us.'
   ),
   'default','default',30,false),

  ('privacy-rights','prose',null,
   'Your rights',
   'Access, correction and deletion',
   null,
   jsonb_build_object(
     'body', E'You may ask us what information we hold about you, request corrections, or ask for it to be deleted where we are not required to keep it. Write to the email address in the footer and we will respond within a reasonable period.\n\nIf you are a staff user, most of your details can be reviewed and updated from your own profile in the portal.'
   ),
   'muted','default',40,false)
  ) as v(section_key, section_type, eyebrow, heading, subheading, summary, content, background, layout, sort_order, is_required)
 where p.slug = 'legal/privacy'
on conflict (page_id, section_key) do update
   set heading = excluded.heading, subheading = excluded.subheading,
       content = excluded.content, sort_order = excluded.sort_order;

-- Terms of use.
insert into public.website_sections
  (page_id, section_key, section_type, eyebrow, heading, subheading, content, background, layout, sort_order, is_required, is_visible)
select p.id, v.section_key, v.section_type, v.eyebrow, v.heading, v.subheading,
       v.content, v.background, v.layout, v.sort_order, v.is_required, true
  from public.website_pages p
  cross join (values
  ('page-hero','page-hero',null,
   'Terms of Use',
   'The terms that govern use of this site',
   null,
   jsonb_build_object('lead','By using this website you agree to these terms. If you do not accept them, please do not use the site.'),
   'dark','default',10,false),

  ('terms-use','prose',null,
   'Permitted use',
   'What you may and may not do',
   null,
   jsonb_build_object(
     'body', E'You may read this site and contact us through it. You may not attempt to gain unauthorised access to any part of the site or its underlying systems, disrupt its operation, or use it to transmit unlawful or harmful material.\n\nAutomated extraction of content at a rate that degrades the service for others is not permitted.'
   ),
   'muted','default',20,false),

  ('terms-information','prose',null,
   'Information on this site',
   'Not investment, legal or financial advice',
   null,
   jsonb_build_object(
     'body', E'The material on this site is published for general information. It does not constitute investment, legal, tax or financial advice, and nothing on it is an offer or a commitment.\n\nDescriptions of our businesses, capacity and performance are indicative and may change. Figures, dates and availability of inventory should be confirmed directly with the relevant operating business before you rely on them.'
   ),
   'default','default',30,false),

  ('terms-liability','prose',null,
   'Liability',
   'The limits of what we accept',
   null,
   jsonb_build_object(
     'body', E'To the extent permitted by law, we are not liable for loss arising from reliance on information published here, or from any interruption to the availability of this site.\n\nNothing in these terms limits liability that cannot lawfully be limited. These terms are governed by the laws of the jurisdiction in which the group is registered, and the courts of that jurisdiction have exclusive jurisdiction.'
   ),
   'muted','default',40,false)
  ) as v(section_key, section_type, eyebrow, heading, subheading, summary, content, background, layout, sort_order, is_required)
 where p.slug = 'legal/terms'
on conflict (page_id, section_key) do update
   set heading = excluded.heading, subheading = excluded.subheading,
       content = excluded.content, sort_order = excluded.sort_order;
