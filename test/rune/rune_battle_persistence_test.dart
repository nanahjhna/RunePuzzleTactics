/// 배틀 → 진행도 저장 통합 테스트 (PHASE 5 + 7, RPT-316)
library;

import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_battle_game.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_battle_view.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_state_helpers.dart';

void main() {
  /// store 주입 + 결정적 RNG로 배틀 화면을 띄운다 (engine 주입 금지 → 재시작/저장 로직이 실제 동작).
  /// 한국어 문자열 검증 유지: ko 고정 LanguageScope로 감싼다 (Localization 테스트 하네스).
  Future<RuneBattleGame> pumpView(
    WidgetTester tester, {
    required InMemoryRuneProgressStore store,
  }) async {
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(
          persist: false,
          initialLanguage: AppLanguage.ko,
        ),
        child: MaterialApp(
          home: RuneBattleView(
            rng: math.Random(7),
            store: store,
            analytics: RuneAnalytics.disabled,
          ),
        ),
      ),
    );
    // store 로드(비동기) → 로딩 화면 → 실제 배틀 화면
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final gameWidget = tester.widget<GameWidget>(find.bySubtype<GameWidget>());
    return gameWidget.game! as RuneBattleGame;
  }

  group('배틀 결과 → 진행도 저장', () {
    testWidgets('Victory: Game 보상 + 최고 클리어 + 승리 횟수 저장', (tester) async {
      final store = InMemoryRuneProgressStore();
      final game = await pumpView(tester, store: store);

      final stage = game.battle.state.stage;
      game.battle.state.monsterHp = 0;
      game.battle.state.phase = BattlePhase.victory;
      game.refreshHud();
      await tester.pump();
      await tester.pump(); // 승/패 확정 → 1.5초 연출 버퍼 타이머 예약 (요구사항 6.2)
      await tester.pump(const Duration(milliseconds: 1500)); // 버퍼 경과 → 결과 push
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // 연출 버퍼 오버레이(요구사항 6.2)와 결과 화면 타이틀이 '🎉 승리!'를 표시한다.
      expect(find.text('🎉 승리!'), findsWidgets);

      final saved = await store.load();
      expect(saved.gameCurrency, stage.goldReward);
      expect(saved.highestCleared, 1);
      expect(saved.nextStage, 2);
      expect(saved.wins, 1);
      expect(saved.losses, 0);
      // 시작 파티(Fire 1) 유지
      expect(saved.partyCount(RuneElement.fire), 1);
    });

    testWidgets('Defeat: 패배 횟수만 저장 (Game 재화 변화 없음)', (tester) async {
      final store = InMemoryRuneProgressStore(
        RuneMeta.initial().copyWith(gameCurrency: 250),
      );
      final game = await pumpView(tester, store: store);

      wipeParty(game.battle.state);
      game.battle.state.phase = BattlePhase.defeat;
      game.refreshHud();
      await tester.pump();
      await tester.pump(); // 승/패 확정 → 1.5초 연출 버퍼 타이머 예약 (요구사항 6.2)
      await tester.pump(const Duration(milliseconds: 1500)); // 버퍼 경과 → 결과 push
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // 턴 인디케이터/연출 버퍼 오버레이(요구사항 6.2)와 결과 화면 타이틀이 '💀 패배'를 표시한다.
      expect(find.text('💀 패배'), findsWidgets);

      final saved = await store.load();
      expect(saved.gameCurrency, 250);
      expect(saved.losses, 1);
      expect(saved.wins, 0);
      expect(saved.highestCleared, 0);
    });
  });

  group('저장된 파티 복원 (RPT-316)', () {
    testWidgets('저장 진행도의 파티가 배틀에 반영된다', (tester) async {
      final store = InMemoryRuneProgressStore(
        RuneProgress(
          highestCleared: 0,
          gameCurrency: 0,
          playCurrency: 5,
          heroOwned: {HeroPool.starter.heroId, 'water_a'},
          heroParty: [HeroPool.starter.heroId, 'water_a'],
        ),
      );
      final game = await pumpView(tester, store: store);

      expect(game.battle.state.party.partyTotal, 2);
      expect(game.battle.state.party.partyCount(RuneElement.fire), 1);
      expect(game.battle.state.party.partyCount(RuneElement.water), 1);
      expect(find.bySubtype<GameWidget>(), findsOneWidget);
    });
  });
}
