import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  group('ExamEvaluation', () {
    const questions = <ExamQuestion>[
      ExamQuestion(
        text: 'Q1',
        options: ['A', 'B', 'C', 'D'],
        correctIndex: 1,
      ),
      ExamQuestion(
        text: 'Q2',
        options: ['A', 'B', 'C', 'D'],
        correctIndex: 0,
      ),
      ExamQuestion(
        text: 'Q3',
        options: ['A', 'B', 'C', 'D'],
        correctIndex: 3,
      ),
    ];

    test('counts correct, wrong and unanswered answers separately', () {
      final result = ExamEvaluation.calculate(questions, [1, 2, null]);

      expect(result.correct, 1);
      expect(result.wrong, 1);
      expect(result.unanswered, 1);
      expect(result.total, 3);
    });

    test('accepts all unanswered questions', () {
      final result = ExamEvaluation.calculate(questions, [null, null, null]);

      expect(result.correct, 0);
      expect(result.wrong, 0);
      expect(result.unanswered, 3);
    });

    test('rejects mismatched answer count', () {
      expect(
        () => ExamEvaluation.calculate(questions, [1]),
        throwsArgumentError,
      );
    });
  });
}
