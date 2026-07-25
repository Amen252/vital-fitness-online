const mongoose = require('mongoose');
const Review = require('../models/Review');
const CoachAssignment = require('../models/CoachAssignment');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { isApprovedPublicCoach } = require('../utils/coachProfile');
const { USER_DISPLAY_SELECT } = require('../utils/userDisplay');

async function getCoachRatingSummary(coachId) {
  const result = await Review.aggregate([
    { $match: { coach: new mongoose.Types.ObjectId(String(coachId)) } },
    {
      $group: {
        _id: '$coach',
        averageRating: { $avg: '$rating' },
        numReviews: { $sum: 1 },
      },
    },
  ]);

  if (!result.length) {
    return { averageRating: 0, numReviews: 0 };
  }
  return {
    averageRating: Math.round(result[0].averageRating * 10) / 10,
    numReviews: result[0].numReviews,
  };
}

// Client creates or updates their review for a coach.
async function submitReview(req, res) {
  try {
    const { coachId } = req.params;
    const { rating, comment } = req.body;

    const parsedRating = Number(rating);
    if (!Number.isInteger(parsedRating) || parsedRating < 1 || parsedRating > 5) {
      return res.status(400).json({ message: 'Rating must be a whole number between 1 and 5' });
    }

    const coach = await User.findById(coachId);
    if (!coach || !isApprovedPublicCoach(coach)) {
      return res.status(404).json({ message: 'Coach not found' });
    }

    // Only clients who are (or were) assigned to this coach can review them.
    const assignment = await CoachAssignment.findOne({ user: req.user._id, coach: coachId });
    if (!assignment) {
      return res.status(403).json({ message: 'You can only review a coach you have worked with' });
    }

    const review = await Review.findOneAndUpdate(
      { coach: coachId, client: req.user._id },
      { rating: parsedRating, comment: String(comment || '').trim() },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );

    await Notification.create({
      user: coachId,
      message: `${req.user.name} left you a ${parsedRating}-star review.`,
      type: 'update',
    });

    const summary = await getCoachRatingSummary(coachId);
    return res.status(201).json({ review, ...summary });
  } catch (error) {
    console.error('[REVIEW] submitReview error:', error.message);
    return res.status(500).json({ message: 'Unable to submit review right now' });
  }
}

// Public list of reviews + aggregate for a coach.
async function getCoachReviews(req, res) {
  try {
    const { coachId } = req.params;

    const coach = await User.findById(coachId);
    if (!coach || !isApprovedPublicCoach(coach)) {
      return res.status(404).json({ message: 'Coach not found' });
    }

    const reviews = await Review.find({ coach: coachId })
      .populate('client', USER_DISPLAY_SELECT)
      .sort({ updatedAt: -1 })
      .lean();

    const summary = await getCoachRatingSummary(coachId);

    let myReview = null;
    if (req.user) {
      myReview = reviews.find((r) => String(r.client?._id) === String(req.user._id)) || null;
    }

    return res.json({ reviews, myReview, ...summary });
  } catch (error) {
    console.error('[REVIEW] getCoachReviews error:', error.message);
    return res.status(500).json({ message: 'Unable to load reviews right now' });
  }
}

async function deleteMyReview(req, res) {
  try {
    const { coachId } = req.params;
    await Review.deleteOne({ coach: coachId, client: req.user._id });
    const summary = await getCoachRatingSummary(coachId);
    return res.json({ message: 'Review removed', ...summary });
  } catch (error) {
    console.error('[REVIEW] deleteMyReview error:', error.message);
    return res.status(500).json({ message: 'Unable to remove review right now' });
  }
}

module.exports = {
  submitReview,
  getCoachReviews,
  deleteMyReview,
  getCoachRatingSummary,
};
