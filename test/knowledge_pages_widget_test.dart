import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/knowledge_pages.dart';

Widget _testHost() => const MaterialApp(
      home: Scaffold(
        body: KnowledgeBrowserPage(
          title: 'کتابخانه',
          description: 'مطالب آفلاین',
        ),
      ),
    );

void main() {
  testWidgets('search finds an offline knowledge article', (tester) async {
    await tester.pumpWidget(_testHost());

    await tester.enterText(
      find.byKey(const ValueKey('knowledge-search')),
      'شبه‌حادثه',
    );
    await tester.pumpAndSettle();

    expect(find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه'), findsOneWidget);
    expect(find.text('آشنایی با مأموریت خدمات گازرسانی'), findsNothing);
  });


  testWidgets('search finds a newly added shift handover article', (tester) async {
    await tester.pumpWidget(_testHost());

    await tester.enterText(
      find.byKey(const ValueKey('knowledge-search')),
      'تحویل شیفت',
    );
    await tester.pumpAndSettle();

    expect(find.text('تحویل شیفت و انتقال وضعیت کار'), findsOneWidget);
  });

  testWidgets('opening an article shows its full text and safety note', (tester) async {
    await tester.pumpWidget(_testHost());

    await tester.enterText(
      find.byKey(const ValueKey('knowledge-search')),
      'شبه‌حادثه',
    );
    await tester.pumpAndSettle();

    final articleTile = find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه');
    expect(articleTile, findsOneWidget);
    await tester.tap(articleTile);
    await tester.pumpAndSettle();

    expect(
      find.text('فرهنگ گزارش‌دهی خطر و شبه‌حادثه'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('article-safety-note')), findsOneWidget);
    expect(
      find.textContaining('این مطلب آموزشی عمومی است'),
      findsOneWidget,
    );
  });
}
