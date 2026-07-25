const mongoose = require('mongoose');
const User = require('../models/User');
const Profile = require('../models/Profile');
const CoachAssignment = require('../models/CoachAssignment');
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

async function seed() {
  try {
    console.log('Connecting to MongoDB of URI:', process.env.MONGO_URI);
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    const coachEmail = 'mahad@example.com';
    const userEmail = 'sahra@example.com';

    // Seed Coach
    let coach = await User.findOne({ email: coachEmail });
    if (!coach) {
      const coachProfile = await Profile.create({
        age: 35,
        heightCm: 180,
        weightKg: 85,
        goals: ['Professional Coaching', 'Endurance Training']
      });

      coach = await User.create({
        name: 'Coach Mahad',
        email: coachEmail,
        password: 'password',
        role: 'coach',
        profile: coachProfile._id
      });
      console.log('Coach seeded successfully');
    } else {
      coach.password = 'password';
      await coach.save();
      console.log('Coach password updated');
    }

    // Seed User
    let user = await User.findOne({ email: userEmail });
    if (!user) {
      const userProfile = await Profile.create({
        age: 28,
        heightCm: 175,
        weightKg: 70,
        goals: ['Weight Loss', 'Flexibility']
      });

      user = await User.create({
        name: 'Sahra Axmed',
        email: userEmail,
        password: 'password',
        role: 'user',
        profile: userProfile._id
      });
      console.log('User seeded successfully');
    } else {
      user.password = 'password';
      await user.save();
      console.log('User password updated');
    }


    // Seed Assignment
    const assignment = await CoachAssignment.findOne({ coach: coach._id, user: user._id });
    if (!assignment) {
      await CoachAssignment.create({
        coach: coach._id,
        user: user._id,
        status: 'active'
      });
      console.log('Coach Assignment seeded successfully');
    } else {
      console.log('Assignment already exists');
    }

    console.log('Seeding complete');
    process.exit(0);
  } catch (error) {
    console.error('Seeding error:', error);
    process.exit(1);
  }
}

seed();

