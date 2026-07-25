const express = require('express');
const { createWaterLog, getWaterHistory } = require('../controllers/waterController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.post('/log', auth, roles('user', 'admin'), createWaterLog);
router.get('/history', auth, roles('user', 'admin'), getWaterHistory);

module.exports = router;
