import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF123B66);
const blue = Color(0xFF1976D2);
const paleBlue = Color(0xFFEAF3FB);
const examDurationPerQuestion = 30;

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
          appBarTheme: const AppBarTheme(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
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
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF073B86),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widthByScreen = constraints.maxWidth * 0.88;
              final widthByHeight = constraints.maxHeight * 0.86 * 2 / 3;
              final posterWidth = widthByScreen < widthByHeight
                  ? widthByScreen
                  : widthByHeight;
              final posterHeight = posterWidth * 1.5;

              return Center(
                child: SizedBox(
                  width: posterWidth,
                  height: posterHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/splash.webp',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF073B86),
                          child: Center(
                            child: Icon(Icons.local_fire_department,
                                color: Colors.white, size: 72),
                          ),
                        ),
                      ),
                      Positioned(
                        left: posterWidth * 0.045,
                        top: posterHeight * 0.39,
                        width: posterWidth * 0.91,
                        height: posterHeight * 0.23,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5FAFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF1976D2), width: 1.2),
                          ),
                          child: const Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _SplashSymbolLine(
                                  number: '۱',
                                  text:
                                      '«لا»: نفی وابستگی به شرق و غرب و بیانگر ملی بودن صنعت نفت.',
                                ),
                                _SplashSymbolLine(
                                  number: '۲',
                                  text:
                                      'فرم‌های اسلیمی: بیانگر رشد و شکوفایی صنایع عظیم نفت و گاز ایران.',
                                ),
                                _SplashSymbolLine(
                                  number: '۳',
                                  text:
                                      'مشعل: نشان سوخت و بیانگر نقش نفت در حیات صنایع است.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _SplashSymbolLine extends StatelessWidget {
  final String number;
  final String text;

  const _SplashSymbolLine({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF123B66),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF102C4B),
                fontSize: 11.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}

class HomePageclass HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  void goTo(int value) => setState(() => index = value);

  Future<void> _handleBack(BuildContext context) async {
    if (index != 0) {
      goTo(0);
      return;
    }
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
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onNavigate: goTo),
      const ExamPage(),
      const TrainingPage(),
      const LibraryPage(),
      const ResultsPage(),
    ];
    const titles = ['داشبورد', 'آزمون‌ها', 'راهنمای استفاده', 'کتابخانه دیجیتال', 'نتایج'];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack(context));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(titles[index])),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: goTo,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'خانه'),
            NavigationDestination(
                icon: Icon(Icons.quiz_outlined), label: 'آزمون'),
            NavigationDestination(
                icon: Icon(Icons.play_lesson_outlined), label: 'راهنما'),
            NavigationDestination(
                icon: Icon(Icons.local_library_outlined), label: 'کتابخانه'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined), label: 'نتایج'),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('به سامانه آموزش خوش آمدید',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('یادگیری، مرور مطالب و سنجش آموخته‌ها',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('دسترسی سریع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.quiz,
            title: 'آزمون‌های چهارگزینه‌ای',
            subtitle: 'پاسخ به پرسش‌ها و ثبت نتیجه',
            onTap: () => onNavigate(1),
          ),
          _MenuTile(
            icon: Icons.menu_book,
            title: 'راهنمای استفاده از برنامه',
            subtitle: 'آشنایی مرحله‌به‌مرحله با امکانات برنامه',
            onTap: () => onNavigate(2),
          ),
          _MenuTile(
            icon: Icons.local_library,
            title: 'کتابخانه دیجیتال',
            subtitle: 'دسترسی به منابع و جزوه‌ها',
            onTap: () => onNavigate(3),
          ),
          _MenuTile(
            icon: Icons.assessment,
            title: 'سوابق آزمون',
            subtitle: 'مشاهده نتایج ذخیره‌شده',
            onTap: () => onNavigate(4),
          ),
        ],
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: paleBlue,
            child: Icon(icon, color: navy),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}

class ExamQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ExamQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  Map<String, Object> toJson() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
        text: json['text'] as String,
        options: List<String>.from(json['options'] as List),
        correctIndex: json['correctIndex'] as int,
        explanation: (json['explanation'] as String?) ?? '',
      );
}

class ExamEvaluation {
  final int correct;
  final int wrong;
  final int unanswered;

