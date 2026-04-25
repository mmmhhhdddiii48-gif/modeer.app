const express = require('express');
const { requireAuth } = require('../auth/auth.middleware');
const { asyncHandler } = require('../../utils/asyncHandler');
const {
  getEmployeeBootstrap,
  getManagerProfile,
  listNotificationsForUser,
  markNotificationRead,
  listMessagesForUser,
  createMessageForAgent,
  markMessagesReadForAgent,
  createDailyEntryForUser,
  listDailyEntriesForUser,
  createLocationForUser,
  listEmployeeLocations,
  getEmployeeSync
} = require('../core/core.service');
const { getCurrentAgentContext } = require('../auth/auth.service');

const employeeRouter = express.Router();
employeeRouter.use(requireAuth);

employeeRouter.get('/bootstrap', asyncHandler((req, res) => {
  res.json({ ok: true, data: getEmployeeBootstrap(Number(req.auth.sub)) });
}));

employeeRouter.get('/manager-profile', asyncHandler((_req, res) => {
  res.json({ ok: true, data: getManagerProfile() });
}));

employeeRouter.get('/notifications', asyncHandler((req, res) => {
  const data = listNotificationsForUser(Number(req.auth.sub), { unread: req.query.unread === '1' });
  res.json({ ok: true, data });
}));

employeeRouter.patch('/notifications/:id/read', asyncHandler((req, res) => {
  const data = markNotificationRead(Number(req.auth.sub), req.params.id);
  res.json({ ok: true, data });
}));

employeeRouter.get('/messages', asyncHandler((req, res) => {
  const data = listMessagesForUser(Number(req.auth.sub));
  const agentId = data.agent.id;
  markMessagesReadForAgent(agentId, 'agent');
  res.json({ ok: true, data: data.messages });
}));

employeeRouter.post('/messages', asyncHandler((req, res) => {
  const context = getCurrentAgentContext(Number(req.auth.sub));
  const data = createMessageForAgent(context.agent.id, req.body, 'agent', context.agent.full_name);
  res.status(201).json({ ok: true, data });
}));

employeeRouter.get('/daily-entries', asyncHandler((req, res) => {
  const data = listDailyEntriesForUser(Number(req.auth.sub), { date: req.query.date });
  res.json({ ok: true, data: data.entries });
}));

employeeRouter.post('/daily-entries', asyncHandler((req, res) => {
  const data = createDailyEntryForUser(Number(req.auth.sub), req.body, 'agent');
  res.status(201).json({ ok: true, data });
}));


employeeRouter.post('/location', asyncHandler((req, res) => {
  const data = createLocationForUser(Number(req.auth.sub), req.body || {});
  res.status(201).json({ ok: true, data });
}));

employeeRouter.post('/locations', asyncHandler((req, res) => {
  const data = createLocationForUser(Number(req.auth.sub), req.body || {});
  res.status(201).json({ ok: true, data });
}));

employeeRouter.get('/locations', asyncHandler((req, res) => {
  const data = listEmployeeLocations(Number(req.auth.sub), req.query || {});
  res.json({ ok: true, data });
}));

employeeRouter.get('/sync', asyncHandler((req, res) => {
  const data = getEmployeeSync(Number(req.auth.sub));
  res.json({ ok: true, data });
}));

module.exports = { employeeRouter };
