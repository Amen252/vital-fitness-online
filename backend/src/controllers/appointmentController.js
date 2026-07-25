const Appointment = require('../models/Appointment');
const CoachAssignment = require('../models/CoachAssignment');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const FitnessClass = require('../models/FitnessClass');
const Notification = require('../models/Notification');
const User = require('../models/User');
const {
  DEFAULT_WORK_START,
  DEFAULT_WORK_END,
  DEFAULT_DURATION,
  getDayName,
  getDayNameFromDateStr,
  generateSlotTimes,
  parseSlotDateTime,
  parseSlotDateTimeInOffset,
  parseTimezoneOffsetMinutes,
  wallClockHHMM,
  isValidSlotTime,
  getHoursForDay,
} = require('../utils/appointmentSlots');
const { isApprovedPublicCoach } = require('../utils/coachProfile');

function formatDateTime(date) {
  return new Date(date).toLocaleString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

function getEndTime(dateTime, durationMinutes) {
  return new Date(new Date(dateTime).getTime() + (durationMinutes || 60) * 60000);
}

async function hasOverlap(coachId, dateTime, durationMinutes, excludeId = null) {
  const start = new Date(dateTime);
  const end = getEndTime(start, durationMinutes);
  const blockingStatuses = ['pending', 'approved', 'rescheduled'];

  const existing = await Appointment.find({
    coach: coachId,
    status: { $in: blockingStatuses },
    ...(excludeId ? { _id: { $ne: excludeId } } : {}),
  }).select('dateTime durationMinutes');

  return existing.some((appt) => {
    const otherStart = new Date(appt.dateTime);
    const otherEnd = getEndTime(otherStart, appt.durationMinutes);
    return start < otherEnd && otherStart < end;
  });
}

async function verifyActiveAssignment(clientId, coachId) {
  const [legacy, modern] = await Promise.all([
    CoachAssignment.findOne({ user: clientId, coach: coachId, status: 'active' }),
    CoachClientAssignment.findOne({ user_id: clientId, coach_id: coachId, status: 'active' }),
  ]);
  return legacy || modern || null;
}

async function notifyUser(userId, message, type = 'reminder') {
  await Notification.create({ user: userId, message, type });
}

async function requestAppointment(req, res) {
  try {
    if (req.user.role !== 'user') {
      return res.status(403).json({ message: 'Only members can request appointments' });
    }

    const { dateTime, durationMinutes, notes } = req.body;
    if (!dateTime) {
      return res.status(400).json({ message: 'Date and time are required' });
    }

    const assignment = await CoachAssignment.findOne({
      user: req.user._id,
      status: 'active',
    });
    if (!assignment) {
      return res.status(403).json({ message: 'You need an assigned coach to request an appointment' });
    }

    const parsedDate = new Date(dateTime);
    if (Number.isNaN(parsedDate.getTime()) || parsedDate <= new Date()) {
      return res.status(400).json({ message: 'Appointment must be scheduled in the future' });
    }

    const duration = durationMinutes || 60;
    const overlap = await hasOverlap(assignment.coach, parsedDate, duration);
    if (overlap) {
      return res.status(409).json({ message: 'That time slot is already booked. Please choose another time.' });
    }

    const appointment = await Appointment.create({
      client: req.user._id,
      user_id: req.user._id,
      coach: assignment.coach,
      coach_id: assignment.coach,
      dateTime: parsedDate,
      datetime: parsedDate,
      durationMinutes: duration,
      duration,
      notes: String(notes || '').trim(),
      type: 'user_request',
      status: 'pending',
    });

    await notifyUser(
      assignment.coach,
      `${req.user.full_name || req.user.username} requested an appointment for ${formatDateTime(parsedDate)}.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.status(201).json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function createCoachAppointment(req, res) {
  try {
    const { clientId, fitnessClassId, dateTime, durationMinutes, notes, coachNotes } = req.body;
    if (!dateTime) {
      return res.status(400).json({ message: 'Date and time are required' });
    }
    if (!clientId && !fitnessClassId) {
      return res.status(400).json({ message: 'Select a user or a group' });
    }
    if (clientId && fitnessClassId) {
      return res.status(400).json({ message: 'Select either a user or a group, not both' });
    }

    const parsedDate = new Date(dateTime);
    if (Number.isNaN(parsedDate.getTime()) || parsedDate <= new Date()) {
      return res.status(400).json({ message: 'Appointment must be scheduled in the future' });
    }

    const duration = durationMinutes || 60;
    const overlap = await hasOverlap(req.user._id, parsedDate, duration);
    if (overlap) {
      return res.status(409).json({ message: 'That time slot overlaps with another appointment.' });
    }

    const baseFields = {
      coach: req.user._id,
      coach_id: req.user._id,
      dateTime: parsedDate,
      datetime: parsedDate,
      durationMinutes: duration,
      duration,
      notes: String(notes || '').trim(),
      coachNotes: String(coachNotes || '').trim(),
      type: 'coach_created',
      status: 'approved',
    };

    if (fitnessClassId) {
      const fitnessClass = await FitnessClass.findOne({
        _id: fitnessClassId,
        coach: req.user._id,
      });
      if (!fitnessClass) {
        return res.status(404).json({ message: 'Group not found' });
      }

      const studentIds = (fitnessClass.enrolledStudents || []).map((id) => String(id));
      if (!studentIds.length) {
        return res.status(400).json({ message: 'This group has no enrolled members' });
      }

      const when = formatDateTime(parsedDate);
      const groupTitle = fitnessClass.title;
      const created = await Appointment.insertMany(
        studentIds.map((studentId) => ({
          ...baseFields,
          client: studentId,
          user_id: studentId,
          fitnessClass: fitnessClassId,
        })),
      );

      await Promise.all(
        studentIds.map((studentId) =>
          notifyUser(
            studentId,
            `Your coach scheduled a group appointment "${groupTitle}" for ${when}.`,
            'reminder',
          ),
        ),
      );

      const populated = await Appointment.find({ _id: { $in: created.map((a) => a._id) } })
        .populate('client', 'username full_name phone')
        .populate('coach', 'username full_name phone')
        .populate('fitnessClass', 'title category');

      return res.status(201).json({
        created: populated.length,
        fitnessClass: { _id: fitnessClass._id, title: fitnessClass.title },
        appointments: populated,
      });
    }

    const assignment = await verifyActiveAssignment(clientId, req.user._id);
    if (!assignment) {
      return res.status(403).json({ message: 'Client is not actively assigned to you' });
    }

    const appointment = await Appointment.create({
      ...baseFields,
      client: clientId,
      user_id: clientId,
    });

    await notifyUser(
      clientId,
      `Your coach scheduled an appointment for ${formatDateTime(parsedDate)}.`,
      'reminder',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone')
      .populate('fitnessClass', 'title category');

    return res.status(201).json({
      created: 1,
      appointments: [populated],
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function getCoachAppointments(req, res) {
  try {
    const appointments = await Appointment.find({ coach: req.user._id })
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone')
      .populate('fitnessClass', 'title category')
      .sort({ dateTime: 1 });
    return res.json(appointments);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function getUserAppointments(req, res) {
  try {
    const appointments = await Appointment.find({ client: req.user._id })
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone')
      .populate('fitnessClass', 'title category')
      .sort({ dateTime: 1 });
    return res.json(appointments);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function approveAppointment(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    if (appointment.status !== 'pending' && appointment.status !== 'rescheduled') {
      return res.status(400).json({ message: 'Only pending or rescheduled appointments can be approved' });
    }

    const overlap = await hasOverlap(req.user._id, appointment.dateTime, appointment.durationMinutes, appointment._id);
    if (overlap) {
      return res.status(409).json({ message: 'Cannot approve — time slot overlaps with another appointment.' });
    }

    const { coachNotes } = req.body;
    appointment.status = 'approved';
    if (coachNotes !== undefined) appointment.coachNotes = String(coachNotes).trim();
    await appointment.save();

    await notifyUser(
      appointment.client,
      `Your appointment on ${formatDateTime(appointment.dateTime)} has been approved.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function rejectAppointment(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    const { coachNotes } = req.body;
    appointment.status = 'rejected';
    if (coachNotes !== undefined) appointment.coachNotes = String(coachNotes).trim();
    await appointment.save();

    await notifyUser(
      appointment.client,
      `Your appointment request for ${formatDateTime(appointment.dateTime)} was declined.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function rescheduleAppointment(req, res) {
  try {
    const { dateTime, coachNotes } = req.body;
    if (!dateTime) {
      return res.status(400).json({ message: 'New date and time are required' });
    }

    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    const parsedDate = new Date(dateTime);
    if (Number.isNaN(parsedDate.getTime()) || parsedDate <= new Date()) {
      return res.status(400).json({ message: 'New appointment time must be in the future' });
    }

    const overlap = await hasOverlap(req.user._id, parsedDate, appointment.durationMinutes, appointment._id);
    if (overlap) {
      return res.status(409).json({ message: 'That time slot overlaps with another appointment.' });
    }

    appointment.rescheduledFrom = appointment.dateTime;
    appointment.dateTime = parsedDate;
    appointment.status = 'rescheduled';
    if (coachNotes !== undefined) appointment.coachNotes = String(coachNotes).trim();
    appointment.reminderSent = false;
    await appointment.save();

    await notifyUser(
      appointment.client,
      `Your appointment has been rescheduled to ${formatDateTime(parsedDate)}.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function completeAppointment(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    if (appointment.status !== 'approved' && appointment.status !== 'rescheduled') {
      return res.status(400).json({ message: 'Only approved or rescheduled appointments can be completed' });
    }

    const { coachNotes } = req.body;
    appointment.status = 'completed';
    if (coachNotes !== undefined) appointment.coachNotes = String(coachNotes).trim();
    await appointment.save();

    await notifyUser(
      appointment.client,
      `Your appointment on ${formatDateTime(appointment.dateTime)} has been marked completed.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function updateAppointmentNotes(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    const { coachNotes } = req.body;
    appointment.coachNotes = String(coachNotes || '').trim();
    await appointment.save();

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

function effectiveAppointmentDays(profile = {}) {
  const appointmentDays = Array.isArray(profile.appointmentDays) ? profile.appointmentDays : [];
  if (appointmentDays.length > 0) {
    return appointmentDays;
  }
  // Legacy coaches registered before appointmentDays existed.
  return Array.isArray(profile.workingDays) ? profile.workingDays : [];
}

async function getCoachSettings(coachId) {
  const coach = await User.findById(coachId)
    .populate(
      'profile',
      'workingDays appointmentDays workingHoursStart workingHoursEnd appointmentDurationMinutes dayAvailability',
    )
    .lean();
  const profile = coach?.profile || {};
  const dayAvailability = Array.isArray(profile.dayAvailability) ? profile.dayAvailability : [];
  const appointmentDays = effectiveAppointmentDays(profile);
  const synthesizedDayAvailability = dayAvailability.length
    ? dayAvailability
    : appointmentDays.map((day) => ({
        day,
        start: profile.workingHoursStart || DEFAULT_WORK_START,
        end: profile.workingHoursEnd || DEFAULT_WORK_END,
      }));
  return {
    workingDays: Array.isArray(profile.workingDays) ? profile.workingDays : [],
    appointmentDays,
    dayAvailability: synthesizedDayAvailability,
    start: profile.workingHoursStart || DEFAULT_WORK_START,
    end: profile.workingHoursEnd || DEFAULT_WORK_END,
    duration: profile.appointmentDurationMinutes || DEFAULT_DURATION,
  };
}

function hoursForDayName(settings, dayName) {
  return getHoursForDay(settings.dayAvailability, dayName, settings.start, settings.end);
}

// GET available slots for a coach on a specific date (member only).
async function getCoachAvailability(req, res) {
  try {
    const coachId = req.query.coachId || req.params.coachId;
    const dateStr = req.query.date;
    if (!coachId || !dateStr) {
      return res.status(400).json({ message: 'coachId and date are required' });
    }

    const coach = await User.findById(coachId);
    if (!coach || !isApprovedPublicCoach(coach)) {
      return res.status(404).json({ message: 'Coach not found' });
    }

    // Only an actively-assigned client can view a coach's availability.
    const assignment = await CoachAssignment.findOne({
      user: req.user._id,
      coach: coachId,
      status: 'active',
    });
    if (!assignment) {
      return res.status(403).json({ message: 'You can only book with your assigned coach.' });
    }

    const dayStart = parseSlotDateTime(dateStr, '00:00');
    if (!dayStart) {
      return res.status(400).json({ message: 'Invalid date' });
    }

    const timezoneOffsetMinutes = parseTimezoneOffsetMinutes(req.query.timezoneOffsetMinutes) ?? 0;

    const settings = await getCoachSettings(coachId);
    const { appointmentDays } = settings;
    const dayName = getDayNameFromDateStr(dateStr);
    const isWorkingDay = appointmentDays.includes(dayName);

    if (!isWorkingDay) {
      return res.json({
        date: dateStr,
        dayName,
        isWorkingDay: false,
        appointmentDays,
        workingDays: settings.workingDays,
        dayAvailability: settings.dayAvailability,
        workingHoursStart: settings.start,
        workingHoursEnd: settings.end,
        appointmentDurationMinutes: settings.duration,
        slots: [],
      });
    }

    const { start, end } = hoursForDayName(settings, dayName);

    const dayEnd = parseSlotDateTimeInOffset(dateStr, '23:59', timezoneOffsetMinutes);
    const dayBegin = parseSlotDateTimeInOffset(dateStr, '00:00', timezoneOffsetMinutes);
    const booked = await Appointment.find({
      coach: coachId,
      status: { $in: ['pending', 'approved', 'rescheduled'] },
      dateTime: { $gte: dayBegin, $lte: dayEnd },
    }).select('dateTime');

    const bookedTimes = new Set(
      booked.map((a) => wallClockHHMM(new Date(a.dateTime), timezoneOffsetMinutes)),
    );

    const now = new Date();
    const slots = generateSlotTimes(start, end, settings.duration).map((time) => {
      const slotDate = parseSlotDateTimeInOffset(dateStr, time, timezoneOffsetMinutes);
      const isPast = slotDate <= now;
      const isBooked = bookedTimes.has(time);
      return { time, available: !isPast && !isBooked, booked: isBooked, past: isPast };
    });

    const availableSlots = slots.filter((slot) => slot.available);

    return res.json({
      date: dateStr,
      dayName,
      isWorkingDay: true,
      appointmentDays,
      workingDays: settings.workingDays,
      dayAvailability: settings.dayAvailability,
      workingHoursStart: start,
      workingHoursEnd: end,
      appointmentDurationMinutes: settings.duration,
      slots: availableSlots,
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

// POST book a slot-based appointment (member only).
async function bookAppointment(req, res) {
  try {
    if (req.user.role !== 'user') {
      return res.status(403).json({ message: 'Only members can book appointments' });
    }

    const { coachId, date, time, notes, timezoneOffsetMinutes: bodyOffset } = req.body;
    if (!coachId || !date || !time) {
      return res.status(400).json({ message: 'Coach, date and time are required' });
    }

    const coach = await User.findById(coachId);
    if (!coach || !isApprovedPublicCoach(coach)) {
      return res.status(404).json({ message: 'Coach not found' });
    }

    const assignment = await CoachAssignment.findOne({
      user: req.user._id,
      coach: coachId,
      status: 'active',
    });
    if (!assignment) {
      return res.status(403).json({ message: 'You can only book with your assigned coach.' });
    }

    const settings = await getCoachSettings(coachId);
    const timezoneOffsetMinutes = parseTimezoneOffsetMinutes(bodyOffset) ?? 0;

    const slotDate = parseSlotDateTimeInOffset(date, time, timezoneOffsetMinutes);
    if (!slotDate) {
      return res.status(400).json({ message: 'Invalid date or time' });
    }
    if (slotDate <= new Date()) {
      return res.status(400).json({ message: 'You cannot book an appointment in the past.' });
    }

    const { appointmentDays } = settings;
    const dayName = getDayNameFromDateStr(date);
    if (!appointmentDays.includes(dayName)) {
      return res.status(400).json({ message: `The coach does not accept appointments on ${dayName}.` });
    }

    const { start, end } = hoursForDayName(settings, dayName);
    if (!isValidSlotTime(time, start, end, settings.duration)) {
      return res.status(400).json({ message: "That time is outside the coach's working hours." });
    }

    // Prevent the same client booking the same coach + slot twice.
    const duplicate = await Appointment.findOne({
      client: req.user._id,
      coach: coachId,
      dateTime: slotDate,
      status: { $in: ['pending', 'approved', 'rescheduled'] },
    });
    if (duplicate) {
      return res.status(409).json({ message: 'You already have a booking for this time.' });
    }

    // Prevent double booking the coach (overlap with any client's appointment).
    const overlap = await hasOverlap(coachId, slotDate, settings.duration);
    if (overlap) {
      return res.status(409).json({ message: 'That time slot has already been booked. Please choose another.' });
    }

    const appointment = await Appointment.create({
      client: req.user._id,
      coach: coachId,
      dateTime: slotDate,
      durationMinutes: settings.duration,
      notes: String(notes || '').trim(),
      type: 'user_request',
      status: 'pending',
    });

    await notifyUser(
      coachId,
      `${req.user.name || 'A client'} booked an appointment for ${formatDateTime(slotDate)}.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.status(201).json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

// PATCH member cancels their own appointment.
async function cancelAppointmentByUser(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.client) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    if (!['pending', 'approved', 'rescheduled'].includes(appointment.status)) {
      return res.status(400).json({ message: 'This appointment can no longer be cancelled.' });
    }

    appointment.status = 'cancelled';
    await appointment.save();

    await notifyUser(
      appointment.coach,
      `${req.user.name || 'A client'} cancelled their appointment on ${formatDateTime(appointment.dateTime)}.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

// PATCH coach cancels an appointment.
async function cancelAppointmentByCoach(req, res) {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
    if (String(appointment.coach) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    if (['completed', 'cancelled', 'rejected'].includes(appointment.status)) {
      return res.status(400).json({ message: 'This appointment can no longer be cancelled.' });
    }

    const { coachNotes } = req.body;
    appointment.status = 'cancelled';
    if (coachNotes !== undefined) appointment.coachNotes = String(coachNotes).trim();
    await appointment.save();

    await notifyUser(
      appointment.client,
      `Your appointment on ${formatDateTime(appointment.dateTime)} was cancelled by your coach.`,
      'update',
    );

    const populated = await Appointment.findById(appointment._id)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone');
    return res.json(populated);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
}

async function processAppointmentReminders() {
  try {
    const now = new Date();
    const appointments = await Appointment.find({
      status: { $in: ['approved', 'rescheduled'] },
      reminderSent: false,
      dateTime: { $gt: now },
    }).select('client coach dateTime reminderMinutesBefore');

    for (const appt of appointments) {
      const reminderAt = new Date(
        appt.dateTime.getTime() - (appt.reminderMinutesBefore || 30) * 60000,
      );
      if (now >= reminderAt) {
        const when = formatDateTime(appt.dateTime);
        const mins = appt.reminderMinutesBefore || 30;
        await notifyUser(
          appt.client,
          `Reminder: Your appointment starts in ${mins} minutes (${when}).`,
          'reminder',
        );
        await notifyUser(
          appt.coach,
          `Reminder: You have an appointment in ${mins} minutes (${when}).`,
          'reminder',
        );
        appt.reminderSent = true;
        await appt.save();
      }
    }
  } catch (error) {
    console.error('processAppointmentReminders:', error.message);
  }
}

module.exports = {
  requestAppointment,
  createCoachAppointment,
  getCoachAppointments,
  getUserAppointments,
  approveAppointment,
  rejectAppointment,
  rescheduleAppointment,
  completeAppointment,
  updateAppointmentNotes,
  processAppointmentReminders,
  getCoachAvailability,
  bookAppointment,
  cancelAppointmentByUser,
  cancelAppointmentByCoach,
};
