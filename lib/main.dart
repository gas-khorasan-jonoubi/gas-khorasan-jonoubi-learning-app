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
  int? selectedExamQuestion;
  String? selectedLibraryTopic;
  final titles = const ['داشبورد', 'آزمون‌ها', 'آموزش‌ها', 'کتابخانه', 'نتایج'];
  Widget get activePage => switch (index) {
    0 => const DashboardPage(),
    1 => ExamPage(key: ValueKey(selectedExamQuestion), initialQuestion: selectedExamQuestion ?? 0),
    2 => const TrainingPage(),
    3 => LibraryPage(initialTopic: selectedLibraryTopic),
    _ => const ResultsPage(),
  };
  void openSearchResult(SearchEntry entry) {
    if (entry.section == 'exam') {
      setState(() { index = 1; selectedExamQuestion = entry.index; });
      return;
    }
    if (entry.section == 'training' || entry.kind == SearchKind.article ||
        entry.kind == SearchKind.image || entry.kind == SearchKind.pdf ||
        entry.kind == SearchKind.video || entry.kind == SearchKind.file) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SearchResultPage(entry: entry),
      ));
      return;
    }
    if (entry.section == 'library-topic') {
      openLibraryTopic(entry.title);
      return;
    }
    setState(() { index = entry.title.contains('آزمون') ? 1 : 3; selectedLibraryTopic = null; });
  }

  void navigateTo(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= titles.length) { return; }
    setState(() => index = nextIndex);
  }

  void openLibraryTopic(String topic) {
    setState(() { index = 3; selectedLibraryTopic = topic; });
  }

  void closeLibraryTopic() {
    setState(() => selectedLibraryTopic = null);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) return;
      if (index != 0 && mounted) {
        setState(() => index = 0);
      }
    },
    child: Scaffold(
    appBar: AppBar(title: Text(titles[index])),
    body: activePage,
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
  ),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    SearchPanel(entries:allSearchEntries,hint:'جستجو در تمام برنامه...',onSelected:(entry)=>context.findAncestorStateOfType<_HomePageState>()?.openSearchResult(entry)),
    const SizedBox(height:16),
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

enum SearchKind { exam, article, topic, image, pdf, video, file }
class SearchEntry {
  final String title, subtitle, content, section;
  final SearchKind kind;
  final int index;
  final String? assetPath;
  const SearchEntry({required this.title, this.subtitle = '', this.content = '', required this.section, required this.kind, this.index = 0, this.assetPath});
}
String normalizeSearchText(String value) => value.replaceAll('ي','ی').replaceAll('ك','ک').replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'),'').toLowerCase().trim();

List<SearchEntry> searchEntries(List<SearchEntry> entries, String query) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return [];
  return entries.where((entry) => normalizeSearchText(
    '${entry.title} ${entry.subtitle} ${entry.content}',
  ).contains(normalizedQuery)).toList();
}

