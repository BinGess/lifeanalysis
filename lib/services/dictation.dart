import 'package:speech_to_text/speech_to_text.dart';

abstract class DictationEngine {
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  });
  Future<void> listen(void Function(String, bool) onResult);
  Future<void> stop();
  Future<void> cancel();
}

/// Uses Apple's Speech framework on iOS and the system recognizer on Android.
/// Audio is never sent to the app's analysis API or saved by this client.
class SystemDictation implements DictationEngine {
  final SpeechToText _speech = SpeechToText();
  int _generation = 0;

  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async {
    final available = await _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
      options: [SpeechToText.androidNoBluetooth],
    );
    // SpeechToText is a singleton and only initializes once. Each sheet must
    // receive its own callbacks even after an earlier sheet has been disposed.
    _speech.statusListener = onStatus;
    _speech.errorListener = (error) => onError(error.errorMsg);
    return available;
  }

  @override
  Future<void> listen(void Function(String, bool) onResult) async {
    final id = ++_generation;
    final locales = await _speech.locales();
    if (id != _generation) return;
    final chinese = locales.where(
      (locale) => locale.localeId.toLowerCase().startsWith('zh'),
    );
    if (chinese.isEmpty) {
      throw StateError('chinese_unavailable');
    }
    final preferred = chinese.where(
      (locale) => locale.localeId.replaceAll('_', '-').toLowerCase() == 'zh-cn',
    );
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId:
            (preferred.isEmpty ? chinese.first : preferred.first).localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        autoPunctuation: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      ),
    );
    if (id != _generation) await _speech.cancel();
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() {
    ++_generation;
    return _speech.cancel();
  }
}

String dictationError(String code) {
  if (code.contains('permission') || code.contains('not_allowed')) {
    return '请在系统设置中允许本 App 使用麦克风和语音识别，也可以继续打字。';
  }
  if (code.contains('no_match') || code.contains('speech_timeout')) {
    return '没有听清，请靠近麦克风再试一次。';
  }
  if (code.contains('network')) return '语音服务连接失败，请检查网络后重试。';
  if (code.contains('chinese_unavailable')) {
    return '系统暂不支持中文识别，请检查系统语音设置或使用键盘输入。';
  }
  return '系统语音识别暂不可用，请稍后重试或使用键盘输入。';
}

String appendDictation(String original, String words) {
  final prefix = original.trimRight();
  return prefix.isEmpty ? words.trim() : '$prefix\n${words.trim()}';
}
