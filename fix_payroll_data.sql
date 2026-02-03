-- FIX PAYROLL DATA VISIBILITY AND LINKAGE
-- Run this script in the Supabase SQL Editor

-- 1. Ensure india_payroll_config has a user_id column used for RLS
ALTER TABLE india_payroll_config ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 2. Link existing payroll records to users via employee_id
--    This updates payroll records to have the correct user_id based on the employee_id in user_profiles
UPDATE india_payroll_config
SET user_id = up.user_id
FROM user_profiles up
WHERE india_payroll_config.employee_id = up.employee_id
  AND india_payroll_config.user_id IS NULL;

-- 3. Enable Row Level Security
ALTER TABLE india_payroll_config ENABLE ROW LEVEL SECURITY;

-- 4. Create/Update Policy to allow users to view their own payroll
--    Allows access if the record's user_id matches OR if the employee_id belongs to the user
DROP POLICY IF EXISTS "Users can view own payroll" ON india_payroll_config;
CREATE POLICY "Users can view own payroll"
ON india_payroll_config
FOR SELECT
USING (
  auth.uid() = user_id
  OR
  employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  )
);

-- 5. (Optional) Check for duplicate records for the same month
--    This helps identify if there's a "Pending" (0 value) and "Approved" (Real value) collision
--    Uncomment to run diagnostic:
/*
SELECT employee_id, pay_period_start, count(*) 
FROM india_payroll_config 
GROUP BY employee_id, pay_period_start 
HAVING count(*) > 1;
*/
