import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_battle_game.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_battle_view.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_state_helpers.dart';

void main() {
  /// [engine]을 주입하지 않는다 — 재시작(retry/next)이 새 엔진을 만들도록.
  /// 한국어 문자열 검증 유지: ko 고정 LanguageScope로 감싼다 (Localization 테스트 하네스).
  Future<RuneBattleGame> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(
          persist: false,
          initialLanguage: AppLanguage.ko,
        ),
        child: MaterialApp(home: RuneBattleView(rng: math.Random(7))),
      ),
    );
    await tester.pump();
    final gameWidget = tester.widget<GameWidget>(find.bySubtype<GameWidget>());
    return gameWidget.game! as RuneBattleGame;
  }

  /// [store]를 갖춘 진입 (저장 진행도 → 아이템/재화 반영).
  Future<RuneBattleGame> pumpViewWithStore(
    WidgetTester tester,
    RuneProgressStore store,
  ) async {
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(
          persist: false,
          initialLanguage: AppLanguage.ko,
        ),
        child: MaterialApp(
          home: RuneBattleView(store: store, rng: math.Random(7)),
        ),
      ),
    );
    await tester.pump(); // bootstrap 로드
    await tester.pump();
    final gameWidget = tester.widget<GameWidget>(find.bySubtype<GameWidget>());
    return gameWidget.game! as RuneBattleGame;
  }

  /// 결과 화면(전체 화면 라우트)이 나타날 때까지 전환 애니메이션을 진행한다.
  /// 요구사항 6.2: 승/패 확정 후 1.5초 연출 버퍼를 거친 뒤 결과 화면이 열린다.
  Future<void> settleResultRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(); // 승/패 확정 → 1.5초 연출 버퍼 타이머 예약
    await tester.pump(const Duration(milliseconds: 1500)); // 버퍼 경과 → 결과 push
    await tester.pump(const Duration(milliseconds: 400)); // 라우트 전환
    await tester.pump();
  }

  group('Rune 배틀 화면 (PHASE 4 + PHASE 7 UI)', () {
    testWidgets('HUD/보드 렌더링: 게임 위젯과 핵심 요소가 나타난다', (tester) async {
      final game = await pumpView(tester);
      expect(game, isNotNull);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySubtype<GameWidget>(), findsOneWidget);
      expect(find.textContaining('STAGE 1'), findsOneWidget);
      expect(find.textContaining('몬스터'), findsWidgets);
      // 몬스터 HP 위에 스테이지 상성(약점/열세) 칩이 뜬다 — 배율이 붙는 규칙을
      // 미리 보여준다. 유닛 슬롯의 ×N 시너지 태그는 삭제됐다.
      expect(find.text('약점'), findsOneWidget);
      expect(find.text('열세'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('battle-synergy-chip')),
        findsNothing,
      );
      // 파티 HP 는 통합 바가 아니라 영웅 포트레이트 **하단** 개별 바에 표시된다.
      expect(find.byKey(const ValueKey('battle-hero-0')), findsOneWidget);
      // 요청 3: 턴 인디케이터가 없다 (보드 그레이아웃으로 대체).
      expect(find.textContaining('PLAYER TURN'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('몬스터 피해 표시 삭제: 개별 피해/합계/초과 칩이 모두 사라졌다 (요청 6)', (tester) async {
      final game = await pumpView(tester);
      final hit = DamageHit(
        source: DamageSource.match,
        element: RuneElement.water,
        damage: 42,
      );

      // 콜백은 엔진/게임에 남아 있으므로 여러 번 호출해도 몬스터 HP 는 줄고,
      // 화면에는 피해 숫자 오버레이가 전혀 렌더링되지 않는다.
      game.onMonsterDamage?.call(hit);
      game.onMonsterDamageTotal?.call(126);
      await tester.pump();

      expect(find.text('💧 -42'), findsNothing);
      expect(find.textContaining('-42'), findsNothing);
      expect(find.byKey(const ValueKey('monster-damage-total')), findsNothing);
      expect(find.byKey(const ValueKey('monster-damage-overflow')), findsNothing);
      expect(find.byType(GestureDetector), findsWidgets); // 보드 등 다른 제스처는 유지
      expect(tester.takeException(), isNull);
    });

    testWidgets('파티 피격 시 화면이 점멸한다', (tester) async {
      // store 없으면 진행도가 없어 파티 HP 가 0 이다 — 실제 HP 로 깎이려면
      // store 로 진입해 영웅별 스탯이 주입되게 한다.
      final store = InMemoryRuneProgressStore(RuneMeta.initial());
      final game = await pumpViewWithStore(tester, store);
      expect(game.battle.state.partyHp, greaterThan(0));

      damageParty(game.battle.state, 10);
      game.refreshHud();
      await tester.pump();
      expect(find.byKey(const ValueKey('party-damage-flash')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('party-damage-flash')), findsNothing);
    });

    testWidgets('턴 표시 제거: 몬스터 턴에만 보드가 그레이아웃된다 (요청 3)', (tester) async {
      final game = await pumpView(tester);
      final battle = game.battle;

      // 초기(plan): 플레이어 턴 → 그레이아웃 없음
      expect(find.textContaining('PLAYER TURN'), findsNothing);
      expect(find.byKey(const ValueKey('board-gray-overlay')), findsNothing);

      // 몬스터 턴 전환 → 보드 그레이아웃 + 턴 라벨은 표시되지 않는다
      battle.state.phase = BattlePhase.monsterTurn;
      game.refreshHud();
      await tester.pump();
      expect(find.textContaining('MONSTER TURN'), findsNothing);
      expect(find.byKey(const ValueKey('board-gray-overlay')), findsOneWidget);

      // 플레이어 턴 복귀 → 그레이아웃 해제
      battle.state.phase = BattlePhase.plan;
      game.refreshHud();
      await tester.pump();
      expect(find.byKey(const ValueKey('board-gray-overlay')), findsNothing);
    });

    testWidgets('Victory → 결과 화면(전체 화면): 승리 문구 + 다음 스테이지', (tester) async {
      final game = await pumpView(tester);

      game.battle.state.monsterHp = 0;
      game.battle.state.phase = BattlePhase.victory;
      game.refreshHud();
      await settleResultRoute(tester);

      expect(
        find.text('🎉 승리!'),
        findsWidgets,
      ); // 연출 버퍼 오버레이 + 결과 화면 타이틀 (요구사항 6.2)
      expect(find.byKey(const ValueKey('result-next')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-lobby')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-retry')), findsNothing);
    });

    testWidgets('Defeat → 결과 화면: 패배 문구 + 다시 도전/상점 버튼', (tester) async {
      final game = await pumpView(tester);

      wipeParty(game.battle.state);
      game.battle.state.phase = BattlePhase.defeat;
      game.refreshHud();
      await settleResultRoute(tester);

      // 턴 인디케이터/연출 버퍼 오버레이(요구사항 6.2)와 결과 화면 타이틀이 '💀 패배'를 표시한다.
      expect(find.text('💀 패배'), findsWidgets);
      expect(find.byKey(const ValueKey('result-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-lobby')), findsOneWidget);
      expect(find.text('상점으로 (성장 후 재도전)'), findsNothing);
    });

    testWidgets('결과 화면: 다시 도전 → 새 배틀(plan)로 재시작', (tester) async {
      final game = await pumpView(tester);

      wipeParty(game.battle.state);
      game.battle.state.phase = BattlePhase.defeat;
      game.refreshHud();
      await settleResultRoute(tester);

      await tester.tap(find.byKey(const ValueKey('result-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // 결과 라우트 pop + 재시작
      await tester.pump();

      final newGame =
          tester.widget<GameWidget>(find.bySubtype<GameWidget>()).game!
              as RuneBattleGame;
      expect(newGame.battle, isNot(same(game.battle)));
      expect(newGame.battle.state.stage.stageNumber, 1);
      expect(newGame.battle.state.phase, BattlePhase.plan);
      expect(find.textContaining('PLAYER TURN'), findsNothing);
    });

    testWidgets('결과 화면: 다음 스테이지 → 스테이지 2로 재시작', (tester) async {
      final game = await pumpView(tester);

      game.battle.state.monsterHp = 0;
      game.battle.state.phase = BattlePhase.victory;
      game.refreshHud();
      await settleResultRoute(tester);

      await tester.tap(find.byKey(const ValueKey('result-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final newGame =
          tester.widget<GameWidget>(find.bySubtype<GameWidget>()).game!
              as RuneBattleGame;
      expect(newGame.battle, isNot(same(game.battle)));
      expect(newGame.battle.state.stage.stageNumber, 2);
    });

    testWidgets('일시정지 → 엔진 pause + 오버레이(재개/다시하기/로비로) → 재개', (tester) async {
      final game = await pumpView(tester);
      expect(game.battle.state.paused, isFalse);

      // 요구사항 6.1: 진입 직후 1.5초 카운트다운이 끝난 뒤에만 조작 가능.
      await tester.pump(const Duration(milliseconds: 1600));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(game.battle.state.paused, isTrue);
      expect(find.text('재개'), findsOneWidget);
      expect(find.text('다시하기'), findsOneWidget);
      expect(find.text('로비로'), findsOneWidget);

      await tester.tap(find.text('재개'));
      await tester.pump();
      expect(game.battle.state.paused, isFalse);
      expect(find.text('재개'), findsNothing);
    });

    testWidgets('Android Back → 일시정지 토글 (RPT-411)', (tester) async {
      final game = await pumpView(tester);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      await navigator.maybePop(); // Back 1: 일시정지
      await tester.pump();
      expect(game.battle.state.paused, isTrue);
      expect(find.text('일시정지'), findsOneWidget);

      await navigator.maybePop(); // Back 2: 재개
      await tester.pump();
      expect(game.battle.state.paused, isFalse);
      expect(find.text('일시정지'), findsNothing);
    });

    testWidgets('상단 [X] 없음 + 일시정지 버튼 → 오버레이 (요청 1·2)', (tester) async {
      final game = await pumpView(tester);

      // 요청 1: 상단 X 버튼이 제거되었다.
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(game.battle.state.paused, isTrue);
      expect(find.text('일시정지'), findsOneWidget);
      expect(find.text('다시하기'), findsOneWidget);
      expect(find.text('로비로'), findsOneWidget);
    });

    testWidgets('일시정지: 다시하기 → 입장 비용 재차감 + 새 배틀 (요청 2)', (tester) async {
      final store = InMemoryRuneProgressStore(RuneMeta.initial());
      final game = await pumpViewWithStore(tester, store);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('다시하기'), findsOneWidget);

      await tester.tap(find.text('다시하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 새 배틀(새 엔진)로 재시작 + Play 입장 비용 1 재차감.
      final newGame =
          tester.widget<GameWidget>(find.bySubtype<GameWidget>()).game!
              as RuneBattleGame;
      expect(newGame.battle, isNot(same(game.battle)));
      final saved = await store.load();
      expect(saved.playCurrency, RuneMeta.stageEntryCost * 4); // 5 → 4
    });

    testWidgets('오래 대기해도 턴 제한시간 없이 플레이어 턴이 유지된다', (tester) async {
      final game = await pumpView(tester);
      final battle = game.battle;
      await tester.pump();

      await tester.pump(const Duration(seconds: 90));
      expect(battle.state.phase, BattlePhase.plan);
      expect(find.text('TIMER'), findsNothing);
      expect(find.text('제한시간'), findsNothing);
    });
  });
}
