import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dictation.dart';

enum _VoicePhase { preparing, listening, finishing, ready }

Future<String?> showDictation(
  BuildContext context, {
  int maxCharacters = 5000,
  DictationEngine? engine,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DictationSheet(
      engine: engine ?? SystemDictation(),
      maxCharacters: maxCharacters,
    ),
  );
}

class DictationSheet extends StatefulWidget {
  final DictationEngine engine;
  final int maxCharacters;
  const DictationSheet({
    super.key,
    required this.engine,
    this.maxCharacters = 5000,
  });
  @override
  State<DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<DictationSheet>
    with WidgetsBindingObserver {
  _VoicePhase phase = _VoicePhase.preparing;
  String words = '';
  String? error;
  int generation = 0;
  Timer? deadline;
  Timer? finishDeadline;
  bool get active => phase != _VoicePhase.ready;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  bool valid(int id) => mounted && id == generation;
  Future<void> cancelEngine() async {
    try {
      await widget.engine.cancel();
    } catch (_) {
      /* Already unavailable. */
    }
  }

  Future<void> start() async {
    final id = ++generation;
    deadline?.cancel();
    finishDeadline?.cancel();
    finishDeadline = null;
    setState(() {
      phase = _VoicePhase.preparing;
      words = '';
      error = null;
    });
    try {
      await cancelEngine();
      if (!valid(id)) return;
      final available = await widget.engine.initialize(
        onStatus: (status) {
          if (!valid(id) || !active) return;
          if (status == 'listening') {
            setState(() => phase = _VoicePhase.listening);
          } else if (status == 'done') {
            complete(id);
          } else if (status == 'notListening') {
            finishing(id);
          }
        },
        onError: (code) {
          if (!valid(id) || !active) return;
          fail(id, dictationError(code));
        },
      );
      if (!valid(id) || !active) return;
      if (!available) {
        fail(id, '未获得语音权限，或系统识别不可用。请在系统设置中检查麦克风与语音识别权限。');
        return;
      }
      await widget.engine.listen((text, isFinal) {
        if (!valid(id) || !active) return;
        // Partial results replace the current utterance; do not append them.
        setState(() => words = text);
        if (isFinal) complete(id);
      });
      if (!valid(id) || !active) return;
      if (phase == _VoicePhase.preparing) {
        setState(() => phase = _VoicePhase.listening);
      }
      deadline = Timer(const Duration(seconds: 60), stop);
    } catch (e) {
      if (valid(id)) fail(id, dictationError(e.toString()));
    }
  }

  void complete(int id) {
    if (!valid(id)) return;
    deadline?.cancel();
    finishDeadline?.cancel();
    setState(() {
      phase = _VoicePhase.ready;
      if (words.trim().isEmpty && error == null) error = '没有识别到文字，可以再试一次。';
    });
    // A final result means this session is over, even if the OS omits done.
    unawaited(cancelEngine());
  }

  void fail(int id, String message) {
    if (!valid(id)) return;
    error = message;
    complete(id);
  }

  void finishing(int id) {
    if (!valid(id) || !active) return;
    setState(() => phase = _VoicePhase.finishing);
    // Some recognizers never deliver a final event. Preserve the last preview.
    finishDeadline ??= Timer(const Duration(seconds: 3), () => complete(id));
  }

  Future<void> stop() async {
    if (phase != _VoicePhase.listening) return;
    final id = generation;
    deadline?.cancel();
    finishing(id);
    try {
      await widget.engine.stop();
    } catch (_) {
      if (valid(id)) fail(id, '语音输入已停止，已识别的文字可以保留。');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission prompts cause inactive while preparing; do not cancel those.
    if (state == AppLifecycleState.inactive && phase == _VoicePhase.listening) {
      unawaited(stop());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (active) {
        ++generation;
        deadline?.cancel();
        finishDeadline?.cancel();
        setState(() {
          phase = _VoicePhase.ready;
          error = '语音输入已暂停，已识别的文字仍可填入。';
        });
        unawaited(cancelEngine());
      }
    }
  }

  @override
  void dispose() {
    ++generation;
    WidgetsBinding.instance.removeObserver(this);
    deadline?.cancel();
    finishDeadline?.cancel();
    unawaited(cancelEngine());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooLong = words.trim().characters.length > widget.maxCharacters;
    final title = switch (phase) {
      _VoicePhase.preparing => '正在准备语音输入…',
      _VoicePhase.listening => '正在听，请说话',
      _VoicePhase.finishing => '正在整理文字…',
      _VoicePhase.ready => '确认识别文字',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: ListView(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '取消语音输入',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 140),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  words.isEmpty ? '说说你正在考虑的事…' : words,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.7,
                    color: words.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (error != null || tooLong)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    tooLong ? '超出输入框可用字数，请重新说一段短一些的内容。' : error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Text(
                '由系统语音服务转写，可能需要联网。确认文字后，再提交分析。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (active)
                FilledButton(
                  onPressed: phase == _VoicePhase.listening ? stop : null,
                  child: Text(phase == _VoicePhase.finishing ? '正在整理…' : '说完了'),
                )
              else
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  spacing: 12,
                  overflowSpacing: 12,
                  children: [
                    OutlinedButton(onPressed: start, child: const Text('重新说')),
                    FilledButton(
                      onPressed: words.trim().isEmpty || tooLong
                          ? null
                          : () => Navigator.pop(context, words.trim()),
                      child: const Text('填入输入框'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recognition is an explicit draft edit; it never submits an analysis.
class VoiceInputButton extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final DictationEngine Function()? engineFactory;
  const VoiceInputButton({
    super.key,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.engineFactory,
  });

  Future<void> enterVoice(BuildContext context) async {
    final base = controller.text;
    final remaining =
        5000 -
        (base.trimRight().isEmpty ? 0 : base.trimRight().characters.length + 1);
    if (remaining <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('输入框已满，请先删减一些文字。')));
      return;
    }
    final words = await showDictation(
      context,
      maxCharacters: remaining,
      engine: engineFactory?.call(),
    );
    if (!context.mounted || words == null || words.isEmpty) return;
    final text = appendDictation(base, words);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged(text);
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: enabled ? () => enterVoice(context) : null,
      icon: const Icon(Icons.mic_none_rounded, size: 20),
      label: const Text('语音输入'),
    ),
  );
}
