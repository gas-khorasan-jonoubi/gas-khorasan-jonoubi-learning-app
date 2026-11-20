import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {

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

  testWidgets('splash displays the approved offline poster without cropping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage()),
    );

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
  });
}
