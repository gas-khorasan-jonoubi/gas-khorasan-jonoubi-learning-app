import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the splash screen opens the dashboard after three seconds',
      (tester) async {
    await tester.pumpWidget(const GasLearningApp());

    expect(find.text('داشبورد'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('داشبورد'), findsOneWidget);
  });

  testWidgets('exam keeps a selected answer when navigating between questions',
      (tester) async {
    await tester.pumpWidget(const GasLearningApp());

    // The app must first complete its normal three-second splash transition.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // Open the exam through the actual bottom navigation used by the app.
    await tester.tap(find.text('آزمون'));
    await tester.pump();

    expect(
      find.text('هدف اصلی آموزش ایمنی در محیط کار چیست؟'),
      findsOneWidget,
    );
    expect(find.text('01:30'), findsOneWidget);

    await tester.tap(find.text('افزایش سرعت کار'));
    await tester.pump();
    expect(find.text('پاسخ ثبت شد'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('سؤال بعد'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('سؤال بعد'));
    await tester.pump();
    expect(
      find.text('در صورت مشاهده وضعیت ناایمن چه باید کرد؟'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('سؤال قبل'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('سؤال قبل'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('هدف اصلی آموزش ایمنی در محیط کار چیست؟'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('هدف اصلی آموزش ایمنی در محیط کار چیست؟'),
      findsOneWidget,
    );
    expect(find.text('پاسخ ثبت شد'), findsOneWidget);
  });
}
