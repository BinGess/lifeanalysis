import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class Citation {
  final String title, label;
  final String? grade, ratio, caliber, sourceType;
  final int? chapterNo, entryNo;
  Citation({
    required this.title,
    required this.label,
    this.grade,
    this.ratio,
    this.caliber,
    this.sourceType,
    this.chapterNo,
    this.entryNo,
  });
  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
    title: '${j['title'] ?? ''}',
    label: '${j['citation'] ?? j['title'] ?? '未提供出处'}',
    grade: j['grade']?.toString(),
    ratio: j['ratio']?.toString(),
    caliber: j['caliber']?.toString(),
    sourceType: j['source_type']?.toString(),
    chapterNo: int.tryParse('${j['chapter_no']}'),
    entryNo: int.tryParse('${j['entry_no']}'),
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'citation': label,
    'grade': grade,
    'ratio': ratio,
    'caliber': caliber,
    'source_type': sourceType,
    'chapter_no': chapterNo,
    'entry_no': entryNo,
  };
}

enum AnswerStatus { processing, complete, interrupted }

class AnswerTurn {
  final String id, question, message;
  final String? parentId;
  final DateTime created;
  final bool streaming;
  final int? topK;
  String answer, error;
  AnswerStatus status;
  List<Citation> citations;
  String? model, provider;
  int? retrieved, elapsedMs;
  AnswerTurn({
    required this.id,
    required this.question,
    required this.message,
    required this.created,
    this.parentId,
    this.streaming = true,
    this.topK,
    this.answer = '',
    this.error = '',
    this.status = AnswerStatus.processing,
    List<Citation>? citations,
  }) : citations = citations ?? [];
  factory AnswerTurn.fromJson(Map<String, dynamic> j) {
    final raw = j['status'];
    final turn = AnswerTurn(
      id: j['id'],
      question: j['question'],
      message: j['message'],
      created: DateTime.parse(j['created']),
      parentId: j['parentId'],
      streaming: j['streaming'] ?? true,
      topK: j['topK'],
      answer: j['answer'] ?? '',
      error: raw == 'processing' ? '上次连接已结束，回答尚未完成。' : j['error'] ?? '',
      status: raw == 'complete'
          ? AnswerStatus.complete
          : AnswerStatus.interrupted,
      citations: (j['citations'] as List? ?? [])
          .map((x) => Citation.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
    );
    turn.model = j['model'];
    turn.provider = j['provider'];
    turn.retrieved = j['retrieved'];
    turn.elapsedMs = j['elapsedMs'];
    return turn;
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'message': message,
    'created': created.toIso8601String(),
    'parentId': parentId,
    'streaming': streaming,
    'topK': topK,
    'answer': answer,
    'error': error,
    'status': status.name,
    'citations': citations.map((x) => x.toJson()).toList(),
    'model': model,
    'provider': provider,
    'retrieved': retrieved,
    'elapsedMs': elapsedMs,
  };
}

class AnalysisSession {
  final String id, title;
  final DateTime created;
  final List<AnswerTurn> turns;
  bool favorite;
  AnalysisSession({
    required this.id,
    required this.title,
    required this.created,
    required this.turns,
    this.favorite = false,
  });
  factory AnalysisSession.fromJson(Map<String, dynamic> j) => AnalysisSession(
    id: j['id'],
    title: j['title'],
    created: DateTime.parse(j['created']),
    favorite: j['favorite'] ?? false,
    turns: (j['turns'] as List)
        .map((x) => AnswerTurn.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created': created.toIso8601String(),
    'favorite': favorite,
    'turns': turns.map((x) => x.toJson()).toList(),
  };
}

enum ActionState { planned, completed, paused }

extension ActionLabel on ActionState {
  String get label => switch (this) {
    ActionState.planned => '准备做',
    ActionState.completed => '已完成',
    ActionState.paused => '暂时搁置',
  };
}

class SavedAction {
  final String id, sessionId, turnId, sourceQuestion;
  final DateTime created;
  String title, firstStep, feedback;
  ActionState state;
  SavedAction({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.sourceQuestion,
    required this.title,
    required this.firstStep,
    required this.created,
    this.feedback = '',
    this.state = ActionState.planned,
  });
  factory SavedAction.fromJson(Map<String, dynamic> j) => SavedAction(
    id: j['id'],
    sessionId: j['sessionId'],
    turnId: j['turnId'],
    sourceQuestion: j['sourceQuestion'],
    title: j['title'],
    firstStep: j['firstStep'],
    created: DateTime.parse(j['created']),
    feedback: j['feedback'] ?? '',
    state: ActionState.values.firstWhere(
      (x) => x.name == j['state'],
      orElse: () => ActionState.planned,
    ),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'turnId': turnId,
    'sourceQuestion': sourceQuestion,
    'title': title,
    'firstStep': firstStep,
    'created': created.toIso8601String(),
    'feedback': feedback,
    'state': state.name,
  };
}
