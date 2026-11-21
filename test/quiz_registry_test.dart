import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/quiz_registry.dart';

void main() {
  group('independent offline quiz packs', () {
    test('registers twenty separate exams for core work areas', () {
      expect(quizPacks, hasLength(20));
      expect(
        quizPacks.map((pack) => pack.id).toSet().length,
        quizPacks.length,
      );
      expect(
        quizPacks.map((pack) => pack.title).toSet(),
        containsAll([
          'آزمون مبانی ایمنی و HSE',
          'آزمون مبانی امور مشترکین',
          'آزمون مبانی وصول مطالبات',
          'آزمون مبانی تعمیرات و نگهداری',
          'آزمون مبانی مدیریت و اداره',
          'آزمون آشنایی عمومی با صنعت گاز',
          'آزمون محیط‌زیست و توسعه پایدار',
          'آزمون امنیت اطلاعات و محرمانگی',
          'آزمون اخلاق حرفه‌ای و سلامت اداری',
          'آزمون مدیریت بحران و تداوم خدمت',
          'آزمون مدیریت زمان و بهره‌وری',
          'آزمون مدیریت اسناد و مکاتبات اداری',
          'آزمون مدیریت کیفیت و بهبود فرایند',
          'آزمون کار تیمی و ارتباطات سازمانی',
          'آزمون مبانی مدیریت پروژه و برنامه‌ریزی',
          'آزمون مهارت‌های دیجیتال و ابزارهای اداری',
          'آزمون مدیریت منابع، تدارکات و انبار',
          'آزمون مشتری‌مداری و رسیدگی به شکایات',
          'آزمون مدیریت ریسک و تصمیم‌گیری مبتنی بر شواهد',
          'آزمون مدیریت تغییر و استقرار روش‌های جدید',
        ]),
      );
    });

    test('each available pack has 40 questions and a 20-minute duration', () {
      for (final pack in quizPacks) {
        expect(pack.questionCount, 40, reason: pack.title);
        expect(pack.durationSeconds, 1200, reason: pack.title);
      }
    });

    test('question prompts are unique across all twenty exam packs', () {
      final prompts = quizPacks
          .expand((pack) => pack.questions.map((question) => question['q']))
          .toList();
      expect(prompts.toSet().length, prompts.length);
    });

    test('each pack has complete choices, unique prompts and balanced answer positions', () {
      for (final pack in quizPacks) {
        final prompts = <String>{};
        final answerDistribution = List<int>.filled(4, 0);
        for (final question in pack.questions) {
          expect(question['q'], isA<String>());
          expect((question['q'] as String).trim(), isNotEmpty);
          expect(question['a'], isA<List<String>>());
          final options = question['a'] as List<String>;
          expect(options, hasLength(4));
          expect(options.every((option) => option.trim().isNotEmpty), isTrue);
          expect(
            options.map((option) => option.trim().toLowerCase()).toSet(),
            hasLength(4),
            reason: 'Duplicate answer choices in ${pack.title}: ${question['q']}',
          );
          final correctIndex = question['correct'] as int;
          expect(correctIndex, inInclusiveRange(0, 3));
          answerDistribution[correctIndex]++;
          expect(prompts.add(question['q'] as String), isTrue);
        }
        // در هر بانک ۴۰ سؤالی، هر جایگاه پاسخ صحیح دقیقاً ۱۰ بار استفاده می‌شود.
        expect(answerDistribution, [10, 10, 10, 10], reason: pack.title);
      }
    });
  });
}
