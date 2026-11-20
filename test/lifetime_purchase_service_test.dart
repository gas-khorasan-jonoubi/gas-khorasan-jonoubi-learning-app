import 'package:flutter_test/flutter_test.dart';
import 'package:iran_iap/iran_iap.dart';
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
}
