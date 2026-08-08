/**
 * OCR-based validation: certificate images must show a person's first + last name
 * (like a typical fitness trainer certificate), preferably matching the applicant.
 *
 * Uses tesseract.js in-process (no new external OCR service / database).
 * Disable with CERTIFICATE_NAME_VALIDATION=off when needed.
 */

const CERTIFICATE_STOP_WORDS = new Set([
  'this', 'that', 'the', 'and', 'for', 'has', 'her', 'his', 'she', 'he', 'now',
  'are', 'was', 'were', 'with', 'from', 'into', 'onto', 'your', 'you', 'our',
  'certificate', 'certified', 'certify', 'certifies', 'certification',
  'fitness', 'trainer', 'training', 'trainers', 'coach', 'coaching',
  'passed', 'pass', 'allowed', 'conduct', 'group', 'one', 'sessions',
  'session', 'issued', 'issue', 'head', 'extreme', 'gym', 'studio',
  'professional', 'national', 'academy', 'institute', 'association',
  'diploma', 'award', 'awarded', 'completion', 'program', 'course',
  'level', 'basic', 'advanced', 'july', 'june', 'august', 'september',
  'october', 'november', 'december', 'january', 'february', 'march', 'april',
  'may', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  'personal', 'strength', 'conditioning', 'nutrition', 'yoga', 'pilates',
  'of', 'to', 'in', 'on', 'by', 'a', 'an', 'is', 'be', 'or', 'as', 'at',
]);

function isNameValidationEnabled() {
  const raw = String(process.env.CERTIFICATE_NAME_VALIDATION || 'on').trim().toLowerCase();
  return !['0', 'false', 'off', 'no', 'disabled'].includes(raw);
}

function normalizeNamePart(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z]/g, '');
}

function splitExpectedName(expectedName) {
  return String(expectedName || '')
    .trim()
    .split(/\s+/)
    .map((part) => normalizeNamePart(part))
    .filter((part) => part.length >= 2);
}

function tokenizeOcrText(text) {
  return String(text || '')
    .replace(/[^A-Za-z\s'-]/g, ' ')
    .split(/\s+/)
    .map((token) => token.replace(/^['-]+|['-]+$/g, ''))
    .filter(Boolean);
}

/**
 * Find consecutive name-like pairs in OCR text (e.g. "Vanessa Suarez").
 */
function findPersonNamePairs(text) {
  const tokens = tokenizeOcrText(text);
  const pairs = [];
  for (let i = 0; i < tokens.length - 1; i += 1) {
    const first = normalizeNamePart(tokens[i]);
    const second = normalizeNamePart(tokens[i + 1]);
    if (first.length < 2 || second.length < 2) continue;
    if (CERTIFICATE_STOP_WORDS.has(first) || CERTIFICATE_STOP_WORDS.has(second)) continue;
    // Avoid all-stop / month-number noise; require alphabetic person-like tokens.
    if (/^\d+$/.test(first) || /^\d+$/.test(second)) continue;
    pairs.push({ first, second, display: `${tokens[i]} ${tokens[i + 1]}` });
  }
  return pairs;
}

function textContainsNameParts(text, parts) {
  if (!parts.length) return false;
  const hay = tokenizeOcrText(text).map(normalizeNamePart).filter(Boolean);
  const haySet = new Set(hay);
  return parts.every((part) => haySet.has(part));
}

/**
 * Validate OCR text contains a first+last name, and matches applicant when provided.
 * @returns {{ ok: true, matchedName?: string } | { ok: false, code: string, message: string }}
 */
function evaluateCertificateNameText(ocrText, { expectedName, index = 1 } = {}) {
  const text = String(ocrText || '').trim();
  if (!text) {
    return {
      ok: false,
      code: 'CERTIFICATE_NAME_REQUIRED',
      message: `Certificate #${index} text could not be read. Upload a clearer JPG/PNG where the full name is visible.`,
    };
  }

  const pairs = findPersonNamePairs(text);
  if (!pairs.length) {
    return {
      ok: false,
      code: 'CERTIFICATE_NAME_REQUIRED',
      message: `Certificate #${index} must clearly show a first and last name (for example "Vanessa Suarez").`,
    };
  }

  const expectedParts = splitExpectedName(expectedName);
  if (!expectedParts.length) {
    return { ok: true, matchedName: pairs[0].display };
  }

  // Prefer exact first+last present in OCR.
  if (expectedParts.length >= 2) {
    const first = expectedParts[0];
    const last = expectedParts[expectedParts.length - 1];
    const pairMatch = pairs.some((p) => p.first === first && p.second === last);
    const looseMatch = textContainsNameParts(text, [first, last]);
    if (pairMatch || looseMatch) {
      return { ok: true, matchedName: `${first} ${last}` };
    }
    return {
      ok: false,
      code: 'CERTIFICATE_NAME_MISMATCH',
      message: `Certificate #${index} must show the applicant name "${expectedName}". First and last name were not found on the image.`,
    };
  }

  // Single registered name (e.g. "Ladan"): must appear plus another name-like word.
  const only = expectedParts[0];
  const hasApplicant = pairs.some((p) => p.first === only || p.second === only)
    || textContainsNameParts(text, [only]);
  if (!hasApplicant) {
    return {
      ok: false,
      code: 'CERTIFICATE_NAME_MISMATCH',
      message: `Certificate #${index} must show the applicant name "${expectedName}" as a first and last name on the document.`,
    };
  }
  return { ok: true, matchedName: pairs.find((p) => p.first === only || p.second === only)?.display || pairs[0].display };
}

let _workerPromise = null;

async function getOcrWorker() {
  if (!_workerPromise) {
    _workerPromise = (async () => {
      const { createWorker } = require('tesseract.js');
      const worker = await createWorker('eng');
      return worker;
    })().catch((error) => {
      _workerPromise = null;
      throw error;
    });
  }
  return _workerPromise;
}

async function recognizeCertificateText(imageSource) {
  const worker = await getOcrWorker();
  const { data } = await worker.recognize(imageSource);
  return String(data?.text || '');
}

/**
 * Validate a certificate image (data URL or uploaded CDN URL) shows first+last name.
 * Prefer calling this AFTER ImageKit upload with the public URL.
 */
async function assertCertificateImageShowsName(imageSource, { expectedName, index = 1 } = {}) {
  if (!isNameValidationEnabled()) {
    return { ok: true, skipped: true };
  }

  const source = String(imageSource || '').trim();
  if (!source) {
    const err = new Error(
      `Certificate #${index} could not be scanned. Upload a clear JPG or PNG of your certificate.`,
    );
    err.code = 'CERTIFICATE_OCR_FAILED';
    throw err;
  }

  let text = '';
  try {
    text = await recognizeCertificateText(source);
  } catch (error) {
    console.error('[CERT OCR]', error.message);
    const err = new Error(
      `Certificate #${index} could not be scanned. Upload a clear JPG or PNG of your certificate.`,
    );
    err.code = 'CERTIFICATE_OCR_FAILED';
    throw err;
  }

  const result = evaluateCertificateNameText(text, { expectedName, index });
  if (!result.ok) {
    const err = new Error(result.message);
    err.code = result.code;
    throw err;
  }
  return result;
}

module.exports = {
  isNameValidationEnabled,
  evaluateCertificateNameText,
  findPersonNamePairs,
  assertCertificateImageShowsName,
  splitExpectedName,
};
