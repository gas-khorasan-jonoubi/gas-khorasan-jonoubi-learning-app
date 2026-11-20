import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  group('quizDurationFor', () {
    test('uses 30 seconds per question', () {
      expect(quizDurationFor(50), const Duration(minutes: 25));
      expect(quizDurationFor(40), const Duration(minutes: 20));
    });

    test('rejects a negative question count', () {
      expect(() => quizDurationFor(-1), throwsArgumentError);
    });
  });

  group('evaluateQuizAnswers', () {
    test('counts correct, wrong and unanswered separately', () {
      final result = evaluateQuizAnswers(
        <int?>[1, 0, null, 2],
        <int>[1, 2, 0, 2],
      );

      expect(result.correct, 2);
      expect(result.wrong, 1);
      expect(result.unanswered, 1);
    });

    test('rejects answer lists with different lengths', () {
      expect(
        () => evaluateQuizAnswers(<int?>[1], <int>[1, 2]),
        throwsArgumentError,
      );
    });
  });
}
