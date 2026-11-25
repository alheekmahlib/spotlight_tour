import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // RenderProxyBox: the test's unlaid page
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

/// Targets tagged with a plain key ([ValueKey]) instead of a [GlobalKey]:
/// for widgets that are mounted more than once at the same time, where a
/// GlobalKey would be a duplicate.
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

Path? spotlightPath(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<SpotlightPainter>()
      .first
      .targetPath;
}

Offset centerOf(RenderBox box) =>
    box.localToGlobal(box.size.center(Offset.zero));

/// A copy of the widget tagged with [key]. Finders skip what sits inside an
/// `Offstage` by default; the tour's lookup does not, so neither do we.
RenderBox copyOf(WidgetTester tester, Key key, {required bool last}) {
  final found = find.byKey(key, skipOffstage: false);
  return tester.renderObject<RenderBox>(last ? found.last : found.first);
}

/// A target nobody can see, so the lookup must give up quickly.
const Duration _shortTimeout = Duration(milliseconds: 100);

Future<void> startAndWait(
  WidgetTester tester,
  SpotlightTourController controller, {
  bool expectsNoTarget = false,
}) async {
  controller.start();
  await tester.pump();
  await settle(tester);
  if (expectsNoTarget) {
    // [TourStep.targetTimeout] is measured on the wall clock, which the
    // test's fake clock does not advance: let real time pass the timeout,
    // then run out the card's entrance.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await settle(tester);
  }
}

/// Lets the tour run out its exit animation, so no retry timer or ticker of
/// its own is left pending when the test ends.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> endTour(
  WidgetTester tester,
  SpotlightTourController controller,
) async {
  controller.skip();
  await tester.pump();
  await settle(tester);
}

