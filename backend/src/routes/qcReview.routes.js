/**
 * QC Review Routes
 * Endpoints under /api/v1/qc-reviews
 */

const express = require('express');
const router = express.Router();
const qcReviewController = require('../controllers/qcReview.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');
const { requireRole } = require('../middleware/role.middleware');
const { validateCreateQCReview } = require('../validators/qcReview.validator');

// GET /api/v1/qc-reviews/export/csv - Export QC Inspection Log CSV
router.get('/export/csv', (req, res, next) => qcReviewController.exportQCReviewsCSV(req, res, next));

// Protect all QC review routes with JWT authentication & require admin or qc_team role
router.use(authenticateJWT, requireRole('admin', 'qc_team', 'qc'));

// POST /api/v1/qc-reviews - Create / Submit QC Review
router.post('/', validateCreateQCReview, (req, res, next) => qcReviewController.createQCReview(req, res, next));

// GET /api/v1/qc-reviews/video/:video_id - Get QC Review for Video
router.get('/video/:video_id', (req, res, next) => qcReviewController.getQCReviewByVideoId(req, res, next));

module.exports = router;
