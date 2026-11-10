const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema(
  {
    loan: { type: mongoose.Schema.Types.ObjectId, ref: 'Loan', required: true, index: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    installmentNo: Number,
    amount: { type: Number, required: true },
    mode: { type: String, default: 'upi' }, // upi, neft, imps, cash, other
    utr: { type: String, trim: true },
    proof: {
      filename: String,
      originalName: String,
      mimeType: String,
      size: Number,
    },
    status: { type: String, enum: ['pending', 'verified', 'rejected'], default: 'pending', index: true },
    remarks: String,
    verifiedBy: String,
    verifiedAt: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Payment', paymentSchema);
