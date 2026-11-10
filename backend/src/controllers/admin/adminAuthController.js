const Admin = require('../../models/Admin');
const { signAdminToken } = require('../../middleware/auth');
const { ApiError, asyncHandler, ok } = require('../../utils/http');
const { RX, validate } = require('../../utils/validators');

exports.login = asyncHandler(async (req, res) => {
  validate(req.body, {
    email: { required: true, rx: RX.email, label: 'Email' },
    password: { required: true, label: 'Password' },
  });
  const admin = await Admin.findOne({ email: String(req.body.email).toLowerCase() }).select('+passwordHash');
  if (!admin || !(await admin.checkPassword(req.body.password))) throw ApiError.unauthorized('Invalid email or password');
  if (!admin.active) throw ApiError.forbidden('Your admin account is disabled');
  admin.lastLoginAt = new Date();
  await admin.save();
  ok(res, { token: signAdminToken(admin), admin }, 'Welcome back');
});

exports.me = asyncHandler(async (req, res) => ok(res, { admin: req.admin }));

exports.changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!newPassword || String(newPassword).length < 8) throw ApiError.badRequest('New password must be at least 8 characters');
  const admin = await Admin.findById(req.admin._id).select('+passwordHash');
  if (!(await admin.checkPassword(currentPassword || ''))) throw ApiError.badRequest('Current password is incorrect');
  await admin.setPassword(newPassword);
  await admin.save();
  ok(res, {}, 'Password updated');
});

/* ---------- team management (superadmin) */

exports.list = asyncHandler(async (_req, res) => {
  ok(res, { admins: await Admin.find().sort({ createdAt: -1 }) });
});

exports.create = asyncHandler(async (req, res) => {
  validate(req.body, {
    name: { required: true, label: 'Name' },
    email: { required: true, rx: RX.email, label: 'Email' },
    password: { required: true, label: 'Password' },
    role: { required: true, label: 'Role', oneOf: ['superadmin', 'manager', 'verifier'] },
  });
  if (String(req.body.password).length < 8) throw ApiError.badRequest('Password must be at least 8 characters');
  const admin = new Admin({ name: req.body.name, email: req.body.email, role: req.body.role });
  await admin.setPassword(req.body.password);
  await admin.save();
  ok(res, { admin }, 'Team member added', 201);
});

exports.update = asyncHandler(async (req, res) => {
  const admin = await Admin.findById(req.params.id);
  if (!admin) throw ApiError.notFound('Admin not found');
  if (String(admin._id) === String(req.admin._id) && (req.body.active === false || (req.body.role && req.body.role !== admin.role))) {
    throw ApiError.badRequest('You cannot disable or change the role of your own account');
  }
  if (req.body.name) admin.name = req.body.name;
  if (req.body.role) admin.role = req.body.role;
  if (typeof req.body.active === 'boolean') admin.active = req.body.active;
  if (req.body.password) {
    if (String(req.body.password).length < 8) throw ApiError.badRequest('Password must be at least 8 characters');
    await admin.setPassword(req.body.password);
  }
  await admin.save();
  ok(res, { admin }, 'Updated');
});
