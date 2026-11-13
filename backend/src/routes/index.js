const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireUser, requireAdmin, requireAny } = require('../middleware/auth');
const { privateUpload, publicUpload } = require('../middleware/upload');

const auth = require('../controllers/authController');
const app = require('../controllers/appController');
const loan = require('../controllers/loanController');
const misc = require('../controllers/miscController');
const aAuth = require('../controllers/admin/adminAuthController');
const aLoan = require('../controllers/admin/adminLoanController');
const aMisc = require('../controllers/admin/adminMiscController');

const router = express.Router();

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: true, legacyHeaders: false, message: { success: false, message: 'Too many attempts, please try again later' } });

/* ------------------------------------------------------------- public */
router.get('/health', (_req, res) => res.json({ success: true, message: 'Credit Ventures API is running', time: new Date() }));
router.get('/app/config', app.config);
router.get('/app/banners', app.banners);

/* ------------------------------------------------------------- user auth */
router.post('/auth/otp/send', authLimiter, auth.sendOtp);
router.post('/auth/otp/verify', authLimiter, auth.verifyOtp);
router.post('/auth/check', authLimiter, auth.checkMobile);
router.post('/auth/register', authLimiter, auth.register);
router.post('/auth/login', authLimiter, auth.login);
router.get('/auth/me', requireUser, auth.me);
router.put('/auth/profile', requireUser, auth.updateProfile);
router.put('/auth/mpin', requireUser, auth.changeMpin);
router.put('/auth/device', requireUser, auth.updateDevice);

/* ------------------------------------------------------------- loan application */
router.get('/loans/current', requireUser, loan.current);
router.get('/loans/quote', requireUser, loan.quote);
router.get('/loans', requireUser, loan.list);
router.put('/loans/current/basic', requireUser, loan.saveBasic);
router.put('/loans/current/offer', requireUser, loan.saveOffer);
router.put('/loans/current/personal', requireUser, loan.savePersonal);
router.put('/loans/current/product', requireUser, loan.saveProductDetails);
router.put('/loans/current/employment', requireUser, loan.saveEmployment);
router.put('/loans/current/address', requireUser, loan.saveAddress);
router.put(
  '/loans/current/kyc',
  requireUser,
  privateUpload.fields([
    { name: 'aadhaarFront', maxCount: 1 },
    { name: 'aadhaarBack', maxCount: 1 },
    { name: 'panCard', maxCount: 1 },
    { name: 'selfie', maxCount: 1 },
    { name: 'salarySlip', maxCount: 1 },
  ]),
  loan.saveKyc
);
router.put('/loans/current/bank', requireUser, privateUpload.single('bankProof'), loan.saveBank);
router.post('/loans/current/submit', requireUser, loan.submit);
router.get('/loans/:id', requireUser, loan.detail);
router.post('/loans/:id/cancel', requireUser, loan.cancel);
router.post('/loans/:id/payments', requireUser, privateUpload.single('proof'), loan.submitPayment);
router.post('/loans/:id/fee-payment', requireUser, privateUpload.single('proof'), loan.submitFeePayment);

/* ------------------------------------------------------------- notifications & files */
router.get('/notifications', requireUser, misc.listNotifications);
router.put('/notifications/:id/read', requireUser, misc.markRead);
router.get('/files/:name', requireAny, misc.getFile);

/* ------------------------------------------------------------- admin */
const admin = express.Router();
const staff = requireAdmin();
const managers = requireAdmin('superadmin', 'manager');
const superadmin = requireAdmin('superadmin');

admin.post('/auth/login', authLimiter, aAuth.login);
admin.get('/auth/me', staff, aAuth.me);
admin.put('/auth/password', staff, aAuth.changePassword);

admin.get('/dashboard', staff, aLoan.dashboard);

admin.get('/loans', staff, aLoan.list);
admin.get('/loans/:id', staff, aLoan.detail);
admin.patch('/loans/:id', managers, aLoan.editApplication);
admin.patch('/loans/:id/verification', staff, aLoan.updateVerification);
admin.patch('/loans/:id/remarks', staff, aLoan.updateRemarks);
admin.patch('/loans/:id/status', managers, aLoan.updateStatus);
admin.patch('/loans/:id/stage', staff, aLoan.updateStage);
admin.patch('/loans/:id/fee', managers, aLoan.reviewFee);
admin.post('/loans/:id/disburse', managers, aLoan.disburse);
admin.patch('/loans/:id/installments/:no', managers, aLoan.markInstallment);

admin.get('/payments', staff, aLoan.listPayments);
admin.patch('/payments/:id', managers, aLoan.reviewPayment);

admin.get('/users', staff, aMisc.listUsers);
admin.get('/users/:id', staff, aMisc.userDetail);
admin.patch('/users/:id', managers, aMisc.updateUser);

admin.get('/settings', staff, aMisc.getSettings);
admin.put('/settings', superadmin, aMisc.updateSettings);
admin.post('/settings/fee-qr', superadmin, publicUpload.single('image'), aMisc.uploadFeeQr);
admin.delete('/settings/fee-qr', superadmin, aMisc.deleteFeeQr);

admin.get('/banners', staff, aMisc.listBanners);
admin.post('/banners', managers, publicUpload.single('image'), aMisc.createBanner);
admin.put('/banners/:id', managers, publicUpload.single('image'), aMisc.updateBanner);
admin.delete('/banners/:id', managers, aMisc.deleteBanner);

admin.get('/notifications', staff, aMisc.listNotifications);
admin.post('/notifications', managers, aMisc.sendNotification);
admin.delete('/notifications/:id', managers, aMisc.deleteNotification);

admin.get('/team', superadmin, aAuth.list);
admin.post('/team', superadmin, aAuth.create);
admin.patch('/team/:id', superadmin, aAuth.update);

router.use('/admin', admin);

module.exports = router;
