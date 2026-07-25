import 'package:flutter_test/flutter_test.dart';
import 'package:vital_fitness/models/progress_model.dart';

void main() {
  test('ProgressSummary parses API payload', () {
    final summary = ProgressSummary.fromJson({
      'caloriesIn': 1800,
      'caloriesOut': 420,
      'hydration': 1500,
      'netCalories': 1380,
      'logCount': 3,
    });

    expect(summary.caloriesIn, 1800);
    expect(summary.caloriesOut, 420);
    expect(summary.hydration, 1500);
    expect(summary.logCount, 3);
  });

  test('ProgressSummary handles null payload', () {
    final summary = ProgressSummary.fromJson(null);
    expect(summary.caloriesIn, 0);
    expect(summary.logCount, 0);
  });
}
