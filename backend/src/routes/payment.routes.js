/**
 * Payment Routes
 * Endpoints under /api/v1/payments
 */

const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');
const {
  validatePaymentVendorIdParam,
  validatePaymentCalculationQuery,
} = require('../validators/payment.validator');

// Protect all payment endpoints with JWT authentication
router.use(authenticateJWT);

// GET /api/v1/payments - Get all recent payout transactions (Admin dashboard)
router.get(
  '/',
  (req, res, next) => paymentController.getAllPayments(req, res, next)
);

// GET /api/v1/payments/export/csv - Download Vendor Settlement CSV Report
router.get(
  '/export/csv',
  (req, res, next) => paymentController.exportPaymentsCSV(req, res, next)
);

// GET /api/v1/payments/export/pdf - Download Vendor Settlement Printable PDF Report
router.get(
  '/export/pdf',
  (req, res, next) => paymentController.exportPaymentsPDF(req, res, next)
);

// GET /api/v1/payments/vendor/:vendorId - Calculate Vendor Payment
router.get(
  '/vendor/:vendorId',
  validatePaymentVendorIdParam,
  validatePaymentCalculationQuery,
  (req, res, next) => paymentController.calculateVendorPayment(req, res, next)
);

module.exports = router;

