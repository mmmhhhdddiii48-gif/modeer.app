const logger = require('../utils/logger');

function errorHandler(err, req, res, next) {
  logger.error('Unhandled request error', {
    message: err.message,
    path: req.originalUrl
  });

  res.status(err.statusCode || 500).json({
    ok: false,
    error: {
      code: err.code || 'INTERNAL_SERVER_ERROR',
      message: err.publicMessage || 'Internal server error'
    }
  });
}

module.exports = { errorHandler };
