import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotlight_tour/spotlight_tour.dart';

import 'golden_test.dart' show pageOneText, secondVerseOfPageOne;

/// مفاتيح أهداف العرض المركزي عبر الصفحتين.
class CentralKeys {
  final nav = GlobalKey<NavigatorState>();
  final verse = GlobalKey();
  final bottomBar = GlobalKey();
  final reciter = GlobalKey();
  final theme = GlobalKey();
}

/// تطبيق صفحتين لعرض الاستدعاء المركزي: مضيف واحد في builder، وجولة تبدأ
/// من صفحة المصحف ثم تعبر إلى صفحة الإعدادات وتبرز عناصرها — بكنترولر واحد
/// ودون أي تغليف خاص بالصفحات.
class CentralDemoApp extends StatelessWidget {
  const CentralDemoApp({super.key, required this.keys, required this.tour});

  final CentralKeys keys;
  final SpotlightTourController tour;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: keys.nav,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF100E0C),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: SpotlightTourHost(controller: tour, child: child!),
      ),
      home: CentralMushafPage(keys: keys),
    );
  }
}

class CentralMushafPage extends StatelessWidget {
  const CentralMushafPage({super.key, required this.keys});

  final CentralKeys keys;

  void openSettings() {
    unawaited(keys.nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: CentralSettingsPage(keys: keys),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('النساء'),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              pageOneText,
              key: keys.verse,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 21,
                height: 2.0,
                color: Color(0xFFE8E2D5),
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          key: keys.bottomBar,
          backgroundColor: const Color(0xFF161411),
          selectedIndex: 0,
          onDestinationSelected: (i) {
            if (i == 3) openSettings();
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
      ),
    );
  }
}

class CentralSettingsPage extends StatelessWidget {
  const CentralSettingsPage({super.key, required this.keys});

  final CentralKeys keys;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        children: [
          ListTile(
            key: keys.reciter,
            leading:
                const Icon(Icons.headphones_outlined, color: Color(0xFFB08E3F)),
            title: const Text('القارئ',
                style: TextStyle(color: Color(0xFFE8E2D5))),
            subtitle: const Text('مشاري العفاسي',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
            onTap: () {},
          ),
          SwitchListTile(
            key: keys.theme,
            secondary:
                const Icon(Icons.dark_mode_outlined, color: Color(0xFFB08E3F)),
            title: const Text('المظهر الداكن',
                style: TextStyle(color: Color(0xFFE8E2D5))),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

/// خطوات جولة تعبر الصفحات: تبدأ من آية المصحف، ثم تنتقل بنفسها إلى
/// الإعدادات وتبرز عنصرين هناك، وتغلق الصفحة عند النهاية.
List<TourStep> centralSteps(CentralKeys keys, CentralMushafPage page) => [
      const TourStep(
        title: 'كنترولر واحد لكل التطبيق',
        description:
            'مضيف واحد أعلى التطبيق يخدم كل الصفحات: أي قسم يستدعي الجولة بخطواته، والجولة تعبر الصفحات معك.',
      ),
      TourStep(
        targetKey: keys.verse,
        shape: TourTargetShape.textLines,
        textRange: secondVerseOfPageOne(),
        title: 'على صفحة المصحف',
        description: 'الإبراز يعمل على الصفحة الحالية كما تعوّدت.',
        icon: Icons.menu_book_outlined,
      ),
      TourStep(
        targetKey: keys.bottomBar,
        title: 'الانتقال إلى قسم آخر',
        description: 'اضغط «التالي» وستفتح الجولة الإعدادات بنفسها وتكمل هناك.',
        icon: Icons.settings_outlined,
        onNext: page.openSettings,
      ),
      TourStep(
        targetKey: keys.reciter,
        title: 'على صفحة الإعدادات',
        description: 'نفس الجولة، نفس الكنترولر، على مسار آخر بالكامل.',
        icon: Icons.headphones_outlined,
      ),
      TourStep(
        targetKey: keys.theme,
        title: 'المظهر',
        description: 'اضغط «التالي» لتغلق الجولة الإعدادات وتنهي الجولة.',
        icon: Icons.dark_mode_outlined,
        onNext: () => keys.nav.currentState!.pop(),
        onExit: () {
          if (keys.nav.currentState!.canPop()) {
            keys.nav.currentState!.pop();
          }
        },
      ),
      const TourStep(
        title: 'هذا كل شيء',
        description: 'أي قسم جديد يضيف خطواته ويستدعي start من أي مكان.',
      ),
    ];
