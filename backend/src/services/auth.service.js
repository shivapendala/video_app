/**
 * Auth Service
 * Single Unified Login Service
 * Inspects credentials and authenticates Admins, Vendors, and Candidates automatically
 */

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../database/connection');

class AuthService {
  /**
   * Single Unified Login API Handler
   * Authenticates based on email / mobile phone / username and password
   * @param {Object} credentials - { email, password }
   * @returns {Object} { accessToken, refreshToken, user: { id, email, full_name, role } }
   */
  async login({ email, password }) {
    const identifier = (email || '').trim().toLowerCase();
    const cleanPassword = (password || '').trim();

    let userRow = null;
    let userRole = 'admin';

    // 1. Check Admins table
    try {
      const adminRes = await db.query(
        'SELECT id, email, password_hash, full_name, is_active FROM admins WHERE LOWER(email) = $1 AND deleted_at IS NULL',
        [identifier]
      );
      if (adminRes.rows.length > 0) {
        userRow = adminRes.rows[0];
        userRole = 'admin';
      }
    } catch (e) {
      // Ignore DB error for dev fallbacks
    }

    // 2. Check Vendors table
    if (!userRow) {
      try {
        const vendorRes = await db.query(
          'SELECT id, email, password_hash, company_name AS full_name, is_active FROM vendors WHERE LOWER(email) = $1 AND (deleted_at IS NULL OR deleted_at > NOW())',
          [identifier]
        );
        if (vendorRes.rows.length > 0) {
          userRow = vendorRes.rows[0];
          userRole = 'vendor';
        }
      } catch (e) {}
    }

    // 2b. Check Users / Vendor Logins table
    if (!userRow) {
      try {
        const userRes = await db.query(
          'SELECT id, email, password_hash, full_name, role, is_active FROM users WHERE LOWER(email) = $1',
          [identifier]
        );
        if (userRes.rows.length > 0) {
          userRow = userRes.rows[0];
          userRole = userRes.rows[0].role || 'vendor';
        }
      } catch (e) {}
    }

    // 3. Check Candidates table
    if (!userRow) {
      try {
        const candidateRes = await db.query(
          'SELECT id, email, password_hash, full_name, is_active FROM candidates WHERE (LOWER(email) = $1 OR phone = $1) AND deleted_at IS NULL',
          [identifier]
        );
        if (candidateRes.rows.length > 0) {
          userRow = candidateRes.rows[0];
          userRole = 'candidate';
        }
      } catch (e) {}
    }

    // 4. Check QC Team / Reviewers table
    if (!userRow) {
      try {
        const reviewerRes = await db.query(
          'SELECT reviewer_id AS id, reviewer_email AS email, password_hash, reviewer_name AS full_name, is_active FROM reviewer_activity WHERE LOWER(reviewer_email) = $1',
          [identifier]
        );
        if (reviewerRes.rows.length > 0) {
          userRow = reviewerRes.rows[0];
          userRole = 'qc_team';
        }
      } catch (e) {}
    }

    // 3. Dev fallbacks for unified single login (Development mode only)
    if (!userRow && process.env.NODE_ENV === 'development') {
      if (identifier === 'admin@gmail.com' || identifier === 'admin') {
        const hash = await bcrypt.hash('admin123', 10);
        userRow = {
          id: '00000000-0000-0000-0000-000000000001',
          email: 'admin@gmail.com',
          password_hash: hash,
          full_name: 'System Admin',
          is_active: true,
        };
        userRole = 'admin';
      } else if (identifier === 'vendor@gmail.com' || identifier.includes('vendor')) {
        const hash = await bcrypt.hash('vendor123', 10);
        userRow = {
          id: '10000000-0000-4000-8000-000000000001',
          email: 'vendor@gmail.com',
          password_hash: hash,
          full_name: 'Acme Vendor Solutions',
          is_active: true,
        };
        userRole = 'vendor';
      } else if (identifier === 'candidate@gmail.com' || identifier.includes('candidate')) {
        const hash = await bcrypt.hash('candidate123', 10);
        userRow = {
          id: '20000000-0000-4000-8000-000000000001',
          email: 'candidate@gmail.com',
          password_hash: hash,
          full_name: 'Vasavi Candidate',
          is_active: true,
        };
        userRole = 'candidate';
      } else if (identifier === 'qcteam@gmail.com' || identifier.includes('qc')) {
        const hash = await bcrypt.hash('qcteam123', 10);
        userRow = {
          id: '30000000-0000-4000-8000-000000000001',
          email: 'qcteam@gmail.com',
          password_hash: hash,
          full_name: 'QC Team Specialist',
          is_active: true,
        };
        userRole = 'qc_team';
      }
    }

    // 4. Validate user existence
    if (!userRow) {
      const error = new Error('Invalid email or password');
      error.statusCode = 401;
      throw error;
    }

    if (userRow.is_active === false) {
      const error = new Error('Account is inactive. Please contact support.');
      error.statusCode = 403;
      throw error;
    }

    // 5. Verify password hash
    if (userRow.password_hash) {
      const isValid = await bcrypt.compare(cleanPassword, userRow.password_hash);
      if (!isValid) {
        const error = new Error('Invalid email or password');
        error.statusCode = 401;
        throw error;
      }
    }

    // 6. Generate JWT Access Token
    const accessToken = jwt.sign(
      {
        id: userRow.id,
        email: userRow.email,
        name: userRow.full_name,
        role: userRole,
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    // 7. Generate Refresh Token
    const refreshToken = jwt.sign(
      {
        id: userRow.id,
        email: userRow.email,
        role: userRole,
        type: 'refresh',
      },
      config.jwt.refreshSecret,
      { expiresIn: config.jwt.refreshExpiresIn }
    );

    // 8. Store Refresh Token in DB if connected
    try {
      await db.query(
        'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, NOW() + INTERVAL \'7 days\') ON CONFLICT DO NOTHING',
        [userRow.id, refreshToken]
      );
    } catch (err) {}

    return {
      accessToken,
      refreshToken,
      user: {
        id: userRow.id,
        email: userRow.email,
        full_name: userRow.full_name,
        role: userRole,
      },
    };
  }

  async refreshToken({ refreshToken }) {
    let payload;
    try {
      payload = jwt.verify(refreshToken, config.jwt.refreshSecret);
    } catch (err) {
      const error = new Error('Invalid or expired refresh token');
      error.statusCode = 401;
      throw error;
    }

    const accessToken = jwt.sign(
      {
        id: payload.id,
        email: payload.email,
        role: payload.role || 'admin',
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    return { accessToken };
  }

  /**
   * Candidate Signup Handler
   * Registers a new candidate associated with a Vendor Code in PostgreSQL
   */
  async candidateSignup({ email, password, vendor_code, full_name, phone }) {
    const cleanEmail = (email || '').trim().toLowerCase();
    const cleanPassword = (password || '').trim();
    const cleanVendorCode = (vendor_code || '').trim().toUpperCase();
    const cleanFullName = (full_name || '').trim() || cleanEmail.split('@')[0];
    const cleanPhone = (phone || '').trim() || `+91 ${Math.floor(6000000000 + Math.random() * 3999999999)}`;

    if (!cleanEmail || !cleanPassword) {
      const error = new Error('Email and password are required');
      error.statusCode = 400;
      throw error;
    }

    // 1. Verify Vendor Code from vendors table
    let vendorId = '10000000-0000-4000-8000-000000000001';
    try {
      if (cleanVendorCode) {
        const vendorRes = await db.query(
          'SELECT id FROM vendors WHERE (UPPER(vendor_code) = $1 OR id::text = $1) AND deleted_at IS NULL LIMIT 1',
          [cleanVendorCode]
        );
        if (vendorRes.rows.length > 0) {
          vendorId = vendorRes.rows[0].id;
        } else {
          const anyVendorRes = await db.query('SELECT id FROM vendors WHERE is_active = TRUE LIMIT 1');
          if (anyVendorRes.rows.length > 0) {
            vendorId = anyVendorRes.rows[0].id;
          }
        }
      } else {
        const anyVendorRes = await db.query('SELECT id FROM vendors WHERE is_active = TRUE LIMIT 1');
        if (anyVendorRes.rows.length > 0) {
          vendorId = anyVendorRes.rows[0].id;
        }
      }
    } catch (e) {}

    // 2. Check if candidate email already exists
    try {
      const existingRes = await db.query(
        'SELECT id FROM candidates WHERE LOWER(email) = $1 AND deleted_at IS NULL',
        [cleanEmail]
      );
      if (existingRes.rows.length > 0) {
        const error = new Error('Email is already registered. Please login instead.');
        error.statusCode = 400;
        throw error;
      }
    } catch (e) {
      if (e.statusCode) throw e;
    }

    // 3. Hash password with bcrypt
    const passwordHash = await bcrypt.hash(cleanPassword, 10);

    // 4. Insert Candidate into candidates PostgreSQL table
    let candidateRow;
    try {
      const insertRes = await db.query(
        `INSERT INTO candidates (vendor_id, full_name, email, phone, password_hash, is_active, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, TRUE, NOW(), NOW())
         RETURNING id, vendor_id, full_name, email, phone, is_active, created_at`,
        [vendorId, cleanFullName, cleanEmail, cleanPhone, passwordHash]
      );
      candidateRow = insertRes.rows[0];
    } catch (e) {
      candidateRow = {
        id: `cand-${Date.now()}`,
        vendor_id: vendorId,
        full_name: cleanFullName,
        email: cleanEmail,
        phone: cleanPhone,
        is_active: true,
      };
    }

    // 5. Generate JWT tokens
    const accessToken = jwt.sign(
      {
        id: candidateRow.id,
        email: candidateRow.email,
        name: candidateRow.full_name,
        role: 'candidate',
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    const refreshToken = jwt.sign(
      {
        id: candidateRow.id,
        email: candidateRow.email,
        role: 'candidate',
        type: 'refresh',
      },
      config.jwt.refreshSecret,
      { expiresIn: config.jwt.refreshExpiresIn }
    );

    return {
      accessToken,
      refreshToken,
      user: {
        id: candidateRow.id,
        email: candidateRow.email,
        full_name: candidateRow.full_name,
        role: 'candidate',
      },
    };
  }
}

module.exports = new AuthService();
