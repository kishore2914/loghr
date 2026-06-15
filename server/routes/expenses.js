const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getEmployeeId(userId) {
  const result = await query('SELECT employee_id, organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0] || { employee_id: null, organization_id: null };
}

// GET /api/expenses/categories
router.get('/categories', authenticateToken, async (req, res) => {
  try {
    const { organization_id } = await getEmployeeId(req.user.userId);
    if (!organization_id) return res.json([]);

    const result = await query(
      'SELECT * FROM expense_categories WHERE organization_id = $1 AND is_active = true',
      [organization_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching expense categories:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/expenses
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      `SELECT e.*, ec.name as category_name
       FROM expenses e
       JOIN expense_categories ec ON e.category_id = ec.id
       WHERE e.employee_id = $1
       ORDER BY e.expense_date DESC`,
      [employee_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching expenses:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/expenses/create
router.post('/create', authenticateToken, async (req, res) => {
  const { categoryId, expenseDate, amount, description, merchantName, receiptUrl } = req.body;
  if (!categoryId || !expenseDate || !amount) {
    return res.status(400).json({ error: 'Missing required expense fields' });
  }

  try {
    const { employee_id, organization_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) {
      return res.status(400).json({ error: 'No employee record linked to user' });
    }

    const expNumber = 'EXP-' + Math.floor(100000 + Math.random() * 900000);

    const result = await query(
      `INSERT INTO expenses (
        organization_id, employee_id, expense_number, category_id, expense_date,
        amount, description, merchant_name, receipt_url, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *`,
      [
        organization_id, employee_id, expNumber, categoryId, expenseDate,
        amount, description || null, merchantName || null, receiptUrl || null, 'pending'
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating expense:', error);
    res.status(500).json({ error: 'Server error creating expense' });
  }
});

// DELETE /api/expenses/:id
router.delete('/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    const result = await query(
      "DELETE FROM expenses WHERE id = $1 AND employee_id = $2 AND status = 'pending' RETURNING *",
      [id, employee_id]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not delete expense (may already be approved/rejected)' });
    }

    res.json({ success: true, message: 'Expense deleted successfully' });
  } catch (error) {
    console.error('Error deleting expense:', error);
    res.status(500).json({ error: 'Server error deleting expense' });
  }
});

module.exports = router;
