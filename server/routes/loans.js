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

module.exports = router;
