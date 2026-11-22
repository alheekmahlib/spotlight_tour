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

/// نص الصفحة المتدفق المشترك بين الشاشة والخطوات.
const String pageText =
    'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا ۗ إِنَّ اللَّهَ كَانَ عَلَىٰ كُلِّ شَيْءٍ حَسِيبًا ﴿٨٦﴾ '
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾';

TextRange secondVerseRange() {
  final start = pageText.indexOf('وَاللَّهُ');
  const marker = '﴿٨٧﴾';
  final end = pageText.indexOf(marker) + marker.length;
  return TextRange(start: start, end: end);
}

class DemoKeys {
  final page = GlobalKey();
  final pageText = GlobalKey();
  final verse = GlobalKey();
  final quickBar = GlobalKey();
  final mic = GlobalKey();
  final nav = GlobalKey();
}

List<TourStep> demoSteps(DemoKeys k) => [
      const TourStep(
        title: 'جولة في التطبيق',
        description:
            'جولة قصيرة نتعرف فيها على أهم أجزاء الشاشة وكيفية استخدامها بسرعة.',
      ),
      TourStep(
        targetKey: k.pageText,
        shape: TourTargetShape.textLines,
        textRange: secondVerseRange(),
        title: 'اضغط مطولاً على أي آية',
        description:
            'يفتح درجاً فيه التفسير والإعراب وأسباب النزول والاستماع، دون أن تغادر الصفحة.',
        icon: Icons.touch_app_outlined,
      ),
      TourStep(
        targetKey: k.verse,
        title: 'بطاقة الآية',
        description: 'هذا إطار عادي حول ويدجت كامل، للمقارنة مع إطار النص.',
        icon: Icons.crop_free,
      ),
      TourStep(
        targetKey: k.quickBar,
        title: 'الأزرار السريعة',
        description:
            'شغّل التلاوة من هذه الآية، وشاركها نصاً أو صورة، وانسخها واحفظها في المحفوظات.',
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
        description: 'تجد هذه الجولة في الإعدادات متى ما أردت إعادتها. قراءة مباركة.',
      ),
    ];

Widget demoScreen(DemoKeys k, SpotlightTourController tour) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF100E0C),
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: SpotlightTour(
        controller: tour,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('النساء'),
            actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
          ),
          body: Column(
            children: [
              Expanded(
                key: k.page,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    pageText,
                    key: k.pageText,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 21,
                      height: 2.0,
                      color: Color(0xFFE8E2D5),
                    ),
                  ),
                ),
              ),
              Container(
                key: k.verse,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x33B08E3F)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'فَمَا لَكُمْ فِي الْمُنَافِقِينَ فِئَتَيْنِ وَاللَّهُ أَرْكَسَهُم بِمَا كَسَبُوا ﴿٨٨﴾',
                  style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 19,
                      height: 1.9,
                      color: Color(0xFFE8E2D5)),
                ),
              ),
              const SizedBox(height: 14),
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
      ),
    ),
  );
}

void main() {
  setUpAll(loadFonts);

  Future<void> settleTransitions(WidgetTester tester) async {
    // Small pumps so the staggered exit -> morph -> enter animations each
    // start and complete in their own frames, like real time would.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> advance(WidgetTester tester, String label, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text(label));
      await tester.pump();
      await settleTransitions(tester);
      label = 'التالي';
    }
  }

  testWidgets('tour goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final keys = DemoKeys();
    final tour = SpotlightTourController(steps: demoSteps(keys));
    await tester.pumpWidget(demoScreen(keys, tour));
    await tester.pump();

    tour.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300)); // pulse mid-cycle
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_intro.png'));

    await advance(tester, 'ابدأ الجولة', 1); // verse range inside flowing text
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_text.png'));

    await advance(tester, 'التالي', 1); // boxed verse widget, rounded rect
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_step.png'));

    await advance(tester, 'التالي', 2); // bottom nav step, card above target
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_bottom.png'));

    await advance(tester, 'التالي', 1); // closing step, centered
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tour_done.png'));
  });
}
