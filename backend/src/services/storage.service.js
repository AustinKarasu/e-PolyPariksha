const fs = require('fs/promises');
const path = require('path');
const { GetObjectCommand, PutObjectCommand, DeleteObjectCommand, S3Client } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');

function getS3Client() {
  const config = {
    region: env.storage.s3.region,
    credentials: {
      accessKeyId: env.storage.s3.accessKeyId,
      secretAccessKey: env.storage.s3.secretAccessKey
    }
  };
  if (env.storage.s3.endpoint) {
    config.endpoint = env.storage.s3.endpoint;
    config.forcePathStyle = true;
  }
  return new S3Client(config);
}

async function savePdf(file) {
  if (env.storage.driver === 's3') {
    if (!env.storage.s3.bucket) {
      throw new ApiError(500, 'S3 bucket is not configured');
    }
    const key = `question-papers/${Date.now()}-${safeName(file.originalname)}`;
    await getS3Client().send(new PutObjectCommand({
      Bucket: env.storage.s3.bucket,
      Key: key,
      Body: file.buffer,
      ContentType: 'application/pdf'
    }));
    return { key, path: key };
  }

  return { key: file.filename, path: file.path };
}

async function saveProfilePhoto(file) {
  const inferredType = contentTypeForName(file.originalname);
  const contentType = !file.mimetype || file.mimetype === 'application/octet-stream'
    ? inferredType || 'application/octet-stream'
    : file.mimetype;
  const bytes = file.buffer || await fs.readFile(file.path);

  if (contentType.startsWith('image/')) {
    return `data:${contentType};base64,${bytes.toString('base64')}`;
  }

  if (env.storage.driver === 's3') {
    if (!env.storage.s3.bucket) {
      throw new ApiError(500, 'S3 bucket is not configured');
    }
    const key = `profile-photos/${Date.now()}-${safeName(file.originalname)}`;
    await getS3Client().send(new PutObjectCommand({
      Bucket: env.storage.s3.bucket,
      Key: key,
      Body: bytes,
      ContentType: contentType
    }));
    if (env.storage.s3.publicBaseUrl) {
      return `${env.storage.s3.publicBaseUrl.replace(/\/$/, '')}/${key}`;
    }
    return `data:${contentType};base64,${bytes.toString('base64')}`;
  }

  const filename = file.filename || `${Date.now()}-${safeName(file.originalname)}`;
  const fullPath = file.path || path.resolve(env.uploadDir, filename);
  return `/uploads/${path.basename(fullPath)}`;
}

async function deletePdf(filePathOrKey) {
  if (!filePathOrKey) return;
  if (env.storage.driver === 's3') {
    await getS3Client().send(new DeleteObjectCommand({
      Bucket: env.storage.s3.bucket,
      Key: filePathOrKey
    })).catch(() => {});
    return;
  }
  await fs.unlink(filePathOrKey).catch(() => {});
}

async function getPdfDelivery(filePathOrKey) {
  if (env.storage.driver === 's3') {
    if (env.storage.s3.publicBaseUrl) {
      return { type: 'redirect', value: `${env.storage.s3.publicBaseUrl.replace(/\/$/, '')}/${filePathOrKey}` };
    }
    const url = await getSignedUrl(
      getS3Client(),
      new GetObjectCommand({ Bucket: env.storage.s3.bucket, Key: filePathOrKey }),
      { expiresIn: 60 }
    );
    return { type: 'redirect', value: url };
  }
  return {
    type: 'file',
    value: path.isAbsolute(filePathOrKey)
      ? filePathOrKey
      : path.resolve(env.uploadDir, path.basename(filePathOrKey))
  };
}

function safeName(name) {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_');
}

function contentTypeForName(name) {
  const lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

module.exports = { savePdf, saveProfilePhoto, deletePdf, getPdfDelivery };
