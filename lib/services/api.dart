import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sse.dart';

class ApiFailure implements Exception {
  final String message;
  ApiFailure(this.message);
  @override
  String toString() => message;
}

class AnswerRequest {
  final Stream<ApiEvent> events;
  final void Function() cancel;
  AnswerRequest(this.events, this.cancel);
}

abstract class DecisionService {
  Future<Map<String, dynamic>> health();
  AnswerRequest answer(String message, {bool streaming = true, int? topK});
}

class DecisionApi implements DecisionService {
  final String baseUrl;
  final http.Client Function() clientFactory;
  DecisionApi({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://vygttv9jhw.coze.site',
    ),
    http.Client Function()? clientFactory,
  }) : clientFactory = clientFactory ?? http.Client.new;
  Uri endpoint(String path) {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    if (uri.scheme != 'https') throw ApiFailure('服务地址必须使用 HTTPS。');
    return uri;
  }

  ApiFailure statusError(int status) => ApiFailure(switch (status) {
    401 => '服务已开启鉴权，需要配置可用的访问方式。',
    422 => '问题或参数未通过校验，请修改后重试。',
    429 => '请求较多，请稍后重试。',
    502 => '生成服务暂时不可用，请稍后重试。',
    503 => '知识库正在准备，请稍后再试。',
    504 => '服务响应超时，请稍后重试。',
    _ => '请求未完成（$status），请稍后重试。',
  });
  @override
  Future<Map<String, dynamic>> health() async {
    final client = clientFactory();
    try {
      final res = await client
          .get(endpoint('/health'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw statusError(res.statusCode);
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
    } finally {
      client.close();
    }
  }

  @override
  AnswerRequest answer(String message, {bool streaming = true, int? topK}) {
    final output = StreamController<ApiEvent>();
    final client = clientFactory();
    var closed = false, hasContent = false, gotDone = false;
    Timer? deadline;
    void end([Object? error]) {
      if (closed) return;
      closed = true;
      deadline?.cancel();
      client.close();
      if (error != null) output.addError(error);
      unawaited(output.close());
    }

    void emit(ApiEvent event) {
      if (!closed) output.add(event);
    }

    Future<void> run() async {
      try {
        if (message.trim().isEmpty) throw ApiFailure('请先输入问题。');
        if (topK != null && (topK < 1 || topK > 20)) {
          throw ApiFailure('检索条数应为 1～20。');
        }
        deadline = Timer(
          const Duration(minutes: 3),
          () => end(ApiFailure('等待超过三分钟，已保留收到的内容。')),
        );
        final body = {'message': message.trim(), 'top_k': ?topK};
        final req =
            http.Request(
                'POST',
                endpoint(streaming ? '/analyze/stream' : '/analyze'),
              )
              ..headers['Content-Type'] = 'application/json'
              ..headers['Accept'] = streaming
                  ? 'text/event-stream'
                  : 'application/json'
              ..body = jsonEncode(body);
        final res = await client.send(req).timeout(const Duration(seconds: 30));
        if (closed) return;
        if (res.statusCode != 200) throw statusError(res.statusCode);
        if (!streaming) {
          final data = jsonDecode(await res.stream.bytesToString());
          if (data is! Map ||
              data['answer'] is! String ||
              (data['answer'] as String).trim().isEmpty ||
              data['citations'] is! List) {
            throw ApiFailure('服务未返回完整的回答和引用。');
          }
          emit(ApiEvent('citations', Map<String, dynamic>.from(data)));
          emit(ApiEvent('delta', {'content': data['answer']}));
          emit(ApiEvent('done', {'elapsed_ms': data['elapsed_ms']}));
          end();
          return;
        }
        if (!(res.headers['content-type'] ?? '').contains(
          'text/event-stream',
        )) {
          throw ApiFailure('流式格式异常，可切换普通回答重试。');
        }
        await for (final event in decodeSse(res.stream)) {
          if (closed) return;
          if (event.type == 'error') throw ApiFailure('生成过程中断，已保留部分内容。');
          if (event.type == 'citations' && event.data['citations'] is! List) {
            throw ApiFailure('引用格式异常。');
          }
          if (event.type == 'delta') {
            if (event.data['content'] is! String) throw ApiFailure('回答片段格式异常。');
            hasContent =
                hasContent ||
                (event.data['content'] as String).trim().isNotEmpty;
          }
          if (event.type == 'done') {
            if (!hasContent) throw ApiFailure('服务没有返回回答内容。');
            gotDone = true;
          }
          emit(event);
          if (gotDone) break;
        }
        if (!gotDone) throw ApiFailure('连接在回答完成前中断，内容尚不完整。');
        end();
      } on ApiFailure catch (e) {
        end(e);
      } on FormatException {
        end(ApiFailure('服务返回格式异常，已保留收到的内容。'));
      } on TimeoutException {
        end(ApiFailure('服务响应超时，请稍后重试。'));
      } catch (_) {
        end(ApiFailure('连接中断或网络不可用，请稍后重试。'));
      }
    }

    output.onListen = () => unawaited(run());
    output.onCancel = () {
      if (!closed) {
        closed = true;
        deadline?.cancel();
        client.close();
      }
    };
    return AnswerRequest(
      output.stream,
      () => end(ApiFailure('已停止接收。内容可能不完整，服务端可能仍在生成。')),
    );
  }
}
