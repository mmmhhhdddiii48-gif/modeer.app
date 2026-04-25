const { getDatabase } = require('../../db');
const { httpError } = require('../../utils/httpError');
const { hashPassword } = require('../../utils/password');
const { findUserById, serializeUser } = require('../users');
const { findAgentById, serializeAgent } = require('../agents');

const ALLOWED_AGENT_STATUSES = new Set(['active', 'inactive', 'suspended']);

function createManagerAgent(body) {
  const input = normalizeCreateInput(body);
  const db = getDatabase();

  assertUsernameAvailable(input.username);
  assertEmployeeIdAvailable(input.employee_id);

  let userId;
  let agentId;

  try {
    db.exec('BEGIN IMMEDIATE TRANSACTION');

    const userResult = db.prepare(`
      INSERT INTO users (username, password_hash, role, is_active, can_login)
      VALUES (?, ?, 'agent', ?, ?)
    `).run(
      input.username,
      hashPassword(input.password),
      boolToInt(input.is_active),
      boolToInt(input.can_login)
    );
    userId = Number(userResult.lastInsertRowid);

    const agentResult = db.prepare(`
      INSERT INTO agents (user_id, employee_id, full_name, phone, status)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      userId,
      input.employee_id,
      input.full_name,
      input.phone,
      input.status
    );
    agentId = Number(agentResult.lastInsertRowid);

    db.exec('COMMIT');
  } catch (error) {
    rollbackQuietly(db);
    handleSqliteConstraint(error);
    throw error;
  }

  return loadManagerAgentResponse(agentId);
}

function updateManagerAgent(agentIdRaw, body) {
  const agentId = normalizeId(agentIdRaw, 'agent id');
  const existingAgent = loadAgentOrFail(agentId);
  const existingUser = loadUserOrFail(existingAgent.user_id);
  const input = normalizeUpdateInput(body);

  if (!Object.keys(input).length) {
    throw httpError(400, 'VALIDATION_ERROR', 'At least one editable field is required.');
  }

  if (input.username && input.username.toLowerCase() !== String(existingUser.username).toLowerCase()) {
    assertUsernameAvailable(input.username, existingUser.id);
  }

  if (input.employee_id && input.employee_id.toLowerCase() !== String(existingAgent.employee_id).toLowerCase()) {
    assertEmployeeIdAvailable(input.employee_id, existingAgent.id);
  }

  const db = getDatabase();

  try {
    db.exec('BEGIN IMMEDIATE TRANSACTION');

    if (Object.prototype.hasOwnProperty.call(input, 'username')) {
      db.prepare(`
        UPDATE users
        SET username = ?, role = 'agent', updated_at = datetime('now')
        WHERE id = ?
      `).run(input.username, existingUser.id);
    }

    const agentFields = [];
    const values = [];

    for (const field of ['employee_id', 'full_name', 'phone', 'status']) {
      if (Object.prototype.hasOwnProperty.call(input, field)) {
        agentFields.push(`${field} = ?`);
        values.push(input[field]);
      }
    }

    if (agentFields.length) {
      agentFields.push('updated_at = datetime(\'now\')');
      values.push(agentId);
      db.prepare(`UPDATE agents SET ${agentFields.join(', ')} WHERE id = ?`).run(...values);
    }

    db.exec('COMMIT');
  } catch (error) {
    rollbackQuietly(db);
    handleSqliteConstraint(error);
    throw error;
  }

  return loadManagerAgentResponse(agentId);
}

function updateManagerAgentAccess(agentIdRaw, body) {
  const agentId = normalizeId(agentIdRaw, 'agent id');
  const existingAgent = loadAgentOrFail(agentId);
  const input = normalizeAccessInput(body);

  const fields = [];
  const values = [];
  if (Object.prototype.hasOwnProperty.call(input, 'is_active')) {
    fields.push('is_active = ?');
    values.push(boolToInt(input.is_active));
  }
  if (Object.prototype.hasOwnProperty.call(input, 'can_login')) {
    fields.push('can_login = ?');
    values.push(boolToInt(input.can_login));
  }

  if (!fields.length) {
    throw httpError(400, 'VALIDATION_ERROR', 'is_active or can_login is required.');
  }

  fields.push('role = \'agent\'');
  fields.push('updated_at = datetime(\'now\')');
  values.push(existingAgent.user_id);

  getDatabase()
    .prepare(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`)
    .run(...values);

  return loadManagerAgentResponse(agentId);
}


function listManagerAgents() {
  const rows = getDatabase().prepare(`
    SELECT a.*, u.username, u.is_active, u.can_login, u.role
    FROM agents a
    LEFT JOIN users u ON u.id = a.user_id
    ORDER BY a.id DESC
    LIMIT 500
  `).all();
  return rows.map((row) => ({
    user: serializeUser({
      id: row.user_id,
      username: row.username,
      role: row.role || 'agent',
      is_active: row.is_active,
      can_login: row.can_login,
      created_at: row.created_at,
      updated_at: row.updated_at
    }),
    agent: serializeAgent(row)
  }));
}

function loadManagerAgentResponse(agentId) {
  const agent = loadAgentOrFail(agentId);
  const user = loadUserOrFail(agent.user_id);
  return {
    user: serializeUser(user),
    agent: serializeAgent(agent)
  };
}

function normalizeCreateInput(body) {
  const username = requiredString(body?.username, 'username');
  const password = requiredString(body?.password, 'password');
  const employee_id = requiredString(body?.employee_id, 'employee_id');
  const full_name = requiredString(body?.full_name, 'full_name');
  const phone = optionalString(body?.phone);
  const status = normalizeStatus(body?.status ?? 'active');
  const is_active = normalizeBoolean(body?.is_active ?? true, 'is_active');
  const can_login = normalizeBoolean(body?.can_login ?? true, 'can_login');

  return { username, password, employee_id, full_name, phone, status, is_active, can_login };
}

function normalizeUpdateInput(body) {
  const input = {};

  if (Object.prototype.hasOwnProperty.call(body || {}, 'username')) {
    input.username = requiredString(body.username, 'username');
  }
  if (Object.prototype.hasOwnProperty.call(body || {}, 'employee_id')) {
    input.employee_id = requiredString(body.employee_id, 'employee_id');
  }
  if (Object.prototype.hasOwnProperty.call(body || {}, 'full_name')) {
    input.full_name = requiredString(body.full_name, 'full_name');
  }
  if (Object.prototype.hasOwnProperty.call(body || {}, 'phone')) {
    input.phone = optionalString(body.phone);
  }
  if (Object.prototype.hasOwnProperty.call(body || {}, 'status')) {
    input.status = normalizeStatus(body.status);
  }

  return input;
}

function normalizeAccessInput(body) {
  const input = {};
  if (Object.prototype.hasOwnProperty.call(body || {}, 'is_active')) {
    input.is_active = normalizeBoolean(body.is_active, 'is_active');
  }
  if (Object.prototype.hasOwnProperty.call(body || {}, 'can_login')) {
    input.can_login = normalizeBoolean(body.can_login, 'can_login');
  }
  return input;
}

function requiredString(value, fieldName) {
  if (typeof value !== 'string' || !value.trim()) {
    throw httpError(400, 'VALIDATION_ERROR', `${fieldName} is required.`);
  }
  return value.trim();
}

function optionalString(value) {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') {
    throw httpError(400, 'VALIDATION_ERROR', 'phone must be a string.');
  }
  return value.trim();
}

