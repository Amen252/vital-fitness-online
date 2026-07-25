/**
 * Data Scientist Agent (Progress Dashboard)
 * Task: Serves as the "analytical heart" of the app.
 * Logic: Processes raw logs into "Visual Charts" and generates summary health reports.
 */
class DataScientistAgent {
  /**
   * Processes raw logs into structured data for charts.
   */
  processLogsForCharts(logs) {
    const { meals, activities, water } = logs;

    const totalCalsIn = meals.reduce((sum, log) => sum + (log.calories || 0), 0);
    const totalCalsOut = activities.reduce((sum, log) => sum + (log.caloriesBurned || 0), 0);
    const netCalories = totalCalsIn - totalCalsOut;
    const hydration = (water || []).reduce((sum, log) => sum + (log.amountMl || 0), 0);

    return {
      dailyBalance: netCalories,
      interpretation: netCalories > 0 ? 'Surplus' : 'Deficit',
      healthReport: this.generateHealthReport({ totalCalsIn, totalCalsOut, netCalories, hydration }),
    };
  }

  /**
   * Generates a clean list of personalized insight strings based on the
   * user's recent calorie balance and hydration.
   */
  generateHealthReport(summary) {
    const { totalCalsIn, totalCalsOut, netCalories, hydration } = summary;
    const reports = [];

    // Calorie balance insight
    if (totalCalsIn === 0 && totalCalsOut === 0) {
      reports.push('Log your meals and workouts to see calorie insights here.');
    } else {
      reports.push(`You've taken in ${totalCalsIn} kcal and burned ${totalCalsOut} kcal recently.`);
      if (netCalories < -200) {
        reports.push("You're in a calorie deficit — great if weight loss is your goal.");
      } else if (netCalories > 500) {
        reports.push("You're in a calorie surplus — helpful if you're building muscle.");
      } else {
        reports.push('Your energy balance looks stable. Nice consistency!');
      }
    }

    // Hydration insight
    if (hydration <= 0) {
      reports.push('No water logged yet — aim for about 2000ml a day.');
    } else if (hydration < 1500) {
      reports.push(`You've logged ${hydration}ml of water. Try to reach at least 2000ml.`);
    } else {
      reports.push(`Great hydration — ${hydration}ml logged. Keep it up!`);
    }

    return reports;
  }
}

module.exports = new DataScientistAgent();
