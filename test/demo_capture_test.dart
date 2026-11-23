import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

import 'central_demo.dart';
import 'golden_test.dart' show DemoKeys, GoldenDemoScreen, loadFonts;

/// Frame capture for the demo video and delivery stills.
///
/// Runs only when explicitly requested:
///
///   CAPTURE_DEMO=1 flutter test test/demo_capture_test.dart
///
/// Frames land in test/capture/frame_0001.png ... Assemble with:
///
///   ffmpeg -framerate 20 -i test/capture/frame_%04d.png \
///     -vf format=yuv420p -c:v libx264 -crf 22 tour-demo.mp4
///
/// The frames are rendered by the Flutter test engine (not a device
/// recording): every animation is real package code, but frame pacing is
/// fixed at 50 ms, so the video demonstrates behaviour, not smoothness.
void main() {
  setUpAll(loadFonts);

  testWidgets('capture demo frames', (tester) async {
    if (Platform.environment['CAPTURE_DEMO'] != '1') return;
    final outDir = Directory('test/capture')..createSync(recursive: true);
    for (final f in outDir.listSync()) {
      f.deleteSync();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captureKey = GlobalKey();
    final keys = DemoKeys();
    final pageController = PageController();
    addTearDown(pageController.dispose);
    final tour = SpotlightTourController();
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
          child: GoldenDemoScreen(
              keys: keys, tour: tour, pageController: pageController),
        ),
      ),
    ));
    await tester.pump();

    var frame = 0;
    Future<void> capture() async {
      // toImage needs the engine to produce a real frame; inside the
      // automated test binding that requires runAsync, otherwise the
      // second capture waits forever for a vsync that never comes.
      await tester.runAsync(() async {
        final ro = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        frame++;
        File('${outDir.path}/frame_${frame.toString().padLeft(4, '0')}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> pumpFor(Duration total) async {
      const step = Duration(milliseconds: 50);
      var elapsed = Duration.zero;
      while (elapsed < total) {
        // A pump before every capture: taps above mark the tree dirty, and
        // toImage asserts on an unpainted boundary.
        await tester.pump(step);
        elapsed += step;
        await capture();
      }
    }

    tour.start();
    await pumpFor(const Duration(milliseconds: 1300)); // intro card

    // The swipe-teaching step: the package turns the real page fully
    // rightward and turns it back to the user's exact spot.
    await tester.tap(find.text('ابدأ الجولة'));
    await pumpFor(const Duration(milliseconds: 3300));

    // Verse contour on the current page.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1900));

    // Next opens the real verse-options sheet; the tour highlights تفسير.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1700));

    // Next closes the sheet, tour continues on the page.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1300));

    // Previous REOPENS the sheet — the fixed regression.
    await tester.tap(find.text('السابق'));
    await pumpFor(const Duration(milliseconds: 1900));

    // Forward again, then skip: the sheet closes, nothing is left behind.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1300));
    await tester.tap(find.text('تخطي الجولة'));
    await pumpFor(const Duration(milliseconds: 800));

    expect(frame, greaterThan(120));
  });

  testWidgets('capture central demo frames', (tester) async {
    if (Platform.environment['CAPTURE_DEMO'] != '1') return;
    final outDir = Directory('test/capture_central')..createSync(recursive: true);
    for (final f in outDir.listSync()) {
      f.deleteSync();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captureKey = GlobalKey();
    final keys = CentralKeys();
    final tour = SpotlightTourController();
    await tester.pumpWidget(RepaintBoundary(
      key: captureKey,
      child: CentralDemoApp(keys: keys, tour: tour),
    ));
    await tester.pump();

    var frame = 0;
    Future<void> capture() async {
      await tester.runAsync(() async {
        final ro = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        frame++;
        File('${outDir.path}/frame_${frame.toString().padLeft(4, '0')}.png')
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
        await capture();
      }
    }

    tour.start(
        steps: centralSteps(keys, CentralMushafPage(keys: keys)));
    await pumpFor(const Duration(milliseconds: 1500)); // intro card

    // Verse contour on the mushaf page.
    await tester.tap(find.text('ابدأ الجولة'));
    await pumpFor(const Duration(milliseconds: 2100));

    // Bottom-bar step: announces the cross-page jump.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1700));

    // Next: the tour itself pushes the settings route and highlights there.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 2400));

    // Theme row on the settings page.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 1900));

    // Next closes the settings page, closing card ends the tour.
    await tester.tap(find.text('التالي'));
    await pumpFor(const Duration(milliseconds: 2100));

    await tester.tap(find.text('تم'));
    await pumpFor(const Duration(milliseconds: 900));

    expect(frame, greaterThan(150));
  });
}