void main() {
  testWidgets(
      'a plain key highlights the on-stage copy of a twice-mounted widget',
      (tester) async {
    // What family_bottom_sheet does: one page widget instance mounted twice,
    // once offstage to measure its height and once for the user.
    const target = ValueKey<String>('menu-item');
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: target, title: 'خيار', description: 'داخل الورقة'),
    ]);
    final item = SizedBox(
      key: target,
      width: 80,
      height: 40,
      child: const ColoredBox(color: Colors.red),
    );

    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: Stack(children: [
          Offstage(child: item),
          Align(alignment: Alignment.bottomCenter, child: item),
        ]),
      ),
    ));
    await startAndWait(tester, controller);

    final path = spotlightPath(tester)!;
    final onStage = copyOf(tester, target, last: true);
    final offStage = copyOf(tester, target, last: false);
    // The two copies sit apart; the measuring one is parked at the origin.
    expect(centerOf(offStage), isNot(centerOf(onStage)));
    expect(path.contains(centerOf(onStage)), isTrue);
    expect(path.contains(centerOf(offStage)), isFalse);
    await endTour(tester, controller);
  });

  testWidgets('a plain key ignores the copy scrolled out of a viewport',
      (tester) async {
    const target = ValueKey<String>('page-mark');
    final controller = SpotlightTourController(steps: [
      TourStep(
          targetKey: target, title: 'علامة الصفحة', description: 'في الصفحة'),
    ]);
    Widget pageMark(Color color) => SizedBox(
          width: 300,
          height: 100,
          child: Center(
            child: SizedBox(
              key: target,
              width: 60,
              height: 40,
              child: ColoredBox(color: color),
            ),
          ),
        );

    // A narrow page view in the middle of a wide screen, as in landscape:
    // the next page's mark still lies inside the screen, so only the
    // viewport's clip hides it.
    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  pageMark(Colors.red),
                  pageMark(Colors.green),
                ]),
              ),
            ),
          ),
        ),
      ),
    ));
    await startAndWait(tester, controller);

    final shown = copyOf(tester, target, last: false);
    final clipped = copyOf(tester, target, last: true);
    expect(clipped.size.width, 60);
    // The clipped copy is on screen coordinates-wise: bounds alone must not
    // disqualify it, only the clip does.
    expect(centerOf(clipped).dx, lessThan(800));
    final path = spotlightPath(tester)!;
    expect(path.contains(centerOf(shown)), isTrue);
    expect(path.contains(centerOf(clipped)), isFalse);
    await endTour(tester, controller);
  });

  testWidgets('the topmost copy wins when a plain key exists on two routes',
      (tester) async {
    const target = ValueKey<String>('gear');
    final navKey = GlobalKey<NavigatorState>();
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: target, title: 'الإعدادات', description: 'في الأعلى'),
    ]);
    Widget gearBar(Alignment alignment, Color color) => Scaffold(
          body: Align(
            alignment: alignment,
            child: SizedBox(
              key: target,
              width: 80,
              height: 40,
              child: ColoredBox(color: color),
            ),
          ),
        );

    await tester.pumpWidget(centralApp(
      controller,
      navKey: navKey,
      home: gearBar(Alignment.topCenter, Colors.blue),
    ));
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: gearBar(Alignment.bottomCenter, Colors.green),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await startAndWait(tester, controller);

    final below = copyOf(tester, target, last: false);
    final onTop = copyOf(tester, target, last: true);
    final path = spotlightPath(tester)!;
    expect(path.contains(centerOf(onTop)), isTrue);
    expect(path.contains(centerOf(below)), isFalse);

    // Leave neither the tour nor the pushed route behind.
    await endTour(tester, controller);
    navKey.currentState!.pop();
    await tester.pump();
    await settle(tester);
  });

  testWidgets('no visible copy shows the card without a spotlight',
      (tester) async {
    const target = ValueKey<String>('offstage-only');
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: target,
        title: 'خيار مخفي',
        description: 'لا يظهر',
        targetTimeout: _shortTimeout,
      ),
    ]);

    await tester.pumpWidget(centralApp(
      controller,
      home: const Scaffold(
        body: Offstage(
          child: SizedBox(
            key: ValueKey<String>('offstage-only'),
            width: 80,
            height: 40,
          ),
        ),
      ),
    ));
    await startAndWait(tester, controller, expectsNoTarget: true);

    expect(find.text('خيار مخفي'), findsOneWidget);
    expect(spotlightPath(tester), isNull);
    await endTour(tester, controller);
  });

  testWidgets('a copy whose position is not finite is skipped', (tester) async {
    // A page kept alive in a viewport that never got a finite size: it is
    // not painted, yet reports a NaN paint transform, which no "is empty"
    // rect check catches. It comes after the good copy in the tree, so
    // "last visible copy wins" would pick it.
    const target = ValueKey<String>('page-mark');
    final controller = SpotlightTourController(steps: [
      TourStep(
          targetKey: target, title: 'علامة الصفحة', description: 'في الصفحة'),
    ]);
    final item = SizedBox(
      key: target,
      width: 80,
      height: 40,
      child: const ColoredBox(color: Colors.red),
    );

    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: Stack(children: [
          Align(alignment: Alignment.bottomCenter, child: item),
          _UnlaidPage(child: item),
        ]),
      ),
    ));
    await startAndWait(tester, controller);

    // The good copy comes first in the tree; the unlaid one is last.
    final good = copyOf(tester, target, last: false);
    final path = spotlightPath(tester)!;
    expect(path.contains(centerOf(good)), isTrue);
    await endTour(tester, controller);
  });

  testWidgets('a GlobalKey target with a non-finite position gets no spotlight',
      (tester) async {
    // A rect holding NaN must never reach the canvas: the engine rejects it.
    final target = GlobalKey();
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: target,
        title: 'هدف بلا موضع',
        description: 'لا إطار',
        targetTimeout: _shortTimeout,
      ),
    ]);

    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: _UnlaidPage(
          child: SizedBox(
            key: target,
            width: 80,
            height: 40,
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    ));
    await startAndWait(tester, controller, expectsNoTarget: true);

    expect(find.text('هدف بلا موضع'), findsOneWidget);
    expect(spotlightPath(tester), isNull);
    await endTour(tester, controller);
  });

  testWidgets(
      'a plain key inside the hidden child of an IndexedStack is skipped',
      (tester) async {
    const target = ValueKey<String>('tab-body');
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: target,
        title: 'تبويب مخفي',
        description: 'لا يظهر',
        targetTimeout: _shortTimeout,
      ),
    ]);

    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: IndexedStack(index: 0, children: [
          const SizedBox(width: 80, height: 40),
          const SizedBox(
            key: target,
            width: 80,
            height: 40,
            child: ColoredBox(color: Colors.red),
          ),
        ]),
      ),
    ));
    await startAndWait(tester, controller, expectsNoTarget: true);

    expect(find.text('تبويب مخفي'), findsOneWidget);
    expect(spotlightPath(tester), isNull);
    await endTour(tester, controller);
  });

  testWidgets(
      'a plain-key target scaled by FittedBox is highlighted as painted',
      (tester) async {
    const target = ValueKey<String>('third-cell');
    final controller = SpotlightTourController(steps: [
      TourStep(targetKey: target, title: 'زر', description: 'داخل صف مصغّر'),
    ]);
    Widget cell(Key? key) => SizedBox(
          key: key,
          width: 100,
          height: 50,
          child: const ColoredBox(color: Colors.red),
        );

    // An 800x50 row scaled down to half in a 400x50 box at (200, 300): the
    // third cell paints at x 300..350, y 300..325, though it is laid out as
    // 100x50.
    await tester.pumpWidget(centralApp(
      controller,
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            Positioned(
              left: 200,
              top: 300,
              width: 400,
              height: 50,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cell(null),
                    cell(null),
                    cell(target),
                    cell(null),
                    cell(null),
                    cell(null),
                    cell(null),
                    cell(null),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
    await startAndWait(tester, controller);

    final path = spotlightPath(tester)!;
    // Centre of the painted cell.
    expect(path.contains(const Offset(325, 312)), isTrue);
    // Inside the unscaled 100x50 box, outside what is actually painted.
    expect(path.contains(const Offset(380, 340)), isFalse);
    await endTour(tester, controller);
  });
}

/// A kept-alive page that is never painted yet still reports where its
/// child would be: a position that is not a number. Stands in for a page
/// kept in a viewport that never got a finite size.
class _UnlaidPage extends SingleChildRenderObjectWidget {
  const _UnlaidPage({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUnlaidPage();
}

class _RenderUnlaidPage extends RenderProxyBox {
  @override
  void performLayout() {
    size = constraints.smallest;
    child?.layout(constraints, parentUsesSize: false);
  }

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.storage[12] = double.nan;
  }
}
