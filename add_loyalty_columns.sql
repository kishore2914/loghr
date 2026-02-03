-- Migration to add loyalty points and card number to employees table
ALTER TABLE public.employees 
ADD COLUMN IF NOT EXISTS loyalty_points INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS loyalty_card_number TEXT;

-- Function to generate a random 16-digit card number
CREATE OR REPLACE FUNCTION generate_loyalty_card_number() RETURNS TEXT AS $$
DECLARE
  new_card_number TEXT;
  done BOOL DEFAULT FALSE;
BEGIN
  WHILE NOT done LOOP
    new_card_number := '';
    FOR i IN 1..16 LOOP
      new_card_number := new_card_number || floor(random() * 10)::TEXT;
    END LOOP;
    
    -- Ensure uniqueness (unlikely to collide but good practice)
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE loyalty_card_number = new_card_number) THEN
      done := TRUE;
    END IF;
  END LOOP;
  RETURN new_card_number;
END;
$$ LANGUAGE plpgsql;

-- Update existing employees who don't have a card number
UPDATE public.employees 
SET loyalty_card_number = generate_loyalty_card_number() 
WHERE loyalty_card_number IS NULL;

-- Function to award loyalty points
CREATE OR REPLACE FUNCTION award_loyalty_points(emp_id UUID, points_to_add INTEGER) RETURNS VOID AS $$
BEGIN
  UPDATE public.employees 
  SET loyalty_points = loyalty_points + points_to_add 
  WHERE id = emp_id;
END;
$$ LANGUAGE plpgsql;
