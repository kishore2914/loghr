-- ============================================================
-- COMPLETE HRMS SCHEMA - India Payroll System
-- Creates ALL tables from scratch
-- ============================================================

CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  country text DEFAULT 'India',
  currency text DEFAULT 'INR',
  timezone text DEFAULT 'Asia/Kolkata',
  legal_name text,
  registration_number text,
  tax_id text,
  pan_number text,
  tan_number text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  email text,
  phone text,
  website text,
  logo_url text,
  settings jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  subscription_plan text DEFAULT 'free',
  subscription_status text DEFAULT 'active',
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'employee',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  organization_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  employee_id uuid,
  full_name text,
  email text,
  phone text,
  avatar_url text,
  role text DEFAULT 'employee' CHECK (role IN ('super_admin', 'admin', 'hr_manager', 'manager', 'employee')),
  permissions jsonb DEFAULT '[]',
  preferences jsonb DEFAULT '{}',
  notification_settings jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  is_onboarded boolean DEFAULT false,
  onboarded_at timestamptz,
  last_login_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  code text,
  description text,
  manager_id uuid,
  parent_department_id uuid REFERENCES departments(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS designations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  code text,
  description text,
  level integer DEFAULT 1,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_code text NOT NULL,
  first_name text NOT NULL,
  last_name text,
  middle_name text,
  personal_email text,
  company_email text,
  mobile_number text,
  alternate_phone text,
  date_of_birth date,
  gender text CHECK (gender IN ('male', 'female', 'other')),
  marital_status text CHECK (marital_status IN ('single', 'married', 'divorced', 'widowed')),
  blood_group text,
  nationality text DEFAULT 'Indian',
  current_address text,
  current_city text,
  current_state text,
  current_pincode text,
  permanent_address text,
  permanent_city text,
  permanent_state text,
  permanent_pincode text,
  aadhaar_number text,
  pan_number text,
  passport_number text,
  passport_expiry date,
  voter_id text,
  driving_license text,
  bank_name text,
  bank_account_number text,
  ifsc_code text,
  bank_branch text,
  uan_number text,
  pf_number text,
  esi_number text,
  tax_regime text DEFAULT 'new' CHECK (tax_regime IN ('old', 'new')),
  date_of_joining date,
  confirmation_date date,
  probation_end_date date,
  department_id uuid REFERENCES departments(id),
  designation_id uuid REFERENCES designations(id),
  reporting_manager_id uuid REFERENCES employees(id),
  employment_status text DEFAULT 'active' CHECK (employment_status IN ('active', 'probation', 'on_hold', 'notice_period', 'resigned', 'terminated', 'retired', 'absconding')),
  employment_type text DEFAULT 'full_time' CHECK (employment_type IN ('full_time', 'part_time', 'contract', 'intern', 'consultant')),
  work_location text,
  work_state text,
  is_remote boolean DEFAULT false,
  resignation_date date,
  last_working_date date,
  separation_reason text,
  emergency_contact_name text,
  emergency_contact_phone text,
  emergency_contact_relation text,
  photo_url text,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, employee_code)
);

ALTER TABLE user_profiles 
  ADD CONSTRAINT fk_user_profiles_employee 
  FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;

ALTER TABLE departments 
  ADD CONSTRAINT fk_departments_manager 
  FOREIGN KEY (manager_id) REFERENCES employees(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS leave_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  code text,
  description text,
  days_per_year numeric(5,2) DEFAULT 0,
  is_paid boolean DEFAULT true,
  is_encashable boolean DEFAULT false,
  max_carry_forward numeric(5,2) DEFAULT 0,
  min_days_per_request numeric(5,2) DEFAULT 0.5,
  max_days_per_request numeric(5,2),
  requires_approval boolean DEFAULT true,
  requires_document boolean DEFAULT false,
  applicable_from_days integer DEFAULT 0,
  applicable_gender text,
  is_active boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS leave_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  leave_type_id uuid NOT NULL REFERENCES leave_types(id) ON DELETE CASCADE,
  year integer NOT NULL,
  opening_balance numeric(5,2) DEFAULT 0,
  accrued numeric(5,2) DEFAULT 0,
  used numeric(5,2) DEFAULT 0,
  adjustment numeric(5,2) DEFAULT 0,
  encashed numeric(5,2) DEFAULT 0,
  carried_forward numeric(5,2) DEFAULT 0,
  closing_balance numeric(5,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(employee_id, leave_type_id, year)
);

CREATE TABLE IF NOT EXISTS leave_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  leave_type_id uuid NOT NULL REFERENCES leave_types(id) ON DELETE CASCADE,
  start_date date NOT NULL,
  end_date date NOT NULL,
  days numeric(5,2) NOT NULL,
  reason text,
  contact_during_leave text,
  is_half_day boolean DEFAULT false,
  half_day_type text CHECK (half_day_type IN ('first_half', 'second_half')),
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'withdrawn')),
  approved_by uuid REFERENCES employees(id),
  approved_at timestamptz,
  rejection_reason text,
  document_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS holidays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  date date NOT NULL,
  holiday_type text DEFAULT 'public' CHECK (holiday_type IN ('public', 'restricted', 'optional', 'weekend')),
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, date)
);

