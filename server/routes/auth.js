const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../db');
const { authenticateToken, JWT_SECRET } = require('../middleware/auth');

const router = express.Router();

// Helper to resolve employee name from database
async function resolveEmployeeName(employeeId) {
  try {
    const result = await query(
      'SELECT id, first_name, last_name, display_name, full_name FROM employees WHERE id = $1',
      [employeeId]
    );
    if (result.rows.length > 0) {
      const emp = result.rows[0];
      const firstName = emp.first_name || '';
      const lastName = emp.last_name || '';
      return `${firstName} ${lastName}`.trim() || emp.full_name || emp.display_name;
    }
  } catch (err) {
    console.error('Error resolving employee name:', err);
  }
  return null;
}

// POST /signup
router.post('/signup', async (req, res) => {
  const { email, password, fullName } = req.body;
  if (!email || !password || !fullName) {
    return res.status(400).json({ error: 'Email, password, and full name are required' });
  }

  try {
    // Check if user already exists
    const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'User with this email already exists' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create a default organization if none exists to ensure foreign keys work
    let orgId;
    const orgResult = await query('SELECT id FROM organizations LIMIT 1');
    if (orgResult.rows.length > 0) {
      orgId = orgResult.rows[0].id;
    } else {
      const newOrg = await query(
        'INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id',
        ['Default Org', 'default-org']
      );
      orgId = newOrg.rows[0].id;
    }

    // Insert user
    const userResult = await query(
      'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) RETURNING id, email, role, created_at',
      [email, passwordHash, 'employee']
    );
    const userId = userResult.rows[0].id;

    // Create an employee record
    const empCode = 'EMP-' + Math.floor(1000 + Math.random() * 9000);
    const empResult = await query(
      `INSERT INTO employees (organization_id, employee_code, first_name, last_name, company_email, is_active)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [orgId, empCode, fullName.split(' ')[0] || fullName, fullName.split(' ').slice(1).join(' ') || '', email, true]
    );
    const employeeId = empResult.rows[0].id;

    // Create user profile
    const profileResult = await query(
      `INSERT INTO user_profiles (user_id, organization_id, employee_id, full_name, email, role, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [userId, orgId, employeeId, fullName, email, 'employee', true]
    );

    const profile = profileResult.rows[0];

    // Generate JWT token
    const token = jwt.sign({ userId, email, role: 'employee' }, JWT_SECRET, { expiresIn: '7d' });

    res.status(201).json({
      token,
      user: {
        user_id: userId,
        email: email,
        employee_id: employeeId,
        full_name: fullName,
        role: 'employee',
        is_active: true,
        created_at: profile.created_at,
      },
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Server error during sign up' });
  }
});

// POST /login & POST /signin
const loginHandler = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // Fetch user
    const userResult = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userResult.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }
    const user = userResult.rows[0];

    // Check password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    // Get user profile
    let profileResult = await query('SELECT * FROM user_profiles WHERE user_id = $1', [user.id]);
    let profile;

    if (profileResult.rows.length === 0) {
      // Auto-create profile if missing
      const orgResult = await query('SELECT id FROM organizations LIMIT 1');
      const orgId = orgResult.rows.length > 0 ? orgResult.rows[0].id : null;

      const newProfile = await query(
        `INSERT INTO user_profiles (user_id, organization_id, full_name, email, role, is_active)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [user.id, orgId, email.split('@')[0], email, user.role, true]
      );
      profile = newProfile.rows[0];
    } else {
      profile = profileResult.rows[0];
    }

    // Update last login
    await query('UPDATE user_profiles SET last_login_at = NOW() WHERE user_id = $1', [user.id]);

    // Resolve employee name if exists
    if (profile.employee_id) {
      const resolvedName = await resolveEmployeeName(profile.employee_id);
      if (resolvedName) {
        profile.full_name = resolvedName;
      }
    }

    // Generate JWT token
    const token = jwt.sign({ userId: user.id, email: user.email, role: profile.role }, JWT_SECRET, { expiresIn: '7d' });

    res.json({
      token,
      user: {
        user_id: user.id,
        email: user.email,
        employee_id: profile.employee_id,
        full_name: profile.full_name,
        role: profile.role,
        is_active: profile.is_active,
        created_at: profile.created_at,
        avatar_url: profile.avatar_url,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Server error during login' });
  }
};

router.post('/login', loginHandler);
router.post('/signin', loginHandler);

// GET /me (load user from token session)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const profileResult = await query('SELECT * FROM user_profiles WHERE user_id = $1', [req.user.userId]);
    if (profileResult.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found' });
    }
    const profile = profileResult.rows[0];

    // Resolve employee name if exists
    if (profile.employee_id) {
      const resolvedName = await resolveEmployeeName(profile.employee_id);
      if (resolvedName) {
        profile.full_name = resolvedName;
      }
    }

    res.json({
      user_id: req.user.userId,
      email: req.user.email,
      employee_id: profile.employee_id,
      full_name: profile.full_name,
      role: profile.role,
      is_active: profile.is_active,
      created_at: profile.created_at,
      avatar_url: profile.avatar_url,
    });
  } catch (error) {
    console.error('Fetch me error:', error);
    res.status(500).json({ error: 'Server error loading session' });
  }
});

// POST /change-password
router.post('/change-password', authenticateToken, async (req, res) => {
  const { newPassword } = req.body;
  if (!newPassword) {
    return res.status(400).json({ error: 'New password is required' });
  }

  try {
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, req.user.userId]);
    res.json({ success: true });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Server error changing password' });
  }
});

module.exports = router;

