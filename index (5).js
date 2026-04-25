const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const { loginAgent, getCurrentAgentContext } = require('./auth.service');
const { requireAuth } = require('./auth.middleware');

const authRouter = express.Router();

authRouter.post('/login', asyncHandler((req, res) => {
  const data = loginAgent(req.body);
  res.status(200).json({ ok: true, data });
}));

authRouter.get('/me', requireAuth, (req, res) => {
  const data = getCurrentAgentContext(req.auth.sub);
  res.status(200).json({ ok: true, data });
});

module.exports = { authRouter };
