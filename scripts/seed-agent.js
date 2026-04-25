const { connectDatabase, closeDatabase } = require('../src/db');
const { hashPassword } = require('../src/utils/password');

function main() {
  const db = connectDatabase();

  const username = process.env.SEED_AGENT_USERNAME || 'agent1';
  const password = process.env.SEED_AGENT_PASSWORD || '1234';
  const employeeId = process.env.SEED_AGENT_EMPLOYEE_ID || 'EMP-001';
  const fullName = process.env.SEED_AGENT_FULL_NAME || 'مندوب تجريبي';
  const phone = process.env.SEED_AGENT_PHONE || '07700000000';

  const passwordHash = hashPassword(password);
  const existingUser = db.prepare('SELECT id FROM users WHERE username = ? COLLATE NOCASE LIMIT 1').get(username);

  let userId;
  if (existingUser) {
    userId = existingUser.id;
    db.prepare(`
      UPDATE users
      SET password_hash = ?, role = 'agent', is_active = 1, can_login = 1, updated_at = datetime('now')
      WHERE id = ?
    `).run(passwordHash, userId);
  } else {
    const result = db.prepare(`
      INSERT INTO users (username, password_hash, role, is_active, can_login)
      VALUES (?, ?, 'agent', 1, 1)
    `).run(username, passwordHash);
    userId = Number(result.lastInsertRowid);
  }

  const existingAgent = db.prepare('SELECT id FROM agents WHERE user_id = ? LIMIT 1').get(userId);
  if (existingAgent) {
    db.prepare(`
      UPDATE agents
      SET employee_id = ?, full_name = ?, phone = ?, status = 'active', updated_at = datetime('now')
      WHERE user_id = ?
    `).run(employeeId, fullName, phone, userId);
  } else {
    db.prepare(`
      INSERT INTO agents (user_id, employee_id, full_name, phone, status)
      VALUES (?, ?, ?, ?, 'active')
    `).run(userId, employeeId, fullName, phone);
  }

  console.log('SEED_AGENT_OK');
  console.log(JSON.stringify({ username, password, employee_id: employeeId, full_name: fullName }, null, 2));
  closeDatabase();
}

try {
  main();
} catch (error) {
  console.error('SEED_AGENT_FAIL', error.message);
  closeDatabase();
  process.exitCode = 1;
}
