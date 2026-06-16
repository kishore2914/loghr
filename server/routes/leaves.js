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

// GET /api/leaves/pending
router.get('/pending', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT la.*, lt.name as leave_type_name, lt.code as leave_type_code, up.full_name as employee_name
       FROM leave_applications la
       JOIN leave_types lt ON la.leave_type_id = lt.id
       JOIN employees e ON la.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE la.organization_id = $1 AND la.status = 'pending'
       ORDER BY la.created_at DESC`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching pending leaves:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Helper to get organization ID
async function getOrgId(userId) {
  const result = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0]?.organization_id;
}

// POST /api/leaves/:id/approve
router.post('/:id/approve', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // Retrieve leave application
    const leaveRes = await query(
      `SELECT la.*, lt.code as leave_code, lt.name as leave_name
       FROM leave_applications la
       JOIN leave_types lt ON la.leave_type_id = lt.id
       WHERE la.id = $1 AND la.organization_id = $2`,
      [id, orgId]
    );

    if (leaveRes.rows.length === 0) {
      return res.status(404).json({ error: 'Leave application not found' });
    }

    const leave = leaveRes.rows[0];
    if (leave.status !== 'pending') {
      return res.status(400).json({ error: `Leave application is already ${leave.status}` });
    }

    // Update status to approved
    await query(
      `UPDATE leave_applications 
       SET status = 'approved', approved_by = (SELECT employee_id FROM user_profiles WHERE user_id = $1), approved_at = NOW() 
       WHERE id = $2`,
      [req.user.userId, id]
    );

    // Sync to attendance calendar
    const startDate = new Date(leave.start_date);
    const endDate = new Date(leave.end_date);
    const leaveCode = (leave.leave_code || '').toLowerCase();
    const leaveName = (leave.leave_name || '').toLowerCase();

    let calendarStatus = 'leave'; // Default
    if (leaveCode.includes('remote') || leaveCode.includes('wfh') || leaveName.includes('wfh') || leaveName.includes('remote')) {
      calendarStatus = 'work_from_home';
    }

    let currentDate = new Date(startDate);
    while (currentDate <= endDate) {
      const dateStr = currentDate.toISOString().split('T')[0];

      // Insert or Update attendance
      const existing = await query(
        'SELECT id, check_in_time FROM attendance WHERE employee_id = $1 AND date = $2',
        [leave.employee_id, dateStr]
      );

      if (existing.rows.length > 0) {
        if (!existing.rows[0].check_in_time) {
          await query(
            'UPDATE attendance SET status = $1, updated_at = NOW() WHERE id = $2',
            [calendarStatus, existing.rows[0].id]
          );
        }
      } else {
        await query(
          `INSERT INTO attendance (organization_id, employee_id, date, status, created_at, updated_at) 
           VALUES ($1, $2, $3, $4, NOW(), NOW())`,
          [orgId, leave.employee_id, dateStr, calendarStatus]
        );
      }

      currentDate.setDate(currentDate.getDate() + 1);
    }

    // Award loyalty points
    try {
      const cardRes = await query('SELECT id FROM loyalty_cards WHERE employee_id = $1', [leave.employee_id]);
      if (cardRes.rows.length > 0) {
        await query(
          `INSERT INTO loyalty_point_transactions (organization_id, employee_id, points, transaction_type, description, reference_id) 
           VALUES ($1, $2, 50, 'earned', $3, $4)`,
          [orgId, leave.employee_id, `Award for approved leave: ${leave.leave_name || 'Leave'}`, id]
        );
        await query(
          `UPDATE loyalty_cards SET points_earned = points_earned + 50 WHERE employee_id = $1`,
          [leave.employee_id]
        );
      }
    } catch (e) {
      console.error('Error awarding points for leave record:', e);
    }

    res.json({ success: true, message: 'Leave approved successfully' });
  } catch (error) {
    console.error('Error approving leave:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/leaves/:id/reject
router.post('/:id/reject', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { rejectionReason } = req.body;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    // Retrieve leave application
    const leaveRes = await query(
      'SELECT employee_id, start_date, end_date, status FROM leave_applications WHERE id = $1 AND organization_id = $2',
      [id, orgId]
    );

    if (leaveRes.rows.length === 0) {
      return res.status(404).json({ error: 'Leave application not found' });
    }

    const leave = leaveRes.rows[0];
    if (leave.status !== 'pending') {
      return res.status(400).json({ error: `Leave application is already ${leave.status}` });
    }

    // Update status to rejected
    await query(
      `UPDATE leave_applications 
       SET status = 'rejected', rejection_reason = $1, updated_at = NOW() 
       WHERE id = $2`,
      [rejectionReason || null, id]
    );

    // Remove calendar entries (only if no check_in_time)
    const startDate = new Date(leave.start_date);
    const endDate = new Date(leave.end_date);
    let currentDate = new Date(startDate);
    while (currentDate <= endDate) {
      const dateStr = currentDate.toISOString().split('T')[0];
      await query(
        `DELETE FROM attendance 
         WHERE employee_id = $1 AND date = $2 AND check_in_time IS NULL`,
        [leave.employee_id, dateStr]
      );
      currentDate.setDate(currentDate.getDate() + 1);
    }

    res.json({ success: true, message: 'Leave rejected successfully' });
  } catch (error) {
    console.error('Error rejecting leave:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
