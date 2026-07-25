const Notification = require('../models/Notification');

function recipientFilter(userId) {
  return {
    $or: [{ user: userId }, { recipient_id: userId }],
  };
}

async function getUserNotifications(req, res) {
  try {
    const notifications = await Notification.find(recipientFilter(req.user._id))
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    return res.json(notifications.map((n) => ({
      _id: n._id,
      message: n.message,
      type: n.type,
      data: n.data || null,
      read: Boolean(n.read || n.read_at),
      createdAt: n.createdAt || n.created_at,
      title: _titleForType(n.type),
    })));
  } catch (error) {
    console.error('getUserNotifications:', error.message);
    return res.status(500).json({ message: 'Error fetching notifications' });
  }
}

async function markNotificationRead(req, res) {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, ...recipientFilter(req.user._id) },
      { read: true, read_at: new Date() },
      { new: true },
    );

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    return res.json({
      _id: notification._id,
      message: notification.message,
      type: notification.type,
      data: notification.data || null,
      read: true,
      createdAt: notification.createdAt,
      title: _titleForType(notification.type),
    });
  } catch (error) {
    console.error('markNotificationRead:', error.message);
    return res.status(500).json({ message: 'Error updating notification' });
  }
}

function _titleForType(type) {
  switch (type) {
    case 'diet':
      return 'Diet Plan';
    case 'reminder':
      return 'Meal Reminder';
    case 'workout':
      return 'Coach Schedule';
    case 'coach_assigned':
      return 'Coach Assigned';
    case 'update':
      return 'Update';
    case 'tip':
      return 'Tip';
    default:
      return 'Notification';
  }
}

module.exports = { getUserNotifications, markNotificationRead };
