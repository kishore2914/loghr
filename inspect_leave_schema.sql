-- INSPECT LEAVE TABLES
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('leave_balances', 'leave_applications', 'leave_types');
