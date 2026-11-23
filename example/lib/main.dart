import 'dart:async';

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

/// نص الصفحة الأولى.
const String pageOneText =
    'وَإِذَا حُيِّيتُم بِتَحِيَّةٍ فَحَيُّوا بِأَحْسَنَ مِنْهَا أَوْ رُدُّوهَا ۗ '
    'إِنَّ اللَّهَ كَانَ عَلَىٰ كُلِّ شَيْءٍ حَسِيبًا ﴿٨٦﴾ '
    'يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَتَّبِعُوا خُطُوَاتِ الشَّيْطَانِ ۚ '
    'وَمَن يَتَّبِعْ خُطُوَاتِهِ فَإِنَّهُ يَأْمُرُ بِالْفَحْشَاءِ وَالْمُنكَرِ ﴿٢١﴾';

/// نص الصفحة الثانية: آيتان متتابعتان في سياق واحد، لعرض إبراز نطاق نصي.
const String pageTwoText =
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ '
    'فَمَا لَكُمْ فِي الْمُنَافِقِينَ فِئَتَيْنِ وَاللَّهُ أَرْكَسَهُم بِمَا كَسَبُوا ۚ أَتُرِيدُونَ أَن تَهْدُوا مَنْ أَضَلَّ اللَّهُ ﴿٨٨﴾';

/// نطاق الآية الأولى من الصفحة الثانية (تبدأ منتصف سطر وتنتهي منتصف سطر).
TextRange firstVerseOfPageTwo() {
  const marker = '﴿٨٧﴾';
  final end = pageTwoText.indexOf(marker) + marker.length;
  return TextRange(start: 0, end: end);
}

/// A small Quran-reader-like screen demonstrating an *interactive* tour:
/// the tour turns real pages, opens the real verse-options sheet and waits
/// for real user gestures — not just explanations floating above the screen.
class MushafDemoScreen extends StatefulWidget {
  const MushafDemoScreen({super.key});

  @override
  State<MushafDemoScreen> createState() => _MushafDemoScreenState();
}

class _MushafDemoScreenState extends State<MushafDemoScreen> {
  final _pageViewKey = GlobalKey();
  final _pageTextKey = GlobalKey();
  final _tafsirKey = GlobalKey();
  final _quickBarKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _navKey = GlobalKey();

  final _pageController = PageController();
  bool _verseOptionsOpen = false;

  /// يتذكّر أن الجولة عُرضت حتى لا تبدأ تلقائياً في كل مرة.
  ///
  /// هذا المخزن يعيش في الذاكرة فقط؛ في تطبيق حقيقي استبدله بمخزن دائم
  /// فوق `get_storage` أو `shared_preferences` كما في توثيق
  /// [TourCompletionStore] — الواجهة ثلاث دوال فقط.
  final _tourStore = InMemoryTourCompletionStore();

  late final SpotlightTourController _tour;

  /// رقم خطوة تعليم السحب داخل قائمة الخطوات.
  static const _swipeStepIndex = 1;

  @override
  void initState() {
    super.initState();
    _tour = SpotlightTourController(
      steps: _buildSteps(),
      // معرّف ثابت لجولة هذا القسم: لكل قسم في التطبيق معرّفه وجولته.
      tourId: 'mushaf',
      completionStore: _tourStore,
    )
      // إن تخطّى المستخدم الجولة أو أنهاها بينما النافذة مفتوحة، أغلقها.
      ..onSkip = _closeVerseOptions
      ..onFinish = _closeVerseOptions;
    // تبدأ تلقائياً أول مرة فقط؛ زر الإعادة في الأعلى يستدعي start() مباشرة.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tour.startOnce());
  }

  /// زر «أعد الجولة»: يمسح علامة الإكمال ثم يبدأ الجولة فوراً.
  Future<void> _replayTour() async {
    await _tourStore.reset('mushaf');
    _tour.start();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tour.dispose();
    super.dispose();
  }

