const Message = require('../models/Message');
const CoachAssignment = require('../models/CoachAssignment');
const Notification = require('../models/Notification');
const { USER_DISPLAY_SELECT } = require('../utils/userDisplay');

async function findAccessibleAssignment(assignmentId, user) {
  const query = { _id: assignmentId };
  if (user.role === 'coach') {
    query.coach = user._id;
    query.status = 'active';
  } else if (user.role === 'user') {
    query.user = user._id;
    query.status = 'active';
  }
  // Admins have unrestricted access (no additional filter in query)

  return CoachAssignment.findOne(query).populate('user coach', USER_DISPLAY_SELECT);
}

async function listThreads(req, res) {
  let query = {};
  if (req.user.role === 'coach') {
    query = { coach: req.user._id, status: 'active' };
  } else if (req.user.role === 'user') {
    query = { user: req.user._id, status: 'active' };
  }
  // Admin query stays empty to fetch all assignments

  const assignments = await CoachAssignment.find(query)
    .populate('user', USER_DISPLAY_SELECT)
    .populate('coach', USER_DISPLAY_SELECT)
    .sort({ updatedAt: -1 });

  const threadSummaries = await Promise.all(
    assignments.map(async (assignment) => {
      const lastMessage = await Message.findOne({ assignment: assignment._id }).sort({ createdAt: -1 });
      const unreadCount = await Message.countDocuments({
        assignment: assignment._id,
        receiver: req.user._id,
        read: false,
      });
      let counterpart;
      if (req.user.role === 'admin') {
        counterpart = assignment.user; // Admins view by user
      } else {
        counterpart = req.user.role === 'coach' ? assignment.user : assignment.coach;
      }

      return {
        assignmentId: assignment._id,
        _id: assignment._id,
        user: counterpart,
        counterpart,
        lastMessage,
        unreadCount,
        updatedAt: assignment.updatedAt,
      };
    })
  );

  return res.json(threadSummaries);
}

async function getThread(req, res) {
  const assignment = await findAccessibleAssignment(req.params.assignmentId, req.user);
  if (!assignment) {
    return res.status(404).json({ message: 'Chat thread not found' });
  }

  const markRead = req.query.markRead !== 'false';
  if (markRead) {
    await Message.updateMany(
      { assignment: assignment._id, receiver: req.user._id, read: false },
      { $set: { read: true } },
    );
  }

  const messages = await Message.find({ assignment: assignment._id })
    .populate('sender', USER_DISPLAY_SELECT)
    .sort({ createdAt: 1 });

  const payload = messages.map((message) => {
    const doc = message.toObject();
    doc.senderRole = message.sender?.role;
    if (markRead && String(message.receiver) === String(req.user._id)) {
      doc.read = true;
    }
    return doc;
  });

  return res.json(payload);
}

async function createMessage(req, res) {
  console.log('[CHAT] createMessage request:', { body: req.body, user: req.user?._id });
  const assignment = await findAccessibleAssignment(req.body.assignmentId, req.user);
  if (!assignment) {
    console.warn('[CHAT] Assignment not found or inaccessible:', req.body.assignmentId);
    return res.status(404).json({ message: 'Coach assignment not found' });
  }

  let receiverId;
  if (req.user.role === 'coach' || req.user.role === 'admin') {
    receiverId = assignment.user?._id;
  } else {
    receiverId = assignment.coach?._id;
  }
  console.log('[CHAT] Identified receiver:', receiverId);

  if (!receiverId) {
    return res.status(400).json({ message: 'Chat receiver unavailable for this assignment' });
  }

  const message = await Message.create({
    assignment: assignment._id,
    sender: req.user._id,
    receiver: receiverId,
    body: req.body.body,
  });

  const senderName = req.user.name || 'Someone';
  const notificationMessage = req.user.role === 'coach'
    ? `${senderName} sent you a message.`
    : `${senderName} sent you a message.`;

  await Notification.create({
    user: receiverId,
    message: notificationMessage,
    type: 'update',
  });

  const populated = await Message.findById(message._id).populate('sender', USER_DISPLAY_SELECT);
  const payload = populated.toObject();
  payload.senderRole = req.user.role;

  const io = req.app.get('io');
  io?.to(String(assignment._id)).emit('message:receive', payload);

  return res.status(201).json(payload);
}

async function updateMessage(req, res) {
  try {
    const body = String(req.body.body ?? '').trim();
    if (!body) {
      return res.status(400).json({ message: 'Message body is required' });
    }

    const message = await Message.findById(req.params.id);
    if (!message) {
      return res.status(404).json({ message: 'Message not found' });
    }
    if (String(message.sender) !== String(req.user._id)) {
      return res.status(403).json({ message: 'You can only edit your own messages' });
    }

    const assignment = await findAccessibleAssignment(message.assignment, req.user);
    if (!assignment) {
      return res.status(404).json({ message: 'Message not found' });
    }

    message.body = body;
    message.editedAt = new Date();
    await message.save();

    const populated = await Message.findById(message._id).populate('sender', USER_DISPLAY_SELECT);
    const payload = populated.toObject();
    payload.senderRole = populated.sender?.role;

    const io = req.app.get('io');
    io?.to(String(message.assignment)).emit('message:update', payload);

    return res.json(payload);
  } catch (error) {
    return res.status(500).json({ message: 'Unable to update message' });
  }
}

async function deleteMessage(req, res) {
  try {
    const message = await Message.findById(req.params.id);
    if (!message) {
      return res.status(404).json({ message: 'Message not found' });
    }
    if (String(message.sender) !== String(req.user._id)) {
      return res.status(403).json({ message: 'You can only delete your own messages' });
    }

    const assignment = await findAccessibleAssignment(message.assignment, req.user);
    if (!assignment) {
      return res.status(404).json({ message: 'Message not found' });
    }

    const messageId = message._id;
    const assignmentId = message.assignment;
    await message.deleteOne();

    const io = req.app.get('io');
    io?.to(String(assignmentId)).emit('message:delete', { _id: messageId, assignmentId });

    return res.json({ message: 'Message deleted', _id: messageId });
  } catch (error) {
    return res.status(500).json({ message: 'Unable to delete message' });
  }
}

module.exports = { listThreads, getThread, createMessage, updateMessage, deleteMessage };