CREATE TABLE IF NOT EXISTS attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  date date NOT NULL,
  check_in_time timestamptz,
  check_out_time timestamptz,
  check_in_location text,
  check_in_latitude numeric(10,8),
  check_in_longitude numeric(11,8),
  check_out_location text,
  check_out_latitude numeric(10,8),
  check_out_longitude numeric(11,8),
  working_hours numeric(5,2),
  overtime_hours numeric(5,2) DEFAULT 0,
  status text DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day', 'leave', 'holiday', 'weekend', 'work_from_home')),
  is_regularized boolean DEFAULT false,
  regularization_reason text,
  regularized_by uuid REFERENCES employees(id),
  regularized_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(employee_id, date)
);

CREATE TABLE IF NOT EXISTS announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  target_type text DEFAULT 'all' CHECK (target_type IN ('all', 'department', 'designation', 'specific')),
  target_departments uuid[],
  target_designations uuid[],
  target_employees uuid[],
  publish_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  priority text DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  is_pinned boolean DEFAULT false,
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ticket_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sla_hours integer DEFAULT 24,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  ticket_number text NOT NULL,
  subject text NOT NULL,
  description text,
  category_id uuid REFERENCES ticket_categories(id),
  priority text DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status text DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'pending', 'resolved', 'closed')),
  created_by_employee_id uuid REFERENCES employees(id),
  created_by_user_id uuid REFERENCES users(id),
  assigned_to uuid REFERENCES employees(id),
  assigned_at timestamptz,
  resolved_at timestamptz,
  resolution_notes text,
  due_at timestamptz,
  is_overdue boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, ticket_number)
);

CREATE TABLE IF NOT EXISTS ticket_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  content text NOT NULL,
  is_internal boolean DEFAULT false,
  created_by_employee_id uuid REFERENCES employees(id),
  created_by_user_id uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  max_amount numeric(12,2),
  requires_receipt boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  expense_number text,
  category_id uuid REFERENCES expense_categories(id),
  expense_date date NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency text DEFAULT 'INR',
  description text,
  merchant_name text,
  receipt_url text,
  status text DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'reimbursed')),
  approved_by uuid REFERENCES employees(id),
  approved_at timestamptz,
  rejection_reason text,
  reimbursed_at date,
  reimbursement_reference text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  assigned_to uuid REFERENCES employees(id),
  assigned_by uuid REFERENCES employees(id),
  start_date date,
  due_date date,
  completed_at timestamptz,
  priority text DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled', 'on_hold')),
  progress_percentage integer DEFAULT 0,
  parent_task_id uuid REFERENCES tasks(id),
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS goal_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, name)
);

CREATE TABLE IF NOT EXISTS goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  goal_type_id uuid REFERENCES goal_types(id),
  start_date date,
  end_date date,
  target_value numeric(12,2),
  current_value numeric(12,2) DEFAULT 0,
  unit text,
  weight numeric(5,2) DEFAULT 100,
  status text DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')),
  progress_percentage integer DEFAULT 0,
  manager_assessment text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS goal_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  comment text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS performance_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  review_period_start date NOT NULL,
  review_period_end date NOT NULL,
  review_type text DEFAULT 'annual' CHECK (review_type IN ('annual', 'half_yearly', 'quarterly', 'probation', 'project-based')),
  self_rating numeric(3,2),
  manager_rating numeric(3,2),
  final_rating numeric(3,2),
  self_assessment text,
  manager_assessment text,
  strengths text,
  areas_of_improvement text,
  promotion_recommended boolean DEFAULT false,
  increment_recommended boolean DEFAULT false,
  training_recommended text,
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'self_review', 'manager_review', 'completed')),
  reviewer_id uuid REFERENCES employees(id),
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(employee_id, review_period_start, review_period_end)
);

