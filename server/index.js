const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRouter = require('./routes/auth');
const attendanceRouter = require('./routes/attendance');
const profileRouter = require('./routes/profile');
const leavesRouter = require('./routes/leaves');
const expensesRouter = require('./routes/expenses');
const loansRouter = require('./routes/loans');
const tasksRouter = require('./routes/tasks');
const announcementsRouter = require('./routes/announcements');
const miscRouter = require('./routes/misc');
const dbRouter = require('./routes/db');
const adminRouter = require('./routes/admin');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRouter);
app.use('/api/attendance', attendanceRouter);
app.use('/api/profile', profileRouter);
app.use('/api/leaves', leavesRouter);
app.use('/api/expenses', expensesRouter);
app.use('/api/loans', loansRouter);
app.use('/api/tasks', tasksRouter);
app.use('/api/announcements', announcementsRouter);
app.use('/api/misc', miscRouter);
app.use('/api/db', dbRouter);
app.use('/api/admin', adminRouter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', time: new Date() });
});

// Root endpoint redirect or welcome
app.get('/', (req, res) => {
  res.send('Welcome to LogHR Custom API Backend Server');
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start Server
app.listen(PORT, () => {
  console.log(`🚀 LogHR Backend Server running on port ${PORT}`);
});
