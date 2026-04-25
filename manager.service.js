const { readBearerToken, verifyAuthToken } = require('../../utils/token');

function requireAuth(req, res, next) {
  try {
    const token = readBearerToken(req);
    req.auth = verifyAuthToken(token);
    next();
  } catch (error) {
    next(error);
  }
}

module.exports = { requireAuth };
