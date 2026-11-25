import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('damaged history entries do not hide valid saved results', (tester) async {
    SharedPreferences.setMockInitialValues({
      'exam_results': [
        '{not valid json',
        '{"date":"not-a-date","examTitle":"رکورد خراب","total":40}',
        '{"date":"2026-11-24T10:30:00.000","examTitle":"آزمون سالم","total":40,"correct":32,"wrong":5,"unanswered":3}',
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ResultsPage())));
    await tester.pumpAndSettle();

    expect(find.textContaining('آزمون سالم'), findsOneWidget);
    expect(find.textContaining('رکورد خراب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed question breakdown opens as a legacy summary safely', (tester) async {
    SharedPreferences.setMockInitialValues({
      'exam_results': [
        '{"date":"2026-11-24T10:30:00.000","examTitle":"سابقه قدیمی","total":40,"correct":20,"wrong":10,"unanswered":10,"questions":[{}],"answers":[]}',
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ResultsPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('سابقه قدیمی'));
    await tester.pumpAndSettle();

    expect(find.text('جزئیات نتیجه آزمون'), findsOneWidget);
    expect(find.textContaining('این نتیجه در نسخهٔ قبلی برنامه ثبت شده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
