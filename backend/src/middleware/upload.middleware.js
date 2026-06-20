const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');

const uploadPath = path.resolve(env.uploadDir);
try { fs.mkdirSync(uploadPath, { recursive: true }); } catch (_) { /* read-only fs */ }

const diskStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadPath),
  filename: (_req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${safeName}`);
  }
});

const pdfUpload = multer({
  storage: env.storage.driver === 's3' ? multer.memoryStorage() : diskStorage,
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.originalname.toLowerCase().endsWith('.pdf')) {
      return cb(new ApiError(422, 'Select a file with a .pdf extension'));
    }
    return cb(null, true);
  }
});

const imageUpload = multer({
  storage: env.storage.driver === 's3' ? multer.memoryStorage() : diskStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const name = file.originalname.toLowerCase();
    const isImage = ['image/png', 'image/jpeg', 'image/webp'].includes(file.mimetype) && /\.(png|jpe?g|webp)$/.test(name);
    if (!isImage) {
      return cb(new ApiError(422, 'Only PNG, JPG, or WEBP images are allowed'));
    }
    return cb(null, true);
  }
});

module.exports = { pdfUpload, imageUpload };
