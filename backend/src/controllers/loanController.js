const Loan = require('../models/Loan');
const Payment = require('../models/Payment');
const Setting = require('../models/Setting');
const { ApiError, asyncHandler, ok, pick } = require('../utils/http');
const { RX, validate, isValidAadhaar, maskAadhaar, ageFrom } = require('../utils/validators');
const { buildQuote, eligibleRange } = require('../utils/emi');
const { fileMeta, removeFile, PRIVATE_DIR } = require('../middleware/upload');

/** Move currentStep forward (never backwards) after `completedStep` is saved. */
const advance = (loan, completedStep) => {
  const steps = loan.stepList();
  const idx = (st) => (st === 'done' ? steps.length : Math.max(0, steps.indexOf(st)));
  const next = steps[steps.indexOf(completedStep) + 1] || 'review';
  if (idx(next) > idx(loan.currentStep)) loan.currentStep = next;
};

const forUser = (loan) => {
  const o = loan.toJSON ? loan.toJSON() : loan;
  if (o.kyc?.aadhaarNumber) o.kyc.aadhaarNumber = maskAadhaar(o.kyc.aadhaarNumber);
  delete o.assignedTo;
  delete o.adminRemarks;
  return o;
};

const getDraft = async (userId) => {
  const loan = await Loan.findOne({ user: userId, status: 'draft' }).sort({ createdAt: -1 });
  if (!loan) throw ApiError.notFound('No application in progress. Please start a new application.');
  return loan;
};

const offerFor = (loan, settings) => {
  settings = settings.forProduct ? settings.forProduct(loan.product) : settings;
  const range = eligibleRange(loan.basic.monthlyIncome, settings);
  const tenures = settings.tenureOptions.map((m) => {
    const q = buildQuote(loan.offer?.amount || range.max, m, settings);
    return { months: m, emi: q.emi, totalPayable: q.totalPayable };
  });
  return { range, tenures };
};

/* ---------------------------------------------------------------- reads */

exports.current = asyncHandler(async (req, res) => {
  const loan = await Loan.findOne({ user: req.user._id, status: { $in: Loan.ACTIVE_STATUSES } }).sort({ createdAt: -1 });
  ok(res, { loan: loan ? forUser(loan) : null });
});

exports.list = asyncHandler(async (req, res) => {
  const loans = await Loan.find({ user: req.user._id, status: { $ne: 'draft' } })
    .sort({ createdAt: -1 })
    .select('loanNumber status product productName offer approved disbursal createdAt submittedAt closedAt');
  ok(res, { loans });
});

exports.detail = asyncHandler(async (req, res) => {
  const loan = await Loan.findOne({ _id: req.params.id, user: req.user._id });
  if (!loan) throw ApiError.notFound('Loan not found');
  const payments = await Payment.find({ loan: loan._id }).sort({ createdAt: -1 }).lean();
  ok(res, { loan: forUser(loan), payments });
});

/* ---------------------------------------------------------------- step 1: basic + eligibility */

