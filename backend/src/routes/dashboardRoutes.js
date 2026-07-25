const express = require('express');
const { getAdminDashboard, getCoachDashboard, getUserDashboard } = require('../controllers/dashboardController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.get('/admin', auth, roles('admin'), getAdminDashboard);
router.get('/coach', auth, roles('coach'), getCoachDashboard);
router.get('/user', auth, roles('user'), getUserDashboard);

module.exports = router;
