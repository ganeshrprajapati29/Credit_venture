const express = require('express');
const mongoose = require('mongoose');
const pkg = require('../../package.json');
const env = require('../config/env');

const router = express.Router();
const STATES = ['disconnected', 'connected', 'connecting', 'disconnecting'];
const startedAt = new Date();

/**
 * Full health check: server + database.
 * 200 when everything is up, 503 when the database is not reachable.
 * Use it for uptime monitors (UptimeRobot, Hostinger, etc.).
 */
router.get('/', async (_req, res) => {
  const state = STATES[mongoose.connection.readyState] || 'unknown';
  let dbPingMs = null;
  if (state === 'connected') {
    const t = Date.now();
    try {
      await mongoose.connection.db.admin().command({ ping: 1 });
      dbPingMs = Date.now() - t;
    } catch {
      dbPingMs = null;
    }
  }
  const dbOk = state === 'connected' && dbPingMs !== null;
  const mem = process.memoryUsage();
  res.status(dbOk ? 200 : 503).json({
    success: dbOk,
    status: dbOk ? 'ok' : 'degraded',
    message: dbOk ? 'Credit Ventures API is running' : 'API is running but the database is not reachable',
    service: 'credit-ventures-api',
    version: pkg.version,
    environment: env.nodeEnv,
    time: new Date().toISOString(),
    startedAt: startedAt.toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    database: { status: state, pingMs: dbPingMs, name: mongoose.connection.name || null },
    node: process.version,
    memoryMb: { rss: Math.round(mem.rss / 1048576), heapUsed: Math.round(mem.heapUsed / 1048576) },
  });
});

/** Liveness only (process is up) – always 200, never touches the database. */
router.get('/live', (_req, res) => res.json({ success: true, status: 'alive', time: new Date().toISOString() }));

module.exports = router;
