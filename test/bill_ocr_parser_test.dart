import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/bill_ocr_parser.dart';

void main() {
  group('BillOcrParser', () {
    test('normalizes Persian and Arabic digits', () {
      expect(BillOcrParser.normalizeDigits('۱۲۳٤۵۶'), '123456');
    });

    test('normalizes Iranian mobile numbers from international formats', () {
      expect(BillOcrParser.normalizeIranianMobile('+989123456789'), '09123456789');
      expect(BillOcrParser.normalizeIranianMobile('00989123456789'), '09123456789');
      expect(BillOcrParser.normalizeIranianMobile('98 912-345-6789'), '09123456789');
      expect(BillOcrParser.normalizeIranianMobile('۰۹۱۲۳۴۵۶۷۸۹'), '09123456789');
      expect(BillOcrParser.normalizeIranianMobile('09123456789'), '09123456789');
      expect(BillOcrParser.isValidIranianMobile('+98 (912) 345-6789'), isTrue);
      expect(BillOcrParser.isValidIranianMobile('00989123456789'), isTrue);
    });

    test('accepts only Iranian mobile numbers with exactly 11 digits', () {
      expect(BillOcrParser.isValidIranianMobile('09123456789'), isTrue);
      expect(BillOcrParser.isValidIranianMobile('۰۹۱۲۳۴۵۶۷۸۹'), isTrue);
      expect(BillOcrParser.isValidIranianMobile('٠٩١٢٣٤٥٦٧٨٩'), isTrue);
      expect(BillOcrParser.isValidIranianMobile('0912345678'), isFalse);
      expect(BillOcrParser.isValidIranianMobile('091234567890'), isFalse);
      expect(BillOcrParser.isValidIranianMobile('08123456789'), isFalse);
      expect(BillOcrParser.isValidIranianMobile('09 123 456 789'), isFalse);
    });

    test('extracts Persian bill fields from multi-line OCR text', () {
      const sample = '''
نام و نام خانوادگی: علی محمدی
شناسه قبض: ۱۲۳۴۵۶۷۸۹۰
شناسه پرداخت: ۹۸۷۶۵۴۳۲۱۰
مبلغ قابل پرداخت: ۲۸۷۵۰۰۰
تعداد دوره بدهی: ۲
شماره همراه: ۰۹۱۲۳۴۵۶۷۸۹
''';
      final result = BillOcrParser.parse(sample);
      expect(result.name, 'علی محمدی');
      expect(result.billId, '1234567890');
      expect(result.paymentId, '9876543210');
      expect(result.amount, '2875000');
      expect(result.periods, '2');
      expect(result.mobile, '09123456789');
    });

    test('reads values placed on the line after their labels', () {
      const sample = '''
نام مشترک
رضا رضایی
شناسه قبض
۱۲۳۴۵۶۷۸۹
شناسه پرداخت
۹۸۷۶۵۴۳۲۱
مبلغ قابل پرداخت
۴۵۶۷۸۹
''';
      final result = BillOcrParser.parse(sample);
      expect(result.name, 'رضا رضایی');
      expect(result.billId, '123456789');
      expect(result.paymentId, '987654321');
      expect(result.amount, '456789');
    });

    test('formats amount as rial without converting to toman', () {
      expect(BillOcrParser.formatRial('۲۸۷۵۰۰۰'), '2.875.000');
      final message = BillOcrParser.buildMessage(
        name: 'علی محمدی',
        billId: '123',
        paymentId: '456',
        amount: '2875000',
        periods: '2',
      );
      expect(message, contains('مبلغ قابل پرداخت: 2.875.000 ریال'));
      expect(message, contains('نام مشترک: علی محمدی\n\nشناسه قبض: 123'));
      expect(message, contains('شناسه قبض: 123\n\nشناسه پرداخت: 456'));
      expect(message, contains('شناسه پرداخت: 456\n\nمبلغ قابل پرداخت: 2.875.000 ریال'));
      expect(message, contains('مبلغ قابل پرداخت: 2.875.000 ریال\n\nتعداد دوره بدهی: 2'));
      expect(message, isNot(contains('تومان')));
    });
  });
}
