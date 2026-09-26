/**
 * Database types.
 *
 * Mirrors supabase/migrations/*.sql. In production this file is regenerated
 * with:
 *
 *   supabase gen types typescript --project-id <ref> > src/types/database.ts
 *
 * The hand-maintained version below exists so a clean checkout type-checks and
 * builds before anyone has connected a project.
 *
 * Convention: every Row has snake_case columns exactly as defined in SQL.
 * Application code converts to camelCase at the service boundary (see
 * `src/lib/queries/*`).
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

/* -------------------------------------------------------------------------- */
/* Enums                                                                       */
/* -------------------------------------------------------------------------- */

export type AccountStatus = "pending" | "active" | "suspended" | "disabled";
export type EmploymentStatus =
  | "applicant"
  | "probation"
  | "active"
  | "on_leave"
  | "suspended"
  | "terminated";
export type ScopeType = "global" | "department" | "business_unit";
export type ContentStatus = "draft" | "published" | "archived";
export type VehicleStatus =
  | "purchased"
  | "in_transit"
  | "arrived"
  | "under_repair"
  | "ready_for_sale"
  | "reserved"
  | "sold"
  | "cancelled";
export type VehicleCondition =
  | "new"
  | "used_excellent"
  | "used_good"
  | "used_fair"
  | "project"
  | "unknown";
export type VehicleExpenseCategory =
  | "shipping"
  | "port_charges"
  | "clearing"
  | "inspection"
  | "transportation"
  | "repair"
  | "parts"
  | "customs_duty"
  | "registration"
  | "insurance"
  | "storage"
  | "documentation"
  | "commission"
  | "other";
export type RepairStatus =
  | "planned"
  | "in_progress"
  | "awaiting_parts"
  | "completed"
  | "cancelled";
export type ShippingStatus =
  | "booked"
  | "picked_up"
  | "in_transit"
  | "customs"
  | "clearing"
  | "delivered"
  | "cancelled";
export type SaleStatus =
  | "inquiry"
  | "negotiation"
  | "deposit_paid"
  | "sold"
  | "cancelled"
  | "refunded";
export type PropertyType =
  | "land"
  | "residential_house"
  | "apartment"
  | "commercial"
  | "office"
  | "industrial"
  | "warehouse"
  | "farmland"
  | "development_site"
  | "other";
export type PropertyStatus =
  | "available"
  | "reserved"
  | "sold"
  | "under_development"
  | "unavailable";
export type PropertyTenure =
  | "freehold"
  | "leasehold"
  | "customary"
  | "share_ownership"
  | "concession"
  | "other";
export type ProjectStatus =
  | "planning"
  | "active"
  | "on_hold"
  | "completed"
  | "cancelled"
  | "closed";
export type LicenseStatus =
  | "application"
  | "granted"
  | "under_review"
  | "suspended"
  | "expired"
  | "revoked";
export type RecordStatus =
  | "draft"
  | "pending_approval"
  | "approved"
  | "rejected"
  | "posted"
  | "cancelled";
export type PaymentMethod =
  | "cash"
  | "bank_transfer"
  | "mobile_money"
  | "cheque"
  | "card"
  | "credit"
  | "barter"
  | "other";
export type ExpenseCategory =
  | "fuel"
  | "transport"
  | "office_supplies"
  | "rent"
  | "utilities"
  | "repairs"
  | "marketing"
  | "salaries"
  | "shipping"
  | "government_fees"
  | "professional_fees"
  | "insurance"
  | "telecommunications"
  | "maintenance"
  | "security"
  | "travel"
  | "entertainment"
  | "donations"
  | "tax"
  | "other";
export type IncomeSource =
  | "vehicle_sale"
  | "property_sale"
  | "agriculture"
  | "mining"
  | "rental"
  | "dividend"
  | "interest"
  | "service_fee"
  | "commission"
  | "logistics"
  | "trading"
  | "other";
export type TransactionDirection = "in" | "out";
export type ThreadKind = "direct" | "group";
export type MessageKind = "text" | "file" | "system" | "announcement";
export type NotificationKind =
  | "message"
  | "group_message"
  | "task_assigned"
  | "task_due"
  | "task_completed"
  | "announcement"
  | "approval_request"
  | "approval_decision"
  | "mention"
  | "system"
  | "document"
  | "lead"
  | "system_alert";
export type TaskStatus =
  | "todo"
  | "in_progress"
  | "pending"
  | "completed"
  | "cancelled";
export type TaskPriority = "low" | "normal" | "high" | "urgent";
export type AnnouncementAudience =
  | "all"
  | "department"
  | "business_unit"
  | "roles"
  | "individuals";
export type ApprovalStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "cancelled"
  | "expired";
export type LeadStatus =
  | "new"
  | "contacted"
  | "qualified"
  | "proposal"
  | "negotiation"
  | "won"
  | "lost"
  | "spam";
