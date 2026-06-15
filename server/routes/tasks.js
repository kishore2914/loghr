const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getEmployeeId(userId) {
  const result = await query('SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0] || { employee_id: null, organization_id: null };
}

// GET /api/tasks
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      'SELECT * FROM tasks WHERE assigned_to = $1 ORDER BY created_at DESC',
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/tasks/create
router.post('/create', authenticateToken, async (req, res) => {
  const { title, description, assignedTo, dueDate, priority } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    
    const result = await query(
      `INSERT INTO tasks (
        organization_id, title, description, assigned_to, assigned_by,
        due_date, priority, status, progress_percentage
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [
        organization_id, title, description || null, assignedTo || employee_id, employee_id,
        dueDate || null, priority || 'medium', 'pending', 0
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Server error creating task' });
  }
});

// POST /api/tasks/update-status
router.post('/update-status', authenticateToken, async (req, res) => {
  const { taskId, status, progressPercentage } = req.body;
  if (!taskId || !status) {
    return res.status(400).json({ error: 'TaskId and status are required' });
  }

  try {
    const { employee_id } = await getEmployeeId(req.user.userId);

    const updates = ['status = $1'];
    const params = [status, taskId, employee_id];
    let paramIndex = 4;

    if (progressPercentage !== undefined) {
      updates.push(`progress_percentage = $${paramIndex}`);
      params.push(progressPercentage);
      paramIndex++;
    }

    if (status === 'completed') {
      updates.push(`completed_at = NOW()`);
    }

    const result = await query(
      `UPDATE tasks 
       SET ${updates.join(', ')} 
       WHERE id = $2 AND assigned_to = $3
       RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found or not assigned to you' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating task status:', error);
    res.status(500).json({ error: 'Server error updating task status' });
  }
});

module.exports = router;
