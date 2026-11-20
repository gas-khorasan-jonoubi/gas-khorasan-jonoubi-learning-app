import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('application home page opens and exposes main destinations',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('داشبورد'), findsOneWidget);
    expect(find.text('آزمون‌های چهارگزینه‌ای'), findsOneWidget);
    expect(find.text('کتابخانه دیجیتال'), findsOneWidget);

    await tester.tap(find.text('راهنما'));
    await tester.pumpAndSettle();

    expect(find.text('راهنمای استفاده از برنامه'), findsOneWidget);
  });
}
