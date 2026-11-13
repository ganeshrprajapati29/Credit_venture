const Loan = require('../../models/Loan');
const Payment = require('../../models/Payment');
const Notification = require('../../models/Notification');
const Setting = require('../../models/Setting');
const { ApiError, asyncHandler, ok, escapeRegex, paginate } = require('../../utils/http');
const { buildQuote, buildSchedule } = require('../../utils/emi');
const { RX } = require('../../utils/validators');

const notify = (user, title, body, type = 'loan') => Notification.create({ user, title, body, type }).catch(() => {});

const fmt = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`;

/* -------------------------------------------------------------- dashboard */

exports.dashboard = asyncHandler(async (_req, res) => {
  const User = require('../../models/User');
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const days = 14;
  const since = new Date(startOfDay);
  since.setDate(since.getDate() - (days - 1));

  const [byStatus, users, usersToday, pendingPayments, disbursedAgg, collectedAgg, overdueAgg, trend, recent] = await Promise.all([
    Loan.aggregate([{ $group: { _id: '$status', count: { $sum: 1 } } }]),
    User.countDocuments(),
    User.countDocuments({ createdAt: { $gte: startOfDay } }),
    Payment.countDocuments({ status: 'pending' }).then(async (n) => ({ emi: n, fee: await Loan.countDocuments({ status: 'approved', 'feePayment.status': 'submitted' }) })),
    Loan.aggregate([{ $match: { status: { $in: ['disbursed', 'closed'] } } }, { $group: { _id: null, amount: { $sum: '$disbursal.amount' }, principal: { $sum: '$approved.amount' } } }]),
    Payment.aggregate([{ $match: { status: 'verified' } }, { $group: { _id: null, amount: { $sum: '$amount' } } }]),
    Loan.aggregate([
      { $match: { status: 'disbursed' } },
      { $unwind: '$schedule' },
      { $match: { 'schedule.status': { $ne: 'paid' }, 'schedule.dueDate': { $lt: new Date() } } },
      { $group: { _id: null, count: { $sum: 1 }, amount: { $sum: '$schedule.amount' } } },
    ]),
    Loan.find({ submittedAt: { $gte: since } }).select('submittedAt offer.amount').lean(),
    Loan.find({ status: { $ne: 'draft' } })
      .sort({ updatedAt: -1 })
      .limit(8)
      .select('loanNumber status basic.firstName basic.lastName offer.amount updatedAt')
      .lean(),
  ]);

  const statusCounts = Object.fromEntries(Loan.STATUSES.map((s) => [s, 0]));
  byStatus.forEach((s) => {
    statusCounts[s._id] = s.count;
  });
  const trendMap = {};
  trend.forEach((l) => {
    const k = new Date(l.submittedAt).toISOString().slice(0, 10);
    trendMap[k] = trendMap[k] || { count: 0, amount: 0 };
    trendMap[k].count += 1;
    trendMap[k].amount += l.offer?.amount || 0;
  });
  const series = [];
  for (let i = 0; i < days; i++) {
    const d = new Date(since);
    d.setDate(d.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    series.push({ date: key, applications: trendMap[key]?.count || 0, amount: trendMap[key]?.amount || 0 });
  }

  ok(res, {
    statusCounts,
    users,
    usersToday,
    pendingPayments: pendingPayments.emi,
    pendingFees: pendingPayments.fee,
    disbursedAmount: disbursedAgg[0]?.amount || 0,
    disbursedPrincipal: disbursedAgg[0]?.principal || 0,
    collectedAmount: collectedAgg[0]?.amount || 0,
    overdue: { count: overdueAgg[0]?.count || 0, amount: overdueAgg[0]?.amount || 0 },
    trend: series,
    recent,
  });
});

/* -------------------------------------------------------------- list / detail */

exports.list = asyncHandler(async (req, res) => {
  const { page, limit, skip } = paginate(req.query);
  const q = {};
  if (req.query.status && req.query.status !== 'all') q.status = req.query.status;
  else q.status = { $ne: 'draft' };
  if (req.query.product && req.query.product !== 'all') q.product = req.query.product;
  if (req.query.feeStatus) {
    q['feePayment.status'] = req.query.feeStatus;
    q.status = 'approved';
  }
  if (req.query.includeDrafts === 'true' && !req.query.status) delete q.status;
  if (req.query.search) {
    const rx = new RegExp(escapeRegex(req.query.search.trim()), 'i');
    const User = require('../../models/User');
    const users = await User.find({ $or: [{ mobile: rx }, { fullName: rx }] }).select('_id').limit(200).lean();
    q.$or = [
      { loanNumber: rx },
      { 'basic.firstName': rx },
      { 'basic.lastName': rx },
      { 'kyc.panNumber': rx },
      { user: { $in: users.map((u) => u._id) } },
    ];
  }
  if (req.query.from || req.query.to) {
    q.createdAt = {};
    if (req.query.from) q.createdAt.$gte = new Date(req.query.from);
    if (req.query.to) {
      const t = new Date(req.query.to);
      t.setHours(23, 59, 59, 999);
      q.createdAt.$lte = t;
    }
  }
  const [items, total] = await Promise.all([
    Loan.find(q)
      .sort({ submittedAt: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('user', 'mobile fullName')
      .select('loanNumber status currentStep stage feePayment.status feePayment.amount product productName user basic.firstName basic.lastName basic.monthlyIncome offer.amount offer.tenureMonths offer.emi approved.amount submittedAt createdAt updatedAt verification')
      .lean(),
    Loan.countDocuments(q),
  ]);
  ok(res, { items, total, page, pages: Math.ceil(total / limit) });
});

exports.detail = asyncHandler(async (req, res) => {
  const loan = await Loan.findById(req.params.id).populate('user').populate('assignedTo', 'name email');
  if (!loan) throw ApiError.notFound('Loan not found');
  const [payments, previous] = await Promise.all([
    Payment.find({ loan: loan._id }).sort({ createdAt: -1 }).lean(),
    Loan.find({ user: loan.user._id, _id: { $ne: loan._id } }).select('loanNumber status offer.amount createdAt').sort({ createdAt: -1 }).lean(),
  ]);
  ok(res, { loan, payments, previous });
});

/* -------------------------------------------------------------- workflow */

exports.updateVerification = asyncHandler(async (req, res) => {
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  ['basic', 'kyc', 'bank', 'employment', 'address', 'product'].forEach((k) => {
    if (typeof req.body[k] === 'boolean') loan.verification[k] = req.body[k];
  });
  if (loan.status === 'submitted') {
    loan.status = 'under_review';
    loan.assignedTo = req.admin._id;
    loan.addHistory('under_review', req.admin.name, 'Verification started');
  }
  await loan.save();
  ok(res, { loan }, 'Verification updated');
});

exports.updateRemarks = asyncHandler(async (req, res) => {
  const loan = await Loan.findByIdAndUpdate(req.params.id, { adminRemarks: String(req.body.remarks || '').slice(0, 2000) }, { new: true });
  if (!loan) throw ApiError.notFound('Loan not found');
  ok(res, { loan }, 'Remarks saved');
});

const TRANSITIONS = {
  submitted: ['under_review', 'approved', 'rejected'],
  under_review: ['approved', 'rejected', 'submitted'],
  approved: ['rejected', 'under_review'],
  draft: ['cancelled'],
  disbursed: ['closed'],
};

exports.updateStatus = asyncHandler(async (req, res) => {
  const { status, remarks } = req.body;
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  const allowed = TRANSITIONS[loan.status] || [];
  if (!allowed.includes(status)) throw ApiError.badRequest(`Cannot move loan from "${loan.status}" to "${status}"`);

  if (status === 'approved') {
    const s = await Setting.get();
    // The admin decides the final amount, tenure, rate and processing fee (may differ from what was applied for)
    const ps = s.forProduct(loan.product);
    const amount = Math.round(Number(req.body.amount || loan.offer.amount));
    const tenure = Number(req.body.tenureMonths || loan.offer.tenureMonths);
    const rate = req.body.interestRate !== undefined && req.body.interestRate !== '' ? Number(req.body.interestRate) : loan.offer.interestRate ?? ps.interestRate;
    if (!amount || amount <= 0) throw ApiError.badRequest('Approved amount is required');
    if (!tenure || tenure <= 0 || tenure > 480) throw ApiError.badRequest('Invalid tenure');
    if (!(rate >= 0 && rate <= 100)) throw ApiError.badRequest('Invalid interest rate');
    const q = buildQuote(amount, tenure, { ...ps, interestRate: rate });
    const fee = req.body.processingFee !== undefined && req.body.processingFee !== '' ? Math.round(Number(req.body.processingFee)) : q.totalFee;
    if (!(fee >= 0) || fee >= amount) throw ApiError.badRequest('Invalid processing fee');
    loan.approved = {
      amount,
      tenureMonths: tenure,
      interestRate: rate,
      emi: q.emi,
      totalPayable: q.totalPayable,
      processingFee: fee,
      remarks: remarks || undefined,
      approvedBy: req.admin.name,
      approvedAt: new Date(),
    };
    loan.feePayment = { required: fee > 0, amount: fee, status: fee > 0 ? 'unpaid' : 'waived' };
    loan.rejectionReason = undefined;
    notify(
      loan.user,
      'Loan approved 🎉',
      fee > 0
        ? `Your ${loan.productName || 'loan'} ${loan.loanNumber} is approved for ${fmt(amount)}. Pay the processing fee of ${fmt(fee)} in the app to get the money in your bank.`
        : `Your ${loan.productName || 'loan'} ${loan.loanNumber} is approved for ${fmt(amount)}. Disbursal will be done shortly.`
    );
  }
  if (status === 'rejected') {
    if (!remarks) throw ApiError.badRequest('Please mention the rejection reason');
    loan.rejectionReason = remarks;
    notify(loan.user, 'Application update', `Sorry, your loan application ${loan.loanNumber} could not be approved. Reason: ${remarks}`);
  }
  if (status === 'under_review') {
    loan.assignedTo = req.admin._id;
    loan.stageUpdatedAt = new Date();
    notify(loan.user, 'Application under review', `Your application ${loan.loanNumber} is being verified by our team.`);
  }
  if (status === 'closed') {
    if (loan.schedule.some((i) => i.status !== 'paid') && !req.body.force) {
      throw ApiError.badRequest('All installments are not paid yet. Use force close if settled offline.');
    }
    loan.closedAt = new Date();
    notify(loan.user, 'Loan closed ✅', `Your loan ${loan.loanNumber} is fully repaid and closed. Thank you!`);
  }
  loan.status = status;
  loan.addHistory(status, req.admin.name, remarks);
  await loan.save();
  ok(res, { loan }, `Loan ${status.replace('_', ' ')}`);
});

exports.disburse = asyncHandler(async (req, res) => {
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  if (loan.status !== 'approved') throw ApiError.badRequest('Only approved loans can be disbursed');
  const fp = loan.feePayment || {};
  if (fp.required && !['verified', 'waived'].includes(fp.status) && !req.body.force) {
    throw ApiError.badRequest('Processing fee is not verified yet. Verify the customer payment first.');
  }
  const { utr, mode = 'IMPS', date } = req.body;
  if (!utr || !/^[A-Za-z0-9]{6,30}$/.test(utr)) throw ApiError.badRequest('Enter a valid UTR / reference number');
  const disbursedOn = date ? new Date(date) : new Date();
  if (Number.isNaN(disbursedOn.getTime())) throw ApiError.badRequest('Invalid disbursal date');
  const a = loan.approved;
  // fee is collected separately through the app, so the full approved amount is sent by default
  const fullAmount = (fp.required && fp.status === 'verified') || fp.status === 'waived' || !a.processingFee;
  const amount = req.body.amount ? Number(req.body.amount) : fullAmount ? a.amount : a.amount - a.processingFee;
  loan.disbursal = { amount, utr, mode, date: disbursedOn, by: req.admin.name };
  loan.schedule = buildSchedule(a.amount, a.interestRate, a.tenureMonths, disbursedOn);
  loan.status = 'disbursed';
  loan.addHistory('disbursed', req.admin.name, `${fmt(amount)} sent via ${mode}, UTR ${utr}`);
  await loan.save();
  notify(loan.user, 'Money sent to your bank 💰', `${fmt(amount)} has been disbursed to your account ending ${String(loan.bank.accountNumber).slice(-4)}. UTR: ${utr}. First EMI of ${fmt(a.emi)} is due on ${loan.schedule[0].dueDate.toDateString()}.`);
  ok(res, { loan }, 'Loan disbursed');
});

exports.markInstallment = asyncHandler(async (req, res) => {
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  const inst = loan.schedule.find((i) => i.installmentNo === Number(req.params.no));
  if (!inst) throw ApiError.notFound('Installment not found');
  const paid = req.body.status !== 'pending';
  inst.status = paid ? 'paid' : 'pending';
  inst.paidAt = paid ? new Date(req.body.paidAt || Date.now()) : undefined;
  inst.paymentRef = paid ? req.body.paymentRef || 'manual' : undefined;
  loan.addHistory(loan.status, req.admin.name, `EMI #${inst.installmentNo} marked ${inst.status}`);
  await loan.save();
  ok(res, { loan }, 'Installment updated');
});

