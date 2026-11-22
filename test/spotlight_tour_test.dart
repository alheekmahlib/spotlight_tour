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
}
