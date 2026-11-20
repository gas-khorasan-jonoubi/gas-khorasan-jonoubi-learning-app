import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('application starts in Persian with right-to-left layout', (tester) async {
    await tester.pumpWidget(const GasLearningApp());
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(direction.textDirection, TextDirection.rtl);
  });
}
