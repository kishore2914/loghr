-- SQL to verify and fix admin role for pixelfactory13@gmail.com
-- Run this in Supabase SQL Editor

-- Step 1: Check if the user exists and what their current role is
-- Note: user_profiles uses user_id (not id) to reference auth.users
SELECT 
    up.id,
    up.user_id,
    up.full_name,
    up.role,
    up.is_active,
    au.email
FROM user_profiles up
LEFT JOIN auth.users au ON au.id = up.user_id
WHERE au.email = 'pixelfactory13@gmail.com';

-- Step 2: Update the role to 'admin' if it's not already set correctly
-- (This will update the role regardless of current value - case-insensitive)
UPDATE user_profiles
SET role = 'admin'
WHERE user_id IN (
    SELECT id FROM auth.users WHERE email = 'pixelfactory13@gmail.com'
)
AND LOWER(TRIM(role)) NOT IN ('admin', 'super_admin');

-- Step 3: Verify the update worked
SELECT 
    up.id,
    up.user_id,
    up.full_name,
    up.role,
    up.is_active,
    au.email
FROM user_profiles up
LEFT JOIN auth.users au ON au.id = up.user_id
WHERE au.email = 'pixelfactory13@gmail.com';

-- Expected result: role should be 'admin' or 'super_admin' (both work as admin in the app)

