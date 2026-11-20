import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('dashboard opens the offline training area', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
    await tester.tap(find.text('آموزش').last);
    await tester.pumpAndSettle();

    expect(find.text('مطالب پایه برای آشنایی با وظایف و اصول عمومی کار در واحدهای مختلف'), findsOneWidget);
    expect(find.text('آشنایی با مأموریت خدمات گازرسانی'), findsOneWidget);
  });

  testWidgets('app opens dashboard only after lifetime access is confirmed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartGate(accessCheck: () async => true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('به سامانه آموزش خوش آمدید'), findsOneWidget);
    expect(find.text('خرید و بازیابی دسترسی'), findsNothing);
  });

  testWidgets('app shows purchase page when lifetime access is not confirmed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartGate(accessCheck: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('خرید و بازیابی دسترسی'), findsOneWidget);
    expect(find.text('به سامانه آموزش خوش آمدید'), findsNothing);
  });

  testWidgets('app safely denies entry when access check fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartGate(
          accessCheck: () async => throw StateError('temporary failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('خرید و بازیابی دسترسی'), findsOneWidget);
    expect(find.text('به سامانه آموزش خوش آمدید'), findsNothing);
  });
}
