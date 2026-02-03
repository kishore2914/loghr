-- Add check-out location columns to attendance table
-- This migration adds latitude and longitude fields for check-out location tracking

-- Add check_out_latitude column
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS check_out_latitude DOUBLE PRECISION;

-- Add check_out_longitude column
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS check_out_longitude DOUBLE PRECISION;

-- Add comment to document the columns
COMMENT ON COLUMN attendance.check_out_latitude IS 'Latitude of the location where employee checked out';
COMMENT ON COLUMN attendance.check_out_longitude IS 'Longitude of the location where employee checked out';











