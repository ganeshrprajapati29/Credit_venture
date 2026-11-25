const env = require('./config/env');
const { connectDB } = require('./config/db');
const app = require('./app');
const Setting = require('./models/Setting');
const { ensureSuperAdmin, seedBanners } = require('./scripts/seed');
const dbStatus = require('./config/dbStatus');

let dbReady = false;

/** Connect to MongoDB with retries so the app (and /health) stays up while the database is unreachable. */
async function connectWithRetry(attempt = 1) {
  try {
    await connectDB();
    await Setting.get(); // create default settings on first boot
    const firstInstall = await ensureSuperAdmin();
    if (firstInstall) await seedBanners(); // default home-screen banners on a fresh install only
    dbReady = true;
    dbStatus.status.lastError = null;
  } catch (err) {
    dbStatus.status.attempts = attempt;
    dbStatus.status.lastError = String(err.message || err).replace(/\/\/[^@\s]*@/g, '//***@');
    dbStatus.status.lastErrorAt = new Date().toISOString();
    const wait = Math.min(60, 5 * attempt);
    console.error(`[db] connection failed (attempt ${attempt}): ${err.message}. Retrying in ${wait}s`);
    setTimeout(() => connectWithRetry(attempt + 1), wait * 1000).unref();
  }
}

function start() {
  // Hostinger / most Node hosts pass the port in PORT
  const server = app.listen(env.port, () => console.log(`[api] Credit Ventures API listening on :${env.port} (${env.nodeEnv})`));
  connectWithRetry();

  const shutdown = (sig) => {
    console.log(`[api] ${sig} received, shutting down`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('unhandledRejection', (err) => console.error('[api] unhandled rejection', err));
}

module.exports = { isDbReady: () => dbReady };

try {
  start();
} catch (err) {
  console.error('[api] failed to start', err);
  process.exit(1);
}
