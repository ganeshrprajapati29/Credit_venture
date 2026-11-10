const User = require('../models/User');
const Loan = require('../models/Loan');
const { signUserToken } = require('../middleware/auth');
const { ApiError, asyncHandler, ok, pick } = require('../utils/http');
const { RX, validate } = require('../utils/validators');

const MAX_FAILED = 5;
const LOCK_MINUTES = 15;

const authPayload = async (user) => {
  const activeLoan = await Loan.findOne({ user: user._id, status: { $in: Loan.ACTIVE_STATUSES } })
    .select('_id loanNumber status currentStep')
    .lean();
  return { token: signUserToken(user), user, activeLoan };
};

exports.checkMobile = asyncHandler(async (req, res) => {
  validate(req.body, { mobile: { required: true, rx: RX.mobile, label: 'Mobile number', msg: 'Enter a valid 10 digit mobile number' } });
  const exists = await User.exists({ mobile: req.body.mobile });
  ok(res, { registered: !!exists });
});

exports.register = asyncHandler(async (req, res) => {
  const { mobile, mpin, fullName, consent = {}, device = {} } = req.body;
  validate(req.body, {
    mobile: { required: true, rx: RX.mobile, label: 'Mobile number', msg: 'Enter a valid 10 digit mobile number' },
    mpin: { required: true, rx: RX.mpin, label: 'MPIN', msg: 'MPIN must be 4 digits' },
  });
  if (/^(\d)\1{3}$/.test(mpin) || ['1234', '4321', '0123'].includes(mpin)) {
    throw ApiError.badRequest('MPIN is too easy to guess, choose a different one');
  }
  if (!consent.termsAccepted || !consent.privacyAccepted) {
    throw ApiError.badRequest('Please accept the Terms & Privacy Policy to continue');
  }
  if (await User.exists({ mobile })) throw ApiError.conflict('This mobile number is already registered. Please login.');

  const user = new User({
    mobile,
    fullName,
    consent: {
      termsAccepted: true,
      privacyAccepted: true,
      creditBureauConsent: !!consent.creditBureauConsent,
      permissions: Array.isArray(consent.permissions) ? consent.permissions.slice(0, 10) : [],
      acceptedAt: new Date(),
      appVersion: device.appVersion,
    },
    device: { ...pick(device, ['model', 'brand', 'os', 'osVersion', 'appVersion', 'deviceId']), lastSeenAt: new Date() },
    lastLoginAt: new Date(),
  });
  await user.setMpin(mpin);
  await user.save();
  ok(res, await authPayload(user), 'Account created', 201);
});

exports.login = asyncHandler(async (req, res) => {
  const { mobile, mpin, device = {} } = req.body;
  validate(req.body, {
    mobile: { required: true, rx: RX.mobile, label: 'Mobile number', msg: 'Enter a valid 10 digit mobile number' },
    mpin: { required: true, rx: RX.mpin, label: 'MPIN', msg: 'MPIN must be 4 digits' },
  });
  const user = await User.findOne({ mobile }).select('+mpinHash');
  if (!user) throw ApiError.notFound('No account found with this number. Please sign up.');
  if (user.status === 'blocked') throw ApiError.forbidden('Your account has been blocked. Please contact support.');
  if (user.lockUntil && user.lockUntil > new Date()) {
    const mins = Math.ceil((user.lockUntil - Date.now()) / 60000);
    throw ApiError.forbidden(`Too many wrong attempts. Try again in ${mins} minute(s).`);
  }
  const match = await user.checkMpin(mpin);
  if (!match) {
    user.failedLogins += 1;
    if (user.failedLogins >= MAX_FAILED) {
      user.lockUntil = new Date(Date.now() + LOCK_MINUTES * 60000);
      user.failedLogins = 0;
    }
    await user.save();
    throw ApiError.unauthorized('Incorrect MPIN');
  }
  user.failedLogins = 0;
  user.lockUntil = undefined;
  user.lastLoginAt = new Date();
  user.device = { ...(user.device?.toObject?.() || {}), ...pick(device, ['model', 'brand', 'os', 'osVersion', 'appVersion', 'deviceId']), lastSeenAt: new Date() };
  await user.save();
  ok(res, await authPayload(user), 'Logged in');
});

exports.me = asyncHandler(async (req, res) => {
  const activeLoan = await Loan.findOne({ user: req.user._id, status: { $in: Loan.ACTIVE_STATUSES } })
    .select('_id loanNumber status currentStep')
    .lean();
  ok(res, { user: req.user, activeLoan });
});

exports.updateProfile = asyncHandler(async (req, res) => {
  const { fullName, email } = req.body;
  if (email) validate(req.body, { email: { rx: RX.email, label: 'Email' } });
  if (fullName !== undefined) req.user.fullName = String(fullName).trim().slice(0, 80);
  if (email !== undefined) req.user.email = email;
  await req.user.save();
  ok(res, { user: req.user }, 'Profile updated');
});

exports.changeMpin = asyncHandler(async (req, res) => {
  const { oldMpin, newMpin } = req.body;
  validate(req.body, {
    oldMpin: { required: true, rx: RX.mpin, label: 'Current MPIN' },
    newMpin: { required: true, rx: RX.mpin, label: 'New MPIN', msg: 'New MPIN must be 4 digits' },
  });
  const user = await User.findById(req.user._id).select('+mpinHash');
  if (!(await user.checkMpin(oldMpin))) throw ApiError.badRequest('Current MPIN is incorrect');
  await user.setMpin(newMpin);
  await user.save();
  ok(res, {}, 'MPIN changed');
});

/** Location / device ping, only sent by the app after the user granted the permission. */
exports.updateDevice = asyncHandler(async (req, res) => {
  const d = pick(req.body, ['model', 'brand', 'os', 'osVersion', 'appVersion', 'deviceId']);
  const { latitude, longitude, permissions } = req.body;
  const device = { ...(req.user.device?.toObject?.() || {}), ...d, lastSeenAt: new Date() };
  if (Number.isFinite(Number(latitude)) && Number.isFinite(Number(longitude))) {
    device.lastLatitude = Number(latitude);
    device.lastLongitude = Number(longitude);
  }
  req.user.device = device;
  if (Array.isArray(permissions)) req.user.consent.permissions = permissions.slice(0, 10);
  await req.user.save();
  ok(res, {}, 'Device updated');
});
