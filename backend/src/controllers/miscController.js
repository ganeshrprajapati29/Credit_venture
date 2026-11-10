const path = require('path');
const fs = require('fs');
const Notification = require('../models/Notification');
const Loan = require('../models/Loan');
const Payment = require('../models/Payment');
const { ApiError, asyncHandler, ok } = require('../utils/http');
const { PRIVATE_DIR } = require('../middleware/upload');

/* ---------------- notifications (user) */

exports.listNotifications = asyncHandler(async (req, res) => {
  const items = await Notification.find({ $or: [{ user: req.user._id }, { user: null }], createdAt: { $gte: req.user.createdAt } })
    .sort({ createdAt: -1 })
    .limit(100)
    .lean();
  const uid = String(req.user._id);
  const notifications = items.map((n) => ({
    _id: n._id,
    title: n.title,
    body: n.body,
    type: n.type,
    createdAt: n.createdAt,
    read: (n.readBy || []).some((r) => String(r) === uid),
  }));
  ok(res, { notifications, unread: notifications.filter((n) => !n.read).length });
});

exports.markRead = asyncHandler(async (req, res) => {
  const filter = { $or: [{ user: req.user._id }, { user: null }] };
  if (req.params.id !== 'all') filter._id = req.params.id;
  await Notification.updateMany(filter, { $addToSet: { readBy: req.user._id } });
  ok(res, {}, 'Marked as read');
});

/* ---------------- private file access (KYC / bank proof / payment proof) */

exports.getFile = asyncHandler(async (req, res) => {
  const name = path.basename(req.params.name);
  if (!/^[\w.-]+$/.test(name)) throw ApiError.badRequest('Invalid file');

  if (!req.admin) {
    // users can only read their own files
    const uid = req.user._id;
    const inLoan = await Loan.exists({
      user: uid,
      $or: [
        { 'kyc.aadhaarFront.filename': name },
        { 'kyc.aadhaarBack.filename': name },
        { 'kyc.panCard.filename': name },
        { 'kyc.selfie.filename': name },
        { 'kyc.salarySlip.filename': name },
        { 'bank.bankProof.filename': name },
      ],
    });
    const inPayment = inLoan ? true : await Payment.exists({ user: uid, 'proof.filename': name });
    if (!inLoan && !inPayment) throw ApiError.notFound('File not found');
  }

  const full = path.join(PRIVATE_DIR, name);
  if (!fs.existsSync(full)) throw ApiError.notFound('File not found');
  res.set('Cache-Control', 'private, max-age=300');
  res.sendFile(full);
});
