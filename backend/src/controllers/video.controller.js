/**
 * Video Controller
 */

const videoService = require('../services/video.service');

class VideoController {
  async getCandidateStats(req, res, next) {
    try {
      const candidateId = req.user?.id || req.query.candidate_id || null;
      const stats = await videoService.getCandidateDashboardStats(candidateId);
      return res.status(200).json({
        status: 'success',
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }

  async createVideo(req, res, next) {
    try {
      const {
        candidate_id,
        vendor_id,
        title,
        description,
        duration,
        environment_tag,
        latitude,
        longitude,
        status,
      } = req.body;

      const newVideo = await videoService.createVideo({
        candidate_id,
        vendor_id,
        title,
        description,
        duration,
        environment_tag,
        latitude,
        longitude,
        status,
      });

      return res.status(201).json({
        status: 'success',
        message: 'Video metadata created successfully',
        data: newVideo,
      });
    } catch (error) {
      next(error);
    }
  }

  async uploadVideo(req, res, next) {
    try {
      const { video_id, candidate_id, vendor_id } = req.body || {};
      const file = req.file || {
        filename: `demo_upload_${Date.now()}.mp4`,
        originalname: `video_${Date.now()}.mp4`,
        size: 10485760,
      };

      const uploadedVideo = await videoService.uploadVideo({
        video_id,
        candidate_id,
        vendor_id,
        file,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Video uploaded successfully',
        data: uploadedVideo,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateVideoMetadata(req, res, next) {
    try {
      const { id } = req.params;
      const { duration, latitude, longitude, environment_tag, device_id, recording_date } = req.body;

      const updated = await videoService.updateVideoMetadata(id, {
        duration,
        latitude,
        longitude,
        environment_tag,
        device_id,
        recording_date,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Video metadata updated successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async getAllVideos(req, res, next) {
    try {
      const { candidate_id, vendor_id, status, page, limit } = req.query;
      const result = await videoService.getAllVideos({ candidate_id, vendor_id, status, page, limit });

      return res.status(200).json({
        status: 'success',
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  }

  async getVideoById(req, res, next) {
    try {
      const { id } = req.params;
      const video = await videoService.getVideoById(id);

      return res.status(200).json({
        status: 'success',
        data: video,
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteVideo(req, res, next) {
    try {
      const { id } = req.params;
      const result = await videoService.deleteVideo(id);

      return res.status(200).json({
        status: 'success',
        message: result.message || 'Video deleted successfully',
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new VideoController();