exports.saveBasic = asyncHandler(async (req, res) => {
  const settings = await Setting.get();
  if (!settings.acceptingApplications) throw ApiError.badRequest('We are not accepting new applications right now. Please try later.');
  const b = req.body;
  validate(b, {
    firstName: { required: true, label: 'First name', rx: /^[A-Za-z][A-Za-z .'-]{0,49}$/, msg: 'Enter first name as per PAN' },
    lastName: { required: true, label: 'Last name', rx: /^[A-Za-z][A-Za-z .'-]{0,49}$/, msg: 'Enter last name as per PAN' },
    dob: { required: true, label: 'Date of birth' },
    gender: { required: true, label: 'Gender', oneOf: ['male', 'female', 'other'] },
    email: { required: true, label: 'Email', rx: RX.email },
    education: { required: true, label: 'Education' },
    maritalStatus: { required: true, label: 'Marital status' },
    employmentType: { required: true, label: 'Employment type' },
    monthlyIncome: { required: true, label: 'Monthly income', min: 1, max: 10000000 },
    salaryMode: { required: true, label: 'Salary mode' },
    preferredAmount: { label: 'Preferred loan amount', min: 0, max: 100000000 },
  });
  const consents = b.consents || {};
  if (!consents.creditBureau || !consents.ckyc) {
    throw ApiError.badRequest('Please accept the credit bureau and CKYC consent to check your offer');
  }

  const age = ageFrom(b.dob);
  if (age === null) throw ApiError.badRequest('Invalid date of birth');

  const existing = await Loan.findOne({ user: req.user._id, status: { $in: Loan.ACTIVE_STATUSES } }).sort({ createdAt: -1 });
  if (existing && existing.status !== 'draft') {
    throw ApiError.conflict(`You already have an active application (${existing.loanNumber}).`);
  }
  const loan = existing || new Loan({ user: req.user._id, status: 'draft', currentStep: 'basic' });

  // loan category
  const productKey = String(b.product || loan.product || 'personal');
  const product = (settings.loanProducts || []).find((p) => p.key === productKey);
  if (!product || product.active === false) throw ApiError.badRequest('This loan type is not available right now');
  if (loan.product !== productKey || !loan.steps || !loan.steps.length) {
    if (existing && loan.product && loan.product !== productKey) {
      loan.offer = undefined;
      loan.productDetails = undefined;
      loan.currentStep = 'basic';
      loan.addHistory('draft', 'user', `Switched to ${product.name}`);
    }
    loan.product = productKey;
    loan.productName = product.name;
    loan.steps = product.steps && product.steps.length ? product.steps : Loan.DEFAULT_STEPS;
  }
  const s = settings.forProduct(productKey);

  loan.basic = {
    ...pick(b, ['firstName', 'lastName', 'gender', 'education', 'maritalStatus', 'employmentType', 'salaryMode']),
    firstName: String(b.firstName).trim(),
    lastName: String(b.lastName).trim(),
    email: String(b.email).trim().toLowerCase(),
    dob: new Date(b.dob),
    monthlyIncome: Number(b.monthlyIncome),
    preferredAmount: b.preferredAmount ? Number(b.preferredAmount) : undefined,
    consents: {
      creditBureau: true,
      ckyc: true,
      incomeDeclaration: !!consents.incomeDeclaration,
      disabilityDeclaration: !!consents.disabilityDeclaration,
      acceptedAt: new Date(),
    },
  };

  // eligibility rules
  const reasons = [];
  if (age < s.minAge || age > s.maxAge) reasons.push(`Applicant age must be between ${s.minAge} and ${s.maxAge} years`);
  if (loan.basic.monthlyIncome < s.minMonthlyIncome) reasons.push(`Minimum monthly income required is ₹${s.minMonthlyIncome.toLocaleString('en-IN')}`);
  const range = eligibleRange(loan.basic.monthlyIncome, s);
  if (range.max < range.min) reasons.push('Your income does not qualify for the minimum loan amount yet');

  if (!req.user.fullName) {
    req.user.fullName = `${loan.basic.firstName} ${loan.basic.lastName}`;
    req.user.email = req.user.email || loan.basic.email;
    await req.user.save();
  }

  if (reasons.length) {
    loan.addHistory('draft', 'system', `Not eligible: ${reasons.join('; ')}`);
    await loan.save();
    return ok(res, { eligible: false, reasons, loan: forUser(loan) }, reasons[0]);
  }

  const preferred = loan.basic.preferredAmount;
  const amount = preferred ? Math.min(range.max, Math.max(range.min, Math.round(preferred / range.step) * range.step)) : range.max;
  const q = buildQuote(amount, s.tenureOptions[0], s);
  loan.offer = { ...q, minAmount: range.min, maxAmount: range.max };
  if (!existing) loan.addHistory('draft', 'user', `${product.name} application started`);
  advance(loan, 'basic');
  await loan.save();
  ok(res, { eligible: true, loan: forUser(loan), offer: offerFor(loan, settings) }, 'Congratulations! You have a pre-approved offer');
});

/* ---------------------------------------------------------------- step 2: choose offer */

exports.quote = asyncHandler(async (req, res) => {
  const settings = await Setting.get();
  let productKey = req.query.product;
  if (!productKey) {
    const draft = await Loan.findOne({ user: req.user._id, status: 'draft' }).select('product').lean();
    productKey = draft?.product || 'personal';
  }
  const s = settings.forProduct(productKey);
  const amount = Number(req.query.amount || req.body.amount);
  const tenure = Number(req.query.tenure || req.body.tenure || s.tenureOptions[0]);
  if (!amount) throw ApiError.badRequest('Amount is required');
  const tenures = s.tenureOptions.map((m) => {
    const q = buildQuote(amount, m, s);
    return { months: m, emi: q.emi, totalPayable: q.totalPayable };
  });
  ok(res, { quote: buildQuote(amount, tenure, s), tenures });
});

exports.saveOffer = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  const s = (await Setting.get()).forProduct(loan.product);
  if (!loan.offer?.maxAmount) throw ApiError.badRequest('Please complete basic details first');
  const amount = Number(req.body.amount);
  const tenure = Number(req.body.tenureMonths);
  if (!amount || amount < loan.offer.minAmount || amount > loan.offer.maxAmount) {
    throw ApiError.badRequest(`Choose an amount between ₹${loan.offer.minAmount} and ₹${loan.offer.maxAmount}`);
  }
  if (!s.tenureOptions.includes(tenure)) throw ApiError.badRequest('Please choose a valid tenure');
  const q = buildQuote(amount, tenure, s);
  loan.offer = { ...loan.offer.toObject(), ...q, promoCode: req.body.promoCode ? String(req.body.promoCode).trim().slice(0, 30) : undefined };
  advance(loan, 'offer');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Offer selected');
});

/* ---------------------------------------------------------------- step 3: personal */

exports.savePersonal = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  validate(req.body, {
    fatherName: { required: true, label: "Father's name", rx: /^[A-Za-z][A-Za-z .'-]{1,59}$/ },
    motherName: { required: true, label: "Mother's name", rx: /^[A-Za-z][A-Za-z .'-]{1,59}$/ },
    residenceType: { required: true, label: 'Residence type', oneOf: ['owned', 'rented', 'family', 'pg'] },
    purpose: { required: true, label: 'Purpose of loan' },
    language: { required: true, label: 'Language preference' },
  });
  if (!req.body.pepDeclaration) throw ApiError.badRequest('Please confirm the politically exposed person declaration');
  loan.personal = pick(req.body, ['fatherName', 'motherName', 'residenceType', 'purpose', 'language']);
  loan.personal.pepDeclaration = true;
  advance(loan, 'personal');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Saved');
});

/* ---------------------------------------------------------------- category specific details */

exports.saveProductDetails = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  const product = (await Setting.get()).product(loan.product);
  const fields = product.fields || [];
  if (!fields.length) throw ApiError.badRequest('No extra details needed for this loan type');
  const out = {};
  const errors = {};
  for (const f of fields) {
    let v = req.body[f.key];
    if (typeof v === 'string') v = v.trim();
    const empty = v === undefined || v === null || v === '';
    if (empty) {
      if (f.required) errors[f.key] = `${f.label.replace(/\s*\(.*\)$/, '')} is required`;
      continue;
    }
    if (f.type === 'number') {
      const n = Number(v);
      if (!Number.isFinite(n) || n < 0) {
        errors[f.key] = `Enter a valid ${f.label}`;
        continue;
      }
      v = n;
    } else if (f.type === 'pincode') {
      if (!RX.pincode.test(String(v))) errors[f.key] = 'Enter a valid 6 digit PIN code';
    } else if (f.type === 'select') {
      if (Array.isArray(f.options) && f.options.length && !f.options.includes(v)) errors[f.key] = `Please select a valid ${f.label}`;
    } else {
      v = String(v).slice(0, 200);
      if (f.pattern && !new RegExp(f.pattern).test(String(v).toUpperCase())) errors[f.key] = f.patternMsg || `Invalid ${f.label}`;
      if (f.pattern) v = String(v).toUpperCase();
    }
    out[f.key] = v;
  }
  const keys = Object.keys(errors);
  if (keys.length) throw ApiError.badRequest(errors[keys[0]], errors);
  loan.productDetails = out;
  loan.markModified('productDetails');
  loan.verification.product = false;
  advance(loan, 'product');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Saved');
});

/* ---------------------------------------------------------------- step 4: employment */

exports.saveEmployment = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  validate(req.body, {
    companyName: { required: true, label: 'Company name' },
    sector: { required: true, label: 'Sector' },
    industryType: { required: true, label: 'Industry type' },
    natureOfWork: { required: true, label: 'Nature of work' },
    companyAddress: { required: true, label: 'Company address' },
    companyPincode: { required: true, label: 'PIN code', rx: RX.pincode, msg: 'Enter a valid 6 digit PIN code' },
    officeEmail: { label: 'Office email', rx: RX.email },
    workExperienceMonths: { label: 'Work experience', min: 0, max: 600 },
  });
  loan.employment = pick(req.body, [
    'companyName',
    'sector',
    'industryType',
    'natureOfWork',
    'designation',
    'officeEmail',
    'companyAddress',
    'companyPincode',
    'workExperienceMonths',
  ]);
  advance(loan, 'employment');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Saved');
});

