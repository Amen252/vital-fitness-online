#!/usr/bin/env node
/**
 * Quick check: can this machine reach MONGO_URI?
 * Usage: cd backend && node scripts/check-db.js
 * Never prints the full URI / password.
 */
require('dotenv').config();
const mongoose = require('mongoose');

function redact(message) {
  return String(message).replace(/mongodb(\+srv)?:\/\/[^@\s]+@/gi, 'mongodb$1://***@');
}

async function main() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error('MONGO_URI is missing. Set it in backend/.env or the shell.');
    process.exit(1);
  }

  let host = '(unknown)';
  let db = '(unknown)';
  try {
    const parsed = new URL(uri.replace(/^mongodb\+srv/, 'https').replace(/^mongodb/, 'http'));
    host = parsed.hostname;
    db = (parsed.pathname || '/').replace(/^\//, '') || '(default)';
  } catch {
    console.error('MONGO_URI is not a valid MongoDB connection string.');
    process.exit(1);
  }

  console.log(`Host: ${host}`);
  console.log(`Database: ${db}`);
  console.log('Connecting…');

  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000 });
    await mongoose.connection.db.admin().command({ ping: 1 });
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('OK — MongoDB is reachable');
    console.log(`Collections: ${collections.length}`);
    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('FAILED — cannot reach MongoDB');
    console.error(redact(error.message));
    console.error('');
    console.error('Fix: MongoDB Atlas → Network Access → Add IP Address');
    console.error('  - For local: add your current IP');
    console.error('  - For Render/Heroku: Allow Access from Anywhere (0.0.0.0/0)');
    process.exit(1);
  }
}

main();
