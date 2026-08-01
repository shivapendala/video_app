/**
 * Admin Controller
 */

const adminService = require('../services/admin.service');

class AdminController {
  async getDashboardStats(req, res, next) {
    try {
      const stats = await adminService.getAdminDashboardStats();
      return res.status(200).json({
        status: 'success',
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }

  async getQCApprovedQueue(req, res, next) {
    try {
      const queue = await adminService.getQCApprovedQueue();
      return res.status(200).json({
        status: 'success',
        data: queue,
      });
    } catch (error) {
      next(error);
    }
  }

  async approveVideo(req, res, next) {
    try {
      const { videoId } = req.params;
      const { comments } = req.body;
      const result = await adminService.approveVideo(videoId, comments);
      return res.status(200).json({
        status: 'success',
        message: 'Video approved by Admin. Vendor payout credited.',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async rejectVideo(req, res, next) {
    try {
      const { videoId } = req.params;
      const { comments } = req.body;
      const result = await adminService.rejectVideo(videoId, comments);
      return res.status(200).json({
        status: 'success',
        message: 'Video rejected by Admin.',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/admins/videos/dispatch-qc
   * Admin 1-Click Dispatch: Divides pending candidate videos evenly among active QC team members
   */
  async dispatchVideosToQC(req, res, next) {
    try {
      const result = await adminService.dispatchVideosToQC();
      return res.status(200).json({
        status: 'success',
        message: result.message,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async createAdmin(req, res, next) {
    try {
      const { full_name, email, phone, password } = req.body;
      const newAdmin = await adminService.createAdmin({
        full_name,
        email,
        phone,
        password,
      });

      return res.status(201).json({
        status: 'success',
        message: 'Admin created successfully',
        data: newAdmin,
      });
    } catch (error) {
      next(error);
    }
  }

  async getAllAdmins(req, res, next) {
    try {
      const { page, limit } = req.query;
      const result = await adminService.getAllAdmins({ page, limit });

      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async getAdminById(req, res, next) {
    try {
      const { id } = req.params;
      const admin = await adminService.getAdminById(id);

      return res.status(200).json({
        status: 'success',
        data: admin,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateAdmin(req, res, next) {
    try {
      const { id } = req.params;
      const { full_name, phone, email, is_active } = req.body;

      const updatedAdmin = await adminService.updateAdmin(id, {
        full_name,
        phone,
        email,
        is_active,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Admin updated successfully',
        data: updatedAdmin,
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteAdmin(req, res, next) {
    try {
      const { id } = req.params;
      const result = await adminService.deleteAdmin(id);

      return res.status(200).json({
        status: 'success',
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AdminController();
