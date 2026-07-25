/** Labels for fitness goals collected at member registration. */
export function fitnessGoalLabel(goal) {
  if (!goal) return "";
  const labels = {
    lose_weight: "Lose weight",
    gain_muscle: "Gain muscle",
    maintain: "Maintain",
    other: "General",
  };
  return labels[goal] || String(goal);
}

/** Registration fields stored on User.clientData (and top-level account fields). */
export function memberRegistrationFromUser(user) {
  if (!user) {
    return {
      full_name: "",
      username: "",
      phone: "",
      gender: "",
      age: null,
      height: null,
      weight: null,
      fitness_goal: "",
      fitness_goal_label: "",
      createdAt: null,
    };
  }
  const cd = user.clientData || {};
  const goal = cd.fitness_goal || "";
  return {
    full_name: user.full_name || "",
    username: user.username || "",
    phone: user.phone || "",
    gender: cd.gender || "",
    age: cd.age ?? null,
    height: cd.height ?? null,
    weight: cd.weight ?? null,
    fitness_goal: goal,
    fitness_goal_label: fitnessGoalLabel(goal),
    createdAt: user.createdAt || null,
  };
}
