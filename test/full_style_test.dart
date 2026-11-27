import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

void main() {
  test('new style fields fall back to theme and override when set', () {
    final base = SpotlightTourTheme.gold().copyWith(
      indicatorColor: Colors.green,
      glowOpacity: 0.3,
      cardMaxWidth: 320,
    );
    final same = const TourStepStyle().applyTo(base);
    expect(same.indicatorColor, Colors.green);
    expect(same.glowOpacity, 0.3);
    expect(same.cardMaxWidth, 320);
    expect(same.hintIcon, Icons.touch_app_outlined);
    final over = const TourStepStyle(
      indicatorColor: Colors.red,
      borderColor: Colors.pink,
      cardBorderWidth: 2,
    ).applyTo(base);
    expect(over.indicatorColor, Colors.red);
    expect(over.borderColor, Colors.pink);
    expect(over.cardBorderWidth, 2);
    expect(over.glowOpacity, 0.3);
  });

  testWidgets('pointer, border and labels follow theme then step style',
      (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    final c = SpotlightTourController(steps: [
      TourStep(targetKey: a, title: 'A', description: 'a'),
      TourStep(
        targetKey: b,
        title: 'B',
        description: 'b',
        nextLabel: 'تابع',
        style: const TourStepStyle(
            indicatorColor: Colors.red, borderColor: Colors.pink),
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: SpotlightTour(
        theme: SpotlightTourTheme.gold().copyWith(
            indicatorColor: Colors.green, borderColor: Colors.orange),
        controller: c,
        child: Scaffold(
          body: Column(children: [
            Container(key: a, height: 60, color: Colors.blue),
            const Spacer(),
            Container(key: b, height: 60, color: Colors.blue),
          ]),
        ),
      ),
    ));
    c.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    PulsePainter pulse() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PulsePainter>()
        .first;
    SpotlightPainter spot() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    expect(pulse().color, Colors.green);
    expect(spot().borderColor, Colors.orange);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(pulse().color, Colors.red);
    expect(spot().borderColor, Colors.pink);
    expect(find.text('تابع'), findsOneWidget);
    c.skip();
    await tester.pump(const Duration(seconds: 1));
  });
}
