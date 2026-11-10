const Setting = require('../models/Setting');
const Banner = require('../models/Banner');
const { asyncHandler, ok } = require('../utils/http');

/** Public settings sent to the mobile app (no secrets). */
const publicSettings = (s) => ({
  appName: s.appName,
  tagline: s.tagline,
  companyName: s.companyName,
  lendingPartner: s.lendingPartner,
  nbfcRegistration: s.nbfcRegistration,
  grievanceOfficer: s.grievanceOfficer,
  support: {
    email: s.supportEmail,
    phone: s.supportPhone,
    whatsapp: s.supportWhatsapp,
    hours: s.supportHours,
    address: s.officeAddress,
  },
  legal: { termsUrl: s.termsUrl, privacyUrl: s.privacyUrl, termsText: s.termsText, privacyText: s.privacyText },
  loan: {
    minAmount: s.minLoanAmount,
    maxAmount: s.maxLoanAmount,
    amountStep: s.amountStep,
    minMonthlyIncome: s.minMonthlyIncome,
    minAge: s.minAge,
    maxAge: s.maxAge,
    interestRate: s.interestRate,
    tenureOptions: s.tenureOptions,
    processingFeePercent: s.processingFeePercent,
    gstPercent: s.gstPercent,
    acceptingApplications: s.acceptingApplications,
  },
  repayment: s.repayment,
  app: {
    minVersion: s.minAppVersion,
    latestVersion: s.latestAppVersion,
    apkUrl: s.apkUrl,
    maintenanceMode: s.maintenanceMode,
    maintenanceMessage: s.maintenanceMessage,
  },
  options: s.options,
});

const bannerUrl = (req, b) => ({
  ...b,
  imageUrl: b.image ? `${req.protocol}://${req.get('host')}/uploads/public/${b.image}` : null,
});

exports.publicSettings = publicSettings;
exports.bannerUrl = bannerUrl;

exports.config = asyncHandler(async (req, res) => {
  const [s, banners] = await Promise.all([Setting.get(), Banner.find({ active: true }).sort({ order: 1, createdAt: -1 }).lean()]);
  ok(res, { settings: publicSettings(s), banners: banners.map((b) => bannerUrl(req, b)) });
});

exports.banners = asyncHandler(async (req, res) => {
  const banners = await Banner.find({ active: true }).sort({ order: 1, createdAt: -1 }).lean();
  ok(res, { banners: banners.map((b) => bannerUrl(req, b)) });
});
