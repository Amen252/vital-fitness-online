const express = require('express');
const { createMessage, getThread, listThreads, updateMessage, deleteMessage } = require('../controllers/chatController');
const auth = require('../middleware/auth');

const router = express.Router();

router.get('/threads', auth, listThreads);
router.get('/threads/:assignmentId', auth, getThread);
router.post('/message', auth, createMessage);
router.patch('/message/:id', auth, updateMessage);
router.delete('/message/:id', auth, deleteMessage);

module.exports = router;
