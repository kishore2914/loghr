-- FIXED RLS Policies for user_profiles table
-- IMPORTANT: The user_profiles table uses user_id (not id) to reference auth.users
-- Run this in Supabase SQL Editor

-- Step 1: Drop all existing policies (to start fresh)
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Service role has full access" ON user_profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

-- Step 2: Enable RLS (if not already enabled)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 3: ESSENTIAL POLICY - Allow users to read their own profile
-- Uses user_id (not id) to match auth.uid()
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid() = user_id);

-- Step 4: Allow users to create their own profile
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Step 5: Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Step 6: Allow admins to view all profiles
-- Note: This checks if the current user is an admin by looking up their own profile
CREATE POLICY "Admins can view all profiles"
ON user_profiles
FOR SELECT
USING (
  -- Check if the current user is an admin by looking up their own profile
  -- This works because Policy 3 allows users to read their own profile
  (SELECT role FROM user_profiles WHERE user_id = auth.uid()) IN ('admin', 'super_admin')
);

-- Step 7: Allow admins to update all profiles
CREATE POLICY "Admins can update all profiles"
ON user_profiles
FOR UPDATE
USING (
  (SELECT role FROM user_profiles WHERE user_id = auth.uid()) IN ('admin', 'super_admin')
)
WITH CHECK (
  (SELECT role FROM user_profiles WHERE user_id = auth.uid()) IN ('admin', 'super_admin')
);

-- Step 8: Allow admins to insert profiles for other users (for admin user management)
CREATE POLICY "Admins can insert profiles"
ON user_profiles
FOR INSERT
WITH CHECK (
  (SELECT role FROM user_profiles WHERE user_id = auth.uid()) IN ('admin', 'super_admin')
);

-- That's it! These policies should fix your login issue.
-- The key difference: using user_id instead of id to match auth.uid()