  /// نفس الدالة التي يستدعيها الضغط المطوّل الحقيقي على الآية.
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
                key: _tafsirKey,
                leading: const Icon(Icons.menu_book_outlined,
                    color: Color(0xFFB08E3F)),
                title: const Text('التفسير',
                    style: TextStyle(color: Color(0xFFE8E2D5))),
                subtitle: const Text('ابن كثير والطبري',
                    style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
                onTap: () {},
              ),
              const ListTile(
                leading:
                    Icon(Icons.share_outlined, color: Color(0x99FFFFFF)),
                title: Text('المشاركة',
                    style: TextStyle(color: Color(0xFFE8E2D5))),
              ),
              const ListTile(
                leading: Icon(Icons.headphones_outlined,
                    color: Color(0x99FFFFFF)),
                title: Text('استماع',
                    style: TextStyle(color: Color(0xFFE8E2D5))),
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

  List<TourStep> _buildSteps() => [
        const TourStep(
          title: 'جولة تفاعلية',
          description:
              'هذه الجولة لا تشرح فقط، بل تنفّذ معك: ستقلب الصفحة بنفسك، وستفتح الجولة خيارات الآية الحقيقية لتشرحها لك.',
        ),
        // خطوة تفاعلية: اللمس يمر عبر التعتيم إلى المصحف نفسه، ولا «التالي»
        // هنا — تتقدم الجولة عندما يسحب المستخدم الصفحة فعلاً.
        TourStep(
          targetKey: _pageViewKey,
          title: 'قلّب الصفحات',
          description:
              'يمكنك التنقل بين صفحات المصحف بالسحب يميناً أو يساراً. جرّب الآن: اسحب الصفحة لتنتقل الجولة معك.',
          icon: Icons.swipe_outlined,
          interaction: TourTargetInteraction.swipe,
          requireInteraction: true,
          interactionHint: 'اسحب الصفحة للمتابعة',
        ),
        // ضغط «التالي» هنا ينفّذ نفس دالة الضغط المطوّل في التطبيق، فتفتح
        // خيارات الآية الحقيقية، ثم تكمل الجولة الشرح عليها.
        TourStep(
          targetKey: _pageTextKey,
          shape: TourTargetShape.textLines,
          textRange: firstVerseOfPageTwo(),
          title: 'خيارات الآية',
          description:
              'الضغط المطوّل على أي آية يفتح خياراتها: التفسير والمشاركة والاستماع. اضغط «التالي» وسنفتحها لك الآن.',
          icon: Icons.touch_app_outlined,
          // مهم: لا نعيد Future الخاص بالنافذة نفسها (يكتمل عند إغلاقها)، بل
          // نشغّل الفتح فقط، وتنتظر الجولة ظهور الهدف التالي تلقائياً.
          onNext: () => unawaited(_openVerseOptions()),
        ),
        // هدف داخل النافذة المنبثقة: ترتفع الجولة فوقها تلقائياً وتبرز
        // «التفسير». ضغط «التالي» يغلق النافذة قبل متابعة الجولة.
        TourStep(
          targetKey: _tafsirKey,
          title: 'التفسير',
          description:
              'من هذه القائمة تفتح التفسير مباشرة. اضغط «التالي» لنغلق القائمة ونكمل الجولة.',
          icon: Icons.menu_book_outlined,
          onNext: _closeVerseOptions,
        ),
        TourStep(
          targetKey: _quickBarKey,
          title: 'الأزرار السريعة',
          description:
              'شغّل التلاوة من هذه الآية، وشاركها نصاً أو صورة، وانسخها واحفظها.',
          icon: Icons.flash_on_outlined,
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

  /// عندما يقلب المستخدم الصفحة فعلاً أثناء خطوة تعليم السحب، تتقدم الجولة.
  void _onPageChanged(int page) {
    if (_tour.status == TourStatus.running &&
        _tour.index == _swipeStepIndex &&
        page == 1) {
      _tour.next();
    }
  }

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
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: 'إعادة الجولة',
              onPressed: _replayTour,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              key: _pageViewKey,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _mushafPage(pageOneText, null),
                  _mushafPage(pageTwoText, _pageTextKey),
                ],
              ),
            ),
            Container(
              key: _quickBarKey,
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
          onPressed: () {
            _closeVerseOptions();
            _tour.start();
          },
          child: const Icon(Icons.replay),
        ),
      ),
    );
  }

  Widget _mushafPage(String text, GlobalKey? textKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: GestureDetector(
          // الضغط المطوّل الحقيقي في التطبيق: نفس الدالة التي تستدعيها الجولة.
          onLongPress: () => unawaited(_openVerseOptions()),
          child: Text(
            text,
            key: textKey,
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
    );
  }
}
