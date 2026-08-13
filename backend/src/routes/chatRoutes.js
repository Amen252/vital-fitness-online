const express = require('express');
const { createMessage, getThread, listThreads, updateMessage, deleteMessage } = require('../controllers/chatController');
const auth = require('../middleware/auth');
const requireApprovedCoachIfCoach = require('../middleware/requireApprovedCoachIfCoach');

const router = express.Router();

router.use(auth, requireApprovedCoachIfCoach);

router.get('/threads', listThreads);
router.get('/threads/:assignmentId', getThread);
router.post('/message', createMessage);
router.patch('/message/:id', updateMessage);
router.delete('/message/:id', deleteMessage);

module.exports = router;
