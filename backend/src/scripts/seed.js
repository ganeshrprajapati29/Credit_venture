const env = require('../config/env');
const Admin = require('../models/Admin');
const Banner = require('../models/Banner');
const Setting = require('../models/Setting');

/** Creates the first super admin from .env if no admin exists yet. */
async function ensureSuperAdmin() {
  const count = await Admin.countDocuments();
  if (count > 0) return null;
  const admin = new Admin({ name: env.seedAdmin.name, email: env.seedAdmin.email, role: 'superadmin' });
  await admin.setPassword(env.seedAdmin.password);
  await admin.save();
  console.log(`[seed] super admin created: ${admin.email} (change the password after first login)`);
  return admin;
}

async function seedBanners() {
  if (await Banner.countDocuments()) return;
  await Banner.insertMany([
    { title: 'Instant Personal Loan', subtitle: 'Get up to ₹2,00,000 in your bank account', ctaText: 'Apply Now', bgColor: '#1B2A6B', order: 1 },
    { title: '100% Digital Process', subtitle: 'Upload documents from your phone. No branch visit.', ctaText: 'Check Offer', bgColor: '#0F766E', order: 2 },
    { title: 'Flexible EMIs', subtitle: 'Choose a tenure from 3 to 12 months', ctaText: 'Calculate EMI', bgColor: '#7C3AED', order: 3 },
  ]);
  console.log('[seed] default banners created');
}

module.exports = { ensureSuperAdmin, seedBanners };

if (require.main === module) {
  const { connectDB } = require('../config/db');
  const mongoose = require('mongoose');
  (async () => {
    await connectDB();
    await Setting.get();
    await ensureSuperAdmin();
    await seedBanners();
    await mongoose.disconnect();
    console.log('[seed] done');
  })().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
