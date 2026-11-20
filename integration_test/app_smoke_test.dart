import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and main sections work on Android emulator',
      (tester) async {
    await tester.pumpWidget(const GasLearningApp());

    // Splash screen intentionally remains visible for three seconds.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
    expect(find.text('آزمون‌های چهارگزینه‌ای'), findsOneWidget);

    await tester.tap(find.text('راهنما'));
    await tester.pumpAndSettle();
    expect(find.text('راهنمای استفاده از برنامه'), findsOneWidget);

    await tester.tap(find.text('کتابخانه'));
    await tester.pumpAndSettle();
    expect(find.text('کتابخانه دیجیتال'), findsOneWidget);

    await tester.tap(find.text('نتایج'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز نتیجه‌ای ثبت نشده است.'), findsOneWidget);
  });
}
