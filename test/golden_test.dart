import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

Future<void> loadFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.view(File(path).readAsBytesSync().buffer);
  final naskh = FontLoader('NotoNaskh')
    ..addFont(read('test/assets/NotoNaskhArabic-Regular.ttf'))
    ..addFont(read('test/assets/NotoNaskhArabic-SemiBold.ttf'))
    ..addFont(read('test/assets/NotoNaskhArabic-Bold.ttf'));
  final amiri = FontLoader('Amiri')
    ..addFont(read('test/assets/Amiri-Regular.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(read(
        '/tmp/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await naskh.load();
  await amiri.load();
  await icons.load();
}

/// نص الصفحة الأولى.
const String pageOneText =
    'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا ۗ '
    'إِنَّ اللَّهَ كَانَ عَلَىٰ كُلِّ شَيْءٍ حَسِيبًا ﴿٨٦﴾ '
    'يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَتَّبِعُوا خُطُوَاتِ الشَّيْطَانِ ۚ '
    'وَمَن يَتَّبِعْ خُطُوَاتِهِ فَإِنَّهُ يَأْمُرُ بِالْفَحْشَاءِ وَالْمُنكَرِ ﴿٢١﴾';

/// نص الصفحة الثانية المتدفق: آيتان متتابعتان في سياق واحد.
const String pageTwoText =
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ '
    'فَمَا لَكُمْ فِي الْمُنَافِقِينَ فِئَتَيْنِ وَاللَّهُ أَرْكَسَهُم بِمَا كَسَبُوا ۚ أَتُرِيدُونَ أَن تَهْدُوا مَنْ أَضَلَّ اللَّهُ ﴿٨٨﴾';

TextRange firstVerseOfPageTwo() {
  const marker = '﴿٨٧﴾';
  final end = pageTwoText.indexOf(marker) + marker.length;
  return TextRange(start: 0, end: end);
}

class DemoKeys {
  final pageView = GlobalKey();
  final pageText = GlobalKey();
  final tafsir = GlobalKey();
  final quickBar = GlobalKey();
  final nav = GlobalKey();
}

/// شاشة العرض نفسها المستخدمة في مثال الحزمة: صفحتان بقلب حقيقي، ونافذة
/// خيارات آية حقيقية تفتحها الجولة ثم تشرح عناصرها.
class GoldenDemoScreen extends StatefulWidget {
  const GoldenDemoScreen({super.key, required this.keys, required this.tour});

  final DemoKeys keys;
  final SpotlightTourController tour;

  static const swipeStepIndex = 1;

  @override
  State<GoldenDemoScreen> createState() => _GoldenDemoScreenState();
}

class _GoldenDemoScreenState extends State<GoldenDemoScreen> {
  bool _verseOptionsOpen = false;

  DemoKeys get k => widget.keys;

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

  List<TourStep> _steps() => [
        const TourStep(
          title: 'جولة تفاعلية',
          description:
              'هذه الجولة لا تشرح فقط، بل تنفّذ معك: ستقلب الصفحة بنفسك، وستفتح الجولة خيارات الآية الحقيقية لتشرحها لك.',
        ),
        TourStep(
          targetKey: k.pageView,
          title: 'قلّب الصفحات',
          description:
              'يمكنك التنقل بين صفحات المصحف بالسحب يميناً أو يساراً. جرّب الآن: اسحب الصفحة لتنتقل الجولة معك.',
          icon: Icons.swipe_outlined,
          interaction: TourTargetInteraction.swipe,
          requireInteraction: true,
          interactionHint: 'اسحب الصفحة للمتابعة',
        ),
        TourStep(
          targetKey: k.pageText,
          shape: TourTargetShape.textLines,
          textRange: firstVerseOfPageTwo(),
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
          onNext: _closeVerseOptions,
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

  void _onPageChanged(int page) {
    if (widget.tour.status == TourStatus.running &&
        widget.tour.index == GoldenDemoScreen.swipeStepIndex &&
        page == 1) {
      widget.tour.next();
    }
  }

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
                onPageChanged: _onPageChanged,
                children: [
                  _mushafPage(pageOneText, null),
                  _mushafPage(pageTwoText, k.pageText),
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
    final tour = SpotlightTourController();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF100E0C),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: GoldenDemoScreen(keys: keys, tour: tour),
      ),
    ));
    await tester.pump();

    tour.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300)); // pulse mid-cycle
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_intro.png'));

    // To the swipe-teaching step: no Next button, a hint pill instead.
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
    await settle(tester);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_swipe.png'));

    // A REAL drag inside the spotlight passes through the backdrop to the
    // PageView: the page turns and the app's onPageChanged advances the tour.
    await tester.drag(find.byKey(keys.pageView), const Offset(320, 0)); // RTL: content moves with the finger toward the right to reveal page 2
    await tester.pump();
    // Mid-morph: the highlight glides from the PageView rect to the verse's
    // text-lines contour, cross-fading the border between the two shapes.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/tour_contour_morph.png'));
    await settle(tester, 18);
    expect(find.text('خيارات الآية'), findsOneWidget);
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
}
