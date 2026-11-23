import 'package:flutter/material.dart' hide Path;
import 'package:flutter/rendering.dart' show RenderParagraph;

import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

RRect line(double left, double top, double right, double bottom,
        [double radius = 16]) =>
    RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom), Radius.circular(radius));

void main() {
  group('steppedContourPath geometry', () {
    test('single line falls back to its rounded rect', () {
      final r = line(10, 10, 200, 50);
      final path = steppedContourPath([r]);
      expect(path.getBounds(), r.outerRect);
    });

    test('verse shape: full lines + shorter last line anchored right (RTL)',
        () {
      // Two full-width lines, then a last line that starts further right,
      // vertically overlapping like padded line boxes do.
      final path = steppedContourPath([
        line(20, 10, 360, 58),
        line(20, 50, 360, 98),
        line(140, 90, 360, 138),
      ]);
      // Exactly one closed contour: the outline can never look disconnected.
      expect(path.computeMetrics().length, 1);
      final b = path.getBounds();
      expect(b, Rect.fromLTRB(20, 10, 360, 138));
      // Inside the neck on the left join (x inside lines 1-2, outside
      // line 3), both above and below the step.
      expect(path.contains(const Offset(30, 60)), isTrue);
      expect(path.contains(const Offset(30, 120)), isFalse);
      // Right side: all lines share the edge, the whole column is inside.
      expect(path.contains(const Offset(350, 30)), isTrue);
      expect(path.contains(const Offset(350, 75)), isTrue);
      expect(path.contains(const Offset(350, 120)), isTrue);
      expect(path.contains(const Offset(370, 75)), isFalse);
    });

    test('middle line narrower than both neighbours', () {
      final path = steppedContourPath([
        line(20, 10, 360, 58),
        line(80, 50, 300, 98),
        line(20, 90, 360, 138),
      ]);
      expect(path.computeMetrics().length, 1);
      // Beside the narrow middle line, inside the wide lines' bands.
      expect(path.contains(const Offset(30, 40)), isTrue);
      expect(path.contains(const Offset(30, 110)), isTrue);
      expect(path.contains(const Offset(340, 40)), isTrue);
      // Middle line's own band is inside at its narrower edges...
      expect(path.contains(const Offset(90, 74)), isTrue);
      expect(path.contains(const Offset(290, 74)), isTrue);
      // ...but the gaps beside it are genuinely outside the outline.
      expect(path.contains(const Offset(30, 74)), isFalse);
      expect(path.contains(const Offset(340, 74)), isFalse);
    });

    test('line below wider on the right steps at its top', () {
      final path = steppedContourPath([
        line(20, 10, 200, 58),
        line(20, 50, 360, 98),
      ]);
      expect(path.computeMetrics().length, 1);
      // Below line 1's right edge, inside line 2's extra reach.
      expect(path.contains(const Offset(300, 74)), isTrue);
      // ...but not above the step (line 1 ends at x=200).
      expect(path.contains(const Offset(300, 30)), isFalse);
      expect(path.contains(const Offset(150, 30)), isTrue);
    });

    test('varied line heights stay one contour', () {
      final path = steppedContourPath([
        line(20, 10, 360, 34, 10),
        line(60, 28, 300, 108, 10),
        line(20, 100, 360, 144, 10),
      ]);
      expect(path.computeMetrics().length, 1);
      expect(path.getBounds(), Rect.fromLTRB(20, 10, 360, 144));
      expect(path.contains(const Offset(30, 22)), isTrue);
      expect(path.contains(const Offset(150, 68)), isTrue);
      expect(path.contains(const Offset(30, 122)), isTrue);
    });

    test('gapped lines (mid-morph) still trace one contour', () {
      // During a step morph the lerped line rects can separate vertically;
      // the outline must stay a single shape rather than split.
      final path = steppedContourPath([
        line(20, 10, 360, 50),
        line(60, 70, 300, 110),
      ]);
      expect(path.computeMetrics().length, 1);
    });

    test('sub-pixel width differences produce no jagged extra contour', () {
      final path = steppedContourPath([
        line(20, 10, 360, 58),
        line(20, 50, 360.3, 98),
        line(20.2, 90, 360, 138),
      ]);
      expect(path.computeMetrics().length, 1);
    });

    test('tall stack with zigzag widths', () {
      final path = steppedContourPath([
        line(100, 10, 360, 50),
        line(20, 44, 360, 84),
        line(20, 78, 260, 118),
        line(150, 112, 360, 152),
        line(20, 146, 200, 186),
      ]);
      expect(path.computeMetrics().length, 1);
      final b = path.getBounds();
      expect(b, Rect.fromLTRB(20, 10, 360, 186));
    });
  });

  testWidgets('RTL verse contour is one connected outline at both joins',
      (tester) async {
    // Partial first and last lines, like a verse selected mid-page: the
    // selection starts mid-line 1 and ends mid-line 3.
    const text =
        'وَاللَّهُ لَا إِلَٰهَ هُوَ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ '
        'الْقِيَامَةِ لَا رَيْبَ فِيهِ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا '
        'وَاللَّهُ لَا إِلَٰهَ هُوَ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ '
        'الْقِيَامَةِ لَا رَيْبَ فِيهِ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا';
    const range = TextRange(start: 20, end: text.length - 30);
    final textKey = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: textKey,
        shape: TourTargetShape.textLines,
        textRange: range,
        title: 'الآية',
        description: 'إطار متصل',
        showPulse: false,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: Text(text,
                    key: textKey,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 18, height: 2.0)),
              ),
            ),
          ),
        ),
      ),
    ));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final paragraph =
        textKey.currentContext!.findRenderObject()! as RenderParagraph;
    final origin = paragraph.localToGlobal(Offset.zero);
    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end));
    expect(boxes.length, greaterThan(2));

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    final path = painter.targetPath!;

    // One closed contour, whatever the line widths are.
    expect(path.computeMetrics().length, 1);

    // Every line's interior is inside the outline; the padding band of a
    // full-width middle line is inside at both side edges.
    final mid = boxes[boxes.length ~/ 2];
    final midY = origin.dy + (mid.top + mid.bottom) / 2;
    expect(path.contains(Offset(origin.dx + mid.left + 1, midY)), isTrue);
    expect(path.contains(Offset(origin.dx + mid.right - 1, midY)), isTrue);

    // Right-side join (RTL: the shared right edge of full lines): the
    // column just inside the edge is inside across every line boundary.
    var right = double.negativeInfinity;
    for (final b in boxes) {
      right = right > b.right ? right : b.right;
    }
    for (var i = 0; i + 1 < boxes.length; i++) {
      final joinY =
          origin.dy + (boxes[i].bottom + boxes[i + 1].top) / 2;
      expect(path.contains(Offset(origin.dx + right - 2, joinY)), isTrue,
          reason: 'right join between line $i and ${i + 1} must be inside');
    }

    // Outside the outline stays outside: past the right edge and above the
    // selection's first line.
    expect(path.contains(Offset(origin.dx + right + 12, midY)), isFalse);
  });
}
