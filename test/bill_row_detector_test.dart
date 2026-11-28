import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:gas_khorasan_jonoubi_learning_app/bill_row_detector.dart';

void main() {
  group('BillRowDetector', () {
    test('detects row intervals between horizontal table rules', () {
      final image = img.Image(width: 240, height: 180);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      for (final y in [10, 50, 90, 130, 170]) {
        img.drawLine(
          image,
          x1: 5,
          y1: y,
          x2: 234,
          y2: y,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 2,
        );
      }
      final rows = BillRowDetector.detect(
        Uint8List.fromList(img.encodePng(image)),
        minimumHorizontalRunRatio: 0.7,
        minimumRowHeightRatio: 0.1,
      );
      expect(rows, hasLength(4));
      expect(rows.first.top, greaterThanOrEqualTo(10));
      expect(rows.first.bottom, lessThanOrEqualTo(50));
    });

    test('tolerates small gaps in printed horizontal rules', () {
      final image = img.Image(width: 300, height: 180);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      for (final y in [10, 50, 90, 130, 170]) {
        img.drawLine(
          image,
          x1: 5,
          y1: y,
          x2: 115,
          y2: y,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 2,
        );
        img.drawLine(
          image,
          x1: 125,
          y1: y,
          x2: 294,
          y2: y,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 2,
        );
      }
      final rows = BillRowDetector.detect(
        Uint8List.fromList(img.encodePng(image)),
        minimumHorizontalRunRatio: 0.45,
        minimumRowHeightRatio: 0.1,
      );
      expect(rows, hasLength(4));
    });

    test('ignores a short stray line above the table', () {
      final image = img.Image(width: 300, height: 180);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawLine(
        image,
        x1: 4,
        y1: 2,
        x2: 150,
        y2: 2,
        color: img.ColorRgb8(0, 0, 0),
        thickness: 2,
      );
      for (final y in [30, 70, 110, 150]) {
        img.drawLine(
          image,
          x1: 5,
          y1: y,
          x2: 294,
          y2: y,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 2,
        );
      }
      final rows = BillRowDetector.detect(
        Uint8List.fromList(img.encodePng(image)),
        minimumHorizontalRunRatio: 0.4,
        minimumRowHeightRatio: 0.1,
      );
      expect(rows, hasLength(3));
      expect(rows.first.top, greaterThanOrEqualTo(30));
    });

    test('returns no rows for an image without table rules', () {
      final image = img.Image(width: 160, height: 160);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      expect(
        BillRowDetector.detect(Uint8List.fromList(img.encodePng(image))),
        isEmpty,
      );
    });
  });
}
