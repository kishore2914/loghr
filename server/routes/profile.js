const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// GET /api/profile
router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      `SELECT 
        up.*, 
        e.first_name, 
        e.last_name, 
        e.middle_name, 
        e.employee_code,
        e.date_of_joining,
        e.personal_email,
        e.company_email,
        e.mobile_number,
        e.employment_status,
        e.employment_type,
        e.pan_number,
        e.aadhaar_number,
        e.bank_name,
        e.bank_account_number,
        e.ifsc_code,
        e.bank_branch,
        e.uan_number,
        d.name AS department,
        ds.name AS designation,
        o.name AS organization_name,
        o.logo_url AS organization_logo
      FROM user_profiles up
      LEFT JOIN employees e ON up.employee_id = e.id
      LEFT JOIN departments d ON e.department_id = d.id
      LEFT JOIN designations ds ON e.designation_id = ds.id
      LEFT JOIN organizations o ON up.organization_id = o.id
      WHERE up.user_id = $1`,
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/profile/employee-code/:employeeId
router.get('/employee-code/:employeeId', authenticateToken, async (req, res) => {
  const { employeeId } = req.params;
  try {
    const result = await query(
      'SELECT employee_code FROM employees WHERE id = $1',
      [employeeId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    res.json({ employee_code: result.rows[0].employee_code });
  } catch (error) {
    console.error('Error fetching employee code:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/profile/departments
router.get('/departments', authenticateToken, async (req, res) => {
  try {
    const profile = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [req.user.userId]);
    if (profile.rows.length === 0 || !profile.rows[0].organization_id) {
      return res.json([]);
    }

    const orgId = profile.rows[0].organization_id;
    const result = await query(
      'SELECT * FROM departments WHERE organization_id = $1 AND is_active = true ORDER BY name',
      [orgId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching departments:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/profile/employee-count
router.get('/employee-count', authenticateToken, async (req, res) => {
  try {
    const profile = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [req.user.userId]);
    if (profile.rows.length === 0 || !profile.rows[0].organization_id) {
      return res.json({ count: 0 });
    }

    const orgId = profile.rows[0].organization_id;
    const result = await query(
      'SELECT COUNT(*) FROM user_profiles WHERE organization_id = $1 AND is_active = true',
      [orgId]
    );

    res.json({ count: parseInt(result.rows[0].count) });
  } catch (error) {
    console.error('Error getting employee count:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/profile/department-employee-count
router.get('/department-employee-count', authenticateToken, async (req, res) => {
  const { departmentId } = req.query;
  if (!departmentId) {
    return res.status(400).json({ error: 'Department ID is required' });
  }

  try {
    const result = await query(
      `SELECT COUNT(*) 
       FROM user_profiles up
       JOIN employees e ON up.employee_id = e.id
       WHERE e.department_id = $1 AND up.is_active = true`,
      [departmentId]
    );

    res.json({ count: parseInt(result.rows[0].count) });
  } catch (error) {
    console.error('Error getting department employee count:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/profile/department-employees
router.get('/department-employees', authenticateToken, async (req, res) => {
  const { departmentId } = req.query;
  if (!departmentId) {
    return res.status(400).json({ error: 'Department ID is required' });
  }

  try {
    const result = await query(
      `SELECT 
        up.full_name, 
        e.employee_code, 
        up.user_id,
        up.employee_id
       FROM user_profiles up
       JOIN employees e ON up.employee_id = e.id
       WHERE e.department_id = $1 AND up.is_active = true
       ORDER BY up.full_name`,
      [departmentId]
    );

    const mapped = result.rows.map(row => ({
      full_name: row.full_name,
      employee_id: row.employee_code || 'N/A',
      is_current_user: row.user_id === req.user.userId,
    }));

    res.json(mapped);
  } catch (error) {
    console.error('Error fetching department employees:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/profile/update
router.post('/update', authenticateToken, async (req, res) => {
  const updates = req.body;
  
  try {
    // 1. Get existing profile to retrieve employee_id
    const profileResult = await query(
      'SELECT id, employee_id FROM user_profiles WHERE user_id = $1',
      [req.user.userId]
    );

    if (profileResult.rows.length === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    const { id: profileId, employee_id: employeeId } = profileResult.rows[0];

    // 2. Perform updates to user_profiles table (for fields that exist in user_profiles)
    const profileFields = ['full_name', 'phone', 'avatar_url'];
    const profileUpdates = [];
    const profileParams = [];
    let paramIndex = 1;

    profileFields.forEach(field => {
      if (updates[field] !== undefined) {
        profileUpdates.push(`${field} = $${paramIndex}`);
        profileParams.push(updates[field]);
        paramIndex++;
      }
    });

    if (profileUpdates.length > 0) {
      profileParams.push(req.user.userId);
      await query(
        `UPDATE user_profiles SET ${profileUpdates.join(', ')} WHERE user_id = $${paramIndex}`,
        profileParams
      );
    }

    // 3. Perform updates to employees table (for fields that exist in employees)
    if (employeeId) {
      const employeeFields = [
        'first_name', 'last_name', 'mobile_number', 'aadhaar_number', 'pan_number',
        'bank_name', 'bank_account_number', 'ifsc_code', 'bank_branch', 'uan_number'
      ];
      
      const empUpdates = [];
      const empParams = [];
      let empParamIndex = 1;

      // Map special updates like split full_name into first/last
      if (updates.full_name !== undefined) {
        const parts = updates.full_name.trim().split(' ');
        const firstName = parts[0] || '';
        const lastName = parts.slice(1).join(' ') || '';
        empUpdates.push(`first_name = $${empParamIndex}`);
        empParams.push(firstName);
        empParamIndex++;
        empUpdates.push(`last_name = $${empParamIndex}`);
        empParams.push(lastName);
        empParamIndex++;
      }

      employeeFields.forEach(field => {
        // Handle mapped names from frontend updates
        let val = updates[field];
        if (field === 'mobile_number' && updates.phone !== undefined) {
          val = updates.phone;
        }
        
        if (val !== undefined && field !== 'first_name' && field !== 'last_name') {
          empUpdates.push(`${field} = $${empParamIndex}`);
          empParams.push(val);
          empParamIndex++;
        }
      });

      if (empUpdates.length > 0) {
        empParams.push(employeeId);
        await query(
          `UPDATE employees SET ${empUpdates.join(', ')} WHERE id = $${empParamIndex}`,
          empParams
        );
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: 'Server error updating profile' });
  }
});

// POST /api/profile/upload-avatar
router.post('/upload-avatar', authenticateToken, async (req, res) => {
  // Simple mock/stub for avatar upload (could be configured to save local file)
  const { avatarUrl } = req.body;
  if (!avatarUrl) {
    return res.status(400).json({ error: 'avatarUrl is required' });
  }

  try {
    await query(
      'UPDATE user_profiles SET avatar_url = $1 WHERE user_id = $2',
      [avatarUrl, req.user.userId]
    );
    res.json({ success: true, avatarUrl });
  } catch (error) {
    console.error('Error uploading avatar:', error);
    res.status(500).json({ error: 'Server error uploading avatar' });
  }
});

module.exports = router;
