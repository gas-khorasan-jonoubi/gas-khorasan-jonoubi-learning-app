import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/knowledge_pages.dart';

void main() {
  testWidgets('search finds an offline knowledge article', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KnowledgeBrowserPage(
          title: 'کتابخانه',
          description: 'مطالب آفلاین',
        ),
      ),
    );

    expect(find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('knowledge-search')), 'شبه‌حادثه');
    await tester.pump();

    expect(find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه'), findsOneWidget);
    expect(find.text('آشنایی با مأموریت خدمات گازرسانی'), findsNothing);
  });

  testWidgets('opening an article shows its full text and safety note', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KnowledgeBrowserPage(
          title: 'کتابخانه',
          description: 'مطالب آفلاین',
        ),
      ),
    );

    await tester.tap(find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه'));
    await tester.pumpAndSettle();

    expect(find.text('نکات کلیدی'), findsOneWidget);
    expect(
      find.textContaining('این مطلب آموزشی عمومی است'),
      findsOneWidget,
    );
  });
}
