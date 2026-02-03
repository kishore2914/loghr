-- SQL to verify and fix admin role for pixelfactory13@gmail.com
-- Updated for the new schema with user_id column
-- Run this in Supabase SQL Editor

-- Step 1: Check if the user exists and what their current role is
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

-- Step 2: Update the role to 'admin' or 'super_admin' if it's not already set correctly
-- This will update the role regardless of current value (case-insensitive)
UPDATE user_profiles
SET role = 'admin'  -- Change to 'super_admin' if you want super admin access
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

-- Expected result: role should be 'admin' or 'super_admin'

-- Step 4: If the user profile doesn't exist, you may need to create it
-- (This should be handled by the app, but if needed, you can run this)
-- Note: Replace 'USER_UUID_HERE' with the actual UUID from auth.users
/*
INSERT INTO user_profiles (user_id, full_name, role, is_active)
SELECT 
    id,
    'Admin User',
    'admin',
    true
FROM auth.users
WHERE email = 'pixelfactory13@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM user_profiles WHERE user_id = auth.users.id
);
*/

