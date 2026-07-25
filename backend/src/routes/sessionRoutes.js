const express = require('express');
const { bookSession, getSessions, updateSessionStatus } = require('../controllers/sessionController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.post('/', auth, roles('user', 'coach'), bookSession);
router.get('/', auth, getSessions);
router.patch('/:id/status', auth, updateSessionStatus);

module.exports = router;
