// PM2 process file – started by deploy/setup-vps.sh
const path = require('path');

const appDir = process.env.APP_DIR || path.join(__dirname, '..', 'backend');
const logDir = process.env.LOG_DIR || path.join(appDir, 'logs');

module.exports = {
  apps: [
    {
      name: 'credit-ventures-api',
      cwd: appDir,
      script: 'src/server.js',
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '400M',
      // run as the unprivileged app user when PM2 is started as root
      ...(process.env.APP_UID ? { uid: process.env.APP_UID, gid: process.env.APP_UID } : {}),
      env_production: { NODE_ENV: 'production' },
      out_file: path.join(logDir, 'api.out.log'),
      error_file: path.join(logDir, 'api.err.log'),
      time: true,
    },
  ],
};
