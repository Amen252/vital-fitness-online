const express = require('express');
const { createDietLog, getDietHistory, getSuggestedPlan } = require('../controllers/dietController');
const {
  getUserAssignedDietPlan,
  getUserDietPlanHistory,
  getUserDietProgress,
  logUserAdherence,
} = require('../controllers/dietPlanController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

router.post('/log', auth, roles('user', 'admin'), createDietLog);
router.get('/history', auth, roles('user', 'admin'), getDietHistory);
router.get('/suggested-plan', auth, roles('user', 'admin'), getSuggestedPlan);
router.get('/plan', auth, roles('user', 'coach'), getUserAssignedDietPlan);
router.get('/plan-history', auth, roles('user', 'admin'), getUserDietPlanHistory);
router.get('/progress', auth, roles('user', 'admin'), getUserDietProgress);
router.post('/adherence', auth, roles('user', 'admin'), logUserAdherence);

module.exports = router;