function normalizeStatus(value) {
  if (typeof value !== 'string' || !ALLOWED_AGENT_STATUSES.has(value.trim())) {
    throw httpError(400, 'VALIDATION_ERROR', 'status must be active, inactive, or suspended.');
  }
  return value.trim();
}

function normalizeBoolean(value, fieldName) {
  if (typeof value === 'boolean') return value;
  if (value === 1 || value === '1') return true;
  if (value === 0 || value === '0') return false;
  throw httpError(400, 'VALIDATION_ERROR', `${fieldName} must be boolean or 0/1.`);
}

function boolToInt(value) {
  return value ? 1 : 0;
}

function normalizeId(value, label) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id < 1) {
    throw httpError(400, 'VALIDATION_ERROR', `Invalid ${label}.`);
  }
  return id;
}

function loadAgentOrFail(agentId) {
  const agent = findAgentById(agentId);
  if (!agent) {
    throw httpError(404, 'AGENT_NOT_FOUND', 'Agent was not found.');
  }
  return agent;
}

function loadUserOrFail(userId) {
  const user = findUserById(userId);
  if (!user) {
    throw httpError(404, 'USER_NOT_FOUND', 'Linked user was not found.');
  }
  return user;
}

function assertUsernameAvailable(username, exceptUserId) {
  const existing = getDatabase()
    .prepare('SELECT id FROM users WHERE username = ? COLLATE NOCASE LIMIT 1')
    .get(username);

  if (existing && Number(existing.id) !== Number(exceptUserId || 0)) {
    throw httpError(409, 'USERNAME_ALREADY_EXISTS', 'username already exists.');
  }
}

function assertEmployeeIdAvailable(employeeId, exceptAgentId) {
  const existing = getDatabase()
    .prepare('SELECT id FROM agents WHERE employee_id = ? COLLATE NOCASE LIMIT 1')
    .get(employeeId);

  if (existing && Number(existing.id) !== Number(exceptAgentId || 0)) {
    throw httpError(409, 'EMPLOYEE_ID_ALREADY_EXISTS', 'employee_id already exists.');
  }
}

function rollbackQuietly(db) {
  try {
    db.exec('ROLLBACK');
  } catch (_) {
    // No active transaction; ignore.
  }
}

function handleSqliteConstraint(error) {
  const message = String(error?.message || '');
  if (!message.includes('constraint')) return;

  if (message.includes('users.username')) {
    throw httpError(409, 'USERNAME_ALREADY_EXISTS', 'username already exists.');
  }
  if (message.includes('agents.employee_id')) {
    throw httpError(409, 'EMPLOYEE_ID_ALREADY_EXISTS', 'employee_id already exists.');
  }
  if (message.includes('agents.user_id')) {
    throw httpError(409, 'USER_ALREADY_LINKED_TO_AGENT', 'user is already linked to an agent.');
  }

  throw httpError(409, 'DATABASE_CONSTRAINT_ERROR', 'Database constraint failed.');
}

module.exports = {
  listManagerAgents,
  createManagerAgent,
  updateManagerAgent,
  updateManagerAgentAccess
};
