/**
 * QC Ticket System Routes
 */

const express = require('express');
const router = express.Router();
const qcTicketController = require('../controllers/qcTicket.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');

// Protect all QC Ticket Endpoints
router.use(authenticateJWT);

// Get QC Dashboard Live Database Stats
router.get('/dashboard-stats', qcTicketController.getDashboardStats);

// Create Ticket
router.post('/tickets', qcTicketController.createTicket);

// Get My Assigned Tickets & Dashboard Stats
router.get('/tickets/my-tickets', qcTicketController.getMyTickets);

// Update Ticket Status
router.patch('/tickets/:id/status', qcTicketController.updateTicketStatus);

// Record Reviewer Activity Timestamp
router.post('/tickets/reviewer-activity', qcTicketController.recordActivity);

// Manual or Admin Trigger for Auto-Reassignment
router.post('/tickets/auto-reassign', qcTicketController.triggerAutoReassignment);

// Get / Update Admin System Configurations
router.get('/admin/qc-config', qcTicketController.getQCConfigs);
router.put('/admin/qc-config', qcTicketController.updateQCConfigs);

module.exports = router;
