-- UPDATED RLS Policies for user_profiles table
-- This matches the actual schema where user_id references auth.users(id)
-- Run this in Supabase SQL Editor

-- Step 1: Drop all existing policies (to start fresh)
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Service role has full access" ON user_profiles;

-- Step 2: Enable RLS (if not already enabled)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 3: ESSENTIAL POLICY - Allow users to read their own profile
-- Uses user_id column which references auth.users(id)
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

-- Step 6: Allow admins and super_admins to view all profiles
-- This policy allows users with admin or super_admin role to see all profiles
CREATE POLICY "Admins can view all profiles"
ON user_profiles
FOR SELECT
USING (
  -- Check if current user is admin or super_admin
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() 
    AND role IN ('admin', 'super_admin')
  )
);

-- Step 7: Allow admins and super_admins to update all profiles
CREATE POLICY "Admins can update all profiles"
ON user_profiles
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() 
    AND role IN ('admin', 'super_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() 
    AND role IN ('admin', 'super_admin')
  )
);

-- Step 8: Allow admins and super_admins to insert profiles for other users
CREATE POLICY "Admins can insert profiles"
ON user_profiles
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() 
    AND role IN ('admin', 'super_admin')
  )
);

-- That's it! These policies should work with your schema.
-- The key difference is using user_id instead of id in the policies.

