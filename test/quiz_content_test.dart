import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/quiz_content.dart';

void main() {
  group('first HSE quiz bank', () {
    test('contains exactly 40 questions for the first exam', () {
      expect(questions, hasLength(40));
    });

    test('every question has four non-empty choices and a valid answer index', () {
      for (var index = 0; index < questions.length; index++) {
        final question = questions[index];
        final prompt = question['q'] as String;
        final options = question['a'] as List<String>;
        final correctIndex = question['correct'] as int;

        expect(prompt.trim(), isNotEmpty, reason: 'Question $index has no prompt');
        expect(options, hasLength(4), reason: 'Question $index must have four choices');
        expect(options.every((option) => option.trim().isNotEmpty), isTrue);
        expect(correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('question prompts are unique', () {
      final prompts = questions.map((question) => question['q']).toSet();
      expect(prompts.length, questions.length);
    });
  });
}
