/**
 * JWT Authentication Middleware
 * Protects private API endpoints by verifying the JWT Access Token in Authorization header.
 * Falls back gracefully in development mode without blocking dashboard data requests.
 */

const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Middleware to authenticate requests using JWT Access Tokens.
 * On valid JWT: sets req.user = decoded payload { id, email, role, name }
 * On missing/mock/expired token in dev: falls back to a neutral default session
 */
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;

  if (!authHeader || typeof authHeader !== 'string') {
    return res.status(401).json({
      status: 'error',
      message: 'Access denied. Authorization token required.',
    });
  }

  const parts = authHeader.trim().split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer' || !parts[1]) {
    return res.status(401).json({
      status: 'error',
      message: 'Access denied. Malformed Bearer token format.',
    });
  }

  const token = parts[1];
  if (!token || token === 'undefined' || token === 'null') {
    return res.status(401).json({
      status: 'error',
      message: 'Access denied. Invalid session token.',
    });
  }

  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = {
      id:    decoded.id    || decoded.sub || null,
      email: decoded.email || null,
      name:  decoded.name  || null,
      role:  decoded.role  || 'candidate',
    };
    return next();
  } catch (error) {
    return res.status(401).json({
      status: 'error',
      message: 'Authentication token expired or invalid. Please login again.',
    });
  }
};

const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;

  if (!authHeader || typeof authHeader !== 'string') {
    req.user = { id: null, role: 'guest', email: null };
    return next();
  }

  const parts = authHeader.trim().split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer' || !parts[1]) {
    req.user = { id: null, role: 'guest', email: null };
    return next();
  }

  try {
    const decoded = jwt.verify(parts[1], config.jwt.secret);
    req.user = {
      id:    decoded.id    || decoded.sub || null,
      email: decoded.email || null,
      name:  decoded.name  || null,
      role:  decoded.role  || 'candidate',
    };
  } catch (_) {
    req.user = { id: null, role: 'guest', email: null };
  }
  return next();
};

module.exports = {
  authenticateJWT,
  optionalAuth,
};
