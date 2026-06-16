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

// GET /api/expenses/pending
router.get('/pending', authenticateToken, async (req, res) => {
  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `SELECT exp.*, ec.name as category_name, up.full_name as employee_name
       FROM expenses exp
       JOIN expense_categories ec ON exp.category_id = ec.id
       JOIN employees e ON exp.employee_id = e.id
       JOIN user_profiles up ON e.id = up.employee_id
       WHERE exp.organization_id = $1 AND exp.status = 'pending'
       ORDER BY exp.expense_date DESC`,
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching pending expenses:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Helper to get organization ID
async function getOrgId(userId) {
  const result = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0]?.organization_id;
}

// POST /api/expenses/:id/approve
router.post('/:id/approve', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `UPDATE expenses 
       SET status = 'approved', approved_by = (SELECT employee_id FROM user_profiles WHERE user_id = $1), approved_at = NOW()
       WHERE id = $2 AND organization_id = $3 AND status = 'pending'
       RETURNING *`,
      [req.user.userId, id, orgId]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not approve expense claim (may not be pending)' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error approving expense:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/expenses/:id/reject
router.post('/:id/reject', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { rejectionReason } = req.body;

  try {
    const orgId = await getOrgId(req.user.userId);
    if (!orgId) return res.status(400).json({ error: 'No organization linked' });

    const result = await query(
      `UPDATE expenses 
       SET status = 'rejected', notes = $1, updated_at = NOW()
       WHERE id = $2 AND organization_id = $3 AND status = 'pending'
       RETURNING *`,
      [rejectionReason ? `REJECTED: ${rejectionReason}` : 'REJECTED', id, orgId]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Could not reject expense claim (may not be pending)' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error rejecting expense:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/expenses/charges
router.get('/charges', authenticateToken, async (req, res) => {
  try {
    const { employee_id } = await getEmployeeId(req.user.userId);
    if (!employee_id) return res.json([]);

    const result = await query(
      `SELECT * FROM employee_charges 
       WHERE employee_id = $1 
       ORDER BY created_at DESC`,
      [employee_id]
    );

    // Map charges to fit the ExpenseClaim structure on the frontend
    const mapped = result.rows.map(row => ({
      id: row.id,
      employee_id: row.employee_id,
      amount: parseFloat(row.amount || 0.0),
      description: row.reason || 'Charge',
      merchant_name: 'Corporate Card',
      expense_date: row.created_at,
      status: 'approved',
      category_name: 'Card Charge',
    }));

    res.json(mapped);
  } catch (error) {
    console.error('Error fetching employee charges:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
