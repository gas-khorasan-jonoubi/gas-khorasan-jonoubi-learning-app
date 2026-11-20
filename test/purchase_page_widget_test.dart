import 'package:flutter_test/flutter_test.dart';
import 'package:iran_iap/iran_iap.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/purchase_page.dart';
import 'package:gas_khorasan_jonoubi_learning_app/services/lifetime_purchase_service.dart';

class _PurchasePageClient implements IranIapClient {
  @override
  IapStore get store => IapStore.bazaar;

  @override
  bool get isInitialized => true;

  @override
  IapCapabilities get capabilities => const IapCapabilities();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<IapProduct>> queryProducts(
    Set<String> productIds, {
    required IapProductType type,
  }) async {
    if (!productIds.contains('danestani_gaz_lifetime') ||
        type != IapProductType.inApp) {
      return const [];
    }
    return [
      IapProduct(
        id: 'danestani_gaz_lifetime',
        type: IapProductType.inApp,
        title: 'دسترسی دائمی',
        description: 'خرید یک‌باره',
        price: '۱۲۰٬۰۰۰ تومان',
      ),
    ];
  }

  @override
  Future<List<IapPurchase>> queryPurchases({
    required IapProductType type,
  }) async => const [];

  @override
  Future<PurchaseOutcome> purchase(IapPurchaseRequest request) async =>
      const PurchaseCancelled();

  @override
  Future<void> consume(IapPurchase purchase) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('purchase page displays the localized price returned by Bazaar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = LifetimePurchaseService(
      productId: 'danestani_gaz_lifetime',
      publicKey: 'test-public-key',
      client: _PurchasePageClient(),
    );

    await tester.pumpWidget(
      MaterialApp(home: PurchasePage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('قیمت در کافه‌بازار: ۱۲۰٬۰۰۰ تومان'),
      findsOneWidget,
    );
    expect(find.text('خرید و بازیابی دسترسی'), findsOneWidget);
  });

  testWidgets('purchase page clearly reports when Bazaar is not configured', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
