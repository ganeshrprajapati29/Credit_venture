// Last MongoDB connection problem, shown on /api/v1/health (no passwords)
const status = { lastError: null, lastErrorAt: null, attempts: 0 };

function hostOf(uri) {
  try {
    const afterScheme = uri.split('://')[1] || '';
    const hostPart = afterScheme.split('@').pop().split('/')[0].split('?')[0];
    return hostPart || null;
  } catch {
    return null;
  }
}

function hintFor(msg = '', uri = '') {
  const m = msg.toLowerCase();
  if (/127\.0\.0\.1|localhost/.test(uri)) return 'MONGO_URI is not set (using localhost). Add your MongoDB Atlas URI in the hosting panel environment variables and restart the app.';
  if (m.includes('bad auth') || m.includes('authentication failed')) return 'Wrong MongoDB username/password in MONGO_URI. If the password has special characters (@ # % / :), URL-encode them or use a simple password.';
  if (m.includes('whitelist') || m.includes('server selection') || m.includes('timed out') || m.includes('could not connect')) return 'MongoDB Atlas is blocking this server: Atlas → Network Access → Add IP Address → Allow access from anywhere (0.0.0.0/0).';
  if (m.includes('querysrv') || m.includes('enotfound') || m.includes('invalid')) return 'MONGO_URI is malformed or the cluster host is wrong. Copy it again from Atlas → Connect → Drivers.';
  return null;
}

module.exports = { status, hostOf, hintFor };
