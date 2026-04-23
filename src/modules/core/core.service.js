const { getDatabase } = require('../../db');
const { httpError } = require('../../utils/httpError');
const { getCurrentAgentContext } = require('../auth/auth.service');

function nowSql() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}
function safeParseJSON(raw, fallback) {
  try { return raw ? JSON.parse(raw) : fallback; }
  catch (_) { return fallback; }
}
function safeString(value, fallback = '') {
  if (value === undefined || value === null) return fallback;
  return String(value).trim();
}
function normalizeId(value, label = 'id') {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id < 1) throw httpError(400, 'VALIDATION_ERROR', `Invalid ${label}.`);
  return id;
}
function boolToInt(value) { return value ? 1 : 0; }
function serializeBool(value) { return Number(value) === 1; }
function normalizeFiles(files) {
  if (!Array.isArray(files)) return [];
  return files.slice(0, 10).map((file) => ({
    id: safeString(file.id) || `file_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    name: safeString(file.name, 'file'),
    type: safeString(file.type, 'application/octet-stream'),
    size: Number(file.size || 0) || 0,
    data: safeString(file.data),
    created_at: safeString(file.created_at) || nowSql()
  })).filter((file) => file.name || file.data);
}
function serializeAttachments(raw) { return safeParseJSON(raw, []); }
function loadAgentById(agentId) {
  const id = normalizeId(agentId, 'agent_id');
  const agent = getDatabase().prepare('SELECT * FROM agents WHERE id = ? LIMIT 1').get(id);
  if (!agent) throw httpError(404, 'AGENT_NOT_FOUND', 'Agent was not found.');
  return agent;
}
function loadAgentByUserId(userId) {
  const agent = getDatabase().prepare('SELECT * FROM agents WHERE user_id = ? LIMIT 1').get(normalizeId(userId, 'user_id'));
  if (!agent) throw httpError(404, 'AGENT_NOT_FOUND', 'Agent was not found.');
  return agent;
}
function serializeAgent(agent) {
  return {
    id: Number(agent.id),
    user_id: Number(agent.user_id),
    employee_id: agent.employee_id,
    full_name: agent.full_name,
    phone: agent.phone || '',
    status: agent.status,
    created_at: agent.created_at,
    updated_at: agent.updated_at
  };
}
function getManagerProfile() {
  const row = getDatabase().prepare('SELECT value FROM system_settings WHERE key = ? LIMIT 1').get('manager_profile');
  const value = safeParseJSON(row?.value, {});
  return {
    name: safeString(value.name, 'المدير'),
    brand: safeString(value.brand, 'تطبيق النخبة'),
    company: safeString(value.company || value.brand, 'تطبيق النخبة'),
    phone: safeString(value.phone),
    email: safeString(value.email),
    role: safeString(value.role, 'مدير'),
    updated_at: safeString(value.updated_at)
  };
}
function updateManagerProfile(body) {
  const current = getManagerProfile();
  const profile = {
    name: safeString(body?.name, current.name) || 'المدير',
    brand: safeString(body?.brand, current.brand) || 'تطبيق النخبة',
    company: safeString(body?.company || body?.brand, current.company || current.brand) || 'تطبيق النخبة',
    phone: safeString(body?.phone, current.phone),
    email: safeString(body?.email, current.email),
    role: safeString(body?.role, current.role) || 'مدير',
    updated_at: nowSql()
  };
  getDatabase().prepare(`
    INSERT INTO system_settings (key, value, updated_at)
    VALUES ('manager_profile', ?, datetime('now'))
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = datetime('now')
  `).run(JSON.stringify(profile));
  return profile;
}
function serializeNotification(row) {
  return {
    id: Number(row.id),
    user_id: Number(row.user_id),
    agent_id: row.agent_id == null ? null : Number(row.agent_id),
    title: row.title,
    message: row.message || '',
    type: row.type || 'general',
    priority: row.priority || 'normal',
    is_read: serializeBool(row.is_read),
    created_at: row.created_at,
    read_at: row.read_at || ''
  };
}
function createNotificationForAgent(agentId, body) {
  const agent = loadAgentById(agentId || body?.agent_id);
  const title = safeString(body?.title);
  if (!title) throw httpError(400, 'VALIDATION_ERROR', 'title is required.');
  const message = safeString(body?.message || body?.details);
  const type = safeString(body?.type, 'general') || 'general';
  const priority = safeString(body?.priority, 'normal') || 'normal';
  const result = getDatabase().prepare(`
    INSERT INTO notifications (user_id, agent_id, title, message, type, priority, is_read)
    VALUES (?, ?, ?, ?, ?, ?, 0)
  `).run(agent.user_id, agent.id, title, message, type, priority);
  return serializeNotification(getDatabase().prepare('SELECT * FROM notifications WHERE id = ?').get(Number(result.lastInsertRowid)));
}
function listNotificationsForUser(userId, options = {}) {
  const db = getDatabase();
  const onlyUnread = !!options.unread;
  const limit = Math.min(Math.max(Number(options.limit || 100), 1), 300);
  const rows = onlyUnread
    ? db.prepare('SELECT * FROM notifications WHERE user_id = ? AND is_read = 0 ORDER BY id DESC LIMIT ?').all(userId, limit)
    : db.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT ?').all(userId, limit);
  return rows.map(serializeNotification);
}
function listManagerNotifications() {
  return getDatabase().prepare(`
    SELECT n.*, a.employee_id, a.full_name
    FROM notifications n
    LEFT JOIN agents a ON a.id = n.agent_id
    ORDER BY n.id DESC
    LIMIT 300
  `).all().map((row) => ({ ...serializeNotification(row), employee_id: row.employee_id || '', agent_name: row.full_name || '' }));
}
function markNotificationRead(userId, notificationId) {
  const id = normalizeId(notificationId, 'notification id');
  const db = getDatabase();
  const row = db.prepare('SELECT * FROM notifications WHERE id = ? AND user_id = ? LIMIT 1').get(id, userId);
  if (!row) throw httpError(404, 'NOTIFICATION_NOT_FOUND', 'Notification was not found.');
  db.prepare('UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, datetime(\'now\')) WHERE id = ?').run(id);
  return serializeNotification(db.prepare('SELECT * FROM notifications WHERE id = ?').get(id));
}
function unreadNotificationCount(userId) {
  const row = getDatabase().prepare('SELECT COUNT(*) AS count FROM notifications WHERE user_id = ? AND is_read = 0').get(userId);
  return Number(row?.count || 0);
}
function serializeMessage(row) {
  return {
    id: Number(row.id),
    user_id: Number(row.user_id),
    agent_id: row.agent_id == null ? null : Number(row.agent_id),
    sender_role: row.sender_role,
    sender_name: row.sender_name || '',
    text: row.text || '',
    files: serializeAttachments(row.attachments_json),
    is_read_by_manager: serializeBool(row.is_read_by_manager),
    is_read_by_agent: serializeBool(row.is_read_by_agent),
    created_at: row.created_at
  };
}
function createMessageForAgent(agentId, body, senderRole = 'manager', senderName = '') {
  const agent = loadAgentById(agentId || body?.agent_id);
  const text = safeString(body?.text || body?.message);
  const files = normalizeFiles(body?.files || body?.attachments || []);
  if (!text && !files.length) throw httpError(400, 'VALIDATION_ERROR', 'text or files is required.');
  const isManager = senderRole === 'manager';
  const result = getDatabase().prepare(`
    INSERT INTO messages (user_id, agent_id, sender_role, sender_name, text, attachments_json, is_read_by_manager, is_read_by_agent)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    agent.user_id,
    agent.id,
    isManager ? 'manager' : 'agent',
    senderName || (isManager ? getManagerProfile().name : agent.full_name),
    text,
    JSON.stringify(files),
    boolToInt(isManager),
    boolToInt(!isManager)
  );
  return serializeMessage(getDatabase().prepare('SELECT * FROM messages WHERE id = ?').get(Number(result.lastInsertRowid)));
}
function listMessagesForAgent(agentId) {
  const agent = loadAgentById(agentId);
  const rows = getDatabase().prepare('SELECT * FROM messages WHERE agent_id = ? ORDER BY id ASC LIMIT 500').all(agent.id);
  return rows.map(serializeMessage);
}
function listMessagesForUser(userId) {
  const agent = loadAgentByUserId(userId);
  const rows = getDatabase().prepare('SELECT * FROM messages WHERE user_id = ? ORDER BY id ASC LIMIT 500').all(userId);
  return { agent: serializeAgent(agent), messages: rows.map(serializeMessage) };
}
function markMessagesReadForAgent(agentId, readerRole) {
  const agent = loadAgentById(agentId);
  if (readerRole === 'manager') {
    getDatabase().prepare('UPDATE messages SET is_read_by_manager = 1 WHERE agent_id = ?').run(agent.id);
  } else {
    getDatabase().prepare('UPDATE messages SET is_read_by_agent = 1 WHERE agent_id = ?').run(agent.id);
  }
  return { ok: true, agent_id: agent.id };
}
function serializeDailyEntry(row) {
  return {
    id: Number(row.id),
    user_id: Number(row.user_id),
    agent_id: Number(row.agent_id),
    employee_id: row.employee_id,
    type: row.entry_type,
    amount: Number(row.amount || 0),
    details: row.details || '',
    date: row.entry_date,
    files: serializeAttachments(row.attachments_json),
    status: row.status || 'open',
    created_by: row.created_by || 'agent',
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}
function createDailyEntryForUser(userId, body, createdBy = 'agent') {
  const agent = loadAgentByUserId(userId);
  const rawType = safeString(body?.type || body?.entry_type);
  const entryType = rawType === 'out' || rawType === 'outgoing' ? 'outgoing' : 'incoming';
  const amount = Number(body?.amount || 0);
  const details = safeString(body?.details || body?.note || body?.description);
  const entryDate = safeString(body?.date || body?.entry_date, new Date().toISOString().slice(0, 10));
  const files = normalizeFiles(body?.files || body?.attachments || []);
  if (!details) throw httpError(400, 'VALIDATION_ERROR', 'details is required.');
  if (!Number.isFinite(amount) || amount <= 0) throw httpError(400, 'VALIDATION_ERROR', 'amount must be greater than zero.');
  const result = getDatabase().prepare(`
    INSERT INTO daily_entries (user_id, agent_id, employee_id, entry_type, amount, details, entry_date, attachments_json, created_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(agent.user_id, agent.id, agent.employee_id, entryType, amount, details, entryDate, JSON.stringify(files), createdBy);
  return serializeDailyEntry(getDatabase().prepare('SELECT * FROM daily_entries WHERE id = ?').get(Number(result.lastInsertRowid)));
}
function listDailyEntriesForUser(userId, options = {}) {
  const agent = loadAgentByUserId(userId);
  const params = [userId];
  let where = 'WHERE user_id = ?';
  if (options.date) { where += ' AND entry_date = ?'; params.push(options.date); }
  const rows = getDatabase().prepare(`SELECT * FROM daily_entries ${where} ORDER BY entry_date DESC, id DESC LIMIT 500`).all(...params);
  return { agent: serializeAgent(agent), entries: rows.map(serializeDailyEntry) };
}
function listManagerDailyEntries(query = {}) {
  const params = [];
  let where = 'WHERE 1 = 1';
  if (query.agent_id) { where += ' AND d.agent_id = ?'; params.push(normalizeId(query.agent_id, 'agent_id')); }
  if (query.employee_id) { where += ' AND d.employee_id = ?'; params.push(safeString(query.employee_id)); }
  if (query.date) { where += ' AND d.entry_date = ?'; params.push(safeString(query.date)); }
  const rows = getDatabase().prepare(`
    SELECT d.*, a.full_name, u.username
    FROM daily_entries d
    LEFT JOIN agents a ON a.id = d.agent_id
    LEFT JOIN users u ON u.id = d.user_id
    ${where}
    ORDER BY d.entry_date DESC, d.id DESC
    LIMIT 800
  `).all(...params);
  return rows.map((row) => ({ ...serializeDailyEntry(row), agent_name: row.full_name || '', username: row.username || '' }));
}
function getEmployeeBootstrap(userId) {
  const context = getCurrentAgentContext(userId);
  return {
    ...context,
    manager: getManagerProfile(),
    unread_notifications: unreadNotificationCount(Number(userId)),
    notifications: listNotificationsForUser(Number(userId), { limit: 50 }),
    messages: listMessagesForUser(Number(userId)).messages,
    daily_entries: listDailyEntriesForUser(Number(userId)).entries
  };
}
module.exports = {
  getManagerProfile,
  updateManagerProfile,
  createNotificationForAgent,
  listManagerNotifications,
  listNotificationsForUser,
  markNotificationRead,
  unreadNotificationCount,
  createMessageForAgent,
  listMessagesForAgent,
  listMessagesForUser,
  markMessagesReadForAgent,
  createDailyEntryForUser,
  listDailyEntriesForUser,
  listManagerDailyEntries,
  getEmployeeBootstrap
};
