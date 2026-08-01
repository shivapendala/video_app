/**
 * Quick Patch Runner — runs individual ALTER statements outside a transaction
 * so each can fail independently without aborting the rest.
 */
const path = require('path');
const { Pool } = require(path.join(__dirname, '../backend/node_modules/pg'));

const DATABASE_URL = 'postgresql://neondb_owner:npg_FBwOPsI5L4fE@ep-young-leaf-axv340na-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const patches = [
  // 1. Drop old videos status constraint and recreate with all operational values
  `ALTER TABLE videos DROP CONSTRAINT IF EXISTS chk_videos_status`,
  `ALTER TABLE videos ADD CONSTRAINT chk_videos_status CHECK (
    status IN (
      'pending','uploaded','under_review',
      'pending_qc','assigned_qc','in_review',
      'qc_approved','qc_rejected',
      'approved','rejected',
      'PENDING_QC','ASSIGNED_QC','IN_REVIEW',
      'QC_APPROVED','QC_REJECTED',
      'APPROVED','REJECTED'
    )
  )`,

  // 2. Add amount column to payments
  `ALTER TABLE payments ADD COLUMN IF NOT EXISTS amount DECIMAL(12,2) DEFAULT 0`,

  // 3. Drop NOT NULL from payments schema columns so simple INSERT works
  `ALTER TABLE payments ALTER COLUMN hourly_rate DROP NOT NULL`,
  `ALTER TABLE payments ALTER COLUMN total_amount DROP NOT NULL`,
  `ALTER TABLE payments ALTER COLUMN approved_seconds DROP NOT NULL`,
  `ALTER TABLE payments ALTER COLUMN approved_hours DROP NOT NULL`,

  // 4. Add score columns to qc_reviews
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS qc_reviewer_id  UUID`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS audio_score     DECIMAL(4,2) DEFAULT 0`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS lighting_score  DECIMAL(4,2) DEFAULT 0`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS framing_score   DECIMAL(4,2) DEFAULT 0`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS env_match_score DECIMAL(4,2) DEFAULT 0`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS qc_comments     TEXT`,
  `ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS admin_comments  TEXT`,

  // 5. Drop old qc_reviews status constraint and recreate
  `ALTER TABLE qc_reviews DROP CONSTRAINT IF EXISTS chk_qc_reviews_status`,
  `ALTER TABLE qc_reviews ADD CONSTRAINT chk_qc_reviews_status CHECK (
    status IN ('approved','rejected','qc_approved','qc_rejected','QC_APPROVED','QC_REJECTED')
  )`,

  // 6. Add password_hash to candidates
  `ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)`,

  // 7. Ensure users table has vendor_id and created_by columns
  `ALTER TABLE users ADD COLUMN IF NOT EXISTS vendor_id   UUID`,
  `ALTER TABLE users ADD COLUMN IF NOT EXISTS created_by  UUID`,

  // 8. Upsert admin account with correct bcrypt hash for admin123
  `INSERT INTO admins (id, email, password_hash, full_name, username, is_active, created_at, updated_at)
   VALUES (
     '00000000-0000-0000-0000-000000000001',
     'admin@gmail.com',
     '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
     'System Administrator',
     'admin',
     TRUE,
     NOW(),
     NOW()
   ) ON CONFLICT (email) DO UPDATE
       SET password_hash = '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
           full_name = 'System Administrator',
           is_active = TRUE,
           updated_at = NOW()`,

  // 9. Ensure refresh_tokens table exists
  `CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_refresh_tokens_token UNIQUE (token)
  )`,

  // 10. Seed default QC configs
  `INSERT INTO admin_qc_configs (key, value, description) VALUES
    ('auto_assignment_enabled',   'true', 'Auto-assign tickets on upload'),
    ('auto_reassignment_enabled', 'true', 'Auto-reassign on reviewer inactivity'),
    ('inactivity_timeout_hours',  '24',   'Hours before reassignment'),
    ('max_tickets_per_reviewer',  '50',   'Max concurrent tickets per reviewer'),
    ('assignment_strategy',       'LEAST_WORKLOAD', 'Distribution algorithm')
   ON CONFLICT (key) DO NOTHING`,
];

async function runPatches() {
  const client = await pool.connect();
  console.log('🔌 Connected to Neon PostgreSQL');
  console.log('🔧 Running individual patches...\n');

  let ok = 0; let skip = 0; let fail = 0;
  for (const sql of patches) {
    const preview = sql.replace(/\n/g, ' ').replace(/\s+/g, ' ').substring(0, 80);
    try {
      await client.query(sql);
      console.log(`  ✅ ${preview}`);
      ok++;
    } catch (err) {
      if (
        err.message.includes('already exists') ||
        err.message.includes('does not exist') ||
        err.code === '42701' || // duplicate column
        err.code === '42710' || // duplicate constraint
        err.code === '23505'    // unique violation
      ) {
        console.log(`  ⏭️  SKIP: ${preview}`);
        skip++;
      } else {
        console.error(`  ❌ FAIL [${err.code}]: ${err.message.substring(0, 100)}`);
        fail++;
      }
    }
  }

  console.log(`\n✅ Done — ${ok} applied, ${skip} skipped, ${fail} failed`);

  // Final verification
  console.log('\n📊 Key table column check:');

  const videosCheck = await client.query(`
    SELECT constraint_name FROM information_schema.table_constraints
    WHERE table_name='videos' AND constraint_name='chk_videos_status'
  `);
  console.log(`  videos.chk_videos_status: ${videosCheck.rowCount > 0 ? '✅ present' : '❌ missing'}`);

  const payColCheck = await client.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_name='payments' AND column_name='amount'
  `);
  console.log(`  payments.amount column:   ${payColCheck.rowCount > 0 ? '✅ present' : '❌ missing'}`);

  const qcColCheck = await client.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_name='qc_reviews' AND column_name='audio_score'
  `);
  console.log(`  qc_reviews.audio_score:   ${qcColCheck.rowCount > 0 ? '✅ present' : '❌ missing'}`);

  const adminCheck = await client.query(`SELECT email FROM admins WHERE email='admin@gmail.com'`);
  console.log(`  admin@gmail.com account:  ${adminCheck.rowCount > 0 ? '✅ present' : '❌ missing'}`);

  client.release();
  await pool.end();
}

runPatches().catch(err => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
