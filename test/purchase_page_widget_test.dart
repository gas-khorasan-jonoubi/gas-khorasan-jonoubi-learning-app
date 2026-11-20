import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/purchase_page.dart';

void main() {
  testWidgets('purchase page clearly reports when Bazaar is not configured', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PurchasePage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('خرید و بازیابی دسترسی'), findsOneWidget);
    expect(find.textContaining('اتصال خرید هنوز پیکربندی نشده است'), findsOneWidget);
    expect(find.text('خرید دائمی از کافه‌بازار'), findsOneWidget);

    final buyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'خرید دائمی از کافه‌بازار'),
    );
    expect(buyButton.onPressed, isNull);
  });
}
