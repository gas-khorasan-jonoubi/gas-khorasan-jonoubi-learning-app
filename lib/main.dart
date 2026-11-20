import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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
    title: 'دانستنی‌های گاز',
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ابتدا تصویر کامل بارگذاری می‌شود؛ سپس زمان سه‌ثانیه‌ای آغاز می‌شود.
      try {
        await precacheImage(const AssetImage('assets/splash.png'), context);
      } catch (_) {
        // اگر بارگذاری تصویر به هر علت شکست خورد، برنامه همچنان قابل ورود است.
      }
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: SizedBox.expand(
          child: Center(
            child: Image.asset(
              'assets/splash.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              alignment: Alignment.center,
            ),
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
  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      // در بخش‌های داخلی، دکمه برگشت فقط به داشبورد برمی‌گردد.
      if (index != 0) {
        setState(() => index = 0);
        return;
      }

      // خروج از برنامه در صفحه اصلی فقط با تأیید کاربر انجام می‌شود.
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('خروج از برنامه'),
          content: const Text('آیا می‌خواهید از برنامه خارج شوید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      );
      if (shouldExit == true && context.mounted) {
        SystemNavigator.pop();
      }
    },
    child: Scaffold(
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
    _MenuTile(icon: Icons.help_outline, title: 'راهنمای استفاده', subtitle: 'آشنایی با بخش‌ها و مثال کاربردی', onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpPage()))),
  ]);
  void _go(BuildContext context, int i) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    state?.setState(() => state.index = i);
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

Duration quizDurationFor(int questionCount) {
  if (questionCount < 0) {
    throw ArgumentError.value(questionCount, 'questionCount', 'Must not be negative.');
  }
  return Duration(seconds: questionCount * 30);
}

class QuizSummary {
  final int correct;
  final int wrong;
  final int unanswered;

  const QuizSummary({
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });
}

QuizSummary evaluateQuizAnswers(
  List<int?> selectedAnswers,
  List<int> correctAnswers,
) {
  if (selectedAnswers.length != correctAnswers.length) {
    throw ArgumentError('Selected answers and correct answers must have equal lengths.');
  }
  var correct = 0;
  var wrong = 0;
  var unanswered = 0;
  for (var i = 0; i < correctAnswers.length; i++) {
    final answer = selectedAnswers[i];
    if (answer == null) {
      unanswered++;
    } else if (answer == correctAnswers[i]) {
      correct++;
    } else {
      wrong++;
    }
  }
  return QuizSummary(
    correct: correct,
    wrong: wrong,
    unanswered: unanswered,
  );
}

