const { createApp } = require('./app');
const { config } = require('./config/env');
const { connectDatabase, closeDatabase } = require('./db');
const logger = require('./utils/logger');

function startServer() {
  connectDatabase();
  const app = createApp();

  const server = app.listen(config.server.port, config.server.host, () => {
    logger.info('Nukhba API server running', {
      host: config.server.host,
      port: config.server.port,
      env: config.env
    });
  });

  function shutdown(signal) {
    logger.warn(`Received ${signal}. Shutting down...`);
    server.close(() => {
      closeDatabase();
      process.exit(0);
    });
  }

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  return server;
}

if (require.main === module) {
  startServer();
}

module.exports = { startServer };
