require('dotenv').config();

const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const CoachAssignment = require('./models/CoachAssignment');
const app = require('./app');
const connectDB = require('./config/db');
const {
  wireDatabaseEvents,
  scheduleConnectionRetry,
  getDatabaseName,
} = require('./config/db');
const { startWorkoutScheduleReminderJob } = require('./jobs/workoutScheduleReminders');
const { startAppointmentReminderJob } = require('./jobs/appointmentReminders');

const port = process.env.PORT || 5050;
const server = http.createServer(app);

function isAllowedOrigin(origin) {
  if (!origin) return true;
  const allowed = [
    process.env.CLIENT_URL,
    'http://localhost:5173',
    'http://127.0.0.1:5173',
    'http://localhost:5174',
    'http://127.0.0.1:5174',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ].filter(Boolean);
  return (
    allowed.includes(origin) ||
    origin.startsWith('http://localhost:') ||
    origin.startsWith('http://127.0.0.1:')
  );
}

const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      if (isAllowedOrigin(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
  },
});

// Graceful shutdown to prevent EADDRINUSE
const shutdown = (signal) => {
  console.log(`Received ${signal}. Shutting down server...`);
  server.close(() => {
    console.log('Server closed.');
    process.exit(0);
  });
  // Force exit after 3 seconds
  setTimeout(() => process.exit(1), 3000);
};

process.once('SIGUSR2', () => {
  server.close(() => {
    process.kill(process.pid, 'SIGUSR2');
  });
});
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

io.use((socket, next) => {
  const token = socket.handshake.auth?.token;

  if (!token) {
    return next(new Error('Unauthorized'));
  }

  try {
    socket.user = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');
    return next();
  } catch (error) {
    return next(new Error('Unauthorized'));
  }
});

io.on('connection', (socket) => {
  socket.on('thread:join', async (assignmentId) => {
    if (!assignmentId) {
      socket.emit('thread:error', { message: 'Missing assignment id' });
      return;
    }

    const query = { _id: assignmentId };
    if (socket.user.role === 'coach') {
      query.coach = socket.user.id;
    } else if (socket.user.role === 'user') {
      query.user = socket.user.id;
    }
    // Admins bypass role check

    const assignment = await CoachAssignment.findOne(query).select('_id');
    if (!assignment) {
      socket.emit('thread:error', { message: 'Unauthorized thread access' });
      return;
    }

    socket.join(String(assignment._id));
  });

  socket.on('message:read', ({ assignmentId, messageId }) => {
    io.to(assignmentId).emit('message:read', { messageId });
  });
});

app.set('io', io);
app.set('databaseName', getDatabaseName(process.env.MONGO_URI || ''));
wireDatabaseEvents(app);

function startBackgroundJobs() {
  if (app.get('backgroundJobsStarted')) return;
  app.set('backgroundJobsStarted', true);
  startWorkoutScheduleReminderJob();
  startAppointmentReminderJob();
}

connectDB()
  .then((dbReady) => {
    app.set('dbReady', dbReady);
    if (dbReady) startBackgroundJobs();
  })
  .catch((error) => {
    app.set('dbReady', false);
    console.error('Database connection failed:', error.message);
    scheduleConnectionRetry(app, startBackgroundJobs);
  })
  .finally(() => {
    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        const healthUrl = `http://127.0.0.1:${port}/api/health`;
        http.get(healthUrl, (res) => {
          let body = '';
          res.on('data', (chunk) => { body += chunk; });
          res.on('end', () => {
            if (res.statusCode === 200) {
              console.log(`Port ${port} is already in use — VitalFitness API is already running.`);
              console.log(`  ${healthUrl}`);
              console.log('No action needed. Run your Flutter app, or use "npm run restart" to restart.');
              process.exit(0);
            }
            console.error(`Port ${port} is in use but the health check failed.`);
            console.error(`Free the port: lsof -ti :${port} | xargs kill`);
            process.exit(1);
          });
        }).on('error', () => {
          console.error(`Port ${port} is already in use by another process.`);
          console.error(`Free the port: lsof -ti :${port} | xargs kill`);
          console.error('Then run: npm start');
          process.exit(1);
        });
        return;
      }

      console.error('Server failed to start:', err.message);
      process.exit(1);
    });

    server.listen(port, () => {
      console.log(`API listening on port ${port}`);
      const dbName = app.get('databaseName');
      if (dbName) {
        console.log(`Database target: ${dbName} (web + mobile share this via API)`);
      }
      if (!app.get('dbReady')) {
        console.warn(
          'MongoDB is not connected yet — API reads/writes return 503 until Atlas is reachable.',
        );
      }
    });
  });
