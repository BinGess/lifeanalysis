import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_guide/services/api.dart';
import 'package:life_guide/services/sse.dart';

class TestClient extends http.BaseClient {
  final int status;
  final String body, contentType;
  final void Function(http.BaseRequest)? inspect;
  TestClient(
    this.body, {
    this.status = 200,
    this.contentType = 'text/event-stream',
    this.inspect,
  });
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    inspect?.call(request);
    return http.StreamedResponse(
      Stream.fromIterable(utf8.encode(body).map((b) => [b])),
      status,
      headers: {'content-type': contentType},
    );
  }
}

void main() {
  test('JSON and Python literal payloads preserve strings and nulls', () {
    expect(
      decodeEventData(
        r'''{'content': '你好\nquote\'s "text"', 'grade': None, 'ok': True}''',
      ),
      {'content': '你好\nquote\'s "text"', 'grade': null, 'ok': true},
    );
    expect(decodeEventData('{"content":"中文","grade":null}')['content'], '中文');
    expect(decodeEventData(r"{'content': '\U0001f600'}")['content'], '😀');
  });
  test('reject executable expressions and excessive nesting', () {
    expect(
      () => decodeEventData("__import__('os').getcwd()"),
      throwsFormatException,
    );
    expect(
      () => decodeEventData("{'x': ${'[' * 70}0${']' * 70}}"),
      throwsFormatException,
    );
  });
  test('SSE handles bytewise UTF-8, CRLF, comments and multiline JSON', () async {
    final text =
        ': keepalive\r\n\r\nevent: delta\r\ndata: {\r\ndata: "content":"你好"}\r\n\r\nevent: done\r\ndata: {}\r\n\r\n';
    final events = await decodeSse(
      Stream.fromIterable(utf8.encode(text).map((x) => [x])),
    ).toList();
    expect(events.map((x) => x.type), ['delta', 'done']);
    expect(events.first.data['content'], '你好');
  });
  test('stream directly accepts current upstream Python format', () async {
    const body =
        "event: citations\ndata: {'citations': [], 'retrieved': 0}\n\nevent: delta\ndata: {'content': '真实内容'}\n\nevent: done\ndata: {'elapsed_ms': 12}\n\n";
    final api = DecisionApi(
      clientFactory: () => TestClient(
        body,
        inspect: (r) {
          expect(r.url.path, '/analyze/stream');
          expect(jsonDecode((r as http.Request).body), {
            'message': '问题',
            'top_k': 2,
          });
        },
      ),
    );
    expect(
      (await api.answer(' 问题 ', topK: 2).events.toList()).map((e) => e.type),
      ['citations', 'delta', 'done'],
    );
  });
  test('EOF without framed done and empty streams fail', () async {
    for (final body in [
      'event: delta\ndata: {"content":"部分"}\n\n',
      'event: delta\ndata: {"content":"部分"}\n\nevent: done\ndata: {}',
      'event: done\ndata: {}\n\n',
    ]) {
      await expectLater(
        DecisionApi(
          clientFactory: () => TestClient(body),
        ).answer('问题').events.toList(),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test('server error terminates and does not expose detail', () async {
    final api = DecisionApi(
      clientFactory: () => TestClient(
        'event: error\ndata: {"error":"bad","detail":"secret"}\n\n',
      ),
    );
    await expectLater(
      api.answer('问题').events.toList(),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret')),
        ),
      ),
    );
  });
  test('ordinary response and HTTP errors', () async {
    final api = DecisionApi(
      clientFactory: () => TestClient(
        jsonEncode({
          'answer': '完整回答',
          'citations': [
            {'grade': null},
          ],
        }),
        contentType: 'application/json',
        inspect: (r) => expect(r.url.path, '/analyze'),
      ),
    );
    expect(
      (await api.answer('问题', streaming: false).events.toList()).last.type,
      'done',
    );
    for (final status in [401, 422, 502]) {
      await expectLater(
        DecisionApi(
          clientFactory: () => TestClient('', status: status),
        ).answer('问题').events.toList(),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test('empty input never sent', () async {
    var called = false;
    final api = DecisionApi(
      clientFactory: () => TestClient('', inspect: (_) => called = true),
    );
    await expectLater(
      api.answer(' ').events.toList(),
      throwsA(isA<ApiFailure>()),
    );
    expect(called, false);
  });
}