/* ---------------------------------------------------------------- step 5: address */

exports.saveAddress = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  validate(req.body, {
    line1: { required: true, label: 'House / Flat / Street' },
    city: { required: true, label: 'City' },
    state: { required: true, label: 'State' },
    pincode: { required: true, label: 'PIN code', rx: RX.pincode, msg: 'Enter a valid 6 digit PIN code' },
  });
  const same = req.body.sameAsPermanent !== false && req.body.sameAsPermanent !== 'false';
  if (!same && !req.body.permanentAddress) throw ApiError.badRequest('Permanent address is required');
  loan.address = {
    ...pick(req.body, ['line1', 'line2', 'landmark', 'city', 'state', 'pincode', 'yearsAtAddress', 'permanentAddress']),
    sameAsPermanent: same,
  };
  advance(loan, 'address');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Saved');
});

/* ---------------------------------------------------------------- step 6: KYC (manual documents) */

const KYC_FILES = ['aadhaarFront', 'aadhaarBack', 'panCard', 'selfie', 'salarySlip'];

exports.saveKyc = asyncHandler(async (req, res) => {
  const files = req.files || {};
  const cleanup = () => Object.values(files).flat().forEach((f) => removeFile(PRIVATE_DIR, f.filename));
  try {
    const loan = await getDraft(req.user._id);
    const body = { ...req.body };
    if (body.panNumber) body.panNumber = String(body.panNumber).toUpperCase().trim();
    if (body.aadhaarNumber) body.aadhaarNumber = String(body.aadhaarNumber).replace(/\s/g, '');

    const prev = loan.kyc || {};
    const needAadhaar = !prev.aadhaarNumber || body.aadhaarNumber;
    validate(body, {
      aadhaarNumber: { required: !prev.aadhaarNumber, label: 'Aadhaar number', test: isValidAadhaar, msg: 'Enter a valid 12 digit Aadhaar number' },
      panNumber: { required: !prev.panNumber, label: 'PAN number', rx: RX.pan, msg: 'Enter a valid PAN (e.g. ABCDE1234F)' },
    });

    const required = ['aadhaarFront', 'aadhaarBack', 'panCard', 'selfie'];
    const missing = required.filter((f) => !(files[f] && files[f][0]) && !(prev[f] && prev[f].filename));
    if (missing.length) throw ApiError.badRequest(`Please upload: ${missing.join(', ')}`);

    const kyc = prev.toObject ? prev.toObject() : { ...prev };
    if (needAadhaar && body.aadhaarNumber) kyc.aadhaarNumber = body.aadhaarNumber;
    if (body.panNumber) kyc.panNumber = body.panNumber;
    KYC_FILES.forEach((f) => {
      if (files[f] && files[f][0]) {
        if (kyc[f]?.filename) removeFile(PRIVATE_DIR, kyc[f].filename);
        kyc[f] = fileMeta(files[f][0]);
      }
    });
    loan.kyc = kyc;
    loan.verification.kyc = false;
    advance(loan, 'kyc');
    await loan.save();
    ok(res, { loan: forUser(loan) }, 'Documents uploaded');
  } catch (e) {
    cleanup();
    throw e;
  }
});

