import 'package:flutter/material.dart';
import 'data/knowledge_content.dart';

const _knowledgeNavy = Color(0xFF123B66);
const _knowledgeBlue = Color(0xFF1976D2);
const _knowledgePale = Color(0xFFEAF3FB);

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) => const KnowledgeBrowserPage(
        title: 'آموزش‌ها',
        description: 'مطالب پایه برای آشنایی با وظایف و اصول عمومی کار در واحدهای مختلف',
        showAreas: true,
      );
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => const KnowledgeBrowserPage(
        title: 'کتابخانه دیجیتال',
        description: 'مجموعه مطالب آفلاین برنامه؛ اسناد رسمی و فایل‌های مصوب در مرحله تکمیل محتوا افزوده می‌شوند',
        showAreas: true,
      );
}

class KnowledgeBrowserPage extends StatefulWidget {
  final String title;
  final String description;
  final bool showAreas;

  const KnowledgeBrowserPage({
    super.key,
    required this.title,
    required this.description,
    this.showAreas = true,
  });

  @override
  State<KnowledgeBrowserPage> createState() => _KnowledgeBrowserPageState();
}

class _KnowledgeBrowserPageState extends State<KnowledgeBrowserPage> {
  final _searchController = TextEditingController();
  KnowledgeArea? _selectedArea;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<KnowledgeArticle> get _filteredArticles {
    final query = _searchController.text.trim().toLowerCase();
    return knowledgeArticles.where((article) {
      final matchesArea = _selectedArea == null || article.area == _selectedArea;
      final haystack = [
        article.title,
        article.summary,
        article.area.label,
        ...article.sections,
        ...article.keyPoints,
      ].join(' ').toLowerCase();
      return matchesArea && (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final articles = _filteredArticles;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('knowledge-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'جست‌وجو در عنوان و متن مطالب',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'پاک کردن جست‌وجو',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (widget.showAreas) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: const Text('همه واحدها'),
                          selected: _selectedArea == null,
                          onSelected: (_) => setState(() => _selectedArea = null),
                        ),
                      ),
                      ...KnowledgeArea.values.map(
                        (area) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(area.label),
                            selected: _selectedArea == area,
                            onSelected: (_) => setState(() => _selectedArea = area),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: articles.isEmpty
              ? const Center(child: Text('مطلبی با این عبارت یا فیلتر پیدا نشد'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: _knowledgePale,
                          child: Icon(_iconFor(article.area), color: _knowledgeNavy),
                        ),
                        title: Text(
                          article.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(article.summary),
                              const SizedBox(height: 5),
                              Text(
                                article.area.label,
                                style: const TextStyle(color: _knowledgeBlue, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => KnowledgeArticlePage(article: article),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

IconData _iconFor(KnowledgeArea area) {
  switch (area) {
    case KnowledgeArea.general:
      return Icons.info_outline;
    case KnowledgeArea.customers:
      return Icons.people_outline;
    case KnowledgeArea.receivables:
      return Icons.receipt_long_outlined;
    case KnowledgeArea.maintenance:
      return Icons.build_outlined;
    case KnowledgeArea.hse:
      return Icons.health_and_safety_outlined;
    case KnowledgeArea.management:
      return Icons.account_tree_outlined;
  }
}

class KnowledgeArticlePage extends StatelessWidget {
  final KnowledgeArticle article;

  const KnowledgeArticlePage({super.key, required this.article});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(article.area.label)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              article.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _knowledgeNavy),
            ),
            const SizedBox(height: 8),
            Text(article.summary, style: const TextStyle(fontSize: 15, color: Colors.black54)),
            const SizedBox(height: 18),
            ...article.sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(section, style: const TextStyle(fontSize: 16, height: 1.75)),
              ),
            ),
            const SizedBox(height: 4),
            Card(
              color: _knowledgePale,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نکات کلیدی', style: TextStyle(fontWeight: FontWeight.bold, color: _knowledgeNavy)),
                    const SizedBox(height: 8),
                    ...article.keyPoints.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 19, color: _knowledgeBlue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(point, style: const TextStyle(height: 1.5))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'یادآوری: این مطلب آموزشی عمومی است و جایگزین بخشنامه، دستورالعمل فنی، مقررات جاری یا آموزش تخصصی مصوب شرکت گاز نیست. برای اقدام عملی، همیشه آخرین سند رسمی و نظر مسئول ذی‌صلاح را ملاک قرار دهید.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      );
}
