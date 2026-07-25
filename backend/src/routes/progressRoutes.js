const express = require('express');
const { getProgress, logWeight } = require('../controllers/progressController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.get('/', auth, roles('user', 'admin'), getProgress);
router.post('/weight', auth, roles('user', 'admin'), logWeight);

module.exports = router;
