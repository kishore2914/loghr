-- Add early_checkout_reason column to attendance_records table
ALTER TABLE attendance_records ADD COLUMN IF NOT EXISTS early_checkout_reason TEXT;

-- For backward compatibility or if 'attendance' table is also used
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS early_checkout_reason TEXT;
