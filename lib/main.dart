import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF123B66);
const blue = Color(0xFF1976D2);
const paleBlue = Color(0xFFEAF3FB);

void main() => runApp(const GasLearningApp());

class GasLearningApp extends StatelessWidget {
  const GasLearningApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'آموزش شرکت گاز خراسان جنوبی',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: navy),
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, centerTitle: true),
    ),
    home: const SplashPage(),
  );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF75BCEB),
    body: SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fill unused screen space with a softly blurred version of the SAME poster.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.asset('assets/splash_poster.webp', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withValues(alpha: 0.10)),
          // Keep the complete original poster visible without cropping its Persian text or artwork.
          Image.asset('assets/splash_poster.webp', fit: BoxFit.contain),
        ],
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int index = 0;
  final pages = const [DashboardPage(), ExamPage(), TrainingPage(), LibraryPage(), ResultsPage()];
  final titles = const ['داشبورد', 'آزمون‌ها', 'آموزش‌ها', 'کتابخانه', 'نتایج'];

  void navigateTo(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= pages.length) { return; }
    setState(() => index = nextIndex);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titles[index])),
    body: pages[index],
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
        NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'آزمون'),
        NavigationDestination(icon: Icon(Icons.play_lesson_outlined), label: 'آموزش'),
        NavigationDestination(icon: Icon(Icons.local_library_outlined), label: 'کتابخانه'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'نتایج'),
      ],
    ),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('به سامانه آموزش خوش آمدید', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
      SizedBox(height: 8), Text('یادگیری، مرور مطالب و سنجش آموخته‌ها', style: TextStyle(color: Colors.white70)),
    ])),
    const SizedBox(height: 18),
    const Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    _MenuTile(icon: Icons.quiz, title: 'آزمون‌های چهارگزینه‌ای', subtitle: 'پاسخ به پرسش‌ها و ثبت نتیجه', onTap: () => _go(context, 1)),
    _MenuTile(icon: Icons.menu_book, title: 'آموزش‌ها', subtitle: 'مطالعه محتوای آموزشی', onTap: () => _go(context, 2)),
    _MenuTile(icon: Icons.local_library, title: 'کتابخانه دیجیتال', subtitle: 'دسترسی به منابع و جزوه‌ها', onTap: () => _go(context, 3)),
    _MenuTile(icon: Icons.assessment, title: 'سوابق آزمون', subtitle: 'مشاهده نتایج ذخیره‌شده', onTap: () => _go(context, 4)),
  ]);
  void _go(BuildContext context, int i) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    state?.navigateTo(i);
  }
}
class _MenuTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: paleBlue, child: Icon(icon, color: navy)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left), onTap: onTap));
}

