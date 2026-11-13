const mongoose = require('mongoose');
const { DEFAULT_PRODUCTS } = require('../config/products');

/**
 * Single document (key = 'app') that drives the whole mobile app dynamically.
 * Everything here is editable from the admin panel.
 */

const DEFAULT_OPTIONS = {
  education: ['Below 10th', '10th Pass', '12th Pass', 'Diploma', 'Graduate', 'Post Graduate', 'Doctorate'],
  maritalStatus: ['Single', 'Married', 'Divorced', 'Widowed'],
  employmentType: ['Salaried', 'Self Employed - Business', 'Self Employed - Professional'],
  salaryMode: ['Bank Transfer', 'Cheque', 'Cash'],
  gender: ['Male', 'Female', 'Other'],
  loanPurpose: [
    'Travel / Vacation',
    'Marriage',
    'Functions at Home',
    'Old home renovation',
    'Furniture for home',
    'Household Expenses',
    'Car Purchase',
    'Two Wheeler Purchase',
    'Education',
    'Business Expense',
    'Medical Expense',
    'Loan Consolidation',
    'Electronics Purchase',
    'Working Capital',
    'Equipment/Material Purchase',
    'Business Expansion',
    'Inventory Purchase',
    'Marketing Expense',
    'Other Personal',
  ],
  language: ['English', 'Hindi', 'Marathi', 'Gujarati', 'Bengali', 'Tamil', 'Telugu', 'Kannada', 'Malayalam'],
  sector: ['Private Limited', 'Public Limited', 'Government / PSU', 'Partnership / LLP', 'Proprietorship', 'MNC', 'Startup', 'NGO / Trust'],
  industryType: [
    'IT / Software',
    'BPO / KPO',
    'Banking / Finance / Insurance',
    'Manufacturing',
    'Retail / E-commerce',
    'Healthcare / Pharma',
    'Education',
    'Hospitality / Travel',
    'Logistics / Transport',
    'Construction / Real Estate',
    'Media / Entertainment',
    'Telecom',
    'Government',
    'Others',
  ],
  natureOfWork: [
    'Back-Office Processing Staff',
    'Video Editor',
    'Graphic Designer / Animation',
    'Content Writing / Copywriting / Proofreading',
    'Digital Marketing',
    'Software Developer',
    'QA - IT',
    'QA - Non-IT',
    'Credit Analyst',
    'Market Research Analyst',
    'Business Analyst',
    'Finance Analyst',
    'Legal Assistant',
    'Professor / Teacher / Educator',
    'Housekeeping / Cleaning',
    'Sales Executive',
    'Account Manager / Relationship Manager',
    'Doctor',
    'Police / Defence Personnel',
    'Government Employee',
    'Frontdesk / Receptionist',
    'Warehouse / Packaging executive',
    'Factory / Plant worker',
    'Others',
  ],
  residenceType: ['Owned house', 'Rented house'],
  accountType: ['Savings', 'Current'],
};

const settingSchema = new mongoose.Schema(
  {
    key: { type: String, unique: true, default: 'app' },

    // Branding / company
    appName: { type: String, default: 'Credit Ventures' },
    tagline: { type: String, default: 'Instant personal loans, made simple' },
    companyName: { type: String, default: 'Credit Ventures Pvt. Ltd.' },
    lendingPartner: { type: String, default: '' }, // RBI registered NBFC / bank partner name
    nbfcRegistration: { type: String, default: '' },
    grievanceOfficer: {
      name: { type: String, default: '' },
      email: { type: String, default: '' },
      phone: { type: String, default: '' },
    },
    supportEmail: { type: String, default: 'support@creditventures.in' },
    supportPhone: { type: String, default: '+91 90000 00000' },
    supportWhatsapp: { type: String, default: '' },
    supportHours: { type: String, default: 'Mon - Sat, 10:00 AM - 7:00 PM' },
    officeAddress: { type: String, default: '' },
    termsUrl: { type: String, default: '' },
    privacyUrl: { type: String, default: '' },
    termsText: { type: String, default: '' },
    privacyText: { type: String, default: '' },

    // Loan product configuration
    minLoanAmount: { type: Number, default: 5000 },
    maxLoanAmount: { type: Number, default: 200000 },
    amountStep: { type: Number, default: 1000 },
    incomeMultiplier: { type: Number, default: 0.5 }, // max loan = income * multiplier
    minMonthlyIncome: { type: Number, default: 15000 },
    minAge: { type: Number, default: 21 },
    maxAge: { type: Number, default: 58 },
    interestRate: { type: Number, default: 30 }, // annual %, reducing balance
    tenureOptions: { type: [Number], default: [3, 4, 6, 9, 12] },
    processingFeePercent: { type: Number, default: 5 },
    minProcessingFee: { type: Number, default: 499 },
    gstPercent: { type: Number, default: 18 },
    latePaymentFeePerDay: { type: Number, default: 0 },
    acceptingApplications: { type: Boolean, default: true },

    // Manual repayment instructions (no payment gateway)
    repayment: {
      accountName: { type: String, default: 'Credit Ventures Pvt. Ltd.' },
      accountNumber: { type: String, default: '' },
      ifsc: { type: String, default: '' },
      bankName: { type: String, default: '' },
      upiId: { type: String, default: '' },
      instructions: {
        type: String,
        default: 'Pay your EMI via UPI / NEFT / IMPS to the account below and upload the payment screenshot with UTR number.',
      },
    },

    // App behaviour
    minAppVersion: { type: String, default: '1.0.0' },
    latestAppVersion: { type: String, default: '1.0.0' },
    apkUrl: { type: String, default: '' },
    maintenanceMode: { type: Boolean, default: false },
    maintenanceMessage: { type: String, default: 'We are upgrading our systems. Please check back shortly.' },

    // Processing fee collection (customer pays by scanning a UPI QR in the app before disbursal)
    feePayment: {
      upiId: { type: String, default: '' }, // empty = demo QR
      payeeName: { type: String, default: 'Credit Ventures Pvt. Ltd.' },
      qrImage: { type: String, default: '' }, // optional uploaded QR image (uploads/public)
      instructions: {
        type: String,
        default: 'Scan the QR with any UPI app (GPay, PhonePe, Paytm), pay the exact processing fee and upload the payment screenshot with the UTR number.',
      },
    },

    // Login OTP: 'demo' shows the OTP on screen (no SMS cost), 'sms' sends it via SMS_PROVIDER
    otpMode: { type: String, enum: ['demo', 'sms'], default: 'demo' },

    // Loan categories (personal, business, home, gold, vehicle, education)
    loanProducts: {
      type: mongoose.Schema.Types.Mixed,
      default: () => JSON.parse(JSON.stringify(DEFAULT_PRODUCTS)),
    },

    options: {
      type: mongoose.Schema.Types.Mixed,
      default: () => JSON.parse(JSON.stringify(DEFAULT_OPTIONS)),
    },
  },
  { timestamps: true, minimize: false }
);

