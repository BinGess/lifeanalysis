import 'package:life_guide/services/ai_disclosure.dart';
import 'dart:async';
import 'package:life_guide/services/api.dart';
import 'package:life_guide/services/sse.dart';
import 'package:life_guide/services/storage.dart';

class MemoryStore implements LocalStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeApi implements DecisionService {
  final requests = <String>[];
  final controllers = <StreamController<ApiEvent>>[];
  @override
  Future<Map<String, dynamic>> health() async => {
    'status': 'ok',
    'entries': 12,
    'model': 'test',
  };
  @override
  AnswerRequest answer(String message, {bool streaming = true, int? topK}) {
    requests.add(message);
    final c = StreamController<ApiEvent>();
    controllers.add(c);
    return AnswerRequest(c.stream, () {
      c.addError(ApiFailure('已停止接收'));
      c.close();
    });
  }

  Future<void> finish([String text = '测试回答']) async {
    final c = controllers.last;
    c.add(
      ApiEvent('citations', {
        'citations': [
          {'citation': '第 4 节第 18 条', 'grade': 'B'},
        ],
        'retrieved': 1,
      }),
    );
    c.add(ApiEvent('delta', {'content': text}));
    c.add(ApiEvent('done', {'elapsed_ms': 123}));
    await c.close();
  }
}

const testDisclosure = AiDisclosure(
  operatorName: '测试运营方',
  providerName: '测试 AI 服务商',
  privacyUrl: 'https://privacy.test/app',
  providerPrivacyUrl: 'https://privacy.test/provider',
);
