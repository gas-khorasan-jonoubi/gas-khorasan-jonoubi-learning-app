import 'package:flutter_test/flutter_test.dart';
import 'package:iran_iap/iran_iap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gas_khorasan_jonoubi_learning_app/services/lifetime_purchase_service.dart';

IapPurchase _purchase({
  IapStore store = IapStore.bazaar,
  String productId = 'danestani_gaz_lifetime',
  IapProductType type = IapProductType.inApp,
  IapPurchaseState state = IapPurchaseState.purchased,
}) {
  return IapPurchase(
    store: store,
    productId: productId,
    type: type,
    token: 'test-purchase-token',
    state: state,
    purchaseTime: DateTime.utc(2026, 1, 1),
  );
}

class _FakeIranIapClient implements IranIapClient {
  bool initialized = false;
  bool failPurchaseQuery = false;
  List<IapProduct> products = [];
  List<IapPurchase> ownedPurchases = [];
  PurchaseOutcome outcome = const PurchaseCancelled();
  IapPurchaseRequest? lastPurchaseRequest;
  int consumeCalls = 0;

  @override
  IapStore get store => IapStore.bazaar;

  @override
  bool get isInitialized => initialized;

  @override
  IapCapabilities get capabilities => const IapCapabilities();

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<List<IapProduct>> queryProducts(
    Set<String> productIds, {
    required IapProductType type,
  }) async {
    return products
        .where((product) => productIds.contains(product.id) && product.type == type)
        .toList();
  }

  @override
  Future<List<IapPurchase>> queryPurchases({
    required IapProductType type,
  }) async {
    if (failPurchaseQuery) throw StateError('store temporarily unavailable');
    return ownedPurchases.where((purchase) => purchase.type == type).toList();
  }

  @override
  Future<PurchaseOutcome> purchase(IapPurchaseRequest request) async {
    lastPurchaseRequest = request;
    return outcome;
  }

  @override
  Future<void> consume(IapPurchase purchase) async {
    consumeCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('lifetime access ownership policy', () {
    test('restores a matching active Bazaar in-app purchase', () {
      expect(
        ownsLifetimeAccess(
          [_purchase()],
          productId: 'danestani_gaz_lifetime',
        ),
        isTrue,
      );
    });

    test('does not grant access for another product', () {
      expect(
        ownsLifetimeAccess(
          [_purchase(productId: 'another_product')],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
    });

    test('does not grant access for refunded or unknown purchase states', () {
      expect(
        ownsLifetimeAccess(
          [_purchase(state: IapPurchaseState.refunded)],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
      expect(
        ownsLifetimeAccess(
          [_purchase(state: IapPurchaseState.unknown)],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
    });

    test('does not grant access for subscriptions or purchases from another store', () {
      expect(
        ownsLifetimeAccess(
          [_purchase(type: IapProductType.subscription)],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
      expect(
        ownsLifetimeAccess(
          [_purchase(store: IapStore.myket)],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
    });

    test('does not grant access when no matching purchase exists', () {
      expect(
        ownsLifetimeAccess(
          const [],
          productId: 'danestani_gaz_lifetime',
        ),
        isFalse,
      );
    });
  });

  group('lifetime purchase service', () {
    const sku = 'danestani_gaz_lifetime';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('caches ownership only after a matching purchase is returned by Bazaar', () async {
      final client = _FakeIranIapClient()..ownedPurchases = [_purchase()];
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(await service.restoreAccess(), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('bazaar_lifetime_access_verified_$sku'), isTrue);
    });

    test('keeps previously verified access during a temporary store outage', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('bazaar_lifetime_access_verified_$sku', true);

      final client = _FakeIranIapClient()..failPurchaseQuery = true;
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(await service.restoreAccess(), isTrue);
    });

    test('clears the cached access after a successful query reports no owned product', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('bazaar_lifetime_access_verified_$sku', true);

      final client = _FakeIranIapClient();
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(await service.restoreAccess(), isFalse);
      expect(preferences.getBool('bazaar_lifetime_access_verified_$sku'), isFalse);
    });

    test('does not reuse offline ownership cache from another product ID', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        'bazaar_lifetime_access_verified_old_product',
        true,
      );

      final client = _FakeIranIapClient();
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(await service.restoreAccess(), isFalse);
    });

    test('completes a one-time in-app purchase and never consumes it', () async {
      final purchase = _purchase(productId: sku);
      final client = _FakeIranIapClient()
        ..products = [
          IapProduct(
            id: sku,
            type: IapProductType.inApp,
            title: 'دسترسی دائمی',
            description: 'خرید یک‌باره',
            price: 'قیمت آزمایشی',
          ),
        ]
        ..outcome = PurchaseCompleted(purchase)
        ..ownedPurchases = [purchase];

      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(
        await service.purchaseLifetimeAccess(),
        LifetimePurchaseResult.purchased,
      );
      expect(client.lastPurchaseRequest?.productId, sku);
      expect(client.lastPurchaseRequest?.type, IapProductType.inApp);
      expect(client.consumeCalls, 0);
    });

    test('returns cancellation without granting ownership', () async {
      final client = _FakeIranIapClient()
        ..products = [
          IapProduct(
            id: sku,
            type: IapProductType.inApp,
            title: 'دسترسی دائمی',
            description: 'خرید یک‌باره',
            price: 'قیمت آزمایشی',
          ),
        ]
        ..outcome = const PurchaseCancelled();

      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(
        await service.purchaseLifetimeAccess(),
        LifetimePurchaseResult.cancelled,
      );
      expect(client.consumeCalls, 0);
    });

    test('returns the matching one-time product metadata for price display', () async {
      final client = _FakeIranIapClient()
        ..products = [
          IapProduct(
            id: sku,
            type: IapProductType.inApp,
            title: 'دسترسی دائمی',
            description: 'خرید یک‌باره',
            price: '۱۲۰٬۰۰۰ تومان',
          ),
          IapProduct(
            id: 'another_product',
            type: IapProductType.inApp,
            title: 'محصول دیگر',
            description: '',
            price: 'رایگان',
          ),
        ];
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      final product = await service.queryLifetimeProduct();
      expect(product?.id, sku);
      expect(product?.price, '۱۲۰٬۰۰۰ تومان');
    });

    test('does not start purchase when the product is not returned by Bazaar', () async {
      final client = _FakeIranIapClient();
      final service = LifetimePurchaseService(
        productId: sku,
        client: client,
      );

      expect(
        await service.purchaseLifetimeAccess(),
        LifetimePurchaseResult.productUnavailable,
      );
      expect(client.lastPurchaseRequest, isNull);
    });
  });
}
