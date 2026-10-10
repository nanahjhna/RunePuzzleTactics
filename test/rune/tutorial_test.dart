/// 튜토리얼 스크립트 결정성 테스트 (RPT-418 ~ RPT-426)
/// - 레인보우/블랙/셔플 등 제거된 요소를 제외한, 개편된 7개 섹션 검증 라이브러리
library;

import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

/// 섹션 스크립트 보드로 엔진 구성 (섹션 스테이지 설정 그대로).
BattleEngine tutorialEngine(TutorialSection s) {
  final battle = BattleEngine.create(
    stage: s.stage,
    roster: HeroRoster.initial(),
    rng: math.Random(42),
    board: PuzzleBoard.fromRows(s.boardRows),
  );
  battle.startBattle();
  return battle;
}

/// 플레이어 스왑 적용 (Plan → Action 승급 포함).
void applyMove(BattleEngine battle, int from, int to) {
  battle.onDragStart(from);
  battle.onDragEnd(PuzzleMove(from, to));
}

/// 보드 위 모든 인접 스왑을 시도해 유효(매치 발생) 스왑 목록을 모은다.
List<PuzzleMove> collectValidMoves(TutorialSection s) {
  final battle = tutorialEngine(s);
  final moves = <PuzzleMove>[];
  for (var from = 0; from < PuzzleBoard.size; from++) {
    final x = from % PuzzleBoard.cols;
    final y = from ~/ PuzzleBoard.rows;
    for (final (dx, dy) in [(1, 0), (0, 1)]) {
      final nx = x + dx;
      final ny = y + dy;
      if (nx >= PuzzleBoard.cols || ny >= PuzzleBoard.rows) continue;
      final to = ny * PuzzleBoard.cols + nx;
      final probe = battle.state.board.clone();
      final result = battle.engine.resolveSwap(probe, from: from, to: to);
      if (result.waves.isNotEmpty) moves.add(PuzzleMove(from, to));
    }
  }
  return moves;
}

void main() {
  group('튜토리얼 스크립트 구성', () {
    test('6개 섹션 + 고유 id + 스크립트 보드 파싱', () {
      expect(TutorialScript.sections, hasLength(6));
      final ids = TutorialScript.sections.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final s in TutorialScript.sections) {
        expect(s.boardRows, hasLength(PuzzleBoard.rows),
            reason: '${s.id}: 보드는 ${PuzzleBoard.rows}행이어야 한다');
        for (final row in s.boardRows) {
          expect(row.length, PuzzleBoard.cols,
              reason: '${s.id}: 보드 행은 ${PuzzleBoard.cols}열이어야 한다');
        }
        expect(() => PuzzleBoard.fromRows(s.boardRows), returnsNormally,
            reason: '${s.id}: 스크립트 문자가 잘못됨');
      }
    });
  });

  group('튜토리얼 핵심 규칙', () {
    test('콤보 섹션: 한 스왑으로 연쇄 ≥ 2 (RPT-81)', () {
      final s = TutorialScript.sections.firstWhere((s) => s.id == 'combo');
      final battle = tutorialEngine(s);

      applyMove(battle, s.hintMove!.from, s.hintMove!.to);
      // 몬스터 턴 후 state.combo는 0이므로 lastCascade로 판정
      expect(battle.lastCascade?.finalCombo, greaterThanOrEqualTo(2));
      expect(s.isDone(battle), isTrue);
    });

    test('몬스터 턴: 스왑 후 몬스터 공격으로 파티 피해 (RPT-112)', () {
      final s = TutorialScript.sections.firstWhere((s) => s.id == 'monster');
      final battle = tutorialEngine(s);
      applyMove(battle, s.hintMove!.from, s.hintMove!.to);
      expect(battle.state.partyHp, lessThan(battle.state.partyMaxHp));
      expect(s.isDone(battle), isTrue);
    });

    test('보스 섹션: Fire 매치 1방으로 승리', () {
      // 몬스터는 무속성이지만 이 스테이지의 약점은 Fire(×1.5)다.
      // fire_a ATK 15 × combo 1.0 × 1.5 = 22.5 → 23, 한 번에 격파된다.
      final s = TutorialScript.sections.firstWhere((s) => s.id == 'boss');
      expect(s.stage.weakElement, RuneElement.fire);
      expect(s.stage.affinityFor(RuneElement.fire), 1.5);
      expect(s.stage.monsterHp, lessThanOrEqualTo(23));
      final battle = tutorialEngine(s);
      applyMove(battle, s.hintMove!.from, s.hintMove!.to);
      expect(battle.state.phase, BattlePhase.victory);
      expect(s.isDone(battle), isTrue);
    });
  });
}
