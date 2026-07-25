const calcBmi = require('../utils/calcBmi');

/**
 * Onboarding Agent (User Management)
 * Task: Handles secure registration, login, and the initial collection of health metrics.
 * Logic: Calculates the user's BMI automatically and registers specific health goals.
 */
class OnboardingAgent {
  /**
   * Process initial metrics and goals for a new user or profile update.
   * @param {Object} metrics - { heightCm, weightKg, age, goals }
   * @returns {Object} - Processed metrics including BMI
   */
  processOnboarding(metrics) {
    const { heightCm, weightKg, age, goals } = metrics;
    
    const bmi = calcBmi(heightCm, weightKg);
    
    return {
      age,
      heightCm,
      weightKg,
      bmi,
      goals: Array.isArray(goals) ? goals : [goals],
      onboardedAt: new Date(),
    };
  }

  /**
   * Determine if the user has completed minimum required metrics.
   */
  isProfileComplete(profile) {
    return !!(profile.heightCm && profile.weightKg && profile.age && profile.goals?.length);
  }
}

module.exports = new OnboardingAgent();
