-- SIMPLE RLS Policies for user_profiles table
-- Run this FIRST to fix the login issue
-- Go to Supabase Dashboard > SQL Editor > New Query > Paste this > Run

-- Step 1: Drop all existing policies (to start fresh)
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON user_profiles;

-- Step 2: Enable RLS (if not already enabled)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 3: ESSENTIAL POLICY - Allow users to read their own profile
-- This is required for login to work!
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid() = id);

-- Step 4: Allow users to create their own profile
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Step 5: Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- That's it! These 3 policies should fix your login issue.
-- After running this, try logging in again.
-- 
-- Note: If you need admin policies later, you can add them, but they require
-- a more complex setup to avoid circular dependencies.













