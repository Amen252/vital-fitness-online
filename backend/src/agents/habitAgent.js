/**
 * Habit & Compliance Agent (Activity & Water Tracking)
 * Task: Monitors physical activities and caloric burn.
 * Logic: Triggers automated notifications and ensures user stays on track with habits.
 */
class HabitAgent {
  /**
   * Calculates caloric burn based on activity logs.
   */
  calculateNetCaloricBurn(activityLogs) {
    return activityLogs.reduce((total, log) => total + (log.caloriesBurned || 0), 0);
  }

  /**
   * Checks for habit compliance and generates notification alerts.
   * @param {Object} logs - { activities, water, profile }
   */
  generateComplianceReport(logs) {
    const { activities, water, profile } = logs;
    const alerts = [];

    // Water Check (e.g., target 2000ml)
    const totalWater = water.reduce((sum, log) => sum + (log.amountMl || 0), 0);
    if (totalWater < 1500) {
      alerts.push({
        type: 'water',
        message: 'Hydration alert: You are below your daily water goal. Drink up!',
        priority: 'high'
      });
    }

    // Activity Check
    const totalActivityMinutes = activities.reduce((sum, log) => sum + (log.durationMinutes || 0), 0);
    if (totalActivityMinutes < 30) {
      alerts.push({
        type: 'activity',
        message: 'Workout nudge: A quick 15-minute walk can boost your energy!',
        priority: 'medium'
      });
    }

    return {
      complianceScore: (totalWater > 1500 && totalActivityMinutes > 30) ? 100 : 50,
      alerts,
      suggestions: [
        'Try to drink 250ml of water every hour.',
        'Consider a morning stretching routine to improve compliance.'
      ]
    };
  }
}

module.exports = new HabitAgent();
