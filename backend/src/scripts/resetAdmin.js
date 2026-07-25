const mongoose = require('mongoose');
const path = require('path');
const User = require('../models/User');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const ADMIN_USERNAME = 'admin@gmail.com';
const ADMIN_PASSWORD = '123123';

async function reset() {
  try {
    await mongoose.connect(process.env.MONGO_URI);

    // Prefer the shared admin identity used by web + mobile
    let admin = await User.findOne({ username: ADMIN_USERNAME });

    // Migrate legacy username "admin" if present and email-admin does not exist yet
    if (!admin) {
      const legacy = await User.findOne({ username: 'admin', role: 'admin' });
      if (legacy) {
        legacy.username = ADMIN_USERNAME;
        admin = legacy;
      }
    }

    if (admin) {
      admin.password = ADMIN_PASSWORD;
      admin.role = 'admin';
      admin.full_name = admin.full_name || 'System Admin';
      admin.status = 'active';
      admin.must_change_password = false;
      admin.login_attempts = 0;
      admin.lock_until = null;
      admin.adminData = { permissions: 'super-admin' };
      await admin.save();
      console.log(`Reset admin "${ADMIN_USERNAME}" password to "${ADMIN_PASSWORD}"`);
    } else {
      await User.create({
        username: ADMIN_USERNAME,
        password: ADMIN_PASSWORD,
        role: 'admin',
        full_name: 'System Admin',
        status: 'active',
        must_change_password: false,
        adminData: { permissions: 'super-admin' },
      });
      console.log(`Created admin "${ADMIN_USERNAME}" with password "${ADMIN_PASSWORD}"`);
    }

    const verified = await User.findOne({ username: ADMIN_USERNAME }).select('+password');
    const ok = verified && (await verified.comparePassword(ADMIN_PASSWORD));
    console.log(
      ok
        ? `Verified: role=${verified.role}, must_change_password=${verified.must_change_password}`
        : 'Verification FAILED',
    );
  } catch (err) {
    console.error('Error resetting admin:', err);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect().catch(() => {});
    process.exit(process.exitCode || 0);
  }
}

reset();
