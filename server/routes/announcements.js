const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

async function getOrganizationId(userId) {
  const result = await query('SELECT organization_id FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0]?.organization_id;
}

// GET /api/announcements
router.get('/', authenticateToken, async (req, res) => {
  try {
    const organizationId = await getOrganizationId(req.user.userId);
    if (!organizationId) return res.json([]);

    const result = await query(
      `SELECT * FROM announcements 
       WHERE organization_id = $1 
         AND status = 'published' 
         AND (expires_at IS NULL OR expires_at > NOW())
       ORDER BY is_pinned DESC, publish_at DESC`,
      [organizationId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching announcements:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
