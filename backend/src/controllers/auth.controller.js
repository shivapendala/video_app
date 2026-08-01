/**
 * Auth Controller
 * Express request handlers for Login and Refresh Token API endpoints
 */

const authService = require('../services/auth.service');

class AuthController {
  /**
   * POST /api/v1/auth/login
   */
  async login(req, res, next) {
    try {
      const { email, password } = req.body;
      const result = await authService.login({ email, password });

      return res.status(200).json({
        status: 'success',
        message: 'Authentication successful',
        data: result,
      });
    } catch (error) {
      if (error.statusCode) {
        return res.status(error.statusCode).json({
          status: 'error',
          message: error.message,
        });
      }
      next(error);
    }
  }

  /**
   * POST /api/v1/auth/refresh
   */
  async refreshToken(req, res, next) {
    try {
      const { refreshToken } = req.body;
      const result = await authService.refreshToken({ refreshToken });

      return res.status(200).json({
        status: 'success',
        message: 'Access token refreshed successfully',
        data: result,
      });
    } catch (error) {
      if (error.statusCode) {
        return res.status(error.statusCode).json({
          status: 'error',
          message: error.message,
        });
      }
      next(error);
    }
  }

  /**
   * POST /api/v1/auth/signup
   */
  async signup(req, res, next) {
    try {
      const { email, password, vendor_code, full_name, phone } = req.body;
      const result = await authService.candidateSignup({ email, password, vendor_code, full_name, phone });

      return res.status(201).json({
        status: 'success',
        message: 'Candidate account created successfully in database',
        data: result,
      });
    } catch (error) {
      if (error.statusCode) {
        return res.status(error.statusCode).json({
          status: 'error',
          message: error.message,
        });
      }
      next(error);
    }
  }
}

module.exports = new AuthController();
