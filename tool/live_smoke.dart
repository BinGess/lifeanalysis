import 'dart:io';
import 'package:life_guide/services/api.dart';

// Explicit small non-personal requests. Not part of automatic unit tests.
Future<void> main() async {
  final api = DecisionApi();
  final status = await api.health();
  stdout.writeln('health: ${status['status']} / entries: ${status['entries']}');
  for (final streaming in [false, true]) {
    var chars = 0, citations = 0, done = false;
    await for (final e
        in api
            .answer('客户端联调：指南对缩短通勤有什么建议与限制？', streaming: streaming, topK: 1)
            .events) {
      if (e.type == 'delta') chars += (e.data['content'] as String).length;
      if (e.type == 'citations') {
        citations = (e.data['citations'] as List).length;
      }
      if (e.type == 'done') done = true;
    }
    if (!done || chars == 0) throw StateError('Incomplete result');
    stdout.writeln(
      '${streaming ? 'stream' : 'normal'}: done=$done, chars=$chars, citations=$citations',
    );
  }
}
