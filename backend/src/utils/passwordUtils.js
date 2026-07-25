const bcrypt = require('bcryptjs');

const BCRYPT_ROUNDS = 10;
const MIN_PASSWORD_LENGTH = 6;
const MAX_PASSWORD_LENGTH = 128;
const BCRYPT_HASH_PATTERN = /^\$2[aby]\$\d{2}\$.{53}$/;
const GENERATED_PASSWORD_LENGTH = 12;
const GENERATED_PASSWORD_ALPHABET =
  'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function generateInitialPassword(length = GENERATED_PASSWORD_LENGTH) {
  const crypto = require('crypto');
  const bytes = crypto.randomBytes(length);
  let password = '';
  for (let i = 0; i < length; i += 1) {
    password += GENERATED_PASSWORD_ALPHABET[bytes[i] % GENERATED_PASSWORD_ALPHABET.length];
  }
  return password;
}

function isBcryptHash(value) {
  return typeof value === 'string' && BCRYPT_HASH_PATTERN.test(value);
}

function validatePasswordPolicy(password) {
  const value = String(password ?? '');
  if (!value) {
    return 'Password is required';
  }
  if (value.length < MIN_PASSWORD_LENGTH) {
    return `Password must be at least ${MIN_PASSWORD_LENGTH} characters`;
  }
  if (value.length > MAX_PASSWORD_LENGTH) {
    return `Password must be at most ${MAX_PASSWORD_LENGTH} characters`;
  }
  return null;
}

async function hashPassword(plainPassword) {
  const policyError = validatePasswordPolicy(plainPassword);
  if (policyError) {
    throw new Error(policyError);
  }
  return bcrypt.hash(String(plainPassword), BCRYPT_ROUNDS);
}

async function comparePassword(plainPassword, hashedPassword) {
  if (plainPassword == null || hashedPassword == null || hashedPassword === '') {
    return false;
  }

  const candidate = String(plainPassword);
  const stored = String(hashedPassword);

  // Prefer bcrypt. Fall back to exact match only for rare legacy plaintext rows
  // so accounts aren't permanently locked after a bad write.
  if (isBcryptHash(stored)) {
    return bcrypt.compare(candidate, stored);
  }
  return candidate === stored;
}

async function hashPasswordIfNeeded(password) {
  if (!password) {
    return password;
  }
  if (isBcryptHash(password)) {
    return password;
  }
  return hashPassword(password);
}

async function ensureHashedPassword(userDoc, plainPassword) {
  if (!userDoc || isBcryptHash(userDoc.password)) {
    return false;
  }
  userDoc.password = plainPassword;
  userDoc.markModified('password');
  await userDoc.save();
  return true;
}

module.exports = {
  BCRYPT_ROUNDS,
  MIN_PASSWORD_LENGTH,
  MAX_PASSWORD_LENGTH,
  normalizeEmail,
  generateInitialPassword,
  isBcryptHash,
  validatePasswordPolicy,
  hashPassword,
  comparePassword,
  hashPasswordIfNeeded,
  ensureHashedPassword,
};