const questions = <Map<String, Object>>[
  {'q':'هدف اصلی آموزش ایمنی در محیط کار چیست؟','a':['افزایش سرعت کار','پیشگیری از حادثه و کاهش خطر','افزایش هزینه‌ها','حذف دستورالعمل‌ها'],'correct':1},
  {'q':'در صورت مشاهده وضعیت ناایمن چه باید کرد؟','a':['بی‌توجهی کرد','موضوع را گزارش و طبق دستورالعمل اقدام کرد','کار را پنهانی ادامه داد','تجهیزات حفاظتی را کنار گذاشت'],'correct':1},
  {'q':'پیش از استفاده از تجهیزات باید چه کاری انجام داد؟','a':['بررسی سلامت و ایمنی تجهیزات','تغییر خودسرانه تنظیمات','حذف حفاظ‌ها','استفاده بدون بررسی'],'correct':0},
];

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});
  @override
  State<ExamPage> createState() => _ExamPageState();
}
class _ExamPageState extends State<ExamPage> {
  int question = 0, score = 0;
  int? selected;
  bool finished = false;
  @override
  Widget build(BuildContext context) {
    if (finished) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.emoji_events, color: blue, size: 64),
      Text('نتیجه آزمون: $score از ${questions.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16), FilledButton(onPressed: () => setState(() { question=0; score=0; selected=null; finished=false; }), child: const Text('آزمون مجدد')),
    ]));
    final q = questions[question];
    final answers = q['a'] as List<String>;
    return ListView(padding: const EdgeInsets.all(18), children: [
      LinearProgressIndicator(value: (question+1)/questions.length),
      const SizedBox(height: 18),
      Text('پرسش ${question+1} از ${questions.length}', style: const TextStyle(color: navy, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(q['q'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      RadioGroup<int>(
        groupValue: selected,
        onChanged: (value) => setState(() => selected = value),
        child: Column(
          children: List.generate(
            answers.length,
            (i) => Card(
              child: RadioListTile<int>(
                value: i,
                title: Text(answers[i]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: selected==null ? null : () {
        if (selected == q['correct']) { score++; }
        if (question == questions.length-1) {
          setState(()=>finished=true);
          _saveResult();
        } else { setState(() { question++; selected=null; }); }
      }, child: Text(question==questions.length-1 ? 'پایان آزمون' : 'پرسش بعدی')),
    ]);
  }
  Future<void> _saveResult() async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getStringList('exam_results') ?? [];
    old.insert(0, jsonEncode({'score':score,'total':questions.length,'date':DateTime.now().toIso8601String()}));
    await prefs.setStringList('exam_results', old.take(100).toList());
  }
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: const [
    Text('محتوای آموزشی', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    _InfoCard(icon:Icons.health_and_safety,title:'اصول ایمنی و بهداشت',body:'آشنایی با اصول عمومی ایمنی، شناسایی خطرها و گزارش شرایط ناایمن.'),
    _InfoCard(icon:Icons.local_fire_department,title:'آشنایی با گاز طبیعی',body:'مفاهیم پایه درباره گاز طبیعی و نکات عمومی استفاده ایمن.'),
    _InfoCard(icon:Icons.warning_amber,title:'اقدام در شرایط اضطراری',body:'حفظ خونسردی، رعایت دستورالعمل‌های سازمانی و اطلاع‌رسانی به مسئول مربوط.'),
  ]);
}
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: const [
    Text('کتابخانه دیجیتال', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    _InfoCard(icon:Icons.picture_as_pdf,title:'جزوه‌های آموزشی',body:'محل نمایش و افزودن فایل‌های آموزشی تأییدشده در نسخه‌های بعدی.'),
    _InfoCard(icon:Icons.book,title:'دستورالعمل‌ها و منابع',body:'منابع و دستورالعمل‌های موردنیاز کارکنان در یک بخش متمرکز.'),
  ]);
}
class _InfoCard extends StatelessWidget {
  final IconData icon; final String title,body;
  const _InfoCard({required this.icon,required this.title,required this.body});
  @override
  Widget build(BuildContext context) => Card(margin:const EdgeInsets.only(top:12), child: Padding(padding:const EdgeInsets.all(16), child: Row(crossAxisAlignment:CrossAxisAlignment.start, children:[Icon(icon,color:blue,size:30),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:6),Text(body)]))])));
}
class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});
  @override
  State<ResultsPage> createState()=>_ResultsPageState();
}
class _ResultsPageState extends State<ResultsPage> {
  late Future<List<String>> results;
  @override
  void initState(){super.initState();results=_load();}
  Future<List<String>> _load() async {final p=await SharedPreferences.getInstance();return p.getStringList('exam_results')??[];}
  @override
  Widget build(BuildContext context)=>FutureBuilder<List<String>>(future:results,builder:(context,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('هنوز نتیجه‌ای ثبت نشده است'));
    return ListView(padding:const EdgeInsets.all(16),children:s.data!.map((v){final x=jsonDecode(v) as Map<String,dynamic>;final d=DateTime.parse(x['date'] as String);return Card(child:ListTile(leading:const Icon(Icons.check_circle,color:blue),title:Text('امتیاز: ${x['score']} از ${x['total']}'),subtitle:Text('${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute}')));}).toList());
  });
}
