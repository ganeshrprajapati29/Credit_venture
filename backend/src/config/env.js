require('dotenv').config();

const required = (key, fallback) => {
  const v = process.env[key] ?? fallback;
  if (v === undefined || v === '') {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return v;
};

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '5000', 10),
  mongoUri: required('MONGO_URI', 'mongodb://127.0.0.1:27017/credit_ventures'),
  jwtSecret: required('JWT_SECRET', process.env.NODE_ENV === 'production' ? undefined : 'dev-user-secret-change-me'),
  jwtAdminSecret: required(
    'JWT_ADMIN_SECRET',
    process.env.NODE_ENV === 'production' ? undefined : 'dev-admin-secret-change-me'
  ),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',
  jwtAdminExpiresIn: process.env.JWT_ADMIN_EXPIRES_IN || '12h',
  uploadDir: process.env.UPLOAD_DIR || require('path').join(__dirname, '..', '..', 'uploads'),
  maxUploadMb: parseInt(process.env.MAX_UPLOAD_MB || '8', 10),
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  seedAdmin: {
    name: process.env.ADMIN_NAME || 'Super Admin',
    email: process.env.ADMIN_EMAIL || 'admin@creditventures.in',
    password: process.env.ADMIN_PASSWORD || 'Admin@12345',
  },
};

env.isProd = env.nodeEnv === 'production';

module.exports = env;
