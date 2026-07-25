const Session = require('../models/Session');
const CoachAssignment = require('../models/CoachAssignment');
const User = require('../models/User');
const { isApprovedPublicCoach } = require('../utils/coachProfile');
const { USER_DISPLAY_SELECT } = require('../utils/userDisplay');

exports.bookSession = async (req, res) => {
  try {
    const { coachId, clientId, date, durationMinutes, notes } = req.body;
    
    if (req.user.role === 'user' && !coachId) {
      return res.status(400).json({ message: 'Coach ID and date are required' });
    }
    if (req.user.role === 'coach' && !clientId) {
      return res.status(400).json({ message: 'Client ID and date are required' });
    }
    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const client = req.user.role === 'coach' ? clientId : req.user.id;
    const coach = req.user.role === 'coach' ? req.user.id : coachId;

    if (req.user.role === 'user') {
      const coachUser = await User.findById(coach);
      if (!coachUser || !isApprovedPublicCoach(coachUser)) {
        return res.status(404).json({ message: 'Coach not found' });
      }
    }

    const assignment = await CoachAssignment.findOne({
      user: client,
      coach,
      status: 'active',
    });
    if (!assignment) {
      return res.status(403).json({ message: 'Sessions are only available with your assigned coach' });
    }

    const session = await Session.create({
      client,
      coach,
      date,
      durationMinutes,
      notes,
      status: 'confirmed',
    });

    const populated = await Session.findById(session._id).populate('client coach', USER_DISPLAY_SELECT);
    res.status(201).json(populated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getSessions = async (req, res) => {
  try {
    const query = {};
    if (req.user.role === 'coach') {
      query.coach = req.user.id;
    } else if (req.user.role === 'user') {
      query.client = req.user.id;
    }
    
    const sessions = await Session.find(query).populate('client coach', USER_DISPLAY_SELECT).sort({ date: 1 });
    res.json(sessions);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateSessionStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    const session = await Session.findById(id);
    if (!session) return res.status(404).json({ message: 'Session not found' });
    
    // Authorization check
    if (req.user.role !== 'admin' && String(session.coach) !== req.user.id && String(session.client) !== req.user.id) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    
    session.status = status;
    await session.save();
    
    res.json(session);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
