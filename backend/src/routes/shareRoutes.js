const express = require('express');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');
const {
  createShareCard,
  getShareCard,
  getMyInvite,
  getInviteStats,
} = require('../controllers/shareController');

const router = express.Router();

router.get('/cards/:token', getShareCard);
router.post('/cards', auth, roles('user'), createShareCard);
router.get('/invite', auth, roles('user'), getMyInvite);
router.get('/invite/stats', auth, roles('user'), getInviteStats);

module.exports = router;
