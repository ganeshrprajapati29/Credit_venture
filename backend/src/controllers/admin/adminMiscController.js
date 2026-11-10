const User = require('../../models/User');
const Loan = require('../../models/Loan');
const Banner = require('../../models/Banner');
const Setting = require('../../models/Setting');
const Notification = require('../../models/Notification');
const { ApiError, asyncHandler, ok, escapeRegex, paginate, pick } = require('../../utils/http');
const { RX } = require('../../utils/validators');
const { removeFile, PUBLIC_DIR } = require('../../middleware/upload');
const { bannerUrl } = require('../appController');

/* ---------------------------------------------------------------- users */

exports.listUsers = asyncHandler(async (req, res) => {
  const { page, limit, skip } = paginate(req.query);
  const q = {};
  if (req.query.status && req.query.status !== 'all') q.status = req.query.status;
  if (req.query.search) {
    const rx = new RegExp(escapeRegex(req.query.search.trim()), 'i');
    q.$or = [{ mobile: rx }, { fullName: rx }, { email: rx }];
  }
  const [items, total] = await Promise.all([User.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(), User.countDocuments(q)]);
  const loans = await Loan.find({ user: { $in: items.map((u) => u._id) } })
    .sort({ createdAt: 1 })
    .select('user status')
    .lean();
  const map = {};
  loans.forEach((l) => {
    const k = String(l.user);
    map[k] = { loans: (map[k]?.loans || 0) + 1, lastStatus: l.status };
  });
  items.forEach((u) => {
    delete u.mpinHash;
    u.loans = map[String(u._id)]?.loans || 0;
    u.lastStatus = map[String(u._id)]?.lastStatus || null;
  });
  ok(res, { items, total, page, pages: Math.ceil(total / limit) });
});

exports.userDetail = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) throw ApiError.notFound('User not found');
  const loans = await Loan.find({ user: user._id }).sort({ createdAt: -1 }).select('loanNumber status offer approved createdAt submittedAt').lean();
  ok(res, { user, loans });
});

exports.updateUser = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id).select('+mpinHash');
  if (!user) throw ApiError.notFound('User not found');
  if (req.body.status && ['active', 'blocked'].includes(req.body.status)) user.status = req.body.status;
  if (req.body.fullName !== undefined) user.fullName = req.body.fullName;
  if (req.body.email !== undefined) user.email = req.body.email;
  if (req.body.resetMpin) {
    if (!RX.mpin.test(String(req.body.resetMpin))) throw ApiError.badRequest('MPIN must be 4 digits');
    await user.setMpin(req.body.resetMpin);
    user.failedLogins = 0;
    user.lockUntil = undefined;
  }
  await user.save();
  ok(res, { user }, 'User updated');
});

/* ---------------------------------------------------------------- settings */

const EDITABLE = [
  'appName',
  'tagline',
  'companyName',
  'lendingPartner',
  'nbfcRegistration',
  'grievanceOfficer',
  'supportEmail',
  'supportPhone',
  'supportWhatsapp',
  'supportHours',
  'officeAddress',
  'termsUrl',
  'privacyUrl',
  'termsText',
  'privacyText',
  'minLoanAmount',
  'maxLoanAmount',
  'amountStep',
  'incomeMultiplier',
  'minMonthlyIncome',
  'minAge',
  'maxAge',
  'interestRate',
  'tenureOptions',
  'processingFeePercent',
  'minProcessingFee',
  'gstPercent',
  'latePaymentFeePerDay',
  'acceptingApplications',
  'repayment',
  'minAppVersion',
  'latestAppVersion',
  'apkUrl',
  'maintenanceMode',
  'maintenanceMessage',
  'options',
];

exports.getSettings = asyncHandler(async (_req, res) => ok(res, { settings: await Setting.get() }));

