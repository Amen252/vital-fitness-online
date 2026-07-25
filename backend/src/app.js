const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const morgan = require('morgan');

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const dietRoutes = require('./routes/dietRoutes');
const activityRoutes = require('./routes/activityRoutes');
const waterRoutes = require('./routes/waterRoutes');
const progressRoutes = require('./routes/progressRoutes');
const coachRoutes = require('./routes/coachRoutes');
const contentRoutes = require('./routes/contentRoutes');
const chatRoutes = require('./routes/chatRoutes');
const adminRoutes = require('./routes/adminRoutes');
const sessionRoutes = require('./routes/sessionRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');

const app = express();

const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:5174',
  'http://127.0.0.1:5174',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
].filter(Boolean);

app.use(cors({
  origin: function (origin, callback) {
    if (
      !origin || 
      allowedOrigins.indexOf(origin) !== -1 ||
      origin.startsWith('http://localhost:') ||
      origin.startsWith('http://127.0.0.1:')
    ) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

app.use(express.json({ limit: '6mb' }));
app.use(cookieParser());
app.use(morgan('dev'));

app.get('/api/health', async (req, res) => {
  const { pingDatabase, scheduleConnectionRetry } = require('./config/db');
  const databaseName = req.app.get('databaseName') || '';
  let dbReady = !!req.app.get('dbReady');

  // readyState can stay "connected" after Atlas IP/TLS drops — verify with a ping.
  if (dbReady) {
    dbReady = await pingDatabase();
    if (!dbReady) {
      req.app.set('dbReady', false);
      scheduleConnectionRetry(req.app);
    }
  }

  res.status(dbReady ? 200 : 503).json({
    status: dbReady ? 'ok' : 'degraded',
    database: dbReady ? 'connected' : 'unavailable',
    databaseName: databaseName || undefined,
    api: `http://127.0.0.1:${process.env.PORT || 5050}/api`,
    ...(dbReady
      ? {}
      : {
          hint:
            'MongoDB Atlas is unreachable. Whitelist this machine’s IP under Atlas → Network Access, then wait for the API to reconnect.',
        }),
  });
});

app.use((req, res, next) => {
  if (req.path === '/api/health') {
    return next();
  }

  if (!req.app.get('dbReady')) {
    return res.status(503).json({
      message: 'Database unavailable. Check that MONGO_URI is set in backend/.env and MongoDB Atlas is reachable, then restart the API.',
    });
  }

  return next();
});

app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/diet', dietRoutes);
app.use('/api/activity', activityRoutes);
app.use('/api/water', waterRoutes);
app.use('/api/progress', progressRoutes);
app.use('/api/coach', coachRoutes);
app.use('/api/content', contentRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/session', sessionRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/share', require('./routes/shareRoutes'));

app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ message: 'Something went wrong' });
});

module.exports = app;
