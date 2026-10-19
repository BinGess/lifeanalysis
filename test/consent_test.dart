import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_guide/app_state.dart';
import 'package:life_guide/main.dart';
import 'package:life_guide/services/ai_disclosure.dart';
import 'package:life_guide/services/api.dart';
import 'fakes.dart';

void main() {
  test('release disclosure identifies recipients and policies', () {
    const disclosure = AiDisclosure();
    expect(disclosure.ready, true);
    expect(disclosure.operatorName, 'BinGess');
    expect(disclosure.providerName, contains('北京春田知韵科技有限公司'));
    expect(Uri.parse(disclosure.privacyUrl).scheme, 'https');
    expect(Uri.parse(disclosure.providerPrivacyUrl).scheme, 'https');
  });

  test(
    'all analysis is blocked before consent; persisted, versioned and revocable',
    () async {
      final store = MemoryStore(), api = FakeApi();
      final s = AppState(api: api, store: store, disclosure: testDisclosure);
      expect(() => s.start('test'), throwsA(isA<ApiFailure>()));
      expect(s.sessions, isEmpty);
      expect(api.requests, isEmpty);
      await s.acceptAiConsent();
      final session = s.start('test');
      await api.finish();
      await s.flush();
      final restored = AppState(
        api: FakeApi(),
        store: store,
        disclosure: testDisclosure,
      );
      await restored.load();
      expect(restored.hasAiConsent, true);
      final changed = AppState(
        api: FakeApi(),
        store: store,
        disclosure: const AiDisclosure(
          operatorName: '新接收方',
          providerName: '测试 AI 服务商',
          privacyUrl: 'https://privacy.test/app',
          providerPrivacyUrl: 'https://privacy.test/provider',
        ),
      );
      await changed.load();
      expect(changed.hasAiConsent, false);
      await s.revokeAiConsent();
      expect(
        () => s.retry(session, session.turns.first),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => s.followup(session, session.turns.first, 'more'),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.requests.length, 1);
      s.dispose();
      restored.dispose();
      changed.dispose();
    },
  );

  testWidgets('reject preserves draft; accept sends once and opens result', (
    tester,
  ) async {
    final api = FakeApi();
    final s = AppState(
      api: api,
      store: MemoryStore(),
      disclosure: testDisclosure,
    );
    await tester.pumpWidget(LifeGuideApp(state: s));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('question-input')), '我的问题');
    await tester.pump();
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();
    expect(find.text('AI 数据分享许可'), findsOneWidget);
    expect(find.textContaining('接收方：'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('AI 服务商隐私政策'), findsOneWidget);
    expect(api.requests, isEmpty);
    await tester.tap(find.text('不同意'));
    await tester.pumpAndSettle();
    expect(s.draft, '我的问题');
    await tester.pump();
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意并继续分析'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.requests, ['我的问题']);
    await api.finish();
    await tester.pumpAndSettle();
    expect(find.text('你的建议'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  test('incomplete disclosure cannot be accepted', () async {
    final s = AppState(
      api: FakeApi(),
      store: MemoryStore(),
      disclosure: const AiDisclosure(
        operatorName: '',
        providerName: '',
        privacyUrl: '',
        providerPrivacyUrl: '',
      ),
    );
    await expectLater(s.acceptAiConsent(), throwsA(isA<ApiFailure>()));
    expect(s.hasAiConsent, false);
    s.dispose();
  });
}
