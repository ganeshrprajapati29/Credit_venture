const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const consentSchema = new mongoose.Schema(
  {
    termsAccepted: { type: Boolean, default: false },
    privacyAccepted: { type: Boolean, default: false },
    creditBureauConsent: { type: Boolean, default: false },
    permissions: { type: [String], default: [] }, // e.g. ['camera','photos','location','notification']
    acceptedAt: Date,
    appVersion: String,
  },
  { _id: false }
);

const deviceSchema = new mongoose.Schema(
  {
    model: String,
    brand: String,
    os: String,
    osVersion: String,
    appVersion: String,
    deviceId: String,
    lastLatitude: Number,
    lastLongitude: Number,
    lastSeenAt: Date,
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    mobile: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      match: [/^[6-9]\d{9}$/, 'Enter a valid 10 digit Indian mobile number'],
    },
    mpinHash: { type: String, required: true, select: false },
    fullName: { type: String, trim: true },
    email: { type: String, trim: true, lowercase: true },
    status: { type: String, enum: ['active', 'blocked'], default: 'active' },
    consent: { type: consentSchema, default: () => ({}) },
    device: { type: deviceSchema, default: () => ({}) },
    failedLogins: { type: Number, default: 0 },
    lockUntil: Date,
    lastLoginAt: Date,
  },
  { timestamps: true }
);

userSchema.methods.setMpin = async function setMpin(mpin) {
  this.mpinHash = await bcrypt.hash(String(mpin), 10);
};

userSchema.methods.checkMpin = function checkMpin(mpin) {
  return bcrypt.compare(String(mpin), this.mpinHash);
};

userSchema.set('toJSON', {
  transform(_doc, ret) {
    delete ret.mpinHash;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('User', userSchema);
