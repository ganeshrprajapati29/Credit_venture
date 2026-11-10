const path = require('path');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const env = require('./config/env');
const routes = require('./routes');
const { PUBLIC_DIR } = require('./middleware/upload');
const { notFound, errorHandler } = require('./middleware/error');

const app = express();

app.set('trust proxy', 1); // behind nginx on the VPS
app.disable('x-powered-by');

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(
  cors({
    origin: env.corsOrigins.includes('*') ? true : env.corsOrigins,
    credentials: false,
  })
);
app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
if (env.nodeEnv !== 'test') app.use(morgan(env.isProd ? 'combined' : 'dev'));

// Public assets (banners). Private KYC files are NOT served statically.
app.use('/uploads/public', express.static(PUBLIC_DIR, { maxAge: '7d', fallthrough: false }));

app.get('/', (_req, res) => res.json({ success: true, name: 'Credit Ventures API', docs: '/api/v1/health' }));
app.use('/api/v1', routes);

// Optional: serve the admin build from the same server (ADMIN_DIST=/path/to/admin/dist)
if (process.env.ADMIN_DIST) {
  const dist = path.resolve(process.env.ADMIN_DIST);
  app.use('/admin', express.static(dist));
  app.get('/admin/*', (_req, res) => res.sendFile(path.join(dist, 'index.html')));
}

app.use(notFound);
app.use(errorHandler);

module.exports = app;
