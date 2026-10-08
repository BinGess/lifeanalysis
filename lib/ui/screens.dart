import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/api.dart';
import 'dictation_sheet.dart';
import 'citation_page.dart';
import 'app_theme.dart';
import 'ai_consent.dart';
import 'popular_questions.dart';

const gap = SizedBox(height: 20);
Widget pageBody(List<Widget> children) => LayoutBuilder(
  builder: (context, constraints) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppTheme.pageWidth),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 360 ? 16 : 24,
          16,
          constraints.maxWidth < 360 ? 16 : 24,
          40,
        ),
        children: children,
      ),
    ),
  ),
);
Widget hint(String text) => Builder(
  builder: (context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall),
);
Widget notice(String text, {bool error = false}) => Builder(
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          height: 1.6,
          color: error ? colors.onErrorContainer : colors.onSurface,
        ),
      ),
    );
  },
);
void tell(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;
void openResult(
  BuildContext context,
  AppState state,
  String sessionId, {
  String? turnId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) =>
        ResultPage(state: state, sessionId: sessionId, initialTurnId: turnId),
  ),
);
Future<void> openLink(BuildContext context, String? href) async {
  final uri = href == null ? null : Uri.tryParse(href);
  if (uri == null) {
    tell(context, '这个链接暂时无法打开。');
    return;
  }
  if (uri.scheme == 'mailto') {
    try {
      if (!await launchUrl(uri) && context.mounted) {
        tell(context, '暂时无法打开邮件应用。');
      }
    } catch (_) {
      if (context.mounted) tell(context, '暂时无法打开邮件应用。');
    }
    return;
  }
  if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
    tell(context, '这个链接暂时无法打开。');
    return;
  }
  if (!await confirm(context, '打开原始链接？', uri.toString())) return;
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      tell(context, '暂时无法打开链接。');
    }
  } catch (_) {
    if (context.mounted) tell(context, '暂时无法打开链接。');
  }
}

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final TextEditingController question;
  List<String> popularQuestions = pickPopularQuestions();
  int tab = 0;
  ActionState filter = ActionState.planned;
  AppState get s => widget.state;
  @override
  void initState() {
    super.initState();
    question = TextEditingController(text: s.draft);
    s.addListener(syncDraft);
    WidgetsBinding.instance.addObserver(this);
    unawaited(s.checkHealth());
  }

  void syncDraft() {
    if (question.text != s.draft) question.text = s.draft;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(s.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.removeListener(syncDraft);
    question.dispose();
    super.dispose();
  }

  bool consentPending = false;
  Future<void> submit([String? selectedQuestion]) async {
    if (consentPending) return;
    final text = selectedQuestion ?? question.text;
    consentPending = true;
    final allowed = await ensureAiConsent(context, s);
    consentPending = false;
    if (!allowed || !mounted) return;
    try {
      final session = s.start(text);
      question.clear();
      FocusScope.of(context).unfocus();
      openResult(context, s, session.id);
    } on ApiFailure catch (e) {
      tell(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(['高性价比人生指南', '我的行动', '我的'][tab])),
      body: SafeArea(
        child: tab == 0
            ? home()
            : tab == 1
            ? actionList()
            : myPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() {
          if (value == 0 && tab != 0) {
            popularQuestions = pickPopularQuestions(previous: popularQuestions);
          }
          tab = value;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '人生指南',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: '我的行动',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    ),
  );
  Widget home() => pageBody([
    const SizedBox(height: 16),
    SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '说说你正在考虑的事',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('question-input'),
            controller: question,
            minLines: 5,
            maxLines: 8,
            maxLength: 5000,
            style: const TextStyle(fontSize: 16, height: 1.6),
            onChanged: (value) {
              s.setDraft(value);
              setState(() {});
            },
            decoration: const InputDecoration(
              hintText: '比如：每天通勤两小时，\n要不要搬到公司附近？',
              counterText: '',
              labelText: '你的问题',
              alignLabelWithHint: true,
            ),
          ),
          VoiceInputButton(
            controller: question,
            enabled: !s.busy,
            onChanged: (value) {
              s.setDraft(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('analyze-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: Theme.of(context).colorScheme.primary,
              disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: s.busy
                ? () => openResult(
                    context,
                    s,
                    s.activeSessionId!,
                    turnId: s.activeTurnId,
                  )
                : question.text.trim().isEmpty
                ? null
                : submit,
            icon: const Icon(Icons.arrow_forward_rounded, size: 21),
            iconAlignment: IconAlignment.end,
            label: Text(s.busy ? '查看回答进度' : '帮我分析'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 28),
    Text('热门问题', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    SoftCard(
      child: Column(
        children: [
          for (var i = 0; i < popularQuestions.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 20, endIndent: 20),
            ListTile(
              key: ValueKey('popular-question-$i'),
              title: Text(popularQuestions[i]),
              trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
              enabled: !s.busy,
              onTap: s.busy ? null : () => submit(popularQuestions[i]),
            ),
          ],
        ],
      ),
    ),
    if (s.storageError != null) ...[gap, notice(s.storageError!, error: true)],
  ]);
  Widget actionList() => pageBody([
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ActionState.values
          .map(
            (x) => ChoiceChip(
              label: Text(x.label),
              selected: filter == x,
              onSelected: (_) => setState(() => filter = x),
            ),
          )
          .toList(),
    ),
    gap,
    if (!s.actions.any((x) => x.state == filter)) ...[
      const SizedBox(height: 40),
      Icon(
        Icons.checklist_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      gap,
      const Center(child: Text('这里还没有行动')),
      gap,
      Center(child: hint('从完整回答中，记下一件愿意开始的事。')),
    ],
    ...s.actions
        .where((a) => a.state == filter)
        .toList()
        .reversed
        .map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                title: Text(a.title),
                subtitle: Text(
                  a.firstStep,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActionPage(state: s, actionId: a.id),
                  ),
                ),
              ),
            ),
          ),
        ),
  ]);
  Widget myPage() => pageBody([
    hint('数据保存在这台设备'),
    gap,
    SoftCard(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('问答历史'),
            trailing: Text('${s.sessions.length}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryPage(state: s)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('收藏分析'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryPage(state: s, favoritesOnly: true),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('回答与服务设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage(state: s)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('数据管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DataPage(state: s)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    ),
    gap,
    hint('基于《高性价比人生指南》\n回答为通用信息，请结合适用条件查看。'),
  ]);
}

class ResultPage extends StatefulWidget {
  final AppState state;
  final String sessionId;
  final String? initialTurnId;
  const ResultPage({
    super.key,
    required this.state,
    required this.sessionId,
    this.initialTurnId,
  });
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String? selected;
  final follow = TextEditingController();
  AppState get s => widget.state;
  @override
  void initState() {
    super.initState();
    selected =
        widget.initialTurnId ?? s.session(widget.sessionId)?.turns.last.id;
  }

  @override
  void dispose() {
    follow.dispose();
    super.dispose();
  }

  Future<void> saveAction(AnalysisSession session, AnswerTurn turn) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionEditor(state: s, session: session, turn: turn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final session = s.session(widget.sessionId),
          turn = s.turn(widget.sessionId, selected ?? '');
      if (session == null || turn == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('分析记录')),
          body: const Center(child: Text('原分析已删除')),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('你的建议'),
          actions: [
            IconButton(
              tooltip: session.favorite ? '取消收藏' : '收藏分析',
              onPressed: () => s.favorite(session),
              icon: Icon(
                session.favorite ? Icons.bookmark : Icons.bookmark_outline,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: pageBody([
            Text(
              turn.question,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(height: 1.5),
            ),
            if (session.turns.length > 1) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(selected),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '问答记录'),
                items: session.turns
                    .asMap()
                    .entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.value.id,
                        child: Text(
                          '第 ${e.key + 1} 次 · ${e.value.status == AnswerStatus.complete
                              ? '已完成'
                              : e.value.status == AnswerStatus.processing
                              ? '回答中'
                              : '未完成'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selected = value),
              ),
            ],
            gap,
            if (turn.status == AnswerStatus.processing) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: hint(turn.answer.isEmpty ? '正在等待服务回答…' : '正在接收回答…'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (turn.error.isNotEmpty) ...[
              notice(turn.error, error: true),
              gap,
            ],
            if (turn.answer.isNotEmpty)
              SoftCard(
                padding: const EdgeInsets.all(20),
                child: MarkdownBody(
                  data: turn.answer,
                  selectable: true,
                  onTapLink: (text, href, title) => openLink(context, href),
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.8),
                    listBullet: Theme.of(context).textTheme.bodyLarge,
                    blockSpacing: 16,
                  ),
                ),
              ),
            if (turn.status == AnswerStatus.processing) ...[
              gap,
              OutlinedButton(
                onPressed: () => s.stop(),
                child: const Text('停止接收'),
              ),
            ],
            if (turn.status == AnswerStatus.interrupted) ...[
              gap,
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () async {
                        if (!await ensureAiConsent(context, s) ||
                            !context.mounted) {
                          return;
                        }
                        try {
                          final next = s.retry(session, turn);
                          setState(() => selected = next.id);
                        } on ApiFailure catch (e) {
                          tell(context, e.message);
                        }
                      },
                child: const Text('重试本次问题'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsPage(state: s)),
                ),
                child: const Text('切换回答方式'),
              ),
            ],
            gap,
            SoftCard(
              child: ExpansionTile(
                key: PageStorageKey('citations-${turn.id}'),
                title: Text('引用条目 · ${turn.citations.length}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (turn.citations.isEmpty) hint('服务未提供引用清单。'),
                  ...turn.citations.map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.label),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CitationPage(
                                  citation: c,
                                  openExternal: openLink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (c.grade != null) badge('原项目证据 ${c.grade}'),
                              if (c.ratio != null) badge('性价比 ${c.ratio}'),
                              if (c.caliber != null) badge(c.caliber!),
                              if (c.sourceType != null &&
                                  c.sourceType != 'book')
                                badge(c.sourceType!),
                            ],
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                  ),
                  hint('点击条目查看原项目正文，原文版本可能与回答所用资料不同。'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('本次回答信息'),
              children: [
                ListTile(
                  title: const Text('回答方式'),
                  subtitle: Text(turn.streaming ? '流式回答' : '普通回答'),
                ),
                if (turn.model != null)
                  ListTile(
                    title: const Text('模型'),
                    subtitle: Text(turn.model!),
                  ),
                if (turn.retrieved != null)
                  ListTile(
                    title: const Text('检索条数'),
                    subtitle: Text('${turn.retrieved}'),
                  ),
                if (turn.elapsedMs != null)
                  ListTile(
                    title: const Text('生成耗时'),
                    subtitle: Text(
                      '${(turn.elapsedMs! / 1000).toStringAsFixed(1)} 秒',
                    ),
                  ),
              ],
            ),
            if (turn.status == AnswerStatus.complete) ...[
              gap,
              OutlinedButton.icon(
                onPressed: () => saveAction(session, turn),
                icon: const Icon(Icons.add_task),
                label: const Text('记一个行动'),
              ),
              gap,
              TextField(
                key: const Key('followup-input'),
                controller: follow,
                minLines: 2,
                maxLines: 5,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: '继续问，或补充你的情况',
                  counterText: '',
                ),
              ),
              VoiceInputButton(
                controller: follow,
                enabled: !s.busy,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              hint('将连同截至本轮的相关问答发送至服务端。'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () async {
                        if (!await ensureAiConsent(context, s) ||
                            !context.mounted) {
                          return;
                        }
                        try {
                          final next = s.followup(session, turn, follow.text);
                          follow.clear();
                          FocusScope.of(context).unfocus();
                          setState(() => selected = next.id);
                        } on ApiFailure catch (e) {
                          tell(context, e.message);
                        }
                      },
                child: const Text('继续问'),
              ),
            ],
            if (s.storageError != null) ...[
              gap,
              notice(s.storageError!, error: true),
            ],
          ]),
        ),
      );
    },
  );
  Widget badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class HistoryPage extends StatelessWidget {
  final AppState state;
  final bool favoritesOnly;
  const HistoryPage({
    super.key,
    required this.state,
    this.favoritesOnly = false,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final list = state.sessions
          .where((s) => !favoritesOnly || s.favorite)
          .toList()
          .reversed
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(favoritesOnly ? '收藏分析' : '问答历史')),
        body: SafeArea(
          child: pageBody([
            if (list.isEmpty) ...[
              const SizedBox(height: 60),
              Center(child: hint(favoritesOnly ? '还没有收藏' : '还没有问答记录')),
            ],
            ...list.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                    title: Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${s.turns.length} 次问答 · ${s.turns.last.status == AnswerStatus.complete
                          ? '已完成'
                          : s.turns.last.status == AnswerStatus.processing
                          ? '生成中'
                          : '未完成'}',
                    ),
                    onTap: () => openResult(context, state, s.id),
                    trailing: PopupMenuButton<String>(
                      tooltip: '管理记录',
                      onSelected: (value) async {
                        if (value == 'favorite') {
                          state.favorite(s);
                          return;
                        }
                        if (await confirm(
                          context,
                          '删除本机分析？',
                          '关联行动和其中保存的摘要仍会保留。这不会删除服务端记录。',
                        )) {
                          try {
                            state.deleteSession(s.id);
                          } on ApiFailure catch (e) {
                            if (context.mounted) tell(context, e.message);
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'favorite',
                          child: Text(s.favorite ? '取消收藏' : '收藏'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除本机分析'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

class ActionEditor extends StatefulWidget {
  final AppState state;
  final AnalysisSession? session;
  final AnswerTurn? turn;
  final SavedAction? action;
  const ActionEditor({
    super.key,
    required this.state,
    this.session,
    this.turn,
    this.action,
  });
  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, step;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.action?.title);
    step = TextEditingController(text: widget.action?.firstStep);
  }

  @override
  void dispose() {
    title.dispose();
    step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.action == null ? '记一个行动' : '编辑行动')),
    body: SafeArea(
      child: Form(
        key: form,
        child: pageBody([
          hint('由你整理第一步，不会自动改写原回答。'),
          gap,
          TextFormField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '要做什么'),
            validator: (v) => v == null || v.trim().isEmpty ? '请填写行动标题' : null,
          ),
          gap,
          TextFormField(
            controller: step,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: '第一小步'),
            validator: (v) => v == null || v.trim().isEmpty ? '请填写第一步' : null,
          ),
          gap,
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              try {
                if (widget.action != null) {
                  widget.state.updateAction(
                    widget.action!,
                    title: title.text,
                    firstStep: step.text,
                  );
                } else {
                  widget.state.saveAction(
                    widget.session!,
                    widget.turn!,
                    title.text,
                    step.text,
                  );
                }
                Navigator.pop(context);
                tell(context, '已保存到我的行动');
              } on ApiFailure catch (e) {
                tell(context, e.message);
              }
            },
            child: const Text('保存行动'),
          ),
        ]),
      ),
    ),
  );
}

