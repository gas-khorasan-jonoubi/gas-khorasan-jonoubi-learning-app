import 'dart:convert';
import 'dart:io';

import 'bill_ocr_parser.dart';

import 'package:material_ui/material_ui.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _billNavy = Color(0xFF123B66);
const _billYellow = Color(0xFFFFD54F);
const _archiveKey = 'scanned_bill_archive_v1';

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
  final _picker = ImagePicker();

  bool _sms = true;
  bool _social = false;
  bool _busy = false;
  String _recognizedText = '';
  String? _imagePath;
  String? _savedImagePath;

  @override
  void dispose() {
    _name.dispose();
    _billId.dispose();
    _paymentId.dispose();
    _amount.dispose();
    _periods.dispose();
    _mobile.dispose();
    super.dispose();
  }

  String _digits(String value) => BillOcrParser.normalizeDigits(value);

  Future<void> _scan() => _chooseImage(ImageSource.camera);

  Future<void> _chooseImage(ImageSource source) async {
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _imagePath = photo.path;
      _savedImagePath = null;
    });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final billsDir = Directory('${directory.path}/bill_archive');
      if (!await billsDir.exists()) {
        await billsDir.create(recursive: true);
      }
      final saved = await File(photo.path).copy(
        '${billsDir.path}/bill_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      _savedImagePath = saved.path;
      final text = await TesseractOcr.extractText(
        photo.path,
        config: OCRConfig(
          language: 'fas+eng',
          engine: OCREngine.tesseract,
          options: {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '6',
          },
        ),
      );
      _recognizedText = text;
      _fillRecognizedFields(text);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تصویر دریافت شد؛ اطلاعات تشخیص‌داده‌شده را بررسی و در صورت نیاز اصلاح کنید.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خواندن تصویر انجام نشد. دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillRecognizedFields(String raw) {
    final parsed = BillOcrParser.parse(raw);
    setState(() {
      if (parsed.name != null && _name.text.isEmpty) _name.text = parsed.name!;
      if (parsed.mobile != null && _mobile.text.isEmpty) _mobile.text = parsed.mobile!;
      if (parsed.billId != null && _billId.text.isEmpty) _billId.text = parsed.billId!;
      if (parsed.paymentId != null && _paymentId.text.isEmpty) _paymentId.text = parsed.paymentId!;
      if (parsed.amount != null && _amount.text.isEmpty) _amount.text = parsed.amount!;
      if (parsed.periods != null && _periods.text.isEmpty) _periods.text = parsed.periods!;
    });
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
      'imagePath': _savedImagePath ?? _imagePath,
    }));
    await prefs.setStringList(_archiveKey, items.take(100).toList());
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _digits(_mobile.text).replaceAll(RegExp(r'[^0-9+]'), '');
    if (_sms && !RegExp(r'^09[0-9]{9}$').hasMatch(phone)) {
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
    if (_social && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای ارسال متن و تصویر، ابتدا قبض را با دوربین اسکن کنید.')),
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
        final imagePath = _savedImagePath ?? _imagePath;
        if (imagePath == null || !await File(imagePath).exists()) {
          throw StateError('ابتدا قبض را با دوربین اسکن کنید.');
        }
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            title: 'اطلاعات قبض گاز',
            files: <XFile>[XFile(imagePath)],
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

  Widget _field(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: required ? (value) => (value == null || value.trim().isEmpty) ? 'این فیلد الزامی است' : null : null,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
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
              'از قبض عکس بگیرید؛ اطلاعات را بررسی و اصلاح کنید، سپس روش ارسال را انتخاب کنید.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _billNavy, padding: const EdgeInsets.all(14)),
          onPressed: _busy ? null : _scan,
          icon: const Icon(Icons.camera_alt),
          label: const Text('اسکن قبض با دوربین'),
        ),
        const SizedBox(height: 8),
        if (_busy) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_imagePath!), height: 180, fit: BoxFit.contain),
          ),
        ],
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(children: [
            _field('نام مشترک', _name, required: true),
            _field('شناسه قبض', _billId, keyboard: TextInputType.number, required: true),
            _field('شناسه پرداخت', _paymentId, keyboard: TextInputType.number, required: true),
            _field('مبلغ بدهی (ریال)', _amount, keyboard: TextInputType.number, required: true),
            _field('تعداد دوره‌های بدهی', _periods, keyboard: TextInputType.number),
            _field('شماره موبایل دریافت‌کننده (برای پیامک الزامی)', _mobile, keyboard: TextInputType.phone),
          ]),
        ),
        if (_recognizedText.isNotEmpty)
          ExpansionTile(
            title: const Text('متن خام تشخیص‌داده‌شده'),
            children: [Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_recognizedText),
            )],
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
                subtitle: const Text('متن و تصویر قبض؛ انتخاب برنامه و گیرنده در مقصد'),
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
