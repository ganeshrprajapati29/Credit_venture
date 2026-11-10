const mongoose = require('mongoose');

const { Schema } = mongoose;

const STATUSES = [
  'draft', // user is still filling the application
  'submitted', // user signed & submitted
  'under_review', // picked up by a verifier
  'approved', // approved, waiting for disbursal
  'rejected',
  'disbursed', // money sent, EMIs running
  'closed', // fully repaid
  'cancelled',
];

const fileSchema = new Schema(
  {
    filename: String, // stored random file name
    originalName: String,
    mimeType: String,
    size: Number,
    uploadedAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const installmentSchema = new Schema({
  installmentNo: Number,
  dueDate: Date,
  amount: Number,
  principal: Number,
  interest: Number,
  balanceAfter: Number,
  status: { type: String, enum: ['pending', 'paid', 'overdue'], default: 'pending' },
  paidAt: Date,
  paymentRef: String,
});

const historySchema = new Schema(
  {
    status: String,
    remarks: String,
    by: String, // 'user' or admin name
    at: { type: Date, default: Date.now },
  },
  { _id: false }
);

const loanSchema = new Schema(
  {
    loanNumber: { type: String, unique: true, index: true },
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    status: { type: String, enum: STATUSES, default: 'draft', index: true },
    currentStep: { type: String, default: 'basic' }, // basic, offer, personal, employment, address, kyc, bank, review, done

    basic: {
      firstName: String,
      lastName: String,
      dob: Date,
      gender: { type: String, enum: ['male', 'female', 'other'] },
      email: String,
      education: String,
      maritalStatus: String,
      preferredAmount: Number,
      employmentType: String,
      monthlyIncome: Number,
      salaryMode: String,
      consents: {
        creditBureau: Boolean,
        ckyc: Boolean,
        incomeDeclaration: Boolean,
        disabilityDeclaration: Boolean,
        acceptedAt: Date,
      },
    },

    offer: {
      minAmount: Number,
      maxAmount: Number,
      amount: Number,
      tenureMonths: Number,
      interestRate: Number,
      emi: Number,
      totalPayable: Number,
      totalInterest: Number,
      processingFee: Number,
      gstOnFee: Number,
      totalFee: Number,
      disbursalAmount: Number,
      promoCode: String,
    },

    personal: {
      fatherName: String,
      motherName: String,
      residenceType: { type: String, enum: ['owned', 'rented', 'family', 'pg'] },
      purpose: String,
      language: String,
      pepDeclaration: Boolean,
    },

    employment: {
      companyName: String,
      sector: String,
      industryType: String,
      natureOfWork: String,
      designation: String,
      officeEmail: String,
      companyAddress: String,
      companyPincode: String,
      workExperienceMonths: Number,
    },

    address: {
      line1: String,
      line2: String,
      landmark: String,
      city: String,
      state: String,
      pincode: String,
      yearsAtAddress: Number,
      sameAsPermanent: { type: Boolean, default: true },
      permanentAddress: String,
    },

    kyc: {
      aadhaarNumber: String, // stored masked except last 4 shown in lists
      panNumber: String,
      aadhaarFront: fileSchema,
      aadhaarBack: fileSchema,
      panCard: fileSchema,
      selfie: fileSchema,
      salarySlip: fileSchema,
    },

    bank: {
      accountHolderName: String,
      accountNumber: String,
      ifsc: String,
      bankName: String,
      branch: String,
      accountType: { type: String, enum: ['savings', 'current'] },
      bankProof: fileSchema, // passbook / cancelled cheque / statement
      autoDebitConsent: Boolean,
    },

    agreement: {
      accepted: Boolean,
      signatureName: String,
      acceptedAt: Date,
      ip: String,
      device: String,
    },

    verification: {
      basic: { type: Boolean, default: false },
      kyc: { type: Boolean, default: false },
      bank: { type: Boolean, default: false },
      employment: { type: Boolean, default: false },
      address: { type: Boolean, default: false },
    },

    approved: {
      amount: Number,
      tenureMonths: Number,
      interestRate: Number,
      emi: Number,
      processingFee: Number,
      approvedBy: String,
      approvedAt: Date,
    },

    disbursal: {
      amount: Number,
      utr: String,
      mode: String,
      date: Date,
      by: String,
    },

    schedule: [installmentSchema],
    rejectionReason: String,
    adminRemarks: String,
    assignedTo: { type: Schema.Types.ObjectId, ref: 'Admin' },
    history: [historySchema],
    submittedAt: Date,
    closedAt: Date,
  },
  { timestamps: true }
);

loanSchema.statics.STATUSES = STATUSES;
loanSchema.statics.ACTIVE_STATUSES = ['draft', 'submitted', 'under_review', 'approved', 'disbursed'];

loanSchema.pre('save', async function assignNumber(next) {
  if (this.loanNumber) return next();
  const d = new Date();
  const ymd = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
  const rand = Math.floor(100000 + Math.random() * 900000);
  this.loanNumber = `CV${ymd}${rand}`;
  return next();
});

loanSchema.methods.addHistory = function addHistory(status, by, remarks) {
  this.history.push({ status, by, remarks, at: new Date() });
};

/** Names of all files attached to this loan (used for access checks). */
loanSchema.methods.fileNames = function fileNames() {
  const out = [];
  const k = this.kyc || {};
  ['aadhaarFront', 'aadhaarBack', 'panCard', 'selfie', 'salarySlip'].forEach((f) => {
    if (k[f] && k[f].filename) out.push(k[f].filename);
  });
  if (this.bank && this.bank.bankProof && this.bank.bankProof.filename) out.push(this.bank.bankProof.filename);
  return out;
};

loanSchema.set('toJSON', {
  transform(_doc, ret) {
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('Loan', loanSchema);
