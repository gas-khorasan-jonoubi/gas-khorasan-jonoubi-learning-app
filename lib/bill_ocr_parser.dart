class ParsedGasBill {
  const ParsedGasBill({
    this.name,
    this.billId,
    this.paymentId,
    this.amount,
    this.periods,
    this.mobile,
  });

  final String? name;
  final String? billId;
  final String? paymentId;
  final String? amount;
  final String? periods;
  final String? mobile;
}

class BillOcrParser {
  const BillOcrParser._();

  static String normalizeDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return value.split('').map((character) {
      final persian = fa.indexOf(character);
      if (persian >= 0) return '$persian';
      final arabic = ar.indexOf(character);
      if (arabic >= 0) return '$arabic';
      return character;
    }).join();
  }

  static String normalizeIranianMobile(String value) {
    var digits = normalizeDigits(value).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0098')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('98')) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('9')) {
      digits = '0$digits';
    }
    return digits;
  }

  static bool isValidIranianMobile(String value) =>
      RegExp(r'^09[0-9]{9}$').hasMatch(normalizeIranianMobile(value));

  static String _normalizeText(String value) => normalizeDigits(value)
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> _lines(String value) => value
      .split(RegExp(r'[\r\n]+'))
      .map(_normalizeText)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  static String? _textValue(List<String> lines, List<String> labels) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      for (final label in labels) {
        final normalizedLabel = _normalizeText(label);
        final position = line.indexOf(normalizedLabel);
        if (position < 0) continue;
        var value = line.substring(position + normalizedLabel.length);
        value = value.replaceFirst(RegExp(r'^[\s:：؛،.\-]+'), '').trim();
        if (value.isEmpty && index + 1 < lines.length) {
          value = lines[index + 1].trim();
        }
        if (value.isNotEmpty && !RegExp(r'\d{4,}').hasMatch(value)) {
          return value.replaceAll(RegExp(r'[|؛;]+$'), '').trim();
        }
      }
    }
    return null;
  }

  static String? _numericValue(
    List<String> lines,
    List<String> labels, {
    int minDigits = 3,
  }) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      for (final label in labels) {
        final normalizedLabel = _normalizeText(label);
        final position = line.indexOf(normalizedLabel);
        if (position < 0) continue;
        var remainder = line.substring(position + normalizedLabel.length);
        var digits = remainder.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty && index + 1 < lines.length) {
          remainder = lines[index + 1];
          digits = remainder.replaceAll(RegExp(r'[^0-9]'), '');
        }
        if (digits.length >= minDigits) return digits;
      }
    }
    return null;
  }

  static ParsedGasBill parse(String rawText) {
    final lines = _lines(rawText);
    final normalizedAll = lines.join(' ');
    final mobile = RegExp(r'09[0-9]{9}').firstMatch(normalizedAll)?.group(0);
    return ParsedGasBill(
      name: _textValue(lines, const [
        'نام و نام خانوادگی',
        'نام مشترک',
        'نام خانوادگی',
      ]),
      billId: _numericValue(lines, const [
        'شناسه قبض',
        'شناسه‌قبض',
        'bill id',
      ]),
      paymentId: _numericValue(lines, const [
        'شناسه پرداخت',
        'شناسه‌پرداخت',
        'payment id',
      ]),
      amount: _numericValue(lines, const [
        'مبلغ قابل پرداخت',
        'مبلغ بدهی',
        'جمع بدهی',
        'مبلغ',
        'amount',
      ]),
      periods: _numericValue(lines, const [
        'تعداد دوره بدهی',
        'تعداد دوره',
        'دوره بدهی',
        'ماه بدهی',
      ], minDigits: 1),
      mobile: mobile,
    );
  }

  static String formatRial(String raw) {
    final digits = normalizeDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return raw.trim();
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
  }

  static String buildMessage({
    required String name,
    required String billId,
    required String paymentId,
    required String amount,
    required String periods,
  }) {
    String value(String input) =>
        input.trim().isEmpty ? 'ثبت نشده' : input.trim();
    return 'سلام\n\n'
        'لطفاً نسبت به پرداخت قبض زیر اقدام فرمایید:\n\n'
        'نوع قبض: گاز\n\n'
        'نام مشترک: \${value(name)}\n\n'
        'شناسه قبض: \${value(billId)}\n\n'
        'شناسه پرداخت: \${value(paymentId)}\n\n'
        'مبلغ قابل پرداخت: \${formatRial(amount)} ریال\n\n'
        'تعداد دوره بدهی: \${value(periods)}\n\n'
        'با تشکر';
  }
}
