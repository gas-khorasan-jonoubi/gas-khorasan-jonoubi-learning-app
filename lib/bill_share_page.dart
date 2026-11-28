import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'bill_row_detector.dart';

import 'bill_ocr_parser.dart';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
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
  static const MethodChannel _contactPicker = MethodChannel('danestani_gaz/contact_picker');
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

  String _normalizeIranianMobile(String raw) =>
      BillOcrParser.normalizeIranianMobile(raw);

  Future<void> _pickContactMobile() async {
    if (_busy) return;
    try {
      final selected = await _contactPicker.invokeMethod<String>('pickPhone');
      if (!mounted || selected == null || selected.trim().isEmpty) return;

      final mobile = _normalizeIranianMobile(selected);
      if (!BillOcrParser.isValidIranianMobile(mobile)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('شماره انتخاب‌شده معتبر نیست؛ مخاطبی با شماره موبایل ۱۱ رقمی ایران انتخاب کنید.'),
            ),
          );
        return;
      }

      setState(() {
        _mobile.text = mobile;
        _mobile.selection = TextSelection.collapsed(offset: mobile.length);
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == 'NO_CONTACT_PICKER'
          ? 'برنامه مخاطبین در این گوشی در دسترس نیست.'
          : 'دریافت شماره مخاطب انجام نشد؛ دوباره تلاش کنید.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('باز کردن فهرست مخاطبین ممکن نشد.')),
        );
    }
  }

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
    final phone = _normalizeIranianMobile(_mobile.text);
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


  Future<void> _scanBillRowWithOcr() async {
    if (_busy) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null || !mounted) return;
      final bytes = await File(photo.path).readAsBytes();
      final rows = BillRowDetector.detect(bytes);
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطوط جدول به‌وضوح تشخیص داده نشد؛ عکس را صاف، کامل و با نور مناسب بگیرید یا از اسکن تکی فیلدها استفاده کنید.')),
        );
        return;
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final selectedIndex = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('انتخاب ردیف قبض (\${rows.length} ردیف تشخیص داده شد)'),
          content: SizedBox(
            width: 380,
            height: 420,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                final crop = img.copyCrop(
                  decoded,
                  x: 0,
                  y: row.top,
                  width: decoded.width,
                  height: row.height,
                );
                final preview = Uint8List.fromList(img.encodeJpg(crop, quality: 75));
                return ListTile(
                  leading: SizedBox(width: 100, height: 52, child: Image.memory(preview, fit: BoxFit.contain)),
                  title: Text('ردیف \${index + 1}'),
                  subtitle: const Text('برای خواندن این ردیف لمس کنید'),
                  onTap: () => Navigator.of(dialogContext).pop(index),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('انصراف')),
          ],
        ),
      );
      if (selectedIndex == null || !mounted) return;
      final selectedRow = rows[selectedIndex];
      final rowImage = img.copyCrop(
        decoded,
        x: 0,
        y: selectedRow.top,
        width: decoded.width,
        height: selectedRow.height,
      );
      final directory = await getTemporaryDirectory();
      final rowFile = File('\${directory.path}/bill_row_\${DateTime.now().microsecondsSinceEpoch}.jpg');
      await rowFile.writeAsBytes(img.encodeJpg(rowImage, quality: 94), flush: true);
      setState(() => _busy = true);
      final recognized = await TesseractOcr.extractText(
        rowFile.path,
        config: OCRConfig(
          language: 'fas',
          engine: OCREngine.tesseract,
          options: const {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '7',
          },
        ),
      );
      if (!mounted) return;
      final tokens = recognized
          .split(RegExp(r'[\s|،؛]+'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('متن ردیف \${selectedIndex + 1}'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('فقط همین ردیف جدا شده است. برای جلوگیری از جابه‌جایی مبلغ، شناسه‌ها و ستون بدهی مشترک، مقادیر را با اسکن تکی هر فیلد تأیید کنید.'),
                  const SizedBox(height: 10),
                  const Text('متن OCR:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  SelectableText(recognized.trim().isEmpty ? 'متنی تشخیص داده نشد.' : recognized.trim()),
                  const SizedBox(height: 10),
                  const Text('قطعه‌های تشخیص‌داده‌شده:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  SelectableText(tokens.join('  |  ')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('بستن و بررسی فیلدها')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسکن برگه انجام نشد؛ لطفاً عکس واضح‌تر و بدون زاویه شدید بگیرید.')),
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _scanFieldWithOcr(
    String label,
    TextEditingController controller, {
    bool numericOnly = false,
    bool mobile = false,
    bool rialAmount = false,
    bool periods = false,
  }) async {
    if (_busy) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.path,
        maxWidth: 2400,
        maxHeight: 1200,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'برش محدوده $label',
            toolbarColor: _billNavy,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      setState(() => _busy = true);
      final recognized = await TesseractOcr.extractText(
        cropped.path,
        config: OCRConfig(
          language: 'fas',
          engine: OCREngine.tesseract,
          options: const {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '7',
          },
        ),
      );
      if (!mounted) return;
      final lines = recognized
          .split(RegExp(r'[\r\n]+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final editor = TextEditingController(text: lines.length == 1 ? lines.first : '');
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('انتخاب مقدار $label'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('روی یکی از متن‌های تشخیص‌داده‌شده بزنید یا مقدار صحیح را دستی اصلاح کنید.'),
                  const SizedBox(height: 10),
                  if (lines.isEmpty)
                    const Text('متنی تشخیص داده نشد؛ مقدار را دستی وارد کنید.')
                  else
                    ...lines.map((line) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line, textDirection: TextDirection.rtl),
                      onTap: () => editor.text = line,
                    )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: editor,
                    autofocus: lines.isEmpty,
                    maxLines: 2,
                    textDirection: numericOnly || mobile || periods || rialAmount
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'مقدار نهایی $label',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(editor.text.trim()),
              child: const Text('ثبت در فیلد'),
            ),
          ],
        ),
      );
      editor.dispose();
      if (selected == null || !mounted) return;
      var value = BillOcrParser.normalizeDigits(selected).trim();
      if (mobile) {
        value = _normalizeIranianMobile(value);
        if (!BillOcrParser.isValidIranianMobile(value)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شماره انتخاب‌شده معتبر نیست؛ شماره باید ۱۱ رقم و با ۰۹ باشد.')),
          );
          return;
        }
      } else if (numericOnly || periods || rialAmount) {
        value = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (periods && value.length > 3) value = value.substring(0, 3);
        if (rialAmount) value = BillOcrParser.formatRial(value);
      }
      controller.text = value;
      controller.selection = TextSelection.collapsed(offset: value.length);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اسکن $label انجام نشد؛ محدوده را واضح‌تر و با نور کافی ثبت کنید.')),
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _scanQrInto(TextEditingController controller) async {
    if (_busy) return;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسکن ردیف قبض'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'دوربین را روی ردیف موردنظر نگه دارید؛ کادر افقی برای اسکن همان ردیف تنظیم شده است.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 88,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      if (capture.barcodes.isEmpty) return;
                      final raw = capture.barcodes.first.rawValue?.trim();
                      if (raw == null || raw.isEmpty) return;
                      Navigator.of(dialogContext).pop(raw);
                    },
                  ),
                ),
              ),
            ],
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
      final numericField = controller == _billId ||
          controller == _paymentId ||
          controller == _periods ||
          controller == _mobile;
      var accepted = numericField
          ? _digits(value).replaceAll(RegExp(r'[^0-9]'), '')
          : value;
      if (controller == _periods && accepted.length > 3) {
        accepted = accepted.substring(0, 3);
      }
      if (controller == _mobile) {
        accepted = _normalizeIranianMobile(accepted);
        if (accepted.length > 11) accepted = accepted.substring(0, 11);
      }
      controller.text = accepted;
      controller.selection = TextSelection.collapsed(offset: accepted.length);
    }
  }

  void _showSpeechFailure({String? errorCode}) {
    if (!mounted) return;
    final code = (errorCode ?? '').toLowerCase();

    if (code == 'error_no_match' || code == 'error_speech_timeout') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('صدا تشخیص داده نشد؛ لطفاً دوباره و واضح‌تر صحبت کنید.'),
          ),
        );
      return;
    }

    if (code == 'error_permission' || code == 'error_audio_error') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('مجوز میکروفون یا دسترسی ضبط صدا را در تنظیمات گوشی بررسی کنید.'),
          ),
        );
      return;
    }

    const networkErrors = <String>{
      'error_network',
      'error_network_timeout',
      'error_server',
      'error_server_disconnected',
      'error_language_unavailable',
      'error_language_not_supported',
    };
    final isNetworkProblem = networkErrors.contains(code) ||
        code.contains('network') ||
        code.contains('server');

    final message = isNetworkProblem
        ? 'تشخیص گفتار آفلاین در دسترس نیست؛ لطفاً اینترنت خود را متصل کنید و دوباره تلاش کنید.'
        : 'ورود صوتی در دسترس نیست؛ لطفاً اینترنت خود را متصل کنید و فعال بودن سرویس گفتار فارسی و مجوز میکروفون را بررسی کنید.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        onError: (error) {
          _showSpeechFailure(errorCode: error.errorMsg);
        },
      );
      if (!_speechReady) {
        _showSpeechFailure();
        return;
      }
      await _speech.listen(
        localeId: 'fa_IR',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted || result.recognizedWords.trim().isEmpty) return;
          final spoken = result.recognizedWords.trim();
          final isNumericField = controller == _billId || controller == _paymentId || controller == _periods || controller == _mobile;
          controller.text = controller == _mobile
              ? _normalizeIranianMobile(_spokenDigits(spoken))
              : isNumericField ? _spokenDigits(spoken) : spoken;
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
          setState(() {});
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _showSpeechFailure();
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    bool mobile = false,
    bool periods = false,
    bool numericOnly = false,
    bool rialAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: mobile || periods || numericOnly
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                if (mobile) LengthLimitingTextInputFormatter(11),
                if (periods) LengthLimitingTextInputFormatter(3),
              ]
            : rialAmount
                ? [_ThousandsSeparatorInputFormatter()]
                : null,
        validator: mobile
            ? (value) {
                final normalized = _normalizeIranianMobile(value ?? '');
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
        textDirection: mobile || periods || numericOnly ? TextDirection.ltr : TextDirection.rtl,
        textAlign: mobile || periods || numericOnly ? TextAlign.right : TextAlign.start,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'اسکن تصویری همین فیلد: $label',
                onPressed: _busy ? null : () => _scanFieldWithOcr(
                  label,
                  controller,
                  numericOnly: numericOnly,
                  mobile: mobile,
                  rialAmount: rialAmount,
                  periods: periods,
                ),
                icon: const Icon(Icons.document_scanner_outlined),
              ),
              IconButton(
                tooltip: 'اسکن QR یا بارکد برای $label',
                onPressed: _busy ? null : () => _scanQrInto(controller),
                icon: const Icon(Icons.qr_code_scanner),
              ),
              IconButton(
                tooltip: 'ورود صوتی برای $label',
                onPressed: _busy ? null : () => _listenInto(controller),
                icon: Icon(_speech.isListening ? Icons.mic_off : Icons.mic),
              ),
              if (mobile)
                IconButton(
                  tooltip: 'انتخاب شماره از مخاطبین گوشی',
                  onPressed: _busy ? null : _pickContactMobile,
                  icon: const Icon(Icons.contacts_outlined),
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
              'برای اسکن تصویری هر فیلد، آیکن برگه را بزنید؛ برای QR از آیکن QR و برای ورود صوتی از میکروفون استفاده کنید. اطلاعات را پیش از ارسال بررسی و اصلاح کنید.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scanBillRowWithOcr,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('اسکن برگه و انتخاب ردیف موردنظر'),
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(children: [
            _field('نام مشترک', _name, required: true),
            _field('شناسه قبض', _billId, keyboard: TextInputType.number, required: true, numericOnly: true),
            _field('شناسه پرداخت', _paymentId, keyboard: TextInputType.number, required: true, numericOnly: true),
            _field('مبلغ کل قبض (ریال) — جداکنندهٔ سه‌رقمی', _amount, keyboard: TextInputType.number, required: true, rialAmount: true),
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
                      'مبلغ کل قبض: ${item['amount'] ?? '-'} ریال\n'
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
