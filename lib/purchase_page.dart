import 'package:flutter/foundation.dart';
import 'package:iran_iap/iran_iap.dart';
import 'package:material_ui/material_ui.dart';
import 'services/lifetime_purchase_service.dart';

class PurchasePage extends StatefulWidget {
  final LifetimePurchaseService? service;
  final VoidCallback? onAccessGranted;

  const PurchasePage({
    super.key,
    this.service,
    this.onAccessGranted,
  });

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  late final LifetimePurchaseService _service =
      widget.service ?? lifetimePurchaseService;
  bool _busy = true;
  bool _hasAccess = false;
  String? _productPrice;
  String _message = 'در حال بررسی وضعیت خرید...';

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    if (!_isAndroid) {
      setState(() {
        _busy = false;
        _message = 'خرید درون‌برنامه‌ای این نسخه فقط از طریق اندروید و کافه‌بازار انجام می‌شود.';
      });
      return;
    }
    if (!_service.isConfigured) {
      setState(() {
        _busy = false;
        _message =
            'اتصال خرید هنوز پیکربندی نشده است. پس از ثبت شناسه محصول و کلید عمومی تأیید خرید کافه‌بازار، خرید و بازیابی فعال می‌شود.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = 'در حال بررسی خریدهای ثبت‌شده در کافه‌بازار...';
    });
    try {
      final owned = await _service.restoreAccess();
      String? price;
      if (!owned) {
        try {
          final product = await _service.queryLifetimeProduct();
          price = product?.price.trim().isNotEmpty == true
              ? product!.price
              : null;
        } catch (_) {
          // A price lookup failure must not discard a previously verified
          // ownership result or prevent the restore screen from loading.
        }
      }
      if (!mounted) return;
      setState(() {
        _hasAccess = owned;
        _productPrice = price;
        _message = owned
            ? 'دسترسی دائمی این برنامه برای حساب کافه‌بازار شما فعال است.'
            : 'برای فعال‌سازی دائمی، خرید را انجام دهید یا خرید قبلی را بازیابی کنید.';
      });
      if (owned) _notifyAccessGranted();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _friendlyError(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy() async {
    if (_busy || !_isAndroid || !_service.isConfigured || _hasAccess) return;
    setState(() {
      _busy = true;
      _message = 'در حال اتصال به کافه‌بازار...';
    });
    try {
      final result = await _service.purchaseLifetimeAccess();
      if (!mounted) return;
      switch (result) {
        case LifetimePurchaseResult.purchased:
          setState(() {
            _hasAccess = true;
            _message = 'خرید تأیید شد؛ دسترسی دائمی فعال است.';
          });
          _notifyAccessGranted();
          break;
        case LifetimePurchaseResult.cancelled:
          setState(() => _message = 'خرید توسط شما لغو شد.');
          break;
        case LifetimePurchaseResult.productUnavailable:
          setState(() => _message = 'محصول خرید در پنل کافه‌بازار پیدا نشد یا هنوز فعال نشده است.');
          break;
        case LifetimePurchaseResult.purchaseNotConfirmed:
          setState(() => _message = 'خرید هنوز در فهرست خریدهای تأییدشده کافه‌بازار دیده نمی‌شود. از بازیابی خرید استفاده کنید.');
          break;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notifyAccessGranted() {
    final callback = widget.onAccessGranted;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  String _friendlyError(Object error) {
    if (error is IapException) {
      return switch (error.code) {
        IapErrorCode.storeNotInstalled =>
          'برای خرید یا بازیابی، برنامه کافه‌بازار باید روی دستگاه نصب و حساب شما در آن فعال باشد.',
        IapErrorCode.serviceUnavailable =>
          'ارتباط با سرویس پرداخت کافه‌بازار برقرار نشد. اتصال اینترنت و وضعیت کافه‌بازار را بررسی و دوباره تلاش کنید.',
        IapErrorCode.activityUnavailable =>
          'امکان بازکردن صفحه پرداخت فراهم نشد. برنامه را دوباره اجرا کنید و مجدداً تلاش کنید.',
        IapErrorCode.notInitialized =>
          'اتصال کافه‌بازار آماده نیست. چند لحظه بعد دوباره برای بررسی یا بازیابی خرید تلاش کنید.',
        _ =>
          'بررسی خرید انجام نشد. لطفاً کافه‌بازار و اتصال اینترنت را بررسی و دوباره تلاش کنید.',
      };
    }
    return 'بررسی خرید انجام نشد. لطفاً کافه‌بازار و اتصال اینترنت را بررسی و دوباره تلاش کنید.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('خرید و بازیابی دسترسی')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium_outlined, size: 42, color: Color(0xFF123B66)),
                    const SizedBox(height: 12),
                    const Text(
                      'دسترسی دائمی به دانستنی‌های گاز',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'خرید یک‌باره است و اشتراک ماهانه یا تمدید دوره‌ای ندارد. خرید به حساب کافه‌بازار شما متصل می‌شود و پس از نصب مجدد یا تعویض گوشی، از همین بخش قابل بازیابی خواهد بود.',
                    ),
                    if (_productPrice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'قیمت در کافه‌بازار: $_productPrice',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF123B66),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _hasAccess ? Icons.verified : Icons.info_outline,
                          color: _hasAccess ? Colors.green : const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_message)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || !_isAndroid || !_service.isConfigured || _hasAccess
                  ? null
                  : _buy,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('خرید دائمی از کافه‌بازار'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || !_isAndroid || !_service.isConfigured
                  ? null
                  : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('بازیابی خرید قبلی'),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 10),
            const Text(
              'توجه: برای خرید و بازیابی، کافه‌بازار باید نصب باشد و کاربر با همان حساب قبلی در آن وارد شده باشد. پس از تأیید مالکیت، محصول دائمی مصرف یا حذف نمی‌شود.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      );
}
