import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';
import 'package:spotlight_tour/src/painters.dart';

import 'central_demo.dart';

Future<void> loadFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.view(File(path).readAsBytesSync().buffer);
  // The material icons font lives in the Flutter SDK cache. The running
  // binary is either dart (<sdk>/bin/cache/dart-sdk/bin/dart) or
  // flutter_tester (<sdk>/bin/cache/artifacts/engine/.../flutter_tester):
  // walk up until we find the cache directory holding the font.
  var dir = File(Platform.resolvedExecutable).absolute.parent;
  var icons =
      '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
  for (var i = 0; i < 8 && !File(icons).existsSync(); i++) {
    dir = dir.parent;
    icons = '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  final naskh = FontLoader('NotoNaskh')
    ..addFont(read('test/assets/NotoNaskhArabic-Regular.ttf'))
    ..addFont(read('test/assets/NotoNaskhArabic-SemiBold.ttf'))
    ..addFont(read('test/assets/NotoNaskhArabic-Bold.ttf'));
  final amiri = FontLoader('Amiri')
    ..addFont(read('test/assets/Amiri-Regular.ttf'));
  final materialIcons = FontLoader('MaterialIcons')..addFont(read(icons));
  await naskh.load();
  await amiri.load();
  await materialIcons.load();
}

/// نص الصفحة الأولى.
const String pageOneText =
    'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا ۗ '
    'إِنَّ اللَّهَ كَانَ عَلَىٰ كُلِّ شَيْءٍ حَسِيبًا ﴿٨٦﴾ '
    'يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَتَّبِعُوا خُطُوَاتِ الشَّيْطَانِ ۚ '
    'وَمَن يَتَّبِعُ خُطُوَاتِهِ فَإِنَّهُ يَأْمُرُ بِالْفَحْشَاءِ وَالْمُنكَرِ ﴿٢١﴾';

/// نص الصفحة الثانية.
const String pageTwoText =
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ '
    'فَمَا لَكُمْ فِي الْمُنَافِقِينَ فِئَتَيْنِ وَاللَّهُ أَرْكَسَهُم بِمَا كَسَبُوا ۚ أَتُرِيدُونَ أَن تَهْدُوا مَنْ أَضَلَّ اللَّهُ ﴿٨٨﴾';

/// نطاق الآية الثانية من الصفحة الأولى (تبدأ منتصف سطر وتنتهي منتصف سطر).
TextRange secondVerseOfPageOne() {
  const startMarker = 'يَا أَيُّهَا';
  const endMarker = '﴿٢١﴾';
  final start = pageOneText.indexOf(startMarker);
  final end = pageOneText.indexOf(endMarker) + endMarker.length;
  return TextRange(start: start, end: end);
}

class DemoKeys {
  final pageView = GlobalKey();
  final pageText = GlobalKey();
  final tafsir = GlobalKey();
  final quickBar = GlobalKey();
  final nav = GlobalKey();
}

/// شاشة العرض نفسها المستخدمة في مثال الحزمة: عرض تلقائي لقلب الصفحة يعود
/// بها إلى موضعها، ونافذة خيارات آية حقيقية تفتحها الجولة ثم تشرح عناصرها،
/// وتُعيد فتحها عند العودة بـ«السابق».
class GoldenDemoScreen extends StatefulWidget {
  const GoldenDemoScreen(
      {super.key,
      required this.keys,
      required this.tour,
      required this.pageController});

  final DemoKeys keys;
  final SpotlightTourController tour;
  final PageController pageController;

  @override
  State<GoldenDemoScreen> createState() => _GoldenDemoScreenState();
}

