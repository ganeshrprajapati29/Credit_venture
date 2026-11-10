const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    subtitle: { type: String, trim: true },
    image: String, // public file name in uploads/public
    ctaText: String,
    ctaAction: { type: String, default: 'apply' }, // apply, link, none
    link: String,
    bgColor: { type: String, default: '#1B2A6B' },
    order: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Banner', bannerSchema);