CREATE TABLE IF NOT EXISTS trainings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  start_date date,
  end_date date,
  duration_hours numeric(5,2),
  training_type text DEFAULT 'internal' CHECK (training_type IN ('internal', 'external', 'online', 'certification')),
  location text,
  is_virtual boolean DEFAULT false,
  meeting_link text,
  trainer_name text,
  trainer_organization text,
  max_participants integer,
  status text DEFAULT 'scheduled' CHECK (status IN ('draft', 'scheduled', 'in_progress', 'completed', 'cancelled')),
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS training_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id uuid NOT NULL REFERENCES trainings(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  enrollment_date timestamptz DEFAULT now(),
  attended boolean DEFAULT false,
  attendance_date date,
  completion_status text DEFAULT 'enrolled' CHECK (completion_status IN ('enrolled', 'attended', 'completed', 'failed', 'dropped')),
  completion_date date,
  score numeric(5,2),
  certificate_url text,
  feedback text,
  rating numeric(3,2),
  created_at timestamptz DEFAULT now(),
  UNIQUE(training_id, employee_id)
);

CREATE TABLE IF NOT EXISTS work_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  report_date date NOT NULL,
  report_type text DEFAULT 'daily' CHECK (report_type IN ('daily', 'weekly', 'monthly')),
  tasks_completed text,
  tasks_in_progress text,
  tasks_planned text,
  blockers text,
  hours_worked numeric(4,2),
  status text DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'reviewed')),
  reviewed_by uuid REFERENCES employees(id),
  reviewed_at timestamptz,
  review_comments text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(employee_id, report_date, report_type)
);

CREATE TABLE IF NOT EXISTS employee_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  document_type text NOT NULL,
  document_name text NOT NULL,
  file_url text NOT NULL,
  file_size integer,
  mime_type text,
  is_verified boolean DEFAULT false,
  verified_by uuid REFERENCES users(id),
  verified_at timestamptz,
  expiry_date date,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS error_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations(id),
  user_id uuid REFERENCES users(id),
  error_type text,
  error_message text,
  error_stack text,
  context jsonb,
  page_url text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS import_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  import_type text NOT NULL,
  file_name text,
  total_rows integer DEFAULT 0,
  successful_rows integer DEFAULT 0,
  failed_rows integer DEFAULT 0,
  status text DEFAULT 'processing' CHECK (status IN ('processing', 'completed', 'failed', 'partial')),
  error_log jsonb,
  imported_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS india_salary_components (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  basic_salary numeric(12,2) NOT NULL,
  dearness_allowance numeric(12,2) DEFAULT 0,
  house_rent_allowance numeric(12,2) DEFAULT 0,
  conveyance_allowance numeric(12,2) DEFAULT 0,
  medical_allowance numeric(12,2) DEFAULT 0,
  special_allowance numeric(12,2) DEFAULT 0,
  other_allowances numeric(12,2) DEFAULT 0,
  is_pf_applicable boolean DEFAULT true,
  pf_contribution_type text DEFAULT 'statutory',
  pf_wage_ceiling numeric(12,2) DEFAULT 15000,
  is_esi_applicable boolean DEFAULT true,
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  effective_to date,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS india_payroll_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  salary_component_id uuid REFERENCES india_salary_components(id),
  pay_period_month integer NOT NULL,
  pay_period_year integer NOT NULL,
  basic_salary numeric(12,2) NOT NULL,
  dearness_allowance numeric(12,2) DEFAULT 0,
  house_rent_allowance numeric(12,2) DEFAULT 0,
  conveyance_allowance numeric(12,2) DEFAULT 0,
  medical_allowance numeric(12,2) DEFAULT 0,
  special_allowance numeric(12,2) DEFAULT 0,
  other_allowances numeric(12,2) DEFAULT 0,
  overtime_hours numeric(5,2) DEFAULT 0,
  overtime_amount numeric(12,2) DEFAULT 0,
  bonus numeric(12,2) DEFAULT 0,
  incentive numeric(12,2) DEFAULT 0,
  arrears numeric(12,2) DEFAULT 0,
  pf_employee numeric(12,2) DEFAULT 0,
  esi_employee numeric(12,2) DEFAULT 0,
  professional_tax numeric(12,2) DEFAULT 0,
  tds numeric(12,2) DEFAULT 0,
  lwf numeric(12,2) DEFAULT 0,
  pf_employer numeric(12,2) DEFAULT 0,
  esi_employer numeric(12,2) DEFAULT 0,
  absence_deduction numeric(12,2) DEFAULT 0,
  loan_deduction numeric(12,2) DEFAULT 0,
  advance_deduction numeric(12,2) DEFAULT 0,
  penalty_deduction numeric(12,2) DEFAULT 0,
  other_deductions numeric(12,2) DEFAULT 0,
  gross_salary numeric(12,2) NOT NULL,
  total_statutory_deductions numeric(12,2) DEFAULT 0,
  total_deductions numeric(12,2) DEFAULT 0,
  net_salary numeric(12,2) NOT NULL,
  ctc numeric(12,2) DEFAULT 0,
  working_days integer DEFAULT 26,
  days_present integer DEFAULT 26,
  days_absent integer DEFAULT 0,
  days_leave integer DEFAULT 0,
  loss_of_pay_days integer DEFAULT 0,
  status text DEFAULT 'draft',
  payment_status text DEFAULT 'pending',
  payment_date date,
  payment_method text DEFAULT 'bank_transfer',
  bank_reference_number text,
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_india_status CHECK (status IN ('draft', 'approved', 'paid', 'cancelled')),
  CONSTRAINT valid_india_payment_status CHECK (payment_status IN ('pending', 'processing', 'paid', 'confirmed', 'failed')),
  CONSTRAINT unique_india_employee_period UNIQUE(employee_id, pay_period_month, pay_period_year)
);

