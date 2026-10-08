import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_guide/main.dart';
import 'package:life_guide/app_state.dart';
import 'fakes.dart';
import 'package:life_guide/services/guide_sources.dart';

void main() {
  testWidgets(
    'home submits real input and shows response without fixed questionnaire',
    (tester) async {
      final api = FakeApi();
      final s = AppState(
        disclosure: testDisclosure,
        api: api,
        store: MemoryStore(),
      );
      await s.acceptAiConsent();
      await tester.runAsync(() => GuideSources.load());
      await tester.pumpWidget(LifeGuideApp(state: s));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('question-input')), '用户实际问题');
      await tester.pump();
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.requests.single, '用户实际问题');
      expect(find.text('你更在意什么？'), findsNothing);
      await api.finish('服务端返回的实际答案');
      await tester.pumpAndSettle();
      expect(find.text('服务端返回的实际答案'), findsWidgets);
      expect(find.text('引用条目 · 1'), findsOneWidget);
      await tester.ensureVisible(find.text('引用条目 · 1'));
      await tester.tap(find.text('引用条目 · 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('第 4 节第 18 条'), findsOneWidget);
      expect(find.text('原项目证据 B'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('引用条目 · 1'));
        await tester.tap(find.text('引用条目 · 1'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('第 4 节第 18 条'), findsOneWidget);
      await tester.ensureVisible(find.text('第 4 节第 18 条'));
      await tester.tap(find.text('第 4 节第 18 条'));
      await tester.pumpAndSettle();
      expect(find.text('引用原文'), findsOneWidget);
      expect(
        find.textContaining('选住处时把通勤时长', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.text('本节阅读说明'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('你的建议'), findsOneWidget);
      expect(find.text('第 4 节第 18 条'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  for (final draft in ['', '我的原问题']) {
    testWidgets('popular question directly analyzes with draft "$draft"', (
      tester,
    ) async {
      final api = FakeApi();
      final state = AppState(
        disclosure: testDisclosure,
        api: api,
        store: MemoryStore(),
      );
      await state.acceptAiConsent();
      await tester.pumpWidget(LifeGuideApp(state: state));
      await tester.pumpAndSettle();
      if (draft.isNotEmpty) {
        await tester.enterText(find.byKey(const Key('question-input')), draft);
      }
      final tile = find.byKey(const ValueKey('popular-question-0'));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      final prompt = (tester.widget<ListTile>(tile).title as Text).data!;
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('你的建议'), findsOneWidget);
      expect(api.requests, [prompt]);
      expect(state.draft, isEmpty);
      await api.finish('热门问题的分析结果');
      await tester.pumpAndSettle();
      expect(find.text('热门问题的分析结果'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }

  testWidgets(
    'question batch stays stable during editing and changes on tab reentry',
    (tester) async {
      final state = AppState(
        disclosure: testDisclosure,
        api: FakeApi(),
        store: MemoryStore(),
      );
      await state.acceptAiConsent();
      await tester.pumpWidget(LifeGuideApp(state: state));
      await tester.pumpAndSettle();
      Future<List<String>> batch() async {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('popular-question-0')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        return List.generate(
          5,
          (i) =>
              (tester
                          .widget<ListTile>(
                            find.byKey(ValueKey('popular-question-$i')),
                          )
                          .title
                      as Text)
                  .data!,
        );
      }

      final first = await batch();
      expect(first.toSet().length, 5);
      await tester.ensureVisible(find.byKey(const Key('question-input')));
      await tester.enterText(find.byKey(const Key('question-input')), '保留草稿');
      await tester.pumpAndSettle();
      expect(await batch(), first);
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('人生指南').last);
      await tester.pumpAndSettle();
      final second = await batch();
      expect(second.toSet().intersection(first.toSet()), isEmpty);
      expect(state.draft, '保留草稿');
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('clearing local data also clears the visible draft', (
    tester,
  ) async {
    final state = AppState(
      disclosure: testDisclosure,
      api: FakeApi(),
      store: MemoryStore(),
    );
    await state.acceptAiConsent();
    await tester.pumpWidget(LifeGuideApp(state: state));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('question-input')), '待清空的草稿');
    await state.clear();
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const Key('question-input')),
    );
    expect(input.controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('dark theme and large text remain usable at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = AppState(
        disclosure: testDisclosure,
        api: FakeApi(),
        store: MemoryStore(),
      );
      await s.acceptAiConsent();
      await tester.pumpWidget(LifeGuideApp(state: s));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['我的行动', '我的']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
  testWidgets('narrow screen navigation does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = AppState(
      disclosure: testDisclosure,
      api: FakeApi(),
      store: MemoryStore(),
    );
    await s.acceptAiConsent();
    await tester.pumpWidget(LifeGuideApp(state: s));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.text('我的行动').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