List<SearchEntry> get allSearchEntries => [
  const SearchEntry(title:'آزمون ایمنی و آشنایی با محیط کار',subtitle:'آزمون شماره ۱',section:'exam',kind:SearchKind.exam),
  ...List.generate(questions.length,(i)=>SearchEntry(title:questions[i]['q'] as String,subtitle:'سؤال ${i+1} از آزمون شماره ۱',content:(questions[i]['a'] as List<String>).join('، '),section:'exam',kind:SearchKind.exam,index:i)),
  const SearchEntry(title:'اصول ایمنی و بهداشت',subtitle:'آموزش عمومی',content:'شناسایی خطرها و گزارش شرایط ناایمن',section:'training',kind:SearchKind.article),
  const SearchEntry(title:'آشنایی با گاز طبیعی',subtitle:'آموزش عمومی',content:'مفاهیم پایه درباره گاز طبیعی و نکات عمومی استفاده ایمن',section:'training',kind:SearchKind.article),
  const SearchEntry(title:'اقدام در شرایط اضطراری',subtitle:'آموزش عمومی',content:'حفظ خونسردی، رعایت دستورالعمل‌های سازمانی و اطلاع‌رسانی',section:'training',kind:SearchKind.article),
  const SearchEntry(title:'آزمون‌ها و سؤالات',subtitle:'کتابخانه دیجیتال',section:'library',kind:SearchKind.topic),
  const SearchEntry(title:'جزوه‌ها و دستورالعمل‌ها',subtitle:'کتابخانه دیجیتال',section:'library',kind:SearchKind.topic),
  ...LibraryPage.knowledgeAreas.map((area)=>SearchEntry(title:area,subtitle:'دانستنی‌ها و آموزش‌های تخصصی',section:'library-topic',kind:SearchKind.topic)),
];
class SearchPanel extends StatefulWidget {
  final List<SearchEntry> entries;
  final ValueChanged<SearchEntry> onSelected;
  final String hint;
  const SearchPanel({super.key,required this.entries,required this.onSelected,this.hint='جستجو در این بخش...'});
  @override State<SearchPanel> createState()=>_SearchPanelState();
}
class _SearchPanelState extends State<SearchPanel> {
  final controller=TextEditingController();
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final query=normalizeSearchText(controller.text);
    final matches=searchEntries(widget.entries,query);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      TextField(controller:controller,textInputAction:TextInputAction.search,onChanged:(_)=>setState((){}),decoration:InputDecoration(hintText:widget.hint,prefixIcon:const Icon(Icons.search),suffixIcon:controller.text.isEmpty?null:IconButton(icon:const Icon(Icons.clear),onPressed:(){controller.clear();setState((){});}),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))),
      if(controller.text.isNotEmpty)...[
        const SizedBox(height:8),
        if(matches.isEmpty) const Padding(padding:EdgeInsets.all(14),child:Text('موردی پیدا نشد.',textAlign:TextAlign.center))
        else ...matches.map((e)=>Card(margin:const EdgeInsets.only(bottom:6),child:ListTile(dense:true,leading:Icon(_searchIcon(e.kind),color:blue),title:Text(e.title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(e.subtitle),trailing:const Icon(Icons.chevron_left),onTap:()=>widget.onSelected(e)))),
      ],
    ]);
  }
}
IconData _searchIcon(SearchKind kind)=>switch(kind){SearchKind.exam=>Icons.quiz_outlined,SearchKind.article=>Icons.menu_book_outlined,SearchKind.topic=>Icons.folder_outlined,SearchKind.image=>Icons.image_outlined,SearchKind.pdf=>Icons.picture_as_pdf_outlined,SearchKind.video=>Icons.video_library_outlined,SearchKind.file=>Icons.insert_drive_file_outlined};
class SearchResultPage extends StatelessWidget {
  final SearchEntry entry;
  const SearchResultPage({super.key, required this.entry});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(entry.title)),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        Icon(_searchIcon(entry.kind), color: blue),
        const SizedBox(width: 8),
        Expanded(child: Text(entry.subtitle, style: const TextStyle(color: navy))),
      ]),
      const SizedBox(height: 16),
      if (entry.kind == SearchKind.image && entry.assetPath != null)
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(entry.assetPath!, fit: BoxFit.contain))
      else if (entry.kind == SearchKind.image)
        const Text('مسیر تصویر هنوز به محتوای برنامه متصل نشده است.')
      else
        Text(entry.content.isEmpty ? 'محتوای این مورد هنوز به برنامه افزوده نشده است.' : entry.content, style: const TextStyle(fontSize: 16, height: 1.8)),
      if (entry.kind == SearchKind.pdf || entry.kind == SearchKind.video || entry.kind == SearchKind.file)
        const Padding(padding: EdgeInsets.only(top: 12), child: Text('برای نمایش این نوع فایل، پس از افزودن فایل اصلی، نمایشگر سازگار آن به برنامه متصل می‌شود.')),
    ]),
  );
}

const questions = <Map<String, Object>>[
  {'q':'هدف اصلی آموزش ایمنی در محیط کار چیست؟','a':['افزایش سرعت کار','پیشگیری از حادثه و کاهش خطر','افزایش هزینه‌ها','حذف دستورالعمل‌ها'],'correct':1},
  {'q':'در صورت مشاهده وضعیت ناایمن چه باید کرد؟','a':['بی‌توجهی کرد','موضوع را گزارش و طبق دستورالعمل اقدام کرد','کار را پنهانی ادامه داد','تجهیزات حفاظتی را کنار گذاشت'],'correct':1},
  {'q':'پیش از استفاده از تجهیزات باید چه کاری انجام داد؟','a':['بررسی سلامت و ایمنی تجهیزات','تغییر خودسرانه تنظیمات','حذف حفاظ‌ها','استفاده بدون بررسی'],'correct':0},
];

