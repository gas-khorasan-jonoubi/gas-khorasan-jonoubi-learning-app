import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('splash uses neutral app wording without organization labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(hours: 1),
          prepareSplash: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('به دانستنی‌های گاز خوش آمدید'), findsOneWidget);
    expect(find.text('آموزش، مطالعه و سنجش آموخته‌ها'), findsOneWidget);
    expect(find.textContaining('شرکت'), findsNothing);
    expect(find.textContaining('اداره'), findsNothing);
    expect(find.textContaining('شهرستان'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash remains visible for three seconds then opens dashboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(displayDuration: const Duration(seconds: 3)),
      ),
    );
    await tester.pump();

    expect(find.text('به دانستنی‌های گاز خوش آمدید'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('داشبورد'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('داشبورد'), findsOneWidget);
  });

  testWidgets('splash timer is cancelled safely when the page is disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(hours: 1),
          prepareSplash: (_) async {},
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
