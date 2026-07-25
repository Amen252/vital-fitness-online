function calcBmi(heightCm, weightKg) {
  if (!heightCm || !weightKg) {
    return null;
  }

  const heightMeters = Number(heightCm) / 100;
  if (!heightMeters) {
    return null;
  }

  return Number((Number(weightKg) / (heightMeters * heightMeters)).toFixed(1));
}

module.exports = calcBmi;
