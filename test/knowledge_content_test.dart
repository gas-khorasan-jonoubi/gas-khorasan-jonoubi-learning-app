import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/knowledge_content.dart';

void main() {
  group('offline knowledge content', () {
    test('contains 24 offline articles for all requested work areas', () {
      expect(knowledgeArticles, hasLength(24));
      final areas = knowledgeArticles.map((article) => article.area).toSet();
      expect(areas, containsAll(KnowledgeArea.values));
    });

    test('each work area has four articles', () {
      for (final area in KnowledgeArea.values) {
        final articlesForArea =
            knowledgeArticles.where((article) => article.area == area);
        expect(
          articlesForArea,
          hasLength(4),
          reason: area.label,
        );
      }
    });

    test('article identifiers are unique and content is not empty', () {
      final ids = knowledgeArticles.map((article) => article.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final article in knowledgeArticles) {
        expect(article.title.trim(), isNotEmpty);
        expect(article.summary.trim(), isNotEmpty);
        expect(article.sections, isNotEmpty);
        expect(article.sections.every((section) => section.trim().isNotEmpty), isTrue);
        expect(article.keyPoints, isNotEmpty);
        expect(article.keyPoints.every((point) => point.trim().isNotEmpty), isTrue);
      }
    });

    test('every article has an area label', () {
      for (final article in knowledgeArticles) {
        expect(article.area.label.trim(), isNotEmpty);
      }
    });
  });
}
