import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';
import 'package:gas_khorasan_jonoubi_learning_app/knowledge_pages.dart';

void _useCompactViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('dashboard remains usable on a compact RTL phone screen', (tester) async {
    _useCompactViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
    expect(find.text('آزمون‌های چهارگزینه‌ای'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('راهنمای استفاده'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('راهنمای استفاده'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline library search and area filters fit a compact RTL screen', (tester) async {
    _useCompactViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: KnowledgeBrowserPage(
              title: 'کتابخانه',
              description: 'مطالب آفلاین',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('knowledge-search')),
      'HSE',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('knowledge-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
