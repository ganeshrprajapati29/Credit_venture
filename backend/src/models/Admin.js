const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const adminSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true, select: false },
    role: { type: String, enum: ['superadmin', 'manager', 'verifier'], default: 'verifier' },
    active: { type: Boolean, default: true },
    lastLoginAt: Date,
  },
  { timestamps: true }
);

adminSchema.methods.setPassword = async function setPassword(pw) {
  this.passwordHash = await bcrypt.hash(String(pw), 12);
};
adminSchema.methods.checkPassword = function checkPassword(pw) {
  return bcrypt.compare(String(pw), this.passwordHash);
};

adminSchema.set('toJSON', {
  transform(_doc, ret) {
    delete ret.passwordHash;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('Admin', adminSchema);
