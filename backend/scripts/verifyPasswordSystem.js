require('dotenv').config();
const http = require('http');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../src/models/User');
const { isBcryptHash } = require('../src/utils/passwordUtils');

function req(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: '127.0.0.1',
      port: 5050,
      path: '/api' + path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
      },
    };
    const r = http.request(opts, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        let parsed = raw;
        try {
          parsed = JSON.parse(raw);
        } catch (_) {}
        resolve({ status: res.statusCode, body: parsed });
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

(async () => {
  await mongoose.connect(process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/vitalguide');

  let failed = 0;
  const check = (label, ok, detail = '') => {
    console.log(`${ok ? 'OK' : 'FAIL'} ${label}${detail ? ` — ${detail}` : ''}`);
    if (!ok) failed += 1;
  };

  const email = `pwtest.${Date.now()}@example.com`;
  const password = 'SecurePass1';
  const newPassword = 'NewSecure2';

  const register = await req('POST', '/auth/register', {
    name: 'Password Test',
    email,
    password,
    role: 'user',
  });
  check('register', register.status === 201, String(register.status));

  const stored = await User.findOne({ email }).select('+password');
  check('stored hash is bcrypt', isBcryptHash(stored?.password), stored?.password?.slice(0, 10));

  const login = await req('POST', '/auth/login', { email: email.toUpperCase(), password });
  check('login case-insensitive email', login.status === 200 && !!login.body?.token, String(login.status));

  const badLogin = await req('POST', '/auth/login', { email, password: 'wrong-password' });
  check('bad password rejected', badLogin.status === 401, String(badLogin.status));

  const token = login.body?.token;
  const change = await req(
    'POST',
    '/auth/change-password',
    { currentPassword: password, newPassword },
    token,
  );
  check('change password', change.status === 200, String(change.status));

  const reloginOld = await req('POST', '/auth/login', { email, password });
  check('old password no longer works', reloginOld.status === 401, String(reloginOld.status));

  const reloginNew = await req('POST', '/auth/login', { email, password: newPassword });
  check('new password works', reloginNew.status === 200, String(reloginNew.status));

  const forgot = await req('POST', '/auth/forgot-password', { email });
  check('forgot password', forgot.status === 200, String(forgot.status));

  const withReset = await User.findOne({ email }).select('+resetPasswordCode +resetPasswordExpires');
  check('reset code stored hashed', isBcryptHash(withReset?.resetPasswordCode), '');

  // Use a known code by setting directly for test only
  const resetCode = '123456';
  await User.updateOne(
    { _id: withReset._id },
    {
      resetPasswordCode: await bcrypt.hash(resetCode, 10),
      resetPasswordExpires: new Date(Date.now() + 15 * 60 * 1000),
    },
  );

  const reset = await req('POST', '/auth/reset-password', {
    email,
    code: resetCode,
    newPassword: 'ResetPass3',
  });
  check('reset password', reset.status === 200, String(reset.status));

  const afterReset = await req('POST', '/auth/login', { email, password: 'ResetPass3' });
  check('login after reset', afterReset.status === 200, String(afterReset.status));

  await User.deleteOne({ email });
  await mongoose.disconnect();
  process.exit(failed > 0 ? 1 : 0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
