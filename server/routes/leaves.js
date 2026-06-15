const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getEmployeeId(userId) {
  const result = await query('SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0] || { employee_id: null, organization_id: null };
}

// GET /api/leaves/types
router.get('/types', authenticateToken, async (req, res) => {
  try {
    const { organization_id } = await getEmployeeId(req.user.userId);
    if (!organization_id) return res.json([]);

    const result = await query(
      'SELECT * FROM leave_types WHERE organization_id = $1 AND is_active = true',
      [organization_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching leave types:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/leaves/balances
router.get('/balances', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const currentYear = new Date().getFullYear();
    const result = await query(
      `SELECT lb.*, lt.name as leave_type_name, lt.code as leave_type_code 
       FROM leave_balances lb
       JOIN leave_types lt ON lb.leave_type_id = lt.id
       WHERE lb.employee_id = $1 AND lb.year = $2`,
      [employee_id, currentYear]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching leave balances:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/leaves/applications
router.get('/applications', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      `SELECT la.*, lt.name as leave_type_name, lt.code as leave_type_code
       FROM leave_applications la
       JOIN leave_types lt ON la.leave_type_id = lt.id
       WHERE la.employee_id = $1
       ORDER BY la.created_at DESC`,
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching leave applications:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/leaves/apply
router.post('/apply', authenticateToken, async (req, res) => {
  const { leaveTypeId, startDate, endDate, days, reason, isHalfDay, halfDayType } = req.body;
  if (!leaveTypeId || !startDate || !endDate || !days) {
    return res.status(400).json({ error: 'Missing required leave fields' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) {
      return res.status(400).json({ error: 'No employee record linked to user' });
    }

    const result = await query(
      `INSERT INTO leave_applications (
        organization_id, employee_id, leave_type_id, start_date, end_date,
        days, reason, is_half_day, half_day_type, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *`,
      [
        organization_id, employee_id, leaveTypeId, startDate, endDate,
        days, reason || null, isHalfDay || false, halfDayType || null, 'pending'
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error applying for leave:', error);
    res.status(500).json({ error: 'Server error applying for leave' });
  }
});

// POST /api/leaves/cancel
router.post('/cancel', authenticateToken, async (req, res) => {
  const { applicationId } = req.body;
  if (!applicationId) {
    return res.status(400).json({ error: 'ApplicationId is required' });
  }

  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    const result = await query(
      `UPDATE leave_applications 
       SET status = 'cancelled' 
       WHERE id = $1 AND employee_id = $2 AND status = 'pending'
       RETURNING *`,
      [applicationId, employee_id]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not cancel application (may already be approved/rejected)' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error cancelling leave:', error);
    res.status(500).json({ error: 'Server error cancelling leave' });
  }
});

module.exports = router;
