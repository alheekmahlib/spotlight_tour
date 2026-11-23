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
    'وَمَن يَتَّبِعُ خُطُوَاتِهِ فَإِنَّهُ يَأْمُرُ بِالْفَحْشَاءِ وَالْمُنكَرِ ﴿٢١﴾';

/// نص الصفحة الثانية.
const String pageTwoText =
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعَنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ '
    'فَمَا لَكُمْ فِي الْمُنَافِقِينَ فِئَتَيْنِ وَاللَّهُ أَرْكَسَهُم بِمَا كَسَبُوا ۚ أَتُرِيدُونَ أَن تَهْدُوا مَنْ أَضَلَّ اللَّهُ ﴿٨٨﴾';

/// نطاق الآية الثانية من الصفحة الأولى (تبدأ منتصف سطر وتنتهي منتصف سطر):
/// تُبرز على الصفحة التي يقف عليها المستخدم نفسها، فلا تحتاج الجولة إلى
/// تغيير صفحته ليظهر التحديد.
TextRange secondVerseOfPageOne() {
  const startMarker = 'يَا أَيُّهَا';
  const endMarker = '﴿٢١﴾';
  final start = pageOneText.indexOf(startMarker);
  final end = pageOneText.indexOf(endMarker) + endMarker.length;
  return TextRange(start: start, end: end);
}

/// A small Quran-reader-like screen demonstrating an *interactive* tour:
/// the tour demonstrates the page swipe by itself, opens the real
/// verse-options sheet and highlights inside it — and going BACK to a step
/// restores exactly the UI that step needs.
class MushafDemoScreen extends StatefulWidget {
  const MushafDemoScreen({super.key});

  @override
  State<MushafDemoScreen> createState() => _MushafDemoScreenState();
}

class _MushafDemoScreenState extends State<MushafDemoScreen>
    with TickerProviderStateMixin {
  final _pageViewKey = GlobalKey();
  final _pageTextKey = GlobalKey();
  final _tafsirKey = GlobalKey();
  final _quickBarKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _navKey = GlobalKey();

  final _pageController = PageController();

  /// عرض قلب الصفحة التلقائي: يحرّك الصفحة يميناً ثم يعيدها إلى موضعها
  /// بالضبط، فلا تتغير الصفحة التي يقف عليها المستخدم.
  late final _swipeDemo = PageSwipeDemo(
    pageController: _pageController,
    vsync: this,
  );

  bool _verseOptionsOpen = false;

  /// يتذكّر أن الجولة عُرضت حتى لا تبدأ تلقائياً في كل مرة.
  ///
  /// هذا المخزن يعيش في الذاكرة فقط؛ في تطبيق حقيقي استبدله بمخزن دائم
  /// فوق `get_storage` أو `shared_preferences` كما في توثيق
  /// [TourCompletionStore] — الواجهة ثلاث دوال فقط.
  final _tourStore = InMemoryTourCompletionStore();

  late final SpotlightTourController _tour;

  @override
  void initState() {
    super.initState();
    _tour = SpotlightTourController(
      steps: _buildSteps(),
      // معرّف ثابت لجولة هذا القسم: لكل قسم في التطبيق معرّفه وجولته.
      tourId: 'mushaf',
      completionStore: _tourStore,
    );
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
    _swipeDemo.dispose();
    _pageController.dispose();
    _tour.dispose();
    super.dispose();
  }

  /// نفس الدالة التي يستدعيها الضغط المطوّل الحقيقي على الآية.
  ///
  /// آمنة التكرار: إن كانت القائمة مفتوحة لا تفعل شيئاً، وهذا ما يجعل
  /// استدعاءها في `onEnter` صحيحاً في الاتجاهين.
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

  /// يحرّك الصفحة يميناً ثم يعيدها تلقائياً، دون أن يتغير موضع المستخدم.
  ///
  /// بنفس قاعدة النبضة: لا حركة تلقائية إطلاقاً مع «تقليل الحركة»، ويكفي
  /// حينها وصف الخطوة نفسه.
  void _demonstrateSwipe() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    unawaited(_swipeDemo.demonstrate(TourSwipeDirection.leftToRight));
  }

  List<TourStep> _buildSteps() => [
        const TourStep(
          title: 'جولة تفاعلية',
          description:
              'هذه الجولة لا تشرح فقط، بل تنفّذ معك: سترى كيف تُقلب الصفحة، وستفتح الجولة خيارات الآية الحقيقية لتشرحها لك.',
        ),
        // خطوة تعليم قلب الصفحة: بدل أن نطلب من المستخدم أن يسحب بنفسه،
        // تحرّك الجولة الصفحةَ يميناً ثم تُعيدها إلى موضعها بالضبط، وتبقى
        // صفحته كما هي. (الطريقة القديمة — تمرير السحبة الحقيقية وانتظارها
        // عبر interaction + requireInteraction — ما زالت متاحة لمن أرادها.)
        TourStep(
          targetKey: _pageViewKey,
          title: 'قلّب الصفحات',
          description:
              'يمكنك التنقل بين صفحات المصحف بالسحب يميناً أو يساراً، كما تتحرك الصفحة الآن أمامك ثم تعود إلى مكانها.',
          icon: Icons.swipe_outlined,
          // المؤشّر يتحرّك من اليسار إلى اليمين ليعلّم سحبة قلب الصفحة.
          indicator: TourIndicator.swipeLeftToRight,
          onEnter: _demonstrateSwipe,
          // إن غادر المستخدم الخطوة (أو تخطّى الجولة) أثناء العرض، تُلغى
          // الحركة فوراً وتعود الصفحة إلى موضعها.
          onExit: _swipeDemo.cancel,
        ),
        // ضغط «التالي» هنا ينفّذ نفس دالة الضغط المطوّل في التطبيق، فتفتح
        // خيارات الآية الحقيقية، ثم تكمل الجولة الشرح عليها.
        TourStep(
          targetKey: _pageTextKey,
          shape: TourTargetShape.textLines,
          textRange: secondVerseOfPageOne(),
          title: 'خيارات الآية',
          description:
              'الضغط المطوّل على أي آية يفتح خياراتها: التفسير والمشاركة والاستماع. اضغط «التالي» وسنفتحها لك الآن.',
          icon: Icons.touch_app_outlined,
          // مهم: لا نعيد Future الخاص بالنافذة نفسها (يكتمل عند إغلاقها)، بل
          // نشغّل الفتح فقط، وتنتظر الجولة ظهور الهدف التالي تلقائياً.
          onNext: () => unawaited(_openVerseOptions()),
        ),
        // هدف داخل النافذة المنبثقة: ترتفع الجولة فوقها تلقائياً وتبرز
        // «التفسير». العودة بـ«السابق» إلى هذه الخطوة تعيد فتح القائمة من
        // جديد، لأن onEnter يعمل في الاتجاهين (ودالة الفتح آمنة التكرار)،
        // وonExit يغلقها عند مغادرة الخطوة في أي اتجاه.
        TourStep(
          targetKey: _tafsirKey,
          title: 'التفسير',
          description:
              'من هذه القائمة تفتح التفسير مباشرة. اضغط «التالي» لنغلق القائمة ونكمل الجولة.',
          icon: Icons.menu_book_outlined,
          onEnter: () => unawaited(_openVerseOptions()),
          onNext: _closeVerseOptions,
          onExit: _closeVerseOptions,
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
                children: [
                  _mushafPage(pageOneText, _pageTextKey),
                  _mushafPage(pageTwoText, null),
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
