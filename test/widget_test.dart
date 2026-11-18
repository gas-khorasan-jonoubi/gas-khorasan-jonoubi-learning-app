import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('shows the approved startup screen', (tester) async {
    await tester.pumpWidget(const GasLearningApp());

    expect(find.byType(SplashPage), findsOneWidget);
  });
}
