const env = require('./config/env');
const { connectDB } = require('./config/db');
const app = require('./app');
const Setting = require('./models/Setting');
const { ensureSuperAdmin } = require('./scripts/seed');

async function start() {
  await connectDB();
  await Setting.get(); // create default settings on first boot
  await ensureSuperAdmin();
  const server = app.listen(env.port, () => console.log(`[api] Credit Ventures API listening on :${env.port} (${env.nodeEnv})`));

  const shutdown = (sig) => {
    console.log(`[api] ${sig} received, shutting down`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start().catch((err) => {
  console.error('[api] failed to start', err);
  process.exit(1);
});