exports.updateSettings = asyncHandler(async (req, res) => {
  const s = await Setting.get();
  const body = pick(req.body, EDITABLE);
  if (body.tenureOptions) {
    body.tenureOptions = [...new Set(body.tenureOptions.map(Number).filter((n) => n > 0 && n <= 120))].sort((a, b) => a - b);
    if (!body.tenureOptions.length) throw ApiError.badRequest('Add at least one tenure option');
  }
  const min = body.minLoanAmount ?? s.minLoanAmount;
  const max = body.maxLoanAmount ?? s.maxLoanAmount;
  if (Number(min) <= 0 || Number(max) < Number(min)) throw ApiError.badRequest('Max loan amount must be greater than min amount');
  if (body.options) {
    const clean = {};
    Object.entries(body.options).forEach(([k, v]) => {
      if (Array.isArray(v)) clean[k] = v.map((x) => String(x).trim()).filter(Boolean);
    });
    body.options = { ...s.options, ...clean };
  }
  Object.entries(body).forEach(([k, v]) => s.set(k, v));
  if (body.options) s.markModified('options');
  await s.save();
  ok(res, { settings: s }, 'Settings saved');
});

/* ---------------------------------------------------------------- banners */

exports.listBanners = asyncHandler(async (req, res) => {
  const banners = await Banner.find().sort({ order: 1, createdAt: -1 }).lean();
  ok(res, { banners: banners.map((b) => bannerUrl(req, b)) });
});

const bannerFields = (body) => {
  const b = pick(body, ['title', 'subtitle', 'ctaText', 'ctaAction', 'link', 'bgColor', 'order', 'active']);
  if (b.order !== undefined) b.order = Number(b.order) || 0;
  if (b.active !== undefined) b.active = b.active === true || b.active === 'true';
  return b;
};

exports.createBanner = asyncHandler(async (req, res) => {
  const data = bannerFields(req.body);
  if (!data.title) {
    if (req.file) removeFile(PUBLIC_DIR, req.file.filename);
    throw ApiError.badRequest('Title is required');
  }
  if (req.file) data.image = req.file.filename;
  const banner = await Banner.create(data);
  ok(res, { banner: bannerUrl(req, banner.toObject()) }, 'Banner created', 201);
});

exports.updateBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findById(req.params.id);
  if (!banner) throw ApiError.notFound('Banner not found');
  Object.assign(banner, bannerFields(req.body));
  if (req.file) {
    removeFile(PUBLIC_DIR, banner.image);
    banner.image = req.file.filename;
  } else if (req.body.removeImage === 'true') {
    removeFile(PUBLIC_DIR, banner.image);
    banner.image = undefined;
  }
  await banner.save();
  ok(res, { banner: bannerUrl(req, banner.toObject()) }, 'Banner updated');
});

exports.deleteBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findByIdAndDelete(req.params.id);
  if (!banner) throw ApiError.notFound('Banner not found');
  removeFile(PUBLIC_DIR, banner.image);
  ok(res, {}, 'Banner deleted');
});

/* ---------------------------------------------------------------- notifications */

exports.listNotifications = asyncHandler(async (req, res) => {
  const { page, limit, skip } = paginate(req.query);
  const [items, total] = await Promise.all([
    Notification.find().sort({ createdAt: -1 }).skip(skip).limit(limit).populate('user', 'mobile fullName').lean(),
    Notification.countDocuments(),
  ]);
  items.forEach((n) => {
    n.reads = (n.readBy || []).length;
    delete n.readBy;
  });
  ok(res, { items, total, page, pages: Math.ceil(total / limit) });
});

exports.sendNotification = asyncHandler(async (req, res) => {
  const { title, body, type = 'info', mobile } = req.body;
  if (!title || !body) throw ApiError.badRequest('Title and message are required');
  let user = null;
  if (mobile) {
    user = await User.findOne({ mobile });
    if (!user) throw ApiError.notFound('No user with this mobile number');
  }
  const n = await Notification.create({ user: user ? user._id : null, title, body, type });
  ok(res, { notification: n }, user ? 'Notification sent' : 'Broadcast sent to all users', 201);
});

exports.deleteNotification = asyncHandler(async (req, res) => {
  await Notification.findByIdAndDelete(req.params.id);
  ok(res, {}, 'Deleted');
});
