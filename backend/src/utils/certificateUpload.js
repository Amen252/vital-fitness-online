const {
  isFileDataUrl,
  isHttpUrl,
  uploadFileDataUrl,
  mimeFromDataUrl,
  extensionFromDataUrl,
} = require('./imageKit');

const MAX_CERTIFICATES = 5;
const MAX_BYTES_PER_FILE = 2 * 1024 * 1024; // 2 MB decoded

const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'application/pdf',
]);

function estimateBase64Bytes(dataUrl) {
  const raw = String(dataUrl || '');
  const comma = raw.indexOf(',');
  const b64 = comma >= 0 ? raw.slice(comma + 1) : raw;
  // Rough decoded size; padding ignored for limit checks.
  return Math.floor((b64.length * 3) / 4);
}

/**
 * Normalize + upload certificate payloads from registration.
 * Accepts:
 * - data URLs (image/pdf)
 * - already-uploaded https URLs (re-apply / pass-through)
 * Returns [{ url, fileName, mimeType, uploadedAt }]
 */
async function resolveCertificateFiles(input, { userId } = {}) {
  if (input == null) return [];
  if (!Array.isArray(input)) {
    const err = new Error('certificateFiles must be an array');
    err.code = 'INVALID_CERTIFICATES';
    throw err;
  }
  if (input.length > MAX_CERTIFICATES) {
    const err = new Error(`You can upload at most ${MAX_CERTIFICATES} certificates`);
    err.code = 'TOO_MANY_CERTIFICATES';
    throw err;
  }

  const results = [];
  for (let i = 0; i < input.length; i += 1) {
    const item = input[i];
    const dataUrl = typeof item === 'string'
      ? item.trim()
      : String(item?.dataUrl || item?.url || item?.file || '').trim();
    const fileNameHint = typeof item === 'object' && item
      ? String(item.fileName || item.name || '').trim()
      : '';

    if (!dataUrl) {
      const err = new Error(`Certificate #${i + 1} is empty`);
      err.code = 'INVALID_CERTIFICATES';
      throw err;
    }

    if (isHttpUrl(dataUrl)) {
      const mimeType = typeof item === 'object' && item?.mimeType
        ? String(item.mimeType)
        : (dataUrl.toLowerCase().includes('.pdf') ? 'application/pdf' : 'image/jpeg');
      results.push({
        url: dataUrl,
        fileName: fileNameHint || `certificate_${i + 1}`,
        mimeType,
        uploadedAt: item?.uploadedAt ? new Date(item.uploadedAt) : new Date(),
      });
      continue;
    }

    if (!isFileDataUrl(dataUrl)) {
      const err = new Error(`Certificate #${i + 1} must be JPG, PNG, or PDF`);
      err.code = 'INVALID_CERTIFICATES';
      throw err;
    }

    const mimeType = mimeFromDataUrl(dataUrl);
    if (!ALLOWED_MIME.has(mimeType) && mimeType !== 'image/jpg') {
      const err = new Error(`Certificate #${i + 1} must be JPG, PNG, or PDF`);
      err.code = 'INVALID_CERTIFICATES';
      throw err;
    }

    const size = estimateBase64Bytes(dataUrl);
    if (size > MAX_BYTES_PER_FILE) {
      const err = new Error(`Certificate #${i + 1} exceeds the 2 MB size limit`);
      err.code = 'CERTIFICATE_TOO_LARGE';
      throw err;
    }

    const ext = extensionFromDataUrl(dataUrl);
    const fileName = fileNameHint || `certificate_${i + 1}.${ext}`;
    const url = await uploadFileDataUrl(dataUrl, {
      folder: '/vital/certificates',
      fileNamePrefix: `cert_${userId || 'coach'}_${i + 1}`,
      fileName,
      tags: ['certificate', 'coach'],
    });

    results.push({
      url,
      fileName,
      mimeType: mimeType === 'image/jpg' ? 'image/jpeg' : mimeType,
      uploadedAt: new Date(),
    });
  }

  return results;
}

function requireCertificateFiles(files) {
  if (!Array.isArray(files) || files.length === 0) {
    const err = new Error('Upload at least one professional certificate (JPG, PNG, or PDF)');
    err.code = 'CERTIFICATES_REQUIRED';
    throw err;
  }
}

module.exports = {
  MAX_CERTIFICATES,
  MAX_BYTES_PER_FILE,
  resolveCertificateFiles,
  requireCertificateFiles,
};
