const multer = require('multer');
const mongoose = require('mongoose');
const env = require('../config/env');

const notFound = (req, res) => res.status(404).json({ success: false, message: `Route not found: ${req.method} ${req.originalUrl}` });

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, _next) => {
  let status = err.status || 500;
  let message = err.message || 'Something went wrong';
  let details = err.details;

  if (err instanceof multer.MulterError) {
    status = 400;
    message = err.code === 'LIMIT_FILE_SIZE' ? `File too large. Max ${env.maxUploadMb} MB allowed.` : err.message;
  } else if (err instanceof mongoose.Error.ValidationError) {
    status = 400;
    message = Object.values(err.errors)[0]?.message || 'Validation failed';
    details = Object.fromEntries(Object.entries(err.errors).map(([k, v]) => [k, v.message]));
  } else if (err instanceof mongoose.Error.CastError) {
    status = 400;
    message = `Invalid ${err.path}`;
  } else if (err.code === 11000) {
    status = 409;
    message = `${Object.keys(err.keyValue || {}).join(', ') || 'Value'} already exists`;
  } else if (err.type === 'entity.parse.failed') {
    status = 400;
    message = 'Invalid JSON body';
  }

  if (status >= 500) console.error('[error]', err);

  res.status(status).json({
    success: false,
    message: status >= 500 && env.isProd ? 'Internal server error' : message,
    ...(details ? { details } : {}),
  });
};

module.exports = { notFound, errorHandler };