settingSchema.statics.get = async function get() {
  let s = await this.findOne({ key: 'app' });
  if (!s) s = await this.create({ key: 'app' });
  // make sure new option groups added in code reach old documents
  const opts = { ...DEFAULT_OPTIONS, ...(s.options || {}) };
  let dirty = false;
  if (JSON.stringify(opts) !== JSON.stringify(s.options)) {
    s.options = opts;
    s.markModified('options');
    dirty = true;
  }
  // add products introduced in code without overwriting admin edits
  const current = Array.isArray(s.loanProducts) ? s.loanProducts : [];
  const missing = DEFAULT_PRODUCTS.filter((d) => !current.some((p) => p.key === d.key));
  if (missing.length || !Array.isArray(s.loanProducts)) {
    s.loanProducts = [...current, ...JSON.parse(JSON.stringify(missing))];
    s.markModified('loanProducts');
    dirty = true;
  }
  const defaultsByKey = Object.fromEntries(DEFAULT_PRODUCTS.map((d) => [d.key, d]));
  (s.loanProducts || []).forEach((p) => {
    const d = defaultsByKey[p.key];
    if (!Array.isArray(p.reviewSteps)) {
      p.reviewSteps = d ? [...d.reviewSteps] : ['Document verification', 'Credit check'];
      dirty = true;
    }
    if (p.minProcessingFee === undefined) {
      p.minProcessingFee = d ? d.minProcessingFee : 0;
      dirty = true;
    }
  });
  if (dirty) {
    s.markModified('loanProducts');
    await s.save();
  }
  return s;
};

settingSchema.statics.DEFAULT_OPTIONS = DEFAULT_OPTIONS;

/** Product by key (falls back to personal). */
settingSchema.methods.product = function product(key) {
  const list = this.loanProducts || [];
  return list.find((p) => p.key === key) || list.find((p) => p.key === 'personal') || DEFAULT_PRODUCTS[0];
};

/**
 * Settings object with the product's pricing applied, used by the EMI / eligibility maths.
 */
settingSchema.methods.forProduct = function forProduct(key) {
  const p = this.product(key);
  const base = this.toObject();
  return {
    ...base,
    minLoanAmount: p.minAmount ?? base.minLoanAmount,
    maxLoanAmount: p.maxAmount ?? base.maxLoanAmount,
    amountStep: p.amountStep ?? base.amountStep,
    incomeMultiplier: p.incomeMultiplier ?? base.incomeMultiplier,
    minMonthlyIncome: p.minMonthlyIncome ?? base.minMonthlyIncome,
    interestRate: p.interestRate ?? base.interestRate,
    tenureOptions: Array.isArray(p.tenureOptions) && p.tenureOptions.length ? p.tenureOptions : base.tenureOptions,
    processingFeePercent: p.processingFeePercent ?? base.processingFeePercent,
    minProcessingFee: p.minProcessingFee ?? base.minProcessingFee,
  };
};

module.exports = mongoose.model('Setting', settingSchema);
