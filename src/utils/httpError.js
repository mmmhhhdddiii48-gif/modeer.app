class HttpError extends Error {
  constructor(statusCode, code, publicMessage, details) {
    super(publicMessage);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.code = code;
    this.publicMessage = publicMessage;
    this.details = details;
  }
}

function httpError(statusCode, code, publicMessage, details) {
  return new HttpError(statusCode, code, publicMessage, details);
}

module.exports = { HttpError, httpError };
