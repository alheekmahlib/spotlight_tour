import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

/// App with the CENTRAL setup: one controller, one [SpotlightTourHost] in
/// [MaterialApp.builder], and plain routes below that never wrap themselves.
Widget centralApp(
  SpotlightTourController controller, {
  required Widget home,
  GlobalKey<NavigatorState>? navKey,
}) {
  return MaterialApp(
    navigatorKey: navKey,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: SpotlightTourHost(controller: controller, child: child!),
    ),
    home: home,
  );
}

Widget page(String title, GlobalKey targetKey, Color color) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Column(
      children: [
        Container(key: targetKey, height: 60, color: color),
        const Spacer(),
      ],
    ),
  );
}

SpotlightPainter spotlightPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<SpotlightPainter>()
      .first;
}

Offset centerOf(GlobalKey key) {
  final box = key.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void expectSpotlightOn(WidgetTester tester, GlobalKey key) {
  final painter = spotlightPainter(tester);
  expect(painter.targetPath, isNotNull);
  expect(painter.targetPath!.contains(centerOf(key)), isTrue);
}

/// Advances fake time in small frames: transitions are multi-frame pipelines
/// (card exit → step hooks → target polling → morph), and a single large
/// pump renders only the final frame, skipping intermediate state the tests
/// assert on.
Future<void> pumpFor(WidgetTester tester, Duration total,
    [Duration step = const Duration(milliseconds: 100)]) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  testWidgets('no tour UI and no cost before the first start', (tester) async {
    final controller = SpotlightTourController();
    final keyA = GlobalKey();
    await tester.pumpWidget(centralApp(controller, home: page('أ', keyA, Colors.blue)));

    expect(find.byType(SpotlightPainter), findsNothing);
    expect(controller.status, TourStatus.idle);
  });

  testWidgets('start from a pushed full-screen route highlights its target',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controller = SpotlightTourController();

    await tester.pumpWidget(
        centralApp(controller, navKey: navKey, home: page('أ', keyA, Colors.blue)));
    await tester.pump();

    // The app navigates on its own; nothing tour-related wraps either page.
    navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: page('ب', keyB, Colors.green))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Called from "anywhere": no SpotlightTour on this route at all.
    controller.start(steps: [
      TourStep(targetKey: keyB, title: 'عنصر الصفحة ب', description: 'مُبرز فوق المسار الكامل'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('عنصر الصفحة ب'), findsOneWidget);
    expectSpotlightOn(tester, keyB);

    controller.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.status, TourStatus.idle);
    expect(find.byType(SpotlightPainter), findsNothing);
  });

  testWidgets('a step navigates to another page and highlights there',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    var pushedB = false;

    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: keyA, title: 'على الصفحة أ', description: 'الأولى'),
      TourStep(
        targetKey: keyB,
        title: 'على الصفحة ب',
        description: 'الجولة انتقلت بنفسها',
        onEnter: () {
          if (pushedB) return;
          pushedB = true;
          unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
              builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: page('ب', keyB, Colors.green)))));
        },
      ),
    ]);

    await tester.pumpWidget(
        centralApp(controller, navKey: navKey, home: page('أ', keyA, Colors.blue)));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expectSpotlightOn(tester, keyA);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1200));

    expect(find.text('على الصفحة ب'), findsOneWidget);
    expectSpotlightOn(tester, keyB);
  });

  testWidgets('start called before the host mounts shows once it does',
      (tester) async {
    final keyA = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: keyA, title: 'بدأت مبكراً', description: 'قبل بناء الواجهة'),
    ]);

    // A service starting the tour during app init, before the first frame.
    controller.start();
    expect(controller.status, TourStatus.running);

    await tester.pumpWidget(centralApp(controller, home: page('أ', keyA, Colors.blue)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('بدأت مبكراً'), findsOneWidget);
    expectSpotlightOn(tester, keyA);
  });

  testWidgets('restarting while running replaces the tour and runs teardown',
      (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final log = <String>[];
    final controller = SpotlightTourController();

    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: Column(children: [
          Container(key: keyA, height: 60, color: Colors.blue),
          Container(key: keyB, height: 60, color: Colors.green),
        ]),
      ),
    ));

    controller.start(steps: [
      TourStep(
        targetKey: keyA,
        title: 'الجولة القديمة',
        description: 'ستُستبدل',
        onNext: () => log.add('old onNext'),
        onExit: () => log.add('old onExit'),
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('الجولة القديمة'), findsOneWidget);

    // Another section asks for its tour while this one is visible.
    controller.start(steps: [
      TourStep(targetKey: keyB, title: 'الجولة الجديدة', description: 'استبدلت'),
    ]);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 900));

    expect(find.text('الجولة الجديدة'), findsOneWidget);
    expect(find.text('الجولة القديمة'), findsNothing);
    expectSpotlightOn(tester, keyB);
    // Teardown of the replaced step ran; its forward action did not.
    expect(log, ['old onExit']);
  });

  testWidgets('skip on a tour that navigated pops what onExit pops',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    var pushedB = false;
    final log = <String>[];

    void pushB() {
      if (pushedB) return;
      pushedB = true;
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: page('ب', keyB, Colors.green)))));
    }

    void popB() {
      if (!pushedB) return;
      pushedB = false;
      log.add('popB');
      navKey.currentState!.pop();
    }

    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: keyA, title: 'خطوة أ', description: 'وصف'),
      TourStep(
          targetKey: keyB,
          title: 'خطوة ب',
          description: 'وصف',
          onEnter: pushB,
          onExit: popB),
    ]);

    await tester.pumpWidget(
        centralApp(controller, navKey: navKey, home: page('أ', keyA, Colors.blue)));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1200));
    expect(find.text('خطوة ب'), findsOneWidget);

    await tester.tap(find.text('تخطي الجولة'));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1200));

    expect(log, ['popB']);
    expect(controller.status, TourStatus.idle);
    expect(find.text('ب'), findsNothing); // route B popped
    expect(find.byType(SpotlightPainter), findsNothing);
  });

  testWidgets('modal sheet opened above a pushed route is highlighted',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final keyA = GlobalKey();
    final sheetItemKey = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keyA,
        title: 'افتح الخيارات',
        description: 'التالي يفتح النافذة',
        onNext: () => unawaited(showModalBottomSheet<void>(
          context: navKey.currentContext!,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              height: 220,
              child: Center(
                child: Container(
                  key: sheetItemKey,
                  padding: const EdgeInsets.all(12),
                  child: const Text('داخل النافذة'),
                ),
              ),
            ),
          ),
        )),
      ),
      TourStep(
          targetKey: sheetItemKey,
          title: 'عنصر النافذة',
          description: 'مُبرز داخل النافذة'),
    ]);

    await tester.pumpWidget(
        centralApp(controller, navKey: navKey, home: page('أ', keyA, Colors.blue)));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1500));

    expect(find.text('عنصر النافذة'), findsOneWidget);
    expectSpotlightOn(tester, sheetItemKey);

    // Clean up: leave neither the tour nor the sheet behind.
    controller.skip();
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 800));
    navKey.currentState!.pop();
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
  });

  testWidgets('host unmount mid-tour removes the overlay; remount reshows',
      (tester) async {
    final keyA = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: keyA, title: 'جولة', description: 'وصف'),
    ]);

    await tester.pumpWidget(centralApp(controller, home: page('أ', keyA, Colors.blue)));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('جولة'), findsOneWidget);

    // The whole app tree goes away (e.g. a splash swap in tests).
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(find.byType(SpotlightPainter), findsNothing);
    expect(controller.status, TourStatus.running);

    // Remount: the running tour comes back without calling start again.
    await tester.pumpWidget(centralApp(controller, home: page('أ', keyA, Colors.blue)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('جولة'), findsOneWidget);
    expectSpotlightOn(tester, keyA);

    controller.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('two hosts for one controller fail in debug', (tester) async {
    final controller = SpotlightTourController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        Expanded(
            child: SpotlightTourHost(
                controller: controller, child: const SizedBox())),
        Expanded(
            child: SpotlightTourHost(
                controller: controller, child: const SizedBox())),
      ]),
    ));
    final error = tester.takeException();
    expect(error, isA<AssertionError>());
    expect(error.toString(), contains('another host is already mounted'));

    // Clean up the poisoned tree so later tests start fresh.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('per-run tourId records completion per section', (tester) async {
    final keyA = GlobalKey();
    final store = InMemoryTourCompletionStore();
    final controller = SpotlightTourController(completionStore: store);

    await tester.pumpWidget(centralApp(controller, home: page('أ', keyA, Colors.blue)));

    // First launch of the mushaf section: runs.
    final started =
        await controller.startOnce(tourId: 'mushaf', steps: [
      TourStep(targetKey: keyA, title: 'جولة المصحف', description: 'وصف'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(started, isTrue);
    expect(find.text('جولة المصحف'), findsOneWidget);

    controller.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Recorded under the per-run id, not the controller's (null) id.
    expect(await store.isCompleted('mushaf'), isTrue);

    // Second launch of the same section: does not run.
    final again = await controller.startOnce(tourId: 'mushaf', steps: [
      TourStep(targetKey: keyA, title: 'جولة المصحف', description: 'وصف'),
    ]);
    expect(again, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('جولة المصحف'), findsNothing);

    // A different section on the SAME controller still runs its first time.
    final other = await controller.startOnce(tourId: 'settings', steps: [
      TourStep(targetKey: keyA, title: 'جولة الإعدادات', description: 'وصف'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(other, isTrue);
    expect(find.text('جولة الإعدادات'), findsOneWidget);

    controller.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
