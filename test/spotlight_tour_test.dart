import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

Widget buildApp(
  SpotlightTourController controller, {
  List<GlobalKey>? keys,
}) {
  final k = keys ?? List.generate(3, (_) => GlobalKey());
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: SpotlightTour(
        controller: controller,
        child: Scaffold(
          body: Column(
            children: [
              Container(key: k[0], height: 60, color: Colors.blue),
              const Spacer(),
              Container(key: k[1], height: 60, color: Colors.green),
              const Spacer(),
              Container(key: k[2], height: 60, color: Colors.red),
            ],
          ),
        ),
      ),
    ),
  );
}

List<TourStep> stepsFor(List<GlobalKey> keys) => [
      TourStep(targetKey: keys[0], title: 'الخطوة الأولى', description: 'وصف أول'),
      TourStep(targetKey: keys[1], title: 'الخطوة الثانية', description: 'وصف ثان'),
      TourStep(targetKey: keys[2], title: 'الخطوة الثالثة', description: 'وصف ثالث'),
    ];

void main() {
  testWidgets('starts, advances, goes back, and finishes', (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    var finished = false;
    final controller = SpotlightTourController(steps: stepsFor(keys))
      ..onFinish = () => finished = true;

    await tester.pumpWidget(buildApp(controller, keys: keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 من 3'), findsOneWidget);
    expect(find.text('الخطوة الأولى'), findsOneWidget);
    expect(find.text('السابق'), findsNothing);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('2 من 3'), findsOneWidget);
    expect(find.text('الخطوة الثانية'), findsOneWidget);

    await tester.tap(find.text('السابق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('1 من 3'), findsOneWidget);

    // Jump to the last step and finish.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('3 من 3'), findsOneWidget);
    expect(find.text('تم'), findsOneWidget);

    await tester.tap(find.text('تم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(finished, isTrue);
    expect(find.text('3 من 3'), findsNothing);
    expect(controller.status, TourStatus.idle);
  });

  testWidgets('skip pill dismisses the tour and calls onSkip', (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    var skipped = false;
    final controller = SpotlightTourController(steps: stepsFor(keys))
      ..onSkip = () => skipped = true;

    await tester.pumpWidget(buildApp(controller, keys: keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('تخطي الجولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(skipped, isTrue);
    expect(find.text('1 من 3'), findsNothing);
    expect(controller.status, TourStatus.idle);
  });

  testWidgets('intro step without a target shows the start label and no counter',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      const TourStep(title: 'جولة في التطبيق', description: 'مقدمة'),
      ...stepsFor(keys),
    ]);

    await tester.pumpWidget(buildApp(controller, keys: keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ابدأ الجولة'), findsOneWidget);
    expect(find.text('1 من 4'), findsNothing);
    expect(find.text('جولة في التطبيق'), findsOneWidget);

    await tester.tap(find.text('ابدأ الجولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('2 من 4'), findsOneWidget);
  });

  testWidgets('textLines shape follows a mid-line text range', (tester) async {
    const text =
        'lorem ipsum dolor sit amet consectetur adipiscing elit sed do '
        'eiusmod tempor incididunt ut labore et dolore magna aliqua enim';
    // Selection starts and ends mid-line: skips the first words of the first
    // line and the last words of the last line.
    const range = TextRange(start: 30, end: text.length - 25);
    final textKey = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: textKey,
        shape: TourTargetShape.textLines,
        textRange: range,
        title: 'النص',
        description: 'إطار متدرج حول السطور',
        showPulse: false,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: SpotlightTour(
        controller: controller,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: Text(text, key: textKey),
            ),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final paragraph = textKey.currentContext!.findRenderObject()!
        as RenderParagraph;
    final paraTopLeft = paragraph.localToGlobal(Offset.zero);
    final allBoxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: text.length));
    expect(allBoxes.length, greaterThan(2)); // wraps to several lines

    final painter = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).
        map((w) => w.painter).whereType<SpotlightPainter>().first;
    final path = painter.targetPath;
    expect(path, isNotNull);

    final bounds = path!.getBounds();
    final lineHeight =
        allBoxes.first.bottom - allBoxes.first.top;
    // The contour spans more than two rendered lines.
    expect(bounds.height, greaterThan(2.5 * lineHeight));

    // Middle line: fully inside the contour.
    final midBox = allBoxes[allBoxes.length ~/ 2];
    final midProbe = Offset(paraTopLeft.dx + paragraph.size.width / 2,
        paraTopLeft.dy + (midBox.top + midBox.bottom) / 2);
    expect(path.contains(midProbe), isTrue);

    // First line, before the selection starts (LTR: left edge): excluded.
    final firstBox = allBoxes.first;
    final firstProbe = Offset(paraTopLeft.dx + 2,
        paraTopLeft.dy + (firstBox.top + firstBox.bottom) / 2);
    expect(path.contains(firstProbe), isFalse);

    // Last line, after the selection ends: excluded.
    final lastBox = allBoxes.last;
    final lastProbe = Offset(
        paraTopLeft.dx + paragraph.size.width - 2,
        paraTopLeft.dy + (lastBox.top + lastBox.bottom) / 2);
    expect(path.contains(lastProbe), isFalse);
  });

  testWidgets('custom labels and LTR direction work', (tester) async {
    final keys = List.generate(2, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: keys[0], title: 'First', description: 'one'),
      TourStep(targetKey: keys[1], title: 'Second', description: 'two'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: SpotlightTour(
        controller: controller,
        labels: TourLabels(
          skip: 'Skip',
          previous: 'Back',
          next: 'Next',
          done: 'Done',
          counter: (c, t) => '$c of $t',
        ),
        child: Scaffold(
          body: Column(children: [
            Container(key: keys[0], height: 50),
            Container(key: keys[1], height: 50),
          ]),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('1 of 2'), findsNothing);
  });

  testWidgets('Next runs the step action and waits for a late target',
      (tester) async {
    final key0 = GlobalKey();
    final lateKey = GlobalKey();
    final showLate = ValueNotifier<bool>(false);
    final events = <String>[];
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: key0,
        title: 'الخطوة الأولى',
        description: 'وصف أول',
        onNext: () {
          events.add('onNext');
          // The target of the next step only appears after the action's
          // effect lands (like a sheet sliding in).
          Future<void>.delayed(const Duration(milliseconds: 200),
              () => showLate.value = true);
        },
      ),
      TourStep(targetKey: lateKey, title: 'الخطوة المتأخرة', description: 'ظهرت لاحقاً'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showLate,
              builder: (context, value, _) => Column(
                children: [
                  Container(key: key0, height: 60, color: Colors.blue),
                  const Spacer(),
                  if (value)
                    Container(key: lateKey, height: 60, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('الخطوة الأولى'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    // The action runs synchronously on press, before any animation frame.
    expect(events, ['onNext']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // card exits
    await tester.pump(const Duration(milliseconds: 100)); // widget appears
    await tester.pump(const Duration(milliseconds: 500)); // morph + enter

    expect(find.text('الخطوة المتأخرة'), findsOneWidget);

    // The spotlight resolved onto the late-appearing widget.
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    final lateBox = lateKey.currentContext!.findRenderObject()! as RenderBox;
    final lateCenter = lateBox.localToGlobal(lateBox.size.center(Offset.zero));
    expect(painter.targetPath, isNotNull);
    expect(painter.targetPath!.contains(lateCenter), isTrue);
  });

  testWidgets('requireInteraction passes the real gesture through and waits',
      (tester) async {
    final btnKey = GlobalKey();
    var taps = 0;
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: btnKey,
        title: 'جرّب بنفسك',
        description: 'اضغط الزر الحقيقي',
        interaction: TourTargetInteraction.tap,
        requireInteraction: true,
      ),
      const TourStep(title: 'أحسنت', description: 'تم تنفيذ الإجراء'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                key: btnKey,
                onPressed: () => taps++,
                child: const Text('زر التطبيق'),
              ),
            ),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // No Next button on this step: the hint replaces it.
    expect(find.text('نفّذ الإجراء في التطبيق للمتابعة'), findsOneWidget);
    expect(find.text('التالي'), findsNothing);

    // The tap passes through the dimmed backdrop inside the spotlight and
    // reaches the app's real button; the tour does not advance by itself.
    await tester.tap(find.byKey(btnKey));
    await tester.pump();
    expect(taps, 1);
    expect(controller.index, 0);

    // The app's own handler advances the tour.
    controller.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('أحسنت'), findsOneWidget);
  });

  testWidgets('backdrop still blocks touches outside the spotlight',
      (tester) async {
    final btnKey = GlobalKey();
    var taps = 0;
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: btnKey,
        title: 'هدف صغير',
        description: 'اللمس خارج الإطار محجوب',
        interaction: TourTargetInteraction.tap,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ElevatedButton(
                key: btnKey,
                onPressed: () => taps++,
                child: const Text('زر'),
              ),
            ),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // A point far from the small target stays blocked.
    await tester.tapAt(const Offset(700, 550));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('overlay rises above a modal sheet and highlights inside it',
      (tester) async {
    final key0 = GlobalKey();
    final sheetItemKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: key0,
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

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            body: Container(key: key0, height: 60, color: Colors.blue),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // sheet slides in
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));

    // The sheet is open and the tour continued onto a step targeting a
    // widget inside it.
    expect(find.text('داخل النافذة'), findsOneWidget);
    expect(find.text('عنصر النافذة'), findsOneWidget);

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    final itemBox =
        sheetItemKey.currentContext!.findRenderObject()! as RenderBox;
    final itemCenter =
        itemBox.localToGlobal(itemBox.size.center(Offset.zero));
    expect(painter.targetPath, isNotNull);
    expect(painter.targetPath!.contains(itemCenter), isTrue);
  });

  testWidgets('reentrant Next taps are ignored while an action runs',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    var actionRuns = 0;
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'الخطوة الأولى',
        description: 'وصف أول',
        onNext: () async {
          actionRuns++;
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
      ),
      TourStep(targetKey: keys[1], title: 'الخطوة الثانية', description: 'وصف ثان'),
      TourStep(targetKey: keys[2], title: 'الخطوة الثالثة', description: 'وصف ثالث'),
    ]);

    await tester.pumpWidget(buildApp(controller, keys: keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Two rapid advances: the second lands while the action is still
    // running. The button is disabled (spinner replaces the label) and a
    // programmatic reentrant call is ignored too.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    expect(find.text('التالي'), findsNothing); // spinner while busy
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    controller.next(); // reentrant programmatic call: must be ignored
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // action completes
    await tester.pump(const Duration(milliseconds: 900)); // transition done

    expect(actionRuns, 1);
    expect(controller.index, 1);
    expect(find.text('الخطوة الثانية'), findsOneWidget);
  });

  List<PulsePainter> pulsePainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<PulsePainter>()
      .toList();

  Widget buildAppWith(
    SpotlightTourController controller,
    List<GlobalKey> keys, {
    SpotlightTourTheme? theme,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SpotlightTour(
            controller: controller,
            theme: theme,
            child: Scaffold(
              body: Column(
                children: [
                  Container(key: keys[0], height: 60, color: Colors.blue),
                  const Spacer(),
                  Container(key: keys[1], height: 60, color: Colors.green),
                  const Spacer(),
                  Container(key: keys[2], height: 60, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('textLines contour tracks a target still moving after activation',
      (tester) async {
    // The tour advances while the page slide is still settling: the first
    // resolution catches the text mid-slide, and the contour must follow it
    // to its final position instead of freezing offset (0.4.0 regression).
    const text =
        'lorem ipsum dolor sit amet consectetur adipiscing elit sed do '
        'eiusmod tempor incididunt ut labore et dolore magna aliqua enim';
    final textKey = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: textKey,
        shape: TourTargetShape.textLines,
        title: 'النص',
        description: 'إطار متدرج حول السطور',
        showPulse: false,
      ),
    ]);

    var dx = -100.0; // the "page" starts mid-slide, shifted left
    late StateSetter slide;
    await tester.pumpWidget(MaterialApp(
      home: SpotlightTour(
        controller: controller,
        child: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            slide = setState;
            return Center(
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: SizedBox(
                  width: 200,
                  child: Text(text, key: textKey),
                ),
              ),
            );
          }),
        ),
      ),
    ));
    controller.start();
    await tester.pump();

    SpotlightPainter spotPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;

    // The expected outline, derived the way the package derives it: the
    // selection's rendered glyph boxes (which may legitimately overhang the
    // paragraph's layout width at wrap points), padded by the step's
    // targetPadding. Glyph metrics are dx-independent, so the expectation
    // tracks the text wherever it slides.
    Rect expectedOutline() {
      final para =
          textKey.currentContext!.findRenderObject()! as RenderParagraph;
      final origin = para.localToGlobal(Offset.zero);
      final boxes = para.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: text.length));
      var left = double.infinity, top = double.infinity;
      var right = double.negativeInfinity, bottom = double.negativeInfinity;
      for (final b in boxes) {
        left = left < b.left + origin.dx ? left : b.left + origin.dx;
        top = top < b.top + origin.dy ? top : b.top + origin.dy;
        right = right > b.right + origin.dx ? right : b.right + origin.dx;
        bottom = bottom > b.bottom + origin.dy ? bottom : b.bottom + origin.dy;
      }
      return Rect.fromLTRB(left - 8, top - 8, right + 8, bottom + 8);
    }

    void expectOutlineFollowsText(Rect actual, Rect expected) {
      expect(actual.left, moreOrLessEquals(expected.left, epsilon: 2));
      expect(actual.top, moreOrLessEquals(expected.top, epsilon: 2));
      expect(actual.right, moreOrLessEquals(expected.right, epsilon: 2));
      expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: 2));
    }

    await tester.pump(const Duration(milliseconds: 500));
    // Mid-slide: the contour sits on the text's CURRENT (shifted) position.
    final midExpected = expectedOutline();
    final midBounds = spotPainter().targetPath!.getBounds();
    expectOutlineFollowsText(midBounds, midExpected);

    // The page settles in steps, like a PageView slide decelerating.
    for (final step in [-60.0, -25.0, -8.0, 0.0]) {
      slide(() => dx = step);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(seconds: 1));

    // Settled: the contour followed the text to its FINAL position, 100px
    // to the right of where it was first resolved.
    final finalBounds = spotPainter().targetPath!.getBounds();
    expectOutlineFollowsText(finalBounds, expectedOutline());
    expect(finalBounds.right - midBounds.right,
        moreOrLessEquals(100, epsilon: 2));
  });

  test('SwipePainter head glides in the requested direction and fades',
      () {
    // Left to right: starts at the left edge, ends at the right edge.
    expect(SwipePainter.headFraction(0.0, leftToRight: true), 0.0);
    expect(SwipePainter.headFraction(0.82, leftToRight: true), 1.0);
    final early = SwipePainter.headFraction(0.30, leftToRight: true);
    final late = SwipePainter.headFraction(0.60, leftToRight: true);
    expect(late, greaterThan(early));
    // Right to left mirrors the motion.
    expect(SwipePainter.headFraction(0.0, leftToRight: false), 1.0);
    expect(SwipePainter.headFraction(0.82, leftToRight: false), 0.0);
    expect(SwipePainter.headFraction(0.60, leftToRight: false),
        lessThan(SwipePainter.headFraction(0.30, leftToRight: false)));
    // The cycle fades in and out so repeats read as separate swipes.
    expect(SwipePainter.headOpacity(0.0), 0.0);
    expect(SwipePainter.headOpacity(0.5), 1.0);
    expect(SwipePainter.headOpacity(1.0), 0.0);
  });

  testWidgets('swipe indicator paints instead of the pulse, then rests',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'اسحب',
        description: 'اسحب الصفحة للمتابعة',
        indicator: TourIndicator.swipeLeftToRight,
      ),
    ]);

    List<SwipePainter> swipePainters(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SwipePainter>()
        .toList();

    await tester.pumpWidget(buildAppWith(controller, keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(swipePainters(tester), isNotEmpty);
    expect(swipePainters(tester).first.leftToRight, isTrue);
    expect(pulsePainters(tester), isEmpty); // not both at once

    // Bounded like the pulse: after 4 cycles it rests.
    await tester.pump(const Duration(milliseconds: 6500));
    await tester.pump();
    expect(swipePainters(tester), isEmpty);
    expect(find.text('1 من 1'), findsOneWidget); // tour still alive
  });

  testWidgets('reduced motion suppresses the swipe indicator too',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'اسحب',
        description: 'اسحب الصفحة للمتابعة',
        indicator: TourIndicator.swipeRightToLeft,
      ),
    ]);

    await tester.pumpWidget(
        buildAppWith(controller, keys, disableAnimations: true));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final swipes = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SwipePainter>()
        .toList();
    expect(swipes, isEmpty);
  });

  testWidgets('bounded pulse rests after its cycles', (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: stepsFor(keys));
    final theme = SpotlightTourTheme.gold().copyWith(
      pulseRepeatCount: () => 2,
    );

    await tester.pumpWidget(buildAppWith(controller, keys, theme: theme));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Pulse is running early on.
    expect(pulsePainters(tester), isNotEmpty);

    // After two 1.5s cycles (plus margin) the orb is gone: nothing keeps
    // repainting while the user reads.
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump();
    expect(pulsePainters(tester), isEmpty);
    // The tour itself is still fully alive.
    expect(find.text('1 من 3'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('2 من 3'), findsOneWidget);
    // The pulse restarted for the new step.
    expect(pulsePainters(tester), isNotEmpty);
  });

  testWidgets('pulseRepeatCount null keeps the pulse repeating', (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: stepsFor(keys));
    final theme = SpotlightTourTheme.gold().copyWith(
      pulseRepeatCount: () => null,
    );

    await tester.pumpWidget(buildAppWith(controller, keys, theme: theme));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 5000));
    expect(pulsePainters(tester), isNotEmpty);
  });

  testWidgets('reduced motion: no pulse, instant spotlight, short card fade',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: stepsFor(keys));

    await tester.pumpWidget(
        buildAppWith(controller, keys, disableAnimations: true));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 من 3'), findsOneWidget);
    expect(pulsePainters(tester), isEmpty);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    // Morph duration is zero: a single short settle reaches the next step.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 من 3'), findsOneWidget);
    expect(pulsePainters(tester), isEmpty);
  });

  testWidgets('glowSigma 0 skips the blur but keeps the border', (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: stepsFor(keys));
    final theme = SpotlightTourTheme.gold().copyWith(glowSigma: 0);

    await tester.pumpWidget(buildAppWith(controller, keys, theme: theme));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    expect(painter.glowSigma, 0);
    expect(painter.targetPath, isNotNull);
    expect(find.text('1 من 3'), findsOneWidget);
  });

  testWidgets('startOnce runs the tour once and remembers completion',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final store = InMemoryTourCompletionStore();
    final controller = SpotlightTourController(
      steps: stepsFor(keys),
      tourId: 'home',
      completionStore: store,
    );

    await tester.pumpWidget(buildAppWith(controller, keys));
    expect(await controller.startOnce(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 من 3'), findsOneWidget);

    // Finishing the tour records completion.
    controller.finish();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(await store.isCompleted('home'), isTrue);

    // A second auto-start does nothing.
    expect(await controller.startOnce(), isFalse);
    await tester.pump();
    expect(controller.status, TourStatus.idle);

    // Resetting (e.g. from a "show the tour again" setting) re-enables it.
    await store.reset('home');
    expect(await controller.startOnce(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 من 3'), findsOneWidget);
  });

  testWidgets('skip marks completion unless markCompletedOnSkip is false',
      (tester) async {
    final keys = List.generate(3, (_) => GlobalKey());
    final store = InMemoryTourCompletionStore();
    final controller = SpotlightTourController(
      steps: stepsFor(keys),
      tourId: 'home',
      completionStore: store,
      markCompletedOnSkip: false,
    );

    await tester.pumpWidget(buildAppWith(controller, keys));
    expect(await controller.startOnce(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    controller.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(await store.isCompleted('home'), isFalse);
    // Not marked: the next auto-start runs the tour again.
    expect(await controller.startOnce(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.status, TourStatus.running);
  });
}