class ActionPage extends StatefulWidget {
  final AppState state;
  final String actionId;
  const ActionPage({super.key, required this.state, required this.actionId});
  @override
  State<ActionPage> createState() => _ActionPageState();
}

class _ActionPageState extends State<ActionPage> {
  late final TextEditingController feedback;
  AppState get s => widget.state;
  @override
  void initState() {
    super.initState();
    feedback = TextEditingController(text: s.action(widget.actionId)?.feedback);
  }

  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final a = s.action(widget.actionId);
      if (a == null) return const SizedBox.shrink();
      final original = s.turn(a.sessionId, a.turnId),
          session = s.session(a.sessionId);
      return Scaffold(
        appBar: AppBar(
          title: const Text('行动详情'),
          actions: [
            IconButton(
              tooltip: '编辑行动',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActionEditor(state: s, action: a),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: pageBody([
            hint(a.state.label),
            const SizedBox(height: 12),
            Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
            gap,
            SoftCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hint('第一小步'),
                    const SizedBox(height: 10),
                    Text(
                      a.firstStep,
                      style: const TextStyle(fontSize: 17, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            gap,
            if (session != null && session.turns.last.id != a.turnId) ...[
              notice('分析已有更新，当前行动保留了你原来保存的内容。'),
              gap,
            ],
            FilledButton(
              onPressed: () => s.updateAction(
                a,
                state: a.state == ActionState.planned
                    ? ActionState.completed
                    : ActionState.planned,
              ),
              child: Text(a.state == ActionState.planned ? '标记完成' : '恢复准备做'),
            ),
            if (a.state == ActionState.planned)
              TextButton(
                onPressed: () => s.updateAction(a, state: ActionState.paused),
                child: const Text('暂时搁置'),
              ),
            gap,
            ExpansionTile(
              title: const Text('遇到困难？调整一下'),
              children: [
                TextField(
                  controller: feedback,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: '记录实际遇到的困难…'),
                ),
                Wrap(
                  spacing: 8,
                  children: ['太费时间', '成本偏高', '不适合我']
                      .map(
                        (x) => ActionChip(
                          label: Text(x),
                          onPressed: () {
                            feedback.text = feedback.text.isEmpty
                                ? x
                                : '${feedback.text}；$x';
                          },
                        ),
                      )
                      .toList(),
                ),
                gap,
                OutlinedButton(
                  onPressed: () {
                    s.updateAction(a, feedback: feedback.text);
                    tell(context, '反馈已保存在本机');
                  },
                  child: const Text('保存反馈'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: s.busy || original == null
                      ? null
                      : () async {
                          if (feedback.text.trim().isEmpty) {
                            tell(context, '请先写下遇到的困难。');
                            return;
                          }
                          if (!await confirm(
                            context,
                            '根据反馈调整？',
                            '将发送行动、反馈及其原分析上下文至服务端。',
                          )) {
                            return;
                          }
                          if (!context.mounted ||
                              !await ensureAiConsent(context, s) ||
                              !context.mounted) {
                            return;
                          }
                          try {
                            s.updateAction(a, feedback: feedback.text);
                            final next = s.followup(
                              session!,
                              original,
                              '我从建议中整理的行动是：${a.title}。第一步：${a.firstStep}。实际困难：${feedback.text}。请依据指南帮助调整。',
                            );
                            if (context.mounted) {
                              openResult(
                                context,
                                s,
                                a.sessionId,
                                turnId: next.id,
                              );
                            }
                          } on ApiFailure catch (e) {
                            if (context.mounted) tell(context, e.message);
                          }
                        },
                  child: const Text('根据反馈调整'),
                ),
                gap,
              ],
            ),
            gap,
            if (original != null)
              TextButton(
                onPressed: () =>
                    openResult(context, s, a.sessionId, turnId: a.turnId),
                child: const Text('查看原分析'),
              )
            else
              hint('原分析已删除，行动摘要仍保留。'),
            hint('来源问题：${a.sourceQuestion}'),
            gap,
            TextButton(
              onPressed: () async {
                if (await confirm(context, '删除这条行动？', '原分析不会一并删除。')) {
                  s.deleteAction(a.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除行动'),
            ),
          ]),
        ),
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('回答与服务设置')),
      body: SafeArea(
        child: pageBody([
          SoftCard(
            child: ListTile(
              leading: Icon(
                state.healthData?['status'] == 'ok'
                    ? Icons.check_circle_outline
                    : Icons.cloud_outlined,
              ),
              title: Text(
                state.checkingHealth
                    ? '正在检查…'
                    : state.healthData?['status'] == 'ok'
                    ? '服务已连接'
                    : state.healthData?['status'] == 'starting'
                    ? '知识库准备中'
                    : '暂时无法连接',
              ),
              trailing: IconButton(
                tooltip: '重新检查',
                onPressed: state.checkingHealth
                    ? null
                    : () => state.checkHealth(),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          gap,
          ListTile(
            title: const Text('AI 数据分享许可'),
            subtitle: Text(state.hasAiConsent ? '已同意，可撤回' : '尚未授权'),
            trailing: state.hasAiConsent
                ? TextButton(
                    onPressed: () async {
                      await state.revokeAiConsent();
                      if (context.mounted) {
                        tell(context, '已撤回许可，后续分析需重新授权。已发送的数据不会因此删除。');
                      }
                    },
                    child: const Text('撤回'),
                  )
                : null,
          ),
          gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('流式回答'),
            subtitle: const Text('关闭后，一次显示完整回答'),
            value: state.streaming,
            onChanged: (value) => state.settings(stream: value),
          ),
          gap,
          DropdownButtonFormField<int>(
            key: ValueKey(state.topK),
            initialValue: state.topK ?? 0,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '检索条数'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('服务端默认')),
              ...List.generate(
                20,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text('${i + 1} 条')),
              ),
            ],
            onChanged: (value) =>
                state.settings(count: value, defaultCount: value == 0),
          ),
          gap,
          ExpansionTile(
            title: const Text('服务详情'),
            children: [
              ListTile(
                title: const Text('模型'),
                subtitle: Text('${state.healthData?['model'] ?? '尚未获取'}'),
              ),
              ListTile(
                title: const Text('知识条目'),
                subtitle: Text('${state.healthData?['entries'] ?? '尚未获取'}'),
              ),
              const ListTile(
                title: Text('连接方式'),
                subtitle: Text('App 直接使用 HTTPS 连接服务，不依赖本地转发。'),
              ),
            ],
          ),
        ]),
      ),
    ),
  );
}

class DataPage extends StatelessWidget {
  final AppState state;
  const DataPage({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: SafeArea(
        child: pageBody([
          Text('你的数据，保存在这里。', style: Theme.of(context).textTheme.headlineSmall),
          gap,
          const Text(
            '本机保存草稿、分析、收藏和行动，不提供账号同步。卸载或清空后可能无法恢复。',
            style: TextStyle(height: 1.8),
          ),
          gap,
          const Text(
            '分析时，问题会发送至人生决策服务；继续追问会同时发送相关问答。删除本机记录不会删除服务端记录。',
            style: TextStyle(height: 1.8),
          ),
          gap,
          hint('当前服务没有任务恢复和取消接口。停止接收不保证服务端停止生成；后台连接可能被系统中断。'),
          gap,
          if (state.storageError != null) ...[
            notice(state.storageError!, error: true),
            gap,
          ],
          OutlinedButton(
            onPressed: state.busy
                ? null
                : () async {
                    if (!await confirm(
                      context,
                      '清空本机数据？',
                      '将删除草稿、全部分析、收藏、行动和偏好，无法恢复。这不涉及服务端数据。',
                    )) {
                      return;
                    }
                    try {
                      await state.clear();
                      if (context.mounted) tell(context, '本机数据已清空');
                    } catch (_) {
                      if (context.mounted) tell(context, '清空失败，请重试。');
                    }
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空本机数据'),
          ),
        ]),
      ),
    ),
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const appName = '高性价比人生指南';
  static const version = '1.0.0';
  static const feedbackEmail = 'baibin1989@foxmail.com';
  static const privacyPolicyUrl =
      'https://lucky-geranium-802.notion.site/3f3407f7a7018059b2bdf49578e173d0';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关于')),
    body: SafeArea(
      child: pageBody([
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/branding/app-icon.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text(appName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('版本 $version', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        gap,
        SoftCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('反馈与联系'),
                subtitle: const Text(feedbackEmail),
                trailing: const Icon(Icons.open_in_new_outlined),
                onTap: () => openLink(
                  context,
                  'mailto:$feedbackEmail?subject=$appName%20反馈',
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('隐私协议'),
                trailing: const Icon(Icons.open_in_new_outlined),
                onTap: () => openLink(context, privacyPolicyUrl),
              ),
            ],
          ),
        ),
        gap,
        hint('基于《高性价比人生指南》\n回答为通用信息，请结合适用条件查看。'),
      ]),
    ),
  );
}
