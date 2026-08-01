require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const bcrypt = require('bcryptjs');
const db = require('./connection');

async function seedNeonDatabase() {
  console.log('🌱 Starting Clean PostgreSQL Database Seeding...');

  try {
    const adminPasswordHash = await bcrypt.hash('admin123', 10);
    const vendorPasswordHash = await bcrypt.hash('vendor123', 10);
    const candidatePasswordHash = await bcrypt.hash('candidate123', 10);
    const qcPasswordHash = await bcrypt.hash('qcteam123', 10);

    // Ensure password_hash column exists on all tables
    await db.query('ALTER TABLE vendors ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});

    await db.query(`
      CREATE TABLE IF NOT EXISTS reviewer_activity (
        reviewer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        reviewer_name VARCHAR(200) NOT NULL,
        reviewer_email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255),
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        is_available BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `).catch(() => {});

    await db.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(200) NOT NULL,
        role VARCHAR(50) NOT NULL DEFAULT 'vendor',
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `).catch(() => {});

    // Clean old dummy credentials
    console.log('🧹 Cleaning old dummy accounts from database...');
    await db.query(`DELETE FROM users WHERE email NOT IN ('admin@gmail.com', 'vendor@gmail.com', 'candidate@gmail.com', 'qcteam@gmail.com');`).catch(() => {});
    await db.query(`DELETE FROM admins WHERE email NOT IN ('admin@gmail.com');`).catch(() => {});
    await db.query(`DELETE FROM vendors WHERE email NOT IN ('vendor@gmail.com');`).catch(() => {});
    await db.query(`DELETE FROM candidates WHERE email NOT IN ('candidate@gmail.com');`).catch(() => {});
    await db.query(`DELETE FROM reviewer_activity WHERE reviewer_email NOT IN ('qcteam@gmail.com');`).catch(() => {});

    // 1. Seed Admins Table (admin@gmail.com / admin123)
    console.log('1. Seeding Admin (admin@gmail.com / admin123)...');
    await db.query(`
      INSERT INTO admins (id, username, email, password_hash, full_name, is_active)
      VALUES ('00000000-0000-0000-0000-000000000001', 'admin', 'admin@gmail.com', $1, 'System Admin', TRUE)
      ON CONFLICT (email) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [adminPasswordHash]);

    // 2. Seed Vendors Table (vendor@gmail.com / vendor123)
    console.log('2. Seeding Vendor (vendor@gmail.com / vendor123)...');
    await db.query(`
      INSERT INTO vendors (id, vendor_code, company_name, contact_person, email, phone, address, password_hash, is_active)
      VALUES ('10000000-0000-4000-8000-000000000001', 'VEN-001', 'Acme Vendor Solutions', 'Vendor Operations', 'vendor@gmail.com', '+91 98765 00001', 'Bangalore, India', $1, TRUE)
      ON CONFLICT (email) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [vendorPasswordHash]);

    await db.query(`
      INSERT INTO users (id, email, password_hash, full_name, role, is_active)
      VALUES ('10000000-0000-4000-8000-000000000001', 'vendor@gmail.com', $1, 'Acme Vendor Solutions', 'vendor', TRUE)
      ON CONFLICT (email) DO UPDATE
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [vendorPasswordHash]);

    // 3. Seed Candidates Table (candidate@gmail.com / candidate123)
    console.log('3. Seeding Candidate (candidate@gmail.com / candidate123)...');
    await db.query(`DELETE FROM candidates WHERE email = 'candidate@gmail.com';`).catch(() => {});
    await db.query(`
      INSERT INTO candidates (id, vendor_id, full_name, email, phone, password_hash, is_active)
      VALUES ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Vasavi Candidate', 'candidate@gmail.com', '+91 98765 43210', $1, TRUE)
      ON CONFLICT (id) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [candidatePasswordHash]);

    // 4. Seed QC Team Table (qcteam@gmail.com / qcteam123)
    console.log('4. Seeding QC Team (qcteam@gmail.com / qcteam123)...');
    await db.query(`
      INSERT INTO reviewer_activity (reviewer_id, reviewer_name, reviewer_email, password_hash, is_active, is_available)
      VALUES ('30000000-0000-4000-8000-000000000001', 'QC Team Specialist', 'qcteam@gmail.com', $1, TRUE, TRUE)
      ON CONFLICT (reviewer_id) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [qcPasswordHash]);

    console.log('🎉 Clean Database Credentials Seeding Completed Successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding Error:', err.message || err);
    process.exit(1);
  }
}

seedNeonDatabase();
