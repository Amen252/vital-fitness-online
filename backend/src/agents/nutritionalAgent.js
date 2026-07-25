/**
 * Nutritional Intelligence Agent (Diet & Calorie Tracker)
 * Task: Automated Generator for personalized diet plans.
 * Logic: Analyzes profile to suggest meals and manages daily intake logs.
 */
class NutritionalAgent {
  /**
   * Generates a suggested diet plan based on user metrics and goals.
   */
  generateDietPlan(profile) {
    const { weightKg, goals, heightCm, age } = profile;
    const goal = goals[0] || 'maintenance';
    
    // Simple BMR calculation (Mifflin-St Jeor Equation)
    const bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5; // Simplified for male/average
    let targetCalories = Math.round(bmr * 1.2); // Sedentary factor

    if (goal === 'weight loss') targetCalories -= 500;
    if (goal === 'muscle gain') targetCalories += 300;

    const plans = {
      'weight loss': {
        breakfast: 'Oatmeal with berries and nuts',
        lunch: 'Grilled chicken salad with avocado',
        dinner: 'Baked salmon with steamed broccoli and quinoa',
        snacks: 'Greek yogurt with almonds',
      },
      'muscle gain': {
        breakfast: 'Scrambled eggs with whole grain toast and avocado',
        lunch: 'Turkey and cheese sandwich with sweet potato fries',
        dinner: 'Steak with roasted potatoes and green beans',
        snacks: 'Protein shake and peanut butter apple slices',
      },
      'maintenance': {
        breakfast: 'Fruits and yogurt parfait',
        lunch: 'Brown rice bowl with chickpeas and roasted veggies',
        dinner: 'Stir-fry tofu with mixed greens',
        snacks: 'Hummus and carrots',
      }
    };

    const suggestedPlan = plans[goal] || plans['maintenance'];

    return {
      targetCalories,
      suggestedPlan,
      macroRatio: goal === 'muscle gain' ? '40/30/30 (P/C/F)' : '30/40/30',
      reasoning: `Based on your goal of ${goal}, your suggested daily intake is ${targetCalories} calories.`,
    };
  }

  /**
   * Aggregates meal logs for a specific user and date.
   */
  calculateDailyIntake(mealLogs) {
    return mealLogs.reduce((acc, log) => {
      acc.totalCalories += log.calories || 0;
      acc.totalProtein += log.protein || 0;
      acc.totalCarbs += log.carbs || 0;
      acc.totalFats += log.fats || 0;
      return acc;
    }, { totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFats: 0 });
  }
}

module.exports = new NutritionalAgent();
