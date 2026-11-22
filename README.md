# spotlight_tour

حزمة Flutter لعمل **جولة تعريفية (Feature Tour / Coach Marks)** داخل أي تطبيق، بنفس شكل وحركة
الجولة الموجودة في الفيديو المرجعي: تعتيم للشاشة، إطار ذهبي متوهّج حول العنصر المستهدف، نبضة
بيضاء متحركة، وبطاقة شرح داكنة فيها زر تخطٍّ وعدّاد «5 من 25» وأزرار السابق/التالي، مع دعم
كامل للعربية واتجاه RTL.

## المزايا

- إبراز أي ويدجت عبر `GlobalKey` بإطار مستطيل مدوّر أو دائري، مع توهّج ونبضة متحركة.
- إبراز **نطاق نصي داخل نص متدفّق** (`Text`/`RichText`) بإطار متدرّج يتبع سطور النص
  نفسها: يبدأ وينتهي منتصف السطر ويستثني ما قبل النطاق وما بعده، تماماً مثل تحديد
  النص، ويدعم العربية واتجاه RTL تلقائياً (`TourTargetShape.textLines` + `textRange`).
- خطوات بدون هدف (مقدمة وخاتمة) تظهر البطاقة في منتصف الشاشة.
- انتقالات متحركة: انزلاق البطاقة للأسفل عند الخروج، انزلاق الإطار بسلاسة بين العناصر،
  ثم ظهور البطاقة الجديدة من الأسفل.
- موضع البطاقة تلقائي: تحت الهدف إن كان أعلى الشاشة، فوقه إن كان أسفلها، وإلا أسفل الشاشة.
- كل النصوص والألوان والمدد قابلة للتخصيص (`TourLabels` و `SpotlightTourTheme`).
- تعمل مع LTR وRTL تلقائياً حسب اتجاه الشاشة.

## الاستخدام

1. أضف `GlobalKey` لكل ويدجت تريد إبرازه:

```dart
final searchKey = GlobalKey();
final verseKey  = GlobalKey();
```

2. عرّف الخطوات وأنشئ الكنترولر:

```dart
late final tour = SpotlightTourController(steps: [
  const TourStep(                                   // خطوة بدون هدف = مقدمة بالمنتصف
    title: 'جولة في التطبيق',
    description: 'جولة قصيرة نتعرف فيها على أهم أجزاء الشاشة.',
  ),
  TourStep(
    targetKey: verseKey,
    title: 'اضغط مطولاً على أي آية',
    description: 'يفتح درجاً فيه التفسير والاستماع دون أن تغادر الصفحة.',
    icon: Icons.touch_app_outlined,                 // أيقونة صغيرة بجانب العدّاد
  ),
  TourStep(
    targetKey: searchKey,
    title: 'ابحث',
    description: 'اكتب كلمة من الآية وانتقل إليها بلمسة.',
    shape: TourTargetShape.circle,                  // إطار دائري بدل المستطيل
    targetPadding: EdgeInsets.all(6),
  ),
  const TourStep(
    title: 'هذا كل شيء',
    description: 'تجد هذه الجولة في الإعدادات متى ما أردت إعادتها.',
  ),
]);
```

3. لفّ شاشتك بـ `SpotlightTour` وابدأ الجولة متى شئت:

```dart
@override
Widget build(BuildContext context) {
  return SpotlightTour(
    controller: tour,
    child: Scaffold(...),
  );
}

// مثلاً عند أول تشغيل:
WidgetsBinding.instance.addPostFrameCallback((_) => tour.start());
```

### إبراز نطاق نصي عبر السطور

لإبراز آية أو جملة داخل نص أطول متدفّق (كما في صفحات المصحف)، ضع المفتاح على ويدجت
النص نفسه واستخدم `TourTargetShape.textLines` مع `textRange` (إزاحات الأحرف داخل
النص، مثل `TextSelection`). إن لم تحدد `textRange` يُبرَز النص كله:

```dart
const pageText = '...نص الصفحة كاملاً هنا...';
final pageTextKey = GlobalKey();

Text(pageText, key: pageTextKey, ...)

final start = pageText.indexOf('وَاللَّهُ');
final end = pageText.indexOf('﴿٨٧﴾') + '﴿٨٧﴾'.length;

TourStep(
  targetKey: pageTextKey,
  shape: TourTargetShape.textLines,
  textRange: TextRange(start: start, end: end),
  title: 'اضغط مطولاً على أي آية',
  description: 'يفتح درجاً فيه التفسير والاستماع.',
)
```

الإطار الناتج متدرّج: يحيط بكل سطر بحدوده الفعلية، فيبدو النص المحدد وكأنه مظلَّل
بإطار واحد متصل، ويبقى النص خارج النطاق معتَّماً حتى لو شارك نفس السطر.

قيود هذا الشكل:

- يعمل فقط مع ويدجت `Text` أو `RichText` (وليس أي ويدجت)، ويجب أن يكون المفتاح على
  ويدجت النص نفسه، وأن يكون النص ظاهراً ومُنسَّقاً على الشاشة.
- لا يدعم `WidgetSpan` (عناصر مضمّنة داخل النص) بشكل دقيق.
- أثناء الانتقال من خطوة لأخرى ينزلق الإطار الخارجي للنطاق أولاً ثم يظهر الشكل
  المتدرّج في نهاية الحركة، لأن عدد السطور يختلف بين الأهداف ولا يمكن مزج شكلين
  متدرّجين بسلاسة مباشرة.
- العرض يُحسب من التنسيق الفعلي للنص، لذا يتبع المحاذاة والاتجاه (RTL/LTR) تلقائياً.

### ردود الأفعال

```dart
tour
  ..onFinish = () => markTourSeen()      // ضغط «تم» في آخر خطوة
  ..onSkip   = () => markTourSeen()      // ضغط «تخطي الجولة»
  ..onStepChanged = (i) => debugPrint('step $i');
```

### تخصيص النصوص والألوان

```dart
SpotlightTour(
  controller: tour,
  labels: const TourLabels(skip: 'تخطّى', next: 'التالي', done: 'إنهاء'),
  theme: SpotlightTourTheme.gold().copyWith(accentColor: Colors.teal),
  barrierDismissible: true,   // اللمس خارج البطاقة يتخطى الجولة (افتراضياً معطّل)
)
```

### ملاحظات

- تأكد أن الويدجت المستهدف ظاهر على الشاشة قبل بدء الخطوة (لو كان داخل ListView
  غير ظاهر حالياً، لن يُرسم إطار حوله وتظهر البطاقة بالمنتصف).
- إن كانت شاشتك داخل `Directionality` خاص بها، تلتقط الحزمة اتجاهها تلقائياً.
- لإعادة الجولة زرّياً: `tour.start()` في أي وقت.

## تشغيل المثال

```bash
cd example
flutter pub get
flutter run
```

## الاختبارات

```bash
flutter test                          # اختبارات السلوك + الاختبارات الذهبية
flutter test --update-goldens         # لإعادة توليد الصور المرجعية بعد تعديل التصميم
```
