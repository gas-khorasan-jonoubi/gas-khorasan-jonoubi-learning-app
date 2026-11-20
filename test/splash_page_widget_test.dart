import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  testWidgets('splash displays the approved offline poster without cropping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage()),
    );

    final posterFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/approved_splash.png',
    );

    expect(posterFinder, findsOneWidget);

    final poster = tester.widget<Image>(posterFinder);
    expect(poster.fit, BoxFit.contain);
    expect(poster.filterQuality, FilterQuality.high);
  });
}
