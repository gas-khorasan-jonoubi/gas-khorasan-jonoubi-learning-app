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

  testWidgets('help explains quiz timing, library search and purchase restore', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    await tester.pumpAndSettle();

    expect(find.text('راهنمای استفاده از برنامه'), findsOneWidget);

    final quizInfo = find.textContaining('۲۰ آزمون مستقل');
    await tester.scrollUntilVisible(
      quizInfo,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(quizInfo, findsOneWidget);

    final libraryTitle = find.text('آموزش و کتابخانه دیجیتال');
    await tester.scrollUntilVisible(
      libraryTitle,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(libraryTitle, findsOneWidget);

    final purchaseTitle = find.text('خرید دائمی و بازیابی خرید');
    await tester.scrollUntilVisible(
      purchaseTitle,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(purchaseTitle, findsOneWidget);

    final restoreGuidance = find.textContaining('همان حساب قبلی');
    await tester.scrollUntilVisible(
      restoreGuidance,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(restoreGuidance, findsOneWidget);
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
