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
}
