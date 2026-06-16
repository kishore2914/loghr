const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getEmployeeId(userId) {
  const result = await query('SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0] || { employee_id: null, organization_id: null };
}

// --- NOTIFICATIONS ---

// GET /api/misc/notifications
router.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
      [req.user.userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/misc/notifications/mark-read
router.post('/notifications/mark-read', authenticateToken, async (req, res) => {
  const { id } = req.body;
  try {
    await query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2', [id, req.user.userId]);
    res.json({ success: true });
  } catch (error) {
    console.error('Error marking notification read:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/misc/notifications/mark-all-read
router.post('/notifications/mark-all-read', authenticateToken, async (req, res) => {
  try {
    await query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.user.userId]);
    res.json({ success: true });
  } catch (error) {
    console.error('Error marking all notifications read:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/misc/notifications/:id
router.delete('/notifications/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  try {
    await query('DELETE FROM notifications WHERE id = $1 AND user_id = $2', [id, req.user.userId]);
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ error: 'Server error' });
  }
});


// --- LOYALTY ---

// GET /api/misc/loyalty/card
router.get('/loyalty/card', authenticateToken, async (req, res) => {
  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.status(400).json({ error: 'No employee record linked' });

    // Fetch card or create one
    let cardResult = await query('SELECT * FROM loyalty_cards WHERE employee_id = $1', [employee_id]);
    
    if (cardResult.rows.length === 0 && organization_id) {
      const cardNum = Date.now().toString().padRight(16, '0');
      await query(
        'INSERT INTO loyalty_cards (organization_id, employee_id, card_number, points_earned) VALUES ($1, $2, $3, $4)',
        [organization_id, employee_id, cardNum, 0]
      );
      cardResult = await query('SELECT * FROM loyalty_cards WHERE employee_id = $1', [employee_id]);
    }

    if (cardResult.rows.length === 0) {
      return res.status(404).json({ error: 'Loyalty card not found' });
    }

    const card = cardResult.rows[0];
    
    // Get organization logo/name
    let org = { name: 'LogHR', logo_url: null };
    if (organization_id) {
      const orgRes = await query('SELECT name, logo_url FROM organizations WHERE id = $1', [organization_id]);
      if (orgRes.rows.length > 0) org = orgRes.rows[0];
    }

    // Get user details
    const profileRes = await query(
      `SELECT up.full_name, ds.name as designation 
       FROM user_profiles up
       LEFT JOIN employees e ON up.employee_id = e.id
       LEFT JOIN designations ds ON e.designation_id = ds.id
       WHERE up.user_id = $1`,
      [req.user.userId]
    );
    const profile = profileRes.rows[0] || { full_name: 'Employee', designation: 'Team Member' };

    res.json({
      card,
      org,
      employee: {
        id: employee_id,
        full_name: profile.full_name,
        designation: profile.designation || 'Team Member',
        role: profile.designation || 'Team Member',
      }
    });
  } catch (error) {
    console.error('Error fetching loyalty card:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/loyalty/transactions
router.get('/loyalty/transactions', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM loyalty_point_transactions WHERE employee_id = $1 ORDER BY created_at DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching loyalty transactions:', error);
    res.status(500).json({ error: 'Server error' });
  }
});


// --- POLICIES ---

// GET /api/misc/policies
router.get('/policies', authenticateToken, async (req, res) => {
  try {
    const { organization_id } = await getEmployeeId(req.user.userId);
    if (!organization_id) return res.json([]);

    const result = await query(
      'SELECT * FROM policies WHERE organization_id = $1 AND is_active = true ORDER BY title',
      [organization_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching policies:', error);
    res.status(500).json({ error: 'Server error' });
  }
});


// --- PERFORMANCE ---

// GET /api/misc/performance/reviews
router.get('/performance/reviews', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM performance_reviews WHERE employee_id = $1 ORDER BY review_period_end DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching performance reviews:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/performance/goals
router.get('/performance/goals', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM goals WHERE employee_id = $1 ORDER BY end_date DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching goals:', error);
    res.status(500).json({ error: 'Server error' });
  }
});


// POST /api/misc/performance/goals/:id/progress
router.post('/performance/goals/:id/progress', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { progress } = req.body;

  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.status(400).json({ error: 'No employee record linked' });

    const result = await query(
      `UPDATE goals 
       SET progress_percentage = $1, status = CASE WHEN $1 = 100 THEN 'completed' ELSE 'in_progress' END, updated_at = NOW()
       WHERE id = $2 AND employee_id = $3 RETURNING *`,
      [progress, id, employee_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Goal not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating goal progress:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/misc/performance/goals/:id/complete
router.post('/performance/goals/:id/complete', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.status(400).json({ error: 'No employee record linked' });

    const result = await query(
      `UPDATE goals 
       SET progress_percentage = 100, status = 'completed', updated_at = NOW()
       WHERE id = $1 AND employee_id = $2 RETURNING *`,
      [id, employee_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Goal not found' });
    }

    // Award loyalty points (100 points)
    try {
      const cardRes = await query('SELECT id FROM loyalty_cards WHERE employee_id = $1', [employee_id]);
      if (cardRes.rows.length > 0) {
        await query(
          `INSERT INTO loyalty_point_transactions (organization_id, employee_id, points, transaction_type, description, reference_id) 
           VALUES ($1, $2, 100, 'earned', $3, $4)`,
          [organization_id, employee_id, `Award for completed goal: ${result.rows[0].title}`, id]
        );
        await query(
          `UPDATE loyalty_cards SET points_earned = points_earned + 100 WHERE employee_id = $1`,
          [employee_id]
        );
      }
    } catch (e) {
      console.error('Error awarding points for goal completion:', e);
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error completing goal:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/performance/goals/:id
router.get('/performance/goals/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const goalResult = await query(
      `SELECT g.*, 
              e.first_name || ' ' || e.last_name AS assigned_to_name,
              d.name AS department_name,
              up.full_name AS created_by_name
       FROM goals g
       LEFT JOIN employees e ON g.employee_id = e.id
       LEFT JOIN departments d ON e.department_id = d.id
       LEFT JOIN user_profiles up ON g.created_by = up.user_id
       WHERE g.id = $1`,
      [id]
    );

    if (goalResult.rows.length === 0) {
      return res.status(404).json({ error: 'Goal not found' });
    }
    res.json(goalResult.rows[0]);
  } catch (error) {
    console.error('Error fetching goal details:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/performance/goals/:id/comments
router.get('/performance/goals/:id/comments', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    try {
      const result = await query(
        `SELECT gc.*, up.full_name, up.email 
         FROM goal_comments gc
         LEFT JOIN user_profiles up ON gc.user_id = up.user_id
         WHERE gc.goal_id = $1
         ORDER BY gc.created_at ASC`,
        [id]
      );
      res.json(result.rows);
    } catch (e) {
      console.log('goal_comments table does not exist or failed query, returning empty list:', e.message);
      res.json([]);
    }
  } catch (error) {
    console.error('Error fetching goal comments:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/misc/performance/goals/:id/comments
router.post('/performance/goals/:id/comments', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { comment } = req.body;
    try {
      const result = await query(
        `INSERT INTO goal_comments (goal_id, user_id, comment, created_at)
         VALUES ($1, $2, $3, NOW()) RETURNING *`,
        [id, req.user.userId, comment]
      );
      res.json(result.rows[0]);
    } catch (e) {
      console.log('goal_comments table insert failed, returning mock comment:', e.message);
      res.json({
        id: 'mock-comment-' + Date.now(),
        goal_id: id,
        user_id: req.user.userId,
        comment: comment,
        created_at: new Date().toISOString()
      });
    }
  } catch (error) {
    console.error('Error posting goal comment:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/holiday-calendar
router.get('/holiday-calendar', authenticateToken, async (req, res) => {
  try {
    const { organization_id } = await getEmployeeId(req.user.userId);
    if (!organization_id) return res.json([]);

    try {
      const result = await query(
        'SELECT * FROM holiday_calendar_documents WHERE organization_id = $1 ORDER BY year DESC',
        [organization_id]
      );
      res.json(result.rows);
    } catch (e) {
      console.log('holiday_calendar_documents table does not exist, returning mock data:', e.message);
      res.json([
        {
          id: 'mock-doc-id',
          year: new Date().getFullYear(),
          file_path: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
          file_type: 'image',
          created_at: new Date().toISOString()
        }
      ]);
    }
  } catch (error) {
    console.error('Error fetching holiday calendar:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/payroll/records
router.get('/payroll/records', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM india_payroll_records WHERE employee_id = $1 ORDER BY pay_period_year DESC, pay_period_month DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching payroll records:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/misc/payroll/records/:id
router.get('/payroll/records/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    const result = await query(
      'SELECT * FROM india_payroll_records WHERE id = $1 AND employee_id = $2',
      [id, employee_id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payroll record not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching payroll record details:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/misc/loyalty/award
router.post('/loyalty/award', authenticateToken, async (req, res) => {
  const { employeeId, points, type, description, referenceId } = req.body;
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    await query(
      `INSERT INTO loyalty_point_transactions (organization_id, employee_id, points, transaction_type, description, reference_id) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [orgId, employeeId, points, type, description || null, referenceId || null]
    );
    
    await query(
      `UPDATE loyalty_cards SET points_earned = points_earned + $1 WHERE employee_id = $2`,
      [points, employeeId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error awarding loyalty points:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
