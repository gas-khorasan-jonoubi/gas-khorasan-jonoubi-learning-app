import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guide replaces the training destination and is reachable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('آموزش‌ها'), findsNothing);
    await tester.tap(find.text('راهنما'));
    await tester.pumpAndSettle();

    expect(find.text('راهنمای استفاده'), findsOneWidget);
    expect(find.text('راهنمای استفاده از برنامه'), findsOneWidget);
    expect(find.text('آشنایی با صفحه اصلی'), findsOneWidget);
  });

  testWidgets('guide section expands to show a practical example',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    await tester.tap(find.text('راهنما'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شرکت در آزمون'));
    await tester.pumpAndSettle();

    expect(find.textContaining('برای هر سؤال ۳۰ ثانیه'), findsOneWidget);
    expect(find.textContaining('گزینه پاسخ را لمس کنید'), findsOneWidget);
  });
}
