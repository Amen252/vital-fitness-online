/**
 * Coaching Liaison Agent (Coach Management System)
 * Task: Bridges the gap between user and professional coach.
 * Logic: Flags significant data trends for the coach and facilitates feedback.
 */
class CoachingLiaisonAgent {
  /**
   * Analyzes client data trends to identify "stalled progress".
   * @param {Object} snapshot - { summary, trends }
   */
  analyzeTrends(snapshot) {
    const { summary, recentLogs } = snapshot;
    const flags = [];
    const logCount = summary?.logCount || 0;

    // Brand-new clients have no history yet — don't alarm the coach.
    if (logCount === 0) {
      return {
        flags: [
          {
            severity: 'info',
            type: 'NEW_CLIENT',
            message: 'Client has not logged activity yet. Encourage them to get started.',
          },
        ],
        isActionRequired: false,
        isNewClient: true,
        healthScore: null,
        lastCalculated: new Date(),
      };
    }

    // 1. Stalled Progress
    if (summary.netCalories > 500) {
      flags.push({
        severity: 'warning',
        type: 'STALLED_PROGRESS',
        message: 'Caloric surplus detected. Review diet plan.',
      });
    }

    // 2. Meal Logging Compliance
    if (!recentLogs.meals || recentLogs.meals.length === 0) {
      flags.push({
        severity: 'critical',
        type: 'MISSED_MEALS',
        message: 'No recent meals logged.',
      });
    }

    // 3. Hydration Compliance
    if (summary.hydration < 1000) {
      flags.push({
        severity: 'warning',
        type: 'DEHYDRATION_RISK',
        message: 'Hydration levels are below target (<1000mL).',
      });
    }

    // 4. Kinetic Engagement
    if (!recentLogs.activities || recentLogs.activities.length === 0) {
      flags.push({
        severity: 'warning',
        type: 'SEDENTARY_STREAK',
        message: 'No workout activities detected in recent logs.',
      });
    }

    // 5. General Engagement
    if (logCount < 3) {
      flags.push({
        severity: 'critical',
        type: 'LOW_ENGAGEMENT',
        message: 'Low app engagement: only ' + logCount + ' recent entries.',
      });
    }

    let healthScore = 100;
    for (const flag of flags) {
      if (flag.severity === 'critical') healthScore -= 25;
      else if (flag.severity === 'warning') healthScore -= 12;
      else healthScore -= 5;
    }
    healthScore = Math.max(0, Math.min(100, healthScore));

    return {
      flags,
      isActionRequired: flags.some((f) => f.severity === 'critical') || flags.length >= 2,
      isNewClient: false,
      healthScore,
      lastCalculated: new Date(),
    };
  }

  /**
   * Helper to format feedback from coach to user.
   */
  formatDirectFeedback(coachNote) {
    return {
      note: coachNote,
      from: 'Coach',
      timestamp: new Date(),
    };
  }
}

module.exports = new CoachingLiaisonAgent();