/* ---------------------------------------------------------------- step 7: bank (manual) */

exports.saveBank = asyncHandler(async (req, res) => {
  const proof = req.file;
  try {
    const loan = await getDraft(req.user._id);
    const body = { ...req.body };
    if (body.ifsc) body.ifsc = String(body.ifsc).toUpperCase().trim();
    if (body.accountNumber) body.accountNumber = String(body.accountNumber).replace(/\s/g, '');
    if (body.confirmAccountNumber) body.confirmAccountNumber = String(body.confirmAccountNumber).replace(/\s/g, '');
    validate(body, {
      accountHolderName: { required: true, label: 'Account holder name' },
      accountNumber: { required: true, label: 'Account number', rx: RX.accountNumber, msg: 'Account number must be 9 to 18 digits' },
      ifsc: { required: true, label: 'IFSC', rx: RX.ifsc, msg: 'Enter a valid IFSC (e.g. SBIN0001234)' },
      bankName: { required: true, label: 'Bank name' },
      accountType: { required: true, label: 'Account type', oneOf: ['savings', 'current'] },
    });
    if (body.confirmAccountNumber !== undefined && body.confirmAccountNumber !== body.accountNumber) {
      throw ApiError.badRequest('Account numbers do not match');
    }
    const prevProof = loan.bank?.bankProof; // bank proof upload is optional

    loan.bank = {
      ...pick(body, ['accountHolderName', 'accountNumber', 'ifsc', 'bankName', 'branch', 'accountType']),
      autoDebitConsent: body.autoDebitConsent === true || body.autoDebitConsent === 'true',
      bankProof: proof ? fileMeta(proof) : prevProof,
    };
    if (proof && prevProof?.filename) removeFile(PRIVATE_DIR, prevProof.filename);
    loan.verification.bank = false;
    advance(loan, 'bank');
    await loan.save();
    ok(res, { loan: forUser(loan) }, 'Bank details saved');
  } catch (e) {
    if (proof) removeFile(PRIVATE_DIR, proof.filename);
    throw e;
  }
});

