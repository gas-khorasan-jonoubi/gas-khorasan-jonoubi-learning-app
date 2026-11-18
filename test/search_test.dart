import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  group('offline search', () {
    test('normalizes Arabic Yeh and Kaf to Persian forms', () {
      expect(normalizeSearchText('ي ك'), 'ی ک');
    });

    test('global search finds the امداد و گازبان topic', () {
      final results = searchEntries(allSearchEntries, 'امداد');
      expect(results, isNotEmpty);
      expect(results.any((entry) => entry.title == 'امداد و گازبان'), isTrue);
    });

    test('section search does not return results from another section', () {
      final examEntries = allSearchEntries.where((entry) => entry.section == 'exam').toList();
      expect(searchEntries(examEntries, 'امداد'), isEmpty);
      expect(searchEntries(examEntries, 'ایمنی'), isNotEmpty);
    });

    test('matches a partial word in the content as well as the title', () {
      final results = searchEntries(allSearchEntries, 'خطرها');
      expect(results.any((entry) => entry.title == 'اصول ایمنی و بهداشت'), isTrue);
    });

    test('empty query returns no search results', () {
      expect(searchEntries(allSearchEntries, '   '), isEmpty);
    });
  });
}
