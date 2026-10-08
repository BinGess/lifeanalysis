import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:life_guide/models.dart';
import 'package:life_guide/services/guide_sources.dart';
import 'package:life_guide/ui/citation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GuideSources sources;
  setUpAll(() {
    sources = GuideSources.fromJson(
      jsonDecode(File('assets/guide/sources.json').readAsStringSync()),
    );
  });
  test(
    'book identifiers persist and resolve full source including limitations',
    () {
      final source = sources.entries.firstWhere(
        (e) => e.chapter == 4 && e.number == 18,
      );
      final citation = Citation.fromJson({
        'chapter_no': '4',
        'entry_no': 18,
        'title': source.title,
        'source_type': 'book',
      });
      final restored = Citation.fromJson(citation.toJson());
      expect(restored.chapterNo, 4);
      expect(restored.entryNo, 18);
      expect(sources.resolve(restored), same(source));
      expect(source.markdown, contains('来源：'));
      expect(source.markdown, contains('备注：'));
      expect(sources.sourceUrl(source).toString(), contains(sources.revision));
      expect(sources.sourceUrl(source).fragment, startsWith('L'));
    },
  );
  test('old stored citations resolve by the readable label', () {
    final legacy = Citation(title: '', label: '第 4 节第 18 条');
    expect(sources.resolve(legacy)?.number, 18);
  });
  test(
    'mismatched or unknown citations never show an unrelated numbered entry',
    () {
      expect(
        sources.resolve(
          Citation(
            title: '不在项目中的标题',
            label: '第4节第18条',
            chapterNo: 4,
            entryNo: 18,
          ),
        ),
        isNull,
      );
      expect(sources.resolve(Citation(title: '', label: '第999节第1条')), isNull);
      expect(sources.resolve(Citation(title: '', label: '无法定位')), isNull);
    },
  );
  test('renumbered references can only match an exact unique title', () {
    final source = sources.entries.firstWhere(
      (e) => e.chapter == 4 && e.number == 18,
    );
    expect(
      sources.resolve(
        Citation(
          title: source.title,
          label: '第4节第99条',
          chapterNo: 4,
          entryNo: 99,
        ),
      ),
      same(source),
    );
    expect(
      sources.resolve(
        Citation(title: source.title.substring(0, 5), label: '第4节第99条'),
      ),
      isNull,
    );
  });
  test(
    'long articles resolve by their declared source without book fallback',
    () {
      final article = sources.resolve(
        Citation(title: '正文某小节', label: '长文', sourceType: '长文·生物钟和夜班'),
      );
      expect(article?.path, 'docs/生物钟和夜班.md');
      expect(article?.markdown, contains('视交叉上核'));
      expect(
        sources.resolve(
          Citation(title: '', label: '第4节第18条', sourceType: '长文·不存在'),
        ),
        isNull,
      );
    },
  );
  test(
    'relative source links stay pinned and external citations stay unchanged',
    () {
      final article = sources.entries.first;
      final uri = sources.resolveLink(article, '../README.md');
      expect(
        uri.path,
        '/eternity4719/HowToLiveBetter/blob/${sources.revision}/README.md',
      );
      expect(
        sources
            .resolveLink(article, 'https://doi.org/10.1000/example')
            .toString(),
        'https://doi.org/10.1000/example',
      );
    },
  );
  testWidgets('unresolved citation presents a clear fallback', (tester) async {
    await tester.runAsync(() => GuideSources.load());
    await tester.pumpWidget(
      MaterialApp(
        home: CitationPage(
          citation: Citation(title: '', label: '第999节第999条'),
          openExternal: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂未找到对应原文'), findsOneWidget);
    expect(find.text('查看原项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
