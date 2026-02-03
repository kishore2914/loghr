-- Refined Loyalty Card Schema Implementation
 
-- 1. Create loyalty_cards table
CREATE TABLE IF NOT EXISTS loyalty_cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id uuid NOT NULL UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    card_number text NOT NULL UNIQUE,
    points_earned integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
 
-- 2. Create loyalty_point_transactions table
CREATE TABLE IF NOT EXISTS loyalty_point_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    points integer NOT NULL,
    transaction_type text NOT NULL, -- 'task_completion', 'goal_completion', 'attendance', 'manual', etc.
    reference_id uuid, -- link to task_id, goal_id, etc.
    description text,
    created_at timestamptz DEFAULT now()
);
 
-- 3. Enable RLS
ALTER TABLE loyalty_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_point_transactions ENABLE ROW LEVEL SECURITY;
 
-- 4. RLS Policies for loyalty_cards
-- Employees can view their own card
DROP POLICY IF EXISTS "Employees can view their own loyalty card" ON loyalty_cards;
CREATE POLICY "Employees can view their own loyalty card"
    ON loyalty_cards FOR SELECT
    USING (employee_id IN (
        SELECT id FROM employees WHERE user_id = auth.uid()
    ));
 
-- Admin/HR can view all cards
DROP POLICY IF EXISTS "Admin and HR can view all loyalty cards" ON loyalty_cards;
CREATE POLICY "Admin and HR can view all loyalty cards"
    ON loyalty_cards FOR ALL
    USING (EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
        AND role IN ('admin', 'hr', 'super_admin', 'manager')
    ));
 
-- 5. RLS Policies for loyalty_point_transactions
-- Employees can view their own transactions
DROP POLICY IF EXISTS "Employees can view their own point transactions" ON loyalty_point_transactions;
CREATE POLICY "Employees can view their own point transactions"
    ON loyalty_point_transactions FOR SELECT
    USING (employee_id IN (
        SELECT id FROM employees WHERE user_id = auth.uid()
    ));
 
-- Admin/HR can view all transactions
DROP POLICY IF EXISTS "Admin and HR can view all point transactions" ON loyalty_point_transactions;
CREATE POLICY "Admin and HR can view all point transactions"
    ON loyalty_point_transactions FOR ALL
    USING (EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
        AND role IN ('admin', 'hr', 'super_admin', 'manager')
    ));
 
-- 6. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_org_id ON loyalty_cards(organization_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_point_transactions_emp_id ON loyalty_point_transactions(employee_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_point_transactions_org_id ON loyalty_point_transactions(organization_id);
 
-- 7. Trigger to update updated_at on loyalty_cards
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';
 
DROP TRIGGER IF EXISTS update_loyalty_cards_updated_at ON loyalty_cards;
CREATE TRIGGER update_loyalty_cards_updated_at
    BEFORE UPDATE ON loyalty_cards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 8. Auto-generation logic for existing employees
CREATE OR REPLACE FUNCTION generate_16_digit_card() RETURNS TEXT AS $$
DECLARE
  new_card_number TEXT;
BEGIN
    new_card_number := '';
    FOR i IN 1..16 LOOP
      new_card_number := new_card_number || floor(random() * 10)::TEXT;
    END LOOP;
    RETURN new_card_number;
END;
$$ LANGUAGE plpgsql;

-- Insert loyalty cards for employees who don't have one
INSERT INTO loyalty_cards (organization_id, employee_id, card_number)
SELECT organization_id, id, generate_16_digit_card()
FROM employees
WHERE id NOT IN (SELECT employee_id FROM loyalty_cards)
AND organization_id IS NOT NULL;
