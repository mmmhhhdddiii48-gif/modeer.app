const { getDatabase } = require('../../db');

const USER_COLUMNS = `
  id,
  username,
  password_hash,
  role,
  is_active,
  can_login,
  created_at,
  updated_at
`;

function findUserByUsername(username) {
  return getDatabase()
    .prepare(`SELECT ${USER_COLUMNS} FROM users WHERE username = ? COLLATE NOCASE LIMIT 1`)
    .get(username);
}

function findUserById(id) {
  return getDatabase()
    .prepare(`SELECT ${USER_COLUMNS} FROM users WHERE id = ? LIMIT 1`)
    .get(id);
}

function serializeUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    is_active: Boolean(user.is_active),
    can_login: Boolean(user.can_login),
    created_at: user.created_at,
    updated_at: user.updated_at
  };
}

module.exports = {
  findUserByUsername,
  findUserById,
  serializeUser
};
