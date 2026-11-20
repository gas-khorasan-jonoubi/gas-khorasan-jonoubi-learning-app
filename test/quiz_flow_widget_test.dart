import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('first HSE exam opens with 40 questions and 20 minutes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExamPage()));

    expect(find.text('آزمون مبانی ایمنی و HSE'), findsOneWidget);
    await tester.tap(find.text('شروع آزمون ۴۰ سؤالی'));

    // اجازه می‌دهیم انیمیشن انتقال صفحه کامل شود؛ تایمر آزمون در این فاصله یک ثانیه جلو نمی‌رود.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('پرسش 1 از 40'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });
}
