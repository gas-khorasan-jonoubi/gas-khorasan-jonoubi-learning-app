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

  /// Extracts only plausible digit-only OCR candidates.
  /// Letters are never stripped and concatenated into an ID, which prevents
  /// Latin OCR hallucinations from becoming apparently valid numeric values.
  static List<String> numericCandidates(
    String rawText, {
    int minDigits = 1,
    int maxDigits = 20,
    int? exactDigits,
  }) {
    final candidates = <String>{};
    for (final rawLine in rawText.split(RegExp(r'[\\r\\n]+'))) {
      final line = normalizeDigits(rawLine).trim();
      if (line.isEmpty) continue;
      final compactDigits = RegExp(r'^[0-9\\s.,،؛:/\\-]+
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

  static bool isValidIranianMobile(String value) {
    final normalized = normalizeDigits(value).trim();
    final international = normalized.startsWith('+98') ||
        normalized.startsWith('0098') ||
        normalized.startsWith('98');
    if (!international && !RegExp(r'^09[0-9]{9}$').hasMatch(normalized)) {
      return false;
    }
    return RegExp(r'^09[0-9]{9}$').hasMatch(normalizeIranianMobile(value));
  }


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

  static String? _amountValue(List<String> lines) {
    // The statement's "بدهی مشترک" column is the outstanding balance,
    // not the total bill amount. Never use it as the message amount.
    const forbidden = ['بدهی مشترک', 'مانده بدهی', 'مبلغ بدهی', 'جمع بدهی'];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (forbidden.any((label) => line.contains(_normalizeText(label)))) {
        continue;
      }
      for (final label in const ['مبلغ کل قبض', 'مبلغ قابل پرداخت', 'مبلغ', 'amount']) {
        final normalizedLabel = _normalizeText(label);
        final position = line.indexOf(normalizedLabel);
        if (position < 0) continue;
        final remainder = line.substring(position + normalizedLabel.length);
        var digits = remainder.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty && index + 1 < lines.length) {
          final nextLine = lines[index + 1];
          if (forbidden.any((item) => nextLine.contains(_normalizeText(item)))) {
            continue;
          }
          digits = nextLine.replaceAll(RegExp(r'[^0-9]'), '');
        }
        if (digits.length >= 3) return digits;
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
      amount: _amountValue(lines),
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
        'نام مشترک: ${value(name)}\n\n'
        'شناسه قبض: ${value(billId)}\n\n'
        'شناسه پرداخت: ${value(paymentId)}\n\n'
        'مبلغ کل قبض: ${formatRial(amount)} ریال\n\n'
        'تعداد دوره بدهی: ${value(periods)}\n\n'
        'با تشکر';
  }
}
).hasMatch(line)
          ? line.replaceAll(RegExp(r'[^0-9]'), '')
          : '';
      final values = compactDigits.isNotEmpty
          ? <String>[compactDigits]
          : RegExp(r'[0-9]+').allMatches(line).map((match) => match.group(0)!).toList();
      for (final value in values) {
        if (exactDigits != null && value.length != exactDigits) continue;
        if (value.length < minDigits || value.length > maxDigits) continue;
        candidates.add(value);
      }
    }
    return candidates.toList(growable: false);
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

  static bool isValidIranianMobile(String value) {
    final normalized = normalizeDigits(value).trim();
    final international = normalized.startsWith('+98') ||
        normalized.startsWith('0098') ||
        normalized.startsWith('98');
    if (!international && !RegExp(r'^09[0-9]{9}$').hasMatch(normalized)) {
      return false;
    }
    return RegExp(r'^09[0-9]{9}$').hasMatch(normalizeIranianMobile(value));
  }


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

  static String? _amountValue(List<String> lines) {
    // The statement's "بدهی مشترک" column is the outstanding balance,
    // not the total bill amount. Never use it as the message amount.
    const forbidden = ['بدهی مشترک', 'مانده بدهی', 'مبلغ بدهی', 'جمع بدهی'];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (forbidden.any((label) => line.contains(_normalizeText(label)))) {
        continue;
      }
      for (final label in const ['مبلغ کل قبض', 'مبلغ قابل پرداخت', 'مبلغ', 'amount']) {
        final normalizedLabel = _normalizeText(label);
        final position = line.indexOf(normalizedLabel);
        if (position < 0) continue;
        final remainder = line.substring(position + normalizedLabel.length);
        var digits = remainder.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty && index + 1 < lines.length) {
          final nextLine = lines[index + 1];
          if (forbidden.any((item) => nextLine.contains(_normalizeText(item)))) {
            continue;
          }
          digits = nextLine.replaceAll(RegExp(r'[^0-9]'), '');
        }
        if (digits.length >= 3) return digits;
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
      amount: _amountValue(lines),
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
        'نام مشترک: ${value(name)}\n\n'
        'شناسه قبض: ${value(billId)}\n\n'
        'شناسه پرداخت: ${value(paymentId)}\n\n'
        'مبلغ کل قبض: ${formatRial(amount)} ریال\n\n'
        'تعداد دوره بدهی: ${value(periods)}\n\n'
        'با تشکر';
  }
}
