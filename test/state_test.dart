import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_guide/app_state.dart';
import 'package:life_guide/models.dart';
import 'package:life_guide/services/api.dart';
import 'fakes.dart';

void main() {
  test(
    'results, actions and favorites persist and action saving deduplicates',
    () async {
      final api = FakeApi(), store = MemoryStore();
      final state = AppState(
        disclosure: testDisclosure,
        api: api,
        store: store,
      );
      await state.acceptAiConsent();
      final session = state.start('测试问题');
      await api.finish();
      expect(state.busy, false);
      state.favorite(session);
      final a = state.saveAction(session, session.turns.single, '我的行动', '第一步');
      expect(
        state.saveAction(session, session.turns.single, '我的行动', '第一步').id,
        a.id,
      );
      state.updateAction(a, state: ActionState.paused, feedback: '成本太高');
      await state.flush();
      final restored = AppState(
        disclosure: testDisclosure,
        api: FakeApi(),
        store: store,
      );
      await restored.load();
      expect(restored.sessions.single.favorite, true);
      expect(restored.actions.single.state, ActionState.paused);
      expect(restored.actions.single.feedback, '成本太高');
      state.dispose();
      restored.dispose();
    },
  );
  test(
    'followup sends selected ancestors rather than other branches',
    () async {
      final api = FakeApi();
      final s = AppState(
        disclosure: testDisclosure,
        api: api,
        store: MemoryStore(),
      );
      await s.acceptAiConsent();
      final session = s.start('root');
      await api.finish('root answer');
      final root = session.turns.first;
      s.followup(session, root, 'branch one');
      await api.finish('branch one answer');
      s.followup(session, root, 'branch two');
      expect(api.requests.last, contains('root answer'));
      expect(api.requests.last, isNot(contains('branch one')));
      await api.finish();
      s.dispose();
    },
  );
  test(
    'stop and restart mark partial records; duplicate requests prevented',
    () async {
      final api = FakeApi(), store = MemoryStore();
      final s = AppState(disclosure: testDisclosure, api: api, store: store);
      await s.acceptAiConsent();
      final session = s.start('question');
      expect(() => s.start('duplicate'), throwsA(isA<ApiFailure>()));
      expect(
        () => s.saveAction(session, session.turns.first, 'x', 'y'),
        throwsA(isA<ApiFailure>()),
      );
      await s.flush();
      final restored = AppState(
        disclosure: testDisclosure,
        api: FakeApi(),
        store: store,
      );
      await restored.load();
      expect(
        restored.sessions.single.turns.single.status,
        AnswerStatus.interrupted,
      );
      s.stop();
      await Future<void>.delayed(Duration.zero);
      expect(s.busy, false);
      expect(session.turns.single.status, AnswerStatus.interrupted);
      s.dispose();
      restored.dispose();
    },
  );
  test(
    'deleting analysis keeps action; clear removes all local records',
    () async {
      final api = FakeApi(), store = MemoryStore();
      final s = AppState(disclosure: testDisclosure, api: api, store: store);
      await s.acceptAiConsent();
      final session = s.start('question');
      await api.finish();
      final a = s.saveAction(session, session.turns.single, 'x', 'y');
      s.deleteSession(session.id);
      expect(s.actions.single.id, a.id);
      expect(s.turn(a.sessionId, a.turnId), null);
      await s.flush();
      await s.clear();
      expect(s.actions, isEmpty);
      expect(store.value, null);
      s.dispose();
    },
  );
  test('broken storage is not overwritten until explicit reset', () async {
    final store = MemoryStore()..value = 'broken';
    final s = AppState(
      disclosure: testDisclosure,
      api: FakeApi(),
      store: store,
    );
    await s.load();
    s.setDraft('new');
    await s.flush();
    expect(store.value, 'broken');
    expect(s.storageError, isNotNull);
    await s.clear();
    s.setDraft('new');
    await s.flush();
    expect(jsonDecode(store.value!)['draft'], 'new');
    s.dispose();
  });
}
