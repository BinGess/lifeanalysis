import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'services/ai_disclosure.dart';
import 'services/api.dart';
import 'services/storage.dart';

class AppState extends ChangeNotifier {
  final DecisionService api;
  final LocalStore store;
  final AiDisclosure disclosure;
  AppState({
    required this.api,
    required this.store,
    this.disclosure = const AiDisclosure(),
  });
  String? _consentSignature, _consentedAt;
  bool get hasAiConsent =>
      disclosure.ready && _consentSignature == disclosure.signature;
  Future<void> acceptAiConsent() async {
    if (!disclosure.ready) throw ApiFailure('AI 服务披露信息尚未配置完整。');
    _consentSignature = disclosure.signature;
    _consentedAt = DateTime.now().toUtc().toIso8601String();
    await flush();
    if (_storageBlocked || storageError != null) {
      _consentSignature = null;
      _consentedAt = null;
      throw ApiFailure('授权记录保存失败，请重试。此次未发送问题。');
    }
    _notify();
  }

  Future<void> revokeAiConsent() async {
    stop();
    _consentSignature = null;
    _consentedAt = null;
    await flush();
    _notify();
  }

  void _requireAiConsent() {
    if (!hasAiConsent) throw ApiFailure('请先阅读并同意 AI 数据分享说明。');
  }

