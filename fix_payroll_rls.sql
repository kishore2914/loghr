-- FIX RLS FOR PAYROLL RECORDS
-- Enable RLS and allow users to view their own payroll records

-- 1. Enable RLS
ALTER TABLE india_payroll_records ENABLE ROW LEVEL SECURITY;

-- 2. Create Policy for SELECT
-- Allows a user to select rows where the employee_id matches their own employee_id from user_profiles
DROP POLICY IF EXISTS "Users can view own payroll records" ON india_payroll_records;

CREATE POLICY "Users can view own payroll records"
ON india_payroll_records
FOR SELECT
USING (
  employee_id IN (
    SELECT employee_id 
    FROM user_profiles 
    WHERE user_id = auth.uid()
  )
);

-- 3. (Optional) Allow admins to view all (if needed here, usually handled via admin service role)
-- CREATE POLICY "Admins can view all payroll" ...
