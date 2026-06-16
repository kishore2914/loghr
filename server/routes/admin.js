const express = require('express');
const bcrypt = require('bcryptjs');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Helper to get organization ID for the logged-in admin user
async function getOrgId(userId) {
  const result = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0]?.organization_id;
}

// GET /api/admin/stats/summary
router.get('/stats/summary', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const todayStr = new Date().toISOString().split('T')[0];

    // 1. Total employees count
    const totalEmpRes = await query(
      'SELECT COUNT(*) FROM user_profiles WHERE organization_id = $1 AND is_active = true',
      [orgId]
    );
    const totalEmployees = parseInt(totalEmpRes.rows[0].count);

    // 2. Active today count (checked in today, check_out_time is null)
    const activeTodayRes = await query(
      `SELECT COUNT(DISTINCT employee_id) FROM attendance 
       WHERE organization_id = $1 AND date = $2 AND check_out_time IS NULL`,
      [orgId, todayStr]
    );
    const activeToday = parseInt(activeTodayRes.rows[0].count);

    // 3. On leave today count
    const onLeaveRes = await query(
      `SELECT COUNT(*) FROM leave_applications 
       WHERE organization_id = $1 AND status = 'approved' AND start_date <= $2 AND end_date >= $2`,
      [orgId, todayStr]
    );
    const onLeaveToday = parseInt(onLeaveRes.rows[0].count);

    // 4. Pending leaves count
    const pendingLeavesRes = await query(
      "SELECT COUNT(*) FROM leave_applications WHERE organization_id = $1 AND status = 'pending'",
      [orgId]
    );
    const pendingLeaves = parseInt(pendingLeavesRes.rows[0].count);

    // 5. Pending expenses count
    const pendingExpensesRes = await query(
      "SELECT COUNT(*) FROM expenses WHERE organization_id = $1 AND status = 'pending'",
      [orgId]
    );
    const pendingExpenses = parseInt(pendingExpensesRes.rows[0].count);

    // 6. Upcoming birthdays count (within next 7 days)
    const employeesRes = await query(
      'SELECT date_of_birth FROM employees WHERE organization_id = $1 AND is_active = true',
      [orgId]
    );
    let upcomingBirthdays = 0;
    const today = new Date();
    for (const emp of employeesRes.rows) {
      if (emp.date_of_birth) {
        const dob = new Date(emp.date_of_birth);
        const thisYearBday = new Date(today.getFullYear(), dob.getMonth(), dob.getDate());
        const diffDays = Math.ceil((thisYearBday - today) / (1000 * 60 * 60 * 24));
        if (diffDays >= 0 && diffDays <= 7) {
          upcomingBirthdays++;
        }
      }
    }

    res.json({
      totalEmployees,
      activeToday,
      onLeaveToday,
      pendingLeaves,
      pendingExpenses,
      upcomingBirthdays,
    });
  } catch (error) {
    console.error('Error fetching admin dashboard stats summary:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/stats/salary-due
router.get('/stats/salary-due', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT pr.*, up.full_name as employee_name
       FROM india_payroll_records pr
       JOIN employees e ON pr.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE pr.organization_id = $1 AND pr.status = 'pending'
       ORDER BY pr.created_at DESC LIMIT 10`,
      [orgId]
    );

    const mapped = result.rows.map(row => ({
      name: row.employee_name || 'Unknown',
      amount: parseFloat(row.gross_salary || row.net_salary || 0.0),
      currency: 'INR',
    }));

    res.json(mapped);
  } catch (error) {
    console.error('Error fetching salary due list:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/stats/birthdays
router.get('/stats/birthdays', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT e.date_of_birth, up.full_name 
       FROM employees e
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE e.organization_id = $1 AND e.is_active = true AND e.date_of_birth IS NOT NULL`,
      [orgId]
    );

    const today = new Date();
    const birthdays = [];
    for (const record of result.rows) {
      const dob = new Date(record.date_of_birth);
      const thisYearBirthday = new Date(today.getFullYear(), dob.getMonth(), dob.getDate());
      const daysUntil = Math.ceil((thisYearBirthday - today) / (1000 * 60 * 60 * 24));

      if (daysUntil >= 0 && daysUntil <= 7) {
        birthdays.push({
          name: record.full_name || 'Unknown',
          date_of_birth: record.date_of_birth,
        });
      }
    }

    res.json(birthdays.slice(0, 10));
  } catch (error) {
    console.error('Error fetching upcoming birthdays:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/stats/payroll-monthly
router.get('/stats/payroll-monthly', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1; // 1-indexed

    const result = await query(
      `SELECT * FROM india_payroll_records 
       WHERE organization_id = $1 AND pay_period_month = $2 AND pay_period_year = $3`,
      [orgId, currentMonth, currentYear]
    );

    let totalAmount = 0.0;
    let paidCount = 0;
    let pendingCount = 0;
    let processingCount = 0;

    for (const record of result.rows) {
      const amt = parseFloat(record.gross_salary || record.net_salary || 0.0);
      totalAmount += amt;

      const status = record.status ? record.status.toLowerCase() : 'pending';
      if (status === 'paid') paidCount++;
      else if (status === 'pending') pendingCount++;
      else if (status === 'processing') processingCount++;
    }

    res.json({
      total_amount: totalAmount,
      paid_count: paidCount,
      pending_count: pendingCount,
      processing_count: processingCount,
      currency: 'INR',
    });
  } catch (error) {
    console.error('Error fetching monthly payroll stats:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/employees
router.get('/employees', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT 
        e.*,
        up.id as profile_id,
        up.user_id,
        up.avatar_url,
        up.is_active as user_active,
        up.role as user_role,
        up.full_name,
        d.name as department_name,
        ds.name as designation_name
       FROM employees e
       LEFT JOIN user_profiles up ON e.id = up.employee_id
       LEFT JOIN departments d ON e.department_id = d.id
       LEFT JOIN designations ds ON e.designation_id = ds.id
       WHERE e.organization_id = $1 AND e.is_active = true
       ORDER BY e.employee_code`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching admin employees list:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/admin/employees
router.post('/employees', authenticateToken, async (req, res) => {
  const {
    email, password, role,
    employeeCode, firstName, lastName,
    personalEmail, companyEmail, mobileNumber,
    dateOfBirth, gender, dateOfJoining,
    departmentId, designationId,
  } = req.body;

  if (!email || !password || !employeeCode || !firstName) {
    return res.status(400).json({ error: 'Missing required credentials' });
  }

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // 1. Create standard User
    const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'User already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const userResult = await query(
      'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) RETURNING id',
      [email, passwordHash, role || 'employee']
    );
    const userId = userResult.rows[0].id;

    // 2. Create Employee
    const empResult = await query(
      `INSERT INTO employees (
        organization_id, employee_code, first_name, last_name,
        personal_email, company_email, mobile_number,
        date_of_birth, gender, date_of_joining,
        department_id, designation_id, is_active
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, true)
      RETURNING id`,
      [
        orgId, employeeCode, firstName, lastName || null,
        personalEmail || email, companyEmail || null, mobileNumber || null,
        dateOfBirth || null, gender || null, dateOfJoining || null,
        departmentId || null, designationId || null,
      ]
    );
    const employeeId = empResult.rows[0].id;

    // 3. Create User Profile
    await query(
      `INSERT INTO user_profiles (
        user_id, organization_id, employee_id, full_name, email, phone, role, is_active
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, true)`,
      [
        userId, orgId, employeeId, `${firstName} ${lastName || ''}`.trim(),
        email, mobileNumber || null, role || 'employee'
      ]
    );

    res.status(201).json({ success: true, employeeId });
  } catch (error) {
    console.error('Error creating employee:', error);
    res.status(500).json({ error: 'Server error creating employee' });
  }
});

// PUT /api/admin/employees/:id
router.put('/employees/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const updates = req.body;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // Validate ownership
    const empCheck = await query('SELECT id FROM employees WHERE id = $1 AND organization_id = $2', [id, orgId]);
    if (empCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    const fields = [
      'first_name', 'last_name', 'personal_email', 'company_email', 'mobile_number',
      'date_of_birth', 'gender', 'date_of_joining', 'department_id', 'designation_id'
    ];

    const sets = [];
    const params = [];
    let paramIndex = 1;

    fields.forEach(field => {
      if (updates[field] !== undefined) {
        sets.push(`${field} = $${paramIndex}`);
        params.push(updates[field]);
        paramIndex++;
      }
    });

    if (sets.length > 0) {
      params.push(id);
      params.push(orgId);
      await query(
        `UPDATE employees SET ${sets.join(', ')} WHERE id = $${paramIndex} AND organization_id = $${paramIndex + 1}`,
        params
      );
    }

    // Update user profiles also
    if (updates.first_name !== undefined || updates.last_name !== undefined) {
      const firstName = updates.first_name || '';
      const lastName = updates.last_name || '';
      await query(
        `UPDATE user_profiles SET full_name = $1 WHERE employee_id = $2`,
        [`${firstName} ${lastName}`.trim(), id]
      );
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error updating employee:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/leave-balances
router.get('/leave-balances', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT lb.*, up.full_name, lt.name as leave_type_name
       FROM leave_balances lb
       JOIN employees e ON lb.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       JOIN leave_types lt ON lb.leave_type_id = lt.id
       WHERE lb.organization_id = $1`,
      [orgId]
    );

    const mapped = result.rows.map(row => ({
      employee_id: row.employee_id,
      employee_name: row.full_name,
      leave_type_name: row.leave_type_name,
      year: row.year,
      closing_balance: parseFloat(row.closing_balance || 0.0),
      accrued: parseFloat(row.accrued || 0.0),
      used: parseFloat(row.used || 0.0),
    }));

    res.json(mapped);
  } catch (error) {
    console.error('Error getting leave balances:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/payroll-employees
router.get('/payroll-employees', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1;

    const result = await query(
      `SELECT 
        e.id as employee_id,
        up.full_name as name,
        e.employee_code,
        ds.name as designation,
        COALESCE(pr.gross_salary, pc.gross_salary, 0) as gross_salary,
        COALESCE(pr.status, 'unprocessed') as payroll_status
       FROM employees e
       JOIN user_profiles up ON e.id = up.employee_id
       LEFT JOIN designations ds ON e.designation_id = ds.id
       LEFT JOIN india_payroll_config pc ON e.id = pc.employee_id
       LEFT JOIN india_payroll_records pr ON e.id = pr.employee_id 
            AND pr.pay_period_month = $1 AND pr.pay_period_year = $2
       WHERE e.organization_id = $3 AND e.is_active = true`,
      [currentMonth, currentYear, orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error getting payroll employees:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/payroll-summary
router.get('/payroll-summary', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1;

    const result = await query(
      `SELECT 
        SUM(COALESCE(gross_salary, 0)) as total_gross,
        SUM(COALESCE(net_salary, 0)) as total_net,
        SUM(COALESCE(employer_pf, 0) + COALESCE(employer_esi, 0)) as total_employer_contributions,
        COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid_count,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count
       FROM india_payroll_records
       WHERE organization_id = $1 AND pay_period_month = $2 AND pay_period_year = $3`,
      [orgId, currentMonth, currentYear]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching payroll summary:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/statutory-compliance
router.get('/statutory-compliance', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1;

    const result = await query(
      `SELECT 
        SUM(COALESCE(employee_pf, 0) + COALESCE(employer_pf, 0)) as pf_compliance,
        SUM(COALESCE(employee_esi, 0) + COALESCE(employer_esi, 0)) as esi_compliance,
        SUM(COALESCE(tds, 0)) as tds_compliance
       FROM india_payroll_records
       WHERE organization_id = $1 AND pay_period_month = $2 AND pay_period_year = $3`,
      [orgId, currentMonth, currentYear]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching statutory compliance stats:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/admin/payroll/process
router.post('/payroll/process', authenticateToken, async (req, res) => {
  const { month, year } = req.body;
  if (!month || !year) {
    return res.status(400).json({ error: 'Month and year are required' });
  }

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // Fetch active employees with payroll config
    const configs = await query(
      `SELECT e.id as employee_id, pc.*
       FROM employees e
       JOIN india_payroll_config pc ON e.id = pc.employee_id
       WHERE e.organization_id = $1 AND e.is_active = true`,
      [orgId]
    );

    for (const config of configs.rows) {
      // Check if already processed
      const existing = await query(
        `SELECT id FROM india_payroll_records 
         WHERE employee_id = $1 AND pay_period_month = $2 AND pay_period_year = $3`,
        [config.employee_id, month, year]
      );

      if (existing.rows.length === 0) {
        // Insert a new record from config values
        const gross = parseFloat(config.gross_salary || 0.0);
        const basic = parseFloat(config.basic_salary || gross * 0.5);
        const hra = parseFloat(config.hra || gross * 0.2);
        
        // simple PF / ESI calculation
        const pf = basic * 0.12;
        const esi = gross <= 21000 ? gross * 0.0075 : 0.0;
        const employerPf = basic * 0.12;
        const employerEsi = gross <= 21000 ? gross * 0.0325 : 0.0;
        
        const net = gross - pf - esi;

        await query(
          `INSERT INTO india_payroll_records (
            organization_id, employee_id, pay_period_month, pay_period_year,
            basic_salary, hra, gross_salary, net_salary, 
            employee_pf, employer_pf, employee_esi, employer_esi, status
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'pending')`,
          [
            orgId, config.employee_id, month, year,
            basic, hra, gross, net,
            pf, employerPf, esi, employerEsi
          ]
        );
      }
    }

    res.json({ success: true, message: 'Payroll records generated successfully' });
  } catch (error) {
    console.error('Error processing payroll:', error);
    res.status(500).json({ error: 'Server error processing payroll' });
  }
});

// GET /api/admin/attendance
router.get('/attendance', authenticateToken, async (req, res) => {
  const { date } = req.query;
  const filterDate = date || new Date().toISOString().split('T')[0];

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT 
        a.*,
        up.full_name as employee_name,
        e.employee_code
       FROM attendance a
       JOIN employees e ON a.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE a.organization_id = $1 AND a.date = $2`,
      [orgId, filterDate]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching admin attendance:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/admin/announcements
router.post('/announcements', authenticateToken, async (req, res) => {
  const { title, content, targetAudience, isUrgent } = req.body;
  if (!title || !content) {
    return res.status(400).json({ error: 'Title and content are required' });
  }

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `INSERT INTO announcements (
        organization_id, title, content, target_audience, is_urgent, created_by, is_active
      ) VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING *`,
      [orgId, title, content, targetAudience || 'all', isUrgent || false, req.user.userId]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating announcement:', error);
    res.status(500).json({ error: 'Server error creating announcement' });
  }
});

// GET /api/admin/department-stats
router.get('/department-stats', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT 
        d.id as department_id,
        d.name as department_name,
        COUNT(e.id) as employee_count
       FROM departments d
       LEFT JOIN employees e ON d.id = e.department_id AND e.is_active = true
       WHERE d.organization_id = $1 AND d.is_active = true
       GROUP BY d.id, d.name
       ORDER BY d.name`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching admin department stats:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/designations
router.get('/designations', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      'SELECT name FROM designations WHERE organization_id = $1 AND is_active = true ORDER BY name',
      [orgId]
    );

    const designations = result.rows.map(row => row.name);
    res.json(designations);
  } catch (error) {
    console.error('Error fetching designation list:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/tasks/stats
router.get('/tasks/stats', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress
       FROM tasks WHERE organization_id = $1`,
      [orgId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error getting admin task stats:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/tasks/all
router.get('/tasks/all', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT t.*, up.full_name as assignee_name
       FROM tasks t
       LEFT JOIN employees e ON t.assigned_to = e.id
       LEFT JOIN user_profiles up ON e.id = up.employee_id
       WHERE t.organization_id = $1
       ORDER BY t.created_at DESC`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error getting all tasks:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/leaves/analytics
router.get('/leaves/analytics', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT 
        COUNT(*) as total_requests,
        COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected
       FROM leave_applications WHERE organization_id = $1`,
      [orgId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error getting leave analytics:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/leaves/types
router.get('/leaves/types', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      'SELECT * FROM leave_types WHERE organization_id = $1 AND is_active = true',
      [orgId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching admin leave types:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
