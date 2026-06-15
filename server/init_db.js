const fs = require('fs');
const path = require('path');
const { pool } = require('./db');

async function initDb() {
  try {
    console.log('Reading schema.sql...');
    const schemaPath = path.join(__dirname, 'schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');

    console.log('Initializing database tables...');
    await pool.query(sql);
    console.log('✅ Database initialization completed successfully.');
  } catch (error) {
    console.error('❌ Failed to initialize database:', error);
  } finally {
    await pool.end();
    process.exit();
  }
}

initDb();
