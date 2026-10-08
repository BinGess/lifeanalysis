import 'dart:convert';
import 'package:flutter/services.dart';
import '../models.dart';

class GuideArticle {
  final String title, markdown, path, intro, chapterTitle;
  final int? chapter, number, line;
  GuideArticle.fromJson(Map<String, dynamic> j)
    : title = j['title'],
      markdown = j['markdown'],
      path = j['path'],
      intro = j['intro'] ?? '',
      chapterTitle = j['chapterTitle'] ?? '',
      chapter = j['chapter'],
      number = j['number'],
      line = j['line'];
}

class GuideSources {
  final String revision, syncedOn, repository;
  final List<GuideArticle> entries, documents;
  GuideSources.fromJson(Map<String, dynamic> j)
    : revision = j['revision'],
      syncedOn = j['syncedOn'],
      repository = j['repository'],
      entries = (j['entries'] as List)
          .map((x) => GuideArticle.fromJson(x))
          .toList(),
      documents = (j['documents'] as List)
          .map((x) => GuideArticle.fromJson(x))
          .toList();

  static GuideSources? _cache;
  static Future<GuideSources> load() async {
    return _cache ??= GuideSources.fromJson(
      jsonDecode(await rootBundle.loadString('assets/guide/sources.json')),
    );
  }

  // Punctuation and whitespace differences are safe; never fuzzy-match titles.
  static String normalized(String text) => text
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '')
      .toLowerCase();

  String _title(Citation c) {
    if (c.title.trim().isNotEmpty) return normalized(c.title);
    final match = RegExp(
      r'第\s*\d+\s*(?:节|章)\s*第\s*\d+\s*条\s*[（(](.+)[）)]',
    ).firstMatch(c.label);
    return match == null ? '' : normalized(match[1]!);
  }

  GuideArticle? resolve(Citation c) {
    final source = c.sourceType ?? '';
    if (source.startsWith('长文')) {
      final name = source.replaceFirst(RegExp(r'^长文[·・：:\s]*'), '');
      final names = [
        name,
        c.title,
        c.label,
      ].where((x) => x.trim().isNotEmpty).map(normalized).toSet();
      final matches = documents
          .where(
            (d) =>
                names.contains(normalized(d.title)) ||
                names.contains(
                  normalized(d.path.split('/').last.replaceFirst('.md', '')),
                ),
          )
          .toList();
      return matches.length == 1 ? matches.single : null;
    }
    if (source.isNotEmpty && source != 'book') return null;
    final label = RegExp(
      r'第\s*(\d+)\s*(?:节|章)\s*第\s*(\d+)\s*条',
    ).firstMatch(c.label);
    final chapter = c.chapterNo ?? int.tryParse(label?[1] ?? '');
    final number = c.entryNo ?? int.tryParse(label?[2] ?? '');
    final title = _title(c);
    final numbered = entries.where(
      (e) => e.chapter == chapter && e.number == number,
    );
    if (numbered.length == 1 &&
        (title.isEmpty || normalized(numbered.single.title) == title)) {
      return numbered.single;
    }
    // A title can survive renumbering. Restrict to its cited chapter when known.
    if (title.isNotEmpty) {
      final matches = entries
          .where(
            (e) =>
                (chapter == null || e.chapter == chapter) &&
                normalized(e.title) == title,
          )
          .toList();
      if (matches.length == 1) return matches.single;
    }
    return null;
  }

  Uri sourceUrl(GuideArticle article) => Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: [
      'eternity4719',
      'HowToLiveBetter',
      'blob',
      revision,
      ...article.path.split('/'),
    ],
    queryParameters: article.line == null ? null : {'plain': '1'},
    fragment: article.line == null ? null : 'L${article.line}',
  );

  Uri resolveLink(GuideArticle article, String href) {
    return sourceUrl(article).replace(query: '', fragment: '').resolve(href);
  }
}