/* ---------------------------------------------------------------- step 8: sign & submit */

exports.submit = asyncHandler(async (req, res) => {
  const loan = await getDraft(req.user._id);
  const { agreementAccepted, signatureName } = req.body;
  const missing = [];
  if (!loan.basic?.firstName) missing.push('basic details');
  if (!loan.offer?.amount || !loan.offer?.tenureMonths) missing.push('loan offer');
  const steps = loan.stepList();
  if (!loan.personal?.fatherName) missing.push('personal details');
  if (steps.includes('product') && !loan.productDetails) missing.push('loan details');
  if (steps.includes('employment') && !loan.employment?.companyName) missing.push('company details');
  if (!loan.address?.line1) missing.push('address');
  if (!loan.kyc?.panCard?.filename) missing.push('KYC documents');
  if (!loan.bank?.accountNumber) missing.push('bank details');
  if (missing.length) throw ApiError.badRequest(`Please complete: ${missing.join(', ')}`);
  if (!agreementAccepted) throw ApiError.badRequest('Please accept the loan agreement');
  const expected = `${loan.basic.firstName} ${loan.basic.lastName}`.trim().toLowerCase().replace(/\s+/g, ' ');
  if (!signatureName || String(signatureName).trim().toLowerCase().replace(/\s+/g, ' ') !== expected) {
    throw ApiError.badRequest(`Type your full name "${loan.basic.firstName} ${loan.basic.lastName}" to sign`);
  }

  loan.agreement = {
    accepted: true,
    signatureName: String(signatureName).trim(),
    acceptedAt: new Date(),
    ip: req.ip,
    device: req.get('user-agent'),
  };
  loan.status = 'submitted';
  loan.currentStep = 'done';
  loan.submittedAt = new Date();
  loan.stage = 0;
  loan.stageNote = 'We have received your application';
  loan.stageUpdatedAt = new Date();
  loan.addHistory('submitted', 'user', 'Application submitted');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Application submitted successfully');
});

exports.cancel = asyncHandler(async (req, res) => {
  const loan = await Loan.findOne({ _id: req.params.id, user: req.user._id });
  if (!loan) throw ApiError.notFound('Loan not found');
  if (!['draft', 'submitted'].includes(loan.status)) throw ApiError.badRequest('This application can no longer be cancelled');
  loan.status = 'cancelled';
  loan.addHistory('cancelled', 'user', req.body.reason || 'Cancelled by user');
  await loan.save();
  ok(res, { loan: forUser(loan) }, 'Application cancelled');
});

/* ---------------------------------------------------------------- Key Fact Statement acceptance (after approval) */

