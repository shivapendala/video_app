/**
 * Auth Routes
 * Endpoints under /api/v1/auth
 */

const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { validateLogin, validateRefreshToken } = require('../validators/auth.validator');

// POST /api/v1/auth/login - Login with email and password
router.post('/login', validateLogin, (req, res, next) => authController.login(req, res, next));

// POST /api/v1/auth/signup - Register candidate account with vendor code
router.post('/signup', (req, res, next) => authController.signup(req, res, next));

// POST /api/v1/auth/refresh - Refresh Access Token using Refresh Token
router.post('/refresh', validateRefreshToken, (req, res, next) => authController.refreshToken(req, res, next));

module.exports = router;
