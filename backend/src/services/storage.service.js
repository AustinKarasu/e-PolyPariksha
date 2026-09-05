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
  const bytes = await getUploadedFileBytes(file);
  if (!bytes.subarray(0, 5).equals(Buffer.from('%PDF-'))) {
    await discardUploadedFile(file);
    throw new ApiError(422, 'The uploaded file is not a valid PDF');
  }
  if (env.storage.driver === 's3') {
    if (!env.storage.s3.bucket) {
      throw new ApiError(500, 'S3 bucket is not configured');
    }
    const key = `question-papers/${Date.now()}-${safeName(file.originalname)}`;
    await getS3Client().send(new PutObjectCommand({
      Bucket: env.storage.s3.bucket,
      Key: key,
      Body: bytes,
      ContentType: 'application/pdf'
    }));
    return { key, path: key };
  }

  return { key: file.filename, path: file.path };
}

async function getUploadedFileBytes(file) {
  if (file.buffer) return file.buffer;
  if (file.path) return fs.readFile(file.path);
  throw new ApiError(422, 'PDF file could not be read');
}

async function saveProfilePhoto(file) {
  const inferredType = contentTypeForName(file.originalname);
  const contentType = !file.mimetype || file.mimetype === 'application/octet-stream'
    ? inferredType || 'application/octet-stream'
    : file.mimetype;
  const bytes = file.buffer || await fs.readFile(file.path);

  if (!isValidImage(bytes, contentType)) {
    await discardUploadedFile(file);
    throw new ApiError(422, 'The uploaded file is not a valid PNG, JPG, or WEBP image');
  }

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

async function getPdfDelivery(filePathOrKey, test = null) {
  if (test?.pdf_data) {
    return {
      type: 'buffer',
      value: Buffer.isBuffer(test.pdf_data) ? test.pdf_data : Buffer.from(test.pdf_data),
      filename: test.pdf_original_name || `polyht-test-${test.id}.pdf`,
      contentType: test.pdf_mime_type || 'application/pdf'
    };
  }
  if (env.storage.driver === 's3') {
    if (!env.storage.s3.bucket) {
      throw new ApiError(500, 'S3 bucket is not configured');
    }
    const url = await getSignedUrl(
      getS3Client(),
      new GetObjectCommand({ Bucket: env.storage.s3.bucket, Key: filePathOrKey }),
      { expiresIn: 60 }
    );
    return { type: 'redirect', value: url };
  }
  if (!filePathOrKey) {
    throw new ApiError(404, 'Question paper PDF is not available. Re-upload this test PDF from the admin app.');
  }
  const value = path.isAbsolute(filePathOrKey)
    ? filePathOrKey
    : path.resolve(env.uploadDir, path.basename(filePathOrKey));
  try {
    await fs.access(value);
  } catch (_) {
    throw new ApiError(404, 'Question paper PDF is not available. Re-upload this test PDF from the admin app.');
  }
  return {
    type: 'file',
    value
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

function isValidImage(bytes, contentType) {
  if (contentType === 'image/png') return bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  if (contentType === 'image/jpeg') return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (contentType === 'image/webp') return bytes.length >= 12 && bytes.subarray(0, 4).equals(Buffer.from('RIFF')) && bytes.subarray(8, 12).equals(Buffer.from('WEBP'));
  return false;
}

async function discardUploadedFile(file) {
  if (file?.path) await fs.unlink(file.path).catch(() => {});
}

module.exports = { savePdf, saveProfilePhoto, deletePdf, getPdfDelivery, getUploadedFileBytes };
