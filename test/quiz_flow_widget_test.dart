import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

Widget _examHost() => const MaterialApp(
      home: Scaffold(body: ExamPage()),
    );

Future<void> _openExam(
  WidgetTester tester,
  String examTitle,
  String appBarTitle,
) async {
  await tester.pumpWidget(_examHost());
  expect(find.text(examTitle), findsOneWidget);
  await tester.tap(find.text(examTitle));
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
    expect(find.text('پرسش 2 از 40'), findsOneWidget);

    await tester.ensureVisible(find.text('قبلی'));
    await tester.tap(find.text('قبلی'));
    await tester.pump();
    expect(find.text('پرسش 1 از 40'), findsOneWidget);
    await tester.tap(find.text('افزایش سرعت بدون توجه به ایمنی'));
    await tester.pump();

    await tester.tap(find.text('پایان آزمون و ثبت نتیجه'));
    await tester.pumpAndSettle();

    expect(find.text('جزئیات نتیجه آزمون'), findsOneWidget);
    expect(find.textContaining('نادرست: 1'), findsOneWidget);

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

}
