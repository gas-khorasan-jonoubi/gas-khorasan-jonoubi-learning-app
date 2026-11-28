import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Finds horizontal table rules by measuring the longest dark run in each
/// image row. Unlike a whole-row darkness ratio, this tolerates slight page
/// skew and vertical cell borders that interrupt a printed rule.
class BillRowBounds {
  const BillRowBounds({required this.top, required this.bottom});

  final int top;
  final int bottom;

  int get height => bottom - top;
}

class BillRowDetector {
  const BillRowDetector._();

  static List<BillRowBounds> detect(
    Uint8List encodedImage, {
    double minimumHorizontalRunRatio = 0.14,
    int threshold = 160,
    int mergeGap = 4,
    double minimumRowHeightRatio = 0.012,
    double minimumTableTopRatio = 0.03,
  }) {
    final decoded = img.decodeImage(encodedImage);
    if (decoded == null || decoded.width < 80 || decoded.height < 100) {
      return const [];
    }

    final gray = img.grayscale(decoded);
    final minimumRun = (gray.width * minimumHorizontalRunRatio).round();
    final lineRows = <int>[];

    for (var y = 0; y < gray.height; y++) {
      var run = 0;
      var longestRun = 0;
      for (var x = 0; x < gray.width; x++) {
        if (gray.getPixel(x, y).r.toInt() < threshold) {
          run++;
          if (run > longestRun) longestRun = run;
        } else {
          run = 0;
        }
      }
      if (longestRun >= minimumRun) lineRows.add(y);
    }

    if (lineRows.length < 2) return const [];
    final lines = <({int top, int bottom})>[];
    var start = lineRows.first;
    var previous = start;
    for (final y in lineRows.skip(1)) {
      if (y - previous > mergeGap + 1) {
        lines.add((top: start, bottom: previous + 1));
        start = y;
      }
      previous = y;
    }
    lines.add((top: start, bottom: previous + 1));

    final minHeight = (gray.height * minimumRowHeightRatio).round();
    final rows = <BillRowBounds>[];
    for (var i = 0; i < lines.length - 1; i++) {
      final top = lines[i].bottom;
      final bottom = lines[i + 1].top;
      if (bottom - top >= minHeight && top >= (gray.height * minimumTableTopRatio).round()) {
        rows.add(BillRowBounds(top: top, bottom: bottom));
      }
    }
    return rows;
  }
}