  const ExamEvaluation({
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  int get total => correct + wrong + unanswered;

  factory ExamEvaluation.calculate(
    List<ExamQuestion> questions,
    List<int?> answers,
  ) {
    if (questions.length != answers.length) {
      throw ArgumentError('تعداد پاسخ‌ها باید با تعداد سؤال‌ها برابر باشد.');
    }
    var correct = 0;
    var wrong = 0;
    var unanswered = 0;
    for (var i = 0; i < questions.length; i++) {
      final answer = answers[i];
      if (answer == null) {
        unanswered++;
      } else if (answer == questions[i].correctIndex) {
        correct++;
      } else {
        wrong++;
      }
    }
    return ExamEvaluation(
        correct: correct, wrong: wrong, unanswered: unanswered);
  }
}

// These are demonstration questions only. Replace them with reviewed,
// organization-approved question banks before publishing a formal course.
const sampleQuestions = <ExamQuestion>[
  ExamQuestion(
    text: 'هدف اصلی آموزش ایمنی در محیط کار چیست؟',
    options: [
      'افزایش سرعت کار',
      'پیشگیری از حادثه و کاهش خطر',
      'افزایش هزینه‌ها',
      'حذف دستورالعمل‌ها'
    ],
    correctIndex: 1,
    explanation: 'هدف آموزش ایمنی، شناسایی و کنترل خطرها و پیشگیری از حادثه است.',
  ),
  ExamQuestion(
    text: 'در صورت مشاهده وضعیت ناایمن چه باید کرد؟',
    options: [
      'بی‌توجهی کرد',
      'موضوع را گزارش و طبق دستورالعمل اقدام کرد',
      'کار را پنهانی ادامه داد',
      'تجهیزات حفاظتی را کنار گذاشت'
    ],
    correctIndex: 1,
    explanation: 'گزارش شرایط ناایمن و پیروی از رویه مصوب ضروری است.',
  ),
  ExamQuestion(
    text: 'پیش از استفاده از تجهیزات باید چه کاری انجام داد؟',
    options: [
      'بررسی سلامت و ایمنی تجهیزات',
      'تغییر خودسرانه تنظیمات',
      'حذف حفاظ‌ها',
      'استفاده بدون بررسی'
    ],
    correctIndex: 0,
    explanation: 'تجهیزات باید پیش از استفاده از نظر سلامت و ایمنی بررسی شوند.',
  ),
];

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final List<ExamQuestion> questions = sampleQuestions;
  List<int?> answers = [];
  int currentQuestion = 0;
  int remainingSeconds = 0;
  Timer? timer;
  bool started = false;
  bool finished = false;
  bool saving = false;
  Map<String, Object>? lastResult;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _startExam() {
    timer?.cancel();
    setState(() {
      answers = List<int?>.filled(questions.length, null);
      currentQuestion = 0;
      remainingSeconds = questions.length * examDurationPerQuestion;
      started = true;
      finished = false;
      saving = false;
      lastResult = null;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || finished) return;
      if (remainingSeconds <= 1) {
        _finishExam(timeExpired: true);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void _finishExam({bool timeExpired = false}) {
    if (finished) return;
    timer?.cancel();
    final evaluation = ExamEvaluation.calculate(questions, answers);
    final result = <String, Object>{
      'date': DateTime.now().toIso8601String(),
      'correct': evaluation.correct,
      'wrong': evaluation.wrong,
      'unanswered': evaluation.unanswered,
      'total': evaluation.total,
      'timeExpired': timeExpired,
      'questions': questions.map((q) => q.toJson()).toList(),
      'answers': answers.map((answer) => answer ?? -1).toList(),
    };
    setState(() {
      finished = true;
      saving = true;
      lastResult = result;
    });
    _saveResult(result);
  }

  Future<void> _saveResult(Map<String, Object> result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getStringList('exam_results') ?? <String>[];
      old.insert(0, jsonEncode(result));
      await prefs.setStringList('exam_results', old.take(100).toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ذخیره نتیجه ناموفق بود؛ فضای ذخیره‌سازی را بررسی کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (finished && lastResult != null) {
      return _ExamResultView(
        result: lastResult!,
        saving: saving,
        onRetry: _startExam,
      );
    }
    if (!started) {
      final totalSeconds = questions.length * examDurationPerQuestion;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: navy),
              const SizedBox(height: 16),
              const Text('آزمون نمونه ایمنی',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '${questions.length} سؤال • زمان: ${_formatTime(totalSeconds)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'این پرسش‌ها نمونه آموزشی هستند و محتوای رسمی شرکت محسوب نمی‌شوند.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _startExam,
                icon: const Icon(Icons.play_arrow),
                label: const Text('شروع آزمون'),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[currentQuestion];
    final selected = answers[currentQuestion];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('سؤال ${currentQuestion + 1} از ${questions.length}'),
            Chip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: Text(_formatTime(remainingSeconds)),
              backgroundColor:
                  remainingSeconds <= 30 ? Colors.red.shade50 : paleBlue,
            ),
          ],
        ),
        LinearProgressIndicator(
            value: (currentQuestion + 1) / questions.length),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List<Widget>.generate(questions.length, (index) {
            final isCurrent = index == currentQuestion;
            final isAnswered = answers[index] != null;
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(42, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: isCurrent
                    ? navy
                    : isAnswered
                        ? Colors.green.shade50
                        : null,
                foregroundColor: isCurrent ? Colors.white : navy,
              ),
              onPressed: () => setState(() => currentQuestion = index),
              child: Text((index + 1).toString()),
            );
          }),
        ),
        const SizedBox(height: 18),
        Text(question.text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        RadioGroup<int>(
          groupValue: selected,
          onChanged: (value) {
            if (value == null) return;
            setState(() => answers[currentQuestion] = value);
          },
          child: Column(
            children: List<Widget>.generate(
              question.options.length,
              (index) => Card(
                child: RadioListTile<int>(
                  value: index,
                  title: Text(question.options[index]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentQuestion == 0
                    ? null
                    : () => setState(() => currentQuestion--),
                icon: const Icon(Icons.chevron_right),
                label: const Text('قبلی'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: currentQuestion == questions.length - 1
                    ? () => _confirmFinish()
                    : () => setState(() => currentQuestion++),
                icon: Icon(currentQuestion == questions.length - 1
                    ? Icons.check
                    : Icons.chevron_left),
                label: Text(currentQuestion == questions.length - 1
                    ? 'پایان آزمون'
                    : 'بعدی'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _confirmFinish(),
          child: const Text('پایان دادن به آزمون'),
        ),
        Text(
           'پاسخ داده‌شده: ${answers.where((answer) => answer != null).length}  |  بی‌پاسخ: ${answers.where((answer) => answer == null).length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Future<void> _confirmFinish() async {
    final unanswered = answers.where((answer) => answer == null).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('پایان آزمون'),
        content: Text(unanswered == 0
            ? 'آیا از ثبت نهایی پاسخ‌ها مطمئن هستید؟'
            : '$unanswered سؤال بی‌پاسخ مانده است. آیا آزمون پایان یابد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('بازگشت به آزمون'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ثبت نتیجه'),
          ),
        ],
      ),
    );
    if (confirmed == true) _finishExam();
  }
}

class _ExamResultView extends StatelessWidget {
  final Map<String, Object> result;
  final bool saving;
  final VoidCallback onRetry;

  const _ExamResultView({
    required this.result,
    required this.saving,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final correct = result['correct'] as int;
    final wrong = result['wrong'] as int;
    final unanswered = result['unanswered'] as int;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.emoji_events, color: blue, size: 64),
        const SizedBox(height: 8),
        const Text('نتیجه آزمون',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        if (result['timeExpired'] == true)
          const Text('زمان آزمون به پایان رسید.',
              textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _ResultCategory(
          title: 'پاسخ‌های صحیح',
          count: correct,
          color: Colors.green,
          onTap: () => _showQuestions(context, result, 'correct'),
        ),
        _ResultCategory(
          title: 'پاسخ‌های غلط',
          count: wrong,
          color: Colors.red,
          onTap: () => _showQuestions(context, result, 'wrong'),
        ),
        _ResultCategory(
          title: 'سؤال‌های بی‌پاسخ',
          count: unanswered,
          color: Colors.orange,
          onTap: () => _showQuestions(context, result, 'unanswered'),
        ),
        const SizedBox(height: 14),
        if (saving)
          const Center(child: CircularProgressIndicator())
        else
          const Text('نتیجه در سوابق همین دستگاه ذخیره شد.',
              textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('آزمون مجدد')),
      ],
    );
  }

  void _showQuestions(
      BuildContext context, Map<String, Object> result, String category) {
    final questions = (result['questions'] as List)
        .map((item) =>
            ExamQuestion.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final answers = List<int>.from(result['answers'] as List);
    final indices = <int>[];
    for (var i = 0; i < questions.length; i++) {
      final answer = answers[i];
      final isCorrect = answer == questions[i].correctIndex;
      if ((category == 'correct' && isCorrect) ||
          (category == 'wrong' && answer >= 0 && !isCorrect) ||
          (category == 'unanswered' && answer < 0)) {
        indices.add(i);
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _QuestionReviewPage(
          questions: questions,
          answers: answers,
          indices: indices,
          title: category == 'correct'
              ? 'پاسخ‌های صحیح'
              : category == 'wrong'
                  ? 'پاسخ‌های غلط'
                  : 'سؤال‌های بی‌پاسخ',
        ),
      ),
    );
  }
}

class _ResultCategory extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ResultCategory({
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(count.toString(),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold)),
          ),
          title: Text(title),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}

class _QuestionReviewPage extends StatelessWidget {
  final List<ExamQuestion> questions;
  final List<int> answers;
  final List<int> indices;
  final String title;

  const _QuestionReviewPage({
    required this.questions,
    required this.answers,
    required this.indices,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: indices.isEmpty
            ? const Center(child: Text('موردی برای نمایش وجود ندارد.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: indices.length,
                itemBuilder: (context, position) {
                  final index = indices[position];
                  final question = questions[index];
                  final answer = answers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سؤال ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: navy)),
                          const SizedBox(height: 8),
                          Text(question.text,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ...List<Widget>.generate(4, (optionIndex) {
                            final isCorrect =
                                optionIndex == question.correctIndex;
                            final isChosen = optionIndex == answer;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isCorrect
                                    ? Icons.check_circle
                                    : isChosen
                                        ? Icons.cancel
                                        : Icons.circle_outlined,
                                color: isCorrect
                                    ? Colors.green
                                    : isChosen
                                        ? Colors.red
                                        : Colors.black26,
                              ),
                              title: Text(question.options[optionIndex]),
                              subtitle: isChosen
                                  ? const Text('پاسخ انتخاب‌شده')
                                  : null,
                            );
                          }),
                          if (question.explanation.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('توضیح: ${question.explanation}'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  static const guides = <_GuideSection>[
    _GuideSection(
      title: 'آشنایی با صفحه اصلی',
      icon: Icons.dashboard_outlined,
      summary: 'از نوار پایین صفحه برای رفتن به داشبورد، آزمون‌ها، راهنما، کتابخانه و نتایج استفاده کنید.',
      example: 'مثال: برای شروع آزمون، گزینه «آزمون» را از نوار پایین انتخاب کنید؛ برای برگشت به صفحه اول، «خانه» را بزنید.',
    ),
    _GuideSection(
      title: 'استفاده از کتابخانه دیجیتال',
      icon: Icons.local_library_outlined,
      summary: 'کتابخانه محل مراجعه به اسناد، فایل‌ها، فرم‌ها و دستورالعمل‌های تأییدشده است.',
      example: 'مثال: وارد «کتابخانه دیجیتال» شوید، دسته موردنظر مثل HSE را انتخاب و نام سند را جست‌وجو کنید. پس از افزودن اسناد رسمی، از همین بخش قابل دسترسی خواهند بود.',
    ),
    _GuideSection(
      title: 'شرکت در آزمون',
      icon: Icons.quiz_outlined,
      summary: 'پیش از شروع، تعداد سؤال‌ها و زمان آزمون نمایش داده می‌شود. برای هر سؤال ۳۰ ثانیه در نظر گرفته شده است.',
      example: 'مثال: گزینه پاسخ را لمس کنید؛ با «بعدی» به سؤال بعد بروید یا از شماره سؤال‌ها برای جابه‌جایی استفاده کنید. تا پایان آزمون می‌توانید پاسخ را تغییر دهید.',
    ),
    _GuideSection(
      title: 'پایان آزمون و مشاهده نتیجه',
      icon: Icons.assessment_outlined,
      summary: 'پس از پایان زمان یا ثبت نهایی، تعداد پاسخ‌های صحیح، غلط و بی‌پاسخ نمایش داده می‌شود.',
      example: 'مثال: روی «پاسخ‌های غلط» بزنید تا سؤال‌ها، گزینه انتخابی شما و پاسخ صحیح را ببینید. نتیجه‌های ذخیره‌شده در بخش «نتایج» قابل مرور هستند.',
    ),
    _GuideSection(
      title: 'استفاده آفلاین',
      icon: Icons.wifi_off_outlined,
      summary: 'امکانات و فایل‌هایی که داخل نسخه نصب‌شده برنامه قرار گرفته‌اند، بدون اینترنت در دسترس‌اند.',
      example: 'مثال: اینترنت گوشی را خاموش و برنامه را باز کنید. محتوای داخلی و سوابق ذخیره‌شده روی همان دستگاه در دسترس می‌مانند؛ دریافت به‌روزرسانی یا محتوای جدید به اینترنت نیاز دارد.',
    ),
    _GuideSection(
      title: 'خرید و بازیابی دسترسی',
      icon: Icons.shopping_bag_outlined,
      summary: 'در نسخه‌ای که خرید یک‌باره فعال شود، دسترسی دائمی با حساب فروشگاه و قابلیت بازیابی خرید مدیریت خواهد شد.',
      example: 'مثال: پس از تعویض گوشی، با همان حساب فروشگاه گزینه بازیابی خرید را می‌زنید. این قابلیت تا زمان پیاده‌سازی و تأیید نهایی پرداخت، فعال‌شده محسوب نمی‌شود.',
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('راهنمای استفاده از برنامه',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('راهنمای گام‌به‌گام امکانات برنامه همراه با مثال‌های ساده. برای دیدن توضیحات هر بخش، آن را باز کنید.'),
          const SizedBox(height: 10),
          ...guides.map((guide) => Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: paleBlue,
                    child: Icon(guide.icon, color: navy),
                  ),
                  title: Text(guide.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(guide.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(guide.example),
                    ),
                  ],
                ),
              )),
        ],
      );
}

class _GuideSection {
  final String title;
  final IconData icon;
  final String summary;
  final String example;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.summary,
    required this.example,
  });
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          Text('کتابخانه دیجیتال',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          _InfoCard(
            icon: Icons.picture_as_pdf,
            title: 'جزوه‌های آموزشی',
            body:
                'زیرساخت نمایش فایل‌های آفلاین در مرحله تکمیل منابع رسمی قرار دارد.',
          ),
          _InfoCard(
            icon: Icons.book,
            title: 'دستورالعمل‌ها و منابع',
            body:
                'نسخه‌های تأییدشده دستورالعمل‌ها پس از دریافت در این بخش قرار می‌گیرند.',
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: blue, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('exam_results') ?? <String>[];
    final output = <Map<String, dynamic>>[];
    for (final item in stored) {
      try {
        output.add(Map<String, dynamic>.from(jsonDecode(item) as Map));
      } catch (_) {
        // Ignore a damaged historical entry without hiding valid records.
      }
    }
    return output;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('بارگذاری سوابق ناموفق بود.'));
          }
          final results = snapshot.data ?? <Map<String, dynamic>>[];
          if (results.isEmpty) {
            return const Center(child: Text('هنوز نتیجه‌ای ثبت نشده است.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final date = DateTime.tryParse(result['date'] as String? ?? '');
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assessment, color: blue),
                  title: Text('صحیح: ${result['correct'] ?? 0}  |  غلط: ${result['wrong'] ?? 0}'),
                  subtitle: Text(
                    'بی‌پاسخ: ${result['unanswered'] ?? 0}${date == null ? '' : '  •  ${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}'}',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    final questions = (result['questions'] as List)
                        .map((item) => ExamQuestion.fromJson(
                            Map<String, dynamic>.from(item as Map)))
                        .toList();
                    final answers = List<int>.from(result['answers'] as List);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _QuestionReviewPage(
                          questions: questions,
                          answers: answers,
                          indices: List<int>.generate(questions.length, (i) => i),
                          title: 'مرور آزمون',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      );
}
