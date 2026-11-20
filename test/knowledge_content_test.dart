import 'package:flutter_test/flutter_test.dart';
import 'package:gas_khorasan_jonoubi_learning_app/data/knowledge_content.dart';

void main() {
  group('offline knowledge content', () {
    test('contains articles for all requested work areas', () {
      final areas = knowledgeArticles.map((article) => article.area).toSet();
      expect(areas, containsAll(KnowledgeArea.values));
    });

    test('article identifiers are unique and content is not empty', () {
      final ids = knowledgeArticles.map((article) => article.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final article in knowledgeArticles) {
        expect(article.title.trim(), isNotEmpty);
        expect(article.summary.trim(), isNotEmpty);
        expect(article.sections, isNotEmpty);
        expect(article.keyPoints, isNotEmpty);
      }
    });

    test('every article has an area label', () {
      for (final article in knowledgeArticles) {
        expect(article.area.label.trim(), isNotEmpty);
      }
    });
  });
}
