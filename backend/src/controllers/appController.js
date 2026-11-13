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
  otpMode: s.otpMode,
  products: (s.loanProducts || [])
    .filter((p) => p.active !== false)
    .sort((a, b) => (a.order || 0) - (b.order || 0))
    .map((p) => ({
      key: p.key,
      name: p.name,
      tagline: p.tagline,
      icon: p.icon,
      color: p.color,
      minAmount: p.minAmount,
      maxAmount: p.maxAmount,
      interestRate: p.interestRate,
      tenureOptions: p.tenureOptions,
      processingFeePercent: p.processingFeePercent,
      minMonthlyIncome: p.minMonthlyIncome,
      incomeLabel: p.incomeLabel,
      detailsTitle: p.detailsTitle,
      reviewSteps: p.reviewSteps || [],
      minProcessingFee: p.minProcessingFee,
      steps: p.steps,
      fields: p.fields || [],
    })),
});

const bannerUrl = (req, b) => ({
  ...b,
  imageUrl: b.image ? `${req.protocol}://${req.get('host')}/uploads/public/${b.image}` : null,
});

exports.publicSettings = publicSettings;
exports.bannerUrl = bannerUrl;

const feePaymentPublic = (req, s) => {
  const f = s.feePayment || {};
  return {
    upiId: f.upiId || '',
    payeeName: f.payeeName || s.companyName,
    instructions: f.instructions || '',
    qrImageUrl: f.qrImage ? `${req.protocol}://${req.get('host')}/uploads/public/${f.qrImage}` : null,
    demo: !f.upiId && !f.qrImage,
  };
};
exports.feePaymentPublic = feePaymentPublic;

exports.config = asyncHandler(async (req, res) => {
  const [s, banners] = await Promise.all([Setting.get(), Banner.find({ active: true }).sort({ order: 1, createdAt: -1 }).lean()]);
  ok(res, { settings: { ...publicSettings(s), feePayment: feePaymentPublic(req, s) }, banners: banners.map((b) => bannerUrl(req, b)) });
});

exports.banners = asyncHandler(async (req, res) => {
  const banners = await Banner.find({ active: true }).sort({ order: 1, createdAt: -1 }).lean();
  ok(res, { banners: banners.map((b) => bannerUrl(req, b)) });
});
