/**
 * PostgreSQL Database Connection
 */

const { Pool } = require('pg');
const config = require('../config');
const logger = require('../utils/logger');

const useSSL = process.env.DB_SSL === 'true';

const poolConfig = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
      max: 30,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
      ssl: useSSL ? { rejectUnauthorized: false } : false,
    }
  : {
      host: process.env.DB_HOST || 'postgres',
      port: parseInt(process.env.DB_PORT, 10) || 5432,
      database: process.env.DB_NAME || 'videoplatform',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgrespassword',
      max: 30,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
      ssl: useSSL ? { rejectUnauthorized: false } : false,
    };

const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  logger.error('Unexpected database pool error', { message: err.message });
});

async function connectDB() {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    logger.info(`✓ Database Connected (${config.database.host}:${config.database.port}/${config.database.name})`);
    return true;
  } catch (error) {
    logger.warn('⚠ Local PostgreSQL not connected. Operating in API mode with fallback handling.', {
      error: error.message,
    });
    return false;
  }
}

function getPool() {
  return pool;
}

async function query(text, params) {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    logger.debug('Executed query', { text, duration: `${duration}ms`, rows: result.rowCount });
    return result;
  } catch (err) {
    logger.warn(`Database Query Warning: ${err.message}`);
    throw err;
  }
}

async function checkConnection() {
  try {
    await pool.query('SELECT 1');
    return true;
  } catch (error) {
    return false;
  }
}

async function closeDB() {
  try {
    await pool.end();
    logger.info('Database pool closed');
  } catch (error) {
    logger.error('Error closing database pool', { error: error.message });
  }
}

module.exports = {
  connectDB,
  getPool,
  query,
  checkConnection,
  closeDB,
};
