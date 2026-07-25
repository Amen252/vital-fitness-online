const express = require('express');
const { createActivityLog, getActivityHistory } = require('../controllers/activityController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.post('/log', auth, roles('user', 'admin'), createActivityLog);
router.get('/history', auth, roles('user', 'admin'), getActivityHistory);

module.exports = router;
