import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

Widget buildApp(
  SpotlightTourController controller,
  List<GlobalKey> keys,
) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: SpotlightTour(
        controller: controller,
        child: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < keys.length; i++) ...[
                Container(key: keys[i], height: 60, color: Colors.blue),
                if (i < keys.length - 1) const Spacer(),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

FilledButton primaryButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

Color? buttonColor(WidgetTester tester) =>
    primaryButton(tester).style?.backgroundColor?.resolve({});

Color? borderColor(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<SpotlightPainter>()
      .firstOrNull;
  return paint?.borderColor;
}

Container cardContainer(WidgetTester tester, String title) {
  final container = tester
      .widgetList<Container>(
        find.ancestor(of: find.text(title), matching: find.byType(Container)),
      )
      .firstWhere((c) => c.decoration is BoxDecoration);
  return container;
}

String _shortCounter(int current, int total) => '$current/$total';

void main() {
  test('applyTo falls back to the base theme for every null field', () {
    final base = SpotlightTourTheme.gold();
    final resolved = const TourStepStyle().applyTo(base);
    expect(resolved.scrimColor, base.scrimColor);
    expect(resolved.cardColor, base.cardColor);
    expect(resolved.accentColor, base.accentColor);
    expect(resolved.onAccentColor, base.onAccentColor);
    expect(resolved.titleStyle, base.titleStyle);
    expect(resolved.bodyStyle, base.bodyStyle);
    expect(resolved.cardRadius, base.cardRadius);
    expect(resolved.cardMaxWidth, base.cardMaxWidth);
    expect(resolved.borderWidth, base.borderWidth);
    expect(resolved.glowSigma, base.glowSigma);
    expect(resolved.targetGap, base.targetGap);
    expect(resolved.primaryButtonHeight, base.primaryButtonHeight);
    expect(resolved.pulseDuration, base.pulseDuration);
    expect(resolved.pulseRepeatCount, base.pulseRepeatCount);
    expect(resolved.spotlightMorphDuration, base.spotlightMorphDuration);
  });

  test('applyTo replaces set fields and merges text styles', () {
    final base = SpotlightTourTheme.gold();
    const style = TourStepStyle(
      accentColor: Colors.teal,
      cardColor: Colors.black,
      cardMaxWidth: 420,
      borderWidth: 3,
      glowSigma: 0,
      titleStyle: TextStyle(color: Colors.tealAccent),
    );
    final resolved = style.applyTo(base);
    expect(resolved.accentColor, Colors.teal);
    expect(resolved.cardColor, Colors.black);
    expect(resolved.cardMaxWidth, 420);
    expect(resolved.borderWidth, 3);
    expect(resolved.glowSigma, 0);
    // Merged: colour from the style, size/weight from the theme.
    expect(resolved.titleStyle.color, Colors.tealAccent);
    expect(resolved.titleStyle.fontSize, base.titleStyle.fontSize);
    expect(resolved.titleStyle.fontWeight, base.titleStyle.fontWeight);
    // Untouched: the theme's value.
    expect(resolved.scrimColor, base.scrimColor);
    expect(resolved.bodyStyle, base.bodyStyle);
  });

  testWidgets('styled step renders with its own colours', (tester) async {
    final keys = List.generate(2, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'خطوة مخصصة',
        description: 'وصف',
        style: const TourStepStyle(
          accentColor: Colors.teal,
          cardColor: Color(0xFF0E2A28),
          titleStyle: TextStyle(color: Colors.tealAccent),
        ),
      ),
      TourStep(targetKey: keys[1], title: 'خطوة عادية', description: 'وصف'),
    ]);

    await tester.pumpWidget(buildApp(controller, keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(buttonColor(tester), Colors.teal);
    expect(borderColor(tester), Colors.teal);
    final card = cardContainer(tester, 'خطوة مخصصة');
    expect((card.decoration as BoxDecoration).color, const Color(0xFF0E2A28));
    final title = tester.widget<Text>(find.text('خطوة مخصصة'));
    expect(title.style?.color, Colors.tealAccent);
    // The default gold theme's title size survives the partial override.
    expect(title.style?.fontSize,
        SpotlightTourTheme.gold().titleStyle.fontSize);
  });

  testWidgets('next step without a style falls back to the tour theme',
      (tester) async {
    final keys = List.generate(2, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'خطوة مخصصة',
        description: 'وصف',
        style: const TourStepStyle(accentColor: Colors.teal),
      ),
      TourStep(targetKey: keys[1], title: 'خطوة عادية', description: 'وصف'),
    ]);

    await tester.pumpWidget(buildApp(controller, keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(buttonColor(tester), Colors.teal);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    final gold = SpotlightTourTheme.gold();
    expect(buttonColor(tester), gold.accentColor);
    expect(borderColor(tester), gold.accentColor);
    final card = cardContainer(tester, 'خطوة عادية');
    expect((card.decoration as BoxDecoration).color, gold.cardColor);
  });

  testWidgets('going back restores the styled step\'s style', (tester) async {
    final keys = List.generate(2, (_) => GlobalKey());
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: keys[0],
        title: 'خطوة مخصصة',
        description: 'وصف',
        style: const TourStepStyle(accentColor: Colors.teal),
      ),
      TourStep(targetKey: keys[1], title: 'خطوة عادية', description: 'وصف'),
    ]);

    await tester.pumpWidget(buildApp(controller, keys));
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(buttonColor(tester), SpotlightTourTheme.gold().accentColor);

    await tester.tap(find.text('السابق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(buttonColor(tester), Colors.teal);
    expect(borderColor(tester), Colors.teal);
  });

  testWidgets('cardMaxWidth caps and centers the card', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    final c = SpotlightTourController(steps: [
      TourStep(targetKey: a, title: 'واسعة', description: 'وصف'),
      TourStep(
        targetKey: b,
        title: 'ضيّقة',
        description: 'وصف',
        style: const TourStepStyle(cardMaxWidth: 260),
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: SpotlightTour(
        theme: SpotlightTourTheme.gold().copyWith(cardMaxWidth: 420),
        // Short strings: the Ahem test font renders every glyph as a wide
        // square, so the default labels would overflow the capped card.
        labels: const TourLabels(
            skip: 'تخطي', counter: _shortCounter),
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
    // The tooltip card is the only Container with a coloured BoxDecoration.
    Finder cardBox() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color != null);

    c.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Theme-level cap on the 768-wide default surface.
    expect(tester.getSize(cardBox()).width, 420);
    expect(tester.getRect(cardBox()).center.dx, moreOrLessEquals(400));

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    // Let the card's horizontal move to the new cap finish settling.
    await tester.pump(const Duration(milliseconds: 500));

    // The step's own cap replaces the theme's.
    expect(tester.getSize(cardBox()).width, 260);
    expect(tester.getRect(cardBox()).center.dx, moreOrLessEquals(400));
  });
}
