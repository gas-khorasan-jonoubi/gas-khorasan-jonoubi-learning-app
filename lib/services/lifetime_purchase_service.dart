import 'package:iran_iap/iran_iap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The permanent product ID and Bazaar's public signature-verification key
/// are supplied by the release configuration. The public key is not a secret.
const bazaarLifetimeProductId = String.fromEnvironment(
  'BAZAAR_LIFETIME_PRODUCT_ID',
);
const bazaarRsaPublicKey = String.fromEnvironment(
  'BAZAAR_RSA_PUBLIC_KEY',
);

/// A release build may bypass billing only when it is explicitly produced
/// for private testing. Public/tagged releases must require Bazaar ownership.
bool canEnterWithoutPurchaseConfiguration({
  required bool isReleaseBuild,
  bool allowPrivateTestAccess = false,
}) =>
    !isReleaseBuild || allowPrivateTestAccess;

enum LifetimePurchaseResult {
  purchased,
  cancelled,
  productUnavailable,
  purchaseNotConfirmed,
}

/// True only for an active, non-consumable purchase of this app's lifetime SKU.
bool ownsLifetimeAccess(
  Iterable<IapPurchase> purchases, {
  required String productId,
}) {
  return purchases.any(
    (purchase) =>
        purchase.store == IapStore.bazaar &&
        purchase.productId == productId &&
        purchase.type == IapProductType.inApp &&
        purchase.state == IapPurchaseState.purchased,
  );
}

/// Cafe Bazaar one-time, non-consumable lifetime access.
///
/// No local preference is treated as proof of ownership. Access is restored
/// from the Bazaar-owned purchase inventory; permanent products are never
/// consumed.
class LifetimePurchaseService {
  LifetimePurchaseService({
    String productId = bazaarLifetimeProductId,
    String publicKey = bazaarRsaPublicKey,
    IranIapClient? client,
  })  : productId = productId.trim(),
        _publicKey = publicKey.trim(),
        _injectedClient = client;

  final String productId;
  final String _publicKey;
  final IranIapClient? _injectedClient;
  IranIapClient? _client;

  bool get isConfigured => productId.isNotEmpty && _publicKey.isNotEmpty;

  IranIapClient get _billingClient {
    if (!isConfigured) {
      throw StateError(
        'شناسه محصول و کلید عمومی تأیید خرید کافه‌بازار هنوز پیکربندی نشده‌اند.',
      );
    }
    return _client ??= _injectedClient ??
        IranIap(
          config: IranIapConfig(
            storePublicKey: _publicKey,
            bazaarSecurityMode: BazaarSecurityMode.localVerification,
            enableSubscriptions: false,
          ),
        );
  }

  String get _cachedOwnershipKey => 'bazaar_lifetime_access_verified_$productId';

  Future<bool> restoreAccess() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedOwnership = preferences.getBool(_cachedOwnershipKey) ?? false;

    try {
      final client = _billingClient;
      await client.initialize();
      final owned = await client.queryPurchases(
        type: IapProductType.inApp,
      );
      final isOwned = ownsLifetimeAccess(owned, productId: productId);

      // A positive cache is written only after the Bazaar inventory returns
      // a matching purchase whose signature was checked locally.
      await preferences.setBool(_cachedOwnershipKey, isOwned);
      return isOwned;
    } catch (_) {
      // Preserve previously verified access for offline use. A successful
      // later store query can still revoke this cache if the purchase is
      // refunded or no longer owned.
      if (cachedOwnership) return true;
      rethrow;
    }
  }

  Future<IapProduct?> queryLifetimeProduct() async {
    final client = _billingClient;
    await client.initialize();
    final products = await client.queryProducts(
      {productId},
      type: IapProductType.inApp,
    );
    for (final product in products) {
      if (product.id == productId && product.type == IapProductType.inApp) {
        return product;
      }
    }
    return null;
  }

  Future<LifetimePurchaseResult> purchaseLifetimeAccess() async {
    final client = _billingClient;
    await client.initialize();

    final product = await queryLifetimeProduct();
    if (product == null) {
      return LifetimePurchaseResult.productUnavailable;
    }

    final outcome = await client.purchase(
      IapPurchaseRequest(
        productId: productId,
        type: IapProductType.inApp,
        payload: 'danestani_gaz_lifetime_access',
      ),
    );

    if (outcome is PurchaseCancelled) {
      return LifetimePurchaseResult.cancelled;
    }

    final completed = outcome as PurchaseCompleted;
    final purchase = completed.purchase;
    if (purchase.productId != productId ||
        purchase.store != IapStore.bazaar ||
        purchase.type != IapProductType.inApp ||
        purchase.state != IapPurchaseState.purchased) {
      return LifetimePurchaseResult.purchaseNotConfirmed;
    }

    // Confirm ownership through the store inventory. Never consume a
    // permanent lifetime-access purchase.
    final restored = await restoreAccess();
    return restored
        ? LifetimePurchaseResult.purchased
        : LifetimePurchaseResult.purchaseNotConfirmed;
  }
}

/// Shared app-level service; the native client is created lazily only after
/// build-time Bazaar configuration is supplied.
final lifetimePurchaseService = LifetimePurchaseService();