CREATE TABLE IF NOT EXISTS india_payroll_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  pf_establishment_code text,
  esi_establishment_code text,
  tan_number text,
  company_pan text,
  company_bank_account text,
  company_bank_ifsc text,
  company_bank_name text,
  default_working_days_per_month integer DEFAULT 26,
  weekend_days text[] DEFAULT ARRAY['sunday']::text[],
  pf_employee_rate numeric(5,4) DEFAULT 0.12,
  pf_employer_rate numeric(5,4) DEFAULT 0.12,
  pf_wage_ceiling numeric(12,2) DEFAULT 15000,
  eps_rate numeric(5,4) DEFAULT 0.0833,
  esi_employee_rate numeric(5,4) DEFAULT 0.0075,
  esi_employer_rate numeric(5,4) DEFAULT 0.0325,
  esi_wage_ceiling numeric(12,2) DEFAULT 21000,
  pt_state text DEFAULT 'Maharashtra',
  pt_slab_1_limit numeric(12,2) DEFAULT 7500,
  pt_slab_1_tax numeric(12,2) DEFAULT 0,
  pt_slab_2_limit numeric(12,2) DEFAULT 10000,
  pt_slab_2_tax numeric(12,2) DEFAULT 175,
  pt_above_slab_2_tax numeric(12,2) DEFAULT 200,
  ot_rate_multiplier numeric(3,2) DEFAULT 2.00,
  gratuity_eligibility_years integer DEFAULT 5,
  gratuity_max_amount numeric(12,2) DEFAULT 2000000,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id)
);

CREATE TABLE IF NOT EXISTS india_monthly_attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  month integer NOT NULL CHECK (month >= 1 AND month <= 12),
  year integer NOT NULL CHECK (year >= 2020),
  total_working_days integer NOT NULL DEFAULT 26,
  days_present integer DEFAULT 0,
  days_absent integer DEFAULT 0,
  days_leave integer DEFAULT 0,
  days_weekend integer DEFAULT 0,
  days_holiday integer DEFAULT 0,
  late_days integer DEFAULT 0,
  half_days integer DEFAULT 0,
  overtime_hours numeric(6,2) DEFAULT 0,
  loss_of_pay_days integer DEFAULT 0,
  is_finalized boolean DEFAULT false,
  finalized_at timestamptz,
  finalized_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, employee_id, month, year)
);