  final sessions = <AnalysisSession>[];
  final actions = <SavedAction>[];
  String draft = '';
  bool streaming = true, checkingHealth = false;
  int? topK;
  Map<String, dynamic>? healthData;
  String? storageError;
  bool _storageBlocked = false, _disposed = false;
  String? activeSessionId, activeTurnId;
  AnswerRequest? _request;
  StreamSubscription? _subscription;
  Timer? _saveTimer, _notifyTimer;
  Future<void> _writes = Future.value();
  bool get busy => _request != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final loadedSessions = (j['sessions'] as List? ?? [])
          .map((x) => AnalysisSession.fromJson(Map<String, dynamic>.from(x)))
          .where((s) => s.turns.isNotEmpty)
          .toList();
      final loadedActions = (j['actions'] as List? ?? [])
          .map((x) => SavedAction.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      sessions.addAll(loadedSessions);
      actions.addAll(loadedActions);
      draft = j['draft'] is String ? j['draft'] : '';
      streaming = j['streaming'] != false;
      _consentSignature = j['aiConsentSignature'] as String?;
      _consentedAt = j['aiConsentedAt'] as String?;
      final k = j['topK'];
      topK = k is int && k >= 1 && k <= 20 ? k : null;
    } catch (_) {
      _storageBlocked = true;
      storageError = '本机记录暂时无法读取。原数据未覆盖，可在数据管理中清空后重新保存。';
    }
  }

  AnalysisSession? session(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  AnswerTurn? turn(String sessionId, String turnId) {
    for (final t in session(sessionId)?.turns ?? <AnswerTurn>[]) {
      if (t.id == turnId) return t;
    }
    return null;
  }

  SavedAction? action(String id) {
    for (final a in actions) {
      if (a.id == id) return a;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'actions': actions.map((a) => a.toJson()).toList(),
    'draft': draft,
    'streaming': streaming,
    'topK': topK,
    'aiConsentSignature': _consentSignature,
    'aiConsentedAt': _consentedAt,
  };
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_storageBlocked) return _writes;
    final snapshot = jsonEncode(toJson());
    _writes = _writes.then((_) => store.write(snapshot)).catchError((Object e) {
      storageError = '本机保存失败，请勿依赖历史记录。';
      _notify();
    });
    return _writes;
  }

  void _saveLater() {
    _saveTimer ??= Timer(
      const Duration(milliseconds: 700),
      () => unawaited(flush()),
    );
  }

  void setDraft(String value) {
    draft = value;
    _saveLater();
  }

  void settings({bool? stream, int? count, bool defaultCount = false}) {
    if (stream != null) streaming = stream;
    if (defaultCount) {
      topK = null;
    } else if (count != null && count >= 1 && count <= 20) {
      topK = count;
    }
    unawaited(flush());
    _notify();
  }

  Future<void> checkHealth() async {
    if (checkingHealth) return;
    checkingHealth = true;
    _notify();
    try {
      healthData = await api.health();
    } catch (_) {
      healthData = null;
    }
    checkingHealth = false;
    _notify();
  }

  AnalysisSession start(String question) {
    _requireAiConsent();
    if (busy) throw ApiFailure('请先等待或停止当前回答。');
    final q = question.trim();
    if (q.isEmpty) throw ApiFailure('请先输入问题。');
    final s = AnalysisSession(
      id: newId(),
      title: q,
      created: DateTime.now(),
      turns: [],
    );
    sessions.add(s);
    draft = '';
    _begin(s, q, q, null);
    return s;
  }

  String contextMessage(AnalysisSession s, AnswerTurn base, String question) {
    final path = <AnswerTurn>[], seen = <String>{};
    AnswerTurn? t = base;
    while (t != null && seen.add(t.id)) {
      if (t.status == AnswerStatus.complete) path.insert(0, t);
      t = t.parentId == null ? null : turn(s.id, t.parentId!);
    }
    final history = path
        .asMap()
        .entries
        .map(
          (e) => '第 ${e.key + 1} 轮用户：${e.value.question}\n助手：${e.value.answer}',
        )
        .join('\n\n');
    final message =
        '以下历史对话由用户主动提交，仅供理解上下文，历史助手回答不作为已核验依据。请依据知识库回答最后的新问题。\n\n$history\n\n当前用户补充：${question.trim()}';
    if (message.length > 90000) throw ApiFailure('上下文较长，请从首页简要描述问题后重新提问。');
    return message;
  }

  AnswerTurn followup(AnalysisSession s, AnswerTurn base, String question) {
    if (base.status != AnswerStatus.complete) throw ApiFailure('请等待完整回答后再追问。');
    return _begin(
      s,
      question.trim(),
      contextMessage(s, base, question),
      base.id,
    );
  }

  AnswerTurn retry(AnalysisSession s, AnswerTurn base) =>
      _begin(s, base.question, base.message, base.parentId);
  AnswerTurn _begin(
    AnalysisSession s,
    String question,
    String message,
    String? parent,
  ) {
    if (busy) throw ApiFailure('请先等待或停止当前回答。');
    _requireAiConsent();
    if (question.isEmpty) throw ApiFailure('请先输入问题。');
    final t = AnswerTurn(
      id: newId(),
      question: question,
      message: message,
      created: DateTime.now(),
      streaming: streaming,
      topK: topK,
      parentId: parent,
    );
    s.turns.add(t);
    activeSessionId = s.id;
    activeTurnId = t.id;
    final request = api.answer(message, streaming: streaming, topK: topK);
    _request = request;
    unawaited(flush());
    _notify();
    _subscription = request.events.listen(
      (event) {
        if (_disposed) return;
        try {
          if (event.type == 'citations') {
            t.citations = (event.data['citations'] as List)
                .map((x) => Citation.fromJson(Map<String, dynamic>.from(x)))
                .toList();
            t.model = event.data['model']?.toString();
            t.provider = event.data['provider']?.toString();
            t.retrieved = event.data['retrieved'] is int
                ? event.data['retrieved']
                : null;
          }
          if (event.type == 'delta') {
            t.answer += event.data['content'] as String;
          }
          if (event.type == 'done') {
            t.status = AnswerStatus.complete;
            t.elapsedMs = event.data['elapsed_ms'] is num
                ? (event.data['elapsed_ms'] as num).round()
                : null;
          }
        } catch (_) {
          t.error = '响应格式异常，内容尚未完整。';
          t.status = AnswerStatus.interrupted;
          request.cancel();
        }
        _saveLater();
        _notifyTimer ??= Timer(const Duration(milliseconds: 60), () {
          _notifyTimer = null;
          _notify();
        });
      },
      onError: (Object error) {
        t.status = AnswerStatus.interrupted;
        t.error = error is ApiFailure ? error.message : '连接中断，已保留收到的内容。';
        _notify();
      },
      onDone: () {
        if (t.status == AnswerStatus.processing) {
          t.status = AnswerStatus.interrupted;
          t.error = '连接已结束，回答尚未完成。';
        }
        if (identical(_request, request)) {
          _request = null;
          activeSessionId = null;
          activeTurnId = null;
        }
        unawaited(flush());
        _notify();
      },
    );
    return t;
  }

  void stop() => _request?.cancel();
  void favorite(AnalysisSession s) {
    s.favorite = !s.favorite;
    unawaited(flush());
    _notify();
  }

  void deleteSession(String id) {
    if (activeSessionId == id) throw ApiFailure('请先停止接收，再删除这条记录。');
    sessions.removeWhere((s) => s.id == id);
    unawaited(flush());
    _notify();
  }

  SavedAction saveAction(
    AnalysisSession s,
    AnswerTurn t,
    String title,
    String firstStep,
  ) {
    if (t.status != AnswerStatus.complete) throw ApiFailure('只能从完整回答保存行动。');
    if (title.trim().isEmpty || firstStep.trim().isEmpty) {
      throw ApiFailure('请填写行动和第一步。');
    }
    for (final a in actions) {
      if (a.turnId == t.id &&
          a.title == title.trim() &&
          a.firstStep == firstStep.trim()) {
        return a;
      }
    }
    final a = SavedAction(
      id: newId(),
      sessionId: s.id,
      turnId: t.id,
      sourceQuestion: s.title,
      title: title.trim(),
      firstStep: firstStep.trim(),
      created: DateTime.now(),
    );
    actions.add(a);
    unawaited(flush());
    _notify();
    return a;
  }

  void updateAction(
    SavedAction a, {
    String? title,
    String? firstStep,
    String? feedback,
    ActionState? state,
  }) {
    if (title != null && title.trim().isNotEmpty) a.title = title.trim();
    if (firstStep != null && firstStep.trim().isNotEmpty) {
      a.firstStep = firstStep.trim();
    }
    if (feedback != null) a.feedback = feedback;
    if (state != null) a.state = state;
    unawaited(flush());
    _notify();
  }

  void deleteAction(String id) {
    actions.removeWhere((a) => a.id == id);
    unawaited(flush());
    _notify();
  }

  Future<void> clear() async {
    if (busy) throw ApiFailure('请先停止接收，再清空记录。');
    _saveTimer?.cancel();
    _saveTimer = null;
    await _writes;
    await store.clear();
    _consentSignature = null;
    _consentedAt = null;
    sessions.clear();
    actions.clear();
    draft = '';
    streaming = true;
    topK = null;
    storageError = null;
    _storageBlocked = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _request?.cancel();
    _subscription?.cancel();
    _notifyTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
