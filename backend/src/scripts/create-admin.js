/**
 * Create (or reset) an admin login.
 *   node src/scripts/create-admin.js <email> [password] [role]
 * role: superadmin (default) | manager | verifier
 * If no password is given, a strong one is generated and printed.
 * Uses MONGO_URI from backend/.env (or the environment).
 */
const crypto = require('crypto');
const mongoose = require('mongoose');
const env = require('../config/env');
const Admin = require('../models/Admin');

(async () => {
  const [emailArg, passArg, roleArg] = process.argv.slice(2);
  const email = String(emailArg || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(email)) {
    console.error('Usage: node src/scripts/create-admin.js <email> [password] [role]');
    process.exit(1);
  }
  const role = ['superadmin', 'manager', 'verifier'].includes(roleArg) ? roleArg : 'superadmin';
  const password = passArg || `Cv@${crypto.randomBytes(6).toString('hex')}`;
  if (password.length < 8) {
    console.error('Password must be at least 8 characters');
    process.exit(1);
  }

  await mongoose.connect(env.mongoUri, { serverSelectionTimeoutMS: 15000 });
  let admin = await Admin.findOne({ email }).select('+passwordHash');
  const created = !admin;
  if (!admin) admin = new Admin({ email, name: 'Super Admin' });
  admin.role = role;
  admin.active = true;
  await admin.setPassword(password);
  await admin.save();

  console.log(`\n${created ? 'Admin created' : 'Admin updated (password reset, enabled)'} in database "${mongoose.connection.name}"`);
  console.log(`  Email   : ${email}`);
  console.log(`  Password: ${password}`);
  console.log(`  Role    : ${role}\n`);
  await mongoose.disconnect();
})().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
