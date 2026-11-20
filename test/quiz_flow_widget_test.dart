import 'package:flutter_test/flutter_test.dart';
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
}
