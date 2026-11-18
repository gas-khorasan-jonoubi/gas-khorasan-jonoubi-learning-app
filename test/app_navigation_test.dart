import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the splash screen opens the dashboard after three seconds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.text('داشبورد'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('داشبورد'), findsOneWidget);
  });

  testWidgets('exam keeps a selected answer when navigating between questions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExamPage()),
      ),
    );

    expect(
      find.text('هدف اصلی آموزش ایمنی در محیط کار چیست؟'),
      findsOneWidget,
    );
    expect(find.text('01:30'), findsOneWidget);

    await tester.tap(find.text('افزایش سرعت کار'));
    await tester.pump();
    expect(find.text('پاسخ ثبت شد'), findsOneWidget);

    await tester.tap(find.text('سؤال بعد'));
    await tester.pump();
    expect(
      find.text('در صورت مشاهده وضعیت ناایمن چه باید کرد؟'),
      findsOneWidget,
    );

    await tester.tap(find.text('سؤال قبل'));
    await tester.pump();
    expect(
      find.text('هدف اصلی آموزش ایمنی در محیط کار چیست؟'),
      findsOneWidget,
    );
    expect(find.text('پاسخ ثبت شد'), findsOneWidget);
  });
}
