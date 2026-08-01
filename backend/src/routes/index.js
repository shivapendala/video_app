const express = require('express');
const router = express.Router();
const healthRoutes = require('./health.routes');
const authRoutes = require('./auth.routes');
const otpRoutes = require('./otp.routes');
const adminRoutes = require('./admin.routes');
const vendorRoutes = require('./vendor.routes');
const candidateRoutes = require('./candidate.routes');
const videoRoutes = require('./video.routes');
const qcReviewRoutes = require('./qcReview.routes');
const qcTicketRoutes = require('./qcTicket.routes');
const paymentRoutes = require('./payment.routes');
const notificationRoutes = require('./notification.routes');

// GET / - Unified Portal Gateway
router.get('/', (req, res) => {
  if (req.accepts('html')) {
    return res.status(200).send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Video Platform • Unified Portal Hub</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #090d16;
      --card-bg: rgba(22, 30, 49, 0.7);
      --card-border: rgba(255, 255, 255, 0.08);
      --card-hover-border: rgba(99, 102, 241, 0.5);
      --primary: #6366f1;
      --primary-glow: rgba(99, 102, 241, 0.25);
      --text: #f8fafc;
      --text-muted: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background-color: var(--bg);
      background-image: 
        radial-gradient(at 15% 15%, rgba(99, 102, 241, 0.15) 0px, transparent 50%),
        radial-gradient(at 85% 85%, rgba(168, 85, 247, 0.12) 0px, transparent 50%),
        radial-gradient(at 50% 50%, rgba(16, 185, 129, 0.08) 0px, transparent 50%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 2rem 1rem;
    }
    .container {
      max-width: 1000px;
      width: 100%;
    }
    .header {
      text-align: center;
      margin-bottom: 3rem;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.35rem 0.85rem;
      border-radius: 9999px;
      background: rgba(99, 102, 241, 0.12);
      border: 1px solid rgba(99, 102, 241, 0.3);
      color: #818cf8;
      font-size: 0.825rem;
      font-weight: 600;
      margin-bottom: 1.25rem;
    }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background-color: #10b981;
      box-shadow: 0 0 10px #10b981;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(0.85); }
    }
    h1 {
      font-size: 2.75rem;
      font-weight: 800;
      letter-spacing: -0.02em;
      background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 0.75rem;
    }
    p.subtitle {
      color: var(--text-muted);
      font-size: 1.1rem;
      max-width: 550px;
      margin: 0 auto;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 1.5rem;
    }
    .card {
      position: relative;
      background: var(--card-bg);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 2rem;
      text-decoration: none;
      color: inherit;
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      overflow: hidden;
    }
    .card::before {
      content: '';
      position: absolute;
      inset: 0;
      border-radius: 20px;
      padding: 1px;
      background: linear-gradient(135deg, rgba(255,255,255,0.15), transparent);
      -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
      -webkit-mask-composite: xor;
      mask-composite: exclude;
      pointer-events: none;
    }
    .card:hover {
      transform: translateY(-4px);
      border-color: var(--card-hover-border);
      box-shadow: 0 20px 40px -15px var(--primary-glow);
    }
    .icon-wrapper {
      width: 56px;
      height: 56px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.75rem;
      margin-bottom: 1.25rem;
    }
    .icon-admin { background: rgba(99, 102, 241, 0.15); color: #818cf8; }
    .icon-vendor { background: rgba(236, 72, 153, 0.15); color: #f472b6; }
    .icon-api { background: rgba(16, 185, 129, 0.15); color: #34d399; }
    .icon-mobile { background: rgba(245, 158, 11, 0.15); color: #fbbf24; }

    .card h2 {
      font-size: 1.35rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .arrow {
      transition: transform 0.2s ease;
      opacity: 0.6;
    }
    .card:hover .arrow {
      transform: translateX(4px);
      opacity: 1;
    }
    .card p {
      color: var(--text-muted);
      font-size: 0.925rem;
      line-height: 1.5;
      margin-bottom: 1.5rem;
    }
    .card-footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 0.825rem;
      font-weight: 600;
      color: #94a3b8;
    }
    .port-tag {
      font-family: monospace;
      padding: 0.25rem 0.6rem;
      background: rgba(255,255,255,0.06);
      border-radius: 6px;
      color: #e2e8f0;
    }
    .footer {
      margin-top: 3.5rem;
      text-align: center;
      color: var(--text-muted);
      font-size: 0.85rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">
        <span class="dot"></span> All Local Services Active
      </div>
      <h1>Video Platform Gateway</h1>
      <p class="subtitle">Access all application portals and API services from a single dashboard</p>
    </div>

    <div class="grid">
      <!-- Mobile App Info -->
      <a href="http://localhost:8081" target="_blank" class="card">
        <div>
          <div class="icon-wrapper icon-mobile">📱</div>
          <h2>Flutter Mobile App <span class="arrow">→</span></h2>
          <p>Multi-role Mobile Application for Candidates, Vendors, and Admins running live in web preview mode.</p>
        </div>
        <div class="card-footer">
          <span>Port 8081</span>
          <span class="port-tag">http://localhost:8081</span>
        </div>
      </a>

      <!-- Backend REST API -->
      <a href="http://localhost:5000/api/v1" target="_blank" class="card">
        <div>
          <div class="icon-wrapper icon-api">⚡</div>
          <h2>REST API Explorer <span class="arrow">→</span></h2>
          <p>Express API endpoint directory, authentication services, video upload, and database connection state.</p>
        </div>
        <div class="card-footer">
          <span>Port 5000</span>
          <span class="port-tag">http://localhost:5000/api/v1</span>
        </div>
      </a>
    </div>

    <div class="footer">
      Video Data Collection & Multi-Role Mobile Platform • Development Suite
    </div>
  </div>
</body>
</html>
    `);
  }

  res.status(200).json({
    status: 'success',
    message: 'Video Data Collection Platform Backend Running',
    version: '1.0.0',
    documentation: '/api/v1',
    portals: {
      mobile_app: 'http://localhost:8081',
      api_explorer: 'http://localhost:5000/api/v1'
    }
  });
});

// GET /health
router.use('/health', healthRoutes);

// GET /api/v1 Root Route
router.get('/api/v1', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'Video Platform REST API v1 Service Ready',
    endpoints: {
      health: '/health',
      auth_login: 'POST /api/v1/auth/login',
      auth_refresh: 'POST /api/v1/auth/refresh',
      vendors: 'GET /api/v1/vendors',
      candidates: 'GET /api/v1/candidates',
      videos: 'GET /api/v1/videos',
      qc_reviews: 'POST /api/v1/qc-reviews',
      payments: 'GET /api/v1/payments/vendor/:vendorId',
      notifications: 'GET /api/v1/notifications',
    },
  });
});

// API v1 Routes
router.use('/api/v1/auth', authRoutes);
router.use('/api/v1/auth', otpRoutes);
router.use('/api/v1/admins', adminRoutes);
router.use('/api/v1/vendors', vendorRoutes);
router.use('/api/v1/candidates', candidateRoutes);
router.use('/api/v1/videos', videoRoutes);
router.use('/api/v1/qc-reviews', qcReviewRoutes);
router.use('/api/v1/qc-tickets', qcTicketRoutes);
router.use('/api/v1/payments', paymentRoutes);
router.use('/api/v1/notifications', notificationRoutes);

module.exports = router;
