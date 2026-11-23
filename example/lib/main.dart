import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

void main() => runApp(const DemoApp());

/// كنترولر واحد لكل التطبيق. في تطبيق حقيقي ضعه في خدمة دائمة (GetX
/// service أو Provider أو متغير عام كما هنا) وعمره عمر التطبيق، فلا تتخلص
/// منه مع أي شاشة.
final appTour = SpotlightTourController();

/// يتذكّر الجولات المكتملة حتى لا تبدأ تلقائياً كل مرة.
///
/// هذا المخزن يعيش في الذاكرة فقط؛ في تطبيق حقيقي استبدله بمخزن دائم فوق
/// `get_storage` أو `shared_preferences` كما في توثيق [TourCompletionStore]
/// — الواجهة ثلاث دوال فقط.
final tourStore = InMemoryTourCompletionStore();

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
      // الاستدعاء المركزي: مضيف واحد فوق الـ Navigator يخدم كل الصفحات.
      // بعده يستطيع أي قسم تشغيل جولته بـ appTour.start(...) من أي مكان.
      builder: (context, child) =>
          SpotlightTourHost(controller: appTour, child: child!),
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
    'وَاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۚ لَيَجْمَعُنَّكُمْ إِلَىٰ يَوْمِ الْقِيَامَةِ لَا رَيْبَ فِيهِ ۗ وَمَنْ أَصْدَقُ مِنَ اللَّهِ حَدِيثًا ﴿٨٧﴾ '
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

/// شاشة المصحف. لاحظ: لا SpotlightTour حولها ولا كنترولر خاص بها — تبني
/// خطواتها فقط وتشغّلها على الكنترولر المركزي، وتنتقل منها إلى صفحة أخرى
/// دون أن يتأثر شيء.
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

  /// عرض قلب الصفحة التلقائي: يقلب الصفحة كاملة يميناً بسرعة واضحة، يتوقف
  /// لحظة، ثم يعيدها إلى موضع المستخدم بالضبط.
  ///
  /// ملاحظة: القلب الكامل يعبر حدود الصفحة، فيطلق PageView ردّ onPageChanged
  /// مرتين (ذهاباً وعودة). إن كان تطبيقك يحدّث حالته من onPageChanged فتجاهل
  /// النداءات أثناء العرض:
  /// `if (_swipeDemo.isRunning) return;`
  late final _swipeDemo = PageSwipeDemo(
    pageController: _pageController,
    vsync: this,
  );

  bool _verseOptionsOpen = false;

  @override
  void initState() {
    super.initState();
    // جولة هذا القسم تبدأ تلقائياً أول مرة فقط، بمعرّفها الخاص على
    // الكنترولر المركزي. زر الإعادة يستدعي start مباشرة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appTour.startOnce(tourId: 'mushaf', steps: _buildSteps());
    });
  }

  /// زر «أعد الجولة»: يمسح علامة الإكمال ثم يبدأ جولة هذا القسم فوراً.
  Future<void> _replayTour() async {
    await tourStore.reset('mushaf');
    appTour.start(tourId: 'mushaf', steps: _buildSteps());
  }

  @override
  void dispose() {
    _swipeDemo.dispose();
    _pageController.dispose();
    // الكنترولر المركزي لا يُتخلَّى عنه هنا: عمره عمر التطبيق.
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
                leading: Icon(Icons.headphones_outlined, color: Color(0x99FFFFFF)),
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

  void _openSettings() {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: SettingsDemoScreen(),
      ),
    )));
  }

  List<TourStep> _buildSteps() => [
        const TourStep(
          title: 'جولة تفاعلية',
          description:
              'هذه الجولة لا تشرح فقط، بل تنفّذ معك: سترى كيف تُقلب الصفحة، وستفتح الجولة خيارات الآية الحقيقية لتشرحها لك.',
        ),
        // خطوة تعليم قلب الصفحة: بدل أن نطلب من المستخدم أن يسحب بنفسه،
        // تقلب الجولة الصفحةَ كاملة يميناً ثم تُعيدها إلى موضعها بالضبط،
        // وتبقى صفحته كما هي. (الطريقة القديمة — تمرير السحبة الحقيقية
        // وانتظارها عبر interaction + requireInteraction — ما زالت متاحة
        // لمن أرادها.)
        TourStep(
          targetKey: _pageViewKey,
          title: 'قلّب الصفحات',
          description:
              'يمكنك التنقل بين صفحات المصحف بالسحب يميناً أو يساراً، كما تقلب الصفحة نفسها الآن أمامك ثم تعود إلى مكانها.',
          icon: Icons.swipe_outlined,
          // المؤشّر يتبع حركة الصفحة نفسها: يميناً مع القلبة ويساراً مع
          // العودة، بدل أن يدور في اتجاه واحد باستمرار.
          indicator: TourIndicator.swipeLeftToRight,
          swipeDemo: _swipeDemo,
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
          description:
              'المحفوظات والقراءة والإعدادات، كلها من الشريط السفلي. اضغط «التالي» وسنفتح الإعدادات ونكمل الجولة هناك.',
          icon: Icons.menu_book_outlined,
          // خطوة تعبر الصفحات: «التالي» ينتقل فعلاً إلى الإعدادات، والخطوة
          // التالية تبرز عنصراً هناك — كل ذلك على نفس الكنترولر المركزي.
          onNext: _openSettings,
        ),
        TourStep(
          targetKey: SettingsDemoScreen.themeKey,
          title: 'متابعة في الإعدادات',
          description:
              'انتقلت الجولة معك إلى صفحة أخرى دون أي كنترولر إضافي. اضغط «التالي» للعودة وإنهاء الجولة.',
          icon: Icons.settings_outlined,
          // إن فتح المستخدم الإعدادات بنفسه قبل وصول الجولة، لا يُعاد فتحها.
          onEnter: () {
            if (!SettingsDemoScreen.isOpen) _openSettings();
          },
          onExit: () {
            if (SettingsDemoScreen.isOpen) {
              Navigator.of(context).pop();
            }
          },
        ),
        const TourStep(
          title: 'هذا كل شيء',
          description: 'تجد جولة كل قسم في إعادته من صفحته متى ما أردت.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        onDestinationSelected: (i) {
          if (i == 3) _openSettings();
        },
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
          appTour.start(tourId: 'mushaf', steps: _buildSteps());
        },
        child: const Icon(Icons.replay),
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