class ExamPage extends StatelessWidget {
  const ExamPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _InfoCard(
            icon: Icons.health_and_safety,
            title: 'آزمون نمونه ایمنی و HSE',
            body: 'این بانک فعلاً شامل چند پرسش نمایشی است. زمان هر پرسش ۳۰ ثانیه در نظر گرفته شده و پاسخ‌ها تا پایان زمان قابل تغییر هستند.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QuizPage()),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('شروع آزمون نمونه'),
          ),
        ],
      );
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final List<int?> _answers =
      List<int?>.filled(questions.length, null);
  int _current = 0;
  late int _remainingSeconds = quizDurationFor(questions.length).inSeconds;
  late DateTime _deadline;
  Timer? _timer;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(quizDurationFor(questions.length));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finishing) return;
      final remaining = _deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        setState(() => _remainingSeconds = 0);
        _finish();
      } else if (remaining != _remainingSeconds) {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();

    final summary = evaluateQuizAnswers(
      _answers,
      questions.map((q) => q['correct'] as int).toList(),
    );

    final record = <String, dynamic>{
      'date': DateTime.now().toIso8601String(),
      'correct': summary.correct,
      'wrong': summary.wrong,
      'unanswered': summary.unanswered,
      'total': questions.length,
      'answers': _answers.map((answer) => answer ?? -1).toList(),
      'questions': questions
          .map((q) => <String, Object>{
                'q': q['q'] as String,
                'a': List<String>.from(q['a'] as List<String>),
                'correct': q['correct'] as int,
              })
          .toList(),
    };

    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getStringList('exam_results') ?? <String>[];
    old.insert(0, jsonEncode(record));
    await prefs.setStringList('exam_results', old.take(100).toList());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultDetailPage(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[_current];
    final answers = q['a'] as List<String>;
    final selected = _answers[_current];

    return Scaffold(
      appBar: AppBar(
        title: Text('پرسش ${_current + 1} از ${questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Text(
                _timeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _remainingSeconds <= 10 ? Colors.red : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          LinearProgressIndicator(
            value: (_current + 1) / questions.length,
          ),
          const SizedBox(height: 18),
          Text(
            q['q'] as String,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            answers.length,
            (i) => Card(
              child: RadioListTile<int>(
                value: i,
                groupValue: selected,
                onChanged: (value) {
                  if (value == null || _finishing) return;
                  setState(() => _answers[_current] = value);
                },
                title: Text(answers[i]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _current == 0
                      ? null
                      : () => setState(() => _current--),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('قبلی'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _current == questions.length - 1
                      ? null
                      : () => setState(() => _current++),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('بعدی'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _finishing ? null : _finish,
            child: const Text('پایان آزمون و ثبت نتیجه'),
          ),
          const SizedBox(height: 8),
          Text(
            'پاسخ داده‌شده: ${_answers.where((a) => a != null).length} از ${questions.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class ResultDetailPage extends StatelessWidget {
  final Map<String, dynamic> record;
  const ResultDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    // نتایج ذخیره‌شده در نسخه‌های قبلی نیز پس از به‌روزرسانی قابل مشاهده می‌مانند.
    final total = (record['total'] as int?) ?? 0;
    final correct = (record['correct'] as int?) ?? (record['score'] as int?) ?? 0;
    final wrong = (record['wrong'] as int?) ?? (total - correct).clamp(0, total).toInt();
    final unanswered = (record['unanswered'] as int?) ?? 0;
    final hasQuestionBreakdown =
        record['questions'] is List && record['answers'] is List;

    return Scaffold(
      appBar: AppBar(title: const Text('جزئیات نتیجه آزمون')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('خلاصه نتیجه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('درست: $correct   |   نادرست: $wrong   |   بی‌پاسخ: $unanswered'),
                  Text('مجموع پرسش‌ها: ${record['total']}'),
                ],
              ),
            ),
          ),
          if (hasQuestionBreakdown) ...[
            _resultGroup('پاسخ‌های درست', 0, correct),
            _resultGroup('پاسخ‌های نادرست و پاسخ صحیح', 1, wrong),
            _resultGroup('پرسش‌های بی‌پاسخ و پاسخ صحیح', 2, unanswered),
          ] else
            const Card(
              child: ListTile(
                title: Text('این نتیجه در نسخهٔ قبلی برنامه ثبت شده است.'),
                subtitle: Text('برای حفظ سابقه، امتیاز قبلی نمایش داده می‌شود؛ جزئیات سؤال‌ها در آن نسخه ذخیره نشده بود.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultGroup(String title, int mode, int count) {
    final savedQuestions = (record['questions'] as List).cast<Map>();
    final answers = (record['answers'] as List).cast<int>();
    final children = <Widget>[];
    for (var i = 0; i < savedQuestions.length; i++) {
      final q = savedQuestions[i];
      final options = (q['a'] as List).cast<String>();
      final correctIndex = q['correct'] as int;
      final userAnswer = answers[i];
      final isUnanswered = userAnswer < 0;
      final isCorrect = userAnswer == correctIndex;
      final include = mode == 0
          ? isCorrect
          : mode == 1
              ? !isUnanswered && !isCorrect
              : isUnanswered;
      if (!include) continue;
      children.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(q['q'] as String),
          subtitle: Text(
            'پاسخ شما: ${isUnanswered ? 'بدون پاسخ' : options[userAnswer]}\n'
            'پاسخ صحیح: ${options[correctIndex]}',
          ),
          isThreeLine: true,
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text('$count'), const SizedBox(width: 8), const Icon(Icons.expand_more)],
        ),
        children: children.isEmpty
            ? const [ListTile(title: Text('موردی برای نمایش وجود ندارد'))]
            : children,
      ),
    );
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
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          Text('راهنمای استفاده از برنامه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          _InfoCard(
            icon: Icons.home,
            title: 'داشبورد',
            body: 'از داشبورد می‌توانید با انتخاب هر کارت مستقیماً وارد آزمون‌ها، آموزش‌ها، کتابخانه یا سوابق شوید.',
          ),
          _InfoCard(
            icon: Icons.quiz,
            title: 'شرکت در آزمون',
            body: 'آزمون را شروع کنید، گزینهٔ هر سؤال را انتخاب کنید و با دکمه‌های قبلی و بعدی بین سؤال‌ها جابه‌جا شوید. زمان هر سؤال ۳۰ ثانیه محاسبه می‌شود و می‌توانید تا پایان زمان پاسخ را تغییر دهید.',
          ),
          _InfoCard(
            icon: Icons.assessment,
            title: 'دیدن نتیجه',
            body: 'پس از پایان یا اتمام زمان، تعداد پاسخ‌های درست، نادرست و بی‌پاسخ نمایش داده می‌شود. هر گروه را باز کنید تا سؤال‌ها و پاسخ صحیح را ببینید.',
          ),
          _InfoCard(
            icon: Icons.menu_book,
            title: 'مثال',
            body: 'برای نمونه، در آزمون ایمنی یک سؤال را پاسخ دهید، به سؤال بعد بروید، دوباره به سؤال قبل برگردید و پاسخ را اصلاح کنید؛ سپس آزمون را پایان دهید تا گزارش نتیجه ذخیره شود.',
          ),
          _InfoCard(
            icon: Icons.wifi_off,
            title: 'استفاده آفلاین',
            body: 'پس از نصب، بخش‌هایی که محتوایشان داخل برنامه قرار گرفته باشد بدون اینترنت قابل استفاده‌اند. محتوای رسمی و فایل‌های آموزشی باید در نسخهٔ نهایی به برنامه افزوده شوند.',
          ),
        ],
      );
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late final Future<List<String>> _results = _load();

  Future<List<String>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('exam_results') ?? <String>[];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data ?? <String>[];
          if (values.isEmpty) {
            return const Center(child: Text('هنوز نتیجه‌ای ثبت نشده است'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: values.map((value) {
              final record = jsonDecode(value) as Map<String, dynamic>;
              final date = DateTime.parse(record['date'] as String);
              final total = (record['total'] as int?) ?? 0;
              final correct = (record['correct'] as int?) ?? (record['score'] as int?) ?? 0;
              final wrong = (record['wrong'] as int?) ?? (total - correct).clamp(0, total).toInt();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assessment, color: blue),
                  title: Text('درست: $correct  |  نادرست: $wrong'),
                  subtitle: Text('${date.year}/${date.month}/${date.day} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResultDetailPage(record: record),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      );
}
