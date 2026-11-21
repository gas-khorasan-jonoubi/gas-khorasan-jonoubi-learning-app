import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('the optimized approved WebP poster is included in the offline bundle', (tester) async {
    final poster = await rootBundle.load('assets/approved_splash.webp');
    expect(poster.lengthInBytes, greaterThan(0));
  });


  testWidgets('splash remains visible for three seconds after poster is ready', (tester) async {
    var posterPrepared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(seconds: 3),
          preparePoster: (_) async {
            posterPrepared = true;
          },
        ),
      ),
    );
    await tester.pump();
    expect(posterPrepared, isTrue);

    final posterFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/approved_splash.webp',
    );
    expect(posterFinder, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2999));
    expect(posterFinder, findsOneWidget);
    expect(find.text('داشبورد'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
  });

  testWidgets('splash displays the approved poster without cropping and cancels its timer on dispose', (tester) async {
    var posterPrepared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(hours: 1),
          preparePoster: (_) async {
            posterPrepared = true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(posterPrepared, isTrue);
    final posterFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/approved_splash.webp',
    );
    expect(posterFinder, findsOneWidget);

    final poster = tester.widget<Image>(posterFinder);
    expect(poster.fit, BoxFit.contain);
    expect(poster.filterQuality, FilterQuality.high);

    // Removing the splash early must cancel its pending timer.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