/// صفحة ثانية مستقلة تماماً: جولتها الخاصة تعمل على نفس الكنترولر المركزي،
/// وتبدأ أول مرة تُفتح فيها الصفحة. ويمكن لجولة قسم آخر أن تبرز عناصرها
/// (كما تفعل جولة المصحف أعلاه).
class SettingsDemoScreen extends StatefulWidget {
  const SettingsDemoScreen({super.key});

  /// مفتاح عنصر «المظهر» لتبرزه جولة المصحف العابرة للصفحات.
  static final themeKey = GlobalKey();

  /// هل الصفحة مفتوحة حالياً (تستخدمه الجولة حتى لا تعيد فتحها فوق نفسها).
  static bool isOpen = false;

  @override
  State<SettingsDemoScreen> createState() => _SettingsDemoScreenState();
}

class _SettingsDemoScreenState extends State<SettingsDemoScreen> {
  final _reciterKey = GlobalKey();
  final _aboutKey = GlobalKey();

  List<TourStep> _buildSteps() => [
        TourStep(
          targetKey: _reciterKey,
          title: 'القارئ',
          description: 'اختر قارئك المفضل للتلاوة من هنا.',
          icon: Icons.headphones_outlined,
        ),
        TourStep(
          targetKey: SettingsDemoScreen.themeKey,
          title: 'المظهر',
          description: 'بدّل بين الوضع الداكن والفاتح.',
          icon: Icons.dark_mode_outlined,
        ),
        TourStep(
          targetKey: _aboutKey,
          title: 'عن التطبيق',
          description: 'الإصدار والروابط المهمة هنا.',
          icon: Icons.info_outline,
        ),
      ];

  @override
  void initState() {
    super.initState();
    SettingsDemoScreen.isOpen = true;
    // جولة الإعدادات تبدأ تلقائياً أول مرة فقط — على نفس الكنترولر المركزي
    // وبمعرّف مستقل عن جولة المصحف.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appTour.startOnce(tourId: 'settings', steps: _buildSteps());
    });
  }

  @override
  void dispose() {
    SettingsDemoScreen.isOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'إعادة جولة الإعدادات',
            onPressed: () async {
              await tourStore.reset('settings');
              appTour.start(tourId: 'settings', steps: _buildSteps());
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          children: [
            ListTile(
              key: _reciterKey,
              leading:
                  const Icon(Icons.headphones_outlined, color: Color(0xFFB08E3F)),
              title: const Text('القارئ',
                  style: TextStyle(color: Color(0xFFE8E2D5))),
              subtitle: const Text('مشاري العفاسي',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
              onTap: () {},
            ),
            SwitchListTile(
              key: SettingsDemoScreen.themeKey,
              secondary:
                  const Icon(Icons.dark_mode_outlined, color: Color(0xFFB08E3F)),
              title: const Text('المظهر الداكن',
                  style: TextStyle(color: Color(0xFFE8E2D5))),
              value: true,
              onChanged: (_) {},
            ),
            ListTile(
              key: _aboutKey,
              leading:
                  const Icon(Icons.info_outline, color: Color(0xFFB08E3F)),
              title: const Text('عن التطبيق',
                  style: TextStyle(color: Color(0xFFE8E2D5))),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