exports.editApplication = asyncHandler(async (req, res) => {
  // allow admins to correct typos in applicant data before approval
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  if (['disbursed', 'closed'].includes(loan.status)) throw ApiError.badRequest('Disbursed loans cannot be edited');
  const sections = ['basic', 'personal', 'employment', 'address', 'bank'];
  sections.forEach((sec) => {
    if (req.body[sec] && typeof req.body[sec] === 'object') {
      Object.entries(req.body[sec]).forEach(([k, v]) => {
        if (['bankProof', 'consents'].includes(k)) return;
        loan.set(`${sec}.${k}`, v);
      });
    }
  });
  if (req.body.kyc) {
    if (req.body.kyc.panNumber) {
      const pan = String(req.body.kyc.panNumber).toUpperCase();
      if (!RX.pan.test(pan)) throw ApiError.badRequest('Invalid PAN');
      loan.kyc.panNumber = pan;
    }
  }
  loan.addHistory(loan.status, req.admin.name, 'Application details edited');
  await loan.save();
  ok(res, { loan }, 'Application updated');
});

/* -------------------------------------------------------------- review stage & processing fee */

exports.updateStage = asyncHandler(async (req, res) => {
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  if (!['submitted', 'under_review'].includes(loan.status)) throw ApiError.badRequest('Stage can be changed only while the application is pending');
  const product = (await Setting.get()).product(loan.product);
  const steps = product.reviewSteps || [];
  const stage = Number(req.body.stage);
  if (!Number.isInteger(stage) || stage < 0 || stage >= Math.max(1, steps.length)) throw ApiError.badRequest('Invalid stage');
  const note = String(req.body.note || '').trim().slice(0, 300);
  loan.stage = stage;
  loan.stageNote = note || undefined;
  loan.stageUpdatedAt = new Date();
  if (loan.status === 'submitted') {
    loan.status = 'under_review';
    loan.assignedTo = req.admin._id;
  }
  const label = steps[stage] || 'In review';
  loan.addHistory('under_review', req.admin.name, `${label}${note ? ` – ${note}` : ''}`);
  await loan.save();
  notify(loan.user, `Application update: ${label}`, note || `Your application ${loan.loanNumber} is now at "${label}".`);
  ok(res, { loan }, 'Stage updated');
});

