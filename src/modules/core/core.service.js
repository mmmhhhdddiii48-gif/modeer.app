const crypto = require('node:crypto');
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
function normalizeFiles(files, options = {}) {
  const strict = options.strict !== false;
  if (files === undefined || files === null) return [];
  if (!Array.isArray(files)) {
    if (strict) throw httpError(400, 'INVALID_ATTACHMENTS_PAYLOAD', 'invalid attachments payload. Send files or attachments as an array.');
    return [];
  }

  const normalized = [];
  const seen = new Set();

  for (const file of files.slice(0, 10)) {
    if (!file || typeof file !== 'object') {
      if (strict) throw httpError(400, 'INVALID_ATTACHMENTS_PAYLOAD', 'invalid attachments payload. Each attachment must be an object.');
      continue;
    }

    const originalId = safeString(file.id);
    const data = safeString(file.data);
    const rawName = safeString(file.name);
    const name = rawName || (data ? 'file' : '');
    const type = safeString(file.type, 'application/octet-stream') || 'application/octet-stream';
    const size = normalizeFileSize(file.size);

    if (!name && !data) continue;

    const dedupeKey = attachmentDedupeKey({ id: originalId, name, type, size, data });
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);

    normalized.push({
      id: originalId || `file_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      name,
      type,
      size,
      data,
      created_at: safeString(file.created_at) || nowSql()
    });
  }

  return normalized;
}

function normalizeAttachmentPayload(body = {}) {
  if (Object.prototype.hasOwnProperty.call(body || {}, 'files')) return normalizeFiles(body.files);
  if (Object.prototype.hasOwnProperty.call(body || {}, 'attachments')) return normalizeFiles(body.attachments);
  return [];
}

function normalizeFileSize(value) {
  const size = Number(value || 0);
  if (!Number.isFinite(size) || size < 0) return 0;
  return Math.floor(size);
}

function attachmentDedupeKey(file) {
  if (file.id) return `id:${file.id.toLowerCase()}`;
  const basis = file.data
    ? `data:${file.name}|${file.size}|${file.data}`
    : `meta:${file.name}|${file.size}|${file.type}`;
  return crypto.createHash('sha256').update(basis).digest('hex');
}

function serializeAttachments(raw) { return normalizeFiles(safeParseJSON(raw, []), { strict: false }); }
function loadAgentById(agentId) {
  const id = normalizeId(agentId, 'agent id');
  const agent = getDatabase().prepare('SELECT * FROM agents WHERE id = ? LIMIT 1').get(id);
  if (!agent) throw httpError(404, 'AGENT_NOT_FOUND', 'agent not found. Use the internal numeric agent.id.');
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
  const message = safeString(body?.message || body?.details || body?.notes || body?.note);
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
  const agent = loadAgentById(agentId);
  const text = safeString(body?.text || body?.message);
  const files = normalizeAttachmentPayload(body);
  if (!text && !files.length) throw httpError(400, 'INVALID_MESSAGE_PAYLOAD', 'invalid message payload. text or files is required.');
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
  const files = normalizeAttachmentPayload(body);
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

function createLocationForUser(userId, body = {}) {
  const agent = loadAgentByUserId(userId);
  const latitude = Number(body.latitude ?? body.lat);
  const longitude = Number(body.longitude ?? body.lng ?? body.lon);
  const accuracy = Number(body.accuracy || 0) || 0;
  const status = safeString(body.status, 'online') || 'online';
  const note = safeString(body.note || body.description);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw httpError(400, 'VALIDATION_ERROR', 'latitude is required and must be valid.');
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw httpError(400, 'VALIDATION_ERROR', 'longitude is required and must be valid.');
  }
  const result = getDatabase().prepare(`
    INSERT INTO location_updates (user_id, agent_id, employee_id, latitude, longitude, accuracy, status, note)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(agent.user_id, agent.id, agent.employee_id, latitude, longitude, accuracy, status, note);
  return serializeLocation(getDatabase().prepare('SELECT l.*, a.full_name FROM location_updates l LEFT JOIN agents a ON a.id = l.agent_id WHERE l.id = ?').get(Number(result.lastInsertRowid)));
}
function serializeLocation(row) {
  return {
    id: Number(row.id),
    user_id: Number(row.user_id),
    agent_id: Number(row.agent_id),
    employee_id: row.employee_id,
    agent_name: row.full_name || row.agent_name || '',
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    accuracy: Number(row.accuracy || 0),
    status: row.status || 'online',
    note: row.note || '',
    created_at: row.created_at
  };
}
function listManagerLocations(query = {}) {
  const params = [];
  let where = 'WHERE 1 = 1';
  if (query.agent_id) { where += ' AND l.agent_id = ?'; params.push(normalizeId(query.agent_id, 'agent_id')); }
  if (query.employee_id) { where += ' AND l.employee_id = ?'; params.push(safeString(query.employee_id)); }
  const latestOnly = query.latest !== '0';
  const sql = latestOnly ? `
    SELECT l.*, a.full_name
    FROM location_updates l
    LEFT JOIN agents a ON a.id = l.agent_id
    INNER JOIN (
      SELECT agent_id, MAX(id) AS max_id FROM location_updates GROUP BY agent_id
    ) x ON x.max_id = l.id
    ${where}
    ORDER BY l.id DESC
    LIMIT 300
  ` : `
    SELECT l.*, a.full_name
    FROM location_updates l
    LEFT JOIN agents a ON a.id = l.agent_id
    ${where}
    ORDER BY l.id DESC
    LIMIT 800
  `;
  return getDatabase().prepare(sql).all(...params).map(serializeLocation);
}
function listEmployeeLocations(userId, query = {}) {
  const agent = loadAgentByUserId(userId);
  const limit = Math.min(Math.max(Number(query.limit || 100), 1), 300);
  return getDatabase().prepare(`
    SELECT l.*, a.full_name
    FROM location_updates l
    LEFT JOIN agents a ON a.id = l.agent_id
    WHERE l.agent_id = ?
    ORDER BY l.id DESC
    LIMIT ?
  `).all(agent.id, limit).map(serializeLocation);
}
function summarizeDayEntries(closeDate) {
  const entries = listManagerDailyEntries({ date: closeDate });
  const totals = entries.reduce((acc, entry) => {
    const type = entry.type === 'outgoing' ? 'outgoing' : 'incoming';
    acc[type].count += 1;
    acc[type].amount += Number(entry.amount || 0);
    return acc;
  }, { incoming: { count: 0, amount: 0 }, outgoing: { count: 0, amount: 0 } });
  const byAgent = {};
  for (const entry of entries) {
    const key = String(entry.agent_id);
    if (!byAgent[key]) byAgent[key] = {
      agent_id: entry.agent_id,
      employee_id: entry.employee_id,
      agent_name: entry.agent_name || '',
      incoming_count: 0,
      incoming_amount: 0,
      outgoing_count: 0,
      outgoing_amount: 0
    };
    if (entry.type === 'outgoing') {
      byAgent[key].outgoing_count += 1;
      byAgent[key].outgoing_amount += Number(entry.amount || 0);
    } else {
      byAgent[key].incoming_count += 1;
      byAgent[key].incoming_amount += Number(entry.amount || 0);
    }
  }
  return {
    date: closeDate,
    totals,
    net: Number(totals.incoming.amount || 0) - Number(totals.outgoing.amount || 0),
    agents: Object.values(byAgent),
    entries
  };
}
function closeDay(body = {}) {
  const closeDate = safeString(body.date || body.close_date, new Date().toISOString().slice(0, 10));
  const notes = safeString(body.notes || body.note);
  const report = summarizeDayEntries(closeDate);
  const db = getDatabase();
  db.prepare(`
    INSERT INTO day_closures (close_date, closed_by, notes, report_json, created_at)
    VALUES (?, 'manager', ?, ?, datetime('now'))
    ON CONFLICT(close_date) DO UPDATE SET
      notes = excluded.notes,
      report_json = excluded.report_json,
      created_at = datetime('now')
  `).run(closeDate, notes, JSON.stringify(report));
  db.prepare("UPDATE daily_entries SET status = 'closed', updated_at = datetime('now') WHERE entry_date = ?").run(closeDate);
  const row = db.prepare('SELECT * FROM day_closures WHERE close_date = ? LIMIT 1').get(closeDate);
  return serializeDayClosure(row);
}
function serializeDayClosure(row) {
  return {
    id: Number(row.id),
    date: row.close_date,
    closed_by: row.closed_by || 'manager',
    notes: row.notes || '',
    report: safeParseJSON(row.report_json, {}),
    created_at: row.created_at
  };
}
function listDayClosures(query = {}) {
  const params = [];
  let where = 'WHERE 1 = 1';
  if (query.date) { where += ' AND close_date = ?'; params.push(safeString(query.date)); }
  return getDatabase().prepare(`SELECT * FROM day_closures ${where} ORDER BY close_date DESC, id DESC LIMIT 200`).all(...params).map(serializeDayClosure);
}
function getManagerSync(query = {}) {
  const date = safeString(query.date || new Date().toISOString().slice(0, 10));
  return {
    notifications: listManagerNotifications(),
    daily_entries: listManagerDailyEntries(date ? { date } : {}),
    locations: listManagerLocations({ latest: '1' }),
    day_closures: listDayClosures({ date })
  };
}
function getEmployeeSync(userId) {
  return {
    notifications: listNotificationsForUser(Number(userId), { limit: 100 }),
    unread_notifications: unreadNotificationCount(Number(userId)),
    messages: listMessagesForUser(Number(userId)).messages,
    daily_entries: listDailyEntriesForUser(Number(userId)).entries,
    locations: listEmployeeLocations(Number(userId), { limit: 20 })
  };
}

function getEmployeeBootstrap(userId) {
  const context = getCurrentAgentContext(userId);
  return {
    ...context,
    manager: getManagerProfile(),
    unread_notifications: unreadNotificationCount(Number(userId)),
    notifications: listNotificationsForUser(Number(userId), { limit: 50 }),
    messages: listMessagesForUser(Number(userId)).messages,
    daily_entries: listDailyEntriesForUser(Number(userId)).entries,
    locations: listEmployeeLocations(Number(userId), { limit: 20 })
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
  createLocationForUser,
  listManagerLocations,
  listEmployeeLocations,
  closeDay,
  listDayClosures,
  getManagerSync,
  getEmployeeSync,
  getEmployeeBootstrap
};
