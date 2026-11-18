import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  const sampleQuestions = <Map<String, Object>>[
    {'q': 'پرسش اول', 'a': ['الف', 'ب'], 'correct': 1},
    {'q': 'پرسش دوم', 'a': ['الف', 'ب'], 'correct': 0},
    {'q': 'پرسش سوم', 'a': ['الف', 'ب'], 'correct': 1},
  ];

  test('counts correct, wrong, and unanswered questions independently', () {
    final result = evaluateExamAnswers(
      sampleQuestions,
      const {0: 1, 1: 1},
    );

    expect(result.correctCount, 1);
    expect(result.wrongCount, 1);
    expect(result.unansweredCount, 1);
    expect(result.totalCount, 3);
  });

  test('marks every missing answer as unanswered', () {
    final result = evaluateExamAnswers(sampleQuestions, const {});

    expect(result.correctCount, 0);
    expect(result.wrongCount, 0);
    expect(result.unansweredCount, 3);
  });

  test('preserves answers changed before submission', () {
    final result = evaluateExamAnswers(
      sampleQuestions,
      const {0: 1, 1: 0, 2: 1},
    );

    expect(result.correctCount, 3);
    expect(result.wrongCount, 0);
    expect(result.unansweredCount, 0);
  });
}
