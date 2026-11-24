import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

import 'golden_test.dart' show loadFonts;

/// Delivery stills for the per-step style feature (0.7.0). Runs only when
/// explicitly requested:
///
///   CAPTURE_STYLE=1 flutter test test/style_capture_test.dart
///
/// Frames land in test/capture_style/step_*.png. Rendered by the Flutter
/// test engine (not a device recording): the tour overlay, painters and
/// card are the package's real code, only the frame pacing is fixed.
void main() {
  setUpAll(loadFonts);

  testWidgets('capture per-step style stills', (tester) async {
    if (Platform.environment['CAPTURE_STYLE'] != '1') return;
    final outDir = Directory('test/capture_style')..createSync(recursive: true);
    for (final f in outDir.listSync()) {
      f.deleteSync();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captureKey = GlobalKey();
    final verseKey = GlobalKey();
    final barKey = GlobalKey();
    final tour = SpotlightTourController(steps: [
      TourStep(
        targetKey: verseKey,
        title: 'خطوة بثيم الجولة',
        description: 'هذه الخطوة بلا style فتبقى على الثيم الذهبي للجولة كما هو.',
        icon: Icons.menu_book_outlined,
      ),
      TourStep(
        targetKey: barKey,
        title: 'خطوة بستايلها الخاص',
        description:
            'accentColor وcardColor ونمط العنوان وسماكة الإطار من TourStepStyle — لهذه الخطوة فقط.',
        icon: Icons.palette_outlined,
        style: const TourStepStyle(
          accentColor: Colors.teal,
          onAccentColor: Color(0xFF03211E),
          cardColor: Color(0xFF0E2A28),
          titleStyle: TextStyle(color: Color(0xFF7FDBD3)),
          borderWidth: 3,
          glowSigma: 18,
        ),
      ),
    ]);

    await tester.pumpWidget(RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF100E0C),
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SpotlightTour(
            controller: tour,
            child: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا',
                      key: verseKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Amiri', fontSize: 22, height: 2.0),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    key: barKey,
                    height: 56,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1A16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white70),
                        Icon(Icons.bookmark_border, color: Colors.white70),
                        Icon(Icons.share_outlined, color: Colors.white70),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    var frame = 0;
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final ro = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        frame++;
        File('${outDir.path}/step_${frame}_$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        img.dispose();
      });
    }

    tour.start();
    await tester.pump();
    // Scrim fade + card entrance + bounded pulse settle.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 6));
    await capture('theme_default');

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 6));
    await capture('step_style');

    // Brief video: default-theme step -> styled step -> back to default.
    final videoDir = Directory('test/capture_style/video')
      ..createSync(recursive: true);
    for (final f in videoDir.listSync()) {
      f.deleteSync();
    }
    var vframe = 0;
    Future<void> vcapture() async {
      await tester.runAsync(() async {
        final ro = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1.0);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        vframe++;
        File('${videoDir.path}/frame_${vframe.toString().padLeft(4, '0')}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> pumpFor(Duration total) async {
      const step = Duration(milliseconds: 50);
      var elapsed = Duration.zero;
      while (elapsed < total) {
        await tester.pump(step);
        elapsed += step;
        await vcapture();
      }
    }

    // Currently on the styled step (pulse already rested); go back to the
    // default-theme step first so the video starts on it.
    await tester.tap(find.text('السابق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 6));
    await pumpFor(const Duration(milliseconds: 1000)); // hold on default
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 2200)); // morph into styled
    await tester.tap(find.text('السابق'));
    await pumpFor(const Duration(milliseconds: 2200)); // morph back
  });
}
