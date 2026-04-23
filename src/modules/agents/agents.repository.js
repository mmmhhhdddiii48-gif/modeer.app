const { getDatabase } = require('../../db');

const AGENT_COLUMNS = `
  id,
  user_id,
  employee_id,
  full_name,
  phone,
  status,
  created_at,
  updated_at
`;

function findAgentByUserId(userId) {
  return getDatabase()
    .prepare(`SELECT ${AGENT_COLUMNS} FROM agents WHERE user_id = ? LIMIT 1`)
    .get(userId);
}

function findAgentById(id) {
  return getDatabase()
    .prepare(`SELECT ${AGENT_COLUMNS} FROM agents WHERE id = ? LIMIT 1`)
    .get(id);
}

function serializeAgent(agent) {
  if (!agent) return null;
  return {
    id: agent.id,
    user_id: agent.user_id,
    employee_id: agent.employee_id,
    full_name: agent.full_name,
    phone: agent.phone || '',
    status: agent.status,
    created_at: agent.created_at,
    updated_at: agent.updated_at
  };
}

module.exports = {
  findAgentByUserId,
  findAgentById,
  serializeAgent
};
