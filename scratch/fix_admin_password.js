const path = require('path');
const { Pool } = require(path.join(__dirname, '../backend/node_modules/pg'));
const bcrypt = require(path.join(__dirname, '../backend/node_modules/bcryptjs'));

const DATABASE_URL = 'postgresql://neondb_owner:npg_FBwOPsI5L4fE@ep-young-leaf-axv340na-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function fixAdminPassword() {
  try {
    console.log('--- Generating Fresh Bcrypt Hash for "admin123" ---');
    const freshHash = await bcrypt.hash('admin123', 10);
    console.log('Generated Hash:', freshHash);

    console.log('--- Updating admins table ---');
    const updateAdminRes = await pool.query(`
      INSERT INTO admins (id, email, password_hash, full_name, username, is_active, created_at, updated_at)
      VALUES (
        '00000000-0000-0000-0000-000000000001',
        'admin@gmail.com',
        $1,
        'System Administrator',
        'admin',
        TRUE,
        NOW(),
        NOW()
      )
      ON CONFLICT (email) DO UPDATE SET
        password_hash = $1,
        username = 'admin',
        full_name = 'System Administrator',
        is_active = TRUE,
        updated_at = NOW()
      RETURNING id, email
    `, [freshHash]);
    console.log('✅ Admin table updated:', updateAdminRes.rows[0]);

    console.log('--- Updating admin@example.com if exists ---');
    await pool.query(`
      INSERT INTO admins (id, email, password_hash, full_name, username, is_active, created_at, updated_at)
      VALUES (
        '00000000-0000-0000-0000-000000000002',
        'admin@example.com',
        $1,
        'System Administrator',
        'admin_ex',
        TRUE,
        NOW(),
        NOW()
      )
      ON CONFLICT (email) DO UPDATE SET
        password_hash = $1,
        is_active = TRUE,
        updated_at = NOW()
    `, [freshHash]);

    console.log('--- Testing bcrypt compare after fix ---');
    const verifyRes = await pool.query('SELECT email, password_hash FROM admins WHERE LOWER(email) = $1', ['admin@gmail.com']);
    const isMatch = await bcrypt.compare('admin123', verifyRes.rows[0].password_hash);
    console.log(`✅ Verification for admin@gmail.com + admin123: MATCH = ${isMatch}`);

  } catch (err) {
    console.error('❌ Error updating admin password:', err.message);
  } finally {
    await pool.end();
  }
}

fixAdminPassword();
