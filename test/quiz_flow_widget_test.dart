import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/quiz_models.dart';

Widget _examHost() => const MaterialApp(
      home: Scaffold(body: ExamPage()),
    );

Future<void> _openExam(
  WidgetTester tester,
  String examTitle,
  String appBarTitle,
) async {
  await tester.pumpWidget(_examHost());
  final examTitleFinder = find.text(examTitle);
  await tester.scrollUntilVisible(
    examTitleFinder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  final examTileFinder = find.ancestor(
    of: examTitleFinder,
    matching: find.byType(ListTile),
  );
  expect(examTileFinder, findsOneWidget);
  await tester.ensureVisible(examTileFinder);
  await tester.pumpAndSettle();
  await tester.tap(examTileFinder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();

  expect(find.text(appBarTitle), findsOneWidget);
  expect(find.text('20:00'), findsOneWidget);
}

void main() {
  testWidgets('first HSE exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی ایمنی و HSE',
      'آزمون مبانی ایمنی و HSE - 1 از 40',
    );
  });

  testWidgets('customer service exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی امور مشترکین',
      'آزمون مبانی امور مشترکین - 1 از 40',
    );
  });
  testWidgets('receivables exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی وصول مطالبات',
      'آزمون مبانی وصول مطالبات - 1 از 40',
    );
  });

  testWidgets('maintenance exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی تعمیرات و نگهداری',
      'آزمون مبانی تعمیرات و نگهداری - 1 از 40',
    );
  });

  testWidgets('management exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی مدیریت و اداره',
      'آزمون مبانی مدیریت و اداره - 1 از 40',
    );
  });

  testWidgets('general gas industry exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون آشنایی عمومی با صنعت گاز',
      'آزمون آشنایی عمومی با صنعت گاز - 1 از 40',
    );
  });

  testWidgets('environmental sustainability exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون محیط‌زیست و توسعه پایدار',
      'آزمون محیط‌زیست و توسعه پایدار - 1 از 40',
    );
  });

  testWidgets('information security exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون امنیت اطلاعات و محرمانگی',
      'آزمون امنیت اطلاعات و محرمانگی - 1 از 40',
    );
  });

  testWidgets('professional ethics exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون اخلاق حرفه‌ای و سلامت اداری',
      'آزمون اخلاق حرفه‌ای و سلامت اداری - 1 از 40',
    );
  });

  testWidgets('crisis management exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مدیریت بحران و تداوم خدمت',
      'آزمون مدیریت بحران و تداوم خدمت - 1 از 40',
    );
  });

  testWidgets('productivity exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مدیریت زمان و بهره‌وری',
      'آزمون مدیریت زمان و بهره‌وری - 1 از 40',
    );
  });

  testWidgets('records management exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مدیریت اسناد و مکاتبات اداری',
      'آزمون مدیریت اسناد و مکاتبات اداری - 1 از 40',
    );
  });

  testWidgets('quality improvement exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مدیریت کیفیت و بهبود فرایند',
      'آزمون مدیریت کیفیت و بهبود فرایند - 1 از 40',
    );
  });

  testWidgets('teamwork exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون کار تیمی و ارتباطات سازمانی',
      'آزمون کار تیمی و ارتباطات سازمانی - 1 از 40',
    );
  });

  testWidgets('project management exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مبانی مدیریت پروژه و برنامه‌ریزی',
      'آزمون مبانی مدیریت پروژه و برنامه‌ریزی - 1 از 40',
    );
  });

  testWidgets('digital skills exam opens independently with 40 questions', (tester) async {
    await _openExam(
      tester,
      'آزمون مهارت‌های دیجیتال و ابزارهای اداری',
      'آزمون مهارت‌های دیجیتال و ابزارهای اداری - 1 از 40',
    );
  });

  testWidgets('answers can be changed and result is saved for the selected exam', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_examHost());
    await tester.tap(find.text('آزمون مبانی ایمنی و HSE'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // پاسخ درست سؤال اول را انتخاب می‌کنیم.
    await tester.tap(find.text('شناخت عوامل بالقوه آسیب پیش از وقوع حادثه'));
    await tester.pump();

    // به سؤال بعد می‌رویم، برمی‌گردیم و پاسخ را تغییر می‌دهیم.
    await tester.ensureVisible(find.text('بعدی'));
    await tester.tap(find.text('بعدی'));
    await tester.pump();
    expect(find.text('آزمون مبانی ایمنی و HSE - 2 از 40'), findsOneWidget);

    await tester.ensureVisible(find.text('قبلی'));
    await tester.tap(find.text('قبلی'));
    await tester.pump();
    expect(find.text('آزمون مبانی ایمنی و HSE - 1 از 40'), findsOneWidget);
    await tester.tap(find.text('افزایش سرعت بدون توجه به ایمنی'));
    await tester.pump();

    await tester.tap(find.text('پایان آزمون و ثبت نتیجه'));
    await tester.pumpAndSettle();

    expect(find.text('جزئیات نتیجه آزمون'), findsOneWidget);
    expect(find.textContaining('نادرست: 1'), findsOneWidget);

    // گزارش باید پاسخ انتخاب‌شده و پاسخ صحیح را در گروه مربوط نمایش دهد.
    await tester.ensureVisible(find.text('پاسخ‌های نادرست و پاسخ صحیح'));
    await tester.tap(find.text('پاسخ‌های نادرست و پاسخ صحیح'));
    await tester.pumpAndSettle();
    expect(find.textContaining('افزایش سرعت بدون توجه به ایمنی'), findsOneWidget);
    expect(find.textContaining('شناخت عوامل بالقوه آسیب پیش از وقوع حادثه'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_results');
    expect(saved, isNotNull);
    expect(saved, hasLength(1));

    final record = jsonDecode(saved!.single) as Map<String, dynamic>;
    expect(record['examId'], 'hse-basics');
    expect(record['examTitle'], 'آزمون مبانی ایمنی و HSE');
    expect(record['correct'], 0);
    expect(record['wrong'], 1);
    expect(record['unanswered'], 39);
  });

  testWidgets('exam finishes automatically when its total timer reaches zero', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const pack = QuizPack(
      id: 'timer-test',
      title: 'آزمون آزمایشی زمان',
      description: 'آزمون کوتاه برای کنترل پایان خودکار',
      questions: [
        {
          'q': 'پرسش زمان‌سنج چیست؟',
          'a': ['گزینه یک', 'گزینه دو', 'گزینه سه', 'گزینه چهار'],
          'correct': 0,
        },
      ],
    );

    var testNow = DateTime.utc(2026, 1, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(pack: pack, clock: () => testNow),
      ),
    );
    expect(find.text('00:30'), findsOneWidget);

    // زمان را تا یک ثانیه مانده به پایان جلو می‌بریم و تیک آخر را جداگانه اجرا می‌کنیم.
    testNow = testNow.add(const Duration(seconds: 29));
    await tester.pump(const Duration(seconds: 29));
    expect(find.text('00:01'), findsOneWidget);

    testNow = testNow.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('جزئیات نتیجه آزمون'), findsOneWidget);
    expect(find.textContaining('بی‌پاسخ: 1'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_results');
    expect(saved, hasLength(1));
    final record = jsonDecode(saved!.single) as Map<String, dynamic>;
    expect(record['examId'], 'timer-test');
    expect(record['correct'], 0);
    expect(record['wrong'], 0);
    expect(record['unanswered'], 1);
  });

}