CREATE TABLE IF NOT EXISTS india_employee_loans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  loan_number text,
  loan_type text DEFAULT 'personal' CHECK (loan_type IN ('personal', 'housing', 'vehicle', 'emergency', 'festival', 'other')),
  loan_amount numeric(12,2) NOT NULL,
  installment_amount numeric(12,2) NOT NULL,
  total_installments integer NOT NULL,
  paid_installments integer DEFAULT 0,
  remaining_amount numeric(12,2),
  start_date date NOT NULL,
  end_date date,
  interest_rate numeric(5,2) DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'active', 'completed', 'cancelled', 'rejected')),
  approved_by uuid REFERENCES users(id),
  approved_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS india_employee_advances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  advance_number text,
  advance_amount numeric(12,2) NOT NULL,
  recovery_amount numeric(12,2) NOT NULL,
  total_recoveries integer NOT NULL DEFAULT 1,
  paid_recoveries integer DEFAULT 0,
  remaining_amount numeric(12,2),
  advance_date date NOT NULL DEFAULT CURRENT_DATE,
  reason text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'active', 'completed', 'rejected')),
  approved_by uuid REFERENCES users(id),
  approved_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS india_gratuity_calculations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  calculation_date date NOT NULL DEFAULT CURRENT_DATE,
  joining_date date NOT NULL,
  years_of_service numeric(10,2) NOT NULL,
  last_drawn_basic numeric(12,2) NOT NULL,
  last_drawn_da numeric(12,2) DEFAULT 0,
  gratuity_amount numeric(12,2) NOT NULL,
  calculation_type text DEFAULT 'estimate' CHECK (calculation_type IN ('estimate', 'final', 'resignation', 'retirement', 'termination', 'death')),
  is_eligible boolean DEFAULT true,
  is_final boolean DEFAULT false,
  separation_date date,
  separation_reason text,
  notes text,
  calculated_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS india_bank_transfer_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  pay_period_month integer NOT NULL,
  pay_period_year integer NOT NULL,
  total_employees integer NOT NULL,
  total_amount numeric(14,2) NOT NULL,
  file_content text NOT NULL,
  file_format text DEFAULT 'csv' CHECK (file_format IN ('csv', 'txt', 'xlsx')),
  status text DEFAULT 'generated' CHECK (status IN ('generated', 'uploaded', 'processed', 'failed')),
  generated_by uuid REFERENCES users(id),
  generated_at timestamptz DEFAULT now(),
  utr_reference text,
  processed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS india_tds_declarations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  financial_year text NOT NULL,
  tax_regime text DEFAULT 'new' CHECK (tax_regime IN ('old', 'new')),
  life_insurance numeric(12,2) DEFAULT 0,
  ppf numeric(12,2) DEFAULT 0,
  elss numeric(12,2) DEFAULT 0,
  nsc numeric(12,2) DEFAULT 0,
  housing_loan_principal numeric(12,2) DEFAULT 0,
  tuition_fees numeric(12,2) DEFAULT 0,
  sukanya_samriddhi numeric(12,2) DEFAULT 0,
  health_insurance_self numeric(12,2) DEFAULT 0,
  health_insurance_parents numeric(12,2) DEFAULT 0,
  preventive_checkup numeric(12,2) DEFAULT 0,
  housing_loan_interest numeric(12,2) DEFAULT 0,
  actual_rent_paid numeric(12,2) DEFAULT 0,
  city_type text DEFAULT 'non_metro' CHECK (city_type IN ('metro', 'non_metro')),
  section_80e_education_loan numeric(12,2) DEFAULT 0,
  section_80g_donations numeric(12,2) DEFAULT 0,
  section_80tta_savings_interest numeric(12,2) DEFAULT 0,
  nps_80ccd_1b numeric(12,2) DEFAULT 0,
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'verified', 'approved')),
  submitted_at timestamptz,
  verified_by uuid REFERENCES users(id),
  verified_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(employee_id, financial_year)
);

CREATE TABLE IF NOT EXISTS loyalty_cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id uuid NOT NULL UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    card_number text NOT NULL UNIQUE,
    points_earned integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS loyalty_point_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    points integer NOT NULL,
    transaction_type text NOT NULL,
    reference_id uuid,
    description text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title text NOT NULL,
    message text NOT NULL,
    type text,
    related_id uuid,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS policies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    content text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS employee_charges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    amount numeric(12,2) NOT NULL,
    reason text,
    created_at timestamptz DEFAULT now()
);


