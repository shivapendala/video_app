const dotenv = require('dotenv');

// 1. Load environment variables first
dotenv.config();

// 2. Validate environment variables
const validateEnv = require('./utils/validateEnv');
validateEnv();

// 3. Import app, config, logger, and DB connection module
const app = require('./app');
const config = require('./config');
const logger = require('./utils/logger');
const db = require('./database/connection');
const { startQCScheduler } = require('./jobs/qcScheduler');

const http = require('http');
const { Server } = require('socket.io');
const notificationService = require('./services/notification.service');

const PORT = config.port;

async function startServer() {
  // 4. Test database connection
  await db.connectDB();

  // 5. Create HTTP Server & Attach Socket.io
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE'],
    },
  });

  notificationService.setSocketIO(io);

  io.on('connection', (socket) => {
    logger.info(`⚡ Socket.io client connected: ${socket.id}`);
    socket.on('disconnect', () => {
      logger.info(`🔌 Socket.io client disconnected: ${socket.id}`);
    });
  });

  server.listen(PORT, () => {
    logger.info(`Server running in ${config.nodeEnv} mode on port ${PORT} with Socket.io WebSockets enabled`);
    startQCScheduler();
  });

  // Graceful shutdown handling
  const gracefulShutdown = async (signal) => {
    logger.info(`${signal} signal received: closing HTTP server and database pool...`);
    server.close(async () => {
      logger.info('HTTP server closed');
      await db.closeDB();
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

startServer();