class _GoldenDemoScreenState extends State<GoldenDemoScreen>
    with TickerProviderStateMixin {
  late final PageSwipeDemo _swipeDemo = PageSwipeDemo(
    pageController: widget.pageController,
    vsync: this,
  );
  bool _verseOptionsOpen = false;

  DemoKeys get k => widget.keys;

  @override
  void dispose() {
    _swipeDemo.dispose();
    super.dispose();
  }

  Future<void> _openVerseOptions() async {
    if (_verseOptionsOpen) return;
    _verseOptionsOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1815),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                key: k.tafsir,
                leading: const Icon(Icons.menu_book_outlined,
                    color: Color(0xFFB08E3F)),
                title: const Text('التفسير',
                    style: TextStyle(color: Color(0xFFE8E2D5))),
                subtitle: const Text('ابن كثير والطبري',
                    style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
                onTap: () {},
              ),
              const ListTile(
                leading: Icon(Icons.share_outlined, color: Color(0x99FFFFFF)),
                title: Text('المشاركة',
                    style: TextStyle(color: Color(0xFFE8E2D5))),
              ),
              const ListTile(
                leading: Icon(Icons.headphones_outlined,
                    color: Color(0x99FFFFFF)),
                title:
                    Text('استماع', style: TextStyle(color: Color(0xFFE8E2D5))),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    _verseOptionsOpen = false;
  }

  void _closeVerseOptions() {
    if (!_verseOptionsOpen) return;
    Navigator.of(context).pop();
  }

  void _demonstrateSwipe() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    unawaited(_swipeDemo.demonstrate(TourSwipeDirection.leftToRight));
  }

  List<TourStep> _steps() => [
        const TourStep(
          title: 'جولة تفاعلية',
          description:
              'هذه الجولة لا تشرح فقط، بل تنفّذ معك: سترى كيف تُقلب الصفحة، وستفتح الجولة خيارات الآية الحقيقية لتشرحها لك.',
        ),
        TourStep(
          targetKey: k.pageView,
          title: 'قلّب الصفحات',
          description:
              'يمكنك التنقل بين صفحات المصحف بالسحب يميناً أو يساراً، كما تتحرك الصفحة الآن أمامك ثم تعود إلى مكانها.',
          icon: Icons.swipe_outlined,
          indicator: TourIndicator.swipeLeftToRight,
          swipeDemo: _swipeDemo,
          onEnter: _demonstrateSwipe,
          onExit: _swipeDemo.cancel,
        ),
        TourStep(
          targetKey: k.pageText,
          shape: TourTargetShape.textLines,
          textRange: secondVerseOfPageOne(),
          title: 'خيارات الآية',
          description:
              'الضغط المطوّل على أي آية يفتح خياراتها: التفسير والمشاركة والاستماع. اضغط «التالي» وسنفتحها لك الآن.',
          icon: Icons.touch_app_outlined,
          onNext: () => unawaited(_openVerseOptions()),
        ),
        TourStep(
          targetKey: k.tafsir,
          title: 'التفسير',
          description:
              'من هذه القائمة تفتح التفسير مباشرة. اضغط «التالي» لنغلق القائمة ونكمل الجولة.',
          icon: Icons.menu_book_outlined,
          onEnter: () => unawaited(_openVerseOptions()),
          onNext: _closeVerseOptions,
          onExit: _closeVerseOptions,
        ),
        TourStep(
          targetKey: k.quickBar,
          title: 'الأزرار السريعة',
          description:
              'شغّل التلاوة من هذه الآية، وشاركها نصاً أو صورة، وانسخها واحفظها.',
          icon: Icons.flash_on_outlined,
        ),
        TourStep(
          targetKey: k.nav,
          title: 'أقسام التطبيق',
          description: 'المحفوظات والقراءة والإعدادات، كلها من الشريط السفلي.',
          icon: Icons.menu_book_outlined,
        ),
        const TourStep(
          title: 'هذا كل شيء',
          description:
              'تجد هذه الجولة في الإعدادات متى ما أردت إعادتها. قراءة مباركة.',
        ),
      ];

  @override
  void initState() {
    super.initState();
    widget.tour.steps = _steps();
  }

  @override
  Widget build(BuildContext context) {
    return SpotlightTour(
      controller: widget.tour,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('النساء'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              key: k.pageView,
              child: PageView(
                controller: widget.pageController,
                children: [
                  _mushafPage(pageOneText, k.pageText),
                  _mushafPage(pageTwoText, null),
                ],
              ),
            ),
            Container(
              key: k.quickBar,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1815),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.mic_none, color: Color(0xFFB08E3F)),
                  Icon(Icons.bookmark_border, color: Color(0x99FFFFFF)),
                  Icon(Icons.copy_outlined, color: Color(0x99FFFFFF)),
                  Icon(Icons.share_outlined, color: Color(0x99FFFFFF)),
                  Icon(Icons.play_arrow, color: Color(0xFFB08E3F), size: 30),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          key: k.nav,
          backgroundColor: const Color(0xFF161411),
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), label: 'المصحف'),
            NavigationDestination(
                icon: Icon(Icons.headphones_outlined), label: 'القراء'),
            NavigationDestination(
                icon: Icon(Icons.bookmark_border), label: 'المحفوظات'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  Widget _mushafPage(String text, GlobalKey? textKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onLongPress: () => unawaited(_openVerseOptions()),
        child: Text(
          text,
          key: textKey,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 21,
            height: 2.0,
            color: Color(0xFFE8E2D5),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadFonts);

  Future<void> settle(WidgetTester tester,
      [int frames = 14, int stepMs = 100]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(Duration(milliseconds: stepMs));
    }
  }

  testWidgets('interactive tour goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final keys = DemoKeys();
    final pageController = PageController();
    addTearDown(pageController.dispose);
    final tour = SpotlightTourController();
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pump();

    tour.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300)); // pulse mid-cycle
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_intro.png'));

    // To the swipe-teaching step: it demonstrates the swipe by itself —
    // the page slides rightward and comes back, no user gesture required.
    final startPixels = pageController.position.pixels;
    await tester.tap(find.text('ابدأ الجولة'));
    await tester.pump();
    // Mid-entrance: the staggered card content is still fading in (title
    // visible, description and buttons on their way). The extra pump lets
    // the async transition pipeline start the entrance animation.
    await tester.pump(const Duration(milliseconds: 220)); // card exit ends
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170)); // mid entrance
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_stagger.png'));

    // The automatic demonstration really turns the page rightward: a full
    // page turn out and back. Capture it mid-turn: the page content is
    // visibly displaced by the slide.
    var moved = 0.0;
    for (var i = 0; i < 80; i++) {
      moved = pageController.position.pixels - startPixels;
      if (moved > 60) break;
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(moved, greaterThan(60),
        reason: 'the auto demonstration should visibly slide the page');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_swipe_demo.png'));

    // The swipe indicator demonstrates the gesture itself: an orb gliding
    // from the left edge of the page to the right. Capture it at two
    // deterministic points of its cycle; the orb must visibly move right.
    double? swipeProgress() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SwipePainter>()
        .map((p) => p.syncFraction ?? p.progress)
        .firstOrNull;
    Future<void> pumpUntilSwipeIn(double lo, double hi) async {
      for (var i = 0; i < 60; i++) {
        final p = swipeProgress();
        if (p != null && p >= lo && p <= hi) return;
        await tester.pump(const Duration(milliseconds: 40));
      }
      fail('swipe indicator never entered cycle range $lo..$hi');
    }

    await pumpUntilSwipeIn(0.30, 0.42); // orb around a third of the way
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_swipe.png'));
    await pumpUntilSwipeIn(0.68, 0.80); // orb past two thirds, moving right
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_swipe_move.png'));

    // The turn is FULL: the page really flips to the next page, holds, and
    // turns back. Watch the whole cycle.
    var sawFullTurn = false;
    for (var i = 0; i < 40; i++) {
      if (pageController.page!.round() == 1) sawFullTurn = true;
      await tester.pump(const Duration(milliseconds: 100));
      if (sawFullTurn &&
          (pageController.position.pixels - startPixels).abs() < 0.01) {
        break; // fully returned to the user's exact spot
      }
    }
    expect(sawFullTurn, isTrue,
        reason: 'the demonstration must turn a FULL page, not a partial slide');

    // The demonstration has ended: the page is back EXACTLY where the user
    // left it (page 0, offset 0 — but the mechanism restores any page, see
    // the PageSwipeDemo widget tests with a non-zero starting page).
    expect(pageController.page!.round(), 0);
    expect(pageController.position.pixels,
        moreOrLessEquals(startPixels, epsilon: 0.001));

    // Next: the verse contour step. The highlight glides from the whole
    // PageView to the verse's text-lines contour, morphing line by line.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    // Wait deterministically for the glide to be in flight: clearly smaller
    // than the whole page, clearly larger than the landed verse contour.
    Rect spotBounds() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first
        .targetPath!
        .getBounds();
    var sb = spotBounds();
    for (var i = 0; i < 60 && (sb.height > 420 || sb.height < 180); i++) {
      await tester.pump(const Duration(milliseconds: 40));
      sb = spotBounds();
    }
    expect(sb.height, inInclusiveRange(180, 420));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_contour_morph.png'));
    await tester.pump(const Duration(milliseconds: 150));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_contour_land.png'));
    await settle(tester, 18);
    expect(find.text('خيارات الآية'), findsOneWidget);
    // The settled contour must sit exactly on the verse's final position.
    final spotPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    final settledBounds = spotPainter.targetPath!.getBounds();
    final versePara =
        keys.pageText.currentContext!.findRenderObject()! as RenderParagraph;
    final verseOrigin = versePara.localToGlobal(Offset.zero);
    final range = secondVerseOfPageOne();
    final verseBoxes = versePara.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end));
    var expLeft = double.infinity, expRight = double.negativeInfinity;
    for (final b in verseBoxes) {
      expLeft = expLeft < b.left + verseOrigin.dx ? expLeft : b.left + verseOrigin.dx;
      expRight =
          expRight > b.right + verseOrigin.dx ? expRight : b.right + verseOrigin.dx;
    }
    expect(settledBounds.left, moreOrLessEquals(expLeft - 8, epsilon: 2));
    expect(settledBounds.right, moreOrLessEquals(expRight + 8, epsilon: 2));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_verse.png'));

    // Pressing Next performs the app's real action: the verse-options sheet
    // opens, the tour rises above it and highlights التفسير inside it.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('المشاركة'), findsOneWidget); // the sheet is really open
    expect(find.text('التفسير'), findsNWidgets(2)); // sheet item + card title
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_sheet.png'));

    // Next closes the sheet (the step's onNext) and continues on the page.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('المشاركة'), findsNothing); // sheet was really closed
    expect(find.text('الأزرار السريعة'), findsOneWidget);

    // REGRESSION — the reported bug: going BACK to the sheet's step must
    // re-run its setup, not just show the description. Previous reopens the
    // verse-options sheet and the spotlight lands on التفسير inside it.
    await tester.tap(find.text('السابق'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('التفسير'), findsNWidgets(2),
        reason: 'returning to the step must reopen the verse-options sheet');
    expect(find.text('المشاركة'), findsOneWidget);
    final tafsirBox =
        keys.tafsir.currentContext!.findRenderObject()! as RenderBox;
    final tafsirCenter =
        tafsirBox.localToGlobal(tafsirBox.size.center(Offset.zero));
    final reopenedPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    expect(reopenedPainter.targetPath!.contains(tafsirCenter), isTrue,
        reason: 'the spotlight must land on the sheet content again');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_sheet_reopen.png'));

    // Going back once more leaves the sheet step: its onExit closes the
    // sheet, so the verse step shows the page as it was.
    await tester.tap(find.text('السابق'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('المشاركة'), findsNothing);
    expect(find.text('خيارات الآية'), findsOneWidget);

    // Forward again: the sheet reopens (verse step's onNext), the tafsir
    // step's idempotent onEnter does not double-push it, and Next closes it.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('المشاركة'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester, 18);
    expect(find.text('المشاركة'), findsNothing);
    expect(find.text('الأزرار السريعة'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester);
    expect(find.text('أقسام التطبيق'), findsOneWidget);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_bottom.png'));

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await settle(tester);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_done.png'));
  });

  testWidgets('central host goldens: one tour crossing routes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final keys = CentralKeys();
    final tour = SpotlightTourController();
    await tester.pumpWidget(CentralDemoApp(keys: keys, tour: tour));
    await tester.pump();

    tour.start(steps: centralSteps(keys, CentralMushafPage(keys: keys)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_host_intro.png'));

    // Verse contour on page A, through the central host.
    await tester.tap(find.text('ابدأ الجولة'));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_host_verse.png'));

    // To the bottom-bar step, then the tour pushes the settings route
    // itself and highlights there — same controller, same run, another
    // route entirely.
    await tester.tap(find.text('التالي'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('التالي'));
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('المظهر الداكن'), findsOneWidget);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_host_settings.png'));

    tour.skip();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('contour joins golden: varied widths, heights, mixed direction',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Worst case for line joins: a partial first line, a taller middle
    // line (larger span), an embedded LTR number run, and a short last
    // line anchored right.
    const fullText =
        'سابق غير محدد وَاللَّهُ لَا إِلَٰهَ هُوَ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ '
        'الْقِيَامَةِ لَا رَيْبَ فِيهِ رقم ٨٧٤٢ وسط السطر وَمَنْ أَصْدَقُ '
        'مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ لاحق غير محدد';
    final textKey = GlobalKey();
    const range = TextRange(start: 14, end: fullText.length - 14);
    final controller = SpotlightTourController(steps: [
      TourStep(
        targetKey: textKey,
        shape: TourTargetShape.textLines,
        textRange: range,
        title: 'وصلات الإطار',
        description: 'سطور مختلفة العرض والارتفاع مع أرقام',
        showPulse: false,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF100E0C),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTour(
          controller: controller,
          child: Scaffold(
            backgroundColor: const Color(0xFF161411),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text.rich(
                key: textKey,
                textDirection: TextDirection.rtl,
                TextSpan(
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 20,
                      height: 1.9,
                      color: Color(0xFFE8E2D5)),
                  children: [
                    TextSpan(text: fullText.substring(0, 60)),
                    TextSpan(
                        text: fullText.substring(60, 74),
                        style: const TextStyle(fontSize: 30)),
                    TextSpan(text: fullText.substring(74)),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      )));
    controller.start();
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SpotlightPainter>()
        .first;
    // The whole outline is a single closed contour.
    expect(painter.targetPath!.computeMetrics().length, 1);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_contour_joins.png'));
  });
}
