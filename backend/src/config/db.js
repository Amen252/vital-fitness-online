const mongoose = require('mongoose');

function getDatabaseName(uri) {
  try {
    const pathname = new URL(uri).pathname.replace(/^\//, '');
    return pathname.split('?')[0] || '';
  } catch {
    const match = String(uri).match(/\/([^/?]+)(\?|$)/);
    return match ? match[1] : '';
  }
}

function isDatabaseConnected() {
  return mongoose.connection.readyState === 1;
}

function isTransientDbError(error) {
  const message = String(error?.message || error || '');
  return (
    error?.name === 'MongoNetworkError'
    || error?.name === 'MongoServerSelectionError'
    || /ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|SSL|TLS|whitelist|server monitor timeout|interrupted/i.test(message)
  );
}

async function pingDatabase() {
  if (!isDatabaseConnected() || !mongoose.connection.db) {
    return false;
  }
  try {
    await mongoose.connection.db.admin().command({ ping: 1 });
    return true;
  } catch (error) {
    console.error('MongoDB ping failed:', error.message);
    return false;
  }
}

function markDatabaseUnavailable(app, reason = '') {
  if (app) {
    app.set('dbReady', false);
  }
  if (reason) {
    console.warn(`MongoDB marked unavailable${reason ? `: ${reason}` : ''}`);
  }
}

function wireDatabaseEvents(app) {
  if (!app || app.get('dbEventsWired')) return;
  app.set('dbEventsWired', true);

  const setReady = (ready) => {
    app.set('dbReady', ready);
    if (!ready) {
      console.warn('MongoDB disconnected — API reads/writes paused until reconnected');
      scheduleConnectionRetry(app);
    }
  };

  mongoose.connection.on('connected', () => setReady(true));
  mongoose.connection.on('reconnected', () => {
    setReady(true);
    console.log('MongoDB reconnected');
  });
  mongoose.connection.on('disconnected', () => setReady(false));
  mongoose.connection.on('error', (error) => {
    console.error('MongoDB connection error:', error.message);
    setReady(false);
  });
}

function isPlaceholderMongoUri(uri) {
  return /xxxxx|<user>|<password>|cluster0\.xxxxx\.mongodb\.net|your-cluster|example\.mongodb\.net/i.test(
    String(uri || ''),
  );
}

async function connectDB() {
  const mongoUri = process.env.MONGO_URI;

  if (!mongoUri) {
    console.warn('MONGO_URI is not set. API will start without a database connection.');
    return false;
  }

  if (isPlaceholderMongoUri(mongoUri)) {
    throw new Error(
      'MONGO_URI still uses a placeholder host (e.g. cluster0.xxxxx.mongodb.net). '
      + 'Set the real Atlas connection string for the existing vitalguide database in backend/.env.',
    );
  }

  const dbName = getDatabaseName(mongoUri);
  const isAtlas = mongoUri.startsWith('mongodb+srv://');
  console.log(
    `Connecting to existing MongoDB database "${dbName || 'default'}"`
    + `${isAtlas ? ' (Atlas)' : ''}…`,
  );

  if (looksLikeTestDb(dbName) && process.env.ALLOW_NON_PRODUCTION_DB !== 'true') {
    throw new Error(
      `Refusing to connect to non-production database "${dbName}". `
      + 'Set ALLOW_NON_PRODUCTION_DB=true only if this is intentional.',
    );
  }

  if (mongoose.connection.readyState === 1) {
    console.log(`MongoDB already connected (${dbName || 'default database'})`);
    return true;
  }

  // Drop a stale socket pool before reconnecting (common after Atlas IP/TLS drops).
  if (mongoose.connection.readyState !== 0) {
    try {
      await mongoose.disconnect();
    } catch {
      // Continue — connect will replace the pool.
    }
  }

  await mongoose.connect(mongoUri, {
    // Avoid unexpected query behavior; prefer explicit update operators everywhere.
    sanitizeFilter: true,
    serverSelectionTimeoutMS: 10000,
    socketTimeoutMS: 45000,
    maxPoolSize: 10,
  });
  console.log(`MongoDB connected (${dbName || 'default database'})`);
  return true;
}

function looksLikeTestDb(dbName) {
  return /test|dev|sandbox|staging/i.test(dbName);
}

let retryTimer = null;

function scheduleConnectionRetry(app, onConnected) {
  if (retryTimer || isDatabaseConnected() || !process.env.MONGO_URI) return;

  const dbName = getDatabaseName(process.env.MONGO_URI);
  console.warn(
    `Will retry MongoDB "${dbName}" every 30s. `
    + 'If using Atlas, add your IP under Network Access: https://cloud.mongodb.com',
  );

  retryTimer = setInterval(async () => {
    if (isDatabaseConnected()) {
      clearInterval(retryTimer);
      retryTimer = null;
      return;
    }
    try {
      const ok = await connectDB();
      if (!ok || !app) return;
      app.set('dbReady', true);
      if (typeof onConnected === 'function') onConnected();
      clearInterval(retryTimer);
      retryTimer = null;
    } catch {
      // Keep retrying until Atlas/network access is fixed.
    }
  }, 30000);
}

module.exports = connectDB;
module.exports.isDatabaseConnected = isDatabaseConnected;
module.exports.isTransientDbError = isTransientDbError;
module.exports.pingDatabase = pingDatabase;
module.exports.markDatabaseUnavailable = markDatabaseUnavailable;
module.exports.wireDatabaseEvents = wireDatabaseEvents;
module.exports.getDatabaseName = getDatabaseName;
module.exports.scheduleConnectionRetry = scheduleConnectionRetry;
