// Explicit live-service test: runs only when this file is selected on a device.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_guide/app_state.dart';
import 'package:life_guide/services/api.dart';
import 'package:life_guide/main.dart';
import 'package:life_guide/models.dart';
import 'package:life_guide/services/storage.dart';

class VolatileStore implements LocalStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native screen submits to live server and completes streaming', (
    tester,
  ) async {
    final state = AppState(api: DecisionApi(), store: VolatileStore());
    state.topK = 1;
    await tester.pumpWidget(LifeGuideApp(state: state));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('question-input')),
      '每天通勤两小时，如何判断是否值得搬到公司附近？',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pump(const Duration(seconds: 1));
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (state.busy && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final turn = state.sessions.single.turns.single;
    expect(turn.status, AnswerStatus.complete, reason: turn.error);
    expect(turn.answer, isNotEmpty);
    expect(turn.citations, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