exports.reviewFee = asyncHandler(async (req, res) => {
  const { status, remarks } = req.body;
  if (!['verified', 'rejected', 'waived'].includes(status)) throw ApiError.badRequest('Invalid status');
  const loan = await Loan.findById(req.params.id);
  if (!loan) throw ApiError.notFound('Loan not found');
  if (loan.status !== 'approved' || !loan.feePayment?.required) throw ApiError.badRequest('No processing fee to review on this loan');
  if (status === 'rejected' && !remarks) throw ApiError.badRequest('Please mention the reason');
  if (status === 'verified' && loan.feePayment.status !== 'submitted') throw ApiError.badRequest('Customer has not submitted the payment yet');
  loan.feePayment.status = status;
  loan.feePayment.remarks = remarks || undefined;
  loan.feePayment.verifiedBy = req.admin.name;
  loan.feePayment.verifiedAt = new Date();
  const msg = { verified: 'Processing fee verified', rejected: `Processing fee rejected: ${remarks}`, waived: 'Processing fee waived' }[status];
  loan.addHistory('approved', req.admin.name, msg);
  await loan.save();
  if (status === 'verified') notify(loan.user, 'Payment received ✅', `We have received your processing fee of ${fmt(loan.feePayment.amount)}. Your loan will be disbursed shortly.`, 'payment');
  if (status === 'rejected') notify(loan.user, 'Processing fee payment issue', `We could not verify your payment: ${remarks}. Please pay again from the app.`, 'payment');
  if (status === 'waived') notify(loan.user, 'Processing fee waived 🎉', 'No processing fee is needed for your loan. Disbursal will be done shortly.', 'payment');
  ok(res, { loan }, msg);
});

