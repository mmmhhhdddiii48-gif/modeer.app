function notFound(req, res) {
  res.status(404).json({
    ok: false,
    error: {
      code: 'NOT_FOUND',
      message: 'No API endpoint is defined for this path yet.'
    }
  });
}

module.exports = { notFound };
