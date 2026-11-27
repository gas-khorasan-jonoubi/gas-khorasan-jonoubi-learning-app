import 'dart:convert';
import 'dart:io';

import 'bill_ocr_parser.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _billNavy = Color(0xFF123B66);
const _billYellow = Color(0xFFFFD54F);
const _archiveKey = 'scanned_bill_archive_v1';

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  String _group(String digits) {
    if (digits.isEmpty) return '';
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write('.');
      result.write(digits[i]);
    }
    return result.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = BillOcrParser.normalizeDigits(newValue.text)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _group(digits);
    final digitsBeforeCursor = BillOcrParser.normalizeDigits(
      newValue.text.substring(0, newValue.selection.extentOffset.clamp(0, newValue.text.length)),
    ).replaceAll(RegExp(r'[^0-9]'), '').length;

    var cursor = 0;
    var seenDigits = 0;
    while (cursor < formatted.length && seenDigits < digitsBeforeCursor) {
      if (formatted.codeUnitAt(cursor) >= 48 && formatted.codeUnitAt(cursor) <= 57) {
        seenDigits++;
      }
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }

}

class BillSharePage extends StatefulWidget {
  const BillSharePage({super.key});

  @override
  State<BillSharePage> createState() => _BillSharePageState();
}

class _BillSharePageState extends State<BillSharePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _billId = TextEditingController();
  final _paymentId = TextEditingController();
  final _amount = TextEditingController();
  final _periods = TextEditingController();
  final _mobile = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;

  bool _sms = true;
  bool _social = false;
  bool _busy = false;

  @override
  void dispose() {
    _speech.stop();
    _name.dispose();
    _billId.dispose();
    _paymentId.dispose();
    _amount.dispose();
    _periods.dispose();
    _mobile.dispose();
    super.dispose();
  }

  String _digits(String value) => BillOcrParser.normalizeDigits(value);

  String _spokenDigits(String value) {
    final normalized = BillOcrParser.normalizeDigits(value);
    final directDigits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (directDigits.isNotEmpty) return directDigits;
    const words = <String, String>{
      'صفر': '0', 'یک': '1', 'یه': '1', 'اول': '1',
      'دو': '2', 'دوتا': '2', 'سه': '3', 'سه‌تا': '3',
      'چهار': '4', 'پنج': '5', 'شش': '6', 'شیش': '6',
      'هفت': '7', 'هشت': '8', 'نه': '9',
    };
    final tokens = normalized
        .replaceAll('،', ' ')
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final result = StringBuffer();
    for (final token in tokens) {
      final digit = words[token];
      if (digit == null) return '';
      result.write(digit);
    }
    return result.toString();
  }

  String _message() => BillOcrParser.buildMessage(
    name: _name.text,
    billId: _billId.text,
    paymentId: _paymentId.text,
    amount: _amount.text,
    periods: _periods.text,
  );

  Future<void> _saveArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_archiveKey) ?? <String>[];
    items.insert(0, jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'name': _name.text.trim(),
      'billId': _billId.text.trim(),
      'paymentId': _paymentId.text.trim(),
      'amount': _amount.text.trim(),
      'periods': _periods.text.trim(),
      'mobile': _mobile.text.trim(),
    }));
    await prefs.setStringList(_archiveKey, items.take(100).toList());
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _digits(_mobile.text).replaceAll(RegExp(r'[^0-9+]'), '');
    if (_sms && !BillOcrParser.isValidIranianMobile(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای ارسال پیامک، شماره موبایل معتبر ۱۱ رقمی با ۰۹ وارد کنید.'),
        ),
      );
      return;
    }
    if (!_sms && !_social) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک روش اشتراک‌گذاری را انتخاب کنید.')),
      );
      return;
    }
    final text = _message();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأیید نهایی ارسال قبض'),
        content: SingleChildScrollView(
          child: SelectableText(
            '${_sms ? 'شماره گیرنده: $phone\n\n' : ''}$text',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('بازبینی و انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تأیید و ادامه'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _saveArchive();
      if (_sms) {
        final smsUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: <String, String>{'body': text},
        );
        final opened = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('برنامه پیامک گوشی باز نشد.')),
          );
        }
      }
      if (_social) {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            title: 'اطلاعات قبض گاز',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اشتراک‌گذاری کامل نشد. برنامه مقصد را بررسی کنید.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanQrInto(TextEditingController controller) async {
    if (_busy) return;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسکن QR برای همین فیلد'),
        content: SizedBox(
          width: 160,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final raw = capture.barcodes.first.rawValue?.trim();
                if (raw == null || raw.isEmpty) return;
                Navigator.of(dialogContext).pop(raw);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty && mounted) {
      controller.text = value;
      controller.selection = TextSelection.collapsed(offset: value.length);
    }
  }

  Future<void> _listenInto(TextEditingController controller) async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() {});
      return;
    }
    try {
      _speechReady = await _speech.initialize(
        onStatus: (_) { if (mounted) setState(() {}); },
        onError: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تشخیص گفتار در گوشی در دسترس نیست.')),
            );
          }
        },
      );
      if (!_speechReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سرویس تشخیص گفتار فارسی روی گوشی فعال نیست.')),
          );
        }
        return;
      }
      await _speech.listen(
        localeId: 'fa_IR',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted || result.recognizedWords.trim().isEmpty) return;
          final spoken = result.recognizedWords.trim();
          final isNumericField = controller == _periods || controller == _mobile;
          controller.text = isNumericField ? _spokenDigits(spoken) : spoken;
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
          setState(() {});
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شروع ورود صوتی ممکن نشد؛ مجوز میکروفون و سرویس گفتار گوشی را بررسی کنید.')),
        );
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    bool mobile = false,
    bool periods = false,
    bool rialAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: mobile || periods
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                LengthLimitingTextInputFormatter(mobile ? 11 : 3),
              ]
            : rialAmount
                ? [_ThousandsSeparatorInputFormatter()]
                : null,
        validator: mobile
            ? (value) {
                final normalized = _digits(value ?? '');
                if (normalized.isEmpty) {
                  return _sms ? 'برای ارسال پیامک، شماره موبایل را وارد کنید.' : null;
                }
                return BillOcrParser.isValidIranianMobile(normalized)
                    ? null
                    : 'شماره موبایل باید دقیقاً ۱۱ رقم و با ۰۹ شروع شود.';
              }
            : required
                ? (value) => (value == null || value.trim().isEmpty)
                    ? 'این فیلد الزامی است'
                    : null
                : null,
        textDirection: mobile || periods ? TextDirection.ltr : TextDirection.rtl,
        textAlign: mobile || periods ? TextAlign.right : TextAlign.start,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'اسکن QR برای $label',
                onPressed: _busy ? null : () => _scanQrInto(controller),
                icon: const Icon(Icons.qr_code_scanner),
              ),
              IconButton(
                tooltip: 'ورود صوتی برای $label',
                onPressed: _busy ? null : () => _listenInto(controller),
                icon: Icon(_speech.isListening ? Icons.mic_off : Icons.mic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: _billNavy,
      foregroundColor: Colors.white,
      title: const Text('اسکن و اشتراک‌گذاری قبض'),
      actions: [
        IconButton(
          tooltip: 'آرشیو قبض‌ها',
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BillArchivePage()),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _billNavy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(children: [
            Icon(Icons.document_scanner_outlined, color: _billYellow, size: 36),
            SizedBox(width: 12),
            Expanded(child: Text(
              'برای ورود اطلاعات، QR کنار همان فیلد یا میکروفون را بزنید؛ اطلاعات را بررسی و اصلاح کنید، سپس روش ارسال را انتخاب کنید.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        if (_busy) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(children: [
            _field('نام مشترک', _name, required: true),
            _field('شناسه قبض', _billId, keyboard: TextInputType.number, required: true),
            _field('شناسه پرداخت', _paymentId, keyboard: TextInputType.number, required: true),
            _field('مبلغ بدهی (ریال) — جداکنندهٔ سه‌رقمی', _amount, keyboard: TextInputType.number, required: true, rialAmount: true),
            _field('تعداد دوره‌های بدهی (حداکثر ۳ رقم)', _periods, keyboard: TextInputType.number, periods: true),
            _field('شماره موبایل دریافت‌کننده (۱۱ رقم)', _mobile, keyboard: TextInputType.phone, mobile: true),
          ]),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('روش اشتراک‌گذاری', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sms,
                onChanged: _busy ? null : (v) => setState(() { _sms = v ?? false; if (v == true) _social = false; }),
                title: const Text('پیامک'),
                subtitle: const Text('فقط متن اطلاعات قبض'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _social,
                onChanged: _busy ? null : (v) => setState(() { _social = v ?? false; if (v == true) _sms = false; }),
                title: const Text('شبکه‌های اجتماعی'),
                subtitle: const Text('فقط متن اطلاعات قبض؛ انتخاب برنامه و گیرنده در مقصد'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _billYellow, foregroundColor: Colors.black, padding: const EdgeInsets.all(15)),
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share),
          label: const Text('اشتراک‌گذاری قبض', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        const Text(
          'توجه: متن و اعداد تشخیص‌داده‌شده را پیش از ارسال کنترل کنید. تشخیص متن فارسی در موتور آفلاین فعلی محدود است؛ نام و شناسه‌ها را حتماً بررسی و در صورت نیاز اصلاح کنید.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class BillArchivePage extends StatefulWidget {
  const BillArchivePage({super.key});

  @override
  State<BillArchivePage> createState() => _BillArchivePageState();
}

class _BillArchivePageState extends State<BillArchivePage> {
  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_archiveKey) ?? <String>[];
    final records = <Map<String, dynamic>>[];
    for (final value in values) {
      try {
        final item = jsonDecode(value);
        if (item is Map<String, dynamic>) records.add(item);
      } catch (_) {}
    }
    return records;
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_archiveKey) ?? <String>[];
    values.removeWhere((value) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map && decoded['date'] == item['date'];
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_archiveKey, values);
    final path = item['imagePath'];
    if (path is String) {
      try { final file = File(path); if (await file.exists()) await file.delete(); } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('آرشیو قبض‌های اسکن‌شده')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) return const Center(child: Text('هنوز قبضی ذخیره نشده است.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final item = records[index];
            final date = DateTime.tryParse(item['date'] as String? ?? '');
            final path = item['imagePath'];
            return Card(
              child: ListTile(
                leading: path is String && File(path).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(path), width: 52, height: 52, fit: BoxFit.cover),
                      )
                    : const CircleAvatar(child: Icon(Icons.receipt_long)),
                title: Text((item['name'] as String?)?.isNotEmpty == true ? item['name'] as String : 'قبض بدون نام'),
                subtitle: Text('شناسه قبض: ${item['billId'] ?? '-'}\n${date == null ? '' : '${date.year}/${date.month}/${date.day}'}'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'حذف از آرشیو',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(item),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('اطلاعات قبض'),
                    content: SingleChildScrollView(child: Text(
                      'نام مشترک: ${item['name'] ?? '-'}\n'
                      'شناسه قبض: ${item['billId'] ?? '-'}\n'
                      'شناسه پرداخت: ${item['paymentId'] ?? '-'}\n'
                      'مبلغ قابل پرداخت: ${item['amount'] ?? '-'} ریال\n'
                      'دوره‌ها: ${item['periods'] ?? '-'}\n'
                      'موبایل: ${item['mobile'] ?? '-'}',
                    )),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
