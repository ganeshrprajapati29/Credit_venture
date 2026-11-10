const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');
const Admin = require('../models/Admin');
const { ApiError, asyncHandler } = require('../utils/http');

const bearer = (req) => {
  const h = req.headers.authorization || '';
  if (h.startsWith('Bearer ')) return h.slice(7);
  return null;
};

const signUserToken = (user) => jwt.sign({ sub: String(user._id), typ: 'user' }, env.jwtSecret, { expiresIn: env.jwtExpiresIn });

const signAdminToken = (admin) =>
  jwt.sign({ sub: String(admin._id), typ: 'admin', role: admin.role }, env.jwtAdminSecret, {
    expiresIn: env.jwtAdminExpiresIn,
  });

const requireUser = asyncHandler(async (req, _res, next) => {
  const token = bearer(req);
  if (!token) throw ApiError.unauthorized('Please login to continue');
  let payload;
  try {
    payload = jwt.verify(token, env.jwtSecret);
  } catch {
    throw ApiError.unauthorized('Session expired, please login again');
  }
  if (payload.typ !== 'user') throw ApiError.unauthorized();
  const user = await User.findById(payload.sub);
  if (!user) throw ApiError.unauthorized('Account not found');
  if (user.status === 'blocked') throw ApiError.forbidden('Your account has been blocked. Please contact support.');
  req.user = user;
  next();
});

const requireAdmin = (...roles) =>
  asyncHandler(async (req, _res, next) => {
    const token = bearer(req);
    if (!token) throw ApiError.unauthorized('Admin login required');
    let payload;
    try {
      payload = jwt.verify(token, env.jwtAdminSecret);
    } catch {
      throw ApiError.unauthorized('Session expired, please login again');
    }
    if (payload.typ !== 'admin') throw ApiError.unauthorized();
    const admin = await Admin.findById(payload.sub);
    if (!admin || !admin.active) throw ApiError.unauthorized('Admin account disabled');
    if (roles.length && !roles.includes(admin.role)) throw ApiError.forbidden('You do not have access to this action');
    req.admin = admin;
    next();
  });

/** Accepts either a user or admin token; sets req.user or req.admin. */
const requireAny = asyncHandler(async (req, _res, next) => {
  const token = bearer(req);
  if (!token) throw ApiError.unauthorized();
  try {
    const p = jwt.verify(token, env.jwtAdminSecret);
    if (p.typ === 'admin') {
      const admin = await Admin.findById(p.sub);
      if (admin && admin.active) {
        req.admin = admin;
        return next();
      }
    }
  } catch {
    /* not an admin token */
  }
  try {
    const p = jwt.verify(token, env.jwtSecret);
    if (p.typ === 'user') {
      const user = await User.findById(p.sub);
      if (user && user.status === 'active') {
        req.user = user;
        return next();
      }
    }
  } catch {
    /* fallthrough */
  }
  throw ApiError.unauthorized();
});

module.exports = { signUserToken, signAdminToken, requireUser, requireAdmin, requireAny };
