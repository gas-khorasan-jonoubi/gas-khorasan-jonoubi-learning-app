import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/main.dart';

void main() {
  // Keep the splash widget test compatible with the current Flutter test view API.
  testWidgets('splash shows the approved artwork full screen without extra labels', (tester) async {
    tester.view.physicalSize = const Size(432, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(hours: 1),
          prepareSplash: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/approved_splash.png',
    );
    expect(imageFinder, findsOneWidget);
    final image = tester.widget<Image>(imageFinder);
    expect(image.fit, BoxFit.cover);
    expect(find.textContaining('شرکت'), findsNothing);
    expect(find.textContaining('اداره'), findsNothing);
    expect(find.textContaining('شهرستان'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash remains visible for three seconds then opens the app start gate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(seconds: 3),
          accessCheck: () async => true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('داشبورد'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(AppStartGate), findsOneWidget);
  });

  testWidgets('splash timer is cancelled safely when the page is disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          displayDuration: const Duration(hours: 1),
          prepareSplash: (_) async {},
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