class ExamPage extends StatefulWidget {
  final int initialQuestion;
  const ExamPage({super.key,this.initialQuestion=0});
  @override
  State<ExamPage> createState() => _ExamPageState();
}
class _ExamPageState extends State<ExamPage> {
  int question = 0, score = 0;
  int? selected;
  bool finished = false;
  @override
  void initState(){super.initState();question=widget.initialQuestion.clamp(0,questions.length-1).toInt();}
  @override
  Widget build(BuildContext context) {
    if (finished) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.emoji_events, color: blue, size: 64),
        Text('نتیجه آزمون: $score از ${questions.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() {
            question = 0;
            score = 0;
            selected = null;
            finished = false;
          }),
          child: const Text('آزمون مجدد'),
        ),
      ]));
    }
    final q = questions[question];
    final answers = q['a'] as List<String>;
    return ListView(padding: const EdgeInsets.all(18), children: [
      SearchPanel(entries:List.generate(questions.length,(i)=>SearchEntry(title:questions[i]['q'] as String,subtitle:'سؤال ${i+1} از آزمون شماره ۱',content:(questions[i]['a'] as List<String>).join('، '),section:'exam',kind:SearchKind.exam,index:i)),hint:'جستجو در همین آزمون...',onSelected:(entry){setState((){question=entry.index;selected=null;});}),
      const SizedBox(height:12),
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
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    SearchPanel(entries:allSearchEntries.where((e)=>e.section=='training').toList(),hint:'جستجو در آموزش‌ها...',onSelected:(entry)=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>SearchResultPage(entry:entry)))),
    const SizedBox(height:12),
    const Text('محتوای آموزشی', style: TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    _InfoCard(icon:Icons.health_and_safety,title:'اصول ایمنی و بهداشت',body:'آشنایی با اصول عمومی ایمنی، شناسایی خطرها و گزارش شرایط ناایمن.'),
    _InfoCard(icon:Icons.local_fire_department,title:'آشنایی با گاز طبیعی',body:'مفاهیم پایه درباره گاز طبیعی و نکات عمومی استفاده ایمن.'),
    _InfoCard(icon:Icons.warning_amber,title:'اقدام در شرایط اضطراری',body:'حفظ خونسردی، رعایت دستورالعمل‌های سازمانی و اطلاع‌رسانی به مسئول مربوط.'),
  ]);
}
class LibraryPage extends StatelessWidget {
  final String? initialTopic;
  const LibraryPage({super.key,this.initialTopic});

  static const knowledgeAreas = <String>[
    'امور مشترکین',
    'وصول مطالبات',
    'تعمیرات',
    'HSE و ایمنی',
    'مدیریت و ریاست اداره',
    'امداد و گازبان',
    'سایر دانستنی‌ها و آموزش‌های تخصصی',
  ];

  @override
  Widget build(BuildContext context) {
    if(initialTopic!=null)return _LibraryTopicPage(topic:initialTopic!);
    return ListView(
    padding: const EdgeInsets.all(18),
    children: [
      SearchPanel(entries:allSearchEntries.where((e)=>e.section=='library'||e.section=='library-topic').toList(),hint:'جستجو در کتابخانه...',onSelected:(entry){if(entry.section=='library-topic'){context.findAncestorStateOfType<_HomePageState>()?.openLibraryTopic(entry.title);}}),
      const SizedBox(height:12),
      const Text('کتابخانه دیجیتال', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('مطالب این کتابخانه در سه دسته اصلی و به‌صورت آفلاین در برنامه قرار می‌گیرند.'),
      Card(
        margin: const EdgeInsets.only(top: 14),
        child: const ListTile(
          leading: CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.quiz, color: navy)),
          title: Text('۱. آزمون‌ها و سؤالات', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('مجموعه آزمون‌های شماره‌گذاری‌شده و پرسش‌های چهارگزینه‌ای'),
        ),
      ),
      Card(
        margin: const EdgeInsets.only(top: 10),
        child: const ListTile(
          leading: CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.menu_book, color: navy)),
          title: Text('۲. جزوه‌ها و دستورالعمل‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('جزوه‌ها، آیین‌نامه‌ها، دستورالعمل‌ها و فایل‌های مرجع'),
        ),
      ),
      Card(
        margin: const EdgeInsets.only(top: 10),
        child: ExpansionTile(
          leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.lightbulb_outline, color: navy)),
          title: const Text('۳. دانستنی‌ها و آموزش‌های تخصصی', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('موضوعات تخصصی موردنیاز کارکنان شرکت گاز'),
          initiallyExpanded: true,
          children: knowledgeAreas.map((area) => ListTile(
            leading: const Icon(Icons.folder_outlined, color: blue),
            title: Text(area),
            dense: true,
            onTap: () => context.findAncestorStateOfType<_HomePageState>()?.openLibraryTopic(area),
          )).toList(),
        ),
      ),
    ],
  );
  }
}
class _LibraryTopicPage extends StatelessWidget {
  final String topic;
  const _LibraryTopicPage({required this.topic});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    Row(children:[IconButton(onPressed:()=>context.findAncestorStateOfType<_HomePageState>()?.closeLibraryTopic(),icon:const Icon(Icons.arrow_back)),Expanded(child:Text(topic,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)))]),
    SearchPanel(entries:[SearchEntry(title:topic,subtitle:'موضوع کتابخانه',content:'مطالب و فایل‌های این موضوع پس از دریافت و ثبت محتوا در برنامه قابل جستجو خواهند بود.',section:'library-topic',kind:SearchKind.topic)],hint:'جستجو در $topic...',onSelected:(entry)=>showDialog<void>(context:context,builder:(_)=>AlertDialog(title:Text(entry.title),content:const Text('محتوای این موضوع هنوز به کتابخانه افزوده نشده است.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('بستن'))]))),
    const SizedBox(height:14),const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('محتوای این بخش پس از دریافت جزوه‌ها، دستورالعمل‌ها، تصاویر و فایل‌های مربوط اضافه می‌شود.'))),
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
