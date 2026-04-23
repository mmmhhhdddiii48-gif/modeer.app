const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { config } = require('./config/env');
const { authRouter } = require('./modules/auth');
const { managerRouter } = require('./modules/manager');
const { employeeRouter } = require('./modules/employee');
const { notFound } = require('./middleware/notFound');
const { errorHandler } = require('./middleware/errorHandler');

function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '15mb' }));
  app.use(express.urlencoded({ extended: false }));

  app.use(cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (config.cors.origins.includes('*')) return callback(null, true);
      if (config.cors.origins.includes(origin)) return callback(null, true);
      return callback(null, false);
    },
    credentials: true
  }));

  app.get('/', (_req, res) => {
    res.json({ ok: true, data: { service: 'nukhba-api', status: 'running' } });
  });

  app.get('/health', (_req, res) => {
    res.json({ ok: true, data: { status: 'healthy', env: config.env } });
  });

  app.use('/auth', authRouter);

  app.use('/manager', managerRouter);

  app.use('/employee', employeeRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
