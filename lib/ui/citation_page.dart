import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models.dart';
import 'app_theme.dart';
import '../services/guide_sources.dart';

class CitationPage extends StatefulWidget {
  final Citation citation;
  final Future<void> Function(BuildContext, String?) openExternal;
  const CitationPage({
    super.key,
    required this.citation,
    required this.openExternal,
  });
  @override
  State<CitationPage> createState() => _CitationPageState();
}

class _CitationPageState extends State<CitationPage> {
  late Future<GuideSources> sources = GuideSources.load();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('引用原文')),
    body: SafeArea(
      child: FutureBuilder<GuideSources>(
        future: sources,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('原文加载失败，请重试。'),
                  TextButton(
                    onPressed: () =>
                        setState(() => sources = GuideSources.load()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final library = snapshot.data!;
          final article = library.resolve(widget.citation);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppTheme.pageWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                children: [
                  Text(
                    widget.citation.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '原项目正文 · 同步于 ${library.syncedOn}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '服务端未提供知识版本，以下原文快照可能与生成回答时的资料不同。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  if (article == null) ...[
                    const Text(
                      '暂未找到对应原文',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '引用编号或标题与当前收录版本不一致，未展示其他条目代替。可以到原项目核对。',
                      style: TextStyle(height: 1.7),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.openExternal(context, library.repository),
                      child: const Text('查看原项目'),
                    ),
                  ] else ...[
                    if (article.chapterTitle.isNotEmpty)
                      Text(
                        article.chapterTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    if (article.intro.isNotEmpty)
                      ExpansionTile(
                        title: const Text('本节阅读说明'),
                        // Selection widgets get an isolated storage scope from the tile.
                        children: [
                          PageStorage(
                            bucket: PageStorageBucket(),
                            child: markdown(article.intro, library, article),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    SoftCard(
                      padding: const EdgeInsets.all(20),
                      child: markdown(article.markdown, library, article),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => widget.openExternal(
                        context,
                        library.sourceUrl(article).toString(),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('在 GitHub 查看原文'),
                    ),
                  ],
                  const Divider(height: 36),
                  const Text(
                    '来源：高性价比人生指南 · eternity4719/HowToLiveBetter 及贡献者',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                  const Text(
                    '正文未改写，仅拆分条目并调整排版。',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.openExternal(context, library.repository),
                        child: const Text('原项目'),
                      ),
                      TextButton(
                        onPressed: () => widget.openExternal(
                          context,
                          'https://creativecommons.org/licenses/by/4.0/',
                        ),
                        child: const Text('CC BY 4.0'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget markdown(String text, GuideSources library, GuideArticle article) =>
      MarkdownBody(
        data: text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ''),
        selectable: true,
        onTapLink: (_, href, _) {
          if (href != null) {
            widget.openExternal(
              context,
              library.resolveLink(article, href).toString(),
            );
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: Theme.of(context).textTheme.bodyLarge,
          listBullet: Theme.of(context).textTheme.bodyLarge,
        ),
      );
}