/* -------------------------------------------------------------- payments */

exports.listPayments = asyncHandler(async (req, res) => {
  const { page, limit, skip } = paginate(req.query);
  const q = {};
  if (req.query.status && req.query.status !== 'all') q.status = req.query.status;
  if (req.query.search) q.utr = new RegExp(escapeRegex(req.query.search.trim()), 'i');
  const [items, total] = await Promise.all([
    Payment.find(q)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('user', 'mobile fullName')
      .populate('loan', 'loanNumber')
      .lean(),
    Payment.countDocuments(q),
  ]);
  ok(res, { items, total, page, pages: Math.ceil(total / limit) });
});

exports.reviewPayment = asyncHandler(async (req, res) => {
  const { status, remarks } = req.body;
  if (!['verified', 'rejected'].includes(status)) throw ApiError.badRequest('Invalid status');
  const payment = await Payment.findById(req.params.id);
  if (!payment) throw ApiError.notFound('Payment not found');
  if (payment.status !== 'pending') throw ApiError.badRequest('Payment already reviewed');
  if (status === 'rejected' && !remarks) throw ApiError.badRequest('Please mention the reason');

  payment.status = status;
  payment.remarks = remarks;
  payment.verifiedBy = req.admin.name;
  payment.verifiedAt = new Date();
  await payment.save();

  const loan = await Loan.findById(payment.loan);
  if (status === 'verified' && loan) {
    let inst = payment.installmentNo ? loan.schedule.find((i) => i.installmentNo === payment.installmentNo) : null;
    if (!inst) inst = loan.schedule.find((i) => i.status !== 'paid');
    if (inst) {
      inst.status = 'paid';
      inst.paidAt = new Date();
      inst.paymentRef = payment.utr;
    }
    loan.addHistory(loan.status, req.admin.name, `Payment ${payment.utr} verified${inst ? ` for EMI #${inst.installmentNo}` : ''}`);
    if (loan.schedule.length && loan.schedule.every((i) => i.status === 'paid')) {
      loan.status = 'closed';
      loan.closedAt = new Date();
      loan.addHistory('closed', 'system', 'All EMIs paid');
      notify(loan.user, 'Loan closed ✅', `Congratulations! Your loan ${loan.loanNumber} is fully repaid.`);
    }
    await loan.save();
    notify(payment.user, 'Payment received', `We have received your payment of ${fmt(payment.amount)} (UTR ${payment.utr}). Thank you!`, 'payment');
  } else if (status === 'rejected') {
    notify(payment.user, 'Payment could not be verified', `Your payment (UTR ${payment.utr}) was rejected: ${remarks}`, 'payment');
  }
  ok(res, { payment }, `Payment ${status}`);
});
