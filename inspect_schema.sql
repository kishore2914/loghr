-- INSPECT SCHEMA
-- Run this to see what columns are actually in the table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'india_payroll_config';
