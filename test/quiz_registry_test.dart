import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/quiz_registry.dart';

void main() {
  group('independent offline quiz packs', () {
    test('registers HSE and customer service as separate exams', () {
      expect(quizPacks, hasLength(2));
      expect(
        quizPacks.map((pack) => pack.id).toSet().length,
        quizPacks.length,
      );
      expect(
        quizPacks.map((pack) => pack.title).toSet(),
        containsAll([
          'آزمون مبانی ایمنی و HSE',
          'آزمون مبانی امور مشترکین',
        ]),
      );
    });

    test('each available pack has 40 questions and a 20-minute duration', () {
      for (final pack in quizPacks) {
        expect(pack.questionCount, 40, reason: pack.title);
        expect(pack.durationSeconds, 1200, reason: pack.title);
      }
    });

    test('each pack has complete question choices and valid answer indexes', () {
      for (final pack in quizPacks) {
        final prompts = <String>{};
        for (final question in pack.questions) {
          expect(question['q'], isA<String>());
          expect((question['q'] as String).trim(), isNotEmpty);
          expect(question['a'], isA<List<String>>());
          final options = question['a'] as List<String>;
          expect(options, hasLength(4));
          expect(options.every((option) => option.trim().isNotEmpty), isTrue);
          expect(question['correct'], inInclusiveRange(0, 3));
          expect(prompts.add(question['q'] as String), isTrue);
        }
      }
    });
  });
}
