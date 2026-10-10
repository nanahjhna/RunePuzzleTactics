import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_helpers.dart';

/// 몬스터 반격 1건이 파티에 주는 피해.
///
/// ```
/// damage = max(1, round(ATK × 100 / (100 + 대상 DEF)))
/// ```
///
/// [testStage] 기본값(ATK 10)에서 대상은 fire_a(DEF 8)다 — 10 × 100/108 = 9.26
/// → 9. 예전의 `ATK - DEF` 선형 차감이었다면 2 였고, 지금은 **9** 라는 점이 이
/// 테스트들이 잡아야 할 값이다. 값에 10 을 하드코딩하지 않고 여기서 파생시킨다.
const int _monsterHit = 9;

void main() {
  group('Black 규칙 (RPT-47 ~ RPT-55)', () {
    test('Direct Black 3: 100% Party Damage (배틀 계층)', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(idx(board, 1, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 4), rune(RuneElement.black));

      final battle = battleWithBoard(
        board: board,
        stage: testStage(blackSpawnRate: 0, blackDamage: 10),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(PuzzleMove(idx(board, 3, 4), idx(board, 3, 5)));

      expect(
        battle.partyHp,
        100 - 10 - _monsterHit,
      ); // Black Direct 10 + 몬스터 반격(감쇄형)
      final w1 = battle.lastCascade!.waves.first;
      expect(w1.hasNormalMatch, isFalse);
      expect(w1.combo, 0); // Black-only 파도는 Combo 증가 없음
    });

    test('Cascade Black 3: 50% Party Damage (RPT-52~53)', () {
      final board = boardFromRows(cleanRows);
      // Wave1: Swap으로 row2 FFF (cols 3~5) — 검은 룬 낙하 경로와 분리.
      board.setIndex(idx(board, 3, 2), rune(RuneElement.fire));
      board.setIndex(idx(board, 4, 2), rune(RuneElement.fire));
      board.setIndex(idx(board, 5, 2), rune(RuneElement.grass));
      board.setIndex(idx(board, 5, 1), rune(RuneElement.fire));
      // Wave2용: 매달린 Black 3개 (cols 1~3, 낙하 경로 비움)
      board.setIndex(idx(board, 1, 4), rune(RuneElement.black));
      board.setIndex(idx(board, 1, 5), null);
      board.setIndex(idx(board, 2, 3), rune(RuneElement.black));
      board.setIndex(idx(board, 2, 4), null);
      board.setIndex(idx(board, 2, 5), null);
      board.setIndex(idx(board, 3, 4), rune(RuneElement.black));
      board.setIndex(idx(board, 3, 5), null);

      final battle = battleWithBoard(
        board: board,
        stage: testStage(blackSpawnRate: 0, blackDamage: 10, monsterHp: 10000),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(PuzzleMove(idx(board, 5, 1), idx(board, 5, 2)));

      expect(
        battle.partyHp,
        100 - 5 - _monsterHit,
      ); // Cascade ×0.5 → 5 + 몬스터 반격(감쇄형)
      expect(battle.lastCascade!.waves.length, greaterThanOrEqualTo(2));
    });

    test('Black 4: Damage + Line Purge (RPT-52~54)', () {
      final board = boardFromRows(cleanRows);
      // 바닥 행(cols 0~2)에 Black 3개 + 스왑으로 4번째 Black(3,5) 생성.
      board.setIndex(idx(board, 0, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 1, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 4), rune(RuneElement.black));
      board.setIndex(idx(board, 4, 5), rune(RuneElement.fire)); // 동일 행 분리
      board.setIndex(idx(board, 5, 5), rune(RuneElement.black)); // 동일 행 → 정화

      final battle = battleWithBoard(
        board: board,
        stage: testStage(blackSpawnRate: 0, blackDamage: 10),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(PuzzleMove(idx(board, 3, 4), idx(board, 3, 5)));

      expect(battle.partyHp, 90 - _monsterHit); // Black 4 Direct 10 + 몬스터 반격
      final w1 = battle.lastCascade!.waves.first;
      expect(w1.runs.single.length, 4);
      // 같은 행의 다른 Black은 정화되어 제거됨
      expect(w1.purgedBlackCells.contains(idx(board, 5, 5)), isTrue);
      expect(w1.removedCells.contains(idx(board, 5, 5)), isTrue);
      expect(battle.state.board.blackCount, 0);
    });

    test('Black 5: 피해 0 + 전체 Black 정화 (RPT-55, RPT-128, RPT-296)', () {
      final board = boardFromRows(cleanRows);
      // 바닥 행(cols 0~3)에 Black 4개 + 스왑으로 5번째 Black(4,5) 생성.
      board.setIndex(idx(board, 0, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 1, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 4, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 4, 4), rune(RuneElement.black));
      board.setIndex(idx(board, 5, 4), rune(RuneElement.black)); // 정화 대상(러너 아님)
      board.setIndex(idx(board, 0, 0), rune(RuneElement.black));

      final battle = battleWithBoard(
        board: board,
        stage: testStage(blackSpawnRate: 0, blackDamage: 10),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(PuzzleMove(idx(board, 4, 4), idx(board, 4, 5)));

      expect(battle.partyHp, 100 - _monsterHit); // Black 5 피해 0 + 몬스터 반격
      final w1 = battle.lastCascade!.waves.first;
      expect(w1.runs.single.length, 5);
      expect(w1.purgedBlackCells.contains(idx(board, 0, 0)), isTrue);
      expect(battle.state.board.blackCount, 0); // 전체 정화
    });

    test('Black이 파티를 사망시키면 Defeat (RPT-148)', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(idx(board, 1, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.black));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 4), rune(RuneElement.black));

      final battle = battleWithBoard(
        board: board,
        stage: testStage(blackSpawnRate: 0, blackDamage: 10),
        partyMaxHp: 10,
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(PuzzleMove(idx(board, 3, 4), idx(board, 3, 5)));

      expect(battle.partyHp, 0);
      expect(battle.state.phase, BattlePhase.defeat);
    });
  });
}

int idx(PuzzleBoard b, int x, int y) => b.indexAt(x, y);
BoardTile rune(RuneElement e) => BoardTile.rune(e);