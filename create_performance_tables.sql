-- Performance System Database Schema
-- This file contains all the table definitions for the performance tracking system

-- ============================================================================
-- Employee Performance Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS employee_performance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL,
  total_xp INTEGER DEFAULT 0,
  current_level INTEGER DEFAULT 1,
  rank TEXT DEFAULT 'Beginner',
  xp_to_next_level INTEGER DEFAULT 100,
  day_streak INTEGER DEFAULT 0,
  badges_earned TEXT[] DEFAULT '{}',
  last_activity_date DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(employee_id)
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_employee_performance_employee_id ON employee_performance(employee_id);

-- ============================================================================
-- Goals Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT CHECK (type IN ('PERSONAL', 'TEAM', 'DEPARTMENT')) DEFAULT 'PERSONAL',
  priority TEXT CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')) DEFAULT 'MEDIUM',
  status TEXT CHECK (status IN ('ACTIVE', 'COMPLETED', 'OVERDUE')) DEFAULT 'ACTIVE',
  progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  start_date DATE NOT NULL,
  due_date DATE NOT NULL,
  completed_date DATE,
  xp_reward INTEGER DEFAULT 25,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_goals_employee_id ON goals(employee_id);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_goals_due_date ON goals(due_date);

-- ============================================================================
-- Badges Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT DEFAULT 'emoji_events',
  color TEXT DEFAULT '#FFD700',
  requirement TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- Employee Badges Junction Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS employee_badges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL,
  badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_date TIMESTAMP DEFAULT NOW(),
  UNIQUE(employee_id, badge_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_employee_badges_employee_id ON employee_badges(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_badges_badge_id ON employee_badges(badge_id);

-- ============================================================================
-- Performance Reviews Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS performance_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL,
  reviewer_id UUID NOT NULL,
  period TEXT NOT NULL,
  rating DECIMAL(2,1) CHECK (rating >= 0 AND rating <= 5) DEFAULT 0.0,
  feedback TEXT,
  goal_id UUID REFERENCES goals(id) ON DELETE SET NULL,
  status TEXT CHECK (status IN ('PENDING', 'COMPLETED')) DEFAULT 'PENDING',
  review_date DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_performance_reviews_employee_id ON performance_reviews(employee_id);
CREATE INDEX IF NOT EXISTS idx_performance_reviews_reviewer_id ON performance_reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_performance_reviews_status ON performance_reviews(status);

-- ============================================================================
-- Activity Feed Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS activity_feed (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL,
  activity_type TEXT NOT NULL,
  description TEXT NOT NULL,
  related_id UUID,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_activity_feed_employee_id ON activity_feed(employee_id);
CREATE INDEX IF NOT EXISTS idx_activity_feed_created_at ON activity_feed(created_at DESC);

-- ============================================================================
-- Add xp_reward column to tasks table (if not exists)
-- ============================================================================
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'xp_reward'
  ) THEN
    ALTER TABLE tasks ADD COLUMN xp_reward INTEGER DEFAULT 25;
  END IF;
END $$;

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE employee_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_feed ENABLE ROW LEVEL SECURITY;

-- Employee Performance Policies
CREATE POLICY "Users can view their own performance"
  ON employee_performance FOR SELECT
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own performance"
  ON employee_performance FOR UPDATE
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "System can insert performance records"
  ON employee_performance FOR INSERT
  WITH CHECK (true);

-- Goals Policies
CREATE POLICY "Users can view their own goals"
  ON goals FOR SELECT
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own goals"
  ON goals FOR UPDATE
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Admins can manage all goals"
  ON goals FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Badges Policies
CREATE POLICY "Everyone can view badges"
  ON badges FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage badges"
  ON badges FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Employee Badges Policies
CREATE POLICY "Users can view their own badges"
  ON employee_badges FOR SELECT
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "System can award badges"
  ON employee_badges FOR INSERT
  WITH CHECK (true);

-- Performance Reviews Policies
CREATE POLICY "Users can view their own reviews"
  ON performance_reviews FOR SELECT
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Reviewers can view reviews they created"
  ON performance_reviews FOR SELECT
  USING (reviewer_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Admins can manage all reviews"
  ON performance_reviews FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Activity Feed Policies
CREATE POLICY "Users can view their own activity"
  ON activity_feed FOR SELECT
  USING (employee_id IN (
    SELECT employee_id FROM user_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "System can insert activity"
  ON activity_feed FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- Sample Data (Optional - for testing)
-- ============================================================================

-- Insert some sample badges
INSERT INTO badges (name, description, icon, color, requirement) VALUES
  ('First Steps', 'Complete your first task', 'emoji_events', '#4CAF50', 'Complete 1 task'),
  ('Task Master', 'Complete 10 tasks', 'emoji_events', '#2196F3', 'Complete 10 tasks'),
  ('Goal Getter', 'Complete your first goal', 'emoji_events', '#FF9800', 'Complete 1 goal'),
  ('Rising Star', 'Reach Level 5', 'emoji_events', '#9C27B0', 'Reach Level 5'),
  ('Streak Master', 'Maintain a 7-day streak', 'emoji_events', '#F44336', 'Maintain 7-day streak')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Functions and Triggers
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers for updated_at
DROP TRIGGER IF EXISTS update_employee_performance_updated_at ON employee_performance;
CREATE TRIGGER update_employee_performance_updated_at
  BEFORE UPDATE ON employee_performance
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_goals_updated_at ON goals;
CREATE TRIGGER update_goals_updated_at
  BEFORE UPDATE ON goals
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_performance_reviews_updated_at ON performance_reviews;
CREATE TRIGGER update_performance_reviews_updated_at
  BEFORE UPDATE ON performance_reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update goal status to OVERDUE
CREATE OR REPLACE FUNCTION update_overdue_goals()
RETURNS void AS $$
BEGIN
  UPDATE goals
  SET status = 'OVERDUE'
  WHERE status = 'ACTIVE'
    AND due_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- You can run this function periodically or create a cron job
-- SELECT update_overdue_goals();
