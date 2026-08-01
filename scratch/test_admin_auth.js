const path = require('path');
const { Pool } = require(path.join(__dirname, '../backend/node_modules/pg'));
const bcrypt = require(path.join(__dirname, '../backend/node_modules/bcryptjs'));

const DATABASE_URL = 'postgresql://neondb_owner:npg_FBwOPsI5L4fE@ep-young-leaf-axv340na-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function checkAdmins() {
  try {
    console.log('--- Inspecting Admins Table ---');
    const res = await pool.query('SELECT id, username, email, password_hash, is_active FROM admins');
    console.log(`Found ${res.rows.length} admin rows:`);
    for (const r of res.rows) {
      console.log(`ID: ${r.id} | Email: ${r.email} | Username: ${r.username}`);
      if (r.password_hash) {
        const testMatch = await bcrypt.compare('admin123', r.password_hash);
        console.log(`  Password 'admin123' match: ${testMatch}`);
      } else {
        console.log('  No password hash set!');
      }
    }
  } catch (err) {
    console.error('Error checking admins:', err.message);
  } finally {
    await pool.end();
  }
}

checkAdmins();
