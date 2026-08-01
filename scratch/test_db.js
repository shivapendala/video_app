const path = require('path');
const { Pool } = require(path.join(__dirname, '../backend/node_modules/pg'));

const DATABASE_URL = 'postgresql://neondb_owner:npg_FBwOPsI5L4fE@ep-young-leaf-axv340na-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function testInsert() {
  try {
    console.log('--- Testing Vendor Insert ---');
    const vRes = await pool.query(`
      INSERT INTO vendors (company_name, contact_person, email, phone, vendor_code, is_active, created_at, updated_at)
      VALUES ('Test Vendor Co', 'Tester Person', 'testvendor@example.com', '+919999999999', 'VEN-TEST', true, NOW(), NOW())
      ON CONFLICT (email) DO UPDATE SET updated_at = NOW()
      RETURNING id, company_name
    `);
    const vId = vRes.rows[0].id;
    console.log('✅ Vendor Inserted, ID:', vId);

    console.log('--- Testing Candidate Insert ---');
    const cRes = await pool.query(`
      INSERT INTO candidates (vendor_id, full_name, phone, email, is_active, created_at, updated_at)
      VALUES ($1, 'Test Candidate Person', '+918888888888', 'testcand@example.com', true, NOW(), NOW())
      ON CONFLICT DO NOTHING
      RETURNING id, full_name
    `, [vId]);
    const cId = cRes.rows[0] ? cRes.rows[0].id : (await pool.query('SELECT id FROM candidates WHERE email=$1', ['testcand@example.com'])).rows[0].id;
    console.log('✅ Candidate Inserted, ID:', cId);

    console.log('--- Testing Video Insert ---');
    const vidRes = await pool.query(`
      INSERT INTO videos (candidate_id, vendor_id, title, file_name, local_path, file_size, environment_tag, upload_date, status, duration)
      VALUES ($1, $2, 'Kitchen Video Test', 'kitchen_test.mp4', 'uploads/videos/kitchen_test.mp4', 10485760, 'Kitchen', NOW(), 'PENDING_QC', 15)
      RETURNING id, title, status
    `, [cId, vId]);
    console.log('✅ Video Inserted:', vidRes.rows[0]);

    console.log('\n--- Verification Counts ---');
    const vCount = await pool.query('SELECT COUNT(*) FROM vendors');
    const cCount = await pool.query('SELECT COUNT(*) FROM candidates');
    const vidCount = await pool.query('SELECT COUNT(*) FROM videos');
    console.log(`Vendors Total: ${vCount.rows[0].count}`);
    console.log(`Candidates Total: ${cCount.rows[0].count}`);
    console.log(`Videos Total: ${vidCount.rows[0].count}`);

  } catch(err) {
    console.error('❌ Insert Error:', err.message);
    console.error(err.stack);
  } finally {
    await pool.end();
  }
}

testInsert();