export type LeadPriority = "low" | "normal" | "high" | "urgent";

/* -------------------------------------------------------------------------- */
/* Table rows                                                                  */
/* -------------------------------------------------------------------------- */

export type UserRow = {
  id: string;
  email: string;
  email_normalised: string;
  full_name: string;
  avatar_url: string | null;
  locale: string;
  timezone: string;
  account_status: AccountStatus;
  status_reason: string | null;
  status_changed_at: string | null;
  status_changed_by: string | null;
  mfa_enabled: boolean;
  last_login_at: string | null;
  failed_login_count: number;
  locked_until: string | null;
  must_change_password: boolean;
  session_absolute_deadline: string | null;
  data: Json;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type DepartmentRow = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  parent_id: string | null;
  head_id: string | null;
  is_active: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type EmployeeRow = {
  id: string;
  user_id: string | null;
  employee_number: string;
  full_name: string;
  preferred_name: string | null;
  photo_url: string | null;
  job_title: string | null;
  department_id: string | null;
  business_unit_id: string | null;
  branch_id: string | null;
  manager_id: string | null;
  work_email: string | null;
  work_phone: string | null;
  mobile_phone: string | null;
  date_of_birth: string | null;
  national_id: string | null;
  tax_id: string | null;
  passport_number: string | null;
  bank_account: string | null;
  address: string | null;
  city: string | null;
  country: string | null;
  employment_type: string | null;
  date_employed: string | null;
  date_terminated: string | null;
  employment_status: EmploymentStatus;
  emergency_contact: Json;
  skills: string[];
  bio: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type PermissionRow = {
  id: string;
  key: string;
  label: string;
  description: string | null;
  category: string;
  is_sensitive: boolean;
  created_at: string;
  updated_at: string;
};

export type RoleRow = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  scope_type: ScopeType;
  is_system: boolean;
  is_active: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type RolePermissionRow = {
  role_id: string;
  permission_id: string;
  granted_at: string;
};

export type UserRoleRow = {
  id: string;
  user_id: string;
  role_id: string;
  scope_type: ScopeType;
  scope_department_id: string | null;
  scope_business_unit_id: string | null;
  granted_by: string | null;
  granted_at: string;
  expires_at: string | null;
  revoked_at: string | null;
  created_at: string;
  updated_at: string;
};

export type BusinessUnitRow = {
  id: string;
  code: string;
  slug: string;
  name: string;
  short_name: string;
  tagline: string | null;
  description: string | null;
  summary: string | null;
  icon: string | null;
  accent_color: string | null;
  image_url: string | null;
  gallery: string[];
  legal_entity: string | null;
  registration_number: string | null;
  established_on: string | null;
  manager_id: string | null;
  public_visible: boolean;
  internal_visible: boolean;
  show_metrics: boolean;
  sort_order: number;
  is_active: boolean;
  seo: Json;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type BranchRow = {
  id: string;
  code: string;
  name: string;
  business_unit_id: string | null;
  country: string;
  city: string | null;
  address_line1: string | null;
  address_line2: string | null;
  phone: string | null;
  email: string | null;
  timezone: string;
  latitude: number | null;
  longitude: number | null;
  is_head_office: boolean;
  is_public: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type CustomerRow = {
  id: string;
  code: string;
  customer_type: string;
  display_name: string;
  legal_name: string | null;
  email: string | null;
  phone: string | null;
  alt_phone: string | null;
  whatsapp: string | null;
  country: string | null;
  city: string | null;
  address: string | null;
  tax_number: string | null;
  credit_limit: number | null;
  credit_currency: string | null;
  default_currency: string;
  payment_terms_days: number;
  rating: number | null;
  assigned_sales_person_id: string | null;
  business_unit_id: string | null;
  notes: string | null;
  tags: string[];
  total_purchased: number;
  outstanding_balance: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type SupplierRow = {
  id: string;
  code: string;
  supplier_type: string;
  display_name: string;
  legal_name: string | null;
  email: string | null;
  phone: string | null;
  country: string | null;
  city: string | null;
  address: string | null;
  tax_number: string | null;
  bank_details: string | null;
  default_currency: string;
  payment_terms_days: number;
  default_business_unit_id: string | null;
  rating: number | null;
  notes: string | null;
  tags: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type LeadRow = {
  id: string;
  reference: string;
  source: string;
  subject: string | null;
  business_unit_id: string | null;
  customer_id: string | null;
  contact_name: string;
  contact_email: string | null;
  contact_phone: string | null;
  country: string | null;
  message: string;
  status: LeadStatus;
  priority: LeadPriority;
  assigned_to: string | null;
  assigned_by: string | null;
  next_follow_up_at: string | null;
  converted_at: string | null;
  lost_reason: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type WebsitePageRow = {
  id: string;
  slug: string;
  title: string;
  subtitle: string | null;
  template: string;
  parent_id: string | null;
  status: ContentStatus;
  is_system: boolean;
  show_in_nav: boolean;
  nav_label: string | null;
  nav_order: number;
  published_at: string | null;
  published_by: string | null;
  seo: Json;
  business_unit_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type WebsiteSectionRow = {
  id: string;
  page_id: string;
  section_key: string;
  section_type: string;
  heading: string | null;
  subheading: string | null;
  eyebrow: string | null;
  content: Json;
  cta_label: string | null;
  cta_href: string | null;
  secondary_cta_label: string | null;
  secondary_cta_href: string | null;
  background: "default" | "muted" | "dark" | "brand" | "image";
  layout: string;
  is_visible: boolean;
  is_required: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type WebsiteMediaRow = {
  id: string;
  storage_bucket: string;
  storage_path: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  width: number | null;
  height: number | null;
  checksum: string | null;
  title: string | null;
  alt_text: string | null;
  caption: string | null;
  folder: string | null;
  tags: string[];
  usage_count: number;
  is_public: boolean;
  uploaded_by: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type NewsPostRow = {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  body: string;
  cover_image_url: string | null;
  category: string;
  business_unit_id: string | null;
  tags: string[];
  status: ContentStatus;
  is_featured: boolean;
  published_at: string | null;
  published_by: string | null;
  author_name: string | null;
  read_minutes: number | null;
  seo: Json;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type TestimonialRow = {
  id: string;
  quote: string;
  author_name: string;
  author_title: string | null;
  author_company: string | null;
  avatar_url: string | null;
  business_unit_id: string | null;
  rating: number | null;
  status: ContentStatus;
  sort_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type CompanyStatisticRow = {
  id: string;
  label: string;
  value: number;
  suffix: string | null;
  prefix: string | null;
  unit: string | null;
  icon: string | null;
  business_unit_id: string | null;
  is_public: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type CompanySettingsRow = {
  id: string;
  company_name: string;
  legal_name: string | null;
  tagline: string | null;
  description: string | null;
  founded_year: number | null;
  base_currency: string;
  supported_currencies: string[];
  registration_number: string | null;
  tax_number: string | null;
  email: string | null;
  phone: string | null;
  whatsapp: string | null;
  address: string | null;
  city: string | null;
  country: string | null;
  logo_url: string | null;
  social_links: Json;
  approval_threshold_default: number;
  feature_flags: Json;
  seo_defaults: Json;
  maintenance_mode: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type VehicleRow = {
  id: string;
  stock_number: string;
  business_unit_id: string;
  department_id: string | null;
  branch_id: string | null;
  make: string;
  model: string;
  variant: string | null;
  model_year: number;
  colour: string | null;
  interior_colour: string | null;
  body_type: string | null;
  transmission: string | null;
  fuel_type: string | null;
  engine_number: string | null;
  chassis_number: string | null;
  plate_number: string | null;
  mileage_km: number | null;
  odometer_unit: string;
  condition: VehicleCondition;
  steering: string | null;
  seats: number | null;
  fuel_capacity_l: number | null;
  supplier_id: string | null;
  country_purchased: string | null;
  purchase_date: string;
  purchase_price: number;
  purchase_currency: string;
  exchange_rate: number | null;
  purchase_invoice_ref: string | null;
  payment_status: string;
  status: VehicleStatus;
  status_changed_at: string;
  status_changed_by: string | null;
  assigned_sales_person_id: string | null;
  current_location: string | null;
  arrival_date: string | null;
  ready_for_sale_at: string | null;
  notes: string | null;
  is_public: boolean;
  public_title: string | null;
  public_description: string | null;
  public_photos: string[];
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type VehicleExpenseRow = {
  id: string;
  vehicle_id: string;
  business_unit_id: string;
  category: VehicleExpenseCategory;
  description: string;
  vendor_id: string | null;
  vendor_name: string | null;
  invoice_ref: string | null;
  amount: number;
  currency: string;
  exchange_rate: number | null;
  incurred_on: string;
  is_approved: boolean;
  approved_by: string | null;
  approved_at: string | null;
  approval_id: string | null;
  receipt_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type VehicleRepairRow = {
  id: string;
  vehicle_id: string;
  reference: string;
  title: string;
  description: string | null;
  problem_reported: string | null;
  diagnosis: string | null;
  work_performed: string | null;
  status: RepairStatus;
  vendor_id: string | null;
  workshop_name: string | null;
  started_on: string | null;
  completed_on: string | null;
  labour_hours: number | null;
  parts_used: string | null;
  total_cost: number;
  currency: string;
  warranty: boolean;
  technician: string | null;
  approved_by: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type VehicleShippingRow = {
  id: string;
  vehicle_id: string;
  reference: string;
  shipping_line: string | null;
  vessel_name: string | null;
  voyage_number: string | null;
  container_number: string | null;
  bill_of_lading: string | null;
  mode: string;
  origin_port: string | null;
  origin_country: string | null;
  destination_port: string | null;
  destination_country: string | null;
  departure_date: string | null;
  arrival_date: string | null;
  estimated_arrival_date: string | null;
  status: ShippingStatus;
  freight_cost: number;
  insurance_cost: number;
  port_charges: number;
  clearing_cost: number;
  inspection_cost: number;
  other_costs: number;
  total_cost: number;
  currency: string;
  documents_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type VehicleSaleRow = {
  id: string;
  vehicle_id: string;
  reference: string;
  customer_id: string | null;
  buyer_name: string;
  buyer_type: string;
  contact_email: string | null;
  contact_phone: string | null;
  country: string | null;
  sale_price: number;
  sale_currency: string;
  exchange_rate: number | null;
  expected_sale_price: number | null;
  expected_sale_currency: string | null;
  commission_rate: number | null;
  discount_amount: number;
  status: SaleStatus;
  deposit_amount: number;
  deposit_paid_at: string | null;
  balance_paid_at: string | null;
  payment_method: string | null;
  payment_reference: string | null;
  sale_date: string | null;
  expected_delivery_date: string | null;
  delivered_at: string | null;
  sales_person_id: string | null;
  contract_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type PropertyRow = {
  id: string;
  code: string;
  title: string;
  slug: string;
  business_unit_id: string;
  department_id: string | null;
  branch_id: string | null;
  property_type: PropertyType;
  status: PropertyStatus;
  status_changed_at: string;
  country: string;
  region: string | null;
  city: string | null;
  district: string | null;
  locality: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  map_url: string | null;
  size_value: number;
  size_unit: string;
  size_label: string | null;
  bedrooms: number | null;
  bathrooms: number | null;
  floors: number | null;
  year_built: number | null;
  construction_status: string | null;
  tenure: PropertyTenure | null;
  title_reference: string | null;
  plot_number: string | null;
  survey_number: string | null;
  zoning: string | null;
  price: number;
  currency: string;
  price_negotiable: boolean;
  rental_price: number | null;
  rental_currency: string | null;
  rental_period: string | null;
  expected_roi: number | null;
  owner_type: string;
  owner_name: string | null;
  ownership_note: string | null;
  ownership_document_path: string | null;
  summary: string | null;
  description: string | null;
  features: string[];
  amenities: string[];
  photos: string[];
  video_url: string | null;
  floor_plan_url: string | null;
  assigned_sales_person_id: string | null;
  listed_at: string | null;
  date_sold: string | null;
  is_public: boolean;
  is_featured: boolean;
  published_at: string | null;
  published_by: string | null;
  seo: Json;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type PropertySaleRow = {
  id: string;
  reference: string;
  property_id: string;
  customer_id: string | null;
  buyer_name: string;
  buyer_type: string;
  contact_email: string | null;
  contact_phone: string | null;
  country: string | null;
  sale_price: number;
  currency: string;
  exchange_rate: number | null;
  deposit_amount: number;
  discount_amount: number;
  commission_rate: number | null;
  status: SaleStatus;
  payment_method: string | null;
  payment_reference: string | null;
  sale_date: string | null;
  handover_date: string | null;
  title_transferred: boolean;
  title_transfer_reference: string | null;
  sales_person_id: string | null;
  contract_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type AgriculturalProjectRow = {
  id: string;
  code: string;
  name: string;
  business_unit_id: string;
  department_id: string | null;
  branch_id: string | null;
  country: string;
  region: string | null;
  district: string | null;
  locality: string | null;
  gps_coordinates: string | null;
  land_size_value: number;
  land_size_unit: string;
  tenure: string | null;
  lease_reference: string | null;
  crop: string;
  variety: string | null;
  season: string | null;
  farming_method: string | null;
  project_manager_id: string | null;
  agronomist_id: string | null;
  start_date: string;
  expected_harvest_date: string | null;
  actual_harvest_date: string | null;
  status: ProjectStatus;
  status_changed_at: string;
  expected_yield_value: number | null;
  expected_yield_unit: string | null;
  actual_yield_value: number | null;
  actual_yield_unit: string | null;
  expected_revenue: number | null;
  revenue_currency: string | null;
  actual_revenue: number | null;
  actual_currency: string | null;
  farm_manager: string | null;
  worker_count: number | null;
  irrigation_source: string | null;
  storage_capacity_tonnes: number | null;
  is_public: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type MiningProjectRow = {
  id: string;
  code: string;
  name: string;
  business_unit_id: string;
  department_id: string | null;
  branch_id: string | null;
  country: string;
  region: string | null;
  district: string | null;
  locality: string | null;
  gps_coordinates: string | null;
  site_area_value: number | null;
  site_area_unit: string | null;
  tenure: string | null;
  mineral: string | null;
  mineral_category: string | null;
  commodity_notes: string | null;
  concession_type: string | null;
  license_number: string | null;
  license_status: LicenseStatus | null;
  license_issued_on: string | null;
  license_expires_on: string | null;
  license_holder: string | null;
  license_document_path: string | null;
  project_manager_id: string | null;
  geologist_id: string | null;
  start_date: string;
  expected_commissioning: string | null;
  commissioning_date: string | null;
  status: ProjectStatus;
  status_changed_at: string;
  status_reason: string | null;
  method: string | null;
  reserve_estimate: string | null;
  resource_grade: string | null;
  plant_capacity: number | null;
  plant_capacity_unit: string | null;
  workforce: number | null;
  is_public: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type ExpenseRow = {
  id: string;
  reference: string;
  expense_date: string;
  department_id: string | null;
  business_unit_id: string | null;
  branch_id: string | null;
  category: ExpenseCategory;
  description: string;
  amount: number;
  currency: string;
  exchange_rate: number | null;
  vendor_id: string | null;
  vendor_name: string | null;
  payment_method: PaymentMethod;
  paid_from_account: string | null;
  receipt_path: string | null;
  requested_by: string | null;
  recorded_by: string;
  approved_by: string | null;
  approved_at: string | null;
  status: RecordStatus;
  approval_id: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type IncomeRow = {
  id: string;
  reference: string;
  income_date: string;
  business_unit_id: string | null;
  department_id: string | null;
  source: IncomeSource;
  description: string;
  customer_id: string | null;
  customer_name: string | null;
  amount: number;
  currency: string;
  exchange_rate: number | null;
  payment_method: PaymentMethod;
  payment_reference: string | null;
  received_in_account: string | null;
  supporting_document_path: string | null;
  recorded_by: string;
  approved_by: string | null;
  approved_at: string | null;
  status: RecordStatus;
  approval_id: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type FinancialTransactionRow = {
  id: string;
  reference: string;
  transaction_date: string;
  direction: TransactionDirection;
  category: string;
  business_unit_id: string | null;
  department_id: string | null;
  description: string;
  amount: number;
  currency: string;
  exchange_rate: number | null;
  payment_method: PaymentMethod | null;
  counterparty: string | null;
  counterparty_account: string | null;
  bank_account: string | null;
  source_type: string | null;
  source_id: string | null;
  status: RecordStatus;
  posted_by: string | null;
  posted_at: string | null;
  approved_by: string | null;
  attachment_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type CurrencyRow = {
  code: string;
  name: string;
  symbol: string | null;
  minor_unit: number;
  is_active: boolean;
  is_base: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
};

export type TaskRow = {
  id: string;
  reference: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  module: string;
  task_type: string | null;
  business_unit_id: string | null;
  department_id: string | null;
  project_domain: string | null;
  project_id: string | null;
  resource_type: string | null;
  resource_id: string | null;
  created_by: string;
  assigned_to: string | null;
  assigned_by: string | null;
  assigned_at: string | null;
  due_at: string | null;
  start_at: string | null;
  completed_at: string | null;
  completion_note: string | null;
  progress_percent: number | null;
  estimated_hours: number | null;
  actual_hours: number | null;
  is_visible_to_all: boolean;
  requires_approval: boolean;
  approval_id: string | null;
  watchers: string[];
  reminders_sent_at: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type MessageThreadRow = {
  id: string;
  kind: ThreadKind;
  subject: string | null;
  direct_key: string | null;
  created_by: string | null;
  last_message_at: string | null;
  last_message_preview: string | null;
  message_count: number;
  is_archived: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type ThreadParticipantRow = {
  thread_id: string;
  user_id: string;
  role: string;
  unread_count: number;
  last_read_at: string | null;
  last_read_message_id: string | null;
  is_muted: boolean;
  joined_at: string;
  left_at: string | null;
};

export type GroupChatRow = {
  id: string;
  slug: string | null;
  name: string;
  description: string | null;
  purpose: string | null;
  colour: string | null;
  icon: string | null;
  avatar_url: string | null;
  business_unit_id: string | null;
  department_id: string | null;
  is_private: boolean;
  is_announcement_only: boolean;
  created_by: string | null;
  last_message_at: string | null;
  member_count: number;
  is_archived: boolean;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type GroupChatMemberRow = {
  group_id: string;
  user_id: string;
  role: string;
  unread_count: number;
  last_read_at: string | null;
  is_muted: boolean;
  joined_at: string;
  removed_at: string | null;
};

export type MessageRow = {
  id: string;
  thread_id: string | null;
  group_id: string | null;
  sender_id: string | null;
  kind: MessageKind;
  body: string;
  reply_to_id: string | null;
  attachments: Json;
  mentions: string[];
  is_edited: boolean;
  edited_at: string | null;
  is_deleted: boolean;
  deleted_by: string | null;
  deleted_at: string | null;
  created_at: string;
  updated_at: string;
};

export type NotificationRow = {
  id: string;
  recipient_id: string;
  kind: NotificationKind;
  title: string;
  body: string | null;
  url: string | null;
  actor_id: string | null;
  resource_type: string | null;
  resource_id: string | null;
  metadata: Json;
  priority: string;
  read_at: string | null;
  created_at: string;
};

export type AnnouncementRow = {
  id: string;
  title: string;
  body: string;
  priority: string;
  category: string;
  audience_type: AnnouncementAudience;
  audience_department_id: string | null;
  audience_business_unit_id: string | null;
  audience_role_ids: string[];
  audience_user_ids: string[];
  require_acknowledgement: boolean;
  attachment_paths: Json;
  status: ContentStatus;
  published_at: string | null;
  published_by: string | null;
  expires_at: string | null;
  pinned: boolean;
  view_count: number;
  ack_count: number;
  author_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type DocumentRow = {
  id: string;
  title: string;
  description: string | null;
  domain: string;
  storage_bucket: string;
  storage_path: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  checksum: string | null;
  business_unit_id: string | null;
  department_id: string | null;
  resource_type: string | null;
  resource_id: string | null;
  tags: string[];
  confidentiality: "public" | "internal" | "confidential" | "restricted";
  is_archived: boolean;
  version: number;
  effective_from: string | null;
  effective_to: string | null;
  uploaded_by: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type AuditLogRow = {
  id: string;
  actor_id: string | null;
  actor_email: string | null;
  actor_role_slug: string | null;
  action: string;
  resource_type: string;
  resource_id: string | null;
  resource_label: string | null;
  summary: string;
  before_state: Json | null;
  after_state: Json | null;
  metadata: Json;
  ip_address: string | null;
  user_agent: string | null;
  request_id: string | null;
  severity: string;
  created_at: string;
};

export type ActivityFeedRow = {
  id: string;
  actor_id: string | null;
  actor_name: string | null;
  actor_avatar: string | null;
  verb: string;
  summary: string;
  detail: string | null;
  domain: string;
  business_unit_id: string | null;
  department_id: string | null;
  resource_type: string | null;
  resource_id: string | null;
  url: string | null;
  visibility: "private" | "department" | "business_unit" | "company";
  audience_user_ids: string[];
  metadata: Json;
  created_at: string;
};

export type ApprovalRow = {
  id: string;
  reference: string;
  rule_id: string | null;
  action_key: string;
  subject_type: string;
  subject_id: string;
  business_unit_id: string | null;
  requested_by: string;
  requested_for: string | null;
  amount: number | null;
  currency: string | null;
  base_amount: number | null;
  base_currency: string | null;
  payload: Json;
  status: ApprovalStatus;
  required_level: number;
  decisions: Json;
  expires_at: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

/* -------------------------------------------------------------------------- */
/* View rows                                                                   */
/* -------------------------------------------------------------------------- */

export type VehicleFinancialRow = {
  vehicle_id: string;
  stock_number: string;
  make: string;
  model: string;
  model_year: number;
  chassis_number: string | null;
  status: VehicleStatus;
  purchase_date: string;
  purchase_price: number;
  purchase_currency: string;
  assigned_sales_person_id: string | null;
  business_unit_id: string;
  is_public: boolean;
  base_currency: string;
  purchase_base: number;
  expenses_base: number;
  shipping_base: number;
  clearing_base: number;
  repair_parts_base: number;
  transport_base: number;
  other_base: number;
  expense_count: number;
  total_acquisition_base: number;
  sale_id: string | null;
  sale_status: SaleStatus | null;
  sale_date: string | null;
  buyer_name: string | null;
  sales_person_id: string | null;
  sale_base: number;
  expected_sale_price: number | null;
  expected_sale_base: number;
  gross_profit_base: number;
  expected_gross_profit_base: number;
  margin_percent: number | null;
  inventory_value_base: number;
  net_sale_base: number;
};

export type VehicleSummaryRow = {
  total_vehicles: number;
  sold_vehicles: number;
  in_stock_vehicles: number;
  ready_for_sale: number;
  reserved_vehicles: number;
  total_acquisition: number;
  total_expenses: number;
  total_shipping: number;
  total_repairs: number;
  total_revenue: number;
  total_gross_profit: number;
  inventory_value: number;
  average_profit_per_vehicle: number;
  average_margin_percent: number;
};

export type PropertyFinancialRow = {
  property_id: string;
  code: string;
  title: string;
  property_type: PropertyType;
  status: PropertyStatus;
  country: string;
  city: string | null;
  size_value: number;
  size_unit: string;
  price: number;
  currency: string;
  business_unit_id: string;
  assigned_sales_person_id: string | null;
  listed_at: string | null;
  is_public: boolean;
  base_currency: string;
  ask_base: number;
  sale_id: string | null;
  sale_status: SaleStatus | null;
  sale_date: string | null;
  buyer_name: string | null;
  sale_base: number;
  gross_profit_base: number;
  inventory_value_base: number;
};

export type AgricultureFinancialRow = {
  project_id: string;
  code: string;
  name: string;
  crop: string;
  status: ProjectStatus;
  country: string;
  land_size_value: number;
  land_size_unit: string;
  start_date: string;
  actual_harvest_date: string | null;
  business_unit_id: string;
  project_manager_id: string | null;
  is_public: boolean;
  total_cost: number;
  input_cost: number;
  labour_cost: number;
  equipment_cost: number;
  realised_revenue: number;
  total_quantity: number;
  projected_profit: number;
  realised_profit: number;
};

export type MiningFinancialRow = {
  project_id: string;
  code: string;
  name: string;
  mineral: string | null;
  license_number: string | null;
  license_status: LicenseStatus | null;
  status: ProjectStatus;
  country: string;
  start_date: string;
  business_unit_id: string;
  project_manager_id: string | null;
  is_public: boolean;
  total_cost: number;
  licensing_cost: number;
  equipment_cost: number;
  total_production: number;
  revenue: number;
  sold_quantity: number;
  profit: number;
};

export type FinanceSummaryRow = {
  business_unit_id: string | null;
  department_id: string | null;
  base_currency: string;
  total_income: number;
  total_expenses: number;
  net_result: number;
};

export type DashboardCountersRow = {
  my_open_tasks: number;
  my_overdue_tasks: number;
  unread_notifications: number;
  unread_messages: number;
  unread_group_messages: number;
  pending_approvals: number;
  active_announcements: number;
};

export type GlobalSearchResult = {
  domain: string;
  result_type: string;
  result_id: string;
  title: string;
  subtitle: string | null;
  url: string;
  score: number | null;
};

export type MyPermissionsResult = {
  userId: string | null;
  employeeId: string | null;
  departmentId: string | null;
  accountStatus: "pending" | "active" | "suspended" | "disabled";
  isActive: boolean;
  isStaff: boolean;
  /** True only for holders of `platform.admin`. See authz.is_platform_admin(). */
  isSuperuser: boolean;
  /** True when the caller holds at least one GLOBAL role assignment. */
  globalScope: boolean;
  permissions: string[];
  scopes: { departments: string[]; businessUnits: string[] };
};

/* -------------------------------------------------------------------------- */
/* Supabase Database generic                                                   */
/* -------------------------------------------------------------------------- */

/**
 * Makes the given keys optional, ignoring any that the row does not have.
 *
 * `K` is intentionally not constrained to `keyof T`. Constraining it looks
 * tidier but forces every caller to prove the row has an `id`, which is not
 * true for the handful of key/value tables (company_settings, fx_rates) and
 * would make the alias unusable as a generic. `Extract<K, keyof T>` narrows
 * the keys to the ones that actually exist, so a missing key is a no-op.
 */
type Optional<T, K extends PropertyKey> = Omit<T, K> &
  Partial<Pick<T, Extract<K, keyof T>>>;

/** Every column whose value can be SQL NULL. */
type NullableKeys<T> = { [K in keyof T]-?: null extends T[K] ? K : never }[keyof T];

/**
 * Inserts: server-managed columns are left to their defaults, and nullable
 * columns are optional because omitting a nullable column is always valid in
 * Postgres — it becomes NULL.
 *
 * Columns that are NOT NULL *with* a default stay required. The type layer does
 * not carry default values, so this is the conservative choice: the compiler
 * will ask for a value it could have inferred, which is a small annoyance,
 * rather than let through an insert the database rejects.
 */
export type Insertable<T> = Optional<
  T,
  "id" | "created_at" | "updated_at" | "deleted_at" | NullableKeys<T>
>;

/**
 * Updates: every column is optional, because an update states only what changes.
 *
 * `id` and `created_at` are omitted outright — they are identity, not data, and
 * letting a client write them would mean a caller can move or forge the history
 * of a row. `updated_at` is left in deliberately: it is guarded by a trigger
 * that overwrites it with now(), so writing it is harmless and occasionally
 * useful for a deliberate backdate in an admin migration.
 */
export type Updatable<T> = Partial<Omit<T, "id" | "created_at">>;

type Table<Row> = {
  Row: Row;
  Insert: Insertable<Row>;
  Update: Updatable<Row>;
  Relationships: [];
};

/**
 * Reporting views are read-only.
 *
 * `Relationships: []` is not optional decoration: supabase-js checks the schema
 * against its `GenericSchema` constraint, and a view entry without it fails that
 * check. When it fails, the client type degrades to `never` for *every* table,
 * function and view in the project — the queries still run, but the compiler
 * silently stops checking any of them.
 */
type View<Row> = {
  Row: Row;
  Relationships: [];
};

export type Database = {
  public: {
    Tables: {
      users: Table<UserRow>;
      departments: Table<DepartmentRow>;
      employees: Table<EmployeeRow>;
      permissions: Table<PermissionRow>;
      roles: Table<RoleRow>;
      role_permissions: Table<RolePermissionRow>;
      user_roles: Table<UserRoleRow>;
      business_units: Table<BusinessUnitRow>;
      branches: Table<BranchRow>;
      customers: Table<CustomerRow>;
      suppliers: Table<SupplierRow>;
      leads: Table<LeadRow>;
      website_pages: Table<WebsitePageRow>;
      website_sections: Table<WebsiteSectionRow>;
      website_media: Table<WebsiteMediaRow>;
      news_posts: Table<NewsPostRow>;
      testimonials: Table<TestimonialRow>;
      company_statistics: Table<CompanyStatisticRow>;
      company_settings: Table<CompanySettingsRow>;
      vehicles: Table<VehicleRow>;
      vehicle_expenses: Table<VehicleExpenseRow>;
      vehicle_repairs: Table<VehicleRepairRow>;
      vehicle_shipping: Table<VehicleShippingRow>;
      vehicle_sales: Table<VehicleSaleRow>;
      real_estate_properties: Table<PropertyRow>;
      property_sales: Table<PropertySaleRow>;
      agricultural_projects: Table<AgriculturalProjectRow>;
      mining_projects: Table<MiningProjectRow>;
      expenses: Table<ExpenseRow>;
      income: Table<IncomeRow>;
      financial_transactions: Table<FinancialTransactionRow>;
      currencies: Table<CurrencyRow>;
      tasks: Table<TaskRow>;
      message_threads: Table<MessageThreadRow>;
      thread_participants: Table<ThreadParticipantRow>;
      group_chats: Table<GroupChatRow>;
      group_chat_members: Table<GroupChatMemberRow>;
      messages: Table<MessageRow>;
      notifications: Table<NotificationRow>;
      announcements: Table<AnnouncementRow>;
      documents: Table<DocumentRow>;
      audit_logs: Table<AuditLogRow>;
      activity_feed: Table<ActivityFeedRow>;
      approvals: Table<ApprovalRow>;
    };
    Views: {
      vehicle_financials: View<VehicleFinancialRow>;
      vehicle_summary: View<VehicleSummaryRow>;
      property_financials: View<PropertyFinancialRow>;
      agriculture_financials: View<AgricultureFinancialRow>;
      mining_financials: View<MiningFinancialRow>;
      finance_summary: View<FinanceSummaryRow>;
      dashboard_counters: View<DashboardCountersRow>;
    };
    Functions: {
      get_my_permissions: { Args: Record<PropertyKey, never>; Returns: MyPermissionsResult };
      write_audit: {
        Args: {
          p_action: string;
          p_resource_type: string;
          p_resource_id?: string | null;
          p_resource_label?: string | null;
          p_summary?: string | null;
          p_metadata?: Json;
          p_severity?: string;
        };
        Returns: string;
      };
      global_search: {
        Args: { p_query: string; p_limit?: number };
        Returns: GlobalSearchResult[];
      };
      direct_thread_key: {
        Args: { a: string; b: string };
        Returns: string;
      };
    };
    Enums: {
      account_status: AccountStatus;
      employment_status: EmploymentStatus;
      content_status: ContentStatus;
      vehicle_status: VehicleStatus;
      vehicle_condition: VehicleCondition;
      vehicle_expense_category: VehicleExpenseCategory;
      repair_status: RepairStatus;
      shipping_status: ShippingStatus;
      sale_status: SaleStatus;
      property_type: PropertyType;
      property_status: PropertyStatus;
      property_tenure: PropertyTenure;
      project_status: ProjectStatus;
      license_status: LicenseStatus;
      record_status: RecordStatus;
      payment_method: PaymentMethod;
      expense_category: ExpenseCategory;
      income_source: IncomeSource;
      transaction_direction: TransactionDirection;
      thread_kind: ThreadKind;
      message_kind: MessageKind;
      notification_kind: NotificationKind;
      task_status: TaskStatus;
      task_priority: TaskPriority;
      announcement_audience: AnnouncementAudience;
      approval_status: ApprovalStatus;
    };
    CompositeTypes: Record<PropertyKey, never>;
  };
};
