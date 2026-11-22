import 'package:flutter/material.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF100E0C),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MushafDemoScreen(),
      ),
    );
  }
}

/// نص الصفحة المتدفق: آيتان متتابعتان في سياق واحد، لعرض إبراز نطاق نصي.
const String pageText =
    'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا ۗ إِنَّ اللَّهَ كَانَ عَلَىٰ كُلِّ شَيْءٍ حَسِيبًا ﴿٨٦﴾ '
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾';

/// نطاق الآية الثانية داخل النص المتدفق (تبدأ منتصف سطر وتنتهي منتصف سطر).
TextRange secondVerseRange() {
  final start = pageText.indexOf('وَاللَّهُ');
  final marker = '﴿٨٧﴾';
  final end = pageText.indexOf(marker) + marker.length;
  return TextRange(start: start, end: end);
}

/// A small Quran-reader-like screen used to demonstrate the tour.
class MushafDemoScreen extends StatefulWidget {
  const MushafDemoScreen({super.key});

  @override
  State<MushafDemoScreen> createState() => _MushafDemoScreenState();
}

class _MushafDemoScreenState extends State<MushafDemoScreen> {
  final _pageKey = GlobalKey();
  final _pageTextKey = GlobalKey();
  final _verseKey = GlobalKey();
  final _quickBarKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _micKey = GlobalKey();
  final _navKey = GlobalKey();

  late final SpotlightTourController _tour;

  @override
  void initState() {
    super.initState();
    _tour = SpotlightTourController(steps: _buildSteps());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tour.start());
  }

  @override
  void dispose() {
    _tour.dispose();
    super.dispose();
  }

  List<TourStep> _buildSteps() => [
        const TourStep(
          title: 'جولة في التطبيق',
          description:
              'جولة قصيرة نتعرف فيها على أهم أجزاء الشاشة وكيفية استخدامها.',
        ),
        TourStep(
          targetKey: _pageKey,
          title: 'كبّر الصفحة',
          description:
              'باعد بين إصبعيك على الصفحة، أو قرّب الإصبعين، لتكبير النص وتصغيره.',
          icon: Icons.zoom_in,
        ),
        TourStep(
          targetKey: _pageTextKey,
          shape: TourTargetShape.textLines,
          textRange: secondVerseRange(),
          title: 'اضغط مطولاً على أي آية',
          description:
              'يفتح درجاً فيه التفسير والترجمة والاستماع، دون أن تغادر الصفحة.',
          icon: Icons.touch_app_outlined,
        ),
        TourStep(
          targetKey: _verseKey,
          title: 'بطاقة الآية',
          description: 'هذا إطار عادي حول ويدجت كامل، للمقارنة مع إطار النص.',
          icon: Icons.crop_free,
        ),
        TourStep(
          targetKey: _quickBarKey,
          title: 'الأزرار السريعة',
          description:
              'شغّل التلاوة من هذه الآية، وشاركها نصاً أو صورة، وانسخها واحفظها.',
          icon: Icons.flash_on_outlined,
        ),
        TourStep(
          targetKey: _searchKey,
          title: 'ابحث',
          description: 'اكتب كلمة من الآية، أو اسم السورة، وانتقل إليها بلمسة.',
          icon: Icons.search,
        ),
        TourStep(
          targetKey: _micKey,
          title: 'سمّع حفظك',
          description:
              'تخفى الآية، فاضغط الميكروفون وابدأ التسميع. يظهر حين تحتاج المراجعة.',
          icon: Icons.mic_none,
          shape: TourTargetShape.circle,
        ),
        TourStep(
          targetKey: _navKey,
          title: 'أقسام التطبيق',
          description: 'المحفوظات والقراءة والإعدادات، كلها من الشريط السفلي.',
          icon: Icons.menu_book_outlined,
        ),
        const TourStep(
          title: 'هذا كل شيء',
          description: 'تجد هذه الجولة في الإعدادات متى ما أردت إعادتها.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return SpotlightTour(
      controller: _tour,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('النساء'),
          actions: [
            IconButton(
              key: _searchKey,
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              key: _pageKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    pageText,
                    key: _pageTextKey,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 22,
                      height: 2.1,
                      color: Color(0xFFE8E2D5),
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ),
            Container(
              key: _verseKey,
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
                    fontSize: 20,
                    height: 1.9,
                    color: Color(0xFFE8E2D5)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: _quickBarKey,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1815),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.mic_none,
                      key: _micKey, color: const Color(0xFFB08E3F)),
                  const Icon(Icons.bookmark_border, color: Color(0x99FFFFFF)),
                  const Icon(Icons.copy_outlined, color: Color(0x99FFFFFF)),
                  const Icon(Icons.share_outlined, color: Color(0x99FFFFFF)),
                  const Icon(Icons.play_arrow,
                      color: Color(0xFFB08E3F), size: 30),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          key: _navKey,
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
        floatingActionButton: FloatingActionButton.small(
          onPressed: () => _tour.start(),
          child: const Icon(Icons.replay),
        ),
      ),
    );
  }
}
