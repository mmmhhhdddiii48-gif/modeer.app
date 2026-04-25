const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const {
  listManagerAgents,
  createManagerAgent,
  updateManagerAgent,
  updateManagerAgentAccess
} = require('./manager.service');
const {
  getManagerProfile,
  updateManagerProfile,
  createNotificationForAgent,
  listManagerNotifications,
  createMessageForAgent,
  listMessagesForAgent,
  markMessagesReadForAgent,
  listManagerDailyEntries,
  listManagerLocations,
  closeDay,
  listDayClosures,
  getManagerSync
} = require('../core/core.service');

const managerRouter = express.Router();

managerRouter.get('/agents', asyncHandler((_req, res) => {
  const data = listManagerAgents();
  res.status(200).json({ ok: true, data });
}));

managerRouter.post('/agents', asyncHandler((req, res) => {
  const data = createManagerAgent(req.body);
  res.status(201).json({ ok: true, data });
}));

managerRouter.put('/agents/:id', asyncHandler((req, res) => {
  const data = updateManagerAgent(req.params.id, req.body);
  res.status(200).json({ ok: true, data });
}));

managerRouter.patch('/agents/:id/access', asyncHandler((req, res) => {
  const data = updateManagerAgentAccess(req.params.id, req.body);
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/profile', asyncHandler((_req, res) => {
  res.status(200).json({ ok: true, data: getManagerProfile() });
}));

managerRouter.put('/profile', asyncHandler((req, res) => {
  const data = updateManagerProfile(req.body);
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/notifications', asyncHandler((_req, res) => {
  const data = listManagerNotifications();
  res.status(200).json({ ok: true, data });
}));

managerRouter.post('/notifications', asyncHandler((req, res) => {
  const data = createNotificationForAgent(req.body.agent_id, req.body);
  res.status(201).json({ ok: true, data });
}));

managerRouter.get('/agents/:id/messages', asyncHandler((req, res) => {
  const data = listMessagesForAgent(req.params.id);
  markMessagesReadForAgent(req.params.id, 'manager');
  res.status(200).json({ ok: true, data });
}));

managerRouter.post('/agents/:id/messages', asyncHandler((req, res) => {
  const data = createMessageForAgent(req.params.id, req.body, 'manager', getManagerProfile().name);
  res.status(201).json({ ok: true, data });
}));

managerRouter.get('/daily-entries', asyncHandler((req, res) => {
  const data = listManagerDailyEntries(req.query || {});
  res.status(200).json({ ok: true, data });
}));


managerRouter.get('/locations', asyncHandler((req, res) => {
  const data = listManagerLocations(req.query || {});
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/tracking', asyncHandler((req, res) => {
  const data = listManagerLocations({ ...(req.query || {}), latest: '1' });
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/location-updates', asyncHandler((req, res) => {
  const data = listManagerLocations(req.query || {});
  res.status(200).json({ ok: true, data });
}));

managerRouter.post('/day-close', asyncHandler((req, res) => {
  const data = closeDay(req.body || {});
  res.status(201).json({ ok: true, data });
}));

managerRouter.get('/day-close', asyncHandler((req, res) => {
  const data = listDayClosures(req.query || {});
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/reports/day-close', asyncHandler((req, res) => {
  const data = listDayClosures(req.query || {});
  res.status(200).json({ ok: true, data });
}));

managerRouter.get('/sync', asyncHandler((req, res) => {
  const data = getManagerSync(req.query || {});
  res.status(200).json({ ok: true, data });
}));

module.exports = { managerRouter };
