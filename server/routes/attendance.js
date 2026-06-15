const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Helper: Get employee info (employee_id, organization_id) from user_id
async function getEmployeeInfo(userId) {
  const result = await query(
    'SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1',
    [userId]
  );
  if (result.rows.length > 0 && result.rows[0].employee_id) {
    return {
      employee_id: result.rows[0].employee_id,
      organization_id: result.rows[0].organization_id,
    };
  }
  // Fallback: use user_id itself if no employee linked
  return { employee_id: userId, organization_id: null };
}

// GET /api/attendance/incomplete
router.get('/incomplete', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeInfo(req.user.userId);
    const todayStr = new Date().toISOString().split('T')[0];

    // Find attendance records with check-in but no check-out, excluding today
    const result = await query(
      `SELECT * FROM attendance 
       WHERE employee_id = $1 
         AND check_in_time IS NOT NULL 
         AND check_out_time IS NULL 
         AND date < $2 
       ORDER BY date DESC LIMIT 1`,
      [employee_id, todayStr]
    );

    if (result.rows.length === 0) {
      return res.json(null);
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching incomplete checkout:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/attendance/today
router.get('/today', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeInfo(req.user.userId);
    const todayStr = new Date().toISOString().split('T')[0];

    const result = await query(
      'SELECT * FROM attendance WHERE employee_id = $1 AND date = $2',
      [employee_id, todayStr]
    );

    if (result.rows.length === 0) {
      return res.json(null);
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching today attendance:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/attendance/history
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeInfo(req.user.userId);

    const result = await query(
      'SELECT * FROM attendance WHERE employee_id = $1 ORDER BY date DESC',
      [employee_id]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching attendance history:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/attendance/check-in
router.post('/check-in', authenticateToken, async (req, res) => {
  const { latitude, longitude, address } = req.body;
  if (latitude === undefined || longitude === undefined || !address) {
    return res.status(400).json({ error: 'Latitude, longitude, and address are required' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeInfo(req.user.userId);
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    // Check for incomplete checkout from previous day
    const incompleteResult = await query(
      `SELECT date FROM attendance 
       WHERE employee_id = $1 
         AND check_in_time IS NOT NULL 
         AND check_out_time IS NULL 
         AND date < $2 
       LIMIT 1`,
      [employee_id, todayStr]
    );

    if (incompleteResult.rows.length > 0) {
      return res.status(400).json({
        error: `You have an incomplete checkout from ${incompleteResult.rows[0].date}. Please checkout first.`,
      });
    }

    // Check if record exists for today
    const existing = await query(
      'SELECT id FROM attendance WHERE employee_id = $1 AND date = $2',
      [employee_id, todayStr]
    );

    let attendanceRecord;

    if (existing.rows.length > 0) {
      // Update
      const result = await query(
        `UPDATE attendance
         SET check_in_time = $1,
             check_in_latitude = $2,
             check_in_longitude = $3,
             check_in_location = $4,
             status = 'present',
             check_out_time = NULL,
             check_out_latitude = NULL,
             check_out_longitude = NULL,
             check_out_location = NULL
         WHERE id = $5
         RETURNING *`,
        [now.toISOString(), latitude, longitude, address, existing.rows[0].id]
      );
      attendanceRecord = result.rows[0];
    } else {
      // Insert
      const result = await query(
        `INSERT INTO attendance (
          organization_id, employee_id, date, check_in_time,
          check_in_latitude, check_in_longitude, check_in_location, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *`,
        [organization_id, employee_id, todayStr, now.toISOString(), latitude, longitude, address, 'present']
      );
      attendanceRecord = result.rows[0];
    }

    res.json(attendanceRecord);
  } catch (error) {
    console.error('Check-in error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/attendance/check-out
router.post('/check-out', authenticateToken, async (req, res) => {
  const { attendanceId, latitude, longitude, address, earlyCheckoutReason } = req.body;
  if (!attendanceId || latitude === undefined || longitude === undefined || !address) {
    return res.status(400).json({ error: 'AttendanceId, latitude, longitude, and address are required' });
  }

  try {
    const { employee_id } = await getEmployeeInfo(req.user.userId);
    const now = new Date();

    // Verify record exists and belongs to employee
    const recordCheck = await query(
      'SELECT id, check_in_time FROM attendance WHERE id = $1 AND employee_id = $2',
      [attendanceId, employee_id]
    );

    if (recordCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const checkInTime = new Date(recordCheck.rows[0].check_in_time);
    const workingHours = Math.round(((now - checkInTime) / (1000 * 60 * 60)) * 100) / 100; // rounded to 2 decimals

    const result = await query(
      `UPDATE attendance
       SET check_out_time = $1,
           check_out_latitude = $2,
           check_out_longitude = $3,
           check_out_location = $4,
           working_hours = $5,
           notes = $6
       WHERE id = $7 AND employee_id = $8
       RETURNING *`,
      [now.toISOString(), latitude, longitude, address, workingHours, earlyCheckoutReason || null, attendanceId, employee_id]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Check-out error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/attendance/calendar-request
router.post('/calendar-request', authenticateToken, async (req, res) => {
  const { date, status } = req.body; // status is e.g. 'remote_wfh', 'planned_leave'
  if (!date || !status) {
    return res.status(400).json({ error: 'Date and status are required' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeInfo(req.user.userId);
    const dateStr = date.split('T')[0];

    // Determine mapped status values
    let mappedStatus = 'present';
    if (status === 'planned_leave') {
      mappedStatus = 'leave';
    } else if (status === 'remote_wfh') {
      mappedStatus = 'work_from_home';
    }

    // Check if record exists
    const existing = await query(
      'SELECT id FROM attendance WHERE employee_id = $1 AND date = $2',
      [employee_id, dateStr]
    );

    let record;
    if (existing.rows.length > 0) {
      const result = await query(
        `UPDATE attendance
         SET status = $1,
             notes = $2
         WHERE id = $3
         RETURNING *`,
        [mappedStatus, `Calendar Request: ${status}`, existing.rows[0].id]
      );
      record = result.rows[0];
    } else {
      const result = await query(
        `INSERT INTO attendance (organization_id, employee_id, date, status, notes)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [organization_id, employee_id, dateStr, mappedStatus, `Calendar Request: ${status}`]
      );
      record = result.rows[0];
    }

    res.json({ success: true, record });
  } catch (error) {
    console.error('Calendar request error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/attendance/calendar-update
router.post('/calendar-update', authenticateToken, async (req, res) => {
  const { userId, date, status } = req.body;
  if (!userId || !date || !status) {
    return res.status(400).json({ error: 'UserId, date, and status are required' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeInfo(userId);
    const dateStr = date.split('T')[0];

    // Determine mapped status values
    let mappedStatus = 'present';
    if (status === 'planned_leave' || status === 'leave') {
      mappedStatus = 'leave';
    } else if (status === 'remote_wfh' || status === 'work_from_home') {
      mappedStatus = 'work_from_home';
    } else {
      mappedStatus = status;
    }

    // Check if record exists
    const existing = await query(
      'SELECT id FROM attendance WHERE employee_id = $1 AND date = $2',
      [employee_id, dateStr]
    );

    let record;
    if (existing.rows.length > 0) {
      const result = await query(
        `UPDATE attendance
         SET status = $1,
             notes = $2
         WHERE id = $3
         RETURNING *`,
        [mappedStatus, `Calendar Update: ${status}`, existing.rows[0].id]
      );
      record = result.rows[0];
    } else {
      const result = await query(
        `INSERT INTO attendance (organization_id, employee_id, date, status, notes)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [organization_id, employee_id, dateStr, mappedStatus, `Calendar Update: ${status}`]
      );
      record = result.rows[0];
    }

    res.json({ success: true, record });
  } catch (error) {
    console.error('Calendar update error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
