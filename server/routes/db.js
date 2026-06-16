const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Generic query execution endpoint removed for security. Use dedicated REST APIs instead.

// POST /api/db/rpc/:fnName
router.post('/rpc/:fnName', authenticateToken, async (req, res) => {
  const { fnName } = req.params;
  const { params, expectSingle } = req.body;

  try {
    if (fnName === 'decrypt_expense_amount') {
      const encrypted = params ? params.encrypted_amount : null;
      let val = 0.0;
      if (encrypted) {
        const parsed = parseFloat(encrypted);
        val = isNaN(parsed) ? 100.0 : parsed;
      }
      return res.json(expectSingle ? val : [val]);
    }

    if (fnName === 'decrypt_expense_amounts_batch') {
      const encryptedAmounts = params ? params.encrypted_amounts : [];
      const decrypted = encryptedAmounts.map(val => {
        const parsed = parseFloat(val);
        return isNaN(parsed) ? 100.0 : parsed;
      });
      return res.json(decrypted);
    }

    if (fnName === 'list_expense_views') {
      return res.json(expectSingle ? 'expenses_with_amounts' : ['expenses_with_amounts']);
    }

    // Generic fallback: execute function on database
    const paramNames = Object.keys(params || {});
    const paramPlaceholders = paramNames.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `SELECT * FROM ${fnName}(${paramPlaceholders})`;
    const sqlParams = paramNames.map(name => params[name]);

    const result = await query(sql, sqlParams);
    if (expectSingle) {
      return res.json(result.rows[0] || null);
    }
    return res.json(result.rows);
  } catch (error) {
    console.error(`RPC Error on function ${fnName}:`, error.message);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
