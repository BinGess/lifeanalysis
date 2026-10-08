import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_guide/services/dictation.dart';
import 'package:life_guide/ui/dictation_sheet.dart';

class FakeDictation implements DictationEngine {
  bool available = true;
  Completer<bool>? permission;
  void Function(String)? status, error;
  void Function(String, bool)? result;
  int listens = 0, stops = 0, cancels = 0;
  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async {
    status = onStatus;
    error = onError;
    return permission == null ? available : await permission!.future;
  }

  @override
  Future<void> listen(void Function(String, bool) onResult) async {
    listens++;
    result = onResult;
    status?.call('listening');
  }

  @override
  Future<void> stop() async {
    stops++;
    status?.call('notListening');
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  testWidgets(
    'partial recognition replaces preview; confirmation appends once',
    (tester) async {
      final engine = FakeDictation();
      final input = TextEditingController(text: '原来的问题');
      String? edited;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceInputButton(
              controller: input,
              onChanged: (text) => edited = text,
              engineFactory: () => engine,
            ),
          ),
        ),
      );
      expect(engine.listens, 0); // No permission or recording on launch.
      await tester.tap(find.text('语音输入'));
      await tester.pumpAndSettle();
      expect(engine.listens, 1);
      engine.result!('我要', false);
      await tester.pump();
      engine.result!('我要缩短通勤', false);
      await tester.pump();
      expect(input.text, '原来的问题');
      expect(edited, null);
      await tester.tap(find.text('说完了'));
      await tester.pump();
      expect(engine.stops, 1);
      engine.result!('我要缩短通勤。', true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('填入输入框'));
      await tester.pumpAndSettle();
      expect(input.text, '原来的问题\n我要缩短通勤。');
      expect(edited, input.text);
      expect(input.selection.baseOffset, input.text.length);
      await tester.pumpWidget(const SizedBox());
      input.dispose();
    },
  );

  testWidgets(
    'permission denied leaves text input available and never listens',
    (tester) async {
      final engine = FakeDictation()..available = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DictationSheet(engine: engine)),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.listens, 0);
      expect(find.textContaining('未获得语音权限'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '填入输入框'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'closing while permission is pending never starts recording later',
    (tester) async {
      final permission = Completer<bool>();
      final engine = FakeDictation()..permission = permission;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DictationSheet(engine: engine)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(engine.listens, 0);
      expect(engine.cancels, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stop without final event finishes; retry gets a new deadline', (
    tester,
  ) async {
    final engine = FakeDictation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DictationSheet(engine: engine)),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      engine.result!('部分文字', false);
      await tester.pump();
      await tester.tap(find.text('说完了'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('填入输入框'), findsOneWidget);
      if (i == 0) {
        await tester.tap(find.text('重新说'));
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background transition cancels recording and ignores late result',
    (tester) async {
      final engine = FakeDictation();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DictationSheet(engine: engine)),
        ),
      );
      await tester.pumpAndSettle();
      engine.result!('已识别内容', false);
      await tester.pump();
      final cancels = engine.cancels;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      engine.result!('迟到内容', true);
      await tester.pump();
      expect(engine.cancels, greaterThan(cancels));
      expect(find.text('已识别内容'), findsOneWidget);
      expect(find.text('迟到内容'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('empty/error and overlength speech do not fill draft', (
    tester,
  ) async {
    final engine = FakeDictation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DictationSheet(engine: engine, maxCharacters: 2)),
      ),
    );
    await tester.pumpAndSettle();
    engine.error!('error_no_match');
    await tester.pumpAndSettle();
    expect(find.textContaining('没有听清'), findsOneWidget);
    await tester.tap(find.text('重新说'));
    await tester.pumpAndSettle();
    engine.result!('太长的输入', true);
    await tester.pumpAndSettle();
    expect(find.textContaining('超出输入框'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '填入输入框'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
