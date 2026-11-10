const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const env = require('../config/env');
const { ApiError } = require('../utils/http');

// Private documents (KYC, bank proof, payment proof) live in uploads/private and are
// only served through an authenticated route. Banners live in uploads/public.
const PRIVATE_DIR = path.join(env.uploadDir, 'private');
const PUBLIC_DIR = path.join(env.uploadDir, 'public');
[PRIVATE_DIR, PUBLIC_DIR].forEach((d) => fs.mkdirSync(d, { recursive: true }));

const ALLOWED = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'application/pdf': '.pdf',
};

const makeStorage = (dir) =>
  multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, dir),
    filename: (_req, file, cb) => {
      const ext = ALLOWED[file.mimetype] || path.extname(file.originalname).toLowerCase() || '.bin';
      cb(null, `${Date.now()}-${crypto.randomBytes(12).toString('hex')}${ext}`);
    },
  });

const fileFilter = (allowPdf) => (_req, file, cb) => {
  const okType = ALLOWED[file.mimetype] && (allowPdf || file.mimetype !== 'application/pdf');
  if (!okType) return cb(ApiError.badRequest(`Unsupported file type for ${file.fieldname}. Upload JPG, PNG${allowPdf ? ' or PDF' : ''}.`));
  return cb(null, true);
};

const privateUpload = multer({
  storage: makeStorage(PRIVATE_DIR),
  fileFilter: fileFilter(true),
  limits: { fileSize: env.maxUploadMb * 1024 * 1024, files: 8 },
});

const publicUpload = multer({
  storage: makeStorage(PUBLIC_DIR),
  fileFilter: fileFilter(false),
  limits: { fileSize: env.maxUploadMb * 1024 * 1024, files: 2 },
});

const fileMeta = (f) =>
  f && {
    filename: f.filename,
    originalName: f.originalname,
    mimeType: f.mimetype,
    size: f.size,
    uploadedAt: new Date(),
  };

const removeFile = (dir, name) => {
  if (!name) return;
  const p = path.join(dir, path.basename(name));
  fs.promises.unlink(p).catch(() => {});
};

module.exports = { privateUpload, publicUpload, fileMeta, removeFile, PRIVATE_DIR, PUBLIC_DIR };
