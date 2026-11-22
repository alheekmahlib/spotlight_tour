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
}
