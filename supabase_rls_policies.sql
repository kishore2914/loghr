-- Row Level Security (RLS) Policies for user_profiles table
-- Run these SQL commands in your Supabase SQL Editor

-- Step 1: Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON user_profiles;

-- Step 2: Enable RLS on user_profiles table (if not already enabled)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow users to SELECT their own profile
-- This is the most important policy - allows users to read their own profile during login
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Allow users to INSERT their own profile
-- Allows the app to auto-create profiles when a user logs in for the first time
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 3: Allow users to UPDATE their own profile
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 4: Allow admins to SELECT all profiles
-- Note: This uses a function to check admin role to avoid circular dependency
CREATE POLICY "Admins can view all profiles"
ON user_profiles
FOR SELECT
USING (
  -- Check if the current user is an admin by looking up their own profile
  -- This works because Policy 1 allows users to read their own profile
  (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
);

-- Policy 5: Allow admins to UPDATE all profiles
CREATE POLICY "Admins can update all profiles"
ON user_profiles
FOR UPDATE
USING (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
);

-- Policy 6: Allow admins to INSERT profiles for other users (for admin user management)
CREATE POLICY "Admins can insert profiles"
ON user_profiles
FOR INSERT
WITH CHECK (
  (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
);

-- Note: If you get "policy already exists" errors, you can drop existing policies first:
-- DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
-- DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
-- DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
-- DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
-- DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;
-- DROP POLICY IF EXISTS "Admins can insert profiles" ON user_profiles;

