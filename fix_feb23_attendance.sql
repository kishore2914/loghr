-- Fix Feb 23 attendance: change work_type from 'Remote' to 'In Office'
-- for employee EMP26188 (Kishore Subramanian)

UPDATE attendance_records
SET 
  work_type = 'In Office',
  gps_verified = true
WHERE 
  date = '2026-02-23'
  AND employee_id = (
    SELECT e.id
    FROM employees e
    WHERE e.employee_id = 'EMP26188'
    LIMIT 1
  );

-- Confirm the update
SELECT date, work_type, check_in_time, check_out_time
FROM attendance_records
WHERE 
  date = '2026-02-23'
  AND employee_id = (
    SELECT e.id FROM employees e WHERE e.employee_id = 'EMP26188' LIMIT 1
  );
