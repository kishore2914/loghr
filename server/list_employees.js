const { query, pool } = require('./db');

async function listEmployees() {
  try {
    const result = await query(`
      SELECT 
        e.id AS employee_uuid,
        e.employee_code,
        e.first_name,
        e.last_name,
        e.personal_email,
        up.user_id,
        up.role,
        up.is_active
      FROM employees e
      LEFT JOIN user_profiles up ON e.id = up.employee_id
      ORDER BY e.employee_code
    `);
    
    console.log('====================================');
    console.log('         LOGHR EMPLOYEES LIST        ');
    console.log('====================================');
    if (result.rows.length === 0) {
      console.log('No employees found in the database.');
    } else {
      console.log(JSON.stringify(result.rows, null, 2));
    }
  } catch (error) {
    console.error('❌ Error fetching employees:', error.message);
  } finally {
    await pool.end();
  }
}

listEmployees();
