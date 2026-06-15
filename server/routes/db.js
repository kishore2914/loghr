const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.post('/query', authenticateToken, async (req, res) => {
  const { table, method, filters, orderColumn, orderAscending, limit, expectSingle, data } = req.body;

  if (!table) {
    return res.status(400).json({ error: 'Table name is required' });
  }

  try {
    let sql = '';
    const params = [];
    let paramIndex = 1;

    // Helper: add parameter and return placeholder
    const addParam = (val) => {
      params.push(val);
      return `$${paramIndex++}`;
    };

    if (method === 'select') {
      if (table === 'user_profiles') {
        sql = `
          SELECT 
            up.*,
            e.employee_code,
            e.first_name,
            e.last_name,
            e.personal_email,
            e.mobile_number,
            e.date_of_joining,
            d.name AS department,
            ds.name AS designation
          FROM user_profiles up
          LEFT JOIN employees e ON up.employee_id = e.id
          LEFT JOIN departments d ON e.department_id = d.id
          LEFT JOIN designations ds ON e.designation_id = ds.id
        `;
      } else {
        sql = `SELECT * FROM ${table}`;
      }
    } else if (method === 'insert') {
      if (!data) return res.status(400).json({ error: 'Insert data is required' });
      
      const columns = Object.keys(data);
      const placeholders = columns.map(col => addParam(data[col]));
      
      sql = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders.join(', ')}) RETURNING *`;
    } else if (method === 'update') {
      if (!data) return res.status(400).json({ error: 'Update data is required' });
      
      const setClauses = Object.keys(data).map(col => `${col} = ${addParam(data[col])}`);
      sql = `UPDATE ${table} SET ${setClauses.join(', ')}`;
    } else if (method === 'delete') {
      sql = `DELETE FROM ${table}`;
    } else {
      return res.status(400).json({ error: 'Invalid method' });
    }

    // Build WHERE clause for filters
    const whereClauses = [];
    if (filters && filters.length > 0) {
      for (const filter of filters) {
        const { column, operator, value } = filter;
        if (!operator) continue;

        let isNot = false;
        let op = operator;
        if (operator.startsWith('not_')) {
          isNot = true;
          op = operator.substring(4);
        }

        let clause = '';
        if (op === 'eq') {
          clause = `${column} = ${addParam(value)}`;
        } else if (op === 'neq') {
          clause = `${column} != ${addParam(value)}`;
        } else if (op === 'lt') {
          clause = `${column} < ${addParam(value)}`;
        } else if (op === 'gt') {
          clause = `${column} > ${addParam(value)}`;
        } else if (op === 'lte') {
          clause = `${column} <= ${addParam(value)}`;
        } else if (op === 'gte') {
          clause = `${column} >= ${addParam(value)}`;
        } else if (op === 'ilike') {
          clause = `${column} ILIKE ${addParam(value)}`;
        } else if (op === 'is') {
          if (value === null || value === 'null') {
            clause = `${column} IS NULL`;
          } else {
            clause = `${column} IS NOT NULL`;
          }
        } else if (op === 'in') {
          if (Array.isArray(value)) {
            const placeholders = value.map(val => addParam(val));
            clause = `${column} IN (${placeholders.join(', ')})`;
          }
        } else if (op === 'or') {
          // Parse string like: id.eq.5,employee_code.eq.5
          const parts = value.split(',');
          const orSubClauses = [];
          for (const part of parts) {
            const match = part.match(/^([^.]+)\.([^.]+)\.(.+)$/);
            if (match) {
              const [_, orCol, orOp, orVal] = match;
              if (orOp === 'eq') {
                orSubClauses.push(`${orCol} = ${addParam(orVal)}`);
              } else if (orOp === 'neq') {
                orSubClauses.push(`${orCol} != ${addParam(orVal)}`);
              }
            }
          }
          if (orSubClauses.length > 0) {
            clause = `(${orSubClauses.join(' OR ')})`;
          }
        }

        if (clause) {
          if (isNot) {
            whereClauses.push(`NOT (${clause})`);
          } else {
            whereClauses.push(clause);
          }
        }
      }
    }

    if (whereClauses.length > 0) {
      sql += ` WHERE ${whereClauses.join(' AND ')}`;
    }

    // Add Order, Limit to Select and Update/Delete if RETURNING is used
    if (method === 'select' || method === 'update' || method === 'insert') {
      if (orderColumn) {
        sql += ` ORDER BY ${orderColumn} ${orderAscending ? 'ASC' : 'DESC'}`;
      }
      if (limit) {
        sql += ` LIMIT ${limit}`;
      }
    }

    if (method === 'update' || method === 'delete') {
      sql += ' RETURNING *';
    }

    console.log(`Executing SQL: ${sql} with params:`, params);

    const result = await query(sql, params);

    if (expectSingle) {
      if (result.rows.length === 0) {
        return res.json(null);
      }
      return res.json(result.rows[0]);
    }

    res.json(result.rows);
  } catch (error) {
    console.error(`DB Query Error on table ${table}:`, error.message);
    res.status(500).json({ error: error.message });
  }
});

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
