const { httpError } = require('../../utils/httpError');
const { verifyPassword } = require('../../utils/password');
const { signAuthToken } = require('../../utils/token');
const { findUserByUsername, findUserById, serializeUser } = require('../users');
const { findAgentByUserId, serializeAgent } = require('../agents');

function normalizeLoginInput(body) {
  const username = typeof body?.username === 'string' ? body.username.trim() : '';
  const password = typeof body?.password === 'string' ? body.password : '';

  if (!username || !password) {
    throw httpError(400, 'VALIDATION_ERROR', 'username and password are required.');
  }

  return { username, password };
}

function loginAgent(body) {
  const { username, password } = normalizeLoginInput(body);
  const user = findUserByUsername(username);

  if (!user) {
    throw httpError(401, 'INVALID_CREDENTIALS', 'Invalid username or password.');
  }

  const passwordOk = verifyPassword(password, user.password_hash);
  if (!passwordOk) {
    throw httpError(401, 'INVALID_CREDENTIALS', 'Invalid username or password.');
  }

  assertAgentLoginAllowed(user);
  const agent = loadLinkedAgentOrFail(user.id);
  const safeUser = serializeUser(user);

  return {
    token: signAuthToken(safeUser),
    token_type: 'Bearer',
    user: safeUser,
    agent: serializeAgent(agent)
  };
}

function getCurrentAgentContext(userId) {
  const user = findUserById(Number(userId));
  if (!user) {
    throw httpError(401, 'USER_NOT_FOUND', 'Authenticated user was not found.');
  }

  assertAgentLoginAllowed(user);
  const agent = loadLinkedAgentOrFail(user.id);

  return {
    user: serializeUser(user),
    agent: serializeAgent(agent)
  };
}

function assertAgentLoginAllowed(user) {
  if (user.role !== 'agent') {
    throw httpError(403, 'ROLE_NOT_ALLOWED', 'Only agent accounts can access the agent app.');
  }

  if (Number(user.is_active) !== 1) {
    throw httpError(403, 'ACCOUNT_INACTIVE', 'This account is inactive.');
  }

  if (Number(user.can_login) !== 1) {
    throw httpError(403, 'LOGIN_DISABLED', 'Login is disabled for this account.');
  }
}

function loadLinkedAgentOrFail(userId) {
  const agent = findAgentByUserId(userId);
  if (!agent) {
    throw httpError(403, 'AGENT_PROFILE_NOT_FOUND', 'No agent profile is linked to this user.');
  }

  if (agent.status !== 'active') {
    throw httpError(403, 'AGENT_INACTIVE', 'The linked agent profile is not active.');
  }

  return agent;
}

module.exports = {
  loginAgent,
  getCurrentAgentContext
};
