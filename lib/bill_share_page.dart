import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _sms = true;
  bool _social = false;
  bool _busy = false;
  String _recognizedText = '';
  String? _imagePath;
  String? _savedImagePath;

  @override
  void dispose() {
    _recognizer.close();
    _name.dispose();
    _billId.dispose();
    _paymentId.dispose();
    _amount.dispose();
    _periods.dispose();
    _mobile.dispose();
    super.dispose();
  }

  String _digits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return value.split('').map((c) {
      final f = fa.indexOf(c);
      if (f >= 0) return '$f';
      final a = ar.indexOf(c);
      if (a >= 0) return '$a';
      return c;
    }).join();
  }

  Future<void> _scan() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _imagePath = photo.path;
    });
    try {
      final result = await _recognizer.processImage(InputImage.fromFilePath(photo.path));
      final text = result.text;
      _recognizedText = text;
      _fillRecognizedFields(text);
      final directory = await getApplicationDocumentsDirectory();
      final billsDir = Directory('${directory.path}/bill_archive');
      if (!await billsDir.exists()) await billsDir.create(recursive: true);
      final saved = await File(photo.path).copy(
        '${billsDir.path}/bill_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      _savedImagePath = saved.path;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر قبض اسکن شد؛ لطفاً اطلاعات تشخیص‌داده‌شده را بررسی کنید.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اسکن انجام نشد. دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillRecognizedFields(String raw) {
    final normalized = _digits(raw);
    final lines = normalized.split(RegExp(r'[\r\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    String? findAfter(List<String> labels) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (labels.any(line.contains)) {
          final sameLine = line.replaceAll(RegExp(r'[^0-9]'), '');
          if (sameLine.length >= 4) return sameLine;
          if (i + 1 < lines.length) {
            final next = lines[i + 1].replaceAll(RegExp(r'[^0-9]'), '');
            if (next.length >= 4) return next;
          }
        }
      }
      return null;
    }

    final phone = RegExp(r'09[0-9]{9}').firstMatch(normalized)?.group(0);
    final bill = findAfter(['شناسه قبض', 'شناسه‌قبض', 'قبض', 'bill id']);
    final payment = findAfter(['شناسه پرداخت', 'شناسه‌پرداخت', 'پرداخت', 'payment id']);
    final amount = findAfter(['مبلغ', 'جمع بدهی', 'بدهی', 'قابل پرداخت', 'amount']);
    final periods = findAfter(['دوره', 'ماه بدهی', 'تعداد دوره']);
    setState(() {
      if (phone != null && _mobile.text.isEmpty) _mobile.text = phone;
      if (bill != null && _billId.text.isEmpty) _billId.text = bill;
      if (payment != null && _paymentId.text.isEmpty) _paymentId.text = payment;
      if (amount != null && _amount.text.isEmpty) _amount.text = amount;
      if (periods != null && _periods.text.isEmpty) _periods.text = periods;
    });
  }

  String _message() {
    String v(TextEditingController c) => c.text.trim().isEmpty ? 'ثبت نشده' : c.text.trim();
    return 'اطلاعات قبض\n'
        'نام مشترک: ${v(_name)}\n'
        'شناسه قبض: ${v(_billId)}\n'
        'شناسه پرداخت: ${v(_paymentId)}\n'
        'مبلغ بدهی: ${v(_amount)}\n'
        'تعداد دوره‌های بدهی: ${v(_periods)}';
  }

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
    if (!_sms && !_social) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک روش اشتراک‌گذاری را انتخاب کنید.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveArchive();
      final text = _message();
      if (_sms) {
        await SharePlus.instance.share(ShareParams(text: text, title: 'اطلاعات قبض - پیامک'));
      }
      if (_social) {
        final path = _savedImagePath ?? _imagePath;
        if (path == null || !await File(path).exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('برای ارسال در شبکه‌های اجتماعی ابتدا تصویر قبض را اسکن کنید.')),
            );
          }
          return;
        }
        await SharePlus.instance.share(ShareParams(
          text: text,
          title: 'تصویر و اطلاعات قبض',
          files: [XFile(path)],
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اشتراک‌گذاری کامل نشد. برنامه مقصد را بررسی کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
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
            _field('نام مشترک', _name),
            _field('شناسه قبض', _billId, keyboard: TextInputType.number),
            _field('شناسه پرداخت', _paymentId, keyboard: TextInputType.number),
            _field('مبلغ بدهی (ریال)', _amount, keyboard: TextInputType.number),
            _field('تعداد دوره‌های بدهی', _periods, keyboard: TextInputType.number),
            _field('شماره موبایل دریافت‌کننده (اختیاری)', _mobile, keyboard: TextInputType.phone),
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
                onChanged: _busy ? null : (v) => setState(() => _sms = v ?? false),
                title: const Text('پیامک'),
                subtitle: const Text('فقط متن اطلاعات قبض'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _social,
                onChanged: _busy ? null : (v) => setState(() => _social = v ?? false),
                title: const Text('شبکه‌های اجتماعی'),
                subtitle: const Text('عکس قبض به همراه متن؛ انتخاب گیرنده در برنامه مقصد'),
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
          'توجه: متن و اعداد تشخیص‌داده‌شده را پیش از ارسال کنترل کنید. تشخیص خودکار فارسی ممکن است کامل نباشد؛ همه کادرها قابل ویرایش‌اند.',
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
                      'مبلغ: ${item['amount'] ?? '-'}\n'
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
