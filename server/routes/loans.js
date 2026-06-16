const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getEmployeeId(userId) {
  const result = await query('SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0] || { employee_id: null, organization_id: null };
}

// GET /api/loans
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM india_employee_loans WHERE employee_id = $1 ORDER BY created_at DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching loans:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/loans/advances
router.get('/advances', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM india_employee_advances WHERE employee_id = $1 ORDER BY created_at DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching advances:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/loans/apply
router.post('/apply', authenticateToken, async (req, res) => {
  const { amount, installmentAmount, installmentsCount, loanType, interestRate, notes } = req.body;
  if (!amount || !installmentAmount || !installmentsCount) {
    return res.status(400).json({ error: 'Missing required loan fields' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) {
      return res.status(400).json({ error: 'No employee record linked to user' });
    }

    const loanNo = 'LN-' + Math.floor(100000 + Math.random() * 900000);
    const startDate = new Date().toISOString().split('T')[0];

    const result = await query(
      `INSERT INTO india_employee_loans (
        organization_id, employee_id, loan_number, loan_type, loan_amount,
        installment_amount, total_installments, paid_installments, remaining_amount,
        start_date, interest_rate, status, notes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        organization_id, employee_id, loanNo, loanType || 'personal', amount,
        installmentAmount, installmentsCount, 0, amount,
        startDate, interestRate || 0, 'pending', notes || null
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error applying for loan:', error);
    res.status(500).json({ error: 'Server error applying for loan' });
  }
});

// POST /api/loans/advance-request
router.post('/advance-request', authenticateToken, async (req, res) => {
  const { amount, recoveryAmount, totalRecoveries, reason, notes } = req.body;
  if (!amount || !recoveryAmount) {
    return res.status(400).json({ error: 'Missing required advance fields' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) {
      return res.status(400).json({ error: 'No employee record linked to user' });
    }

    const advNo = 'ADV-' + Math.floor(100000 + Math.random() * 900000);

    const result = await query(
      `INSERT INTO india_employee_advances (
        organization_id, employee_id, advance_number, advance_amount,
        recovery_amount, total_recoveries, paid_recoveries, remaining_amount,
        reason, status, notes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *`,
      [
        organization_id, employee_id, advNo, amount,
        recoveryAmount, totalRecoveries || 1, 0, amount,
        reason || null, 'pending', notes || null
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error requesting advance:', error);
    res.status(500).json({ error: 'Server error requesting advance' });
  }
});

// GET /api/loans/eligibility
router.get('/eligibility', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // Retrieve employee record
    const empRes = await query(
      `SELECT e.id as employee_id, e.date_of_joining, e.employment_status, pc.gross_salary
       FROM user_profiles up
       JOIN employees e ON up.employee_id = e.id
       LEFT JOIN india_payroll_config pc ON e.id = pc.employee_id
       WHERE up.user_id = $1`,
      [req.user.userId]
    );

    if (empRes.rows.length === 0) {
      return res.json({
        isEligible: false,
        reason: 'No employee record linked to user',
        monthsWorked: 0,
        status: 'UNKNOWN',
        dateOfJoining: null,
      });
    }

    const emp = empRes.rows[0];
    const dojStr = emp.date_of_joining;
    if (!dojStr) {
      return res.json({
        isEligible: false,
        reason: 'Date of joining not set',
        monthsWorked: 0,
        status: emp.employment_status?.toUpperCase() || 'UNKNOWN',
        dateOfJoining: null,
      });
    }

    const doj = new Date(dojStr);
    const now = new Date();
    const monthsWorked = (now.getFullYear() - doj.getFullYear()) * 12 + (now.getMonth() - doj.getMonth()) + (now.getDate() >= doj.getDate() ? 0 : -1);

    const validStatuses = ['active', 'probation', 'confirmed', 'permanent', 'regular'];
    const statusLower = (emp.employment_status || 'active').toLowerCase().trim();
    const isStatusValid = validStatuses.contains ? validStatuses.contains(statusLower) : validStatuses.indexOf(statusLower) !== -1;

    const isEligible = monthsWorked >= 6 && isStatusValid;

    res.json({
      isEligible,
      reason: isEligible 
          ? null 
          : monthsWorked < 6 
              ? `Must complete 6 months. Completed: ${monthsWorked < 0 ? 0 : monthsWorked} months.`
              : `Status must be active/probation. Current: ${statusLower}`,
      monthsWorked: monthsWorked < 0 ? 0 : monthsWorked,
      status: statusLower.toUpperCase(),
      dateOfJoining: dojStr,
      grossSalary: parseFloat(emp.gross_salary || 0.0),
      employeeId: emp.employee_id,
    });
  } catch (error) {
    console.error('Error checking loan eligibility:', error);
    res.status(500).json({ error: 'Server error checking loan eligibility' });
  }
});

// GET /api/loans/pending
router.get('/pending', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT l.*, up.full_name as employee_name
       FROM india_employee_loans l
       JOIN employees e ON l.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE l.organization_id = $1 AND l.status = 'pending'
       ORDER BY l.created_at DESC`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching pending loans:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Helper to get organization ID
async function getOrgId(userId) {
  const result = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0]?.organization_id;
}

// POST /api/loans/:id/approve
router.post('/:id/approve', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `UPDATE india_employee_loans 
       SET status = 'approved', approved_by = (SELECT employee_id FROM user_profiles WHERE user_id = $1), approved_at = NOW()
       WHERE id = $2 AND organization_id = $3 AND status = 'pending'
       RETURNING *`,
      [req.user.userId, id, orgId]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not approve loan (may not be pending)' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error approving loan:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/loans/:id/reject
router.post('/:id/reject', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { rejectionReason } = req.body;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `UPDATE india_employee_loans 
       SET status = 'rejected', notes = $1, updated_at = NOW()
       WHERE id = $2 AND organization_id = $3 AND status = 'pending'
       RETURNING *`,
      [rejectionReason ? `REJECTED: ${rejectionReason}` : 'REJECTED', id, orgId]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not reject loan (may not be pending)' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error rejecting loan:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
