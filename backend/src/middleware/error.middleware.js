function errorHandler(err, _req, res, _next) {
  const statusCode = err.statusCode || 500;
  const isServerError = statusCode >= 500;

  // In production, don't leak internal error details for 500s
  if (isServerError && process.env.NODE_ENV === 'production') {
    console.error('Internal error:', err.message, err.stack);
    return res.status(statusCode).json({
      message: 'Internal server error',
      details: null
    });
  }

  res.status(statusCode).json({
    message: err.message || 'Internal server error',
    details: err.details || null
  });
}

module.exports = { errorHandler };