exports.acceptTerms = asyncHandler(async (req, res) => {
  const loan = await Loan.findOne({ _id: req.params.id, user: req.user._id });
  if (!loan) throw ApiError.notFound('Loan not found');
  if (loan.status !== 'approved' || !loan.approved?.amount) throw ApiError.badRequest('There are no approved terms to accept');
  if (!loan.approved.termsAcceptedAt) {
    loan.approved.termsAcceptedAt = new Date();
    loan.approved.termsAcceptedIp = req.ip;
    loan.addHistory('approved', 'user', 'Key Fact Statement accepted');
    await loan.save();
  }
  ok(res, { loan: forUser(loan) }, 'Terms accepted');
});

/* ---------------------------------------------------------------- processing fee (QR payment after approval) */

exports.submitFeePayment = asyncHandler(async (req, res) => {
  const proof = req.file;
  try {
    const loan = await Loan.findOne({ _id: req.params.id, user: req.user._id });
    if (!loan) throw ApiError.notFound('Loan not found');
    const fp = loan.feePayment || {};
    if (loan.status !== 'approved' || !fp.required) throw ApiError.badRequest('No processing fee is due on this loan');
    if (!['unpaid', 'rejected'].includes(fp.status)) throw ApiError.badRequest('Your payment is already submitted for verification');
    if (!loan.approved?.termsAcceptedAt) throw ApiError.badRequest('Please review and accept the Key Fact Statement first');
    validate(req.body, {
      utr: { required: true, label: 'UTR / Transaction ID', rx: /^[A-Za-z0-9]{6,30}$/, msg: 'Enter a valid UTR / transaction ID' },
    });
    if (!proof) throw ApiError.badRequest('Please upload the payment screenshot');
    const utr = String(req.body.utr).toUpperCase();
    const dupFee = await Loan.exists({ _id: { $ne: loan._id }, 'feePayment.utr': utr, 'feePayment.status': { $in: ['submitted', 'verified'] } });
    const dupEmi = await Payment.exists({ utr, status: { $ne: 'rejected' } });
    if (dupFee || dupEmi) throw ApiError.conflict('This UTR has already been used');
    if (fp.proof?.filename) removeFile(PRIVATE_DIR, fp.proof.filename);
    loan.feePayment = {
      ...(fp.toObject ? fp.toObject() : fp),
      status: 'submitted',
      utr,
      mode: req.body.mode || 'upi',
      proof: fileMeta(proof),
      submittedAt: new Date(),
      remarks: undefined,
    };
    loan.addHistory('approved', 'user', `Processing fee paid, UTR ${utr}`);
    await loan.save();
    ok(res, { loan: forUser(loan) }, 'Payment submitted. We will verify it shortly.');
  } catch (e) {
    if (proof) removeFile(PRIVATE_DIR, proof.filename);
    throw e;
  }
});

/* ---------------------------------------------------------------- repayments (manual) */

exports.submitPayment = asyncHandler(async (req, res) => {
  const proof = req.file;
  try {
    const loan = await Loan.findOne({ _id: req.params.id, user: req.user._id });
    if (!loan) throw ApiError.notFound('Loan not found');
    if (loan.status !== 'disbursed') throw ApiError.badRequest('Payments can be made only on an active (disbursed) loan');
    validate(req.body, {
      amount: { required: true, label: 'Amount', min: 1 },
      utr: { required: true, label: 'UTR / Transaction ID', rx: /^[A-Za-z0-9]{6,30}$/, msg: 'Enter a valid UTR / transaction ID' },
    });
    if (!proof) throw ApiError.badRequest('Please upload the payment screenshot');
    const installmentNo = req.body.installmentNo ? Number(req.body.installmentNo) : undefined;
    if (installmentNo && !loan.schedule.some((i) => i.installmentNo === installmentNo)) {
      throw ApiError.badRequest('Invalid installment');
    }
    const dup = await Payment.exists({ utr: req.body.utr, status: { $ne: 'rejected' } });
    if (dup) throw ApiError.conflict('This UTR has already been submitted');
    const payment = await Payment.create({
      loan: loan._id,
      user: req.user._id,
      installmentNo,
      amount: Number(req.body.amount),
      mode: req.body.mode || 'upi',
      utr: req.body.utr,
      proof: fileMeta(proof),
    });
    ok(res, { payment }, 'Payment submitted for verification', 201);
  } catch (e) {
    if (proof) removeFile(PRIVATE_DIR, proof.filename);
    throw e;
  }
});
