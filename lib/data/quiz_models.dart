class QuizPack {
  final String id;
  final String title;
  final String description;
  final List<Map<String, Object>> questions;

  const QuizPack({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });

  int get questionCount => questions.length;
  int get durationSeconds => questionCount * 30;
}
